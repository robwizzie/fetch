class_name DogVisual
extends Node2D
## Procedural placeholder art for a dog, drawn from DogData colours.
## Swap this node for an AnimatedSprite2D when real art lands; the Dog only calls
## setup(), update_motion(), set_dashing() and play_knocked_out().

var data: DogData
var player_color := Color.WHITE
var _speed01 := 0.0
var _walk_phase := 0.0
var _dashing := false
var _catching := false
var _knocked_out := false


func setup(p_data: DogData, p_color: Color) -> void:
	data = p_data
	player_color = p_color
	queue_redraw()


func update_motion(facing: Vector2, speed01: float) -> void:
	if _knocked_out:
		return
	rotation = facing.angle()
	_speed01 = speed01
	_walk_phase += speed01 * 0.35
	queue_redraw()


func set_dashing(v: bool) -> void:
	_dashing = v
	queue_redraw()


func set_catching(v: bool) -> void:
	_catching = v
	queue_redraw()


func play_knocked_out(dir: Vector2) -> void:
	_knocked_out = true
	var t := create_tween().set_parallel(true)
	t.tween_property(self, "rotation", rotation + TAU * 2.0, 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_property(self, "position", position + dir * 70.0, 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_property(self, "modulate", Color(1, 1, 1, 0.35), 0.7)
	t.tween_property(self, "scale", scale * 0.8, 0.7)
	queue_redraw()


func _draw() -> void:
	if data == null:
		return
	var fur := data.fur_color
	var accent := data.accent_color
	if _dashing:
		fur = fur.lightened(0.35)

	# Shadow
	draw_circle(Vector2(0, 5), 26.0, Color(0, 0, 0, 0.18))

	# Legs (wiggle while moving)
	var leg := sin(_walk_phase) * 6.0 * _speed01
	draw_line(Vector2(-14, -12), Vector2(-16 + leg, -20), fur, 7.0)
	draw_line(Vector2(-14, 12), Vector2(-16 - leg, 20), fur, 7.0)
	draw_line(Vector2(6, -12), Vector2(8 - leg, -20), fur, 7.0)
	draw_line(Vector2(6, 12), Vector2(8 + leg, 20), fur, 7.0)

	# Tail
	var wag := sin(_walk_phase * 2.0 + Time.get_ticks_msec() * 0.01) * 6.0
	draw_line(Vector2(-26, 0), Vector2(-40, wag), fur, 6.0)

	# Body + head
	draw_circle(Vector2(-8, 0), 21.0, fur)
	draw_circle(Vector2(14, 0), 16.0, fur)

	# Ears
	draw_circle(Vector2(7, -14), 7.0, accent)
	draw_circle(Vector2(7, 14), 7.0, accent)

	# Bandana in the dog's own colour
	draw_arc(Vector2(0, 0), 15.0, -1.3, 1.3, 14, data.bandana_color, 6.0, true)

	# Catch pose: paws out front
	if _catching:
		draw_circle(Vector2(30, -12), 6.0, accent)
		draw_circle(Vector2(30, 12), 6.0, accent)
		draw_arc(Vector2(14, 0), 34.0, -0.9, 0.9, 12, Color(1, 1, 1, 0.5), 3.0, true)

	# Snout, nose, eyes
	draw_circle(Vector2(26, 0), 7.5, accent)
	draw_circle(Vector2(31, 0), 3.2, Color(0.08, 0.06, 0.06))
	draw_circle(Vector2(19, -6), 2.6, Color(0.08, 0.06, 0.06))
	draw_circle(Vector2(19, 6), 2.6, Color(0.08, 0.06, 0.06))
	draw_circle(Vector2(20, -7), 0.9, Color.WHITE)
	draw_circle(Vector2(20, 5), 0.9, Color.WHITE)
