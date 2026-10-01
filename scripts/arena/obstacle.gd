@tool
class_name Obstacle
extends StaticBody3D
## A solid prop. Pick a [member kind] and a footprint [member size]; the visual is built from
## crafted beveled forms; the collider stays the authored footprint box.
## CUSTOM leaves the visual root available for map-specific scenery.
##
## Two kinds are routes rather than walls. A TUNNEL keeps only its two side walls, so the tube
## is open end to end. A RAMP keeps only its side rails and reports a deck height through
## [Terrain], so dogs and toys run up and over it. Both are still solid from the side.

enum Kind { BOX, CRATE, DOGHOUSE, TABLE, BUSH, COUCH, ARMCHAIR, TV, PLANT, TIRE, CUSTOM,
	RAMP, TUNNEL, WEAVE, COUNTER, FRIDGE, UMBRELLA, ROCK, COOLER,
	SNOWMAN, DRIFT, BLOCKS, TOY_CHEST }

@export var kind := Kind.BOX:
	set(v):
		kind = v
		_rebuild()
@export var size := Vector3(2, 1.4, 2):
	set(v):
		size = v
		_rebuild()
@export var color := Color(0.8, 0.62, 0.38):
	set(v):
		color = v
		_rebuild()
@export var accent := Color(0.55, 0.38, 0.2):
	set(v):
		accent = v
		_rebuild()

## Cover that does not last: thrown toys wear it down and it splinters, then it is back next
## round. A charged throw counts double.
@export var breakable := false
@export_range(1, 8) var toughness := 3
## Hits that count double: anything thrown at least this fast (a wound-up throw).
const HARD_HIT_SPEED := 14.0

const OCCLUDED_OPACITY := 0.22
const OCCLUSION_CHECK_INTERVAL := 0.075
## Side walls and rails on the props you can cross.
const WALL_THICKNESS := 0.17
## How far a rail stands above the deck it guards.
const RAIL_HEIGHT := 0.46
## Sight-line-only bodies live here, where nothing else looks.
const OCCLUSION_LAYER := 16

var _shapes: Array[CollisionShape3D] = []
var _occluder: StaticBody3D
var _visual: Node3D
var _opacity := 1.0
var _target_opacity := 1.0
var _occlusion_timer := 0.0
var _fade_materials: Array[StandardMaterial3D] = []
var _base_colors: Array[Color] = []
var _base_transparency: Array[int] = []
var _fade_meshes: Array[MeshInstance3D] = []
var _base_shadows: Array[int] = []
var _shadow_proxies: Array[MeshInstance3D] = []
var _ground_shade: MeshInstance3D
var _hits_left := 0
var _broken := false
var _rubble: Node3D


func _ready() -> void:
	collision_layer = 1
	collision_mask = 0
	_hits_left = toughness
	_rebuild()
	set_physics_process(not Engine.is_editor_hint())


func _rebuild() -> void:
	if not is_inside_tree():
		return
	_build_colliders()
	if _ground_shade != null and is_instance_valid(_ground_shade):
		_ground_shade.queue_free()
	# Seats the prop on the ground. Without it a primitive reads as hovering over the grass.
	var longest_side := maxf(size.x, size.z)
	_ground_shade = Mats.contact_shadow(self, longest_side * 0.53, Vector3(0, 0.024, 0))
	_ground_shade.scale = Vector3(size.x / longest_side, 1, size.z / longest_side)
	# Contact shading follows a bench/counter footprint instead of making every prop
	# sit on a large circular spot; the directional light supplies the cast shadow.
	(_ground_shade.material_override as StandardMaterial3D).albedo_color.a = 0.18
	if _visual:
		_visual.queue_free()
	_visual = Node3D.new()
	add_child(_visual)
	match kind:
		Kind.CRATE:
			_crate()
		Kind.DOGHOUSE:
			_doghouse()
		Kind.TABLE:
			_table()
		Kind.BUSH:
			_bush()
		Kind.COUCH, Kind.ARMCHAIR:
			_seat()
		Kind.TV:
			_tv()
		Kind.PLANT:
			_plant()
		Kind.TIRE:
			_tire()
		Kind.RAMP:
			_ramp()
		Kind.TUNNEL:
			_tunnel()
		Kind.WEAVE:
			_weave()
		Kind.COUNTER:
			_counter()
		Kind.FRIDGE:
			_fridge()
		Kind.UMBRELLA:
			_umbrella()
		Kind.ROCK:
			_rock()
		Kind.COOLER:
			_cooler()
		Kind.SNOWMAN:
			_snowman()
		Kind.DRIFT:
			_drift()
		Kind.BLOCKS:
			_blocks()
		Kind.TOY_CHEST:
			_toy_chest()
		Kind.CUSTOM:
			pass
		_:
			_block(size, color, Vector3(0, size.y * 0.5, 0), 0.12)

	if not Engine.is_editor_hint():
		_prepare_occlusion_materials()


## Solid props are one footprint box. A tunnel is two walls with open ends, an A-frame is two
## rails with an open deck; both keep a sight-line-only body over the whole footprint so a dog
## inside or behind them still fades the prop out.
func _build_colliders() -> void:
	for shape in _shapes:
		shape.queue_free()
	_shapes.clear()
	if is_instance_valid(_occluder):
		_occluder.queue_free()
	_occluder = null
	if is_in_group(Terrain.GROUP):
		remove_from_group(Terrain.GROUP)
	match kind:
		Kind.TUNNEL:
			for side: float in [-1.0, 1.0]:
				_collider(Vector3(size.x, size.y, WALL_THICKNESS),
					Vector3(0, size.y * 0.5, side * (size.z - WALL_THICKNESS) * 0.5))
			_build_occluder()
		Kind.RAMP:
			add_to_group(Terrain.GROUP)
			for spec: Array in _rail_segments():
				_collider(spec[1], spec[0])
			_build_occluder()
		_:
			_collider(size, Vector3(0, size.y * 0.5, 0))


func _collider(dimensions: Vector3, at: Vector3) -> void:
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = dimensions
	shape.shape = box
	shape.position = at
	add_child(shape)
	_shapes.append(shape)


## Nothing collides with this body; it is only there for the sight-line test that fades props,
## which would otherwise see straight through an open tunnel and leave a dog hidden inside it.
func _build_occluder() -> void:
	_occluder = StaticBody3D.new()
	_occluder.name = "Occluder"
	_occluder.collision_layer = OCCLUSION_LAYER
	_occluder.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.position = Vector3(0, size.y * 0.5, 0)
	_occluder.add_child(shape)
	add_child(_occluder)


## The A-frame deck: ground level at both ends, rising to the ridge in the middle.
func deck_height(local_x: float) -> float:
	var half := size.x * 0.5
	if half <= 0.0:
		return 0.0
	return size.y * clampf(1.0 - absf(local_x) / half, 0.0, 1.0)


## Walkable height at a world point, or 0 off the deck. Queried through [Terrain].
func surface_height(at: Vector3) -> float:
	if kind != Kind.RAMP:
		return 0.0
	var local := to_local(at)
	if absf(local.x) > size.x * 0.5 or absf(local.z) > size.z * 0.5:
		return 0.0
	return deck_height(local.x)


## Stepped rails following the deck profile, as [position, size] pairs. They are the ramp's
## only collision: you get on at either end and cannot walk off the side, so the climb is real.
func _rail_segments() -> Array:
	var steps := maxi(4, int(size.x / 0.75))
	var specs: Array = []
	for side: float in [-1.0, 1.0]:
		for i in steps:
			var x0 := -size.x * 0.5 + size.x * float(i) / float(steps)
			var x1 := -size.x * 0.5 + size.x * float(i + 1) / float(steps)
			var top := maxf(deck_height(x0), deck_height(x1)) + RAIL_HEIGHT
			specs.append([Vector3((x0 + x1) * 0.5, top * 0.5, side * (size.z - WALL_THICKNESS) * 0.5),
				Vector3(x1 - x0, top, WALL_THICKNESS)])
	return specs


func _block(dimensions: Vector3, tint: Color, at: Vector3, bevel: float = 0.055, rotation_deg: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	return ArenaArt.block(_visual, dimensions, tint, at, rotation_deg, bevel)


func _crate() -> void:
	var s := size
	_block(s * Vector3(0.94, 0.96, 0.94), color.darkened(0.12), Vector3(0, s.y * 0.5, 0))
	for i in 4:
		var y := (i + 0.5) * s.y / 4.0
		_block(Vector3(s.x, s.y / 4.0 - 0.028, s.z), color.lightened(i % 2 * 0.035), Vector3(0, y, 0), 0.035)
	for side in [-1.0, 1.0]:
		for x in [-s.x * 0.38, s.x * 0.38]:
			_block(Vector3(0.14, s.y, 0.075), accent, Vector3(x, s.y * 0.5, side * s.z * 0.5), 0.025)
		# A clean diagonal brace makes this silhouette a wooden crate even from above.
		var brace_length := Vector2(s.x * 0.65, s.y * 0.68).length()
		_block(Vector3(brace_length, 0.115, 0.06), accent.lightened(0.06), Vector3(0, s.y * 0.5, side * (s.z * 0.5 + 0.04)), 0.025,
			Vector3(0, 0, rad_to_deg(atan2(s.y * 0.68, s.x * 0.65))))
	for i in 4:
		_block(Vector3(s.x / 4.0 - 0.025, 0.075, s.z), color.lightened(0.09), Vector3(-s.x * 0.5 + (i + 0.5) * s.x / 4.0, s.y, 0), 0.02)


func _cooler() -> void:
	var s := size
	_block(Vector3(s.x * 0.95, s.y * 0.81, s.z * 0.95), color, Vector3(0, s.y * 0.44, 0), 0.11)
	_block(Vector3(s.x, s.y * 0.18, s.z), accent, Vector3(0, s.y * 0.91, 0), 0.07)
	_block(Vector3(s.x * 0.75, 0.024, s.z * 0.74), accent.darkened(0.07), Vector3(0, s.y + 0.01, 0), 0.012)
	for side in [-1.0, 1.0]:
		_block(Vector3(0.075, s.y * 0.30, s.z * 0.45), accent.darkened(0.18), Vector3(side * s.x * 0.48, s.y * 0.58, 0), 0.032)
		_block(Vector3(0.085, s.y * 0.12, s.z * 0.30), color.darkened(0.22), Vector3(side * s.x * 0.51, s.y * 0.61, 0), 0.025)
	_block(Vector3(s.x * 0.25, s.y * 0.16, 0.025), accent, Vector3(0, s.y * 0.48, s.z * 0.487), 0.025)
	_block(Vector3(s.x * 0.06, s.y * 0.22, 0.045), accent.darkened(0.22), Vector3(0, s.y * 0.79, s.z * 0.51), 0.015)


func _doghouse() -> void:
	var s := size
	var body_h := s.y * 0.65
	var roof_h := s.y - body_h
	_block(Vector3(s.x, body_h, s.z), color, Vector3(0, body_h * 0.5, 0), 0.065)
	for i in 4:
		_block(Vector3(s.x + 0.015, 0.025, s.z + 0.015), color.darkened(0.12), Vector3(0, body_h * (i + 1) / 5.0, 0), 0.005)
	for side in [-1.0, 1.0]:
		for z in [-s.z * 0.47, s.z * 0.47]:
			_block(Vector3(0.13, body_h, 0.14), Color("efd5ac"), Vector3(side * s.x * 0.47, body_h * 0.5, z), 0.025)
	Mats.mesh(_visual, Mats.prism(Vector3(s.x * 1.12, roof_h, s.z * 1.10)), accent, Vector3(0, body_h + roof_h * 0.5, 0))
	# Sloped roof boards and a cream eave are fitted to the actual triangular roof.
	var slope := rad_to_deg(atan2(roof_h, s.x * 0.56))
	var roof_length := Vector2(s.x * 0.56, roof_h).length()
	for side in [-1.0, 1.0]:
		for i in 5:
			_block(Vector3(roof_length, 0.065, s.z * 1.11 / 5.0 - 0.022), accent.lightened(0.04 if i % 2 == 0 else 0.0),
				Vector3(side * s.x * 0.28, body_h + roof_h * 0.5 + 0.035, -s.z * 0.55 + (i + 0.5) * s.z * 1.1 / 5.0),
				0.018, Vector3(0, 0, -side * slope))
	_block(Vector3(0.13, 0.11, s.z * 1.13), accent.lightened(0.18), Vector3(0, s.y + 0.04, 0), 0.04)
	var doorway_y := body_h * 0.37
	_block(Vector3(s.x * 0.47, body_h * 0.78, 0.07), Color("efd5ac"), Vector3(0, doorway_y, s.z * 0.5 + 0.02), 0.12)
	_block(Vector3(s.x * 0.36, body_h * 0.65, 0.075), Color("42372f"), Vector3(0, doorway_y - 0.04, s.z * 0.5 + 0.065), 0.10)
	_block(Vector3(s.x * 0.43, 0.10, 0.3), accent, Vector3(0, 0.05, s.z * 0.5 + 0.06), 0.03)


func _table() -> void:
	var s := size
	_block(Vector3(s.x * 0.92, 0.13, s.z * 0.88), accent, Vector3(0, s.y - 0.23, 0))
	for i in 5:
		_block(Vector3(s.x, 0.18, s.z / 5.0 - 0.024), color.lightened(0.035 * (i % 2)), Vector3(0, s.y - 0.09, -s.z * 0.5 + (i + 0.5) * s.z / 5.0), 0.055)
	for x in [-1.0, 1.0]:
		for z in [-1.0, 1.0]:
			_block(Vector3(0.16, s.y - 0.18, 0.16), accent, Vector3(x * (s.x * 0.5 - 0.23), (s.y - 0.18) * 0.5, z * (s.z * 0.5 - 0.22)), 0.035)
		_block(Vector3(0.12, 0.12, s.z * 0.8), accent.lightened(0.08), Vector3(x * (s.x * 0.5 - 0.23), s.y * 0.26, 0), 0.025)


func _bush() -> void:
	var s := size
	_block(Vector3(s.x * 0.93, 0.15, s.z * 0.94), accent.darkened(0.14), Vector3(0, 0.075, 0), 0.05)
	for i in 5:
		var x := ((i % 3) - 1) * s.x * 0.25
		var z := (-0.17 if i < 3 else 0.22) * s.z
		var foliage := Mats.mesh(_visual, Mats.sphere(0.5), color.lightened(i % 3 * 0.045), Vector3(x, s.y * (0.47 if i == 1 else 0.40), z))
		foliage.scale = Vector3(s.x * 0.48, s.y * (1.02 if i == 1 else 0.85), s.z * 0.68)
	for i in 3:
		ArenaArt.flower(_visual, Vector3((i - 1) * s.x * 0.26, s.y * 0.78, s.z * 0.18), Color("f0cea8"), 0.07)


func _seat() -> void:
	var s := size
	var seat_h := s.y * 0.45
	for x in [-s.x * 0.4, s.x * 0.4]:
		for z in [-s.z * 0.36, s.z * 0.36]:
			_block(Vector3(0.14, 0.22, 0.14), Color("725941"), Vector3(x, 0.11, z), 0.025)
	_block(Vector3(s.x, seat_h - 0.10, s.z), color.darkened(0.16), Vector3(0, seat_h * 0.5 + 0.05, 0), 0.12)
	_block(Vector3(s.x * 0.98, s.y * 0.77, s.z * 0.26), color.darkened(0.08), Vector3(0, s.y * 0.59, -s.z * 0.35), 0.12)
	for side in [-1.0, 1.0]:
		_block(Vector3(maxf(0.22, s.x * 0.105), s.y * 0.62, s.z * 0.97), color, Vector3(side * s.x * 0.445, s.y * 0.43, 0), 0.11)
	var cushions := 3 if kind == Kind.COUCH else 1
	var span := s.x * 0.74 / cushions
	for i in cushions:
		var x := (i - (cushions - 1) * 0.5) * span
		_block(Vector3(span - 0.045, 0.20, s.z * 0.65), color.lightened(0.12), Vector3(x, seat_h + 0.07, s.z * 0.08), 0.08)
		_block(Vector3(span - 0.06, s.y * 0.44, s.z * 0.19), color.lightened(0.035), Vector3(x, s.y * 0.73, -s.z * 0.22), 0.09, Vector3(-8, 0, 0))
		_block(Vector3(span - 0.12, 0.022, s.z * 0.025), color.lightened(0.27), Vector3(x, seat_h + 0.06, s.z * 0.408), 0.008)
	# One accent pillow, proportioned to a seat instead of a single long cushion slab.
	var pillow := minf(0.62, s.x * 0.28)
	_block(Vector3(pillow, pillow * 0.8, 0.19), accent, Vector3(-s.x * 0.22, seat_h + pillow * 0.5, -s.z * 0.07), 0.10, Vector3(-15, 0, -12))


func _tv() -> void:
	var s := size
	_block(Vector3(s.x, s.y * 0.3, s.z), accent, Vector3(0, s.y * 0.2, 0), 0.075)
	_block(Vector3(s.x + 0.06, 0.08, s.z + 0.04), accent.lightened(0.12), Vector3(0, s.y * 0.36, 0), 0.035)
	for side in [-1.0, 1.0]:
		_block(Vector3(s.x * 0.43, s.y * 0.19, 0.025), accent.darkened(0.13), Vector3(side * s.x * 0.25, s.y * 0.20, s.z * 0.505), 0.025)
		_block(Vector3(0.28, 0.035, 0.03), Color("caa76e"), Vector3(side * s.x * 0.25, s.y * 0.25, s.z * 0.53), 0.012)
		_block(Vector3(0.16, s.y * 0.1, 0.28), color, Vector3(side * s.x * 0.25, s.y * 0.4, 0), 0.025)
	_block(Vector3(s.x * 0.9, s.y * 0.55, 0.16), color, Vector3(0, s.y * 0.71, 0), 0.075)
	_block(Vector3(s.x * 0.82, s.y * 0.47, 0.035), Color("527a82"), Vector3(0, s.y * 0.71, 0.095), 0.045)
	# Quiet graphic on the screen avoids the old solid luminous blue rectangle.
	_block(Vector3(s.x * 0.55, 0.045, 0.012), Color("9ec5bc"), Vector3(-s.x * 0.07, s.y * 0.73, 0.12), 0.015)
	_block(Vector3(s.x * 0.31, 0.028, 0.012), Color("82a9a6"), Vector3(-s.x * 0.19, s.y * 0.66, 0.12), 0.01)
	Mats.mesh(_visual, Mats.sphere(0.03), Color("cce7ad"), Vector3(s.x * 0.37, s.y * 0.445, 0.095))


func _plant() -> void:
	var s := size
	var radius := minf(s.x, s.z) * 0.36
	Mats.mesh(_visual, Mats.cylinder(radius * 0.76, s.y * 0.34, radius), accent, Vector3(0, s.y * 0.17, 0))
	Mats.mesh(_visual, Mats.torus(radius * 0.85, radius * 1.05), accent.lightened(0.13), Vector3(0, s.y * 0.34, 0), Vector3.ZERO, Vector3(1, 0.48, 1))
	Mats.mesh(_visual, Mats.cylinder(radius * 0.85, 0.035), Color("5d4837"), Vector3(0, s.y * 0.34, 0))
	for i in 7:
		var angle := TAU * i / 7.0
		var top := Vector3(cos(angle) * radius * 0.68, s.y * (0.66 + (i % 3) * 0.11), sin(angle) * radius * 0.68)
		ArenaArt.rod(_visual, Vector3(0, s.y * 0.32, 0), top, 0.026, color.darkened(0.17))
		var leaf := Mats.mesh(_visual, Mats.sphere(radius * 0.64), color.lightened((i % 3) * 0.05), top)
		leaf.scale = Vector3(0.6, 1.3, 0.33)
		leaf.rotation_degrees = Vector3(25, rad_to_deg(-angle), 28)


func _tire() -> void:
	var s := size
	var radius := minf(s.x, s.z) * 0.48
	var ring := Mats.mesh(_visual, Mats.torus(radius * 0.49, radius), color, Vector3(0, s.y * 0.5, 0))
	ring.scale.y = s.y / maxf(radius * 0.51, 0.01)
	for i in 18:
		var angle := TAU * float(i) / 18.0
		_block(Vector3(0.12, s.y * 0.57, radius * 0.13), color.lightened(0.12), Vector3(sin(angle) * radius * 0.93, s.y * 0.5, cos(angle) * radius * 0.93), 0.025, Vector3(0, rad_to_deg(angle) + 10, 0))
	var rim := Mats.mesh(_visual, Mats.torus(radius * 0.55, radius * 0.61), color.lightened(0.18), Vector3(0, s.y * 0.89, 0))
	rim.scale.y = 0.5


func _ramp() -> void:
	var s := size
	var half := s.x * 0.5
	var slope := atan2(s.y, half)
	var deck_length := Vector2(half, s.y).length()
	var deck_width := s.z - WALL_THICKNESS * 2.0
	var thickness := 0.16
	for side: float in [-1.0, 1.0]:
		# The plank's top face is laid on the deck line, so what is drawn is what is walked on.
		var up := Vector2(sin(side * slope), cos(slope))
		var centre := Vector2(side * half * 0.5, s.y * 0.5) - up * (thickness * 0.5)
		var tilt := Vector3(0, 0, rad_to_deg(-side * slope))
		_block(Vector3(deck_length, thickness, deck_width), color if side < 0.0 else color.lightened(0.05),
			Vector3(centre.x, centre.y, 0), 0.03, tilt)
		for i in 6:
			var t := 0.1 + float(i) * 0.155
			var batten := Vector2(side * half * (1.0 - t), s.y * t) + up * 0.028
			_block(Vector3(0.07, 0.05, deck_width * 0.94), Color("f0debb"), Vector3(batten.x, batten.y, 0), 0.012, tilt)
	# The rails are drawn exactly where they collide, so the edge you can see is the edge you hit.
	for spec: Array in _rail_segments():
		var at: Vector3 = spec[0]
		var dimensions: Vector3 = spec[1]
		_block(dimensions, accent, at, 0.03)
		_block(Vector3(dimensions.x - 0.03, 0.09, WALL_THICKNESS + 0.06), accent.lightened(0.18),
			Vector3(at.x, dimensions.y, at.z), 0.03)
	_block(Vector3(0.22, 0.12, s.z + 0.06), Color("f4e4c5"), Vector3(0, s.y + 0.02, 0), 0.045)


func _tunnel() -> void:
	var s := size
	# A continuous fabric body and evenly spaced ribs replace separated floating rings.
	var body := Mats.mesh(_visual, Mats.cylinder(s.y * 0.47, s.x), color, Vector3(0, s.y * 0.49, 0), Vector3(0, 0, 90))
	body.scale.z = s.z / s.y
	var ribs := maxi(5, int(s.x / 0.48))
	for i in ribs:
		var x := lerpf(-s.x * 0.5, s.x * 0.5, float(i) / (ribs - 1))
		var ring := Mats.mesh(_visual, Mats.torus(s.y * 0.435, s.y * 0.50), accent if i == 0 or i == ribs - 1 else color.lightened(0.15), Vector3(x, s.y * 0.5, 0), Vector3(0, 0, 90))
		ring.scale.z = s.z / s.y
	for side in [-1.0, 1.0]:
		var end := Mats.mesh(_visual, Mats.cylinder(s.y * 0.4, 0.018), color.darkened(0.52), Vector3(side * (s.x * 0.5 + 0.008), s.y * 0.5, 0), Vector3(0, 0, 90))
		end.scale.z = s.z / s.y


func _weave() -> void:
	var s := size
	_block(Vector3(s.x, 0.1, s.z), accent.darkened(0.13), Vector3(0, 0.05, 0), 0.045)
	var poles := maxi(3, int(s.x / 0.7))
	for i in poles:
		var x := lerpf(-s.x * 0.44, s.x * 0.44, float(i) / (poles - 1))
		var z := sin(float(i) / (poles - 1) * TAU) * s.z * 0.18
		Mats.mesh(_visual, Mats.cylinder(0.085, s.y - 0.1), color, Vector3(x, (s.y + 0.1) * 0.5, z))
		for stripe in 2:
			Mats.mesh(_visual, Mats.cylinder(0.088, s.y * 0.17), accent, Vector3(x, s.y * (0.38 + stripe * 0.33), z))
		Mats.mesh(_visual, Mats.sphere(0.088), Color("f3e4c9"), Vector3(x, s.y, z))


func _counter() -> void:
	var s := size
	_block(Vector3(s.x * 0.96, s.y - 0.1, s.z * 0.96), color.darkened(0.08), Vector3(0, s.y * 0.5, 0), 0.065)
	_block(Vector3(s.x + 0.10, 0.16, s.z + 0.1), accent, Vector3(0, s.y - 0.035, 0), 0.06)
	_block(Vector3(s.x * 0.91, 0.10, s.z * 0.9), accent.darkened(0.24), Vector3(0, 0.07, 0), 0.035)
	var doors := maxi(1, int(s.x / 1.0))
	for i in doors:
		var width := s.x * 0.94 / doors
		var x := (i - (doors - 1) * 0.5) * width
		_block(Vector3(width - 0.045, s.y * 0.69, 0.055), color, Vector3(x, s.y * 0.48, s.z * 0.49), 0.035)
		_block(Vector3(width * 0.72, s.y * 0.46, 0.012), color.lightened(0.045), Vector3(x, s.y * 0.46, s.z * 0.525), 0.015)
		_block(Vector3(minf(0.25, width * 0.35), 0.042, 0.075), accent.darkened(0.3), Vector3(x, s.y * 0.7, s.z * 0.54), 0.016)
	# A small butcher-block inset makes the island readable from the gameplay camera.
	_block(Vector3(s.x * 0.28, 0.035, s.z * 0.6), accent.lightened(0.16), Vector3(-s.x * 0.24, s.y + 0.065, 0), 0.02)


func _fridge() -> void:
	var s := size
	_block(s, color.darkened(0.06), Vector3(0, s.y * 0.5, 0), 0.15)
	for section in 2:
		var h := s.y * (0.33 if section == 0 else 0.61)
		var y := s.y * (0.81 if section == 0 else 0.32)
		_block(Vector3(s.x * 0.95, h, 0.12), color.lightened(0.045), Vector3(0, y, s.z * 0.5), 0.07)
		_block(Vector3(0.09, h * 0.43, 0.09), accent, Vector3(s.x * 0.31, y, s.z * 0.5 + 0.12), 0.04)
	_block(Vector3(s.x * 0.85, 0.11, 0.04), color.darkened(0.3), Vector3(0, 0.09, s.z * 0.51), 0.025)
	_block(Vector3(s.x * 0.21, s.y * 0.15, 0.016), Color("f4dfad"), Vector3(-s.x * 0.17, s.y * 0.48, s.z * 0.57), 0.015, Vector3(0, 0, -8))
	Mats.mesh(_visual, Mats.sphere(0.055), Color("83b8ac"), Vector3(-s.x * 0.13, s.y * 0.57, s.z * 0.58))


func _umbrella() -> void:
	var s := size
	var radius := minf(s.x, s.z) * 0.49
	Mats.mesh(_visual, Mats.cylinder(0.3, 0.12, 0.23), accent, Vector3(0, 0.06, 0))
	Mats.mesh(_visual, Mats.cylinder(0.055, s.y * 0.94), Color("e8d6b3"), Vector3(0, s.y * 0.47, 0))
	for i in 10:
		var angle_a := TAU * float(i) / 10.0
		var angle_b := TAU * float(i + 1) / 10.0
		var top := Vector3(0, s.y, 0)
		var a := Vector3(cos(angle_a) * radius, s.y * 0.78, sin(angle_a) * radius)
		var b := Vector3(cos(angle_b) * radius, s.y * 0.78, sin(angle_b) * radius)
		var middle := (a + b) * 0.5 - Vector3(0, s.y * 0.06, 0)
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for point in [top, a, middle, top, middle, b]:
			st.add_vertex(point)
		st.generate_normals()
		var panel := Mats.mesh(_visual, st.commit(), color if i % 2 == 0 else Color("f4e7c8"))
		(panel.material_override as StandardMaterial3D).cull_mode = BaseMaterial3D.CULL_DISABLED
		ArenaArt.rod(_visual, top, a, 0.018, accent)
		ArenaArt.rod(_visual, a, middle, 0.025, color.darkened(0.12))
		ArenaArt.rod(_visual, middle, b, 0.025, color.darkened(0.12))
	Mats.mesh(_visual, Mats.sphere(0.095), accent, Vector3(0, s.y + 0.035, 0))


func _rock() -> void:
	var s := size
	for i in 3:
		var rock := Mats.mesh(_visual, Mats.sphere(0.5), color.lightened(0.04 * i),
			Vector3((i - 1) * s.x * 0.22, s.y * (0.45 if i == 1 else 0.30), (0.08 if i == 1 else -0.08) * s.z))
		rock.scale = Vector3(s.x * (0.61 if i == 1 else 0.49), s.y * (1.05 if i == 1 else 0.68), s.z * 0.89)
		rock.rotation_degrees.y = i * 31.0


func _snowman() -> void:
	var s := size
	var r := minf(s.x, s.z) * 0.5
	# Three stacked balls, a stick-arm each side, a scarf in the accent colour and a carrot nose
	# pointing at the camera so it reads as a face from above.
	Mats.mesh(_visual, Mats.sphere(r), color, Vector3(0, r * 0.85, 0), Vector3.ZERO, Vector3(1, 0.9, 1))
	Mats.mesh(_visual, Mats.sphere(r * 0.72), color, Vector3(0, r * 1.95, 0))
	var head_y := minf(s.y - r * 0.5, r * 2.75)
	Mats.mesh(_visual, Mats.sphere(r * 0.5), color, Vector3(0, head_y, 0))
	var scarf := Mats.mesh(_visual, Mats.torus(r * 0.38, r * 0.6), accent, Vector3(0, head_y - r * 0.42, 0))
	scarf.scale.y = 0.7
	_block(Vector3(r * 0.24, r * 0.6, 0.06), accent, Vector3(r * 0.25, head_y - r * 0.75, r * 0.55), 0.02, Vector3(0, 0, -12))
	Mats.mesh(_visual, Mats.cone(r * 0.1, r * 0.55), Color("ef8a3c"), Vector3(0, head_y, r * 0.65), Vector3(90, 0, 0))
	for side: float in [-1.0, 1.0]:
		Mats.mesh(_visual, Mats.sphere(r * 0.06), Color("2a2c30"), Vector3(side * r * 0.18, head_y + r * 0.16, r * 0.43))
		ArenaArt.rod(_visual, Vector3(side * r * 0.62, r * 1.95, 0), Vector3(side * r * 1.25, r * 2.4, 0.05), 0.035, Color("6b4a2f"))
	for i in 3:
		Mats.mesh(_visual, Mats.sphere(r * 0.07), Color("2a2c30"), Vector3(0, r * (1.7 + i * 0.22), r * 0.7 - i * 0.02))
	# A bobble hat, because this is a dog park.
	var hat := Mats.mesh(_visual, Mats.cylinder(r * 0.34, r * 0.3, r * 0.2), accent, Vector3(0, head_y + r * 0.5, 0))
	hat.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	Mats.mesh(_visual, Mats.sphere(r * 0.13), Color("fff6ea"), Vector3(0, head_y + r * 0.72, 0))


func _drift() -> void:
	var s := size
	# Heaped snow: overlapping soft mounds over a packed base, cool blue in the hollows.
	_block(Vector3(s.x * 0.96, 0.18, s.z * 0.96), accent.lightened(0.25), Vector3(0, 0.09, 0), 0.08)
	for i in 5:
		var x := ((i % 3) - 1) * s.x * 0.24
		var z := (-0.2 if i < 3 else 0.22) * s.z
		var mound := Mats.mesh(_visual, Mats.sphere(0.5), color.lerp(accent, 0.08 * float(i % 2)), Vector3(x, s.y * (0.46 if i == 1 else 0.34), z))
		mound.scale = Vector3(s.x * 0.52, s.y * (0.98 if i == 1 else 0.76), s.z * 0.62)
	# Snowballs stacked ready at the foot of the heap.
	for i in 3:
		Mats.mesh(_visual, Mats.sphere(0.17), color.lightened(0.06), Vector3((float(i) - 1.0) * 0.34, 0.17 + (0.26 if i == 1 else 0.0), s.z * 0.5 - 0.16))


func _blocks() -> void:
	var s := size
	# Building blocks stacked into a wobbly tower: alternating colours, each slightly turned,
	# with a raised letter panel on the front face like the wooden ones.
	var palette := [color, accent, Color("f2c84b"), Color("5bb06a"), Color("3f86e0"), Color("e2533f")]
	var rows := maxi(1, int(round(s.y / 0.55)))
	var block_h := s.y / float(rows)
	var across := maxi(1, int(round(s.x / 0.75)))
	var deep := maxi(1, int(round(s.z / 0.75)))
	var bx := s.x / float(across)
	var bz := s.z / float(deep)
	var n := 0
	for row in rows:
		# Each layer up is a little narrower, so the stack reads as a pile, not a box.
		var shrink := 1.0 - float(row) * 0.06
		for ix in across:
			for iz in deep:
				n += 1
				if row == rows - 1 and (ix + iz + row) % 2 == 1:
					continue
				var tint: Color = palette[(ix * 3 + iz * 2 + row) % palette.size()]
				var at := Vector3((-s.x * 0.5 + (ix + 0.5) * bx) * shrink, (row + 0.5) * block_h, (-s.z * 0.5 + (iz + 0.5) * bz) * shrink)
				var cube := Vector3(bx * 0.94, block_h * 0.96, bz * 0.94)
				_block(cube, tint, at, 0.05, Vector3(0, float((n * 37) % 13) - 6.0, 0))
				_block(Vector3(cube.x * 0.55, cube.y * 0.55, 0.02), tint.lightened(0.35), at + Vector3(0, 0, cube.z * 0.5), 0.015)


func _toy_chest() -> void:
	var s := size
	_block(Vector3(s.x, s.y * 0.78, s.z), color, Vector3(0, s.y * 0.39, 0), 0.08)
	_block(Vector3(s.x + 0.08, s.y * 0.2, s.z + 0.08), color.lightened(0.12), Vector3(0, s.y * 0.88, 0), 0.07)
	for x: float in [-s.x * 0.47, s.x * 0.47]:
		_block(Vector3(0.12, s.y * 0.78, s.z + 0.04), accent, Vector3(x, s.y * 0.39, 0), 0.03)
	_block(Vector3(s.x + 0.04, 0.1, 0.06), accent, Vector3(0, s.y * 0.55, s.z * 0.5 + 0.01), 0.02)
	# The lid is what the camera sees: a bright inset panel with a band of stars across it.
	_block(Vector3(s.x * 0.86, 0.03, s.z * 0.7), accent, Vector3(0, s.y * 0.98 + 0.012, 0), 0.015)
	for i in 5:
		var star := Mats.mesh(_visual, Mats.cylinder(0.09, 0.02), Color("fff6ea"), Vector3((float(i) - 2.0) * s.x * 0.17, s.y * 0.98 + 0.035, s.z * 0.22))
		star.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Toys spilling over the rim: a ball, a block and a ring stacker peg.
	Mats.mesh(_visual, Mats.sphere(0.24), Color("e2533f"), Vector3(-s.x * 0.25, s.y + 0.1, 0))
	_block(Vector3(0.34, 0.34, 0.34), Color("5bb06a"), Vector3(s.x * 0.18, s.y + 0.1, 0.05), 0.04, Vector3(0, 25, 12))
	Mats.mesh(_visual, Mats.torus(0.1, 0.2), Color("f2c84b"), Vector3(s.x * 0.36, s.y + 0.04, -0.1))


## A thrown toy struck this prop. Only breakable props care: each hit darkens and jolts it, and
## the last one splinters it into planks and opens the way.
func take_hit(toy_velocity: Vector3) -> void:
	if not breakable or _broken:
		return
	_hits_left -= 2 if toy_velocity.length() >= HARD_HIT_SPEED else 1
	var chips := accent if accent != Color.BLACK else color
	Juice.burst(get_parent(), global_position + Vector3(0, size.y * 0.6, 0), chips.lightened(0.15), 8, 3.0)
	if _hits_left <= 0:
		_splinter(toy_velocity)
		return
	Sfx.play_at("land", global_position, 0.75, -4.0)
	# Each hit leaves it a little darker and a little more battered, so you can see it is going.
	for i in _base_colors.size():
		_base_colors[i] = _base_colors[i].darkened(0.12)
		_fade_materials[i].albedo_color = Color(_base_colors[i], _fade_materials[i].albedo_color.a)
	var jolt := _visual.create_tween()
	var lean := Vector3(0, 0, 6.0 if _hits_left % 2 == 0 else -6.0)
	jolt.tween_property(_visual, "rotation_degrees", lean, 0.05)
	jolt.tween_property(_visual, "rotation_degrees", lean * 0.3, 0.2).set_trans(Tween.TRANS_BACK)


func _splinter(toy_velocity: Vector3) -> void:
	_broken = true
	for shape in _shapes:
		shape.set_deferred("disabled", true)
	_visual.visible = false
	if is_instance_valid(_ground_shade):
		_ground_shade.visible = false
	Sfx.play_at("whack", global_position, 0.7, -2.0)
	Juice.shake(0.18)
	Juice.burst(get_parent(), global_position + Vector3(0, size.y * 0.5, 0), color.lightened(0.2), 22, 6.0)
	# Planks fly off along the throw and settle as rubble you can run over.
	_rubble = Node3D.new()
	_rubble.name = "Rubble"
	add_child(_rubble)
	var push := Vector3(toy_velocity.x, 0, toy_velocity.z).normalized()
	for i in 6:
		var plank := ArenaArt.block(_rubble, Vector3(size.x * 0.55, 0.08, 0.22), color.darkened(0.1 * float(i % 3)),
			Vector3(0, size.y * 0.5, 0), Vector3(0, randf() * 180.0, 0), 0.02)
		plank.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var land := (push * randf_range(0.3, 1.2) + Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)) * 0.6) * size.x * 0.5
		var fly := plank.create_tween().set_parallel(true)
		fly.tween_property(plank, "position", Vector3(land.x, 0.05, land.z), 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		fly.tween_property(plank, "rotation_degrees", Vector3(randf_range(-8, 8), randf() * 360.0, randf_range(-8, 8)), 0.45)


func reset_for_round() -> void:
	if not breakable:
		return
	_hits_left = toughness
	if not _broken:
		# Dents from last round are forgiven too.
		_rebuild()
		return
	_broken = false
	if is_instance_valid(_rubble):
		_rubble.queue_free()
	_rebuild()


## Alpha is applied to instance-owned materials: GeometryInstance transparency
## is unavailable in the Compatibility renderer. The physical prop stays solid.
func _prepare_occlusion_materials() -> void:
	_fade_materials.clear()
	_base_colors.clear()
	_base_transparency.clear()
	_fade_meshes.clear()
	_base_shadows.clear()
	_shadow_proxies.clear()
	_opacity = 1.0
	_target_opacity = 1.0
	for child in _visual.find_children("*", "MeshInstance3D", true, false):
		var mesh := child as MeshInstance3D
		var original := mesh.material_override as StandardMaterial3D
		if original == null:
			continue
		var material := original.duplicate() as StandardMaterial3D
		material.resource_local_to_scene = true
		mesh.material_override = material
		_fade_materials.append(material)
		_base_colors.append(original.albedo_color)
		_base_transparency.append(original.transparency)
		_fade_meshes.append(mesh)
		_base_shadows.append(mesh.cast_shadow)
		var shadow: MeshInstance3D = null
		if mesh.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
			# Transparent materials stop casting reliable shadows in GL. Keep the
			# original opaque shadow so a faded prop's occupied footprint is clear.
			shadow = MeshInstance3D.new()
			shadow.name = "OcclusionShadow"
			shadow.mesh = mesh.mesh
			shadow.material_override = original
			shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
			shadow.visible = false
			mesh.add_child(shadow)
		_shadow_proxies.append(shadow)


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint() or _fade_materials.is_empty():
		return
	_occlusion_timer -= delta
	if _occlusion_timer <= 0.0:
		_occlusion_timer = OCCLUSION_CHECK_INTERVAL
		_target_opacity = OCCLUDED_OPACITY if _hides_the_action() else 1.0
	var next_opacity := lerpf(_opacity, _target_opacity, 1.0 - exp(-14.0 * delta))
	if absf(next_opacity - _target_opacity) < 0.003:
		next_opacity = _target_opacity
	if is_equal_approx(_opacity, next_opacity):
		return
	_opacity = next_opacity
	var fading := _opacity < 0.999
	for i in _fade_materials.size():
		var color := _base_colors[i]
		color.a *= _opacity
		_fade_materials[i].albedo_color = color
		_fade_materials[i].transparency = BaseMaterial3D.TRANSPARENCY_ALPHA if fading else _base_transparency[i]
		_fade_meshes[i].cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if fading else _base_shadows[i]
		if is_instance_valid(_shadow_proxies[i]):
			_shadow_proxies[i].visible = fading


func _hides_the_action() -> bool:
	# A tube is only a route if the table can watch the chase go through it, whatever the
	# camera can make of the fabric.
	if kind == Kind.TUNNEL and _holds_someone():
		return true
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return false
	for node in get_tree().get_nodes_in_group("dogs"):
		if not node is Dog or not node.alive or node.is_queued_for_deletion():
			continue
		# A dog up on our own deck is on top of us, not behind us. The occlusion body is the
		# whole footprint, so without this an A-frame would ghost out the moment anyone
		# climbed it - exactly when the shape being run over most needs to be readable.
		if surface_height(node.global_position) > 0.05:
			continue
		var target: Vector3 = node.global_position + Vector3(0, 0.65, 0)
		if camera.is_position_behind(target):
			continue
		# Orthographic sight rays must start at the dog's screen coordinate,
		# rather than converging on the camera position as perspective rays do.
		var screen_point := camera.unproject_position(target)
		var origin := camera.project_ray_origin(screen_point)
		var query := PhysicsRayQueryParameters3D.create(origin, target, 1 | OCCLUSION_LAYER)
		var hit := get_world_3d().direct_space_state.intersect_ray(query)
		var blocker: Variant = hit.get("collider")
		if blocker == self or (blocker != null and blocker == _occluder):
			return true
	return false


## True when a live dog or a toy in flight is inside this prop's footprint.
func _holds_someone() -> bool:
	for node in get_tree().get_nodes_in_group("dogs"):
		var dog := node as Dog
		if dog != null and dog.alive and not dog.is_queued_for_deletion() and _contains(dog.global_position):
			return true
	for node in get_tree().get_nodes_in_group("toys"):
		var toy := node as Toy
		if toy != null and toy.state == Toy.State.FLYING and _contains(toy.global_position):
			return true
	return false


func _contains(at: Vector3) -> bool:
	var local := to_local(at)
	return absf(local.x) <= size.x * 0.5 and absf(local.z) <= size.z * 0.5
