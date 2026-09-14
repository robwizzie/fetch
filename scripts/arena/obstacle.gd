@tool
class_name Obstacle
extends StaticBody2D
## A solid rectangular prop (crate, table, doghouse, couch...). Toys bounce off it, dogs can't pass.
## Set size/colour/label in the inspector; a real sprite can replace the drawing later.

@export var size := Vector2(120, 120):
	set(v):
		size = v
		_refresh()
@export var color := Color(0.75, 0.55, 0.3):
	set(v):
		color = v
		queue_redraw()
@export var label := "":
	set(v):
		label = v
		queue_redraw()
@export var rounded := 12.0

var _shape: CollisionShape2D


func _ready() -> void:
	collision_layer = 1
	collision_mask = 0
	_refresh()


func _refresh() -> void:
	if _shape == null:
		_shape = CollisionShape2D.new()
		_shape.shape = RectangleShape2D.new()
		add_child(_shape)
	(_shape.shape as RectangleShape2D).size = size
	queue_redraw()


func _draw() -> void:
	var r := Rect2(-size / 2.0, size)
	draw_rect(Rect2(r.position + Vector2(6, 8), r.size), Color(0, 0, 0, 0.22))
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(int(rounded))
	style.border_color = color.darkened(0.35)
	style.set_border_width_all(5)
	draw_style_box(style, r)
	# Top highlight to give it some volume
	draw_rect(Rect2(r.position + Vector2(10, 10), Vector2(r.size.x - 20, 8)), color.lightened(0.25))
	if label != "":
		var font := ThemeDB.fallback_font
		draw_string(font, Vector2(-size.x / 2.0, 8), label, HORIZONTAL_ALIGNMENT_CENTER, size.x, 20, color.darkened(0.5))
