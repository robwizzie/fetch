class_name Dog
extends CharacterBody2D
## One playable dog. Reads a DeviceInput, moves, dashes (with i-frames), throws, catches.
## Hits are decided by Toy.gd calling [method hit_by]; this class only decides if the hit lands.

signal eliminated(dog: Dog)

enum State { ALIVE, ELIMINATED }

const ACCEL := 3400.0
const DASH_TIME := 0.16
const SPAWN_GRACE := 0.6

var slot: PlayerSlot
var data: DogData
var input: DeviceInput
var state := State.ALIVE
var facing := Vector2.RIGHT
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

@onready var body_shape: CollisionShape2D = $Body
@onready var visual: DogVisual = $Visual
@onready var catch_area: Area2D = $CatchArea
@onready var catch_shape: CollisionShape2D = $CatchArea/Shape
@onready var name_tag: Label = $NameTag
@onready var ring: Node2D = $Ring


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
	var body := body_shape.shape.duplicate() as CircleShape2D
	body.radius = data.body_radius
	body_shape.shape = body
	var catch := catch_shape.shape.duplicate() as CircleShape2D
	catch.radius = data.catch_radius
	catch_shape.shape = catch
	visual.setup(data, slot.color)
	visual.scale = Vector2.ONE * (data.body_radius / 19.0)
	name_tag.text = data.display_name
	name_tag.add_theme_color_override("font_color", slot.color)
	name_tag.position.x = -name_tag.size.x / 2.0
	ring.modulate = slot.color
	ring.radius = data.body_radius + 10.0
	name_tag.position.y = -data.body_radius * 1.5 - 44.0
	Juice.pop(visual, 1.6, 0.35)


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
			visual.set_catching(false)

	var move := input.move_vector()
	if move != Vector2.ZERO:
		facing = move.normalized()

	if _dash_timer > 0.0:
		_dash_timer -= delta
		if _dash_timer <= 0.0:
			invincible = false
			visual.set_dashing(false)
	else:
		velocity = velocity.move_toward(move * data.move_speed * speed_scale, ACCEL * delta)
		if input.just_pressed(&"dash") and _dash_cooldown <= 0.0:
			_start_dash()

	if input.just_pressed(&"throw"):
		_throw_or_catch()

	move_and_slide()
	visual.update_motion(facing, velocity.length() / data.move_speed)
	if held_toy:
		held_toy.global_position = get_hold_position()


func get_hold_position() -> Vector2:
	return global_position + facing * (data.body_radius + 12.0)


# ---------------------------------------------------------------- actions

func _start_dash() -> void:
	_dash_timer = DASH_TIME
	_dash_cooldown = data.dash_cooldown
	velocity = facing * (data.dash_distance / DASH_TIME)
	invincible = true
	visual.set_dashing(true)
	Sfx.play("dash", randf_range(0.9, 1.1))
	Juice.burst(get_parent(), global_position - facing * 10.0, Color(1, 1, 1, 0.6), 8, 160.0)


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
	visual.set_catching(true)


func _throw() -> void:
	var toy := held_toy
	held_toy = null
	toy.throw(self, facing, data.throw_power)
	Juice.squash(visual)
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
	visual.set_catching(false)
	toy.pick_up(self)
	Sfx.play("catch")
	Juice.pop(visual, 1.35)
	Juice.float_text(get_parent(), global_position + Vector2(-50, -80), "CATCH!", slot.color, 44)
	Events.toy_caught.emit(toy, self)


## Called by an idle toy the dog walks over.
func try_pickup(toy: Toy) -> bool:
	if held_toy != null or not alive:
		return false
	toy.pick_up(self)
	Sfx.play("pickup", randf_range(0.9, 1.2), -6.0)
	Juice.pop(visual, 1.15, 0.12)
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
	velocity = Vector2.ZERO
	Sfx.play("bonk")
	Juice.hitstop()
	Juice.shake(16.0)
	Juice.burst(get_parent(), global_position, slot.color, 26)
	Juice.float_text(get_parent(), global_position + Vector2(-60, -90), "BONK!", Color(1.0, 0.85, 0.2), 60)
	var dir := by.velocity.normalized() if by and by.velocity.length() > 1.0 else Vector2.UP
	visual.play_knocked_out(dir)
	ring.visible = false
	eliminated.emit(self)
	Events.dog_eliminated.emit(self, by)
