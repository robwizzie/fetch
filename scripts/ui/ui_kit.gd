class_name UiKit
extends RefCounted
## Shared look for every screen: palette from the design boards, fonts, and small builders.
## (Layouts are code-built for now; move them to .tscn files once the look settles.)

const FONT_DISPLAY: Font = preload("res://assets/fonts/LuckiestGuy-Regular.ttf")
const FONT_UI: Font = preload("res://assets/ui/fredoka_semibold.tres")

const NAVY := Color(0.06, 0.09, 0.17)
const NAVY_DARK := Color(0.04, 0.06, 0.12)
const INK := Color(0.09, 0.08, 0.14)
const CREAM := Color(0.99, 0.97, 0.92)
const YELLOW := Color(1.0, 0.82, 0.25)
const ACCENT := YELLOW
const WOOD := Color(0.58, 0.38, 0.2)
const WOOD_DARK := Color(0.33, 0.2, 0.1)
const WOOD_LIGHT := Color(0.72, 0.5, 0.28)
const BG := NAVY

static var _paw_tex: ImageTexture


static func backdrop(parent: Control, color: Color = NAVY) -> void:
	var bg := ColorRect.new()
	bg.color = color
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(bg)
	parent.move_child(bg, 0)


## Big brush-font heading with a dark outline (the boards' section titles).
static func title(text: String, size: int = 96, color: Color = CREAM) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_override("font", FONT_DISPLAY)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", INK)
	l.add_theme_constant_override("outline_size", int(size / 7.0))
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
		Juice.pop(b, 1.05, 0.12))
	return b


## Wood-plank menu button with a paw icon, from the title-screen board.
static func wood_button(text: String, min_width: float = 420.0) -> Button:
	var b := button(text, min_width)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.icon = paw_texture()
	b.expand_icon = false
	b.add_theme_constant_override("h_separation", 18)
	b.add_theme_constant_override("icon_max_width", 34)
	b.add_theme_font_size_override("font_size", 32)
	b.add_theme_color_override("font_color", CREAM)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_focus_color", Color.WHITE)
	b.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.4))
	b.add_theme_color_override("icon_disabled_color", Color(1, 1, 1, 0.4))
	b.add_theme_stylebox_override("normal", _wood_style(WOOD, WOOD_DARK))
	b.add_theme_stylebox_override("hover", _wood_style(WOOD_LIGHT, YELLOW))
	b.add_theme_stylebox_override("focus", _wood_style(WOOD_LIGHT, YELLOW))
	b.add_theme_stylebox_override("pressed", _wood_style(WOOD_DARK, YELLOW))
	b.add_theme_stylebox_override("disabled", _wood_style(Color(0.4, 0.28, 0.16), Color(0.28, 0.18, 0.1)))
	return b


static func _wood_style(bg: Color, border: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(4)
	s.set_corner_radius_all(8)
	s.content_margin_left = 22
	s.content_margin_right = 30
	s.content_margin_top = 10
	s.content_margin_bottom = 10
	s.shadow_color = Color(0, 0, 0, 0.35)
	s.shadow_size = 6
	s.shadow_offset = Vector2(3, 5)
	return s


static func paw_texture() -> ImageTexture:
	if _paw_tex == null:
		_paw_tex = PawIcon.texture(40, CREAM)
	return _paw_tex


## Small rounded tag ("P1", "READY!").
static func chip(text: String, color: Color, size: int = 22, text_color: Color = INK) -> PanelContainer:
	var p := PanelContainer.new()
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.set_corner_radius_all(10)
	s.content_margin_left = 12
	s.content_margin_right = 12
	s.content_margin_top = 3
	s.content_margin_bottom = 3
	p.add_theme_stylebox_override("panel", s)
	var l := label(text, size, text_color)
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	l.add_theme_font_override("font", FONT_DISPLAY)
	p.add_child(l)
	return p


static func stat_row(name: String, rating: int, color: Color) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 5)
	var l := Label.new()
	l.text = name
	l.custom_minimum_size = Vector2(84, 0)
	l.add_theme_font_size_override("font_size", 20)
	l.add_theme_color_override("font_color", CREAM)
	row.add_child(l)
	for i in 5:
		var seg := PanelContainer.new()
		var s := StyleBoxFlat.new()
		s.bg_color = color if i < rating else Color(0, 0, 0, 0.35)
		s.set_corner_radius_all(4)
		seg.add_theme_stylebox_override("panel", s)
		seg.custom_minimum_size = Vector2(26, 14)
		row.add_child(seg)
	return row


## Vertical gradient rectangle (for the dog cards).
static func gradient_rect(top: Color, bottom: Color, radius: int = 22) -> Control:
	var r := PanelContainer.new()
	var s := StyleBoxFlat.new()
	s.set_corner_radius_all(radius)
	s.bg_color = Color.WHITE
	r.add_theme_stylebox_override("panel", s)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var t := TextureRect.new()
	var g := Gradient.new()
	g.set_color(0, top)
	g.set_color(1, bottom)
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(0, 1)
	t.texture = gt
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_SCALE
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.add_child(t)
	r.self_modulate = Color.WHITE
	return r


## A live 3D dog inside the 2D UI (SubViewport turntable).
static func dog_portrait(data: DogData, color: Color, box: Vector2 = Vector2(320, 240), zoom: float = 1.0, spin: float = 0.5, head_on: bool = false) -> DogPortrait:
	var p := DogPortrait.new()
	p.setup(data, color, box, zoom, spin, head_on)
	return p


static func panel_style(border: Color, bg: Color = Color(0.09, 0.11, 0.19, 0.95)) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(4)
	s.set_corner_radius_all(22)
	s.content_margin_left = 18
	s.content_margin_right = 18
	s.content_margin_top = 14
	s.content_margin_bottom = 14
	return s
