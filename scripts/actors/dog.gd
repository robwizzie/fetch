class_name Dog
extends CharacterBody3D
## One playable dog. Reads a DeviceInput, moves on the XZ plane, dashes (with i-frames),
## throws, catches. Hits are decided by Toy.gd calling [method hit_by].

signal eliminated(dog: Dog)

enum State { ALIVE, ELIMINATED }

const ACCEL := 60.0
const DASH_TIME := 0.16
const SPAWN_GRACE := 0.6

var slot: PlayerSlot
var data: DogData
var input: DeviceInput
var state := State.ALIVE
var facing := Vector3(0, 0, -1)
var held_toy: Toy = null
var invincible := false
## Set by zones (e.g. the pool) to slow the dog down.
var speed_scale := 1.0

var _dash_timer := 0.0
var _dash_cooldown := 0.0
var _spawn_grace := SPAWN_GRACE
## While > 0 an incoming hit becomes a catch (set by a catch press, see DogData.catch_window).
var _catch_buffer := 0.0
var _catch_cooldown := 0.0

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
	input = DeviceInput.new(slot.device)


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
	name_tag.text = data.display_name.to_upper()
	name_tag.font = UiKit.FONT_DISPLAY
	name_tag.modulate = slot.color
	name_tag.position.y = 1.55 * data.model_scale + 0.35
	ring.mesh = Mats.torus(data.body_radius + 0.12, data.body_radius + 0.28)
	ring.material_override = Mats.unlit(slot.color)
	Juice.pop(model, 1.5, 0.35)


func _physics_process(delta: float) -> void:
	if state != State.ALIVE:
		return
	_spawn_grace = maxf(0.0, _spawn_grace - delta)
	_dash_cooldown = maxf(0.0, _dash_cooldown - delta)
	_catch_cooldown = maxf(0.0, _catch_cooldown - delta)
	if _catch_buffer > 0.0:
		_catch_buffer -= delta
		if _catch_buffer <= 0.0:
			_catch_cooldown = data.catch_cooldown
			model.set_catching(false)

	var move2 := input.move_vector()
	var move := Vector3(move2.x, 0.0, move2.y)
	if move != Vector3.ZERO:
		facing = move.normalized()

	if _dash_timer > 0.0:
		_dash_timer -= delta
		if _dash_timer <= 0.0:
			invincible = false
			model.set_dashing(false)
	else:
		velocity = velocity.move_toward(move * data.move_speed * speed_scale, ACCEL * delta)
		if input.just_pressed(&"dash") and _dash_cooldown <= 0.0:
			_start_dash()

	if input.just_pressed(&"throw"):
		_throw_or_catch()

	velocity.y = 0.0
	move_and_slide()
	global_position.y = 0.0
	model.update_motion(facing, velocity.length() / data.move_speed, delta)
	if held_toy:
		held_toy.global_position = get_hold_position()


func get_hold_position() -> Vector3:
	return global_position + facing * (data.body_radius + 0.45) + Vector3(0, 0.7, 0)


# ---------------------------------------------------------------- actions

func _start_dash() -> void:
	_dash_timer = DASH_TIME
	_dash_cooldown = data.dash_cooldown
	velocity = facing * (data.dash_distance / DASH_TIME)
	invincible = true
	model.set_dashing(true)
	Sfx.play("dash", randf_range(0.9, 1.1))
	Juice.burst(get_parent(), global_position - facing * 0.3 + Vector3(0, 0.3, 0), Color(1, 1, 1, 0.7), 8, 3.0)


func _throw_or_catch() -> void:
	if held_toy:
		_throw()
		return
	if _catch_cooldown > 0.0 or _catch_buffer > 0.0:
		return
	var toy := _find_catchable_toy()
	if toy:
		_catch(toy)
		return
	# Arm the catch window: a toy that reaches us in the next catch_window seconds is caught.
	_catch_buffer = data.catch_window
	model.set_catching(true)


func _throw() -> void:
	var toy := held_toy
	held_toy = null
	toy.throw(self, facing, data.throw_power)
	model.squash()
	Sfx.play("throw", randf_range(0.95, 1.1))
	Events.toy_thrown.emit(toy, self)


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
	if held_toy != null or not alive:
		return false
	toy.pick_up(self)
	Sfx.play("pickup", randf_range(0.9, 1.2), -6.0)
	Juice.pop(model, 1.12, 0.12)
	return true


## Called by a flying toy. Returns true if the hit landed.
func hit_by(toy: Toy) -> bool:
	if not alive or invincible or _spawn_grace > 0.0:
		return false
	if _catch_buffer > 0.0 and held_toy == null and toy.can_be_caught_by(self):
		_catch(toy)
		return false
	eliminate(toy)
	return true


func eliminate(by: Toy = null) -> void:
	if state == State.ELIMINATED:
		return
	state = State.ELIMINATED
	if held_toy:
		var dropped := held_toy
		held_toy = null
		dropped.drop(global_position)
	body_shape.set_deferred("disabled", true)
	catch_shape.set_deferred("disabled", true)
	velocity = Vector3.ZERO
	Sfx.play("bonk")
	Juice.hitstop()
	Juice.shake(0.35)
	Juice.burst(get_parent(), global_position + Vector3(0, 0.6, 0), slot.color, 26, 6.0)
	Juice.float_text(get_parent(), global_position + Vector3(0, 1.8, 0), "BONK!", Color(1.0, 0.85, 0.2), 1.0)
	var dir := by.velocity.normalized() if by and by.velocity.length() > 0.1 else Vector3(0, 0, 1)
	model.play_knocked_out(dir)
	ring.visible = false
	eliminated.emit(self)
	Events.dog_eliminated.emit(self, by)
