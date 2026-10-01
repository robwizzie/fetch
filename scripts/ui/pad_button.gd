class_name PadButton
extends Control
## A controller face button drawn the way it looks on the pad: a round button in the pad's own
## colour with its letter, or for PlayStation its shape. Someone holding a pad looks for "the
## green one" or "the square", not for the word SQUARE printed on a keyboard key.
##
## Shapes are drawn rather than typed because the game's fonts have no PlayStation symbols.

enum Glyph { LETTER, CROSS, CIRCLE, SQUARE, TRIANGLE }

var glyph := Glyph.LETTER
var letter := ""
var fill := Color.DIM_GRAY
var ink := Color.WHITE


static func make(p_glyph: Glyph, p_letter: String, p_fill: Color, p_ink: Color, diameter: float) -> PadButton:
	var button := PadButton.new()
	button.glyph = p_glyph
	button.letter = p_letter
	button.fill = p_fill
	button.ink = p_ink
	button.custom_minimum_size = Vector2(diameter, diameter)
	button.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return button


## The badge for one face button on one kind of pad, or null when it is not a face button
## (sticks, shoulders, Start) and should stay a text cap.
static func for_label(word: String, family: DeviceInput.PadFamily, diameter: float) -> PadButton:
	var dark := Color(0.13, 0.13, 0.16)
	match family:
		DeviceInput.PadFamily.XBOX:
			var colors := {"A": Color("5cb53b"), "B": Color("e2463c"), "X": Color("3f86e0"), "Y": Color("eab52a")}
			if colors.has(word):
				return make(Glyph.LETTER, word, colors[word], Color.WHITE, diameter)
		DeviceInput.PadFamily.PLAYSTATION:
			var shapes := {"Cross": [Glyph.CROSS, Color("8fb3f0")], "Circle": [Glyph.CIRCLE, Color("ef7b7b")],
				"Square": [Glyph.SQUARE, Color("e59ad6")], "Triangle": [Glyph.TRIANGLE, Color("4fd1b0")]}
			if shapes.has(word):
				return make(shapes[word][0], "", dark, shapes[word][1], diameter)
		DeviceInput.PadFamily.NINTENDO:
			if word in ["A", "B", "X", "Y"]:
				return make(Glyph.LETTER, word, dark, Color.WHITE, diameter)
	return null


func _draw() -> void:
	var middle := size * 0.5
	var radius := minf(size.x, size.y) * 0.5
	draw_circle(middle + Vector2(0, radius * 0.08), radius, fill.darkened(0.45))
	draw_circle(middle, radius * 0.94, fill)
	var mark := radius * 0.42
	var width := maxf(2.0, radius * 0.17)
	match glyph:
		Glyph.LETTER:
			var font := UiKit.FONT_DISPLAY
			var font_size := int(radius * 1.25)
			var text_size := font.get_string_size(letter, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
			draw_string(font, middle + Vector2(-text_size.x * 0.5, font_size * 0.36), letter,
				HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, ink)
		Glyph.CROSS:
			draw_line(middle + Vector2(-mark, -mark), middle + Vector2(mark, mark), ink, width, true)
			draw_line(middle + Vector2(-mark, mark), middle + Vector2(mark, -mark), ink, width, true)
		Glyph.CIRCLE:
			draw_arc(middle, mark, 0.0, TAU, 32, ink, width, true)
		Glyph.SQUARE:
			draw_rect(Rect2(middle - Vector2(mark, mark) * 0.9, Vector2(mark, mark) * 1.8), ink, false, width)
		Glyph.TRIANGLE:
			var points := PackedVector2Array([middle + Vector2(0, -mark * 1.05), middle + Vector2(mark, mark * 0.75),
				middle + Vector2(-mark, mark * 0.75), middle + Vector2(0, -mark * 1.05)])
			draw_polyline(points, ink, width, true)
