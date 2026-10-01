class_name Dog
extends CharacterBody3D
## One playable dog. Reads a DeviceInput, moves on the XZ plane, dashes (with i-frames),
## throws, catches. Hits are decided by Toy.gd calling [method hit_by].

signal eliminated(dog: Dog)

enum State { ALIVE, ELIMINATED }

const ACCEL := 47.0
const BRAKE := 65.0
const TURN_ACCEL := 76.0
const INPUT_BUFFER := 0.085
const DASH_TIME := 0.22
## Invincibility covers the burst but not the recovery, so a dash is an escape, not a shield.
const DASH_IFRAMES := 0.14
const SPAWN_GRACE := 1.1
## Close-quarters swipe for a dog with nothing in its mouth.
const WHACK_RANGE := 1.55
const WHACK_COOLDOWN := 0.6
## A short lockout after any throw, catch or swipe. Mashing the button used to fire an attempt
## every frame, which felt unresponsive rather than fast; this makes each press mean one action.
const ACTION_LOCKOUT := 0.2
const DIZZY_TIME := 1.5
## Holding throw winds the shot up. Power runs from TAP_POWER to FULL_POWER over this long.
const CHARGE_TIME := 0.62
## Throw power for a flick of the button, as a fraction of the dog's throw_power. A tap is a
## short, soft lob - still lethal up close, but it drops under danger_speed within a few
## metres. Range and punch are what the wind-up buys, which is what makes holding a decision.
const TAP_POWER := 0.62
## Throw power at a full wind-up. Everything in between is linear.
const FULL_POWER := 1.85
## Top speed while winding up, as a fraction of normal. Reached at full charge.
const CHARGE_MOVE_SCALE := 0.55
## Audible steps as the wind-up fills. The meter is deliberately quiet to look at, so the
## rising ticks are what tell the person holding the button how far along they are.
const CHARGE_TICKS := 5
## How fast a dog hugs a rising deck, in metres per second. Play stays on the XZ plane: this
## only follows the surface an A-frame reports, it never lifts a dog off the ground.
const CLIMB_SPEED := 9.0
## Zoomies: top speed and dash recharge. Big enough to see from across the room.
const ZOOMIES_SPEED := 1.3
const ZOOMIES_COOLDOWN := 0.45
## Dig!: a burrow covers this much more ground than a dash, and takes this much longer.
const DIG_DISTANCE := 1.9
const DIG_TIME_SCALE := 1.7

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
## Rebuilt from the slot's power-ups whenever the belt changes (see apply_powerups).
var _speed_mult := 1.0
var _dash_mult := 1.0
var _cooldown_mult := 1.0
## Ghost Pup: concealed everywhere, not just in tall grass, with only paw prints to go on.
var ghost := false
## Dig!: the dash goes underground - longer, fully protected, and out of sight until it surfaces.
var digger := false
var _burrowed := false
var _mound: MeshInstance3D
var _print_side := 1.0

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
var _action_lockout := 0.0
## Wind-up state: how far the held throw is charged, and the last ring step that ticked.
var _charge := 0.0
var _charging := false
var _charge_step := 0
var _charge_meter: ChargeMeter
var _shield_bubble: MeshInstance3D
## While > 0 the dog is seeing stars: no input, no actions.
var dizzy_time := 0.0
## Set during the practice round: the dog can throw, catch and whack, but nothing can put it
## out. Learning which button throws should never cost you a knockout.
var practice_safe := false
var _weapon_impulse := Vector3.ZERO
## Who last knocked this dog about, and when (msec), so a fall into a hole is credited to them.
var _last_pusher: Dog
var _last_push_msec := -100000
## Set while going down a hole, so the knockout plays as a fall rather than a tumble.
var _falling_into := Vector3.INF
## A push this recent still counts as the reason a dog ended up down a hole.
const PUSH_CREDIT_MSEC := 2000
## Height of the deck under the paws. Zero everywhere except on a ramp.
var ground_y := 0.0
var _slow_sources: Dictionary = {}
## Where the dog meant to go this frame, before walls took their share. A dog leaning into a
## wall has no velocity left after sliding, and portals need to know it was pushing.
var push_velocity := Vector3.ZERO
var _buffered_throw := 0.0
var _footstep_distance := 0.0
var _sight_timer := 0.0
## One volley (a Scatter Fetch press) is one hit: the id and when it last landed on this dog.
var _last_volley := 0
var _last_volley_msec := 0
const VOLLEY_WINDOW_MSEC := 450
## Scatter Fetch fans its two side toys out this far either side, at this share of the power.
const SCATTER_ANGLE := 16.0
const SCATTER_POWER := 0.85
var _decoy: Decoy
## Tall grass the dog is standing in, by source. While any holds it, and it has not just given
## itself away, the dog is concealed: body, ring and name all hidden.
var _cover: Dictionary = {}
var _reveal_time := 0.0
var concealed := false
var _contact_disc: MeshInstance3D
## Throwing or dashing out of cover shows you for this long.
const REVEAL_TIME := 0.7
## The arena's outer collision is taller than its fence, so it is left out of the sight test.
var _outer_walls: RID
var _last_step_position := Vector3.ZERO

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
	catch.radius = data.catch_radius
	catch_shape.shape = catch
	catch_shape.position.y = 0.5
	model.setup(data, slot.color)
	model.setup_silhouette(slot.color)
	name_tag.text = "%s · %s" % [slot.label, data.display_name.to_upper()]
	name_tag.font = UiKit.FONT_DISPLAY
	name_tag.modulate = slot.color
	name_tag.position.y = 1.55 * data.model_scale + 0.35
	ring.mesh = Mats.torus(data.body_radius + 0.10, data.body_radius + 0.17)
	ring.material_override = Mats.unlit(Color(slot.color, 0.85))
	_contact_disc = Mats.contact_shadow(self, data.body_radius * 0.85)
	name_tag.pixel_size = 0.006
	_build_aim_marker()
	_charge_meter = ChargeMeter.new()
	add_child(_charge_meter)
	_charge_meter.setup(slot.color, data.body_radius)
	# A real bubble, not just a ring on the floor: a shield you are wearing should look like
	# something between you and the toy.
	var shell := Mats.sphere(data.body_radius + 0.46)
	_shield_bubble = Mats.mesh(self, shell, Color(0.55, 0.88, 1.0, 0.3), Vector3(0, data.body_radius + 0.24, 0))
	var bubble_mat := Mats.glass(Color(0.55, 0.88, 1.0, 0.24))
	bubble_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	bubble_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_shield_bubble.material_override = bubble_mat
	_shield_bubble.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_shield_bubble.visible = false
	_powerup_halo = Mats.mesh(self, Mats.torus(data.body_radius + 0.37, data.body_radius + 0.43), Color.WHITE, Vector3(0, 0.055, 0))
	_powerup_halo.material_override = Mats.unlit(PowerupKinds.color(PowerupKinds.SHIELD))
	_powerup_halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_powerup_halo.visible = false
	apply_powerups()
	_last_step_position = global_position
	# No spawn pop: dogs are placed while the countdown has the actors disabled, which froze a
	# 1.5x pop mid-tween and showed every dog oversized until the whistle. True size, always.


func _physics_process(delta: float) -> void:
	if state != State.ALIVE or round_locked:
		return
	_powerup_halo.visible = shield_charges > 0 and not concealed
	_powerup_halo.scale = Vector3.ONE * (1.0 + sin(Time.get_ticks_msec() * 0.006) * 0.055)
	_spawn_grace = maxf(0.0, _spawn_grace - delta)
	_pickup_lock = maxf(0.0, _pickup_lock - delta)
	_stagger_time = maxf(0.0, _stagger_time - delta)
	_whack_cooldown = maxf(0.0, _whack_cooldown - delta)
	_action_lockout = maxf(0.0, _action_lockout - delta)
	_update_shield_bubble(delta)
	if dizzy_time > 0.0:
		dizzy_time = maxf(0.0, dizzy_time - delta)
		if dizzy_time <= 0.0 and model.has_method("set_dizzy"):
			model.call("set_dizzy", false)
	_weapon_impulse = _weapon_impulse.move_toward(Vector3.ZERO, 20.0 * delta)
	_dash_cooldown = maxf(0.0, _dash_cooldown - delta)
	_catch_cooldown = maxf(0.0, _catch_cooldown - delta)
	if _charging:
		if is_instance_valid(held_toy) and dizzy_time <= 0.0:
			_advance_charge(delta)
		else:
			_cancel_charge()
	if _catch_buffer > 0.0:
		_catch_buffer -= delta
		if _catch_buffer <= 0.0:
			_catch_cooldown = data.catch_cooldown
			model.set_catching(false)

	var move2 := input.move_vector()
	var dash_pressed := input.just_pressed(&"dash")
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
			# Uncurl into the recovery pose as protection ends, before movement has recovered.
			model.set_dashing(false)
	if _dash_timer > 0.0:
		_dash_timer -= delta
		if _dash_timer <= 0.0:
			model.set_dashing(false)
			if _burrowed:
				_surface()
	else:
		var stagger_scale := 0.55 if _stagger_time > 0.0 else 1.0
		# Planting your feet is what a wind-up costs: the harder the throw, the slower the walk.
		var wind_up_scale := lerpf(1.0, CHARGE_MOVE_SCALE, _charge) if _charging else 1.0
		var rate := BRAKE if move.is_zero_approx() else (TURN_ACCEL if velocity.dot(move) < 0.0 else ACCEL)
		velocity = velocity.move_toward(move * data.move_speed * speed_scale * stagger_scale * wind_up_scale * _speed_mult + _weapon_impulse, rate * delta)
		if dash_pressed and _dash_cooldown <= 0.0 and dizzy_time <= 0.0:
			_start_dash()

	# Both edges are polled every frame: a button held down through a dizzy spell must not
	# leave a stale press waiting to fire the moment the stars clear.
	var throw_pressed := input.just_pressed(&"throw")
	var throw_released := input.just_released(&"throw")
	_buffered_throw = maxf(0.0, _buffered_throw - delta)
	if dizzy_time > 0.0:
		_buffered_throw = 0.0
	if throw_pressed and dizzy_time <= 0.0:
		if _action_lockout > 0.0 and _action_lockout <= INPUT_BUFFER:
			_buffered_throw = INPUT_BUFFER
		else:
			_throw_or_catch()
	elif throw_released and _charging:
		_release_throw()
	if _buffered_throw > 0.0 and _action_lockout <= 0.0:
		_buffered_throw = 0.0
		_throw_or_catch()
		if _charging and not input.is_pressed(&"throw"):
			_release_throw()

	velocity.y = 0.0
	push_velocity = velocity
	move_and_slide()
	ground_y = move_toward(ground_y, Terrain.ground_height(self, global_position), CLIMB_SPEED * delta)
	global_position.y = ground_y
	var traveled := global_position.distance_to(_last_step_position)
	_last_step_position = global_position
	if traveled < 0.8 and _dash_timer <= 0.0:
		_footstep_distance += traveled
		if _footstep_distance > 0.85 and velocity.length() > 0.8:
			_footstep_distance = 0.0
			if speed_scale < 0.99:
				# Wading through mud or water: every step is a squelch.
				Sfx.play_at("splat", global_position, randf_range(0.9, 1.15), -17.0)
			else:
				# Smaller breeds patter a little higher than the big dogs.
				Sfx.play_at("paw", global_position, 1.08 - (data.model_scale - 1.0) * 0.6, -19.0)
			if concealed and ghost:
				_leave_paw_print()
	model.update_motion(facing, velocity.length() / data.move_speed, delta)
	_aim_marker.position = facing * (data.body_radius + 0.62) + Vector3(0, 0.04, 0)
	_aim_marker.rotation.y = atan2(-facing.x, -facing.z)
	_aim_marker.visible = held_toy != null and not concealed
	ring.scale = Vector3.ONE * (1.08 if _catch_buffer > 0.0 else 1.0)
	if held_toy:
		held_toy.global_position = get_hold_position()


func _process(delta: float) -> void:
	# A round can end, or a dog go out, mid-burrow; nobody should finish a round underground.
	if _burrowed and (round_locked or not alive):
		_surface()
	_reveal_time = maxf(0.0, _reveal_time - delta)
	_update_concealment()
	_sight_timer -= delta
	if _sight_timer > 0.0:
		return
	_sight_timer = 0.1
	model.set_silhouette(alive and not concealed and _hidden_from_camera())


## Cover sources (tall grass) report whether this dog is inside them.
func set_cover(source: Node, inside: bool) -> void:
	if inside:
		_cover[source.get_instance_id()] = true
	else:
		_cover.erase(source.get_instance_id())


## Giving yourself away: a throw or a dash from cover shows you briefly.
func reveal() -> void:
	_reveal_time = REVEAL_TIME
	_update_concealment()


func _update_concealment() -> void:
	var hide := alive and (ghost or not _cover.is_empty()) and _reveal_time <= 0.0 and not _charging
	if hide == concealed:
		return
	concealed = hide
	if not _burrowed:
		_set_body_shown(not hide)
	if hide:
		_powerup_halo.visible = false
	else:
		_powerup_halo.visible = shield_charges > 0 and alive


## A push from the arena itself (a sprinkler jet). Not an attack: nothing drops, nobody is dizzy.
func shove(impulse: Vector3) -> void:
	if not alive or round_locked or invincible:
		return
	_weapon_impulse = impulse
	_stagger_time = maxf(_stagger_time, 0.2)


## True when a prop, hedge or gate stands between the camera and this dog. Two sample heights,
## so a low hedge that only hides the legs does not count but a wall that hides the body does.
func _hidden_from_camera() -> bool:
	var camera := get_viewport().get_camera_3d()
	if camera == null or camera.projection != Camera3D.PROJECTION_ORTHOGONAL:
		return false
	if not _outer_walls.is_valid():
		var arena := get_tree().get_first_node_in_group("arenas")
		var walls := arena.get_node_or_null("Walls") as CollisionObject3D if arena != null else null
		if walls != null:
			_outer_walls = walls.get_rid()
	var space := get_world_3d().direct_space_state
	for height: float in [0.45, 0.9]:
		var target := global_position + Vector3.UP * height * data.model_scale
		# Orthographic rays start at the dog's own screen position, not at the lens.
		var origin := camera.project_ray_origin(camera.unproject_position(target))
		var query := PhysicsRayQueryParameters3D.create(origin, target, 1 | 16)
		query.exclude = [get_rid(), _outer_walls] if _outer_walls.is_valid() else [get_rid()]
		if space.intersect_ray(query).is_empty():
			return false
	return true


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
	_dash_timer = DASH_TIME * (DIG_TIME_SCALE if digger else 1.0)
	# A burrow is protected from the moment the dog goes under until it is back up.
	_iframe_timer = _dash_timer + 0.05 if digger else DASH_IFRAMES
	_dash_cooldown = data.dash_cooldown * _cooldown_mult
	velocity = facing * (data.dash_distance * _dash_mult / _dash_timer)
	invincible = true
	model.set_dashing(true)
	Sfx.play_at("dash", global_position, randf_range(0.9, 1.1))
	if digger:
		_burrow()
	else:
		reveal()
	if slot != null and slot.has_powerup(PowerupKinds.GOOD_DECOY):
		if is_instance_valid(_decoy):
			_decoy.poof()
		_decoy = Decoy.new()
		_decoy.setup(self)
		get_parent().add_child(_decoy)
		_decoy.global_position = global_position
	Juice.burst(get_parent(), global_position - facing * 0.3 + Vector3(0, 0.3, 0), Color(1, 1, 1, 0.7), 8, 3.0)


## Dig!: the dog drops out of sight and a molehill tears across the lawn in its place.
func _burrow() -> void:
	_burrowed = true
	_set_body_shown(false)
	if not is_instance_valid(_mound):
		_mound = Mats.mesh(self, Mats.sphere(data.body_radius * 0.7), Color("7a5a3a"), Vector3.ZERO)
		_mound.scale = Vector3(1.0, 0.45, 1.0)
		_mound.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_mound.visible = true
	Sfx.play_at("splat", global_position, 0.7, -6.0)
	Juice.burst(get_parent(), global_position + Vector3.UP * 0.2, Color("8a6844"), 14, 3.4)


func _surface() -> void:
	if not _burrowed:
		return
	_burrowed = false
	if is_instance_valid(_mound):
		_mound.visible = false
	_set_body_shown(not concealed)
	if alive and not round_locked:
		reveal()
		Juice.pop(model, 1.2, 0.16)
		Sfx.play_at("splat", global_position, 1.1, -6.0)
		Juice.burst(get_parent(), global_position + Vector3.UP * 0.3, Color("8a6844"), 18, 4.2)


func _set_body_shown(shown: bool) -> void:
	for part: Node3D in [model, ring, name_tag, _contact_disc]:
		if is_instance_valid(part):
			part.visible = shown
	if is_instance_valid(held_toy):
		held_toy.model.visible = shown


## Ghost Pup's only tell: a fading print on each step, left and right in turn.
func _leave_paw_print() -> void:
	_print_side = -_print_side
	var side := Vector3(-facing.z, 0.0, facing.x) * 0.13 * _print_side
	var at := global_position + side + Vector3(0, 0.03, 0)
	var print_mesh := Mats.mesh(get_parent(), Mats.cylinder(0.11, 0.01), Color.WHITE, at)
	print_mesh.scale = Vector3(0.8, 1.0, 1.1)
	print_mesh.rotation.y = atan2(-facing.x, -facing.z)
	var ink := Mats.unlit(Color(0.12, 0.1, 0.14, 0.5))
	print_mesh.material_override = ink
	print_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var fade := print_mesh.create_tween()
	fade.tween_interval(0.6)
	fade.tween_property(ink, "albedo_color:a", 0.0, 0.9)
	fade.tween_callback(print_mesh.queue_free)


## Feedback for the lockout: the ring flicks so a press that arrived too early reads as "not
## yet" rather than as nothing happening at all.
func _reject_press() -> void:
	ring.scale = Vector3(1.22, 1.0, 1.22)
	Sfx.play("ui_move", 1.5, -20.0)


## The shield bubble breathes while it is up, and pops when the last charge goes.
func _update_shield_bubble(delta: float) -> void:
	if not is_instance_valid(_shield_bubble):
		return
	# A hidden dog does not get a bubble giving its position away.
	var want := shield_charges > 0 and not concealed and not _burrowed
	if _shield_bubble.visible != want:
		_shield_bubble.visible = want
		if want:
			_shield_bubble.scale = Vector3.ZERO
	if want:
		var breathe := 1.0 + sin(Time.get_ticks_msec() * 0.004) * 0.045
		_shield_bubble.scale = _shield_bubble.scale.move_toward(Vector3.ONE * breathe, delta * 4.5)


## What a press of the throw button does, given what is in the dog's mouth: start a wind-up,
## swipe at a rival in reach, catch a toy already on top of us, or arm the catch window.
func _throw_or_catch() -> void:
	if _action_lockout > 0.0:
		_reject_press()
		return
	if held_toy:
		# A throw is not fired by the press; the release is what lets it go.
		_begin_charge()
		return
	_action_lockout = ACTION_LOCKOUT
	# An incoming toy gets defensive priority over an incidental nearby rival.
	if _catch_cooldown <= 0.0:
		var incoming := _find_catchable_toy()
		if incoming != null:
			_catch(incoming)
			return
	var target := _whack_target()
	if target != null:
		_whack(target)
		return
	if _catch_cooldown > 0.0 or _catch_buffer > 0.0:
		_reject_press()
		return
	# Arm the catch window: a toy that reaches us in the next catch_window seconds is caught.
	_catch_buffer = data.catch_window
	model.set_catching(true)


## [param charge] is 0 for a tap and 1 for a full wind-up, scaling power from [constant
## TAP_POWER] to [constant FULL_POWER].
func _throw(charge: float = 0.0) -> void:
	if not is_instance_valid(held_toy) or not alive or round_locked:
		return
	var toy := held_toy
	held_toy = null
	var power := data.throw_power * lerpf(TAP_POWER, FULL_POWER, charge)
	toy.throw(self, facing, power, charge)
	if toy.power_effects.scatter:
		_scatter(toy, power, charge)
	if model.has_method("play_throw"):
		model.call("play_throw")
	else:
		model.squash()
	# A heavier throw lands lower and louder, so power is mostly carried by sound and by how
	# fast the toy leaves, rather than by decoration on the dog.
	reveal()
	Sfx.play_at("throw", global_position, randf_range(0.95, 1.1) - charge * 0.22, charge * 3.0)
	if charge > 0.35:
		Juice.burst(get_parent(), global_position + facing * 0.7 + Vector3(0, 0.55, 0),
			Color(1.0, 0.9, 0.6), int(3.0 + charge * 6.0), 1.8 + charge * 2.4)
	Events.toy_thrown.emit(toy, self)


## Two side toys fan out from a Scatter Fetch throw, carrying the same snapshot.
func _scatter(main: Toy, power: float, charge: float) -> void:
	var scene := load("res://scenes/actors/toy.tscn") as PackedScene
	for side in [-1.0, 1.0]:
		var extra := scene.instantiate() as Toy
		extra.setup(main.data)
		extra.ephemeral = true
		get_parent().add_child(extra)
		extra.global_position = main.global_position
		extra.throw(self, facing.rotated(Vector3.UP, deg_to_rad(SCATTER_ANGLE) * side), power * SCATTER_POWER, charge, main.power_effects)


# ---------------------------------------------------------------- winding up

## A press with something in the mouth starts the wind-up; the release is the throw.
func _begin_charge() -> void:
	if not alive or round_locked:
		return
	_charging = true
	_charge = 0.0
	_charge_step = 0
	_charge_meter.set_charge(0.0, facing)
	model.set_charge(0.0, true)


func _advance_charge(delta: float) -> void:
	var before := _charge
	_charge = minf(1.0, _charge + delta / CHARGE_TIME)
	# Rising ticks as the arc fills, then a single soft chime when there is no more to give.
	var step := int(_charge * float(CHARGE_TICKS))
	if step > _charge_step:
		_charge_step = step
		Sfx.play("charge", 0.85 + _charge * 1.05, -14.0)
	if before < 1.0 and _charge >= 1.0:
		Sfx.play_at("charged", global_position, 1.0, -10.0)
		Events.throw_charged.emit(self)
		Juice.pop(model, 1.07, 0.14)
	_charge_meter.set_charge(_charge, facing)
	model.set_charge(_charge, true)
	held_toy.set_wind_up(_charge)


func _release_throw() -> void:
	var charge := _charge
	_cancel_charge()
	if not is_instance_valid(held_toy):
		return
	_action_lockout = ACTION_LOCKOUT
	_throw(charge)


func _cancel_charge() -> void:
	if not _charging:
		return
	_charging = false
	_charge = 0.0
	_charge_step = 0
	_charge_meter.hide_meter()
	model.set_charge(0.0, false)
	if is_instance_valid(held_toy):
		held_toy.set_wind_up(0.0)


## How far this dog's throw is wound up, for the HUD. Zero when nothing is charging.
func charge_ratio() -> float:
	return _charge if _charging else 0.0


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
		if slot.allied_with(other.slot) and not Game.friendly_fire:
			continue
		var offset := other.global_position - global_position
		offset.y = 0.0
		var distance := offset.length()
		if distance > best_distance:
			continue
		# Only what the dog is roughly facing: no blind swipes behind you.
		if facing.dot(offset.normalized()) < 0.15:
			continue
		if not CombatRules.clear_between(self, global_position + Vector3.UP * 0.7, other.global_position + Vector3.UP * 0.7):
			continue
		best = other
		best_distance = distance
	return best


func _whack(target: Dog) -> void:
	_whack_cooldown = WHACK_COOLDOWN
	model.play_whack()
	var away := target.global_position - global_position
	away.y = 0.0
	target.receive_whack(away.normalized(), self)
	Sfx.play_at("whack", global_position, randf_range(0.92, 1.08), -2.0)
	Juice.burst(get_parent(), global_position + facing * 0.6 + Vector3.UP * 0.6, slot.color.lightened(0.3), 10, 3.2)


## Taking a swipe: a dog holding something loses it, an empty-pawed one sees stars.
func receive_whack(direction: Vector3, from: Dog) -> void:
	if not alive or round_locked or invincible or _spawn_grace > 0.0 or practice_safe:
		return
	if from != null:
		_last_pusher = from
		_last_push_msec = Time.get_ticks_msec()
	_cancel_charge()
	_buffered_throw = 0.0
	if is_instance_valid(held_toy):
		var dropped := held_toy
		held_toy = null
		dropped.drop(global_position)
		dropped.velocity = direction * 5.0
		_pickup_lock = 0.7
		_weapon_impulse = direction * 7.0
		_stagger_time = maxf(_stagger_time, 0.35)
		Sfx.play_at("squeak", global_position, randf_range(0.8, 0.95), -6.0)
		Juice.float_text(get_parent(), global_position + Vector3.UP * 1.6, DogTalk.disarm(), UiKit.CREAM, 0.6)
	else:
		dizzy_time = DIZZY_TIME
		if _catch_buffer > 0.0:
			_catch_buffer = 0.0
			_catch_cooldown = data.catch_cooldown
			model.set_catching(false)
		_weapon_impulse = direction * 5.0
		if model.has_method("set_dizzy"):
			model.call("set_dizzy", true)
		Sfx.play_at("bark", global_position, randf_range(0.8, 0.92), -5.0)
		Sfx.play_at("dizzy", global_position, randf_range(0.95, 1.05), -8.0)
		Juice.float_text(get_parent(), global_position + Vector3.UP * 1.7, "DIZZY!", Color(1.0, 0.88, 0.4), 0.8)
	model.play_stagger()
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
	_cancel_charge()
	_catch_buffer = 0.0
	model.set_catching(false)
	if toy.ephemeral:
		# A caught side toy is a save, not a prize: it pops and the paws stay empty.
		toy.vanish()
		Sfx.play_at("catch", global_position)
		Juice.float_text(get_parent(), global_position + Vector3(0, 1.6, 0), DogTalk.catch_line(), slot.color, 0.7)
		return
	toy.pick_up(self)
	Sfx.play_at("catch", global_position)
	Juice.pop(model, 1.3)
	Juice.float_text(get_parent(), global_position + Vector3(0, 1.6, 0), DogTalk.catch_line(), slot.color, 0.7)
	Events.toy_caught.emit(toy, self)


## Called by an idle toy the dog walks over.
func try_pickup(toy: Toy) -> bool:
	if toy.ephemeral or held_toy != null or not alive or round_locked or _pickup_lock > 0.0:
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
	return CombatRules.can_hurt(toy.thrower, self)


func hit_by(toy: Toy) -> bool:
	if not toy.is_dangerous():
		return false
	return _resolve_hit(toy, false, Vector3.ZERO)


func hit_by_blast(toy: Toy, origin: Vector3) -> bool:
	var direction := global_position - origin
	direction.y = 0.0
	return _resolve_hit(toy, true, direction.normalized())


func _resolve_hit(toy: Toy, area_hit: bool, direction: Vector3) -> bool:
	if not alive or round_locked or invincible or _spawn_grace > 0.0:
		return false
	# Toys from one volley are one hit: once a volley has landed, its other toys pass through.
	var volley := toy.power_effects.volley if toy.power_effects != null else 0
	if volley != 0 and volley == _last_volley and Time.get_ticks_msec() - _last_volley_msec < VOLLEY_WINDOW_MSEC:
		return false
	if not can_be_hurt_by(toy):
		# Reads as a hit so the throw is not silently ignored, but nobody goes out.
		if not area_hit:
			toy.deflect_from(self)
		Sfx.play("bounce", 0.95, -6.0)
		return false
	if practice_safe:
		if area_hit:
			return false
		# Still reads as a hit so a catch can be practised, but never eliminates.
		if _catch_buffer > 0.0 and held_toy == null and toy.can_be_caught_by(self):
			_catch(toy)
		else:
			toy.deflect_from(self)
			Juice.float_text(get_parent(), global_position + Vector3.UP * 1.6, "BONK!", Color(1.0, 0.85, 0.3), 0.6)
			Sfx.play("bounce", 0.9, -5.0)
		return false
	if not area_hit and _catch_buffer > 0.0 and held_toy == null and toy.can_be_caught_by(self):
		_catch(toy)
		return false
	if volley != 0:
		_last_volley = volley
		_last_volley_msec = Time.get_ticks_msec()
	if shield_charges > 0:
		# A shield is spent, not rented: it comes off the belt for the rest of the match, so
		# taking a hit behind one actually costs something.
		shield_charges -= 1
		if slot != null:
			slot.use_powerup(PowerupKinds.SHIELD)
		_powerup_halo.visible = shield_charges > 0
		if not area_hit:
			toy.deflect_from(self)
		# The bubble pops where the toy hit it, so the shield is visibly what stopped it.
		if is_instance_valid(_shield_bubble) and shield_charges <= 0:
			var burst := _shield_bubble.create_tween()
			burst.tween_property(_shield_bubble, "scale", Vector3.ONE * 1.45, 0.14).set_trans(Tween.TRANS_BACK)
			burst.tween_property(_shield_bubble, "scale", Vector3.ZERO, 0.12)
		Juice.burst(get_parent(), global_position + Vector3.UP * 0.8, Color(0.6, 0.9, 1.0), 20, 4.2)
		Juice.float_text(get_parent(), global_position + Vector3.UP * 1.6, DogTalk.shield_pop(), Color(1.0, 0.88, 0.4), 0.6)
		Juice.burst(get_parent(), global_position + Vector3.UP * 0.7, Color(1.0, 0.88, 0.4), 14, 3.5)
		Sfx.play("shield", 1.0, -3.0)
		return true
	eliminate(toy, direction)
	return true


func is_dashing() -> bool:
	return _dash_timer > 0.0


## True while something other than this dog's own legs is moving it: a whack, a sprinkler, a mower.
func is_being_pushed(threshold: float) -> bool:
	return _weapon_impulse.length() > threshold


## Whoever put this dog out: the thrower of the toy that hit it, or - for a fall down a hole -
## whoever whacked it there in the last couple of seconds. Null for nobody in particular.
func knocked_out_by(by: Node) -> Dog:
	var thrower: Variant = by.get("thrower") if is_instance_valid(by) else null
	if thrower is Dog and is_instance_valid(thrower):
		return thrower
	if is_instance_valid(_last_pusher) and Time.get_ticks_msec() - _last_push_msec < PUSH_CREDIT_MSEC:
		return _last_pusher
	return null


## Down a hole: out of the round, the same as a bonk.
func fall_into(centre: Vector3) -> void:
	if not alive or round_locked or practice_safe:
		return
	_falling_into = centre
	eliminate(null, Vector3(centre.x - global_position.x, 0, centre.z - global_position.z).normalized())


func eliminate(by: Toy = null, impact_direction: Vector3 = Vector3.ZERO) -> void:
	if state == State.ELIMINATED:
		return
	state = State.ELIMINATED
	dizzy_time = 0.0
	_cancel_charge()
	if model.has_method("set_dizzy"):
		model.call("set_dizzy", false)
	if held_toy:
		var dropped := held_toy
		held_toy = null
		dropped.drop(global_position)
	body_shape.set_deferred("disabled", true)
	catch_shape.set_deferred("disabled", true)
	velocity = Vector3.ZERO
	Sfx.play_at("hit", global_position)
	Sfx.play_at("bonk", global_position, 1.0, -4.0)
	Sfx.play_at("bark", global_position, randf_range(0.92, 1.12), -3.0)
	var landing := global_position
	# The thump lands with the body at the end of the tumble, not with the hit.
	get_tree().create_timer(0.36, false).timeout.connect(func() -> void: Sfx.play_at("land", landing, randf_range(0.9, 1.1), -6.0))
	Music.duck(0.9)
	# A knockout is the loudest thing that happens in a round, so it gets the longest freeze.
	Juice.hitstop(0.085, 0.05)
	Juice.shake(0.42)
	var dir := by.velocity.normalized() if by and by.velocity.length() > 0.1 else Vector3(0, 0, 1)
	if not impact_direction.is_zero_approx():
		dir = impact_direction
	# Three layers, because one puff of the player colour read as a tidy little sparkle rather
	# than as someone being knocked out of the round: a hard flash at the point of impact, fur
	# thrown along the line of the throw, and dust kicked up where the body lands.
	Juice.burst(get_parent(), global_position + Vector3(0, 0.75, 0), Color(1, 1, 1, 0.9), 12, 8.5)
	Juice.burst(get_parent(), global_position + Vector3(0, 0.6, 0), slot.color, 26, 6.0)
	Juice.burst(get_parent(), global_position + dir * 0.5 + Vector3(0, 0.5, 0), data.fur_color.lightened(0.12), 18, 5.0)
	Juice.burst(get_parent(), global_position + dir * DogModel.KO_KNOCKBACK + Vector3(0, 0.12, 0),
		Color(0.85, 0.8, 0.7, 0.75), 14, 2.6)
	var own_goal := by != null and by.thrower == self
	var line := "DOWN THE HOLE!" if _falling_into != Vector3.INF else (DogTalk.own_goal() if own_goal else DogTalk.knockout())
	Juice.float_text(get_parent(), global_position + Vector3(0, 1.8, 0), line, Color(1.0, 0.85, 0.2), 1.0)
	_cover.clear()
	_update_concealment()
	if _falling_into != Vector3.INF:
		model.play_fall(model.get_parent().to_local(_falling_into) if model.get_parent() is Node3D else Vector3.ZERO)
	else:
		model.play_knocked_out(dir)
	ring.visible = false
	_powerup_halo.visible = false
	_aim_marker.visible = false
	# The body is thrown clear of where it stood; the real shadow goes with it, this disc does not.
	if is_instance_valid(_contact_disc):
		_contact_disc.visible = false
	eliminated.emit(self)
	Events.dog_eliminated.emit(self, by)


## Rebuilds the dog's stats from its slot's power-up belt. Called on spawn, so a belt kept
## from an earlier round is in force from the first frame, and again whenever one is added.
func apply_powerups() -> void:
	_speed_mult = 1.0
	_dash_mult = 1.0
	_cooldown_mult = 1.0
	shield_charges = 0
	ghost = false
	digger = false
	if slot == null:
		return
	slot.normalize_powerups()
	for kind in slot.powerups:
		match kind:
			PowerupKinds.SHIELD:
				shield_charges += 1
			PowerupKinds.ZOOMIES:
				_speed_mult *= ZOOMIES_SPEED
				_cooldown_mult *= ZOOMIES_COOLDOWN
			PowerupKinds.GHOST_PUP:
				ghost = true
			PowerupKinds.DIG:
				digger = true
				_dash_mult *= DIG_DISTANCE
	if is_instance_valid(_powerup_halo):
		_powerup_halo.visible = shield_charges > 0
	if is_inside_tree():
		_update_concealment()


func effective_radius() -> float:
	return data.body_radius


## Source ownership keeps overlapping terrain and temporary powers from clearing each other.
func set_slow(source: Node, factor: float) -> void:
	_slow_sources[source.get_instance_id()] = clampf(factor, 0.1, 1.0)
	_refresh_slows()


func clear_slow(source: Node) -> void:
	_slow_sources.erase(source.get_instance_id())
	_refresh_slows()


func _refresh_slows() -> void:
	speed_scale = 1.0
	for factor: float in _slow_sources.values():
		speed_scale = minf(speed_scale, factor)


## Shows what is on the belt above the dog's head as a round opens, so the table can see who
## is carrying what before the whistle rather than finding out the hard way.
func show_belt_parade() -> void:
	if slot == null or slot.powerups.is_empty():
		return
	var top := 1.55 * data.model_scale + 0.8
	for i in slot.powerups.size():
		var kind: StringName = slot.powerups[i]
		var icon := Sprite3D.new()
		icon.texture = PowerupIcon.badge(kind, 96)
		icon.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		icon.pixel_size = 0.0045
		icon.no_depth_test = true
		icon.render_priority = 9
		var spread := (float(i) - float(slot.powerups.size() - 1) * 0.5) * 0.45
		icon.position = Vector3(spread, top, 0)
		add_child(icon)
		var show := icon.create_tween()
		show.tween_interval(0.07 * float(i))
		show.tween_property(icon, "scale", Vector3.ONE, 0.28).from(Vector3.ZERO) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		show.tween_interval(1.1)
		show.tween_property(icon, "position:y", top + 0.4, 0.45)
		show.parallel().tween_property(icon, "modulate:a", 0.0, 0.45)
		show.tween_callback(icon.queue_free)


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
