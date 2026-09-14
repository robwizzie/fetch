class_name Toy
extends CharacterBody3D
## A throwable. Three states: IDLE on the ground (walk over to pick up), HELD by a dog,
## FLYING (dangerous while faster than ToyData.danger_speed). Flies at a fixed height,
## bounces off walls with move_and_collide, hits dogs through the HitArea.

enum State { IDLE, HELD, FLYING }

const FLY_HEIGHT := 0.75

var data: ToyData
var state := State.IDLE
var holder: Dog = null
var thrower: Dog = null
var bounces := 0
## The thrower can't be hit (or catch it back) until the toy bounces once.
var _owner_immune := false
var _spin := 0.0

@onready var shape: CollisionShape3D = $Shape
@onready var hit_area: Area3D = $HitArea
@onready var hit_shape: CollisionShape3D = $HitArea/Shape
@onready var model: ToyModel = $Model
@onready var trail: CPUParticles3D = $Trail


## Must be called before adding to the tree.
func setup(p_data: ToyData) -> void:
	data = p_data


func _ready() -> void:
	add_to_group("toys")
	var body := SphereShape3D.new()
	body.radius = data.radius
	shape.shape = body
	var hit := SphereShape3D.new()
	hit.radius = data.radius + 0.15
	hit_shape.shape = hit
	model.setup(data)
	trail.color = Color(data.color, 0.8)
	trail.mesh = Mats.sphere(data.radius * 0.55)
	var pm := Mats.unlit(Color.WHITE)
	pm.vertex_color_use_as_albedo = true
	trail.mesh.material = pm
	trail.emitting = false
	hit_area.body_entered.connect(_on_hit_area_body_entered)
	if global_position.y == 0.0:
		global_position.y = data.radius


func is_dangerous() -> bool:
	return state == State.FLYING and velocity.length() >= data.danger_speed


func can_be_caught_by(dog: Dog) -> bool:
	return not (dog == thrower and _owner_immune)


# ---------------------------------------------------------------- state changes

func pick_up(dog: Dog) -> void:
	state = State.HELD
	holder = dog
	thrower = null
	velocity = Vector3.ZERO
	bounces = 0
	_owner_immune = false
	_set_solid(false)
	dog.held_toy = self
	global_position = dog.get_hold_position()
	trail.emitting = false


func throw(dog: Dog, dir: Vector3, power: float) -> void:
	state = State.FLYING
	holder = null
	thrower = dog
	bounces = 0
	_owner_immune = true
	global_position = _safe_release_point(dog, dir)
	velocity = dir * data.throw_speed * power
	velocity.y = 0.0
	_set_solid(true)
	trail.emitting = true
	Juice.pop(model, 1.5, 0.2)


## Where the toy appears when released. Normally just in front of the dog's nose, but if a wall
## or prop is in the way (dog pressed against it) the toy is released short of it so it can never
## start inside or beyond a collider.
func _safe_release_point(dog: Dog, dir: Vector3) -> Vector3:
	var from := dog.global_position + Vector3(0, FLY_HEIGHT, 0)
	var to := from + dir * (dog.data.body_radius + data.radius + 0.2)
	var query := PhysicsRayQueryParameters3D.create(from, to + dir * data.radius, 1)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return to
	return (hit.position as Vector3) - dir * (data.radius + 0.05)


func drop(at: Vector3) -> void:
	state = State.IDLE
	holder = null
	thrower = null
	velocity = Vector3(randf_range(-1.0, 1.0), 0.0, randf_range(-1.0, 1.0)) * 2.0
	global_position = Vector3(at.x, data.radius, at.z)
	_set_solid(true)
	trail.emitting = false


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
					trail.emitting = false
			else:
				_check_pickup()
	_update_visuals(delta)


func _slide(delta: float) -> void:
	# Settle to ground height when slow, fly at FLY_HEIGHT when fast.
	var target_y := FLY_HEIGHT if state == State.FLYING else data.radius
	global_position.y = lerpf(global_position.y, target_y, minf(1.0, 10.0 * delta))
	if velocity == Vector3.ZERO:
		return
	var col := move_and_collide(velocity * delta)
	if col:
		var n := col.get_normal()
		n.y = 0.0
		if n.length_squared() > 0.001:
			velocity = velocity.bounce(n.normalized()) * data.bounciness
		velocity.y = 0.0
		bounces += 1
		_owner_immune = false
		if bounces > data.max_bounces:
			velocity *= 0.5
		if state == State.FLYING:
			Sfx.play("bounce", randf_range(0.9, 1.25), -4.0)
			Juice.shake(0.08)
			Juice.burst(get_parent(), global_position, Color(1, 1, 1, 0.8), 5, 2.5)
	velocity = velocity.move_toward(Vector3.ZERO, data.friction * delta)


func _check_hits() -> void:
	for body in hit_area.get_overlapping_bodies():
		_try_hit(body)


func _on_hit_area_body_entered(body: Node3D) -> void:
	_try_hit(body)


func _try_hit(body: Node3D) -> void:
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
		if holder:
			model.basis = Basis.looking_at(holder.facing, Vector3.UP)
		return
	_spin += velocity.length() * delta * 2.5
	model.rotation = Vector3(_spin * 0.3, _spin, 0.0)
