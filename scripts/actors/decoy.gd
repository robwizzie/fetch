class_name Decoy
extends CharacterBody3D
## Good Boy Decoy: a second you, running around on its own, so nobody is sure which one to
## throw at. It looks exactly like the dog it copies - hat or crown, ring, name tag, shield
## glow - and acts like it: it roams at the same pace, dashes now and then, holds a toy when
## you hold one and goes through the motions of a throw when you throw.
##
## It cannot hurt anyone, carries nothing real and does not count as a dog in the round. A
## dangerous toy that reaches it pops it; so does its dog going out. One per round while the
## power is on the belt (see Dog._maybe_send_decoy).

const DASH_EVERY := Vector2(2.2, 4.5)
const DASH_TIME := 0.22
## How long it may chase one spot before giving up on it and picking another.
const LEG_TIME := Vector2(1.6, 3.2)

var dog: Dog
var _model: DogModel
var _popped := false
var _route: PackedVector3Array = []
var _leg := 0.0
var _dash_in := 2.0
var _dash_left := 0.0
var _idle := 0.0
var _facing := Vector3(0, 0, -1)
var _fake_holder: Node3D
var _fake_toy_id: StringName = &""
var _halo: MeshInstance3D
var _bubble: MeshInstance3D
var _rng := RandomNumberGenerator.new()


func setup(p_dog: Dog) -> void:
	dog = p_dog


func _ready() -> void:
	add_to_group("decoys")
	add_to_group("combat_effects")
	_rng.randomize()
	# Bumps into the arena like a dog, but nothing bumps into it: layer 0, world mask.
	collision_layer = 0
	collision_mask = 1
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	var body := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = dog.data.body_radius
	capsule.height = dog.data.body_radius * 2.0 + 0.6
	body.shape = capsule
	body.position.y = capsule.height * 0.5
	add_child(body)
	_model = DogModel.new()
	add_child(_model)
	_model.setup(dog.data, dog.slot.color)
	_model.set_hat(Game.hat(dog.slot.hat))
	_model.quaternion = dog.model.quaternion
	_facing = dog.facing
	# Everything that tells dogs apart on the field, copied from the real one.
	var ring := MeshInstance3D.new()
	ring.mesh = dog.ring.mesh
	ring.material_override = dog.ring.material_override
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ring.position = dog.ring.position
	add_child(ring)
	var tag := dog.name_tag.duplicate(0) as Label3D
	add_child(tag)
	_halo = _copy_mesh(dog.get("_powerup_halo"))
	_bubble = _copy_mesh(dog.get("_shield_bubble"))
	Mats.contact_shadow(self, dog.data.body_radius * 0.85)
	_dash_in = _rng.randf_range(DASH_EVERY.x, DASH_EVERY.y)
	# Straight off and away: two dogs standing together would give the game away.
	_next_leg(true)


func _copy_mesh(source: MeshInstance3D) -> MeshInstance3D:
	if source == null:
		return null
	var copy := source.duplicate(0) as MeshInstance3D
	add_child(copy)
	return copy


func _physics_process(delta: float) -> void:
	if _popped:
		return
	if not is_instance_valid(dog) or not dog.alive or dog.round_locked:
		poof()
		return
	_roam(delta)
	_mimic()
	_check_hits()


## Off to somewhere, along the bots' routes so it goes round furniture rather than into it.
func _roam(delta: float) -> void:
	_leg -= delta
	_dash_in -= delta
	_dash_left = maxf(0.0, _dash_left - delta)
	if _idle > 0.0:
		_idle -= delta
		velocity = velocity.move_toward(Vector3.ZERO, 40.0 * delta)
	else:
		while not _route.is_empty() and _flat(_route[0] - global_position).length() < 0.6:
			_route.remove_at(0)
		if _route.is_empty() or _leg <= 0.0:
			_next_leg()
		if not _route.is_empty():
			var to := _flat(_route[0] - global_position).normalized()
			var speed := dog.data.move_speed * float(dog.get("_speed_mult"))
			if _dash_in <= 0.0:
				_dash_in = _rng.randf_range(DASH_EVERY.x, DASH_EVERY.y)
				_dash_left = DASH_TIME
				_model.set_dashing(true)
			if _dash_left > 0.0:
				speed = dog.data.dash_distance / DASH_TIME
			elif _model != null:
				_model.set_dashing(false)
			velocity = velocity.move_toward(to * speed, 47.0 * delta)
	move_and_slide()
	global_position.y = 0.0
	var flat := _flat(velocity)
	if flat.length() > 0.3:
		_facing = flat.normalized()
	_model.update_motion(_facing, flat.length() / maxf(dog.data.move_speed, 0.1), delta)


## Either near a rival - the way a player would hunt - or anywhere open. Sometimes it stops
## for a beat, as players do.
func _next_leg(first: bool = false) -> void:
	_leg = _rng.randf_range(LEG_TIME.x, LEG_TIME.y)
	if not first and _rng.randf() < 0.18:
		_idle = _rng.randf_range(0.3, 0.8)
	var offset := Vector3(_rng.randf_range(-7.0, 7.0), 0.0, _rng.randf_range(-5.0, 5.0))
	if first and offset.length() < 3.0:
		offset = (offset if offset.length() > 0.1 else Vector3.RIGHT).normalized() * 3.5
	var target := global_position + offset
	var rivals := get_tree().get_nodes_in_group("dogs").filter(func(node: Node) -> bool:
		return node is Dog and node != dog and (node as Dog).alive and not (node as Dog).slot.allied_with(dog.slot))
	if not first and not rivals.is_empty() and _rng.randf() < 0.5:
		var rival := rivals[_rng.randi() % rivals.size()] as Dog
		target = rival.global_position + Vector3(_rng.randf_range(-4.0, 4.0), 0.0, _rng.randf_range(-4.0, 4.0))
	var arenas := get_tree().get_nodes_in_group("arenas")
	if not arenas.is_empty():
		var arena := arenas.back() as Arena
		var half := arena.size * 0.5
		target = Vector3(clampf(target.x, -half.x + 1.0, half.x - 1.0), 0.0, clampf(target.z, -half.y + 1.0, half.y - 1.0))
		target = arena.clear_pickup_position(target, dog.data.body_radius + 0.2)
		var navigation := arena.get_node_or_null("BotNavigation") as BotNavigation
		if navigation != null:
			_route = navigation.route(global_position, target)
			_route.append(target)
			return
	_route = PackedVector3Array([target])


## Shows what its dog is showing: a crown, a shield, a toy in the mouth - and a throw when its
## dog throws.
func _mimic() -> void:
	if dog.model.is_crowned() != _model.is_crowned():
		_model.set_crown(dog.model.is_crowned())
	var shielded := dog.shield_charges > 0
	if _halo != null:
		_halo.visible = shielded
		_halo.scale = Vector3.ONE * (1.0 + sin(Time.get_ticks_msec() * 0.006) * 0.055)
	if _bubble != null:
		_bubble.visible = shielded
		_bubble.scale = (dog.get("_shield_bubble") as MeshInstance3D).scale
	var held := dog.held_toy.data.id if is_instance_valid(dog.held_toy) else &""
	if held != _fake_toy_id:
		if _fake_toy_id != &"" and held == &"":
			# Its dog let go: a throw, as far as anyone watching can tell.
			_model.play_throw()
		_fake_toy_id = held
		if is_instance_valid(_fake_holder):
			_fake_holder.queue_free()
		_fake_holder = null
		if held != &"":
			# Held the way Toy holds itself: the body on the mouth socket, the model posed in it.
			_fake_holder = Node3D.new()
			add_child(_fake_holder)
			var fake := ToyModel.new()
			fake.setup(dog.held_toy.data)
			fake.rotation_degrees = dog.held_toy.data.held_rotation
			fake.scale = Vector3.ONE * dog.held_toy.data.held_scale
			_fake_holder.add_child(fake)
	if is_instance_valid(_fake_holder):
		var socket := _model.get_mouth_transform()
		_fake_holder.global_transform = Transform3D(socket.basis.orthonormalized(), socket.origin)


## Any dangerous toy that is not its own dog's reaching it pops it.
func _check_hits() -> void:
	for node in get_tree().get_nodes_in_group("toys"):
		var toy := node as Toy
		if toy == null or not toy.is_dangerous() or toy.thrower == dog:
			continue
		var gap := _flat(toy.global_position - global_position)
		if gap.length() < dog.data.body_radius + toy.data.radius:
			poof()
			return


func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)


## Gone in a puff: the tell that it was never the real dog.
func poof() -> void:
	if _popped:
		return
	_popped = true
	remove_from_group("decoys")
	var color := dog.slot.color if is_instance_valid(dog) else Color.WHITE
	Juice.burst(get_parent(), global_position + Vector3.UP * 0.6, Color(1, 1, 1, 0.85), 14, 3.5)
	Juice.burst(get_parent(), global_position + Vector3.UP * 0.6, color, 10, 2.5)
	Juice.float_text(get_parent(), global_position + Vector3.UP * 1.5, "POOF! DECOY", Color(0.9, 0.93, 1.0), 0.6)
	Sfx.play_at("squeak", global_position, 1.6, -8.0)
	queue_free()
