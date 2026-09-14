class_name DogPortrait
extends SubViewportContainer
## A little 3D stage showing one dog (turntable + idle walk), usable anywhere in the 2D UI.

var model: DogModel
var _angle := 0.0
var _spin_speed := 0.5
var _viewport: SubViewport


func setup(data: DogData, color: Color, box: Vector2 = Vector2(320, 240), zoom: float = 1.0, spin: float = 0.5) -> void:
	custom_minimum_size = box
	stretch = true
	_spin_speed = spin
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
	e.ambient_light_color = Color(0.8, 0.85, 1.0)
	e.ambient_light_energy = 0.8
	env.environment = e
	_viewport.add_child(env)

	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-45, -35, 0)
	light.light_energy = 1.3
	light.shadow_enabled = true
	_viewport.add_child(light)

	var cam := Camera3D.new()
	cam.fov = 40.0
	cam.look_at_from_position(Vector3(0, 1.6, 3.0) / zoom, Vector3(0, 0.55, 0), Vector3.UP)
	_viewport.add_child(cam)

	model = DogModel.new()
	model.setup(data, color)
	model.scale = Vector3.ONE * (data.body_radius / 0.55)
	_viewport.add_child(model)
	_angle = -0.6


func _process(delta: float) -> void:
	if model == null:
		return
	_angle += _spin_speed * delta
	model.update_motion(Vector3(sin(_angle), 0.0, cos(_angle)), 0.35, delta)
