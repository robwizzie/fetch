class_name BoneBreak
extends Control
## The point a self-bonk costs, made into something you watch go: a bone pops up off the
## player's card, wobbles, snaps in two, and the halves tumble off the bottom of the screen
## with a few crumbs. Draws itself; runs on real time, so knockout slow motion cannot stall it.

const LENGTH := 96.0
const THICK := 21.0
const KNOB := 16.0
const FILL := Color("fff1d2")
const EDGE := Color("3a1f10")
const GRAVITY := 2400.0

## -1 the left half, 1 the right half, 0 the whole bone; 2 is a crumb.
var piece := 0
var _velocity := Vector2.ZERO
var _spin := 0.0
var _age := 0.0
var _falling := false


## Starts the whole show at [param at] in [param parent]'s space.
static func play(parent: Control, at: Vector2) -> void:
	var bone := BoneBreak.new()
	bone.position = at
	bone.scale = Vector2.ZERO
	parent.add_child(bone)
	var show := bone.create_tween().set_ignore_time_scale(true)
	# Out of the card and down onto the field, where there is room to see it go.
	show.tween_property(bone, "position", at + Vector2(0, 150), 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	show.parallel().tween_property(bone, "scale", Vector2.ONE * 1.3, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	show.tween_property(bone, "scale", Vector2.ONE, 0.08)
	# The wobble before it goes: it knows.
	for i in 6:
		show.tween_property(bone, "rotation", 0.24 * (1.0 if i % 2 == 0 else -1.0), 0.055)
	show.tween_property(bone, "rotation", 0.0, 0.05)
	show.tween_callback(bone._snap)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _snap() -> void:
	Sfx.play("squeak", 0.62, -2.0)
	for side in [-1, 1]:
		var half := BoneBreak.new()
		half.piece = side
		half.position = position + Vector2(side * (LENGTH * 0.5 - KNOB) * 0.5, 0)
		half._velocity = Vector2(side * randf_range(150.0, 230.0), randf_range(-620.0, -520.0))
		half._spin = side * randf_range(5.0, 8.0)
		half._falling = true
		get_parent().add_child(half)
	for i in 6:
		var crumb := BoneBreak.new()
		crumb.piece = 2
		crumb.position = position
		crumb._velocity = Vector2(randf_range(-260.0, 260.0), randf_range(-520.0, -200.0))
		crumb._falling = true
		get_parent().add_child(crumb)
	queue_free()


func _process(delta: float) -> void:
	if not _falling:
		return
	var step := delta / maxf(Engine.time_scale, 0.01)
	_age += step
	_velocity.y += GRAVITY * step
	position += _velocity * step
	rotation += _spin * step
	modulate.a = clampf(1.4 - _age, 0.0, 1.0)
	if _age > 1.4 or position.y > get_viewport_rect().size.y + 80.0:
		queue_free()


func _draw() -> void:
	if piece == 2:
		draw_circle(Vector2.ZERO, 7.0, EDGE)
		draw_circle(Vector2.ZERO, 4.5, FILL)
		return
	# Outline first, as the same shapes grown, then the fill on top.
	_shape(4.0, EDGE)
	_shape(0.0, FILL)
	# A crack line on the broken end of a half.
	if piece != 0:
		# The broken end: where the middle of the whole bone was, after the half's shift.
		var x := -float(piece) * (LENGTH * 0.5 - KNOB) * 0.5
		var crack := PackedVector2Array([Vector2(x, -THICK * 0.5), Vector2(x - piece * 8.0, -3), Vector2(x + piece * 3.0, 3),
			Vector2(x - piece * 6.0, THICK * 0.5)])
		draw_polyline(crack, EDGE, 3.5, true)


func _shape(grow: float, color: Color) -> void:
	var half_length := LENGTH * 0.5 - KNOB
	# The whole bone runs -half_length..half_length. A half keeps its own side, drawn about its
	# own middle so it spins about it as it flies; its broken end has no knobs.
	var from := -half_length if piece <= 0 else 0.0
	var to := half_length if piece >= 0 else 0.0
	var shift := -float(piece) * half_length * 0.5
	from += shift
	to += shift
	var knob_left := piece <= 0
	var knob_right := piece >= 0
	var left := from - (grow if knob_left else 0.0)
	var right := to + (grow if knob_right else 0.0)
	draw_rect(Rect2(left, -THICK * 0.5 - grow, right - left, THICK + grow * 2.0), color)
	for lobe in [-1.0, 1.0]:
		if knob_left:
			draw_circle(Vector2(from, lobe * KNOB * 0.72), KNOB + grow, color)
		if knob_right:
			draw_circle(Vector2(to, lobe * KNOB * 0.72), KNOB + grow, color)
