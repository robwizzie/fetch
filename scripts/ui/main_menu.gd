extends Control
## Title screen. Play -> dog select. The galleries show content so new dogs/toys/arenas
## are visible the moment their .tres file exists.

var _parade: Array[DogVisual] = []


func _ready() -> void:
	Game.clear_players()
	UiKit.backdrop(self)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_CENTER)
	vbox.grow_horizontal = Control.GROW_DIRECTION_BOTH
	vbox.grow_vertical = Control.GROW_DIRECTION_BOTH
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 8)
	vbox.position.y -= 90.0
	add_child(vbox)

	vbox.add_child(UiKit.title("FETCH", 170, UiKit.ACCENT))
	vbox.add_child(UiKit.label("THROW. DODGE. FETCH. REPEAT.", 30, Color(1, 1, 1, 0.8)))
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 30)
	vbox.add_child(spacer)

	var play := _add_button(vbox, "Play", func() -> void: Game.goto(Game.SCENE_DOG_SELECT))
	_add_button(vbox, "Dogs", func() -> void: _gallery("dogs"))
	_add_button(vbox, "Toys", func() -> void: _gallery("toys"))
	_add_button(vbox, "Arenas", func() -> void: _gallery("arenas"))
	_add_button(vbox, "Game Modes", func() -> void: _gallery("modes"))
	var settings := _add_button(vbox, "Settings (soon)", func() -> void: pass)
	settings.disabled = true
	_add_button(vbox, "Quit", func() -> void: get_tree().quit())
	play.grab_focus()

	_build_parade()

	var version := UiKit.label("v%s  ·  prototype" % ProjectSettings.get_setting("application/config/version"), 18, Color(1, 1, 1, 0.4))
	version.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	version.position = Vector2(1920 - 340, 1080 - 44)
	version.size = Vector2(320, 30)
	add_child(version)


func _process(_delta: float) -> void:
	var i := 0
	for v in _parade:
		v.update_motion(Vector2(1.0, sin(Time.get_ticks_msec() * 0.003 + i) * 0.25).normalized(), 0.6)
		i += 1


func _add_button(parent: Control, text: String, on_pressed: Callable) -> Button:
	var b := UiKit.button(text)
	b.pressed.connect(on_pressed)
	parent.add_child(b)
	return b


func _gallery(kind: String) -> void:
	Game.gallery_kind = kind
	Game.goto(Game.SCENE_GALLERY)


## The five dogs running along the bottom of the screen, like the key art.
func _build_parade() -> void:
	var count := Game.dogs.size()
	if count == 0:
		return
	var y := 985.0
	var spacing := 1920.0 / (count + 1)
	for i in count:
		var v := DogVisual.new()
		v.position = Vector2(spacing * (i + 1), y)
		v.scale = Vector2.ONE * 2.3
		v.setup(Game.dogs[i], PlayerSlot.COLORS[i % PlayerSlot.COLORS.size()])
		add_child(v)
		_parade.append(v)
		var tag := UiKit.label(Game.dogs[i].display_name, 24, Color(1, 1, 1, 0.85))
		tag.position = v.position + Vector2(-100, 52)
		tag.size = Vector2(200, 30)
		add_child(tag)
