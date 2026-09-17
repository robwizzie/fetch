extends Node
## Cover-led, controller-friendly front door. Every displayed option is playable.
## The supplied cover fills the screen; the wooden column sits over it like the design board.

var _stage: CoverStage
var _canvas: Control
var _menu_buttons: Array[Button] = []
var _modal: Control
var _return_focus: Control
var _activation_device := DeviceInput.KEYBOARD_WASD


func _ready() -> void:
	Music.play("menu")
	Game.clear_players()
	var layer := CanvasLayer.new()
	add_child(layer)
	_stage = CoverStage.new()
	layer.add_child(_stage)
	_canvas = _stage.canvas
	_build_menu()


func _input(event: InputEvent) -> void:
	if event is InputEventJoypadButton and event.pressed:
		_activation_device = event.device
	elif event is InputEventKey and event.pressed:
		_activation_device = DeviceInput.KEYBOARD_WASD
	if event.is_action_pressed("ui_cancel") and is_instance_valid(_modal):
		_close_modal()
		get_viewport().set_input_as_handled()



func _build_menu() -> void:
	var menu := VBoxContainer.new()
	menu.position = Vector2(CoverStage.COLUMN_X, CoverStage.COLUMN_TOP)
	menu.size = Vector2(560, 480)
	menu.add_theme_constant_override("separation", 10)
	_canvas.add_child(menu)
	var play := _add(menu, "PARTY PLAY", func() -> void: Game.goto(Game.SCENE_DOG_SELECT))
	play.tooltip_text = "2–4 friends. Join with gamepads or share a keyboard."
	var solo := _add(menu, "SOLO PRACTICE", func() -> void: Game.start_practice(_activation_device))
	solo.tooltip_text = "Jump in with three computer-controlled dogs."
	_add(menu, "MEET THE PACK", func() -> void: _gallery("dogs"))
	_add(menu, "TOYS", func() -> void: _gallery("toys"))
	_add(menu, "ARENAS", func() -> void: _gallery("arenas"))
	_add(menu, "POWER-UPS", func() -> void: _gallery("powerups"))
	_add(menu, "SETTINGS", _show_settings)

	var footer := HBoxContainer.new()
	footer.position = Vector2(CoverStage.COLUMN_X, 866)
	footer.size = Vector2(560, 60)
	footer.add_theme_constant_override("separation", 12)
	_canvas.add_child(footer)
	_small_button(footer, "HOW TO PLAY", _show_controls, 336)
	_small_button(footer, "QUIT", func() -> void: get_tree().quit(), 208)

	var blurb := CoverStage.copy("1–4 players   •   local multiplayer   •   gamepads + keyboard", 21, Color(0.92, 0.95, 0.86))
	blurb.position = Vector2(CoverStage.COLUMN_X + 2, 946)
	blurb.size = Vector2(700, 32)
	_canvas.add_child(blurb)

	_build_session_chip()
	_build_button_hints()
	_wire_focus(_menu_buttons)
	play.grab_focus()


## Top-right status, in the place the design board puts the profile chip.
func _build_session_chip() -> void:
	var chip := Panel.new()
	chip.size = Vector2(394, 92)
	chip.position = Vector2(1450, 44)
	var style := CoverStage.paper_style(Color(0.08, 0.15, 0.09, 0.82), Color(0.82, 0.88, 0.62, 0.7), 22)
	style.shadow_size = 0
	chip.add_theme_stylebox_override("panel", style)
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.add_child(chip)
	var paw := TextureRect.new()
	paw.texture = UiKit.paw_texture()
	paw.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	paw.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	paw.position = Vector2(20, 22)
	paw.size = Vector2(48, 48)
	paw.modulate = UiKit.YELLOW
	chip.add_child(paw)
	var name_label := UiKit.label("LOCAL PARTY", 24, UiKit.CREAM)
	name_label.position = Vector2(84, 16)
	name_label.size = Vector2(290, 30)
	chip.add_child(name_label)
	var sub := UiKit.label("FETCH  /  %s" % ProjectSettings.get_setting("application/config/version"), 19, Color(0.82, 0.88, 0.62))
	sub.position = Vector2(84, 50)
	sub.size = Vector2(290, 28)
	chip.add_child(sub)


## Bottom-right controller legend, matching the board's A / B prompts.
func _build_button_hints() -> void:
	var row := HBoxContainer.new()
	row.position = Vector2(1180, 962)
	row.size = Vector2(664, 62)
	row.alignment = BoxContainer.ALIGNMENT_END
	row.add_theme_constant_override("separation", 18)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.add_child(row)
	row.add_child(_hint("A", Color(0.38, 0.75, 0.33), "Select", 104))
	row.add_child(_hint("B", Color(0.86, 0.32, 0.29), "Back", 82))


func _hint(glyph: String, tint: Color, action: String, caption_width: float) -> Control:
	var pill := PanelContainer.new()
	var style := CoverStage.paper_style(Color(0.07, 0.12, 0.07, 0.78), Color(0, 0, 0, 0), 26)
	style.set_border_width_all(0)
	style.shadow_size = 0
	style.content_margin_left = 10
	style.content_margin_right = 20
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	pill.add_theme_stylebox_override("panel", style)
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	pill.add_child(box)
	var badge := Panel.new()
	badge.custom_minimum_size = Vector2(38, 38)
	var badge_style := CoverStage.paper_style(tint, tint.lightened(0.35), 19)
	badge_style.shadow_size = 0
	badge.add_theme_stylebox_override("panel", badge_style)
	box.add_child(badge)
	var letter := UiKit.label(glyph, 22, UiKit.CREAM)
	letter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	letter.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	letter.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	badge.add_child(letter)
	var caption := UiKit.label(action, 22, UiKit.CREAM)
	caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	caption.autowrap_mode = TextServer.AUTOWRAP_OFF
	caption.custom_minimum_size = Vector2(caption_width, 38)
	box.add_child(caption)
	return pill


func _add(parent: Control, text: String, on_pressed: Callable, width: float = 560, height: float = 66) -> Button:
	var button := UiKit.wood_button(text, width)
	button.custom_minimum_size.y = height
	button.add_theme_font_override("font", UiKit.FONT_DISPLAY)
	button.add_theme_font_size_override("font_size", 29)
	button.pressed.connect(on_pressed)
	parent.add_child(button)
	_menu_buttons.append(button)
	return button


func _small_button(parent: Control, text: String, action: Callable, width: float) -> Button:
	var button := UiKit.button(text, width)
	button.custom_minimum_size.y = 62
	button.add_theme_font_size_override("font_size", 23)
	for state in ["normal", "hover", "focus", "pressed"]:
		var fill := Color("e6e6c7") if state == "normal" else Color("d1daa6")
		var style := CoverStage.paper_style(fill, Color("a0ac72"), 13)
		style.shadow_size = 0
		button.add_theme_stylebox_override(state, style)
	button.add_theme_color_override("font_color", CoverStage.FOREST)
	button.add_theme_color_override("font_hover_color", CoverStage.FOREST)
	button.add_theme_color_override("font_focus_color", CoverStage.FOREST)
	button.add_theme_color_override("font_pressed_color", CoverStage.FOREST)
	button.pressed.connect(action)
	parent.add_child(button)
	_menu_buttons.append(button)
	return button


func _gallery(kind: String) -> void:
	Game.gallery_kind = kind
	Game.goto(Game.SCENE_GALLERY)


func _show_controls() -> void:
	var body := _open_modal("A LITTLE FRIENDLY RIVALRY")
	body.add_child(CoverStage.copy("Start empty-handed. Run over a toy to pick it up, then aim and throw.\nPress throw with empty paws to catch. Dash through danger.\nTreats arrive from round 2. Last dog standing scores!", 27))
	body.add_child(HSeparator.new())
	body.add_child(CoverStage.copy("GAMEPAD   Stick / D-pad move   •   X throw + catch   •   A dash\nWASD   Move   •   Space throw + catch   •   Shift / E dash\nARROWS   Move   •   Enter throw + catch   •   Ctrl or slash dash\nPAUSE   Esc on keyboard / Start on a gamepad", 25))
	body.add_child(CoverStage.copy("Party play: press A / Start, Space, or Enter to join.\nChoose a dog, ready up, then confirm again to set up the match.\nSolo practice: one player takes on three computer-controlled dogs.", 24, Color("6b754d")))
	_modal_close_button(body)


func _show_settings() -> void:
	var body := _open_modal("MAKE YOURSELF AT HOME")
	var sound := UiKit.wood_button("SOUND EFFECTS: ON" if Sfx.enabled else "SOUND EFFECTS: OFF", 770)
	sound.pressed.connect(func() -> void:
		Sfx.enabled = not Sfx.enabled
		sound.text = "SOUND EFFECTS: ON" if Sfx.enabled else "SOUND EFFECTS: OFF")
	body.add_child(sound)
	var music := UiKit.wood_button("MUSIC: ON" if Music.enabled else "MUSIC: OFF", 770)
	music.pressed.connect(func() -> void:
		Music.enabled = not Music.enabled
		music.text = "MUSIC: ON" if Music.enabled else "MUSIC: OFF")
	body.add_child(music)
	# Cabinets report their encoder name, but the override is here because they vary.
	var arcade_names := ["ARCADE CONTROLS: AUTO", "ARCADE CONTROLS: ALWAYS", "ARCADE CONTROLS: NEVER"]
	var arcade := UiKit.wood_button(arcade_names[int(Game.arcade_hints)], 770)
	arcade.pressed.connect(func() -> void:
		Game.arcade_hints = ((int(Game.arcade_hints) + 1) % 3) as Game.ArcadeHints
		arcade.text = arcade_names[int(Game.arcade_hints)])
	body.add_child(arcade)
	body.add_child(CoverStage.copy("MASTER VOLUME", 25))
	body.add_child(_volume_slider("Master"))
	body.add_child(CoverStage.copy("MUSIC VOLUME", 25))
	body.add_child(_volume_slider("Music"))
	body.add_child(CoverStage.copy("EFFECTS VOLUME", 25))
	body.add_child(_volume_slider("SFX"))
	var fullscreen := UiKit.wood_button("FULLSCREEN: ON" if _is_fullscreen() else "FULLSCREEN: OFF", 770)
	fullscreen.pressed.connect(func() -> void:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if _is_fullscreen() else DisplayServer.WINDOW_MODE_FULLSCREEN)
		fullscreen.text = "FULLSCREEN: ON" if _is_fullscreen() else "FULLSCREEN: OFF")
	body.add_child(fullscreen)
	body.add_child(CoverStage.copy("Settings apply for this play session.", 21, Color("6b754d")))
	_modal_close_button(body)
	sound.grab_focus()


## One slider per audio bus, so music and effects can be balanced against each other.
func _volume_slider(bus: String) -> HSlider:
	var index := AudioServer.get_bus_index(bus)
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.custom_minimum_size = Vector2(770, 44)
	slider.value = AudioServer.get_bus_volume_linear(index) if index != -1 else 1.0
	slider.value_changed.connect(func(value: float) -> void:
		if index != -1:
			AudioServer.set_bus_volume_linear(index, value))
	return slider


func _open_modal(title: String) -> VBoxContainer:
	_return_focus = get_viewport().gui_get_focus_owner()
	for button in _menu_buttons:
		button.focus_mode = Control.FOCUS_NONE
	_modal = Control.new()
	_modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_canvas.add_child(_modal)
	var shade := ColorRect.new()
	shade.color = Color(0.09, 0.14, 0.07, 0.68)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_modal.add_child(shade)
	var panel := PanelContainer.new()
	panel.position = Vector2(460, 190)
	panel.size = Vector2(1000, 710)
	var style := CoverStage.paper_style(CoverStage.PAPER, Color("c79859"), 26)
	style.content_margin_left = 48
	style.content_margin_right = 48
	style.content_margin_top = 34
	style.content_margin_bottom = 34
	panel.add_theme_stylebox_override("panel", style)
	_modal.add_child(panel)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 22)
	panel.add_child(body)
	body.add_child(CoverStage.heading(title, 42))
	return body


func _modal_close_button(body: VBoxContainer) -> void:
	var close := UiKit.wood_button("BACK TO THE PACK", 770)
	close.pressed.connect(_close_modal)
	body.add_child(close)
	close.grab_focus()
	var controls: Array[Control] = []
	for child in body.get_children():
		if child is Control and child.focus_mode == Control.FOCUS_ALL:
			controls.append(child)
	for i in controls.size():
		controls[i].focus_neighbor_top = controls[i].get_path_to(controls[wrapi(i - 1, 0, controls.size())])
		controls[i].focus_neighbor_bottom = controls[i].get_path_to(controls[(i + 1) % controls.size()])


func _close_modal() -> void:
	if not is_instance_valid(_modal):
		return
	_modal.queue_free()
	_modal = null
	for button in _menu_buttons:
		button.focus_mode = Control.FOCUS_ALL
	if is_instance_valid(_return_focus):
		_return_focus.grab_focus()


func _wire_focus(buttons: Array[Button]) -> void:
	for i in buttons.size():
		buttons[i].focus_neighbor_top = buttons[i].get_path_to(buttons[wrapi(i - 1, 0, buttons.size())])
		buttons[i].focus_neighbor_bottom = buttons[i].get_path_to(buttons[(i + 1) % buttons.size()])


func _is_fullscreen() -> bool:
	return DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
