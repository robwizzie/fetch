class_name SelectCursor
extends Control
## One player's pointer on the dog select screen: a coin in their colour with their tag on it
## and a tip pointing at what they are on. Glides to its target rather than jumping, so you can
## follow your own across a busy screen. Also used, smaller and without the tip, as the token a
## player leaves on the dog they picked.

const SIZE := 64.0

var tag := "P1"
var color := Color.WHITE
## Draws the pointer tip. Off for a placed token.
var pointer := true
## Where the tip should be, in this control's parent's coordinates.
var target := Vector2.ZERO
var _placed := false


static func make(p_tag: String, p_color: Color, diameter: float = SIZE, p_pointer: bool = true) -> SelectCursor:
	var cursor := SelectCursor.new()
	cursor.tag = p_tag
	cursor.color = p_color
	cursor.pointer = p_pointer
	cursor.custom_minimum_size = Vector2(diameter, diameter)
	cursor.size = Vector2(diameter, diameter)
	cursor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return cursor


func _process(delta: float) -> void:
	if not pointer:
		return
	# The tip sits at the coin's bottom-left; the coin hangs up and to the right of the target.
	var want := target - Vector2(size.x * 0.1, size.y * 0.95)
	if not _placed:
		position = want
		_placed = true
	position = position.lerp(want, 1.0 - exp(-22.0 * delta))
	var bob := sin(Time.get_ticks_msec() * 0.008) * 2.0
	pivot_offset = size * 0.5
	rotation = deg_to_rad(bob)


func _draw() -> void:
	var radius := minf(size.x, size.y) * 0.5
	var middle := size * 0.5
	if pointer:
		# The tip: a little triangle from the coin's edge down to where it is pointing.
		var tip := Vector2(size.x * 0.1, size.y * 0.95)
		var a := middle + (tip - middle).normalized().rotated(0.5) * radius * 0.82
		var b := middle + (tip - middle).normalized().rotated(-0.5) * radius * 0.82
		draw_colored_polygon(PackedVector2Array([a, tip, b]), color.darkened(0.35))
	draw_circle(middle + Vector2(0, radius * 0.1), radius, Color(0, 0, 0, 0.35))
	draw_circle(middle, radius, color.darkened(0.35))
	draw_circle(middle, radius * 0.84, color)
	draw_arc(middle, radius * 0.84, PI * 1.1, PI * 1.9, 16, color.lightened(0.45), radius * 0.08, true)
	var font := UiKit.FONT_DISPLAY
	var font_size := int(radius * (0.78 if tag.length() <= 2 else 0.5))
	var text_size := font.get_string_size(tag, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
	var baseline := middle + Vector2(-text_size.x * 0.5, font_size * 0.36)
	draw_string_outline(font, baseline, tag, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, int(radius * 0.16), UiKit.INK)
	draw_string(font, baseline, tag, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, Color.WHITE)
