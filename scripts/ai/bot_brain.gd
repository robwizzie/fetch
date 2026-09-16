class_name BotBrain
extends Node
## Readable practice opponent: fetch loose toys, aim before throwing, and react to danger.
## Steering uses the same obstacle collisions as players and never teleports the dog.

var _attack_wait := 0.8
var _aim_time := 0.0
var _reaction_wait := 0.0
var _stuck_time := 0.0
var _detour_time := 0.0
var _detour := Vector2.ZERO
var _last_position := Vector3.ZERO


func _ready() -> void:
	_attack_wait = randf_range(0.5, 1.3)
	_last_position = (get_parent() as Dog).global_position
	# Supply input before the dog consumes it in the same physics frame.
	process_physics_priority = -10


func _physics_process(delta: float) -> void:
	var dog := get_parent() as Dog
	if dog == null or not dog.alive or dog.round_locked:
		return
	dog.input.virtual_buttons[&"throw"] = false
	dog.input.virtual_buttons[&"dash"] = false
	_attack_wait -= delta
	_reaction_wait -= delta
	var rival := _nearest_rival(dog)
	if rival == null:
		dog.input.virtual_move = Vector2.ZERO
		return
	var duel := get_tree().get_nodes_in_group("dogs").filter(func(d: Dog) -> bool: return d.alive).size() <= 2
	# Rope wins space, not a duel. Trade it for a finishing toy when one is free.
	if duel and dog.held_toy and dog.held_toy.data.special == ToyData.Special.KNOCKBACK:
		var replacement := _nearest_toy(dog, true)
		if replacement:
			var gap := replacement.global_position - dog.global_position
			if Vector2(gap.x, gap.z).length() < 1.5:
				dog.held_toy.drop(dog.global_position)
				dog._pickup_lock = 0.25
			else:
				dog.input.virtual_move = _steer(dog, Vector2(gap.x, gap.z).normalized(), delta)
				_react(dog)
				return
	var goal := rival.global_position
	if dog.held_toy == null:
		_aim_time = 0.0
		var loose := _nearest_toy(dog, duel)
		if loose:
			goal = loose.global_position
	# A nearby treat is worth a short detour; avoid repeatedly seeking an active buff.
	var treat := _nearby_treat(dog)
	if treat:
		var to_treat := Vector2(treat.global_position.x - dog.global_position.x, treat.global_position.z - dog.global_position.z)
		dog.input.virtual_move = _steer(dog, to_treat.normalized(), delta) * 0.9
		_react(dog)
		return
	var direction := Vector2(goal.x - dog.global_position.x, goal.z - dog.global_position.z)
	var distance := direction.length()
	direction = direction.normalized()
	if dog.held_toy and distance < 11.0 and _clear_path(dog, rival.global_position):
		if _attack_wait <= 0.0:
			# Briefly face the opponent before releasing. Players get a visible tell.
			_aim_time += delta
			dog.input.virtual_move = direction * 0.02
			if _aim_time >= 0.24:
				dog.input.virtual_buttons[&"throw"] = true
				_attack_wait = randf_range(0.9, 1.6)
				_aim_time = 0.0
			_react(dog)
			return
	else:
		_aim_time = 0.0
	dog.input.virtual_move = _steer(dog, direction, delta) * 0.82
	_react(dog)


func _nearest_rival(dog: Dog) -> Dog:
	var nearest: Dog = null
	var best := INF
	for candidate in get_tree().get_nodes_in_group("dogs"):
		if candidate == dog or not candidate.alive:
			continue
		var distance := dog.global_position.distance_squared_to(candidate.global_position)
		if distance < best:
			best = distance
			nearest = candidate
	return nearest


func _nearest_toy(dog: Dog, lethal_only: bool = false) -> Toy:
	var nearest: Toy = null
	var best := INF
	for candidate in get_tree().get_nodes_in_group("toys"):
		if candidate.state != Toy.State.IDLE or (lethal_only and candidate.data.special == ToyData.Special.KNOCKBACK):
			continue
		var distance := dog.global_position.distance_squared_to(candidate.global_position)
		if distance < best:
			best = distance
			nearest = candidate
	return nearest


func _clear_path(dog: Dog, target: Vector3) -> bool:
	var from := dog.global_position + Vector3(0, 0.7, 0)
	var to := Vector3(target.x, 0.7, target.z)
	return dog.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(from, to, 1)).is_empty()


func _steer(dog: Dog, direction: Vector2, delta: float) -> Vector2:
	var moved := dog.global_position.distance_to(_last_position)
	_last_position = dog.global_position
	_stuck_time = _stuck_time + delta if moved < 0.02 else 0.0
	if _stuck_time > 0.3:
		_stuck_time = 0.0
		_detour = direction.orthogonal() * (1.0 if randf() > 0.5 else -1.0)
		_detour_time = 0.75
	if _detour_time > 0.0:
		_detour_time -= delta
		direction = _detour
	# Cast ahead of the collision body; prefer the smallest clear sidestep.
	for angle in [0.0, 0.65, -0.65, 1.2, -1.2, 1.8, -1.8, PI]:
		var candidate := direction.rotated(angle)
		var ahead := dog.global_position + Vector3(candidate.x, 0, candidate.y) * (dog.data.body_radius + 1.1)
		if _clear_path(dog, ahead):
			return candidate
	return -direction


func _react(dog: Dog) -> void:
	if _reaction_wait > 0.0:
		return
	for toy in get_tree().get_nodes_in_group("toys"):
		if not toy.is_dangerous() or not toy.can_be_caught_by(dog):
			continue
		var to_dog: Vector3 = dog.global_position - toy.global_position
		to_dog.y = 0.0
		var heading: Vector3 = toy.velocity.normalized()
		var along := to_dog.dot(heading)
		if along <= 0.0 or along > toy.velocity.length() * 0.28:
			continue
		if (to_dog - heading * along).length() > dog.data.body_radius + toy.data.radius:
			continue
		_reaction_wait = randf_range(0.7, 1.3)
		if randf() < 0.45:
			return
		if dog.held_toy == null:
			dog.input.virtual_buttons[&"throw"] = true
		else:
			dog.input.virtual_move = Vector2(-heading.z, heading.x)
			dog.input.virtual_buttons[&"dash"] = true
		return


func _nearby_treat(dog: Dog) -> Powerup:
	var nearest: Powerup
	var best := 36.0
	for node in get_tree().get_nodes_in_group("powerups"):
		var treat := node as Powerup
		if treat.is_queued_for_deletion() or treat.age < 0.65:
			continue
		# Crates are a mystery, so there is nothing to be picky about: a full belt is the
		# only reason to ignore one.
		if dog.slot != null and dog.slot.powerups.size() >= PowerupKinds.MAX_SLOTS:
			continue
		var distance := dog.global_position.distance_squared_to(treat.global_position)
		if distance < best and _clear_path(dog, treat.global_position):
			best = distance
			nearest = treat
	return nearest
