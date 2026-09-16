class_name Toy
extends CharacterBody3D
## Ground pickups are harmless. Only an outbound throw can hit a dog. Flight is
## swept in collision order so a fast toy cannot tunnel through a dog or a wall.

enum State { IDLE, HELD, FLYING }

const FLY_HEIGHT := 0.72
const OWNER_GRACE := 0.38

var data: ToyData
var state := State.IDLE
var holder: Dog = null
var thrower: Dog = null
var bounces := 0
var _owner_immune := false
var _owner_cleared := false
var _flight_time := 0.0
var _pickup_delay := 0.0
var _spin := 0.0
var _squeaked := false
var _hit_dogs: Array[int] = []
var _pickup_halo: MeshInstance3D

@onready var shape: CollisionShape3D = $Shape
@onready var hit_area: Area3D = $HitArea
@onready var hit_shape: CollisionShape3D = $HitArea/Shape
@onready var model: ToyModel = $Model
@onready var trail: CPUParticles3D = $Trail


func setup(p_data: ToyData) -> void:
	data = p_data


func _ready() -> void:
	add_to_group("toys")
	process_priority = 100
	var body := SphereShape3D.new()
	body.radius = data.radius
	shape.shape = body
	var hit := SphereShape3D.new()
	hit.radius = data.radius + 0.15
	hit_shape.shape = hit
	model.setup(data)
	trail.color = Color(data.color, 0.65)
	trail.amount = 18
	trail.lifetime = 0.19
	trail.mesh = Mats.sphere(data.radius * 0.33)
	var pm := Mats.unlit(Color.WHITE)
	pm.vertex_color_use_as_albedo = true
	trail.mesh.material = pm
	trail.emitting = false
	_pickup_halo = Mats.mesh(self, Mats.torus(data.radius + 0.14, data.radius + 0.18), Color(data.color, 0.48))
	_pickup_halo.material_override = Mats.unlit(Color(data.color, 0.48))
	_pickup_halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if is_zero_approx(global_position.y):
		global_position.y = data.radius


func is_dangerous() -> bool:
	return state == State.FLYING and velocity.length() >= data.danger_speed


func can_be_caught_by(dog: Dog) -> bool:
	return is_dangerous() and not (dog == thrower and _owner_immune) and _visible_from(global_position, dog)


func pick_up(dog: Dog) -> void:
	if is_instance_valid(holder) and holder != dog and holder.held_toy == self:
		holder.held_toy = null
	state = State.HELD
	holder = dog
	thrower = null
	velocity = Vector3.ZERO
	bounces = 0
	_owner_immune = false
	_hit_dogs.clear()
	_set_solid(false)
	dog.held_toy = self
	_update_held_transform()
	trail.emitting = false
	_pickup_halo.visible = false


func throw(dog: Dog, dir: Vector3, power: float) -> void:
	if dog.held_toy == self:
		dog.held_toy = null
	state = State.FLYING
	holder = null
	thrower = dog
	bounces = 0
	_owner_immune = true
	_owner_cleared = false
	_flight_time = 0.0
	_squeaked = false
	_hit_dogs.clear()
	dir.y = 0.0
	dir = dog.facing if dir.length_squared() < 0.001 else dir.normalized()
	global_basis = Basis.IDENTITY
	global_position = _safe_release_point(dog, dir)
	velocity = dir * data.throw_speed * power
	_set_solid(true)
	model.scale = Vector3.ONE
	model.position = Vector3.ZERO
	trail.emitting = true
	_pickup_halo.visible = false


## Release before the nearest wall. A short blocked throw retains owner immunity
## until it has both cleared the dog and spent enough time in flight.
func _safe_release_point(dog: Dog, dir: Vector3) -> Vector3:
	var from := dog.global_position + Vector3(0, FLY_HEIGHT, 0)
	var to := from + dir * (dog.data.body_radius + data.radius + 0.12)
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape.shape
	query.transform = Transform3D(Basis.IDENTITY, from)
	query.motion = to - from
	query.collision_mask = 1
	query.margin = 0.035
	var result := get_world_3d().direct_space_state.cast_motion(query)
	return from.lerp(to, result[0])


func drop(at: Vector3) -> void:
	if is_instance_valid(holder) and holder.held_toy == self:
		holder.held_toy = null
	state = State.IDLE
	holder = null
	thrower = null
	_owner_immune = false
	_pickup_delay = 0.38
	velocity = Vector3(randf_range(-1.0, 1.0), 0.0, randf_range(-1.0, 1.0)) * 2.0
	global_basis = Basis.IDENTITY
	global_position = Vector3(at.x, data.radius, at.z)
	model.scale = Vector3.ONE
	_set_solid(true)
	trail.emitting = false


## Shield impacts are defused instead of producing a second point-blank hit.
func deflect_from(dog: Dog) -> void:
	state = State.IDLE
	_owner_immune = false
	_pickup_delay = 0.45
	var away := global_position - dog.global_position
	away.y = 0.0
	velocity = away.normalized() * 3.0
	trail.emitting = false


func _set_solid(solid: bool) -> void:
	shape.set_deferred("disabled", not solid)
	hit_shape.set_deferred("disabled", not solid)


## Follow the rendered pose after animation processing, including eased turns.
func _process(_delta: float) -> void:
	if state == State.HELD and is_instance_valid(holder):
		_update_held_transform()


func _physics_process(delta: float) -> void:
	_pickup_delay = maxf(0.0, _pickup_delay - delta)
	match state:
		State.HELD:
			if not is_instance_valid(holder) or not holder.alive:
				drop(global_position)
		State.FLYING:
			_flight_time += delta
			_update_owner_immunity()
			_slide(delta)
			if state == State.FLYING and not is_dangerous():
				_settle()
		State.IDLE:
			_slide(delta)
			_check_pickup()
	_update_visuals(delta)


func _update_owner_immunity() -> void:
	if not _owner_immune or not is_instance_valid(thrower):
		return
	var separation := Vector2(global_position.x - thrower.global_position.x, global_position.z - thrower.global_position.z).length()
	if separation > thrower.data.body_radius + data.radius + 0.75:
		_owner_cleared = true
	if bounces > 0 and _owner_cleared and _flight_time >= OWNER_GRACE:
		_owner_immune = false


func _slide(delta: float) -> void:
	var target_y := FLY_HEIGHT if state == State.FLYING else data.radius
	global_position.y = lerpf(global_position.y, target_y, minf(1.0, 12.0 * delta))
	var remaining := delta
	# Trace each segment before reflecting. Never trace through the wall and back.
	for _step in 3:
		if velocity.length_squared() < 0.001 or remaining <= 0.0001:
			break
		var start := global_position
		var motion := velocity * remaining
		var collision := move_and_collide(motion)
		var end := global_position
		if state == State.FLYING:
			_trace_dogs(start, end)
		if state != State.FLYING and state != State.IDLE:
			return
		if not collision:
			break
		var normal := collision.get_normal()
		normal.y = 0.0
		if normal.length_squared() < 0.001:
			break
		bounces += 1
		if state == State.FLYING and data.special == ToyData.Special.HEAVY:
			velocity = Vector3.ZERO
			_settle()
			break
		velocity = velocity.bounce(normal.normalized()) * data.bounciness
		velocity.y = 0.0
		if bounces > data.max_bounces:
			velocity *= 0.5
		if state == State.FLYING:
			Sfx.play("bounce", randf_range(0.96, 1.15), -9.0)
			Juice.burst(get_parent(), global_position, data.color.lightened(0.35), 4, 1.8)
			if data.special == ToyData.Special.SQUEAK:
				_squeak()
		remaining *= collision.get_remainder().length() / maxf(motion.length(), 0.001)
		_update_owner_immunity()
	velocity = velocity.move_toward(Vector3.ZERO, data.friction * delta)


## Circle sweep in the movement plane, ordered by first contact. The separate
## visibility check keeps a dog's generous hit volume from reaching through props.
func _trace_dogs(from: Vector3, to: Vector3) -> void:
	if not is_dangerous():
		return
	var start := Vector2(from.x, from.z)
	var segment := Vector2(to.x - from.x, to.z - from.z)
	var contacts: Array[Dictionary] = []
	for node in get_tree().get_nodes_in_group("dogs"):
		var dog := node as Dog
		if not dog.alive or (dog == thrower and _owner_immune) or _hit_dogs.has(dog.get_instance_id()):
			continue
		var offset := start - Vector2(dog.global_position.x, dog.global_position.z)
		var radius := dog.data.body_radius + data.radius
		var a := segment.length_squared()
		var c := offset.length_squared() - radius * radius
		var contact := 0.0
		if c > 0.0:
			if a < 0.000001:
				continue
			var b := 2.0 * offset.dot(segment)
			var discriminant := b * b - 4.0 * a * c
			if discriminant < 0.0:
				continue
			contact = (-b - sqrt(discriminant)) / (2.0 * a)
			if contact < 0.0 or contact > 1.0:
				continue
		contacts.append({"dog": dog, "t": contact})
	contacts.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.t < b.t)
	for contact in contacts:
		if not is_dangerous():
			break
		_try_hit(contact.dog, from.lerp(to, contact.t))


func _visible_from(from: Vector3, dog: Dog) -> bool:
	var target := dog.global_position + Vector3(0, FLY_HEIGHT, 0)
	var query := PhysicsRayQueryParameters3D.create(from, target, 1)
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()


func _try_hit(body: Node3D, contact: Vector3 = Vector3.INF) -> void:
	if not is_dangerous() or not (body is Dog):
		return
	var dog := body as Dog
	if (dog == thrower and _owner_immune) or _hit_dogs.has(dog.get_instance_id()):
		return
	var at := global_position if contact == Vector3.INF else contact
	if not _visible_from(at, dog):
		return
	if dog.hit_by(self):
		_hit_dogs.append(dog.get_instance_id())
		if state != State.FLYING: # Shield defused this impact.
			return
		if data.special == ToyData.Special.SQUEAK:
			_squeak()
		if data.special == ToyData.Special.HEAVY:
			velocity *= 0.8
		elif data.special == ToyData.Special.KNOCKBACK:
			velocity *= 0.25
		else:
			velocity *= 0.36


func _check_pickup() -> void:
	if _pickup_delay > 0.0:
		return
	# Centre distance keeps pickup reliable even while the dog's render pose turns.
	for body in get_tree().get_nodes_in_group("dogs"):
		var dog := body as Dog
		var gap := Vector2(global_position.x - dog.global_position.x, global_position.z - dog.global_position.z)
		if gap.length() <= dog.data.body_radius + data.radius + 0.18 and _visible_from(global_position + Vector3.UP * 0.25, dog):
			if dog.try_pickup(self):
				return


func _settle() -> void:
	if data.special == ToyData.Special.SQUEAK:
		_squeak()
	state = State.IDLE
	_owner_immune = false
	_pickup_delay = 0.12
	trail.emitting = false


func _squeak() -> void:
	if _squeaked:
		return
	_squeaked = true
	Sfx.play("squeak", randf_range(0.94, 1.08), -2.0)
	Juice.burst(get_parent(), global_position, Color(1.0, 0.82, 0.25), 16, 3.8)
	Juice.float_text(get_parent(), global_position + Vector3.UP * 0.5, "SQUEAK!", Color(1.0, 0.88, 0.4), 0.55)
	for body in get_tree().get_nodes_in_group("dogs"):
		var dog := body as Dog
		if dog == thrower or not dog.alive or dog.global_position.distance_to(global_position) > 2.4:
			continue
		if _visible_from(global_position, dog):
			dog.receive_toy_impulse(dog.global_position - global_position, 3.0, 0.7, true)


func _update_held_transform() -> void:
	global_transform = holder.get_hold_transform()
	model.position = Vector3.ZERO
	model.rotation_degrees = data.held_rotation
	model.scale = Vector3.ONE * data.held_scale


func _update_visuals(delta: float) -> void:
	_pickup_halo.visible = state == State.IDLE
	if state == State.HELD:
		if is_instance_valid(holder):
			_update_held_transform()
		return
	model.scale = Vector3.ONE
	if state == State.IDLE:
		var t := Time.get_ticks_msec() * 0.001
		_pickup_halo.global_position = Vector3(global_position.x, 0.035, global_position.z)
		_pickup_halo.scale = Vector3.ONE * (1.0 + sin(t * 3.0) * 0.07)
		var resting_height := data.ground_height if data.ground_height >= 0.0 else data.radius
		model.position.y = resting_height - data.radius + sin(t * 2.5 + get_instance_id() % 7) * 0.018
		model.rotation = Vector3(0.0, _spin, 0.0)
	else:
		model.position = Vector3.ZERO
		_spin += velocity.length() * delta * 1.5
		model.rotation = Vector3(0.0, _spin, 0.0) if data.flat_spin else Vector3(_spin * 0.35, _spin, 0.0)
