class_name UiKit
extends RefCounted
## Tiny helpers for building menu screens in code so every screen looks the same.
## (Layouts are code-built for now; move them to .tscn files once the look settles.)

const BG := Color(0.07, 0.09, 0.16)
const ACCENT := Color(1.0, 0.85, 0.3)


static func backdrop(parent: Control) -> void:
	var bg := ColorRect.new()
	bg.color = BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(bg)
	parent.move_child(bg, 0)


static func title(text: String, size: int = 96, color: Color = Color.WHITE) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0.02, 0.03, 0.08))
	l.add_theme_constant_override("outline_size", int(size / 8.0))
	return l


static func label(text: String, size: int = 26, color: Color = Color.WHITE) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


static func button(text: String, min_width: float = 420.0) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(min_width, 0)
	b.focus_entered.connect(func() -> void:
		Sfx.play("ui")
		b.pivot_offset = b.size / 2.0
		Juice.pop(b, 1.06, 0.12))
	return b


static func stat_row(name: String, rating: int, color: Color) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	var l := Label.new()
	l.text = name
	l.custom_minimum_size = Vector2(90, 0)
	l.add_theme_font_size_override("font_size", 20)
	row.add_child(l)
	for i in 5:
		var seg := ColorRect.new()
		seg.custom_minimum_size = Vector2(22, 12)
		seg.color = color if i < rating else Color(1, 1, 1, 0.12)
		row.add_child(seg)
	return row


## A live 3D dog inside the 2D UI (SubViewport turntable).
static func dog_portrait(data: DogData, color: Color, box: Vector2 = Vector2(320, 240), zoom: float = 1.0, spin: float = 0.5) -> DogPortrait:
	var p := DogPortrait.new()
	p.setup(data, color, box, zoom, spin)
	return p


static func panel_style(border: Color, bg: Color = Color(0.09, 0.11, 0.19, 0.95)) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(4)
	s.set_corner_radius_all(20)
	s.content_margin_left = 18
	s.content_margin_right = 18
	s.content_margin_top = 14
	s.content_margin_bottom = 14
	return s
