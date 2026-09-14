class_name DogPortrait
extends SubViewportContainer
## A little 3D stage showing one dog (turntable or head-on portrait with idle motion),
## usable anywhere in the 2D UI.

var model: DogModel
var _angle := 0.0
var _spin_speed := 0.5
var _head_on := false
var _viewport: SubViewport


func setup(data: DogData, color: Color, box: Vector2 = Vector2(320, 240), zoom: float = 1.0, spin: float = 0.5, head_on: bool = false) -> void:
	custom_minimum_size = box
	stretch = true
	_spin_speed = spin
	_head_on = head_on
	_viewport = SubViewport.new()
	_viewport.size = box
	_viewport.transparent_bg = true
	_viewport.own_world_3d = true
	_viewport.msaa_3d = Viewport.MSAA_2X
	add_child(_viewport)

	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0, 0, 0, 0)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.85, 0.9, 1.0)
	e.ambient_light_energy = 0.7
	env.environment = e
	_viewport.add_child(env)

	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-40, -30, 0)
	light.light_energy = 1.15
	light.shadow_enabled = true
	_viewport.add_child(light)

	model = DogModel.new()
	model.setup(data, color)
	_viewport.add_child(model)

	var h := model.height()
	var cam := Camera3D.new()
	cam.fov = 36.0
	if head_on:
		cam.look_at_from_position(Vector3(0, h * 1.25, h * 2.9) / zoom, Vector3(0, h * 0.55, -0.1), Vector3.UP)
	else:
		cam.look_at_from_position(Vector3(0, h * 1.3, h * 3.0) / zoom, Vector3(0, h * 0.45, 0), Vector3.UP)
	_viewport.add_child(cam)
	_angle = 0.35 if head_on else -0.6


func _process(delta: float) -> void:
	if model == null:
		return
	if _head_on:
		var sway := sin(Time.get_ticks_msec() * 0.0012) * 0.18
		model.update_motion(Vector3(sway, 0.0, 1.0), 0.12, delta)
	else:
		_angle += _spin_speed * delta
		model.update_motion(Vector3(sin(_angle), 0.0, cos(_angle)), 0.35, delta)
