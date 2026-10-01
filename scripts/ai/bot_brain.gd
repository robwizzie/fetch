class_name BotBrain
extends Node
## Readable practice opponent: fetch loose toys, aim before throwing, and react to danger.
## Steering uses the same obstacle collisions as players and never teleports the dog.

var _attack_wait := 0.8
var _aim_time := 0.0
## Wind-up in progress: how long this bot means to hold throw, and how long it has. Negative
## goal means it is not winding anything up.
var _charge_goal := -1.0
var _charge_held := 0.0
var _reaction_wait := 0.0
var _stuck_time := 0.0
var _detour_time := 0.0
var _detour := Vector2.ZERO
var _last_position := Vector3.ZERO
var _navigation: BotNavigation
var _route := PackedVector3Array()
var _route_goal := Vector3.INF
var _route_clock := 0.0
var _rng := RandomNumberGenerator.new()
## Set while the route runs through a wall doorway: head straight into it, no sidestepping.
var _portal_entry: Portal
## The rival this bot is committed to. Straight-line nearest ignores walls, so re-picking every
## frame made a bot flip targets the moment a doorway carried it across the yard - and walk
## straight back through the door after the other one, forever.
var _target: Dog
var _target_time := 0.0
const TARGET_COMMIT := 3.0
const HIDDEN_NOTICE := 3.0
## How often a bot takes the bait when a rival's decoy is nearer than the rival. Decided once
## per decoy, so a bot does not flicker between the two.
const DECOY_BELIEF := 0.65
var _decoy_verdicts: Dictionary = {}


func _ready() -> void:
	_rng.seed = 9137 + (get_parent() as Dog).slot.index * 127
	_attack_wait = _rng.randf_range(0.5, 1.3)
	_last_position = (get_parent() as Dog).global_position
	# Supply input before the dog consumes it in the same physics frame.
	process_physics_priority = -10
	var arenas := get_tree().get_nodes_in_group("arenas")
	if not arenas.is_empty():
		var arena := arenas.back() as Arena
		_navigation = arena.get_node_or_null("BotNavigation") as BotNavigation
		if _navigation == null:
			_navigation = BotNavigation.new()
			_navigation.name = "BotNavigation"
			arena.add_child(_navigation)


func _physics_process(delta: float) -> void:
	var dog := get_parent() as Dog
	if dog == null or not dog.alive or dog.round_locked:
		return
	dog.input.virtual_buttons[&"throw"] = false
	dog.input.virtual_buttons[&"dash"] = false
	_attack_wait -= delta
	_reaction_wait -= delta
	_route_clock -= delta
	_target_time -= delta
	var rival := _committed_rival(dog)
	# A squeaking toy about to burst: grab it if it is right here, otherwise get clear. A side
	# toy can never be picked up, so that one is always a run.
	var fused := _armed_blast_near(dog)
	if fused != null:
		var away := Vector2(dog.global_position.x - fused.global_position.x, dog.global_position.z - fused.global_position.z)
		if away.length() > dog.effective_radius() + fused.data.radius + 0.6 or dog.held_toy != null or fused.ephemeral:
			dog.input.virtual_move = _steer(dog, away.normalized(), delta)
			return
	if rival == null:
		_search(dog, delta)
		return
	var aim_at := _aim_point(dog, rival)
	var goal := aim_at
	if dog.held_toy == null:
		_aim_time = 0.0
		_charge_goal = -1.0
		var loose := _nearest_toy(dog)
		if loose:
			goal = loose.global_position
	# A nearby treat is worth a short detour; avoid repeatedly seeking an active buff.
	var treat := _nearby_treat(dog)
	if treat:
		dog.input.virtual_move = _move_along_route(dog, treat.global_position, delta) * 0.9
		_react(dog)
		return
	# The mode may want the bot somewhere (King of the Bed): holding a toy it goes there unless a
	# shot is on; empty-pawed it goes there when that is nearer than the next toy.
	var mode_goal := GameMode.current.bot_goal(dog) if GameMode.current != null else Vector3.INF
	if mode_goal != Vector3.INF:
		if dog.held_toy != null or goal == aim_at or dog.global_position.distance_to(mode_goal) < dog.global_position.distance_to(goal):
			goal = mode_goal
	var direction := Vector2(aim_at.x - dog.global_position.x, aim_at.z - dog.global_position.z)
	var distance := direction.length()
	direction = direction.normalized()
	# Hot Potato: a bone about to pop goes to anyone, at any range worth a throw.
	var urgent := dog.held_toy != null and GameMode.current != null and GameMode.current.bot_should_throw_now(dog, dog.held_toy)
	if urgent:
		_attack_wait = minf(_attack_wait, 0.0)
	var keeps := dog.held_toy != null and GameMode.current != null and GameMode.current.bot_keeps(dog, dog.held_toy)
	if dog.held_toy and not keeps and distance < (16.0 if urgent else 11.0) and _clear_path(dog, aim_at):
		if _attack_wait <= 0.0:
			# Briefly face the opponent before releasing. Players get a visible tell.
			_aim_time += delta
			dog.input.virtual_move = direction * 0.02
			if _aim_time >= 0.24:
				# Bots wind up as well, so the charge is something you read across the table
				# rather than a move only the players in front of a keyboard have.
				if _charge_goal < 0.0:
					# Wind up for the range and no further: holding longer than the shot needs
					# only leaves the bot planted and slow. The slop keeps four bots from all
					# looking like one player, and the floor guarantees at least one frame with
					# the button down, which is what the dog reads as a press at all.
					var needed := _charge_for(dog, distance) + _rng.randf_range(-0.05, 0.3)
					_charge_goal = clampf(needed, 0.06, 1.05) * Dog.CHARGE_TIME
					_charge_held = 0.0
				if _charge_held < _charge_goal:
					_charge_held += delta
					dog.input.virtual_buttons[&"throw"] = true
				else:
					# Leaving the button up this frame is what throws it.
					_attack_wait = _rng.randf_range(0.9, 1.6)
					_aim_time = 0.0
					_charge_goal = -1.0
			_react(dog)
			return
	else:
		_aim_time = 0.0
		_charge_goal = -1.0
	dog.input.virtual_move = _move_along_route(dog, goal, delta) * 0.92
	_react(dog)


## Nobody in sight (every rival hidden in grass or ghosted): no shot to line up, but a bot
## standing still is a free target. Arm up, take treats, chase the mode's goal, and drift to the
## middle where a hiding dog is most likely to be flushed out.
func _search(dog: Dog, delta: float) -> void:
	_aim_time = 0.0
	_charge_goal = -1.0
	var goal := Vector3.ZERO
	if dog.held_toy == null:
		var loose := _nearest_toy(dog)
		if loose:
			goal = loose.global_position
	var treat := _nearby_treat(dog)
	if treat:
		goal = treat.global_position
	var mode_goal := GameMode.current.bot_goal(dog) if GameMode.current != null else Vector3.INF
	if mode_goal != Vector3.INF and (goal == Vector3.ZERO or dog.global_position.distance_to(mode_goal) < dog.global_position.distance_to(goal)):
		goal = mode_goal
	var flat := Vector2(goal.x - dog.global_position.x, goal.z - dog.global_position.z)
	dog.input.virtual_move = _move_along_route(dog, goal, delta) * 0.92 if flat.length() > 1.0 else Vector2.ZERO
	_react(dog)


## How much wind-up this shot needs to still be dangerous when it lands, worked out from the
## held toy's own flight numbers. A tap is a short lob, so a bot has to know the difference
## between a shove in the face and a shot from across the park.
func _charge_for(dog: Dog, distance: float) -> float:
	if not is_instance_valid(dog.held_toy):
		return 0.0
	var toy: ToyData = dog.held_toy.data
	var base := toy.throw_speed * dog.data.throw_power
	if base <= 0.0:
		return 1.0
	# Margin for a target that keeps moving and for a throw that is led badly.
	var reach := distance * 1.5 + 2.0
	var needed := sqrt(2.0 * toy.friction * reach + toy.danger_speed * toy.danger_speed)
	return (needed / base - Dog.TAP_POWER) / (Dog.FULL_POWER - Dog.TAP_POWER)


## Where to throw: the rival, unless a decoy of theirs is nearer and this bot believes it.
func _aim_point(dog: Dog, rival: Dog) -> Vector3:
	var best := rival.global_position
	var best_distance := dog.global_position.distance_to(best)
	for node in get_tree().get_nodes_in_group("decoys"):
		var decoy := node as Decoy
		if decoy == null or not is_instance_valid(decoy.dog) or decoy.dog == dog or dog.slot.allied_with(decoy.dog.slot):
			continue
		var key := decoy.get_instance_id()
		if not _decoy_verdicts.has(key):
			_decoy_verdicts[key] = _rng.randf() < DECOY_BELIEF
		if not _decoy_verdicts[key]:
			continue
		var distance := dog.global_position.distance_to(decoy.global_position)
		if distance < best_distance:
			best = decoy.global_position
			best_distance = distance
	return best


func _committed_rival(dog: Dog) -> Dog:
	var valid := is_instance_valid(_target) and _target.alive and not dog.slot.allied_with(_target.slot)
	if valid and _target_time > 0.0:
		return _target
	var nearest := _nearest_rival(dog)
	if nearest != _target:
		_target = nearest
		_target_time = TARGET_COMMIT
	elif valid:
		_target_time = TARGET_COMMIT * 0.5
	return _target


func _nearest_rival(dog: Dog) -> Dog:
	var nearest: Dog = null
	var best := INF
	for candidate in get_tree().get_nodes_in_group("dogs"):
		if candidate == dog or not candidate.alive or dog.slot.allied_with(candidate.slot):
			continue
		var distance := dog.global_position.distance_squared_to(candidate.global_position)
		# A rival hiding in tall grass is only noticed up close, same as a person would.
		if candidate.concealed and distance > HIDDEN_NOTICE * HIDDEN_NOTICE:
			continue
		if distance < best:
			best = distance
			nearest = candidate
	return nearest


func _nearest_toy(dog: Dog) -> Toy:
	var nearest: Toy = null
	var best := INF
	for candidate in get_tree().get_nodes_in_group("toys"):
		if candidate.state != Toy.State.IDLE or candidate.ephemeral:
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
		_detour = direction.orthogonal() * (1.0 if _rng.randf() > 0.5 else -1.0)
		_detour_time = 0.3
		_route_clock = 0.0
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
		if (to_dog - heading * along).length() > dog.effective_radius() + toy.data.radius:
			continue
		_reaction_wait = _rng.randf_range(0.7, 1.3)
		if _rng.randf() < 0.45:
			return
		if dog.held_toy == null:
			dog.input.virtual_buttons[&"throw"] = true
		else:
			dog.input.virtual_move = Vector2(-heading.z, heading.x)
			dog.input.virtual_buttons[&"dash"] = true
		return


func _armed_blast_near(dog: Dog) -> Toy:
	for node in get_tree().get_nodes_in_group("toys"):
		var toy := node as Toy
		if toy.power_effects == null or toy.power_effects.fuse_left < 0.0:
			continue
		if not CombatRules.can_hurt(toy.thrower, dog):
			continue
		var gap := Vector2(toy.global_position.x - dog.global_position.x, toy.global_position.z - dog.global_position.z)
		if gap.length() < ToyPowerEffects.BLAST_RADIUS + dog.effective_radius() + 0.5:
			return toy
	return null


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


func _move_along_route(dog: Dog, goal: Vector3, delta: float) -> Vector2:
	var direction := _route_direction(dog, goal)
	# The wall ahead is the point when walking into a doorway; the sidestep would dodge it.
	return direction if _portal_entry != null else _steer(dog, direction, delta)


## Replan after teleports and as moving targets change cells. Never skip a wall or portal edge.
func _route_direction(dog: Dog, goal: Vector3) -> Vector2:
	_portal_entry = null
	var direct := Vector2(goal.x - dog.global_position.x, goal.z - dog.global_position.z)
	if not is_instance_valid(_navigation) or _walk_clear(dog, goal):
		return direct.normalized()
	if _route_clock <= 0.0 or _route_goal.distance_to(goal) > 1.5 or (_route.size() > 0 and dog.global_position.distance_to(_route[0]) > 3.0):
		_route = _navigation.route(dog.global_position, goal)
		_route_goal = goal
		_route_clock = 0.6
	while _route.size() > 1 and Vector2(_route[0].x - dog.global_position.x, _route[0].z - dog.global_position.z).length() < 0.55:
		# Keep a doorway's waypoint until the portal has actually taken the dog.
		if _route[0].distance_to(_route[1]) > BotNavigation.CELL * 3.0:
			break
		_route.remove_at(0)
	if _route.is_empty():
		return direct.normalized()
	# A long hop between neighbouring route points is a portal link: go through the doorway.
	if _route.size() > 1 and _route[0].distance_to(_route[1]) > BotNavigation.CELL * 3.0:
		var doorway := _navigation.portal_near(_route[0])
		if doorway != null:
			var local := doorway.global_position - dog.global_position
			if Vector2(local.x, local.z).length() < doorway.radius + dog.effective_radius() + 1.2:
				_portal_entry = doorway
				var into := -doorway.normal()
				# Aim through the middle of the doorway so the dog does not graze a pillar.
				var aim := Vector2(local.x, local.z) + Vector2(into.x, into.z) * 1.5
				return aim.normalized()
	var target := _route[0]
	return Vector2(target.x - dog.global_position.x, target.z - dog.global_position.z).normalized()


func _walk_clear(dog: Dog, target: Vector3) -> bool:
	var shape := SphereShape3D.new()
	shape.radius = dog.effective_radius() + 0.07
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = Transform3D(Basis.IDENTITY, dog.global_position + Vector3.UP * 0.9)
	query.motion = Vector3(target.x - dog.global_position.x, 0, target.z - dog.global_position.z)
	query.collision_mask = 1
	return dog.get_world_3d().direct_space_state.cast_motion(query)[0] >= 0.99
