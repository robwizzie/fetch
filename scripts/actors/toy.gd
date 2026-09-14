class_name Toy
extends CharacterBody2D
## A throwable. Three states: IDLE on the ground (walk over to pick up), HELD by a dog,
## FLYING (dangerous while faster than ToyData.danger_speed). Bounces off walls with
## move_and_collide; hits dogs through the HitArea.

enum State { IDLE, HELD, FLYING }

var data: ToyData
var state := State.IDLE
var holder: Dog = null
var thrower: Dog = null
var bounces := 0
## The thrower can't be hit (or catch it back) until the toy bounces once.
var _owner_immune := false
var _spin := 0.0

@onready var shape: CollisionShape2D = $Shape
@onready var hit_area: Area2D = $HitArea
@onready var hit_shape: CollisionShape2D = $HitArea/Shape
@onready var visual: ToyVisual = $Visual
@onready var trail: Line2D = $Trail


## Must be called before adding to the tree.
func setup(p_data: ToyData) -> void:
	data = p_data


func _ready() -> void:
	add_to_group("toys")
	var body := shape.shape.duplicate() as CircleShape2D
	body.radius = data.radius
	shape.shape = body
	var hit := hit_shape.shape.duplicate() as CircleShape2D
	hit.radius = data.radius + 8.0
	hit_shape.shape = hit
	visual.setup(data)
	trail.top_level = true
	trail.default_color = Color(data.color, 0.6)
	trail.width = data.radius * 1.2
	hit_area.body_entered.connect(_on_hit_area_body_entered)


func is_dangerous() -> bool:
	return state == State.FLYING and velocity.length() >= data.danger_speed


func can_be_caught_by(dog: Dog) -> bool:
	return not (dog == thrower and _owner_immune)


# ---------------------------------------------------------------- state changes

func pick_up(dog: Dog) -> void:
	state = State.HELD
	holder = dog
	thrower = null
	velocity = Vector2.ZERO
	bounces = 0
	_owner_immune = false
	_set_solid(false)
	dog.held_toy = self
	global_position = dog.get_hold_position()
	trail.clear_points()
	visual.set_held(true)


func throw(dog: Dog, dir: Vector2, power: float) -> void:
	state = State.FLYING
	holder = null
	thrower = dog
	bounces = 0
	_owner_immune = true
	global_position = dog.global_position + dir * (dog.data.body_radius + data.radius + 6.0)
	velocity = dir * data.throw_speed * power
	_set_solid(true)
	visual.set_held(false)
	Juice.pop(visual, 1.5, 0.2)


func drop(at: Vector2) -> void:
	state = State.IDLE
	holder = null
	thrower = null
	velocity = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * 120.0
	global_position = at
	_set_solid(true)
	visual.set_held(false)


func _set_solid(solid: bool) -> void:
	shape.set_deferred("disabled", not solid)
	hit_shape.set_deferred("disabled", not solid)


# ---------------------------------------------------------------- per frame

func _physics_process(delta: float) -> void:
	match state:
		State.HELD:
			if holder == null or not is_instance_valid(holder):
				drop(global_position)
		State.FLYING, State.IDLE:
			_slide(delta)
			if state == State.FLYING:
				_check_hits()
				if velocity.length() < data.danger_speed:
					state = State.IDLE
					_owner_immune = false
			else:
				_check_pickup()
	_update_visuals(delta)


func _slide(delta: float) -> void:
	if velocity == Vector2.ZERO:
		return
	var col := move_and_collide(velocity * delta)
	if col:
		velocity = velocity.bounce(col.get_normal()) * data.bounciness
		bounces += 1
		_owner_immune = false
		if bounces > data.max_bounces:
			velocity *= 0.5
		if state == State.FLYING:
			Sfx.play("bounce", randf_range(0.9, 1.25), -4.0)
			Juice.shake(3.0)
			Juice.burst(get_parent(), global_position, Color(1, 1, 1, 0.7), 5, 140.0)
	velocity = velocity.move_toward(Vector2.ZERO, data.friction * delta)


func _check_hits() -> void:
	for body in hit_area.get_overlapping_bodies():
		_try_hit(body)


func _on_hit_area_body_entered(body: Node2D) -> void:
	_try_hit(body)


func _try_hit(body: Node2D) -> void:
	if not is_dangerous() or not (body is Dog):
		return
	var dog := body as Dog
	if dog == thrower and _owner_immune:
		return
	if dog.hit_by(self):
		match data.special:
			ToyData.Special.KNOCKBACK:
				velocity *= 0.6
			_:
				velocity *= 0.35


func _check_pickup() -> void:
	for body in hit_area.get_overlapping_bodies():
		if body is Dog and (body as Dog).try_pickup(self):
			return


func _update_visuals(delta: float) -> void:
	if state == State.HELD:
		visual.rotation = holder.facing.angle() if holder else 0.0
		return
	_spin += velocity.length() * delta * 0.03
	visual.rotation = _spin
	if state == State.FLYING:
		trail.add_point(global_position)
		while trail.get_point_count() > 14:
			trail.remove_point(0)
	elif trail.get_point_count() > 0:
		trail.remove_point(0)
