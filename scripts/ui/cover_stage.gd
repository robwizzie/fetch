class_name CoverStage
extends Control
## The shared front-end stage. The supplied cover art fills the screen and everything else is
## laid out over it on one 1920x1080 design canvas, scaled to whatever window we get.
## Loading and the main menu both use this, so the boot sequence never changes its look.

## The supplied home screen is already 16:9 and already carries the FETCH logo, so it fills
## the screen untouched and nothing is drawn on top of the wordmark.
const ART: Texture2D = preload("res://images/fetch-home-screen.png")
const ART_ASPECT := 941.0 / 1672.0
## Left-hand column, aligned under the logo painted into the art.
const COLUMN_X := 118.0
const COLUMN_WIDTH := 560.0
## First row sits clear of the painted logo.
const COLUMN_TOP := 398.0

const SKY := Color("a9def0")
const FOREST := Color("314a2c")
const ORANGE := Color("f79632")
const PAPER := Color("fff4de")
const BROWN := Color("63361e")

var canvas: Control


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas = Control.new()
	canvas.size = Vector2(1920, 1080)
	canvas.clip_contents = true
	canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(canvas)
	_build_backdrop()
	resized.connect(_fit)
	_fit()


func _fit() -> void:
	if canvas == null:
		return
	var factor := minf(size.x / 1920.0, size.y / 1080.0)
	canvas.scale = Vector2.ONE * factor
	canvas.position = (size - Vector2(1920, 1080) * factor) * 0.5


## The home screen art, scaled to the full width and never stretched.
func _build_backdrop() -> void:
	var art := TextureRect.new()
	art.name = "FetchHomeArt"
	art.texture = ART
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_SCALE
	art.size = Vector2(1920, 1920 * ART_ASPECT)
	art.position = Vector2(0, (1080.0 - art.size.y) * 0.5)
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(art)
	# A scrim on the left so wood and cream read against the art. It fades in BELOW the logo
	# painted into the artwork: darkening the wordmark would flatten the thing it sits on.
	var scrim := TextureRect.new()
	var mask := Image.create(128, 128, false, Image.FORMAT_RGBA8)
	for y in 128:
		var v := float(y) / 127.0
		# Nothing over the logo, easing in across the button column.
		var down := clampf((v - 0.30) / 0.16, 0.0, 1.0)
		for x in 128:
			var u := float(x) / 127.0
			var across := clampf(1.0 - u / 0.62, 0.0, 1.0)
			mask.set_pixel(x, y, Color(0.05, 0.11, 0.06, pow(across, 1.5) * 0.72 * down))
	scrim.texture = ImageTexture.create_from_image(mask)
	scrim.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	scrim.stretch_mode = TextureRect.STRETCH_SCALE
	scrim.size = Vector2(1920, 1080)
	scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(scrim)


static func paper_style(background: Color, border: Color, radius: int = 24) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(3)
	style.set_corner_radius_all(radius)
	style.shadow_color = Color(0.2, 0.26, 0.12, 0.22)
	style.shadow_size = 18
	style.shadow_offset = Vector2(3, 10)
	return style


static func heading(text: String, size_: int = 66) -> Label:
	var label := UiKit.title(text, size_, UiKit.CREAM)
	label.add_theme_color_override("font_outline_color", Color(0.05, 0.11, 0.06))
	label.add_theme_constant_override("outline_size", 8)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	return label


static func copy(text: String, size_: int = 26, color: Color = UiKit.CREAM) -> Label:
	var label := UiKit.label(text, size_, color)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	return label
