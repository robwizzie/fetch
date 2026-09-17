class_name Dog
extends CharacterBody3D
## One playable dog. Reads a DeviceInput, moves on the XZ plane, dashes (with i-frames),
## throws, catches. Hits are decided by Toy.gd calling [method hit_by].

signal eliminated(dog: Dog)

enum State { ALIVE, ELIMINATED }

const ACCEL := 47.0
const DASH_TIME := 0.22
## Invincibility covers the burst but not the recovery, so a dash is an escape, not a shield.
const DASH_IFRAMES := 0.14
const SPAWN_GRACE := 1.1
## Close-quarters swipe for a dog with nothing in its mouth.
const WHACK_RANGE := 1.55
const WHACK_COOLDOWN := 0.6
const DIZZY_TIME := 1.5

var slot: PlayerSlot
var data: DogData
var input: DeviceInput
var state := State.ALIVE
var facing := Vector3(0, 0, -1)
var held_toy: Toy = null
var _aim_marker: MeshInstance3D
var invincible := false
## Locks gameplay immediately while end-of-round collision changes are deferred.
var round_locked := false
## Set by zones (e.g. the pool) to slow the dog down.
var speed_scale := 1.0
var shield_charges := 0
var _powerup_halo: MeshInstance3D
## Stacked multipliers rebuilt from the slot's power-ups when the dog spawns.
var _speed_mult := 1.0
var _catch_mult := 1.0
var _throw_mult := 1.0
var _dash_mult := 1.0
var _cooldown_mult := 1.0

var _dash_timer := 0.0
var _iframe_timer := 0.0
var _dash_cooldown := 0.0
var _spawn_grace := SPAWN_GRACE
## While > 0 an incoming hit becomes a catch (set by a catch press, see DogData.catch_window).
var _catch_buffer := 0.0
var _catch_cooldown := 0.0
var _pickup_lock := 0.0
var _stagger_time := 0.0
var _whack_cooldown := 0.0
## While > 0 the dog is seeing stars: no input, no actions.
var dizzy_time := 0.0
## Set during the practice round: the dog can throw, catch and whack, but nothing can put it
## out. Learning which button throws should never cost you a knockout.
var practice_safe := false
var _weapon_impulse := Vector3.ZERO

@onready var body_shape: CollisionShape3D = $Body
@onready var model: DogModel = $Model
@onready var catch_area: Area3D = $CatchArea
@onready var catch_shape: CollisionShape3D = $CatchArea/Shape
@onready var name_tag: Label3D = $NameTag
@onready var ring: MeshInstance3D = $Ring


var alive: bool:
	get:
		return state == State.ALIVE


## Must be called before adding to the tree.
func setup(p_slot: PlayerSlot) -> void:
	slot = p_slot
	data = slot.dog
	input = DeviceInput.new(DeviceInput.VIRTUAL if slot.is_bot else slot.device)
	apply_powerups()


func _ready() -> void:
	add_to_group("dogs")
	var body := CapsuleShape3D.new()
	body.radius = data.body_radius
	body.height = data.body_radius * 2.0 + 0.6
	body_shape.shape = body
	body_shape.position.y = body.height / 2.0
	var catch := SphereShape3D.new()
	catch.radius = data.catch_radius * _catch_mult
	catch_shape.shape = catch
	catch_shape.position.y = 0.5
	model.setup(data, slot.color)
	name_tag.text = "%s · %s" % [slot.label, data.display_name.to_upper()]
	name_tag.font = UiKit.FONT_DISPLAY
	name_tag.modulate = slot.color
	name_tag.position.y = 1.55 * data.model_scale + 0.35
	ring.mesh = Mats.torus(data.body_radius + 0.12, data.body_radius + 0.28)
	ring.material_override = Mats.unlit(slot.color)
	_build_aim_marker()
	_powerup_halo = Mats.mesh(self, Mats.torus(data.body_radius + 0.37, data.body_radius + 0.43), Color.WHITE, Vector3(0, 0.055, 0))
	_powerup_halo.material_override = Mats.unlit(Color(1.0, 0.88, 0.4))
	_powerup_halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_powerup_halo.visible = false
	Juice.pop(model, 1.5, 0.35)


func _physics_process(delta: float) -> void:
	if state != State.ALIVE or round_locked:
		return
	_powerup_halo.visible = shield_charges > 0
	_powerup_halo.scale = Vector3.ONE * (1.0 + sin(Time.get_ticks_msec() * 0.006) * 0.055)
	_spawn_grace = maxf(0.0, _spawn_grace - delta)
	_pickup_lock = maxf(0.0, _pickup_lock - delta)
	_stagger_time = maxf(0.0, _stagger_time - delta)
	_whack_cooldown = maxf(0.0, _whack_cooldown - delta)
	if dizzy_time > 0.0:
		dizzy_time = maxf(0.0, dizzy_time - delta)
		if dizzy_time <= 0.0 and model.has_method("set_dizzy"):
			model.call("set_dizzy", false)
	_weapon_impulse = _weapon_impulse.move_toward(Vector3.ZERO, 20.0 * delta)
	_dash_cooldown = maxf(0.0, _dash_cooldown - delta)
	_catch_cooldown = maxf(0.0, _catch_cooldown - delta)
	if _catch_buffer > 0.0:
		_catch_buffer -= delta
		if _catch_buffer <= 0.0:
			_catch_cooldown = data.catch_cooldown
			model.set_catching(false)

	var move2 := input.move_vector()
	if dizzy_time > 0.0:
		# Stumbling: the dog drifts where it was already going, not where you point.
		move2 = Vector2(facing.x, facing.z) * 0.25
	var move := Vector3(move2.x, 0.0, move2.y)
	if move != Vector3.ZERO and dizzy_time <= 0.0:
		facing = move.normalized()

	if _iframe_timer > 0.0:
		_iframe_timer -= delta
		if _iframe_timer <= 0.0:
			invincible = false
	if _dash_timer > 0.0:
		_dash_timer -= delta
		if _dash_timer <= 0.0:
			model.set_dashing(false)
	else:
		var stagger_scale := 0.55 if _stagger_time > 0.0 else 1.0
		velocity = velocity.move_toward(move * data.move_speed * speed_scale * stagger_scale * _speed_mult + _weapon_impulse, ACCEL * delta)
		if input.just_pressed(&"dash") and _dash_cooldown <= 0.0 and dizzy_time <= 0.0:
			_start_dash()

	if input.just_pressed(&"throw") and dizzy_time <= 0.0:
		_throw_or_catch()

	velocity.y = 0.0
	move_and_slide()
	global_position.y = 0.0
	model.update_motion(facing, velocity.length() / data.move_speed, delta)
	_aim_marker.position = facing * (data.body_radius + 0.62) + Vector3(0, 0.04, 0)
	_aim_marker.rotation.y = atan2(-facing.x, -facing.z)
	_aim_marker.visible = held_toy != null
	ring.scale = Vector3.ONE * (1.08 if _catch_buffer > 0.0 else 1.0)
	if held_toy:
		held_toy.global_position = get_hold_position()


func get_hold_transform() -> Transform3D:
	if model.has_method("get_mouth_transform"):
		var socket: Transform3D = model.call("get_mouth_transform")
		socket.basis = socket.basis.orthonormalized()
		return socket
	return Transform3D(Basis.looking_at(facing, Vector3.UP), global_position + facing * (data.body_radius + 0.24) + Vector3(0, 0.7, 0))


func get_hold_position() -> Vector3:
	return get_hold_transform().origin


# ---------------------------------------------------------------- actions

func _start_dash() -> void:
	_dash_timer = DASH_TIME
	_iframe_timer = DASH_IFRAMES
	_dash_cooldown = data.dash_cooldown * _cooldown_mult
	velocity = facing * (data.dash_distance * _dash_mult / DASH_TIME)
	invincible = true
	model.set_dashing(true)
	Sfx.play("dash", randf_range(0.9, 1.1))
	Juice.burst(get_parent(), global_position - facing * 0.3 + Vector3(0, 0.3, 0), Color(1, 1, 1, 0.7), 8, 3.0)


func _throw_or_catch() -> void:
	if held_toy:
		_throw()
		return
	var target := _whack_target()
	if target != null:
		_whack(target)
		return
	if _catch_cooldown > 0.0 or _catch_buffer > 0.0:
		return
	var toy := _find_catchable_toy()
	if toy:
		_catch(toy)
		return
	# Arm the catch window: a toy that reaches us in the next catch_window seconds is caught.
	_catch_buffer = data.catch_window * _catch_mult
	model.set_catching(true)


func _throw() -> void:
	if not is_instance_valid(held_toy) or not alive or round_locked:
		return
	var toy := held_toy
	held_toy = null
	toy.throw(self, facing, data.throw_power * _throw_mult)
	if model.has_method("play_throw"):
		model.call("play_throw")
	else:
		model.squash()
	Sfx.play("throw", randf_range(0.95, 1.1))
	Events.toy_thrown.emit(toy, self)


## The nearest rival a bare-pawed dog can reach. Nothing in range means the press falls
## through to the catch window instead.
func _whack_target() -> Dog:
	if _whack_cooldown > 0.0 or not alive or round_locked:
		return null
	var best: Dog = null
	var best_distance := WHACK_RANGE
	for node in get_tree().get_nodes_in_group("dogs"):
		var other := node as Dog
		if other == self or not other.alive or other.round_locked:
			continue
		var offset := other.global_position - global_position
		offset.y = 0.0
		var distance := offset.length()
		if distance > best_distance:
			continue
		# Only what the dog is roughly facing: no blind swipes behind you.
		if facing.dot(offset.normalized()) < 0.15:
			continue
		best = other
		best_distance = distance
	return best


func _whack(target: Dog) -> void:
	_whack_cooldown = WHACK_COOLDOWN
	model.squash()
	if model.has_method("play_throw"):
		model.call("play_throw")
	var away := target.global_position - global_position
	away.y = 0.0
	target.receive_whack(away.normalized(), self)
	Sfx.play("bounce", randf_range(1.25, 1.45), -3.0)
	Juice.burst(get_parent(), global_position + facing * 0.6 + Vector3.UP * 0.6, slot.color.lightened(0.3), 10, 3.2)


## Taking a swipe: a dog holding something loses it, an empty-pawed one sees stars.
func receive_whack(direction: Vector3, from: Dog) -> void:
	if not alive or round_locked or invincible or _spawn_grace > 0.0 or practice_safe:
		return
	if is_instance_valid(held_toy):
		var dropped := held_toy
		held_toy = null
		dropped.drop(global_position)
		dropped.velocity = direction * 5.0
		_pickup_lock = 0.7
		_weapon_impulse = direction * 7.0
		_stagger_time = maxf(_stagger_time, 0.35)
		Sfx.play("squeak", randf_range(0.8, 0.95), -6.0)
		Juice.float_text(get_parent(), global_position + Vector3.UP * 1.6, "DROPPED!", UiKit.CREAM, 0.6)
	else:
		dizzy_time = DIZZY_TIME
		_catch_buffer = 0.0
		_weapon_impulse = direction * 5.0
		if model.has_method("set_dizzy"):
			model.call("set_dizzy", true)
		Sfx.play("bark", randf_range(0.8, 0.92), -5.0)
		Juice.float_text(get_parent(), global_position + Vector3.UP * 1.7, "DIZZY!", Color(1.0, 0.88, 0.4), 0.8)
	model.squash()
	Juice.shake(0.12)
	Events.dog_whacked.emit(self, from)


func _find_catchable_toy() -> Toy:
	var best: Toy = null
	var best_d := INF
	for body in catch_area.get_overlapping_bodies():
		if body is Toy and body.is_dangerous() and body.can_be_caught_by(self):
			var d := global_position.distance_squared_to(body.global_position)
			if d < best_d:
				best = body
				best_d = d
	return best


func _catch(toy: Toy) -> void:
	_catch_buffer = 0.0
	model.set_catching(false)
	toy.pick_up(self)
	Sfx.play("catch")
	Juice.pop(model, 1.3)
	Juice.float_text(get_parent(), global_position + Vector3(0, 1.6, 0), "CATCH!", slot.color, 0.7)
	Events.toy_caught.emit(toy, self)


## Called by an idle toy the dog walks over.
func try_pickup(toy: Toy) -> bool:
	if held_toy != null or not alive or round_locked or _pickup_lock > 0.0:
		return false
	if toy.state != Toy.State.IDLE:
		return false
	toy.pick_up(self)
	Sfx.play("pickup", randf_range(0.9, 1.2), -6.0)
	Juice.pop(model, 1.12, 0.12)
	return true


## Called by a flying toy. Returns true if the hit landed.
## True when this toy is allowed to put this dog out, given who threw it. A toy that cannot
## hurt you still bounces off - it just does not eliminate.
func can_be_hurt_by(toy: Toy) -> bool:
	var attacker: Dog = toy.thrower
	if attacker == null or not is_instance_valid(attacker) or attacker.slot == null or slot == null:
		return true
	if attacker == self:
		return Game.self_fire
	if slot.allied_with(attacker.slot):
		return Game.friendly_fire
	return true


func hit_by(toy: Toy) -> bool:
	if not alive or round_locked or invincible or _spawn_grace > 0.0 or not toy.is_dangerous():
		return false
	if not can_be_hurt_by(toy):
		# Reads as a hit so the throw is not silently ignored, but nobody goes out.
		toy.deflect_from(self)
		Sfx.play("bounce", 0.95, -6.0)
		return false
	if practice_safe:
		# Still reads as a hit so a catch can be practised, but never eliminates.
		if _catch_buffer > 0.0 and held_toy == null and toy.can_be_caught_by(self):
			_catch(toy)
		else:
			toy.deflect_from(self)
			Juice.float_text(get_parent(), global_position + Vector3.UP * 1.6, "BONK!", Color(1.0, 0.85, 0.3), 0.6)
			Sfx.play("bounce", 0.9, -5.0)
		return false
	if _catch_buffer > 0.0 and held_toy == null and toy.can_be_caught_by(self):
		_catch(toy)
		return false
	if shield_charges > 0:
		# One charge per shield held; the belt restores them at the start of the next round.
		shield_charges -= 1
		_powerup_halo.visible = shield_charges > 0
		toy.deflect_from(self)
		Juice.float_text(get_parent(), global_position + Vector3.UP * 1.6, "SHIELD!", Color(1.0, 0.88, 0.4), 0.6)
		Juice.burst(get_parent(), global_position + Vector3.UP * 0.7, Color(1.0, 0.88, 0.4), 14, 3.5)
		Sfx.play("catch", 1.25, -3.0)
		return true
	if toy.data.special == ToyData.Special.KNOCKBACK:
		return receive_toy_impulse(toy.velocity, 10.0, 0.42, true)
	eliminate(toy)
	return true


## Rope tugs and chicken squeaks create space without counting as a wall bonk.
func receive_toy_impulse(direction: Vector3, strength: float, slow_time: float, disarm: bool) -> bool:
	if not alive or round_locked or invincible or _spawn_grace > 0.0:
		return false
	direction.y = 0.0
	_weapon_impulse = direction.normalized() * strength
	_stagger_time = maxf(_stagger_time, slow_time)
	if disarm and is_instance_valid(held_toy):
		var dropped := held_toy
		held_toy = null
		dropped.drop(global_position)
		dropped.velocity = _weapon_impulse * 0.6
		_pickup_lock = 0.55
	model.squash()
	Sfx.play("bounce", 0.75, -4.0)
	Juice.burst(get_parent(), global_position + Vector3.UP * 0.5, slot.color.lightened(0.4), 9, 3.0)
	return true


func eliminate(by: Toy = null) -> void:
	if state == State.ELIMINATED:
		return
	state = State.ELIMINATED
	dizzy_time = 0.0
	if model.has_method("set_dizzy"):
		model.call("set_dizzy", false)
	if held_toy:
		var dropped := held_toy
		held_toy = null
		dropped.drop(global_position)
	body_shape.set_deferred("disabled", true)
	catch_shape.set_deferred("disabled", true)
	velocity = Vector3.ZERO
	Sfx.play("bonk")
	Sfx.play("bark", randf_range(0.92, 1.12), -3.0)
	Music.duck(0.9)
	Juice.hitstop()
	Juice.shake(0.35)
	Juice.burst(get_parent(), global_position + Vector3(0, 0.6, 0), slot.color, 26, 6.0)
	Juice.float_text(get_parent(), global_position + Vector3(0, 1.8, 0), "BONK!", Color(1.0, 0.85, 0.2), 1.0)
	var dir := by.velocity.normalized() if by and by.velocity.length() > 0.1 else Vector3(0, 0, 1)
	model.play_knocked_out(dir)
	ring.visible = false
	_powerup_halo.visible = false
	_aim_marker.visible = false
	eliminated.emit(self)
	Events.dog_eliminated.emit(self, by)


## Rebuilds the dog's stats from its slot's power-up belt. Called on spawn, so a belt kept
## from an earlier round is in force from the first frame, and again whenever one is added.
func apply_powerups() -> void:
	_speed_mult = 1.0
	_catch_mult = 1.0
	_throw_mult = 1.0
	_dash_mult = 1.0
	_cooldown_mult = 1.0
	shield_charges = 0
	if slot == null:
		return
	for kind in slot.powerups:
		match kind:
			PowerupKinds.SHIELD:
				shield_charges += 1
			PowerupKinds.ZOOMIES:
				_speed_mult *= 1.18
				_cooldown_mult *= 0.82
			PowerupKinds.BIG_CATCH:
				_catch_mult *= 1.35
			PowerupKinds.CANNON:
				_throw_mult *= 1.22
			PowerupKinds.SPRINGS:
				_dash_mult *= 1.3
				_cooldown_mult *= 0.8
	if is_instance_valid(catch_shape) and catch_shape.shape is SphereShape3D:
		(catch_shape.shape as SphereShape3D).radius = data.catch_radius * _catch_mult
	if is_instance_valid(_powerup_halo):
		_powerup_halo.visible = shield_charges > 0


## Takes a crate: adds to the belt, re-applies, and reports what (if anything) was displaced.
func collect_powerup(kind: StringName) -> StringName:
	if not alive or round_locked or slot == null:
		return &""
	var dropped := slot.take_powerup(kind)
	apply_powerups()
	Juice.pop(model, 1.12, 0.18)
	return dropped


func powerup_status() -> String:
	if slot == null or slot.powerups.is_empty():
		return ""
	var parts: PackedStringArray = []
	for kind in slot.powerups:
		parts.append(PowerupKinds.display_name(kind))
	return " + ".join(parts)


func dash_ready() -> bool:
	return _dash_cooldown <= 0.0


## Ground arrow shows the throw direction without covering the dog silhouette.
func _build_aim_marker() -> void:
	var triangle := ImmediateMesh.new()
	triangle.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	triangle.surface_add_vertex(Vector3(-0.17, 0, 0.16))
	triangle.surface_add_vertex(Vector3(0.0, 0, -0.21))
	triangle.surface_add_vertex(Vector3(0.17, 0, 0.16))
	triangle.surface_end()
	_aim_marker = MeshInstance3D.new()
	_aim_marker.mesh = triangle
	var mat := Mats.unlit(slot.color)
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_aim_marker.material_override = mat
	_aim_marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_aim_marker)
