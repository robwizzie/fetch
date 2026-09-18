class_name UiKit
extends RefCounted
## Shared look for every screen: palette from the design boards, fonts, and small builders.
## (Layouts are code-built for now; move them to .tscn files once the look settles.)

const FONT_DISPLAY: Font = preload("res://assets/fonts/LuckiestGuy-Regular.ttf")
const FONT_UI: Font = preload("res://assets/ui/fredoka_semibold.tres")

# Menu colours are the cover's colours. These are literals because a const cannot call a
# function, but each is derived from Palette - sampled from the art itself - so the menus and
# the maps stop having separate ideas about what brown and green are.
const NAVY := Color("223528")
const NAVY_DARK := Color("16241a")
const INK := Color(0.09, 0.08, 0.14)
const CREAM := Color(0.99, 0.97, 0.92)
const YELLOW := Color("e8c84f")  ## Palette.GOLD, opened up for type
const ACCENT := YELLOW
## Palette.WOOD stepped down so the plank grain still reads against it.
const WOOD := Color("b4682f")
const WOOD_DARK := Color("7d4620")
const WOOD_LIGHT := Color("ce793c")  ## the cover's wood exactly
## Highlighted menu row, from the title-screen board.
const SELECT_GREEN := Color("63ad2c")
const SELECT_GREEN_DARK := Color("447a1d")
const BG := NAVY

static var _plank_cache: Dictionary = {}

static var _paw_tex: ImageTexture


static func backdrop(parent: Control, color: Color = NAVY) -> void:
	var bg := TextureRect.new()
	var gradient := Gradient.new()
	gradient.set_color(0, color.lightened(0.13))
	gradient.set_color(1, color.darkened(0.24))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill_from = Vector2(0, 0)
	texture.fill_to = Vector2(0.8, 1)
	bg.texture = texture
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(bg)
	parent.move_child(bg, 0)
	var decoration := Control.new()
	decoration.mouse_filter = Control.MOUSE_FILTER_IGNORE
	decoration.set_anchors_preset(Control.PRESET_FULL_RECT)
	parent.add_child(decoration)
	parent.move_child(decoration, 1)
	decoration.draw.connect(func() -> void:
		var bounds := decoration.size
		for i in 7:
			var radius := 44.0 + (i % 3) * 18.0
			var position := Vector2(bounds.x - 60.0 - i * 39.0, 16.0 + i * 44.0)
			decoration.draw_circle(position, radius, Color(0.5, 0.68, 0.24, 0.09))
			decoration.draw_circle(bounds - position, radius * 1.4, Color(0.5, 0.68, 0.24, 0.08)))
	decoration.resized.connect(decoration.queue_redraw)


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
		Sfx.play("ui_move", 1.0, -4.0)
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
	b.add_theme_stylebox_override("normal", plank_style(WOOD, WOOD_DARK))
	b.add_theme_stylebox_override("hover", plank_style(SELECT_GREEN, SELECT_GREEN_DARK, YELLOW))
	b.add_theme_stylebox_override("focus", plank_style(SELECT_GREEN, SELECT_GREEN_DARK, YELLOW))
	b.add_theme_stylebox_override("pressed", plank_style(SELECT_GREEN_DARK, SELECT_GREEN_DARK, YELLOW))
	b.add_theme_stylebox_override("disabled", plank_style(Color(0.4, 0.28, 0.16), Color(0.26, 0.17, 0.09)))
	return b


## A sawn board: lit from above, horizontal grain, darkened cut edges and a screw at each end.
## Nine-sliced so the screws and rounded ends stay crisp at any button width.
static func plank_style(base: Color, edge: Color, rim: Color = Color(0, 0, 0, 0)) -> StyleBoxTexture:
	var key := "%s|%s|%s" % [base.to_html(), edge.to_html(), rim.to_html()]
	if _plank_cache.has(key):
		return _plank_cache[key]
	var style := StyleBoxTexture.new()
	style.texture = _plank_texture(base, edge, rim)
	style.set_texture_margin_all(0)
	style.texture_margin_left = 46
	style.texture_margin_right = 46
	style.texture_margin_top = 26
	style.texture_margin_bottom = 26
	style.content_margin_left = 30
	style.content_margin_right = 26
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	_plank_cache[key] = style
	return style


static func _plank_texture(base: Color, edge: Color, rim: Color) -> ImageTexture:
	var w := 320
	var h := 88
	var radius := 13.0
	var image := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		var v := float(y) / float(h - 1)
		# Boards are lit from above: highlight along the top, shade toward the bottom.
		var row := base.lerp(base.lightened(0.30), pow(1.0 - v, 2.6))
		row = row.lerp(edge, pow(v, 1.8) * 0.68)
		for x in w:
			var u := float(x) / float(w - 1)
			var grain := sin(u * 31.0 + sin(v * 6.5) * 1.2) * 0.5 + 0.5
			var colour := row.lerp(edge, grain * 0.13)
			var inset_x := float(mini(x, w - 1 - x))
			var inset_y := float(mini(y, h - 1 - y))
			# Sawn edge all the way round, then the optional bright rim inside it.
			var inset := minf(inset_x, inset_y)
			if inset < 5.0:
				colour = colour.lerp(edge.darkened(0.3), (1.0 - inset / 5.0) * 0.85)
			if rim.a > 0.0 and inset >= 1.0 and inset <= 4.0:
				colour = rim
			# A screw in each corner, clear of the paw icon that sits over the left end.
			for screw_x in [15.0, float(w) - 15.0]:
				for screw_y in [16.0, float(h) - 16.0]:
					var d := Vector2(float(x) - screw_x, float(y) - screw_y).length()
					if d < 3.4:
						colour = colour.lerp(edge.darkened(0.5), 0.92)
					elif d < 4.8:
						colour = colour.lerp(base.lightened(0.4), 0.6)
			var alpha := 1.0
			if inset_x < radius and inset_y < radius:
				var corner := Vector2(radius - inset_x, radius - inset_y).length()
				alpha = clampf(radius + 0.5 - corner, 0.0, 1.0)
			colour.a = alpha
			image.set_pixel(x, y, colour)
	return ImageTexture.create_from_image(image)


static func paw_texture() -> ImageTexture:
	if _paw_tex == null:
		_paw_tex = PawIcon.texture(72, CREAM)
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
	var r := ColorRect.new()
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;
uniform vec4 top_color : source_color;
uniform vec4 bottom_color : source_color;
uniform vec2 extent = vec2(380.0, 660.0);
uniform float radius = 22.0;
void fragment() {
	vec2 q = abs(UV * extent - extent * 0.5) - (extent * 0.5 - vec2(radius));
	float distance = length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0) - radius;
	COLOR = mix(top_color, bottom_color, UV.y);
	COLOR.a *= 1.0 - smoothstep(-1.0, 1.0, distance);
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("top_color", top)
	material.set_shader_parameter("bottom_color", bottom)
	material.set_shader_parameter("radius", float(radius))
	r.material = material
	r.resized.connect(func() -> void: material.set_shader_parameter("extent", r.size))
	return r


## Reference artwork for selection, or a live 3D turntable for celebrations.
static func dog_portrait(data: DogData, color: Color, box: Vector2 = Vector2(320, 240), zoom: float = 1.0, spin: float = 0.5, head_on: bool = false) -> DogPortrait:
	var p := DogPortrait.new()
	p.setup(data, color, box, zoom, spin, head_on)
	return p


static func panel_style(border: Color, bg: Color = Color(0.09, 0.17, 0.12, 0.95)) -> StyleBoxFlat:
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
