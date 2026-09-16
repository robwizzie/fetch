class_name Arena
extends Node3D
## Base for every arena scene. Builds the ground, the outer walls (collision + fence/baseboard
## visuals), decorative ground patches, and exposes spawn points. Camera, light and environment
## are child nodes of the arena scene so each arena can have its own mood.
## To make a new arena: duplicate scenes/arenas/backyard.tscn, move things around, add an ArenaData.

enum WallStyle { FENCE, BASEBOARD, NONE }
## AUTO keeps the historical behaviour: boards indoors, grass patches outdoors.
enum GroundStyle { AUTO, PATCHES, BOARDS, TILES }

## Playable area in metres (x = width, y = depth), centred on the origin.
@export var size := Vector2(26, 14.6)
@export var wall_style := WallStyle.FENCE
@export var ground_style := GroundStyle.AUTO
@export var wall_height := 1.1
@export var ground_color := Color(0.38, 0.68, 0.26)
@export var ground_accent := Color(0.36, 0.66, 0.26)
@export var wall_color := Color(0.62, 0.42, 0.24)
@export var wall_accent := Color(0.5, 0.33, 0.18)
## Ground outside the walls (so the perspective camera never shows the void).
@export var surround_color := Color(0.3, 0.5, 0.22)
@export var flowers := true
@export var pattern_seed := 7
## Name burned into the welcome sign behind the back fence. Empty hides the sign.
@export var sign_text := "THE DOG PARK"

@onready var spawn_points: Node3D = $SpawnPoints
@onready var toy_spawns: Node3D = $ToySpawns


func _ready() -> void:
	_build_ground()
	_build_walls()
	if wall_style == WallStyle.FENCE:
		_build_garden()


## True when a point is outside the playable area (used as a safety net for escaped toys).
func is_outside(p: Vector3, margin: float = 1.0) -> bool:
	return absf(p.x) > size.x / 2.0 + margin or absf(p.z) > size.y / 2.0 + margin


func get_spawn_position(i: int) -> Vector3:
	var points := spawn_points.get_children()
	if points.is_empty():
		return Vector3.ZERO
	return (points[i % points.size()] as Node3D).global_position


func get_toy_spawn_position(i: int) -> Vector3:
	var points := toy_spawns.get_children()
	if points.is_empty():
		return Vector3.ZERO
	return (points[i % points.size()] as Node3D).global_position


func _build_ground() -> void:
	var root := Node3D.new()
	root.name = "Ground"
	add_child(root)
	Mats.mesh(root, Mats.box(Vector3(size.x + 40.0, 0.5, size.y + 40.0)), surround_color, Vector3(0, -0.3, 0))
	Mats.mesh(root, Mats.box(Vector3(size.x, 0.5, size.y)), ground_color, Vector3(0, -0.24, 0))
	var rng := RandomNumberGenerator.new()
	rng.seed = pattern_seed
	var style := ground_style
	if style == GroundStyle.AUTO:
		style = GroundStyle.BOARDS if wall_style == WallStyle.BASEBOARD else GroundStyle.PATCHES
	if style == GroundStyle.TILES:
		var tile := 1.62
		for row in int(size.y / tile) + 1:
			for col in int(size.x / tile) + 1:
				if (row + col) % 2 == 1:
					continue
				var tx := -size.x / 2.0 + (col + 0.5) * tile
				var tz := -size.y / 2.0 + (row + 0.5) * tile
				var w := minf(tile - 0.06, size.x / 2.0 - absf(tx) + tile * 0.5)
				var d := minf(tile - 0.06, size.y / 2.0 - absf(tz) + tile * 0.5)
				if w <= 0.1 or d <= 0.1:
					continue
				Mats.mesh(root, Mats.box(Vector3(w, 0.016, d)), ground_accent, Vector3(tx, 0.02, tz))
		return
	if style == GroundStyle.BOARDS:
		# Warm floorboards replace the outdoor lawn patches indoors.
		for row in int(size.y / 0.85):
			var z := -size.y / 2.0 + 0.425 + row * 0.85
			for col in 7:
				var x := -size.x / 2.0 + (col + 0.5) * size.x / 7.0
				var wood := ground_color.lerp(ground_accent, rng.randf_range(0.05, 0.75))
				Mats.mesh(root, Mats.box(Vector3(size.x / 7.0 - 0.035, 0.018, 0.82)), wood, Vector3(x, 0.02, z))
		return
	for i in 26:
		var p := Vector3(rng.randf_range(-size.x / 2.0, size.x / 2.0), 0.012, rng.randf_range(-size.y / 2.0, size.y / 2.0))
		var patch := Mats.mesh(root, Mats.cylinder(rng.randf_range(0.6, 1.8), 0.02), ground_accent, p)
		patch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if flowers:
		var colors := [Color(1, 0.85, 0.3), Color(1, 0.5, 0.6), Color(0.95, 0.95, 1.0), Color(0.6, 0.5, 1.0)]
		for i in 24:
			# Flowers stay at the edges, leaving the combat floor uncluttered.
			var z := (size.y / 2.0 - 0.38) * (-1.0 if i % 2 == 0 else 1.0)
			var p := Vector3(rng.randf_range(-size.x / 2.0 + 0.5, size.x / 2.0 - 0.5), 0.12, z)
			Mats.mesh(root, Mats.cylinder(0.03, 0.25), Color(0.3, 0.6, 0.25), p)
			Mats.mesh(root, Mats.sphere(0.09), colors[i % colors.size()], p + Vector3(0, 0.15, 0))


## Scenery outside the collision fence frames the play area without blocking a dog or a toy.
func _build_garden() -> void:
	var garden := Node3D.new()
	garden.name = "Garden"
	add_child(garden)
	var hx := size.x * 0.5
	var hz := size.y * 0.5
	var leaf_colors := [Color("537e39"), Color("68984a"), Color("81a94d")]
	for i in 8:
		var x := -hx - 2.6 + float(i) * (size.x + 5.2) / 7.0
		var z := -hz - 3.2 - sin(float(i) * 2.0) * 0.5
		var trunk := Vector3(x, 1.3, z)
		Mats.mesh(garden, Mats.cylinder(0.22, 2.6), Color("765538"), trunk)
		for j in 3:
			var crown := Vector3(x + (j - 1) * 0.8, 2.7 + (0.5 if j == 1 else 0.0), z + j * 0.25)
			Mats.mesh(garden, Mats.sphere(1.3), leaf_colors[(i + j) % 3], crown, Vector3.ZERO, Vector3(1.0, 0.85, 0.9))
	for side in [-1.0, 1.0]:
		for i in 7:
			var p := Vector3(side * (hx + 1.8), 0.25, -hz + i * size.y / 6.0)
			Mats.mesh(garden, Mats.sphere(0.8), leaf_colors[i % 3], p, Vector3.ZERO, Vector3(1, 0.65, 1.1))
	# A little welcome sign lives behind the back fence, clear of the playing surface.
	if sign_text.is_empty():
		return
	Mats.mesh(garden, Mats.box(Vector3(0.16, 1.5, 0.16)), Color("765538"), Vector3(0, 0.75, -hz - 0.75))
	Mats.mesh(garden, Mats.box(Vector3(2.9, 0.85, 0.16)), Color("98693e"), Vector3(0, 1.4, -hz - 0.75))
	var plate := Label3D.new()
	plate.text = sign_text
	plate.font = UiKit.FONT_DISPLAY
	plate.font_size = 50
	plate.pixel_size = 0.0035
	plate.modulate = UiKit.CREAM
	plate.outline_size = 3
	plate.position = Vector3(0, 1.4, -hz - 0.65)
	garden.add_child(plate)


func _build_walls() -> void:
	var walls := StaticBody3D.new()
	walls.name = "Walls"
	walls.collision_layer = 1
	walls.collision_mask = 0
	add_child(walls)
	var t := 2.0
	var h := 3.0
	var hx := size.x / 2.0
	var hz := size.y / 2.0
	var specs := [
		[Vector3(0, h / 2.0, -hz - t / 2.0), Vector3(size.x + t * 2.0, h, t)],
		[Vector3(0, h / 2.0, hz + t / 2.0), Vector3(size.x + t * 2.0, h, t)],
		[Vector3(-hx - t / 2.0, h / 2.0, 0), Vector3(t, h, size.y)],
		[Vector3(hx + t / 2.0, h / 2.0, 0), Vector3(t, h, size.y)],
	]
	for s in specs:
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = s[1]
		shape.shape = box
		shape.position = s[0]
		walls.add_child(shape)
	match wall_style:
		WallStyle.FENCE:
			_build_fence(walls, hx, hz)
		WallStyle.BASEBOARD:
			_build_baseboard(walls, hx, hz)


func _build_fence(parent: Node3D, hx: float, hz: float) -> void:
	var post := Mats.box(Vector3(0.28, wall_height, 0.28))
	var rail_x := Mats.box(Vector3(size.x + 0.6, 0.16, 0.1))
	var rail_z := Mats.box(Vector3(0.1, 0.16, size.y + 0.6))
	for z in [-hz - 0.15, hz + 0.15]:
		var x := -hx
		while x <= hx + 0.01:
			Mats.mesh(parent, post, wall_color, Vector3(x, wall_height / 2.0, z))
			x += 1.6
		for y in [wall_height * 0.35, wall_height * 0.75]:
			Mats.mesh(parent, rail_x, wall_accent, Vector3(0, y, z))
	for x in [-hx - 0.15, hx + 0.15]:
		var z := -hz
		while z <= hz + 0.01:
			Mats.mesh(parent, post, wall_color, Vector3(x, wall_height / 2.0, z))
			z += 1.6
		for y in [wall_height * 0.35, wall_height * 0.75]:
			Mats.mesh(parent, rail_z, wall_accent, Vector3(x, y, 0))


func _build_baseboard(parent: Node3D, hx: float, hz: float) -> void:
	var t := 0.5
	Mats.mesh(parent, Mats.box(Vector3(size.x + t * 2.0, wall_height, t)), wall_color, Vector3(0, wall_height / 2.0, -hz - t / 2.0))
	Mats.mesh(parent, Mats.box(Vector3(size.x + t * 2.0, wall_height * 0.6, t)), wall_color, Vector3(0, wall_height * 0.3, hz + t / 2.0))
	Mats.mesh(parent, Mats.box(Vector3(t, wall_height, size.y + t * 2.0)), wall_color, Vector3(-hx - t / 2.0, wall_height / 2.0, 0))
	Mats.mesh(parent, Mats.box(Vector3(t, wall_height, size.y + t * 2.0)), wall_color, Vector3(hx + t / 2.0, wall_height / 2.0, 0))
	# Skirting trim
	Mats.mesh(parent, Mats.box(Vector3(size.x + t * 2.0, 0.18, t + 0.1)), wall_accent, Vector3(0, 0.09, -hz - t / 2.0))
	Mats.mesh(parent, Mats.box(Vector3(t + 0.1, 0.18, size.y + t * 2.0)), wall_accent, Vector3(-hx - t / 2.0, 0.09, 0))
	Mats.mesh(parent, Mats.box(Vector3(t + 0.1, 0.18, size.y + t * 2.0)), wall_accent, Vector3(hx + t / 2.0, 0.09, 0))


## Uses authored collision shapes, including before the first physics tick.
func is_clear_position(at: Vector3, radius: float) -> bool:
	var local := to_local(at)
	if absf(local.x) + radius > size.x * 0.5 or absf(local.z) + radius > size.y * 0.5:
		return false
	for node in find_children("*", "CollisionShape3D", true, false):
		var collider := node as CollisionShape3D
		if collider.disabled or not (collider.get_parent() is StaticBody3D):
			continue
		if collider.shape is BoxShape3D:
			var half := (collider.shape as BoxShape3D).size * 0.5
			var point := collider.to_local(at)
			var nearest := Vector2(clampf(point.x, -half.x, half.x), clampf(point.z, -half.z, half.z))
			if Vector2(point.x, point.z).distance_to(nearest) < radius:
				return false
	return true


func clear_pickup_position(preferred: Vector3, radius: float = 0.85) -> Vector3:
	if is_clear_position(preferred, radius):
		return preferred
	# The search starts at a random bearing so a blocked spot does not always resolve to the
	# same side of the prop: two draws in a cluttered arena still land in different places.
	var bearing := randi() % 16
	for ring in range(1, 9):
		for step in 16:
			var angle := TAU * ((step + bearing) % 16) / 16.0
			var candidate := preferred + Vector3(cos(angle), 0, sin(angle)) * ring * 0.4
			if is_clear_position(candidate, radius):
				return candidate
	push_warning("No clear pickup location near %s" % preferred)
	return preferred
