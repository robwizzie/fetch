class_name ToyVisual
extends Node2D
## Procedural placeholder art for toys. Picks a shape by toy id; everything else is colour.

var data: ToyData
var _held := false


func setup(p_data: ToyData) -> void:
	data = p_data
	queue_redraw()


func set_held(v: bool) -> void:
	_held = v
	queue_redraw()


func _draw() -> void:
	if data == null:
		return
	var r := data.radius
	if not _held:
		draw_circle(Vector2(0, 4), r * 1.05, Color(0, 0, 0, 0.18))
	match data.id:
		&"frisbee":
			draw_circle(Vector2.ZERO, r, data.color)
			draw_arc(Vector2.ZERO, r * 0.6, 0.0, TAU, 24, data.color.darkened(0.25), 3.0, true)
		&"bone":
			draw_line(Vector2(-r * 0.7, 0), Vector2(r * 0.7, 0), data.color, r * 0.7)
			for p in [Vector2(-r * 0.7, -r * 0.4), Vector2(-r * 0.7, r * 0.4), Vector2(r * 0.7, -r * 0.4), Vector2(r * 0.7, r * 0.4)]:
				draw_circle(p, r * 0.45, data.color)
		&"rope_toy":
			draw_line(Vector2(-r, 0), Vector2(r, 0), data.color, r * 0.8)
			draw_line(Vector2(-r, 0), Vector2(r, 0), data.color.darkened(0.3), r * 0.25)
		&"squeaky_chicken":
			draw_circle(Vector2(-r * 0.2, 0), r * 0.9, data.color)
			draw_circle(Vector2(r * 0.7, -r * 0.3), r * 0.5, data.color)
			draw_circle(Vector2(r * 1.1, -r * 0.3), r * 0.2, Color(1.0, 0.5, 0.1))
		_:
			# Tennis ball / super ball: circle with seam lines
			draw_circle(Vector2.ZERO, r, data.color)
			draw_arc(Vector2(-r * 0.9, 0), r * 0.85, -0.9, 0.9, 12, Color(1, 1, 1, 0.8), 2.5, true)
			draw_arc(Vector2(r * 0.9, 0), r * 0.85, PI - 0.9, PI + 0.9, 12, Color(1, 1, 1, 0.8), 2.5, true)
			if data.special == ToyData.Special.RICOCHET:
				draw_circle(Vector2.ZERO, r * 0.35, Color(1, 1, 1, 0.5))
