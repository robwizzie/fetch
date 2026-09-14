@tool
class_name SlowZone
extends Area2D
## An area that slows dogs while inside (kiddie pool, mud, rug). Toys fly over it unaffected.

@export var radius := 110.0:
	set(v):
		radius = v
		_refresh()
@export var color := Color(0.3, 0.7, 1.0, 0.9):
	set(v):
		color = v
		queue_redraw()
@export_range(0.1, 1.0) var slow_factor := 0.55

var _shape: CollisionShape2D


func _ready() -> void:
	collision_layer = 8
	collision_mask = 2
	monitorable = false
	_refresh()
	if not Engine.is_editor_hint():
		body_entered.connect(_on_body_entered)
		body_exited.connect(_on_body_exited)


func _refresh() -> void:
	if _shape == null:
		_shape = CollisionShape2D.new()
		_shape.shape = CircleShape2D.new()
		add_child(_shape)
	(_shape.shape as CircleShape2D).radius = radius
	queue_redraw()


func _on_body_entered(body: Node2D) -> void:
	if body is Dog:
		body.speed_scale = slow_factor


func _on_body_exited(body: Node2D) -> void:
	if body is Dog:
		body.speed_scale = 1.0


func _draw() -> void:
	draw_circle(Vector2.ZERO, radius + 10.0, color.darkened(0.3))
	draw_circle(Vector2.ZERO, radius, color)
	draw_arc(Vector2(-radius * 0.3, -radius * 0.3), radius * 0.45, PI, PI * 1.6, 10, Color(1, 1, 1, 0.5), 5.0, true)
