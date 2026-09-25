class_name Toy
extends CharacterBody3D
## Ground pickups are harmless. Only an outbound throw can hit a dog. Flight is
## swept in collision order so a fast toy cannot tunnel through a dog or a wall.
## Toys are solid to each other: a throw into a loose toy shunts it, and a hard enough
## shunt sends it off as a live carom credited to whoever started the chain.

enum State { IDLE, HELD, FLYING }

const FLY_HEIGHT := 0.72
const OWNER_GRACE := 0.38
## Share of the incoming toy's speed along the contact normal handed to the toy it struck.
const CAROM_TRANSFER := 0.78
## Both toys ignore each other for this long after a hit, so one contact resolves once.
const CONTACT_LOCK := 0.1

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
var _hit_dogs: Array[int] = []
var _pickup_halo: MeshInstance3D
var _pickup_shadow: MeshInstance3D
## How far the holder has this throw wound up, 0 to 1. Purely presentation.
var _wind_up := 0.0
var _contact_lock := 0.0
var power_effects: ToyPowerEffects
## A Scatter Fetch side toy: it flies and hits like the real thing, then vanishes instead of
## becoming another pickup, so a volley never litters the arena.
var ephemeral := false
var _life := 0.0
const EPHEMERAL_LIFE := 1.3

@onready var shape: CollisionShape3D = $Shape
@onready var hit_area: Area3D = $HitArea
@onready var hit_shape: CollisionShape3D = $HitArea/Shape
@onready var model: ToyModel = $Model
@onready var trail: CPUParticles3D = $Trail


func setup(p_data: ToyData) -> void:
	data = p_data


func _ready() -> void:
	add_to_group("toys")
	power_effects = ToyPowerEffects.new()
	add_child(power_effects)
	process_priority = 100
	var body := SphereShape3D.new()
	body.radius = data.radius
	shape.shape = body
	var hit := SphereShape3D.new()
	hit.radius = data.radius + 0.15
	hit_shape.shape = hit
	model.setup(data)
	_spin = float(posmod(get_instance_id(), 17)) * TAU / 17.0
	trail.color = Color(data.color, 0.65)
	trail.amount = 18
	trail.lifetime = 0.19
	trail.mesh = Mats.sphere(data.radius * 0.33)
	var pm := Mats.unlit(Color.WHITE)
	pm.vertex_color_use_as_albedo = true
	pm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	trail.mesh.material = pm
	var trail_fade := Gradient.new()
	trail_fade.set_color(0, Color(1, 1, 1, 0.8))
	trail_fade.set_color(1, Color(1, 1, 1, 0))
	trail.color_ramp = trail_fade
	var trail_taper := Curve.new()
	trail_taper.add_point(Vector2(0, 1))
	trail_taper.add_point(Vector2(1, 0.05))
	trail.scale_amount_curve = trail_taper
	trail.emitting = false
	var halo_color := Color(data.color.lerp(Color("fff3d6"), 0.35), 0.48)
	_pickup_halo = Mats.mesh(self, Mats.torus(data.radius + 0.12, data.radius + 0.138), halo_color)
	_pickup_halo.material_override = Mats.unlit(halo_color)
	_pickup_halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# The halo takes the toy's own colour, so a cream one lands invisible on kitchen lino or
	# courtyard stone. A dark backing ring under it reads on any floor. It is a child, so it
	# inherits the halo's position, scale and visibility for free.
	var backing := Color(0.13, 0.11, 0.1, 0.42)
	var edge := Mats.mesh(_pickup_halo, Mats.torus(data.radius + 0.10, data.radius + 0.162), backing, Vector3(0, -0.004, 0))
	edge.material_override = Mats.unlit(backing)
	edge.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_pickup_shadow = Mats.contact_shadow(self, data.radius * 0.80)
	if is_zero_approx(global_position.y):
		global_position.y = data.radius


func is_dangerous() -> bool:
	return state == State.FLYING and velocity.length() >= data.danger_speed


func can_be_caught_by(dog: Dog) -> bool:
	return is_dangerous() and not (dog == thrower and _owner_immune) and _visible_from(global_position, dog)


func pick_up(dog: Dog) -> void:
	power_effects.reset()
	model.visible = not dog.concealed
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
	_pickup_shadow.visible = false


## [param charge] is the wind-up that produced this throw, 0 to 1. It is already folded into
## [param power]; what it changes here is how loudly the shot reads in the air.
func throw(dog: Dog, dir: Vector3, power: float, charge: float = 0.0, snapshot: ToyPowerEffects = null) -> void:
	if snapshot != null:
		power_effects.copy_from(snapshot)
	else:
		power_effects.launch(dog)
	model.visible = true
	if dog.held_toy == self:
		dog.held_toy = null
	_wind_up = 0.0
	state = State.FLYING
	holder = null
	thrower = dog
	bounces = 0
	_owner_immune = true
	_owner_cleared = false
	_flight_time = 0.0
	_hit_dogs.clear()
	dir.y = 0.0
	dir = dog.facing if dir.length_squared() < 0.001 else dir.normalized()
	global_basis = Basis.IDENTITY
	global_position = _safe_release_point(dog, dir)
	velocity = dir * data.throw_speed * power
	_set_solid(true)
	model.scale = Vector3.ONE
	model.position = Vector3.ZERO
	trail.amount = int(18.0 + charge * 22.0)
	trail.lifetime = 0.19 + charge * 0.13
	_tint_trail(charge)
	trail.emitting = true
	_pickup_halo.visible = false
	_pickup_shadow.visible = false


## A plain throw trails the toy's own colour. A powered one trails its powers' colours - fading
## from one to the next when it carries two - so a shot can be read before it lands.
func _tint_trail(charge: float) -> void:
	var colors := power_effects.trail_colors()
	var fade := Gradient.new()
	if colors.is_empty():
		var tint := data.color.lerp(Color(1.0, 0.92, 0.55), charge * 0.6)
		trail.color = Color(tint, 0.65 + charge * 0.3)
		fade.set_color(0, Color(1, 1, 1, 0.8))
		fade.set_color(1, Color(1, 1, 1, 0))
	else:
		trail.color = Color(1, 1, 1, 0.95)
		trail.amount = maxi(trail.amount, 30)
		fade.set_color(0, Color(colors[0], 1.0))
		fade.set_color(1, Color(colors[colors.size() - 1], 0.0))
		if colors.size() > 2:
			fade.add_point(0.5, Color(colors[1], 0.7))
	trail.color_ramp = fade


## Set by the holder while it winds a throw up: the toy is cocked back and shivering.
func set_wind_up(value: float) -> void:
	_wind_up = clampf(value, 0.0, 1.0)


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
	power_effects.reset()
	model.visible = true
	if is_instance_valid(holder) and holder.held_toy == self:
		holder.held_toy = null
	state = State.IDLE
	holder = null
	thrower = null
	_wind_up = 0.0
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
	power_effects.reset()
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
	_contact_lock = maxf(0.0, _contact_lock - delta)
	match state:
		State.HELD:
			if not is_instance_valid(holder) or not holder.alive:
				drop(global_position)
		State.FLYING:
			_flight_time += delta
			_update_owner_immunity()
			power_effects.steer_toward(delta)
			_slide(delta)
			if state == State.FLYING and not is_dangerous():
				_settle()
		State.IDLE:
			_slide(delta)
			_check_pickup()
	_update_visuals(delta)
	power_effects.tick(delta)
	if ephemeral:
		_life += delta
		# A fused side toy waits for its burst; otherwise it goes once spent or out of time.
		if power_effects.fuse_left < 0.0 and (state != State.FLYING or _life > EPHEMERAL_LIFE):
			vanish()


## A side toy leaving the arena: a puff where it was, nothing left behind.
func vanish() -> void:
	if is_queued_for_deletion():
		return
	Juice.burst(get_parent(), global_position, data.color.lightened(0.4), 6, 2.0)
	remove_from_group("toys")
	queue_free()


func _update_owner_immunity() -> void:
	if not _owner_immune or not is_instance_valid(thrower):
		return
	var separation := Vector2(global_position.x - thrower.global_position.x, global_position.z - thrower.global_position.z).length()
	if separation > thrower.data.body_radius + data.radius + 0.75:
		_owner_cleared = true
	if bounces > 0 and _owner_cleared and _flight_time >= OWNER_GRACE:
		_owner_immune = false


func _slide(delta: float) -> void:
	# Flight rides whatever deck is underneath, so a throw up the A-frame reaches the dog on it.
	var ground := Terrain.ground_height(self, global_position)
	var target_y := ground + (FLY_HEIGHT if state == State.FLYING else data.radius)
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
			power_effects.travel(start, end)
			_trace_dogs(start, end)
		if state != State.FLYING and state != State.IDLE:
			return
		if not collision:
			break
		var normal := collision.get_normal()
		normal.y = 0.0
		if normal.length_squared() < 0.001:
			break
		normal = normal.normalized()
		var struck := collision.get_collider() as Toy
		if struck != null:
			if not _strike_toy(struck, normal):
				break
			remaining *= collision.get_remainder().length() / maxf(motion.length(), 0.001)
			continue
		# A doorway in the wall takes the toy instead of bouncing it. Throws only: a toy
		# nudged along the floor is not something anyone meant to send.
		if state == State.FLYING and Portal.catch_toy(self, collision.get_position()):
			remaining *= collision.get_remainder().length() / maxf(motion.length(), 0.001)
			continue
		if state == State.FLYING and collision.get_collider() is DogBed:
			(collision.get_collider() as DogBed).take_hit(velocity)
		bounces += 1
		var banking := state == State.FLYING and power_effects.bank and not power_effects._banked
		if state == State.FLYING and not banking:
			power_effects.impact()
		if state == State.FLYING and data.special == ToyData.Special.HEAVY:
			velocity = Vector3.ZERO
			_settle()
			break
		velocity = velocity.bounce(normal) * data.bounciness
		velocity.y = 0.0
		if banking:
			power_effects.bank_bounce()
		if bounces > data.max_bounces:
			velocity *= 0.5
		if state == State.FLYING:
			Sfx.toy_impact(data.id, velocity.length(), global_position)
			Juice.burst(get_parent(), global_position, data.color.lightened(0.35), 4, 1.8)
		remaining *= collision.get_remainder().length() / maxf(motion.length(), 0.001)
		_update_owner_immunity()
	velocity = velocity.move_toward(Vector3.ZERO, data.friction * delta)


## Toy against toy. Whatever this one carries into the contact is mostly handed over, and a
## loose toy shunted hard enough leaves as a live carom credited to whoever started the chain -
## a throw into a pile is a real play. Returns false when the contact was already resolved.
func _strike_toy(other: Toy, normal: Vector3) -> bool:
	if _contact_lock > 0.0 or other._contact_lock > 0.0:
		return false
	var push := -normal
	var impact := maxf(0.0, velocity.dot(push))
	bounces += 1
	other._receive_strike(push * impact * CAROM_TRANSFER, self)
	if state == State.FLYING:
		power_effects.impact()
	if data.special == ToyData.Special.HEAVY:
		# "Ploughs through dogs, stops at walls" holds here too: it shoves and carries on.
		# The bounce budget is a wall rule, so it does not also tax a toy it barged past.
		velocity *= 0.72
	else:
		# Only the part aimed into the other toy is spent, so a graze keeps its line and a
		# square hit hands nearly everything over and kicks back a little.
		var into := minf(0.0, velocity.dot(normal))
		velocity -= normal * into * (1.0 + data.bounciness * 0.3)
		if bounces > data.max_bounces:
			velocity *= 0.6
	velocity.y = 0.0
	_contact_lock = CONTACT_LOCK
	if state == State.FLYING:
		Sfx.play_at("bounce", global_position, randf_range(1.28, 1.52), -7.0)
		Juice.burst(get_parent(), (global_position + other.global_position) * 0.5,
			data.color.lerp(other.data.color, 0.5).lightened(0.3), 7, 2.8)
	_update_owner_immunity()
	return true


## The struck side of a contact: take the shove, and arm if it was hard enough to be lethal.
func _receive_strike(impulse: Vector3, from: Toy) -> void:
	_contact_lock = CONTACT_LOCK
	velocity += impulse
	velocity.y = 0.0
	if state == State.IDLE and velocity.length() >= data.danger_speed:
		# Caroms transfer the shooter's behavior snapshot as well as attribution.
		power_effects.reset()
		power_effects.blast = from.power_effects.blast
		power_effects.mud = from.power_effects.mud
		state = State.FLYING
		thrower = from.thrower
		bounces = 0
		_flight_time = 0.0
		_hit_dogs.clear()
		# The carom inherits the throw's owner rules, so nobody is bonked point-blank by a
		# toy they set off at their own feet.
		_owner_immune = is_instance_valid(thrower)
		_owner_cleared = false
		trail.emitting = true
		_pickup_halo.visible = false
		_pickup_shadow.visible = false
		# Only an armed carom is briefly out of reach. A toy that was merely shoved stays a
		# pickup, so a jostling pile can never make itself unfetchable.
		_pickup_delay = maxf(_pickup_delay, 0.15)


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
		var radius := dog.effective_radius() + data.radius
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
		power_effects.impact()
		# A heavy toy carries on through; everything else is mostly spent by the hit.
		velocity *= 0.8 if data.special == ToyData.Special.HEAVY else 0.36


func _check_pickup() -> void:
	if _pickup_delay > 0.0 or ephemeral:
		return
	# Centre distance keeps pickup reliable even while the dog's render pose turns.
	for body in get_tree().get_nodes_in_group("dogs"):
		var dog := body as Dog
		var gap := Vector2(global_position.x - dog.global_position.x, global_position.z - dog.global_position.z)
		if gap.length() <= dog.effective_radius() + data.radius + 0.18 and _visible_from(global_position + Vector3.UP * 0.25, dog):
			if dog.try_pickup(self):
				return


func _settle() -> void:
	state = State.IDLE
	_owner_immune = false
	_pickup_delay = 0.12
	trail.emitting = false


func _update_held_transform() -> void:
	global_transform = holder.get_hold_transform()
	model.position = Vector3.ZERO
	model.rotation_degrees = data.held_rotation
	model.scale = Vector3.ONE * data.held_scale
	if _wind_up > 0.0:
		# Cocked back in the mouth and shivering, so the throw builds where you are looking.
		var shiver := sin(Time.get_ticks_msec() * 0.055) * 0.022 * _wind_up
		model.position = Vector3(shiver, 0.0, 0.12 * _wind_up)
		model.scale *= 1.0 + 0.08 * _wind_up


func _update_visuals(delta: float) -> void:
	_pickup_halo.visible = state == State.IDLE
	_pickup_shadow.visible = state == State.IDLE
	if state == State.HELD:
		if is_instance_valid(holder):
			_update_held_transform()
		return
	model.scale = Vector3.ONE
	if state == State.IDLE:
		var t := Time.get_ticks_msec() * 0.001
		var floor_y := Terrain.ground_height(self, global_position)
		_pickup_halo.global_position = Vector3(global_position.x, floor_y + 0.035, global_position.z)
		_pickup_halo.scale = Vector3.ONE * (1.0 + sin(t * 2.0) * 0.035)
		_pickup_shadow.global_position = Vector3(global_position.x, floor_y + 0.018, global_position.z)
		var resting_height := data.ground_height if data.ground_height >= 0.0 else data.radius
		var settle := minf(1.0, delta * 14.0)
		model.position.y = lerpf(model.position.y, resting_height - data.radius + sin(t * 2.0 + get_instance_id() % 7) * 0.009, settle)
		model.rotation = Vector3(lerp_angle(model.rotation.x, 0.0, settle), lerp_angle(model.rotation.y, _spin, settle), lerp_angle(model.rotation.z, 0.0, settle))
	else:
		model.position = Vector3.ZERO
		if ephemeral:
			model.scale = Vector3.ONE * 0.8
		_spin += velocity.length() * delta * 1.5
		model.rotation = Vector3(0.0, _spin, 0.0) if data.flat_spin else Vector3(_spin * 0.35, _spin, 0.0)
