class_name Arena
extends Node2D
## Base for every arena scene. Draws the ground, builds the outer walls from [member size],
## and exposes spawn points. Author obstacles as child nodes (see obstacle.gd, slow_zone.gd).
## To make a new arena: duplicate scenes/arenas/backyard.tscn, move things around, add an ArenaData.

@export var size := Vector2(1920, 1080)
@export var wall_thickness := 48.0
@export var ground_color := Color(0.45, 0.7, 0.3)
@export var ground_accent := Color(0.4, 0.66, 0.27)
@export var wall_color := Color(0.5, 0.35, 0.2)
@export var wall_accent := Color(0.42, 0.28, 0.15)
## Deterministic seed for the decorative ground pattern.
@export var pattern_seed := 7

@onready var spawn_points: Node2D = $SpawnPoints
@onready var toy_spawns: Node2D = $ToySpawns


func _ready() -> void:
	_build_walls()
	queue_redraw()


func get_spawn_position(i: int) -> Vector2:
	var points := spawn_points.get_children()
	if points.is_empty():
		return size / 2.0
	return (points[i % points.size()] as Node2D).global_position


func get_toy_spawn_position(i: int) -> Vector2:
	var points := toy_spawns.get_children()
	if points.is_empty():
		return size / 2.0
	return (points[i % points.size()] as Node2D).global_position


func _build_walls() -> void:
	var walls := StaticBody2D.new()
	walls.name = "Walls"
	walls.collision_layer = 1
	walls.collision_mask = 0
	var t := wall_thickness
	var rects := [
		Rect2(0, 0, size.x, t),
		Rect2(0, size.y - t, size.x, t),
		Rect2(0, 0, t, size.y),
		Rect2(size.x - t, 0, t, size.y),
	]
	for r in rects:
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = r.size
		shape.shape = rect
		shape.position = r.position + r.size / 2.0
		walls.add_child(shape)
	add_child(walls)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), ground_color)
	var rng := RandomNumberGenerator.new()
	rng.seed = pattern_seed
	for i in 40:
		var p := Vector2(rng.randf_range(0, size.x), rng.randf_range(0, size.y))
		draw_circle(p, rng.randf_range(30, 90), ground_accent)
	_draw_walls()


func _draw_walls() -> void:
	var t := wall_thickness
	draw_rect(Rect2(0, 0, size.x, t), wall_color)
	draw_rect(Rect2(0, size.y - t, size.x, t), wall_color)
	draw_rect(Rect2(0, 0, t, size.y), wall_color)
	draw_rect(Rect2(size.x - t, 0, t, size.y), wall_color)
	# Fence posts / trim
	var step := 96.0
	var x := 0.0
	while x < size.x:
		draw_rect(Rect2(x, 0, 12, t), wall_accent)
		draw_rect(Rect2(x, size.y - t, 12, t), wall_accent)
		x += step
	var y := 0.0
	while y < size.y:
		draw_rect(Rect2(0, y, t, 12), wall_accent)
		draw_rect(Rect2(size.x - t, y, t, 12), wall_accent)
		y += step
