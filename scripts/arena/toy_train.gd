@tool
class_name ToyTrain
extends Node3D
## Toy Room gimmick: a wind-up train running laps of a wooden track. Every car is solid to dogs
## and toys alike (an AnimatableBody3D on the world layer), so a throw bounces off whichever car
## is passing - the lanes through the middle of the room open and shut as it goes round. A
## dog in its way is bumped aside, never hurt; loose toys on the rails get nudged off them.
##
## The track is a stadium loop: two straights joined by half circles, centred on this node.
## Lay it with a clear margin to every wall and prop (TRACK_CLEARANCE) and the train can never
## pin a dog against anything.

## Length of each straight, and the radius of the turns, in metres.
@export var straight := 7.2:
	set(v):
		straight = v
		_rebuild()
@export var turn_radius := 2.4:
	set(v):
		turn_radius = v
		_rebuild()
## Metres per second round the loop. Negative runs it the other way.
@export var speed := 3.0
## Engine plus this many carriages.
@export_range(0, 5) var carriages := 2
## Where along the loop the engine starts each round, in metres.
@export var start_distance := 0.0

## Car footprint: length along the track, height, width across it.
const CAR := Vector3(1.35, 1.0, 0.84)
const CAR_GAP := 0.25
## How hard a bumped dog is pushed aside, and how soon it can be bumped again.
const BUMP := 5.5
const REBUMP := 0.35
## Keep at least this much open floor between the rails and anything solid.
const TRACK_CLEARANCE := 1.6
const RAIL_WIDTH := 0.95

var distance := 0.0
var _cars: Array[AnimatableBody3D] = []
var _track: Node3D
var _cooldown: Dictionary = {}
var _puff := 0.0


func _ready() -> void:
	if not Engine.is_editor_hint():
		add_to_group("gimmicks")
	distance = start_distance
	_rebuild()


## Total length of one lap.
func loop_length() -> float:
	return straight * 2.0 + TAU * turn_radius


## Position (local, on the floor) and heading along the loop at [param s] metres.
func point_at(s: float) -> Transform3D:
	var total := loop_length()
	s = fposmod(s, total)
	var half := straight * 0.5
	var turn := PI * turn_radius
	var at := Vector3.ZERO
	var ahead := Vector3.RIGHT
	if s < straight:
		# Near straight, running +X along the front of the loop.
		at = Vector3(-half + s, 0, turn_radius)
		ahead = Vector3.RIGHT
	elif s < straight + turn:
		var angle := (s - straight) / turn_radius
		at = Vector3(half + sin(angle) * turn_radius, 0, cos(angle) * turn_radius)
		ahead = Vector3(cos(angle), 0, -sin(angle))
	elif s < straight * 2.0 + turn:
		at = Vector3(half - (s - straight - turn), 0, -turn_radius)
		ahead = Vector3.LEFT
	else:
		var angle := (s - straight * 2.0 - turn) / turn_radius
		at = Vector3(-half - sin(angle) * turn_radius, 0, -cos(angle) * turn_radius)
		ahead = Vector3(-cos(angle), 0, sin(angle))
	# A car's local +X is the way it is travelling.
	var basis := Basis(ahead, Vector3.UP, ahead.cross(Vector3.UP))
	return Transform3D(basis, at)


## True when a floor point is within [param margin] of the rails' centre line.
func near_track(point: Vector3, margin: float) -> bool:
	var local := to_local(Vector3(point.x, global_position.y, point.z))
	var half := straight * 0.5
	var nearest_x := clampf(local.x, -half, half)
	var off := Vector2(local.x - nearest_x, local.z)
	return absf(off.length() - turn_radius) < margin


## Back to the start of the loop for every round, so nothing spawns where the train was.
func reset_for_round() -> void:
	distance = start_distance
	_cooldown.clear()
	_place_cars()


## Where the engine is right now, for tests.
func engine_position() -> Vector3:
	return _cars[0].global_position if not _cars.is_empty() else global_position


func cars() -> Array[AnimatableBody3D]:
	return _cars


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	distance = fposmod(distance + speed * delta, loop_length())
	_place_cars()
	for key in _cooldown.keys():
		_cooldown[key] -= delta
		if _cooldown[key] <= 0.0:
			_cooldown.erase(key)
	for car in _cars:
		_clear_car(car, delta)
	_puff -= delta
	if _puff <= 0.0 and not _cars.is_empty():
		_puff = 0.45
		var stack := _cars[0].global_transform * Vector3(CAR.x * 0.28, CAR.y + 0.45, 0)
		Juice.burst(get_parent(), stack, Color(1, 1, 1, 0.75), 3, 0.8)


func _place_cars() -> void:
	var spacing := CAR.x + CAR_GAP
	var back := -signf(speed) if speed != 0.0 else -1.0
	for i in _cars.size():
		var t := point_at(distance + back * spacing * float(i))
		if speed < 0.0:
			# Running the other way round: the cars face back along the loop.
			t.basis = t.basis.rotated(Vector3.UP, PI)
		_cars[i].transform = t


## Pushes anything standing where this car now is out to the side it is on.
func _clear_car(car: AnimatableBody3D, _delta: float) -> void:
	var across := car.global_transform.basis.z.normalized()
	for node in get_tree().get_nodes_in_group("dogs"):
		var dog := node as Dog
		if dog == null or not dog.alive or not dog.can_process() or dog.is_burrowed():
			continue
		var local := car.to_local(dog.global_position)
		var reach := dog.effective_radius()
		if absf(local.x) > CAR.x * 0.5 + reach or absf(local.z) > CAR.z * 0.5 + reach:
			continue
		var side := 1.0 if local.z >= 0.0 else -1.0
		# Out of the car's way through the dog's own collider, never through a wall.
		var overlap := CAR.z * 0.5 + reach - absf(local.z)
		dog.move_and_collide(across * side * minf(overlap, 0.3))
		var id := dog.get_instance_id()
		if not _cooldown.has(id):
			_cooldown[id] = REBUMP
			dog.shove((across * side + car.global_transform.basis.x * 0.4).normalized() * BUMP)
			Sfx.play_at("bounce", dog.global_position, 1.2, -8.0)
	for node in get_tree().get_nodes_in_group("toys"):
		var toy := node as Toy
		if toy == null or toy.state != Toy.State.IDLE:
			continue
		var local := car.to_local(toy.global_position)
		var reach := toy.data.radius + 0.05
		if absf(local.x) > CAR.x * 0.5 + reach or absf(local.z) > CAR.z * 0.5 + reach:
			continue
		var side := 1.0 if local.z >= 0.0 else -1.0
		var overlap := CAR.z * 0.5 + reach - absf(local.z)
		toy.global_position += across * side * overlap
		toy.velocity = across * side * 3.5 + car.global_transform.basis.x * absf(speed)


func _rebuild() -> void:
	if not is_inside_tree():
		return
	for car in _cars:
		if is_instance_valid(car):
			car.queue_free()
	_cars.clear()
	if is_instance_valid(_track):
		_track.queue_free()
	_track = Node3D.new()
	add_child(_track)
	_build_track()
	var paints := [Color("e2533f"), Color("3f86e0"), Color("f2c84b"), Color("5bb06a"), Color("b46fd0")]
	for i in carriages + 1:
		var car := AnimatableBody3D.new()
		car.name = "Engine" if i == 0 else "Car%d" % i
		car.sync_to_physics = false
		car.collision_layer = 1
		car.collision_mask = 0
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = CAR
		shape.shape = box
		shape.position.y = CAR.y * 0.5
		car.add_child(shape)
		add_child(car)
		if i == 0:
			_build_engine(car)
		else:
			_build_wagon(car, paints[i % paints.size()], i)
		_cars.append(car)
	_place_cars()


func _build_track() -> void:
	var wood := Color("c99561")
	var groove := Color("7e5232")
	# One long wooden strip, laid as short planks so it follows the turns.
	var total := loop_length()
	var pieces := int(ceil(total / 0.5))
	for i in pieces:
		var s := (float(i) + 0.5) * total / float(pieces)
		var t := point_at(s)
		var plank := ArenaArt.block(_track, Vector3(total / float(pieces) + 0.03, 0.05, RAIL_WIDTH), wood if i % 2 == 0 else wood.lightened(0.04),
			t.origin + Vector3(0, 0.025, 0), Vector3.ZERO, 0.012)
		plank.basis = t.basis
		plank.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		for side: float in [-1.0, 1.0]:
			var line := Mats.mesh_plain(_track, Mats.box(Vector3(total / float(pieces) + 0.03, 0.006, 0.07)), groove,
				t.origin + t.basis.z * side * 0.22 + Vector3(0, 0.053, 0))
			line.basis = t.basis
			line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _build_engine(car: Node3D) -> void:
	var red := Color("e2533f")
	var navy := Color("2f4a7a")
	ArenaArt.block(car, Vector3(CAR.x, 0.16, CAR.z), Color("3a3a42"), Vector3(0, 0.2, 0), Vector3.ZERO, 0.04)
	# Boiler out front, cab at the back, a chimney you can see puffing from across the room.
	var boiler := Mats.mesh(car, Mats.cylinder(0.3, CAR.x * 0.62), red, Vector3(CAR.x * 0.17, 0.55, 0), Vector3(0, 0, 90))
	boiler.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	Mats.mesh(car, Mats.cylinder(0.31, 0.06), Color("f2c84b"), Vector3(CAR.x * 0.1, 0.55, 0), Vector3(0, 0, 90))
	Mats.mesh(car, Mats.cylinder(0.31, 0.06), Color("f2c84b"), Vector3(CAR.x * 0.33, 0.55, 0), Vector3(0, 0, 90))
	ArenaArt.block(car, Vector3(CAR.x * 0.38, 0.72, CAR.z * 0.96), navy, Vector3(-CAR.x * 0.3, 0.62, 0), Vector3.ZERO, 0.06)
	ArenaArt.block(car, Vector3(CAR.x * 0.46, 0.08, CAR.z + 0.06), red, Vector3(-CAR.x * 0.3, 1.0, 0), Vector3.ZERO, 0.03)
	for side: float in [-1.0, 1.0]:
		ArenaArt.block(car, Vector3(0.24, 0.22, 0.02), Color("fff1c6"), Vector3(-CAR.x * 0.3, 0.72, side * CAR.z * 0.49), Vector3.ZERO, 0.01)
	Mats.mesh(car, Mats.cylinder(0.1, 0.34, 0.15), Color("2a2c30"), Vector3(CAR.x * 0.3, 0.98, 0))
	Mats.mesh(car, Mats.sphere(0.075), Color("ffd98a"), Vector3(CAR.x * 0.5, 0.55, 0))
	ArenaArt.block(car, Vector3(0.1, 0.18, CAR.z * 0.9), Color("f2c84b"), Vector3(CAR.x * 0.5, 0.24, 0), Vector3.ZERO, 0.03)
	_wheels(car, Color("f2c84b"))
	Mats.contact_shadow(car, CAR.x * 0.5)


func _build_wagon(car: Node3D, paint: Color, index: int) -> void:
	ArenaArt.block(car, Vector3(CAR.x, 0.16, CAR.z), Color("3a3a42"), Vector3(0, 0.2, 0), Vector3.ZERO, 0.04)
	# An open wagon: four painted sides around a load of building blocks or balls.
	ArenaArt.block(car, Vector3(CAR.x * 0.92, 0.5, CAR.z * 0.96), paint, Vector3(0, 0.52, 0), Vector3.ZERO, 0.06)
	ArenaArt.block(car, Vector3(CAR.x * 0.8, 0.04, CAR.z * 0.8), paint.darkened(0.35), Vector3(0, 0.78, 0), Vector3.ZERO, 0.02)
	var cargo := [Color("f2c84b"), Color("5bb06a"), Color("3f86e0"), Color("e2533f")]
	for j in 3:
		var tint: Color = cargo[(index + j) % cargo.size()]
		if index % 2 == 0:
			Mats.mesh(car, Mats.sphere(0.2), tint, Vector3((j - 1) * 0.36, 0.9, (0.08 if j == 1 else -0.06)))
		else:
			ArenaArt.block(car, Vector3(0.32, 0.32, 0.32), tint, Vector3((j - 1) * 0.36, 0.92 + (0.06 if j == 1 else 0.0), 0), Vector3(0, j * 17.0, 0), 0.04)
	_wheels(car, Color("fff1c6"))
	Mats.contact_shadow(car, CAR.x * 0.5)


func _wheels(car: Node3D, hub: Color) -> void:
	for x: float in [-CAR.x * 0.3, CAR.x * 0.3]:
		for side: float in [-1.0, 1.0]:
			Mats.mesh(car, Mats.cylinder(0.17, 0.08), Color("2a2c30"), Vector3(x, 0.17, side * (CAR.z * 0.5 + 0.02)), Vector3(90, 0, 0))
			Mats.mesh(car, Mats.cylinder(0.07, 0.1), hub, Vector3(x, 0.17, side * (CAR.z * 0.5 + 0.03)), Vector3(90, 0, 0))
