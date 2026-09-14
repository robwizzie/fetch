extends Node
## Title screen, laid out like the board: logo top-left, wood-plank menu below it, the dogs
## ambling around a live 3D backyard behind everything, and the tagline on the right.

const BACKYARD := preload("res://scenes/arenas/backyard.tscn")
const DOG_SCENE := preload("res://scenes/actors/dog.tscn")

var _cam: Camera3D
var _cam_base := Vector3.ZERO


func _ready() -> void:
	Game.clear_players()
	_build_world()
	_build_ui()


func _process(_delta: float) -> void:
	if _cam:
		var t := Time.get_ticks_msec() * 0.001
		_cam.position = _cam_base + Vector3(sin(t * 0.15) * 0.8, sin(t * 0.21) * 0.15, cos(t * 0.11) * 0.4)


func _build_world() -> void:
	var world := Node3D.new()
	add_child(world)
	var arena: Arena = BACKYARD.instantiate()
	world.add_child(arena)
	_cam = Camera3D.new()
	_cam.fov = 44.0
	_cam_base = Vector3(-2.0, 5.0, 16.0)
	_cam.position = _cam_base
	world.add_child(_cam)
	_cam.look_at(Vector3(2.0, 0.4, -3.0), Vector3.UP)
	_cam.make_current()
	# The pack, ambling about
	var spots := [Vector3(-4, 0, 3), Vector3(3, 0, 4), Vector3(7, 0, 1), Vector3(-8, 0, -1), Vector3(1, 0, -4)]
	for i in Game.dogs.size():
		var slot := PlayerSlot.new()
		slot.index = i
		slot.device = DeviceInput.VIRTUAL
		slot.dog = Game.dogs[i]
		var dog: Dog = DOG_SCENE.instantiate()
		dog.setup(slot)
		dog.position = spots[i % spots.size()]
		world.add_child(dog)
		dog.name_tag.visible = false
		dog.ring.visible = false
		var brain := WanderBrain.new()
		brain.area = Vector2(arena.size.x - 4.0, arena.size.y - 4.0)
		dog.add_child(brain)


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)

	# Left-side shade so the menu reads over the scene
	var shade := TextureRect.new()
	var g := Gradient.new()
	g.set_color(0, Color(UiKit.NAVY_DARK, 0.9))
	g.set_color(1, Color(UiKit.NAVY_DARK, 0.0))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill_from = Vector2(0.15, 0)
	gt.fill_to = Vector2(0.62, 0)
	shade.texture = gt
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(shade)

	var logo := FetchLogo.new()
	logo.build(150)
	logo.position = Vector2(110, 70)
	root.add_child(logo)

	var tagline := UiKit.label("THROW. JUMP. OUTPLAY.", 30, UiKit.CREAM)
	tagline.add_theme_font_override("font", UiKit.FONT_DISPLAY)
	tagline.add_theme_color_override("font_outline_color", UiKit.INK)
	tagline.add_theme_constant_override("outline_size", 8)
	tagline.position = Vector2(130, 262)
	tagline.size = Vector2(560, 40)
	root.add_child(tagline)

	var menu := VBoxContainer.new()
	menu.position = Vector2(130, 340)
	menu.add_theme_constant_override("separation", 10)
	root.add_child(menu)
	var play := _add(menu, "Play", func() -> void: Game.goto(Game.SCENE_DOG_SELECT))
	_add(menu, "Party Play", func() -> void: pass).disabled = true
	_add(menu, "Campaign", func() -> void: pass).disabled = true
	_add(menu, "Dogs", func() -> void: _gallery("dogs"))
	_add(menu, "Toys", func() -> void: _gallery("toys"))
	_add(menu, "Arenas", func() -> void: _gallery("arenas"))
	_add(menu, "Settings", func() -> void: pass).disabled = true
	_add(menu, "Quit", func() -> void: get_tree().quit())
	play.grab_focus()

	var slogan := UiKit.title("SAME FRIENDS.\nNEW TRICKS.", 66, UiKit.CREAM)
	slogan.position = Vector2(1330, 120)
	slogan.size = Vector2(520, 180)
	slogan.pivot_offset = slogan.size / 2.0
	slogan.rotation_degrees = -6.0
	root.add_child(slogan)

	var hint := UiKit.label("2–4 players  ·  gamepads + keyboard  ·  A / Enter to select", 20, Color(1, 1, 1, 0.75))
	hint.add_theme_color_override("font_outline_color", UiKit.INK)
	hint.add_theme_constant_override("outline_size", 6)
	hint.position = Vector2(130, 1080 - 60)
	hint.size = Vector2(700, 30)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	root.add_child(hint)

	var version := UiKit.label("v%s  ·  prototype" % ProjectSettings.get_setting("application/config/version"), 18, Color(1, 1, 1, 0.55))
	version.add_theme_color_override("font_outline_color", UiKit.INK)
	version.add_theme_constant_override("outline_size", 5)
	version.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	version.position = Vector2(1920 - 340, 1080 - 50)
	version.size = Vector2(320, 30)
	root.add_child(version)


func _add(parent: Control, text: String, on_pressed: Callable) -> Button:
	var b := UiKit.wood_button(text, 380)
	b.pressed.connect(on_pressed)
	parent.add_child(b)
	return b


func _gallery(kind: String) -> void:
	Game.gallery_kind = kind
	Game.goto(Game.SCENE_GALLERY)
