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


## The cover art, softly blurred and dimmed, behind a page: the menus keep the home screen's
## sunny park instead of dropping to a flat colour the moment you leave it. [param dim] is how
## much of the art the forest-green wash hides (0 none, 1 all).
static func cover_backdrop(parent: Control, dim: float = 0.62) -> void:
	var art := TextureRect.new()
	art.texture = _blurred_cover()
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.set_anchors_preset(Control.PRESET_FULL_RECT)
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	# The shader samples its own linear-filtered copy: the project filters canvas textures
	# nearest, and a nearest blur of a small image is a mosaic.
	var blur := _blur_material()
	blur.set_shader_parameter("art", art.texture)
	art.material = blur
	parent.add_child(art)
	parent.move_child(art, 0)
	# A wash that is a touch lighter up top, like the sky, and deepest at the foot of the page
	# where the buttons sit.
	var wash := TextureRect.new()
	var gradient := Gradient.new()
	gradient.set_color(0, Color(0.06, 0.13, 0.08, dim * 0.85))
	gradient.set_color(1, Color(0.04, 0.09, 0.05, minf(dim * 1.25, 0.97)))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill_from = Vector2(0.5, 0)
	texture.fill_to = Vector2(0.5, 1)
	wash.texture = texture
	wash.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	wash.set_anchors_preset(Control.PRESET_FULL_RECT)
	wash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(wash)
	parent.move_child(wash, 1)


static var _blurred_cover_tex: ImageTexture


## The art at a fraction of its size: the blur shader below does the rest, and a small texture
## keeps its taps cheap.
static func _blurred_cover() -> ImageTexture:
	if _blurred_cover_tex != null:
		return _blurred_cover_tex
	var image := CoverStage.ART.get_image()
	if image.is_compressed():
		image.decompress()
	var aspect := float(image.get_height()) / float(image.get_width())
	# Down in halving steps, so it averages rather than skips pixels.
	var width := image.get_width()
	while width > 240:
		width = maxi(width / 2, 240)
		image.resize(width, maxi(int(width * aspect), 1), Image.INTERPOLATE_BILINEAR)
	_blurred_cover_tex = ImageTexture.create_from_image(image)
	return _blurred_cover_tex


static var _blur: ShaderMaterial


## A soft 7x7 Gaussian, in texels of whatever texture it is drawn with.
static func _blur_material() -> ShaderMaterial:
	if _blur != null:
		return _blur
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;
uniform sampler2D art : filter_linear, repeat_disable;
uniform float spread = 1.6;
void fragment() {
	vec2 step_size = spread / vec2(textureSize(art, 0));
	vec4 sum = vec4(0.0);
	float total = 0.0;
	for (int x = -3; x <= 3; x++) {
		for (int y = -3; y <= 3; y++) {
			float weight = exp(-float(x * x + y * y) / 7.0);
			sum += texture(art, clamp(UV + vec2(float(x), float(y)) * step_size, vec2(0.0), vec2(1.0))) * weight;
			total += weight;
		}
	}
	COLOR = sum / total;
}
"""
	_blur = ShaderMaterial.new()
	_blur.shader = shader
	return _blur


## A page heading painted on a wooden sign, like the logo's: a board with the title in cream.
static func sign(text: String, size: int = 60) -> CenterContainer:
	var holder := CenterContainer.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var board := PanelContainer.new()
	board.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := plank_style(WOOD, WOOD_DARK).duplicate() as StyleBoxTexture
	style.content_margin_left = 54
	style.content_margin_right = 54
	style.content_margin_top = PLANK_PAD + 12
	style.content_margin_bottom = PLANK_LIP + PLANK_PAD + 4
	board.add_theme_stylebox_override("panel", style)
	var words := title(text, size, CREAM)
	words.add_theme_color_override("font_outline_color", PLANK_INK)
	words.add_theme_constant_override("outline_size", int(size / 5.5))
	board.add_child(words)
	holder.add_child(board)
	return holder


## The showcase card: a deep forest panel rimmed in [param tint], lifted off the page by a soft
## shadow.
static func card_style(tint: Color, glow: bool = false) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.07, 0.13, 0.09, 0.94)
	s.border_color = tint.lightened(0.3) if glow else tint.darkened(0.08)
	s.set_border_width_all(5 if glow else 4)
	s.set_corner_radius_all(24)
	s.shadow_color = Color(0, 0, 0, 0.38)
	s.shadow_size = 16
	s.shadow_offset = Vector2(0, 8)
	s.anti_aliasing_size = 1.2
	return s


## A filled name banner across the top of a card, in the card's colour.
static func card_banner(text: String, tint: Color, size: int = 32) -> PanelContainer:
	var banner := PanelContainer.new()
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var s := StyleBoxFlat.new()
	s.bg_color = tint
	s.corner_radius_top_left = 20
	s.corner_radius_top_right = 20
	s.content_margin_top = 10
	s.content_margin_bottom = 6
	s.content_margin_left = 12
	s.content_margin_right = 12
	# A lighter top edge, so the band looks painted on rather than pasted.
	s.border_color = tint.lightened(0.25)
	s.border_width_top = 3
	banner.add_theme_stylebox_override("panel", s)
	# Cream lettering on a pale band (a bone, a ghost) vanishes; those get dark lettering.
	var pale := tint.get_luminance() > 0.72
	var words := title(text, size, PLANK_INK if pale else CREAM)
	words.add_theme_constant_override("outline_size", 0 if pale else int(size / 4.5))
	words.add_theme_color_override("font_outline_color", tint.darkened(0.62))
	words.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	banner.add_child(words)
	return banner


## A soft spotlight in [param tint] for a model to stand in: bright in the middle and fading to
## nothing at the edges, so it has no hard corners to clip.
static func spotlight(tint: Color) -> TextureRect:
	var light := TextureRect.new()
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	gradient.colors = PackedColorArray([Color(tint.lightened(0.15), 0.55), Color(tint, 0.18), Color(tint, 0.0)])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.58)
	texture.fill_to = Vector2(0.5, 0.02)
	texture.width = 256
	texture.height = 256
	light.texture = texture
	light.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	light.stretch_mode = TextureRect.STRETCH_SCALE
	light.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return light


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


## Wood-plank menu button with a paw icon, in the style of the logo's wooden sign: a chunky
## board with a dark cartoon outline, lit from above, standing on a thicker lower lip. Focus
## brightens the wood, rings it in gold and turns the paw the logo's orange; pressing pushes
## the board down onto its lip. [param small] is the lighter secondary version (Back, Quit).
static func wood_button(text: String, min_width: float = 420.0, small: bool = false) -> Button:
	var b := button(text, min_width)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT if not small else HORIZONTAL_ALIGNMENT_CENTER
	if not small:
		b.icon = paw_texture()
		b.expand_icon = false
		b.add_theme_constant_override("h_separation", 16)
		b.add_theme_constant_override("icon_max_width", 36)
		b.add_theme_color_override("icon_normal_color", CREAM)
		b.add_theme_color_override("icon_hover_color", PAW_ORANGE)
		b.add_theme_color_override("icon_focus_color", PAW_ORANGE)
		b.add_theme_color_override("icon_pressed_color", PAW_ORANGE)
		b.add_theme_color_override("icon_disabled_color", Color(1, 1, 1, 0.35))
	b.add_theme_font_override("font", FONT_DISPLAY)
	b.add_theme_font_size_override("font_size", 24 if small else 30)
	b.add_theme_constant_override("outline_size", 7 if small else 9)
	b.add_theme_color_override("font_outline_color", PLANK_INK)
	b.add_theme_color_override("font_color", CREAM)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_focus_color", Color.WHITE)
	b.add_theme_color_override("font_pressed_color", Color("fff0c2"))
	b.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.4))
	var wood := WOOD_LIGHT if small else WOOD
	b.add_theme_stylebox_override("normal", plank_style(wood, WOOD_DARK, false, false, small))
	b.add_theme_stylebox_override("hover", plank_style(wood.lightened(0.12), WOOD_DARK, true, false, small))
	b.add_theme_stylebox_override("focus", plank_style(wood.lightened(0.12), WOOD_DARK, true, false, small))
	b.add_theme_stylebox_override("pressed", plank_style(wood.darkened(0.05), WOOD_DARK, true, true, small))
	b.add_theme_stylebox_override("disabled", plank_style(Color(0.42, 0.33, 0.25), Color(0.26, 0.2, 0.15), false, false, small))
	b.custom_minimum_size.y = 56 if small else 66
	return b


const PLANK_INK := Color("3a1f10")
const PAW_ORANGE := Color("f79632")
## Pixels of the plank texture outside the board itself: room for the gold rim and the shadow.
const PLANK_PAD := 6
const PLANK_LIP := 9


## A sawn board, nine-sliced: the ends (outline, rounded corners, nails) stay crisp at any width
## and the middle tiles rather than stretches, so the grain never smears across a wide button.
static func plank_style(base: Color, edge: Color, glow: bool = false, pressed: bool = false, small: bool = false) -> StyleBoxTexture:
	var key := "%s|%s|%s|%s|%s" % [base.to_html(), edge.to_html(), glow, pressed, small]
	if _plank_cache.has(key):
		return _plank_cache[key]
	var style := StyleBoxTexture.new()
	style.texture = _plank_texture(base, edge, glow, pressed)
	style.texture_margin_left = 40
	style.texture_margin_right = 40
	style.texture_margin_top = 20
	style.texture_margin_bottom = 24
	style.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE_FIT
	style.content_margin_left = 28 if not small else 22
	style.content_margin_right = 26 if not small else 22
	# The board's face sits above its lip; pressing it down moves the label with it.
	# Luckiest Guy rides high in its line, so the face's middle is a few pixels lower than the
	# box's.
	style.content_margin_top = (PLANK_PAD + 7) if not pressed else (PLANK_PAD + PLANK_LIP + 5)
	style.content_margin_bottom = (PLANK_LIP + PLANK_PAD) if not pressed else (PLANK_PAD + 2)
	_plank_cache[key] = style
	return style


static func _plank_texture(base: Color, edge: Color, glow: bool, pressed: bool) -> ImageTexture:
	var w := 300
	var h := 72
	var pad := PLANK_PAD
	var radius := 15.0
	var outline := 3.0
	var lip := 2.0 if pressed else float(PLANK_LIP)
	var top := float(pad) + (lip - 2.0 if pressed else 0.0)
	var bottom := float(h - pad)
	var left := float(pad)
	var right := float(w - pad)
	var image := Image.create(w, h, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	# Grain: a few long wavy streaks and one knot, the same on every board so a menu reads as
	# one set of planks.
	var streaks: Array[Vector3] = []
	for i in 6:
		streaks.append(Vector3(rng.randf_range(0.18, 0.86), rng.randf_range(0.0, TAU), rng.randf_range(0.6, 1.3)))
	var knot := Vector2(w * 0.62, (top + bottom - lip) * 0.5 + 4.0)
	for y in h:
		for x in w:
			var p := Vector2(x + 0.5, y + 0.5)
			var inside := _round_rect_distance(p, left, top, right, bottom, radius)
			var colour := Color(0, 0, 0, 0)
			if inside <= 0.0:
				var face_bottom := bottom - lip
				var v := clampf((p.y - top) / maxf(face_bottom - top, 1.0), 0.0, 1.0)
				if p.y > face_bottom:
					# The lip: the board's thickness, darker and in shade.
					colour = edge.lerp(base, 0.25)
				else:
					colour = base.lightened(0.22 * pow(1.0 - v, 2.2)).darkened(0.12 * pow(v, 1.6))
					for streak in streaks:
						var line_y := top + 6.0 + streak.x * (face_bottom - top - 12.0) + sin(p.x * 0.045 * streak.z + streak.y) * 2.2
						var dy := absf(p.y - line_y)
						if dy < 1.1:
							colour = colour.lerp(edge, 0.22 * (1.0 - dy / 1.1))
					var k := ((p - knot) / Vector2(9.0, 4.5)).length()
					if k < 1.0:
						colour = colour.lerp(edge, 0.35 * (1.0 - k))
					# A bright bevel just inside the top edge.
					if p.y - top < outline + 3.0 and p.y - top > outline:
						colour = colour.lightened(0.25)
				# Nails near each end.
				for nail_x in [left + 20.0, right - 20.0]:
					var d := Vector2(p.x - nail_x, p.y - (top + face_bottom) * 0.5).length()
					if d < 3.2:
						colour = edge.darkened(0.35).lerp(base.lightened(0.5), clampf((3.2 - d) / 3.2 * 0.6 - 0.1, 0.0, 1.0) if d < 1.4 else 0.0)
				if inside > -outline:
					colour = PLANK_INK
				colour.a = clampf(-inside + 0.5, 0.0, 1.0)
				if inside > -outline:
					colour.a = 1.0 if inside < -0.5 else clampf(0.5 - inside, 0.0, 1.0)
			elif glow and inside < float(pad) - 0.5:
				# Gold rim around a focused board.
				colour = Color(YELLOW, clampf(1.0 - inside / float(pad - 1), 0.0, 1.0) * 0.95)
			elif not pressed and p.y > bottom - 4.0 and inside < 4.0:
				colour = Color(0, 0, 0, 0.18 * clampf(1.0 - inside / 4.0, 0.0, 1.0))
			image.set_pixel(x, y, colour)
	return ImageTexture.create_from_image(image)


## Signed distance from [param p] to a rounded rectangle (negative inside).
static func _round_rect_distance(p: Vector2, left: float, top: float, right: float, bottom: float, radius: float) -> float:
	var centre := Vector2((left + right) * 0.5, (top + bottom) * 0.5)
	var half := Vector2((right - left) * 0.5, (bottom - top) * 0.5) - Vector2(radius, radius)
	var q := (p - centre).abs() - half
	return Vector2(maxf(q.x, 0.0), maxf(q.y, 0.0)).length() + minf(maxf(q.x, q.y), 0.0) - radius


## White pads ringed in dark wood, so a button can tint it (cream at rest, orange on focus).
static func paw_texture() -> ImageTexture:
	if _paw_tex == null:
		_paw_tex = PawIcon.texture(80, Color.WHITE, PLANK_INK, 0.06)
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


## One key or button drawn as a key: a pale cap with a heavier bottom edge, so "Space" reads as
## something to press rather than a word in a sentence.
static func keycap(text: String, size: int = 18) -> PanelContainer:
	var cap := PanelContainer.new()
	cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var s := StyleBoxFlat.new()
	s.bg_color = CREAM
	s.border_color = Color(0.55, 0.5, 0.42)
	s.set_border_width_all(2)
	s.border_width_bottom = 5
	s.set_corner_radius_all(7)
	s.content_margin_left = 9
	s.content_margin_right = 9
	s.content_margin_top = 1
	s.content_margin_bottom = 0
	cap.add_theme_stylebox_override("panel", s)
	var l := label(text, size, INK)
	l.name = "Text"
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	l.add_theme_font_override("font", FONT_DISPLAY)
	cap.add_child(l)
	return cap


## The key(s) for one action on one player's device. A keyboard shows every key the game
## accepts as caps; a pad shows its main button only, since the alternatives
## ("X or Y/LT/RT") are a wall of letters to someone who has never held one, and draws a face
## button the way it looks on the pad (see PadButton). [param family] overrides the detected
## pad type, so tools can show every kind without one plugged in.
static func keycaps(action: StringName, device: int, size: int = 18, family: int = -1) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 4)
	# Beside a taller control the caps would otherwise stretch to its height and squash thin.
	row.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if device == DeviceInput.KEYBOARD_WASD or device == DeviceInput.KEYBOARD_ARROWS:
		for word in DeviceInput.glyph(action, device).split(" or "):
			if not word.is_empty():
				row.add_child(keycap(word.to_upper() if word.length() <= 6 else word, size))
		return row
	var pad: DeviceInput.PadFamily = DeviceInput.pad_family(device) if family < 0 else family as DeviceInput.PadFamily
	var word := DeviceInput.pad_glyph(action, pad).get_slice(" or ", 0)
	if word.is_empty():
		return row
	var badge := PadButton.for_label(word, pad, size * 1.75)
	row.add_child(badge if badge != null else keycap(word.to_upper() if word.length() <= 6 else word, size))
	return row


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
