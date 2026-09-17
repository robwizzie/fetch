class_name ModelPreview
extends TextureRect
## A live 3D model on a menu, turning slowly on the spot.
##
## Dog select used a cropped bitmap of the reference sheet, which meant the thing you picked
## was never quite the thing you played. This renders the real model in its own little world,
## so the card shows the dog that walks out of the pen — and the same widget does duty for
## toys and power-ups in the galleries.
##
## The model lives in a SubViewport with own_world_3d, so menu lighting is ours alone and no
## arena can reach in and change it.

## Degrees per second. Slow enough to read, fast enough to show it is real.
const SPIN := 34.0
## Framing: the subject is scaled so its height fills this much of the viewport.
const FILL := 0.74

var _view: SubViewport
var _pivot: Node3D
var _camera: Camera3D
var _spin := true


func _init(size: Vector2i = Vector2i(420, 420)) -> void:
	_view = SubViewport.new()
	_view.size = size
	_view.own_world_3d = true
	_view.transparent_bg = true
	# Only while it is actually on screen: a gallery left open in the background should not be
	# paying for a 3D pass per card.
	_view.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	_view.msaa_3d = Viewport.MSAA_4X
	add_child(_view)

	_pivot = Node3D.new()
	_view.add_child(_pivot)

	# A warm key with a cool fill, matching the cover's light rather than the arena's.
	var key := DirectionalLight3D.new()
	key.light_energy = 1.25
	key.light_color = Palette.SUN_COLOR
	key.rotation_degrees = Vector3(-30, 38, 0)
	_view.add_child(key)
	var fill := DirectionalLight3D.new()
	fill.light_energy = 0.45
	fill.light_color = Palette.AMBIENT_COLOR
	fill.rotation_degrees = Vector3(-14, -128, 0)
	_view.add_child(fill)
	var world := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_CANVAS
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Palette.AMBIENT_COLOR
	env.ambient_light_energy = 0.95
	world.environment = env
	_view.add_child(world)

	_camera = Camera3D.new()
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_view.add_child(_camera)
	_camera.make_current()

	texture = _view.get_texture()
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Puts a dog's authored model on the turntable, falling back to the procedural one when a
## dog has no model yet, so a card is never empty.
func show_dog(data: DogData) -> void:
	_clear()
	var model := DogModel.new()
	model.setup(data, Color.WHITE)
	_pivot.add_child(model)
	# Face the camera rather than away from it: the models are authored facing +Z.
	model.rotation_degrees = Vector3(0, 180, 0)
	_frame(maxf(0.4, data.model_height * data.model_scale), 0.24)


## A toy, sized from its own radius so a tennis ball and a frisbee both fill the frame.
func show_toy(data: ToyData) -> void:
	_clear()
	var model := ToyModel.new()
	model.setup(data)
	_pivot.add_child(model)
	_frame(maxf(0.25, data.radius * 3.4), 0.0)


## A power-up, shown as its crate colour with the drawn icon standing on top of it.
func show_powerup(kind: StringName) -> void:
	_clear()
	var tint := PowerupKinds.color(kind)
	var crate := Mats.mesh(_pivot, Mats.box(Vector3(0.62, 0.62, 0.62)), tint.darkened(0.25))
	Mats.mesh(crate, Mats.box(Vector3(0.68, 0.1, 0.68)), tint.lightened(0.3), Vector3(0, 0.31, 0))
	var badge := Sprite3D.new()
	badge.texture = PowerupIcon.texture(kind, 192, Color(1, 1, 1, 0.98))
	badge.pixel_size = 0.0034
	badge.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	badge.no_depth_test = true
	badge.render_priority = 4
	badge.position = Vector3(0, 0.62, 0)
	_pivot.add_child(badge)
	_frame(1.15, 0.2)


## Stops the turntable, for a still where movement would be a distraction.
func set_spinning(on: bool) -> void:
	_spin = on
	if not on:
		_pivot.rotation_degrees.y = -22.0


func _clear() -> void:
	for child in _pivot.get_children():
		child.queue_free()
	_pivot.rotation_degrees = Vector3.ZERO


## Points the camera at a subject of the given height, keeping it centred in frame.
func _frame(height: float, lift: float) -> void:
	_camera.size = height / FILL
	_camera.position = Vector3(0, height * 0.5 + lift, height * 2.4 + 1.0)
	_camera.rotation_degrees = Vector3(-7, 0, 0)


func _process(delta: float) -> void:
	if _spin and is_instance_valid(_pivot):
		_pivot.rotation_degrees.y = fmod(_pivot.rotation_degrees.y + SPIN * delta, 360.0)
