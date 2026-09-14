class_name Arena
extends Node3D
## Base for every arena scene. Builds the ground, the outer walls (collision + fence/baseboard
## visuals), decorative ground patches, and exposes spawn points. Camera, light and environment
## are child nodes of the arena scene so each arena can have its own mood.
## To make a new arena: duplicate scenes/arenas/backyard.tscn, move things around, add an ArenaData.

enum WallStyle { FENCE, BASEBOARD, NONE }

## Playable area in metres (x = width, y = depth), centred on the origin.
@export var size := Vector2(26, 14.6)
@export var wall_style := WallStyle.FENCE
@export var wall_height := 1.1
@export var ground_color := Color(0.38, 0.68, 0.26)
@export var ground_accent := Color(0.36, 0.66, 0.26)
@export var wall_color := Color(0.62, 0.42, 0.24)
@export var wall_accent := Color(0.5, 0.33, 0.18)
## Ground outside the walls (so the perspective camera never shows the void).
@export var surround_color := Color(0.3, 0.5, 0.22)
@export var flowers := true
@export var pattern_seed := 7

@onready var spawn_points: Node3D = $SpawnPoints
@onready var toy_spawns: Node3D = $ToySpawns


func _ready() -> void:
	_build_ground()
	_build_walls()


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
	for i in 26:
		var p := Vector3(rng.randf_range(-size.x / 2.0, size.x / 2.0), 0.012, rng.randf_range(-size.y / 2.0, size.y / 2.0))
		var patch := Mats.mesh(root, Mats.cylinder(rng.randf_range(0.6, 1.8), 0.02), ground_accent, p)
		patch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if flowers:
		var colors := [Color(1, 0.85, 0.3), Color(1, 0.5, 0.6), Color(0.95, 0.95, 1.0), Color(0.6, 0.5, 1.0)]
		for i in 30:
			var p := Vector3(rng.randf_range(-size.x / 2.0 + 1.0, size.x / 2.0 - 1.0), 0.12, rng.randf_range(-size.y / 2.0 + 1.0, size.y / 2.0 - 1.0))
			Mats.mesh(root, Mats.cylinder(0.03, 0.25), Color(0.3, 0.6, 0.25), p)
			Mats.mesh(root, Mats.sphere(0.09), colors[i % colors.size()], p + Vector3(0, 0.15, 0))


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
