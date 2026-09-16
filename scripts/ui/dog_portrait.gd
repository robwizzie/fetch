class_name DogPortrait
extends Control
## Character selection uses the supplied character art, cropped without resampling.
## Celebrations retain a lit, animated 3D turntable of the actual in-game model.

var model: DogModel
var _angle := 0.0
var _spin_speed := 0.5
var _head_on := false
var _viewport: SubViewport


func setup(data: DogData, color: Color, box: Vector2 = Vector2(320, 240), zoom: float = 1.0, spin: float = 0.5, head_on: bool = false) -> void:
	custom_minimum_size = box
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_spin_speed = spin
	_head_on = head_on
	for child in get_children():
		child.queue_free()
	model = null
	if head_on and not data.reference_sheet.is_empty() and ResourceLoader.exists(data.reference_sheet):
		_show_reference(data)
		return

	var container := SubViewportContainer.new()
	container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	container.stretch = true
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(container)
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(box)
	_viewport.transparent_bg = true
	_viewport.own_world_3d = true
	_viewport.msaa_3d = Viewport.MSAA_4X
	container.add_child(_viewport)

	var env := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0, 0, 0, 0)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.91, 0.93, 1.0)
	environment.ambient_light_energy = 0.50
	env.environment = environment
	_viewport.add_child(env)

	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-35, -35, 0)
	light.light_color = Color(1.0, 0.91, 0.79)
	light.light_energy = 0.75
	light.shadow_enabled = true
	_viewport.add_child(light)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-25, 145, 0)
	fill.light_color = Color(0.77, 0.84, 1.0)
	fill.light_energy = 0.25
	_viewport.add_child(fill)

	model = DogModel.new()
	model.setup(data, color)
	_viewport.add_child(model)
	var h := model.height()
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = h * 1.28 / zoom
	_viewport.add_child(cam)
	cam.look_at_from_position(Vector3(0, h * 1.0, h * 3.0), Vector3(0, h * 0.48, 0), Vector3.UP)
	_angle = 0.35 if head_on else -0.6


## The crops are all different shapes, so rather than resize the art the frame takes the
## sheet's own background colour. The letterbox then disappears instead of showing as a
## whiter rectangle inside the cream card. The crop itself is never widened: these are
## turnaround sheets, and widening pulls the neighbouring pose into frame.
func _show_reference(data: DogData) -> void:
	var sheet := load(data.reference_sheet) as Texture2D
	var region := data.portrait_region
	var background := Panel.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = _sheet_background(sheet, region)
	style.set_corner_radius_all(18)
	background.add_theme_stylebox_override("panel", style)
	add_child(background)
	var art := TextureRect.new()
	var atlas := AtlasTexture.new()
	atlas.atlas = sheet
	atlas.region = region
	atlas.filter_clip = true
	art.texture = atlas
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	art.offset_top = 6
	art.offset_bottom = -6
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(art)


## The flat colour the sheet was drawn on. Sampled from the sheet's own corner, not the crop's:
## a crop corner can land on artwork (Goose's sits on red) and would tint the whole frame.
func _sheet_background(sheet: Texture2D, _region: Rect2) -> Color:
	var fallback := Color(0.975, 0.960, 0.929)
	if sheet == null:
		return fallback
	var image := sheet.get_image()
	if image == null or image.is_empty():
		return fallback
	var corners: Array[Vector2i] = [
		Vector2i(3, 3),
		Vector2i(image.get_width() - 4, 3),
		Vector2i(3, image.get_height() - 4),
	]
	for corner in corners:
		var sample := image.get_pixel(corner.x, corner.y)
		# A cut-out sheet leaves a transparent corner; keep looking, then fall back.
		if sample.a >= 0.5:
			sample.a = 1.0
			return sample
	return fallback


func _process(delta: float) -> void:
	if model == null:
		return
	if _head_on:
		var sway := sin(Time.get_ticks_msec() * 0.0012) * 0.18
		model.update_motion(Vector3(sway, 0.0, 1.0), 0.05, delta)
	else:
		_angle += _spin_speed * delta
		model.update_motion(Vector3(sin(_angle), 0.0, cos(_angle)), 0.22, delta)
