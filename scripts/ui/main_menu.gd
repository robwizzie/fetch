extends Control
## Title screen. Play -> dog select. The galleries show content so new dogs/toys/arenas
## are visible the moment their .tres file exists.



func _ready() -> void:
	Game.clear_players()
	UiKit.backdrop(self)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_CENTER)
	vbox.grow_horizontal = Control.GROW_DIRECTION_BOTH
	vbox.grow_vertical = Control.GROW_DIRECTION_BOTH
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 8)
	vbox.position.y -= 150.0
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


func _add_button(parent: Control, text: String, on_pressed: Callable) -> Button:
	var b := UiKit.button(text)
	b.pressed.connect(on_pressed)
	parent.add_child(b)
	return b


func _gallery(kind: String) -> void:
	Game.gallery_kind = kind
	Game.goto(Game.SCENE_GALLERY)


## The dogs lined up along the bottom of the screen, like the key art.
func _build_parade() -> void:
	var count := Game.dogs.size()
	if count == 0:
		return
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 30)
	row.anchor_left = 0.0
	row.anchor_right = 1.0
	row.anchor_top = 1.0
	row.anchor_bottom = 1.0
	row.offset_top = -290.0
	row.offset_bottom = -10.0
	add_child(row)
	for i in count:
		var box := VBoxContainer.new()
		box.alignment = BoxContainer.ALIGNMENT_END
		var color: Color = PlayerSlot.COLORS[i % PlayerSlot.COLORS.size()]
		box.add_child(UiKit.dog_portrait(Game.dogs[i], color, Vector2(280, 235), 1.15, 0.35 + i * 0.07))
		box.add_child(UiKit.label(Game.dogs[i].display_name, 24, Color(1, 1, 1, 0.85)))
		row.add_child(box)
