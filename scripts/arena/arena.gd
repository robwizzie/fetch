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
## Visual dressing is independent from the collision and floor styles.
@export_enum("Garden", "Agility", "Living Room", "Kitchen", "Beach", "Warp", "Courtyard", "Rooftop") var decor_theme := "Garden"
## Name burned into the welcome sign behind the back fence. Empty hides the sign.
@export var sign_text := "THE DOG PARK"

## Edge of one square of the mown lawn, in metres (rounded to fit the arena exactly).
const LAWN_SQUARE := 2.6

@onready var spawn_points: Node3D = $SpawnPoints
@onready var toy_spawns: Node3D = $ToySpawns


func _ready() -> void:
	add_to_group("arenas")
	var hard := ground_style in [GroundStyle.BOARDS, GroundStyle.TILES] or wall_style == WallStyle.BASEBOARD \
		or decor_theme in ["Rooftop", "Courtyard"]
	Sfx.set_room(decor_theme in ["Living Room", "Kitchen"], hard)
	_style_lighting()
	_build_ground()
	_build_walls()
	if wall_style == WallStyle.FENCE:
		_build_garden()
	elif decor_theme == "Living Room" or decor_theme == "Kitchen":
		_build_room_details()


## A single consistent key and a cooler fill keep small silhouettes readable on every map.
## Orthogonal shadows spend the atlas on the compact playfield instead of distant cascades.
## The key is a little lower than overhead so props and dogs throw a shadow you can see from
## the camera. Linear tonemapping keeps the palette saturated; the key is kept low enough
## that sunlit floors do not clip, which is what lets the cast shadows actually read.
func _style_lighting() -> void:
	var indoor := decor_theme in ["Living Room", "Kitchen"]
	var night := decor_theme == "Rooftop"
	for child in get_children():
		if child is DirectionalLight3D and child.name != "Fill":
			child.rotation_degrees = Vector3(-50.0, -34.0, 0.0)
			if not night:
				child.light_color = Color("ffe9cf") if indoor else Color("fff0da")
				child.light_energy = 0.83 if indoor else 0.9
			else:
				child.light_energy = 0.8
			child.shadow_enabled = true
			child.shadow_bias = 0.03
			child.shadow_normal_bias = 1.0
			child.shadow_opacity = 0.78
			child.shadow_blur = 1.6
			child.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
			# The perspective lens sits ~35-45 m out; the far wall has to stay in shadow range.
			child.directional_shadow_max_distance = 80.0
		if child is WorldEnvironment and child.environment != null:
			var env: Environment = child.environment.duplicate()
			child.environment = env
			# Warm key, cool sky: shadowed sides pick up blue instead of going grey.
			env.ambient_light_color = Color("c9d6ec") if indoor else Color("b9cff0")
			env.ambient_light_energy = 0.42
			env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
			env.tonemap_exposure = 1.0
			env.adjustment_enabled = true
			env.adjustment_saturation = 1.06
			env.adjustment_contrast = 1.04
	if get_node_or_null("Fill") == null:
		# A soft, shadowless bounce from the opposite side so the far flank of a dog still
		# has shape instead of flattening into its own silhouette.
		var fill := DirectionalLight3D.new()
		fill.name = "Fill"
		fill.rotation_degrees = Vector3(-30.0, 150.0, 0.0)
		fill.light_color = Color("a9c4ff") if not indoor else Color("ffd9b0")
		fill.light_energy = 0.22
		fill.shadow_enabled = false
		fill.light_specular = 0.0
		add_child(fill)


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
	# A layered, shallow diorama base gives every arena a clean, intentional edge.
	Mats.mesh_plain(root, Mats.box(Vector3(size.x + 70.0, 0.5, size.y + 70.0)), surround_color, Vector3(0, -0.78, 0))
	ArenaArt.block(root, Vector3(size.x + 0.75, 0.5, size.y + 0.75), wall_accent.darkened(0.18), Vector3(0, -0.34, 0), Vector3.ZERO, 0.18)
	ArenaArt.block(root, Vector3(size.x + 0.28, 0.18, size.y + 0.28), ground_accent.darkened(0.12), Vector3(0, -0.09, 0))
	Mats.mesh_plain(root, Mats.box(Vector3(size.x, 0.12, size.y)), ground_color, Vector3(0, -0.05, 0))
	var rng := RandomNumberGenerator.new()
	rng.seed = pattern_seed
	var style := ground_style
	if style == GroundStyle.AUTO:
		style = GroundStyle.BOARDS if wall_style == WallStyle.BASEBOARD else GroundStyle.PATCHES
	if style == GroundStyle.TILES:
		_build_tiles(root, rng)
	elif style == GroundStyle.BOARDS:
		_build_boards(root, rng)
	elif decor_theme == "Beach":
		_build_sand(root, rng)
	else:
		_build_lawn(root)
		_build_lawn_border(root, rng)
		if decor_theme == "Agility":
			for side in [-1.0, 1.0]:
				for i in 14:
					_floor_strip(root, Vector3(0.65, 0.01, 0.065), Color("d7dcba"), Vector3(-size.x * 0.5 + 2.0 + i * (size.x - 4.0) / 13.0, 0.032, side * (size.y * 0.5 - 1.25)))


## A mown checkerboard: squares of light and dark grass a couple of metres across. A flat green
## floor gave the eye nothing to measure a throw or a run against; the squares do, and they
## are what makes a toy-sized lawn read as a tended little arena rather than a field.
func _build_lawn(parent: Node3D) -> void:
	var cols := maxi(2, int(round(size.x / LAWN_SQUARE)))
	var rows := maxi(2, int(round(size.y / LAWN_SQUARE)))
	var width := size.x / cols
	var depth := size.y / rows
	var light := ground_color.lightened(0.07)
	var dark := ground_color.darkened(0.06)
	for row in rows:
		for col in cols:
			_floor_strip(parent, Vector3(width, 0.009, depth), light if (row + col) % 2 == 0 else dark,
				Vector3(-size.x * 0.5 + (col + 0.5) * width, 0.018, -size.y * 0.5 + (row + 0.5) * depth))


func _floor_strip(parent: Node3D, dimensions: Vector3, tint: Color, at: Vector3) -> void:
	var mesh := Mats.mesh_plain(parent, Mats.box(dimensions), tint, at)
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _build_tiles(parent: Node3D, rng: RandomNumberGenerator, tile: float = 1.65) -> void:
	var cols := int(ceil(size.x / tile))
	var rows := int(ceil(size.y / tile))
	var width := size.x / cols
	var depth := size.y / rows
	for row in rows:
		for col in cols:
			var tint := ground_color if (row + col) % 2 == 0 else ground_accent
			if decor_theme == "Warp":
				tint = ground_color.lerp(ground_accent, rng.randf_range(0.1, 0.8))
			else:
				tint = tint.lightened(rng.randf_range(0.0, 0.025))
			_floor_strip(parent, Vector3(width - 0.028, 0.018, depth - 0.028), tint,
				Vector3(-size.x * 0.5 + (col + 0.5) * width, 0.021, -size.y * 0.5 + (row + 0.5) * depth))
	# Thin inset border frames the field without increasing the visual contrast in the lanes.
	for side in [-1.0, 1.0]:
		_floor_strip(parent, Vector3(size.x, 0.014, 0.15), wall_accent, Vector3(0, 0.034, side * (size.y * 0.5 - 0.12)))
		_floor_strip(parent, Vector3(0.15, 0.014, size.y), wall_accent, Vector3(side * (size.x * 0.5 - 0.12), 0.034, 0))


func _build_boards(parent: Node3D, rng: RandomNumberGenerator) -> void:
	var rows := int(ceil(size.y / 0.9))
	var depth := size.y / rows
	var board_length := 4.25
	for row in rows:
		var x := -size.x * 0.5 - (board_length * 0.5 if row % 2 == 1 else 0.0)
		while x < size.x * 0.5:
			var left := maxf(x, -size.x * 0.5)
			var right := minf(x + board_length, size.x * 0.5)
			var tint := ground_color.lerp(ground_accent, rng.randf_range(0.08, 0.72))
			_floor_strip(parent, Vector3(right - left - 0.022, 0.015, depth - 0.018), tint,
				Vector3((left + right) * 0.5, 0.021, -size.y * 0.5 + (row + 0.5) * depth))
			x += board_length


func _build_lawn_border(parent: Node3D, rng: RandomNumberGenerator) -> void:
	for side in [-1.0, 1.0]:
		_floor_strip(parent, Vector3(size.x, 0.02, 0.42), ground_accent.darkened(0.10), Vector3(0, 0.026, side * (size.y * 0.5 - 0.21)))
		for i in int(size.x / 1.05):
			var p := Vector3(-size.x * 0.5 + 0.6 + i * 1.05, 0.05, side * (size.y * 0.5 - 0.19))
			if flowers and i % 3 == 0:
				ArenaArt.flower(parent, p + Vector3(0, 0.07, 0), Color("fff1c6") if i % 2 == 0 else Color("e6a191"), 0.075)
			elif rng.randf() > 0.45:
				for blade in 2:
					var leaf := Mats.mesh(parent, Mats.cone(0.038, 0.18), ground_accent.lightened(0.16), p + Vector3(blade * 0.08, 0.07, 0))
					leaf.rotation_degrees.z = -18.0 + blade * 36.0


func _build_sand(parent: Node3D, rng: RandomNumberGenerator) -> void:
	# Wind ripples: broken pale ridges across the sand, so the floor has a grain to read a run
	# and a throw against instead of being one flat colour.
	var ridge := ground_color.lightened(0.09)
	var trough := ground_color.darkened(0.05)
	var z := -size.y * 0.5 + 1.1
	while z < size.y * 0.5 - 0.9:
		var x := -size.x * 0.5 + rng.randf_range(0.4, 1.4)
		while x < size.x * 0.5 - 1.0:
			var length := minf(rng.randf_range(1.4, 3.2), size.x * 0.5 - 0.6 - x)
			var bend := rng.randf_range(-0.12, 0.12)
			_floor_strip(parent, Vector3(length, 0.008, 0.09), ridge, Vector3(x + length * 0.5, 0.017, z + bend))
			_floor_strip(parent, Vector3(length * 0.9, 0.007, 0.07), trough, Vector3(x + length * 0.5, 0.016, z + bend + 0.12))
			x += length + rng.randf_range(0.5, 1.6)
		z += rng.randf_range(1.05, 1.45)
	# Small, composed shell groups sit at the margin.
	for side in [-1.0, 1.0]:
		_floor_strip(parent, Vector3(size.x, 0.012, 0.45), ground_accent, Vector3(0, 0.022, side * (size.y * 0.5 - 0.25)))
		for i in 16:
			var p := Vector3(rng.randf_range(-size.x * 0.5 + 0.8, size.x * 0.5 - 0.8), 0.06, side * (size.y * 0.5 - 0.4))
			Mats.mesh(parent, Mats.sphere(rng.randf_range(0.06, 0.12)), Color("efdbc0"), p, Vector3.ZERO, Vector3(1.0, 0.35, 0.7))


## Dressing stays beyond the authored collision boundary.
func _build_garden() -> void:
	var garden := Node3D.new()
	garden.name = "Garden"
	add_child(garden)
	var hx := size.x * 0.5
	var hz := size.y * 0.5
	if decor_theme == "Beach":
		_build_seaside(garden, hx, hz)
	else:
		var leaf_colors := [Color("548469"), Color("71995e"), Color("8ba669")]
		for i in 5:
			var x := -hx + float(i) * size.x / 4.0
			var z := -hz - 2.4 - sin(float(i) * 2.0) * 0.5
			Mats.mesh(garden, Mats.cylinder(0.17, 2.2, 0.12), Color("816550"), Vector3(x, 1.0, z))
			for j in 3:
				var crown := Vector3(x + (j - 1) * 0.65, 2.5 + (0.6 if j == 1 else 0.0), z + j * 0.12)
				Mats.mesh(garden, Mats.sphere(1.15), leaf_colors[(i + j) % 3], crown, Vector3.ZERO, Vector3(1.0, 0.96, 0.85))
		for side in [-1.0, 1.0]:
			for i in 5:
				var p := Vector3(side * (hx + 1.0), 0.18, -hz + i * size.y / 4.0)
				ArenaArt.block(garden, Vector3(0.9, 0.3, 1.55), wall_accent.darkened(0.18), p)
				Mats.mesh(garden, Mats.sphere(0.68), leaf_colors[i % 3], p + Vector3(0, 0.42, 0), Vector3.ZERO, Vector3(0.8, 0.7, 1.25))
		if decor_theme == "Agility":
			_build_bunting(garden, hx, hz)
		elif decor_theme == "Warp":
			_build_fairy_lights(garden, hx, hz)
	_build_sign(garden, hz)


func _build_sign(parent: Node3D, hz: float) -> void:
	if sign_text.is_empty():
		return
	for x in [-1.25, 1.25]:
		ArenaArt.block(parent, Vector3(0.12, 1.8, 0.12), wall_accent, Vector3(x, 0.9, -hz - 0.75))
	ArenaArt.block(parent, Vector3(3.4, 0.92, 0.18), wall_accent.darkened(0.22), Vector3(0, 1.7, -hz - 0.75))
	ArenaArt.block(parent, Vector3(3.23, 0.73, 0.06), wall_color, Vector3(0, 1.7, -hz - 0.63), Vector3.ZERO, 0.035)
	var plate := Label3D.new()
	plate.text = sign_text
	plate.font = UiKit.FONT_DISPLAY
	plate.font_size = 48
	plate.pixel_size = 0.0035
	plate.modulate = Color("fff3d8")
	plate.outline_size = 0
	plate.position = Vector3(0, 1.7, -hz - 0.58)
	parent.add_child(plate)


func _build_bunting(parent: Node3D, hx: float, hz: float) -> void:
	var colors := [Color("df8c6c"), Color("e8bf65"), Color("7aabbb")]
	# Typed: a bare literal array hands out Variants, and nothing inside can then be inferred.
	for side: float in [-1.0, 1.0]:
		var x := side * (hx - 2.0)
		ArenaArt.rod(parent, Vector3(x, 0, -hz - 0.5), Vector3(x, 2.6, -hz - 0.5), 0.055, wall_accent)
	for i in 13:
		var x := lerpf(-hx + 2.0, hx - 2.0, float(i) / 12.0)
		var y := 2.6 - sin(float(i) / 12.0 * PI) * 0.5
		Mats.mesh(parent, Mats.prism(Vector3(0.52, 0.55, 0.035)), colors[i % 3], Vector3(x, y - 0.25, -hz - 0.5), Vector3(0, 0, 180))
		if i < 12:
			var next_x := lerpf(-hx + 2.0, hx - 2.0, float(i + 1) / 12.0)
			var next_y := 2.6 - sin(float(i + 1) / 12.0 * PI) * 0.5
			ArenaArt.rod(parent, Vector3(x, y, -hz - 0.5), Vector3(next_x, next_y, -hz - 0.5), 0.018, Color("efe4c9"))


func _build_seaside(parent: Node3D, hx: float, hz: float) -> void:
	for side in [-1.0, 1.0]:
		_floor_strip(parent, Vector3(size.x + 4.0, 0.06, 1.25), Color("d5bb86"), Vector3(0, -0.3, side * (hz + 0.8)))
		for row in 2:
			_floor_strip(parent, Vector3(size.x + 6.0 + row * 3.0, 0.025, 0.14), Color("bbdfd7").lerp(surround_color, row * 0.25), Vector3(0, -0.46, side * (hz + 1.6 + row * 1.2)))
	for side in [-1.0, 1.0]:
		var p := Vector3(side * (hx + 0.85), 0, -hz - 1.0)
		ArenaArt.rod(parent, p + Vector3(0, -0.4, 0), p + Vector3(-side * 0.45, 3.4, 0), 0.19, Color("b38960"))
		var top := p + Vector3(-side * 0.45, 3.4, 0)
		for i in 7:
			var angle := TAU * float(i) / 7.0
			var direction := Vector3(cos(angle), 0, sin(angle))
			var leaf := Mats.mesh(parent, Mats.sphere(0.72), Color("548f78") if i % 2 == 0 else Color("72a67d"), top + direction * 0.75 - Vector3(0, 0.1, 0))
			leaf.scale = Vector3(1.6, 0.13, 0.47)
			leaf.rotation.y = -angle


## Warm bulbs strung along the back fence: a backyard after dark, lit for one more game of
## fetch. Unshaded, so they glow against the dusk whatever the key light is doing.
func _build_fairy_lights(parent: Node3D, hx: float, hz: float) -> void:
	var z := -hz - 0.35
	for side: float in [-1.0, 0.0, 1.0]:
		ArenaArt.rod(parent, Vector3(side * (hx - 0.4), 0, z), Vector3(side * (hx - 0.4), 2.3, z), 0.05, wall_accent)
	var bulbs := [Color("ffd98a"), Color("ffb877"), Color("fff0c2")]
	for span in 2:
		var x0 := -hx + 0.4 + span * (hx - 0.4)
		var x1 := x0 + hx - 0.4
		for i in 14:
			var t := float(i) / 13.0
			var at := Vector3(lerpf(x0, x1, t), 2.3 - sin(t * PI) * 0.45, z)
			var bulb := Mats.mesh(parent, Mats.sphere(0.085), bulbs[i % 3], at + Vector3(0, -0.1, 0))
			bulb.material_override = Mats.unlit(bulbs[i % 3])
			bulb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			if i < 13:
				var t2 := float(i + 1) / 13.0
				ArenaArt.rod(parent, at, Vector3(lerpf(x0, x1, t2), 2.3 - sin(t2 * PI) * 0.45, z), 0.012, Color("3b3440"))


func _build_room_details() -> void:
	var decor := Node3D.new()
	decor.name = "RoomDetails"
	add_child(decor)
	var hz := size.y * 0.5
	# Framed prints and inset wall panels decorate the back rim, clear of every sight line.
	for side in [-1.0, 1.0]:
		var p := Vector3(side * size.x * 0.28, wall_height * 0.66, -hz - 0.19)
		ArenaArt.block(decor, Vector3(1.6, 0.75, 0.1), wall_accent, p, Vector3.ZERO, 0.035)
		ArenaArt.block(decor, Vector3(1.42, 0.58, 0.025), Color("f2e7cf"), p + Vector3(0, 0, 0.064), Vector3.ZERO, 0.02)
		Mats.mesh(decor, Mats.cylinder(0.2, 0.02), Color("c98167") if side < 0 else Color("789e9c"), p + Vector3(-0.28, 0.04, 0.085), Vector3(90, 0, 0))
		ArenaArt.block(decor, Vector3(0.45, 0.24, 0.022), Color("e0b46c"), p + Vector3(0.29, -0.08, 0.09), Vector3.ZERO, 0.025)


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
	for z in [-hz - 0.15, hz + 0.15]:
		var count := int(ceil(size.x / 1.65))
		for i in count + 1:
			_fence_post(parent, Vector3(lerpf(-hx, hx, float(i) / count), 0, z))
		for y in [wall_height * 0.31, wall_height * 0.72]:
			ArenaArt.block(parent, Vector3(size.x + 0.55, 0.14, 0.12), wall_accent, Vector3(0, y, z), Vector3.ZERO, 0.025)
	for x in [-hx - 0.15, hx + 0.15]:
		var count := int(ceil(size.y / 1.65))
		for i in count + 1:
			_fence_post(parent, Vector3(x, 0, lerpf(-hz, hz, float(i) / count)))
		for y in [wall_height * 0.31, wall_height * 0.72]:
			ArenaArt.block(parent, Vector3(0.12, 0.14, size.y + 0.55), wall_accent, Vector3(x, y, 0), Vector3.ZERO, 0.025)


func _fence_post(parent: Node3D, p: Vector3) -> void:
	ArenaArt.block(parent, Vector3(0.23, wall_height, 0.23), wall_color, p + Vector3(0, wall_height * 0.5, 0), Vector3.ZERO, 0.035)
	ArenaArt.block(parent, Vector3(0.32, 0.1, 0.32), wall_color.lightened(0.12), p + Vector3(0, wall_height, 0), Vector3.ZERO, 0.04)
	ArenaArt.block(parent, Vector3(0.3, 0.13, 0.3), wall_accent, p + Vector3(0, 0.07, 0), Vector3.ZERO, 0.025)


func _build_baseboard(parent: Node3D, hx: float, hz: float) -> void:
	var t := 0.42
	for side: float in [-1.0, 1.0]:
		var height := wall_height * (0.5 if side > 0.0 else 1.0)
		var z := side * (hz + t * 0.5)
		ArenaArt.block(parent, Vector3(size.x + t * 2.0, height, t), wall_color, Vector3(0, height * 0.5, z))
		ArenaArt.block(parent, Vector3(size.x + t * 2.0 + 0.08, 0.12, t + 0.09), wall_color.lightened(0.13), Vector3(0, height, z), Vector3.ZERO, 0.025)
		ArenaArt.block(parent, Vector3(size.x + t * 2.0, 0.16, t + 0.07), wall_accent, Vector3(0, 0.1, z), Vector3.ZERO, 0.025)
		var x := side * (hx + t * 0.5)
		ArenaArt.block(parent, Vector3(t, wall_height, size.y + t * 2.0), wall_color, Vector3(x, wall_height * 0.5, 0))
		ArenaArt.block(parent, Vector3(t + 0.09, 0.12, size.y + t * 2.0), wall_color.lightened(0.13), Vector3(x, wall_height, 0), Vector3.ZERO, 0.025)
		ArenaArt.block(parent, Vector3(t + 0.07, 0.16, size.y + t * 2.0), wall_accent, Vector3(x, 0.1, 0), Vector3.ZERO, 0.025)
		for i in int(size.y / 2.5):
			var z_panel := -hz + (i + 0.5) * size.y / int(size.y / 2.5)
			ArenaArt.block(parent, Vector3(0.025, wall_height * 0.54, 1.9), wall_color.darkened(0.055), Vector3(x - side * 0.22, wall_height * 0.5, z_panel), Vector3.ZERO, 0.012)


## A shape a dog actually bumps into: walls, props and dog beds on the world layer. Sight-line
## occluders (tunnel, A-frame) and trigger areas are not solid.
static func is_solid_shape(collider: CollisionShape3D) -> bool:
	var body := collider.get_parent() as CollisionObject3D
	if not (body is StaticBody3D or body is AnimatableBody3D):
		return false
	return body.collision_layer & 1 != 0


## Uses authored collision shapes, including before the first physics tick.
func is_clear_position(at: Vector3, radius: float) -> bool:
	var local := to_local(at)
	if absf(local.x) + radius > size.x * 0.5 or absf(local.z) + radius > size.y * 0.5:
		return false
	for pit in find_children("*", "Pit", true, false):
		if (pit as Pit).covers(at, radius + 0.4):
			return false
	for node in find_children("*", "CollisionShape3D", true, false):
		var collider := node as CollisionShape3D
		if collider.disabled or not is_solid_shape(collider):
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
