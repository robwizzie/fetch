extends Control
## MindGoblin studio bumper. Plays once at boot, then hands off to the loading screen.
## Any button skips straight to the fade-out. Built in code like the rest of the menus.
##
## The supplied mark has its background baked in, so the card uses that exact colour and every
## added light sits ON TOP of the art additively. Anything layered behind it would be occluded
## by the logo's own opaque square and read as a visible seam.

const LOGO: Texture2D = preload("res://images/mindgoblin.png")
const PAPER := Color("e5e3da")
const INK := Color("1b1d29")
## Where the glowing brain sits inside the square logo, in normalised art coordinates.
const BRAIN_AT := Vector2(0.493, 0.302)
const LOGO_SIZE := 660.0

var _canvas: Control
var _fade: ColorRect
var _logo: TextureRect
var _glow: TextureRect
var _presents: Label
var _skip_hint: Label
var _leaving := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_backdrop())

	# One 1920x1080 design canvas, scaled to fit whatever window we get.
	_canvas = Control.new()
	_canvas.size = Vector2(1920, 1080)
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_canvas)

	var centre := Vector2(960, 498)
	_logo = TextureRect.new()
	_logo.texture = LOGO
	_logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	# Without this the rect refuses to shrink below the 1024px source art.
	_logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_logo.size = Vector2(LOGO_SIZE, LOGO_SIZE)
	_logo.position = centre - _logo.size * 0.5
	_logo.pivot_offset = _logo.size * 0.5
	_logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_logo.modulate.a = 0.0
	_logo.scale = Vector2.ONE * 0.9
	_canvas.add_child(_logo)

	_glow = TextureRect.new()
	_glow.texture = _radial(Color(0.5, 0.72, 1.0, 1.0), Color(0.72, 0.42, 1.0, 0.0))
	_glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_glow.size = Vector2(300, 300)
	_glow.position = centre + (BRAIN_AT - Vector2(0.5, 0.5)) * LOGO_SIZE - _glow.size * 0.5
	_glow.pivot_offset = _glow.size * 0.5
	_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_glow.material = additive
	_glow.modulate.a = 0.0
	_canvas.add_child(_glow)

	_presents = UiKit.label("P R E S E N T S", 22, Color(INK, 0.5))
	_presents.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_presents.position = Vector2(560, 902)
	_presents.size = Vector2(800, 34)
	_presents.modulate.a = 0.0
	_canvas.add_child(_presents)

	_skip_hint = UiKit.label("PRESS ANY BUTTON TO SKIP", 17, Color(INK, 0.28))
	_skip_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_skip_hint.position = Vector2(1120, 1016)
	_skip_hint.size = Vector2(720, 28)
	_skip_hint.modulate.a = 0.0
	_canvas.add_child(_skip_hint)

	_fade = ColorRect.new()
	_fade.color = Color.BLACK
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fade)

	resized.connect(_fit)
	_fit()
	Sfx.play("sting", 1.0, -4.0)
	_play()


## Stretching a patch of the logo's own corner means the card and the mark travel the same
## texture path, so the logo's baked background cannot read as a lighter square. A flat
## ColorRect of the sampled colour does not match once the renderer is done with each.
func _backdrop() -> Control:
	var card := TextureRect.new()
	var art := LOGO.get_image()
	if art != null and not art.is_empty():
		card.texture = ImageTexture.create_from_image(art.get_region(Rect2i(0, 0, 8, 8)))
	else:
		var flat := Image.create(8, 8, false, Image.FORMAT_RGBA8)
		flat.fill(PAPER)
		card.texture = ImageTexture.create_from_image(flat)
	card.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	card.stretch_mode = TextureRect.STRETCH_SCALE
	card.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return card


func _radial(inner: Color, outer: Color) -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.set_color(0, inner)
	gradient.set_color(1, outer)
	gradient.add_point(0.32, Color(inner.r, inner.g, inner.b, inner.a * 0.42))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	texture.width = 512
	texture.height = 512
	return texture


func _fit() -> void:
	if _canvas == null:
		return
	var factor := minf(size.x / 1920.0, size.y / 1080.0)
	_canvas.scale = Vector2.ONE * factor
	_canvas.position = (size - Vector2(1920, 1080) * factor) * 0.5


func _play() -> void:
	var tween := create_tween()
	tween.set_parallel(true)
	# Open from black onto the card.
	tween.tween_property(_fade, "modulate:a", 0.0, 0.5).from(1.0).set_ease(Tween.EASE_OUT)
	# The logo settles forward rather than popping.
	tween.tween_property(_logo, "modulate:a", 1.0, 0.7).set_ease(Tween.EASE_OUT)
	tween.tween_property(_logo, "scale", Vector2.ONE, 1.4).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	# The brain lights up a beat after the head arrives.
	tween.chain().tween_property(_glow, "modulate:a", 0.4, 0.6).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(_glow, "scale", Vector2.ONE * 1.12, 0.6).from(Vector2.ONE * 0.75).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(_presents, "modulate:a", 1.0, 0.7).set_delay(0.15)
	tween.parallel().tween_property(_skip_hint, "modulate:a", 1.0, 0.6).set_delay(0.3)
	tween.parallel().tween_callback(_release_motes).set_delay(0.05)
	# Settle to a resting glow and hold the card.
	tween.chain().tween_property(_glow, "modulate:a", 0.26, 0.8).set_trans(Tween.TRANS_SINE)
	tween.parallel().tween_property(_glow, "scale", Vector2.ONE, 0.8).set_trans(Tween.TRANS_SINE)
	tween.chain().tween_interval(0.45)
	tween.chain().tween_callback(_leave)


## Thought motes drifting up out of the brain, echoing the dots in the mark.
func _release_motes() -> void:
	var origin := _glow.position + _glow.size * 0.5
	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	for i in 9:
		var mote := TextureRect.new()
		var width := randf_range(9.0, 19.0)
		mote.texture = _radial(Color(0.6, 0.72, 1.0, 1.0), Color(0.74, 0.45, 1.0, 0.0))
		mote.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		mote.size = Vector2(width, width)
		mote.position = origin + Vector2(randf_range(-110.0, 110.0), randf_range(-30.0, 30.0)) - mote.size * 0.5
		mote.material = additive
		mote.mouse_filter = Control.MOUSE_FILTER_IGNORE
		mote.modulate.a = 0.0
		_canvas.add_child(mote)
		var rise := create_tween()
		rise.set_parallel(true)
		rise.tween_property(mote, "position:y", mote.position.y - randf_range(170.0, 300.0), randf_range(1.8, 2.6)).set_ease(Tween.EASE_OUT)
		rise.tween_property(mote, "position:x", mote.position.x + randf_range(-70.0, 70.0), 2.2).set_ease(Tween.EASE_OUT)
		rise.tween_property(mote, "modulate:a", 0.5, 0.5).set_delay(randf_range(0.05, 0.45))
		rise.chain().tween_property(mote, "modulate:a", 0.0, randf_range(1.0, 1.6))


func _input(event: InputEvent) -> void:
	if _leaving:
		return
	var pressed: bool = (event is InputEventKey and event.pressed and not event.echo) \
		or (event is InputEventJoypadButton and event.pressed) \
		or (event is InputEventMouseButton and event.pressed)
	if pressed:
		get_viewport().set_input_as_handled()
		_leave()


func _leave() -> void:
	if _leaving:
		return
	_leaving = true
	var tween := create_tween()
	tween.tween_property(_fade, "modulate:a", 1.0, 0.45).from(0.0).set_ease(Tween.EASE_IN)
	tween.tween_callback(func() -> void: get_tree().change_scene_to_file(Game.SCENE_MAIN_MENU))
