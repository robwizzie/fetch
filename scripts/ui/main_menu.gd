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
		# Whoever drives the menu with the arrows and Enter plays on the arrows layout.
		var key := (event as InputEventKey).physical_keycode
		var arrows := [KEY_ENTER, KEY_KP_ENTER, KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT, KEY_BACKSPACE]
		_activation_device = DeviceInput.KEYBOARD_ARROWS if key in arrows else DeviceInput.KEYBOARD_WASD
	if event.is_action_pressed("ui_cancel") and is_instance_valid(_modal):
		_close_modal()
		get_viewport().set_input_as_handled()



func _build_menu() -> void:
	# The two ways to play get full-width boards; everything you browse sits in a grid of
	# smaller ones beneath, so eight choices fit the column without crowding the footer.
	var menu := VBoxContainer.new()
	menu.position = Vector2(CoverStage.COLUMN_X, CoverStage.COLUMN_TOP)
	menu.size = Vector2(560, 482)
	menu.add_theme_constant_override("separation", 10)
	_canvas.add_child(menu)
	var play := _add(menu, "PARTY PLAY", func() -> void: Game.goto(Game.SCENE_DOG_SELECT), 560, 76)
	play.add_theme_font_size_override("font_size", 36)
	play.tooltip_text = "2–4 friends. Join with gamepads or share a keyboard."
	var solo := _add(menu, "SOLO PRACTICE", func() -> void: Game.start_practice(_activation_device))
	solo.tooltip_text = "Pick your dog, then take on three computer-controlled dogs."
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 10)
	menu.add_child(grid)
	for entry in [["MEET THE PACK", func() -> void: _gallery("dogs")], ["TOYS", func() -> void: _gallery("toys")],
			["ARENAS", func() -> void: _gallery("arenas")], ["POWER-UPS", func() -> void: _gallery("powerups")],
			["HATS  %d/%d" % [Progress.unlocked_hats().size(), Game.hats.size()], func() -> void: _gallery("hats")],
			["SETTINGS", _show_settings]]:
		var item := _add(grid, entry[0], entry[1], 274, 60)
		item.add_theme_font_size_override("font_size", 25)

	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 12)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 8)
	menu.add_child(gap)
	menu.add_child(footer)
	_small_button(footer, "HOW TO PLAY", _show_controls, 336)
	_small_button(footer, "QUIT", func() -> void: get_tree().quit(), 208)

	var blurb := CoverStage.copy("1–4 players   •   local multiplayer   •   gamepads + keyboard", 21, Color(0.92, 0.95, 0.86))
	blurb.position = Vector2(CoverStage.COLUMN_X + 2, 870)
	blurb.size = Vector2(700, 32)
	_canvas.add_child(blurb)

	_build_session_chip()
	_build_button_hints()
	# Directional focus by position: the grid wants left/right between its columns and up/down
	# between its rows, which Godot's own neighbour search already gives.
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


func _add(parent: Control, text: String, on_pressed: Callable, width: float = 560, height: float = 62) -> Button:
	var button := UiKit.wood_button(text, width)
	button.custom_minimum_size.y = height
	button.add_theme_font_override("font", UiKit.FONT_DISPLAY)
	button.add_theme_font_size_override("font_size", 29)
	button.pressed.connect(on_pressed)
	parent.add_child(button)
	_menu_buttons.append(button)
	return button


func _small_button(parent: Control, text: String, action: Callable, width: float) -> Button:
	# The same boards as the menu above, a size down, so the two read as one set.
	var button := UiKit.wood_button(text, width, true)
	button.pressed.connect(action)
	parent.add_child(button)
	_menu_buttons.append(button)
	return button


func _gallery(kind: String) -> void:
	Game.gallery_kind = kind
	Game.goto(Game.SCENE_GALLERY)


func _show_controls() -> void:
	var body := _open_modal("A LITTLE FRIENDLY RIVALRY")
	# The whole game in a handful of moves, as cards rather than a paragraph.
	var tips := GridContainer.new()
	tips.columns = 2
	tips.add_theme_constant_override("h_separation", 14)
	tips.add_theme_constant_override("v_separation", 14)
	for tip in [
		["GRAB", "Start empty-handed. Run over a toy to pick it up."],
		["THROW", "Aim and throw. Hold the button for a harder throw."],
		["CATCH", "Press throw with empty paws as a toy flies at you."],
		["DASH", "Tap dash to dart out of the way of a flying toy."],
		["BARK", "Bark at your rivals. Purely for morale."],
		["TREATS", "Grab mystery treats for power-ups. Carry up to three."],
	]:
		tips.add_child(_tip_card(tip[0], tip[1]))
	body.add_child(tips)
	var goal := _modal_copy("One hit from a flying toy and you're out. Last dog standing scores!", 25)
	goal.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_child(goal)
	body.add_child(_section("CONTROLS"))
	body.add_child(_controls_grid())
	body.add_child(_section("GETTING STARTED"))
	body.add_child(_modal_copy(("Party play: press %s to join, choose a dog, then confirm again to set up the match.\nSolo practice: pick your dog and take on three computer-controlled dogs.\nForgot a button mid-match? Pause - the controls are there too." \
		% DeviceInput.button_label(&"confirm", [])), 23))
	_modal_close_button(body)


func _tip_card(heading: String, text: String) -> PanelContainer:
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var style := StyleBoxFlat.new()
	style.bg_color = Color("f6e6c4")
	style.border_color = Color("dcc08f")
	style.set_border_width_all(2)
	style.set_corner_radius_all(16)
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 10
	style.content_margin_bottom = 12
	card.add_theme_stylebox_override("panel", style)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 2)
	card.add_child(column)
	var title := UiKit.title(heading, 28, UiKit.PAW_ORANGE)
	title.add_theme_color_override("font_outline_color", UiKit.PLANK_INK)
	title.add_theme_constant_override("outline_size", 6)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	column.add_child(title)
	column.add_child(_modal_copy(text, 21))
	return card


## Every way to play, as the keys and buttons themselves: one row per kind of controller
## plugged in (an Xbox-style row when none is), then both keyboard layouts.
func _controls_grid() -> GridContainer:
	var grid := GridContainer.new()
	var actions := [[&"move", "Move"], [&"throw", "Throw / catch"], [&"dash", "Dash"], [&"bark", "Bark"], [&"pause", "Pause"]]
	grid.columns = actions.size() + 1
	grid.add_theme_constant_override("h_separation", 18)
	grid.add_theme_constant_override("v_separation", 12)
	grid.add_child(Control.new())
	for action in actions:
		var head := _modal_copy(action[1], 19)
		head.modulate = Color(1, 1, 1, 0.7)
		head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		head.autowrap_mode = TextServer.AUTOWRAP_OFF
		grid.add_child(head)
	var rows: Array = []
	var seen: Array[String] = []
	for device in Input.get_connected_joypads():
		var family := DeviceInput.family_name(device)
		if not seen.has(family):
			seen.append(family)
			rows.append([family, device, -1])
	if rows.is_empty():
		rows.append([DeviceInput.family_name(0), 0, DeviceInput.PadFamily.XBOX])
	for device in [DeviceInput.KEYBOARD_WASD, DeviceInput.KEYBOARD_ARROWS]:
		rows.append([DeviceInput.family_name(device), device, -1])
	for row in rows:
		var name_label := _modal_copy(str(row[0]), 21)
		name_label.autowrap_mode = TextServer.AUTOWRAP_OFF
		name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		grid.add_child(name_label)
		for action in actions:
			var cell := CenterContainer.new()
			cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			cell.add_child(UiKit.keycaps(action[0], row[1], 17, row[2]))
			grid.add_child(cell)
	return grid


func _show_settings() -> void:
	var body := _open_modal("MAKE YOURSELF AT HOME")
	body.add_child(_section("SOUND"))
	var sound := _setting("Sound effects", func() -> Variant: return Sfx.enabled,
		func() -> void: Sfx.enabled = not Sfx.enabled)
	body.add_child(sound)
	body.add_child(_setting("Music", func() -> Variant: return Music.enabled,
		func() -> void: Music.enabled = not Music.enabled))
	body.add_child(_volume_row("Master volume", "Master"))
	body.add_child(_volume_row("Music volume", "Music"))
	body.add_child(_volume_row("Effects volume", "SFX"))

	body.add_child(_section("GAME FEEL"))
	body.add_child(_flag("Controller rumble", "rumble"))
	body.add_child(_flag("Knockout slow motion", "knockout_slowmo"))
	body.add_child(_flag("Final-bonk replay", "replays"))
	body.add_child(_flag("Screen shake", "screen_shake"))

	body.add_child(_section("SCREEN"))
	body.add_child(_flag("Colour-blind friendly colours", "colorblind_colors"))
	# Remembered, so a cabinet comes back up filling its screen. F11 or Start+Select also works.
	body.add_child(_setting("Fullscreen", func() -> Variant: return _is_fullscreen(),
		func() -> void: Game.set_fullscreen(not _is_fullscreen())))

	body.add_child(_section("CONTROLLERS"))
	# Cabinets report their encoder name, but the override is here because they vary.
	var arcade_names := ["Auto", "Always", "Never"]
	body.add_child(_setting("Arcade button labels", func() -> Variant: return arcade_names[int(Game.arcade_hints)],
		func() -> void: Game.arcade_hints = ((int(Game.arcade_hints) + 1) % 3) as Game.ArcadeHints))
	body.add_child(_setting("Controller test", func() -> Variant: return "Open",
		func() -> void: Game.goto("res://scenes/ui/controller_test.tscn")))
	var note := _modal_copy("Everything here is remembered on this machine.", 20)
	note.modulate = Color(1, 1, 1, 0.7)
	body.add_child(note)
	_modal_close_button(body)
	sound.grab_focus()


## An on/off setting kept in a Game property.
func _flag(title: String, property: String) -> Button:
	return _setting(title, func() -> Variant: return Game.get(property),
		func() -> void: Game.set(property, not Game.get(property)))


## A small heading that splits the paper into groups.
func _section(text: String) -> Label:
	var label := UiKit.title(text, 24, Color("b0602a"))
	label.add_theme_constant_override("outline_size", 0)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	return label


## A setting on the paper: what it is on the left, its state on the right - a switch for on/off
## (when [param read] returns a bool), a wooden tag for anything else. Pressing it, or left and
## right on it, moves to the next state, and the change is saved straight away.
func _setting(title: String, read: Callable, advance: Callable) -> Button:
	var row := Button.new()
	row.set_meta("setting", title)
	row.custom_minimum_size = Vector2(0, 54)
	row.add_theme_stylebox_override("normal", _row_style(Color(0, 0, 0, 0), Color(0, 0, 0, 0)))
	var lit := _row_style(Color(UiKit.WOOD, 0.14), UiKit.PAW_ORANGE)
	for state_name in ["hover", "focus", "pressed", "hover_pressed"]:
		row.add_theme_stylebox_override(state_name, lit)
	var line := HBoxContainer.new()
	line.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	line.offset_left = 16
	line.offset_right = -12
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(line)
	var caption := _modal_copy(title, 25)
	caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	caption.autowrap_mode = TextServer.AUTOWRAP_OFF
	line.add_child(caption)
	var state := Control.new()
	state.custom_minimum_size = Vector2(220, 0)
	state.mouse_filter = Control.MOUSE_FILTER_IGNORE
	state.draw.connect(func() -> void: _draw_state(state, read.call(), row.has_focus() or row.is_hovered()))
	line.add_child(state)
	row.pressed.connect(func() -> void:
		advance.call()
		Game.save_settings()
		Sfx.play("ui_move", 1.0, -4.0)
		state.queue_redraw())
	row.gui_input.connect(func(event: InputEvent) -> void:
		if event.is_action_pressed("ui_left") or event.is_action_pressed("ui_right"):
			row.pressed.emit()
			row.accept_event())
	for changed: Signal in [row.focus_entered, row.focus_exited, row.mouse_entered, row.mouse_exited]:
		changed.connect(state.queue_redraw)
	return row


func _row_style(fill: Color, edge: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = edge
	style.set_border_width_all(3)
	style.set_corner_radius_all(14)
	return style


## The right-hand end of a setting row: a switch, or the current choice on a wooden tag.
func _draw_state(canvas: Control, value: Variant, lit: bool) -> void:
	var font := UiKit.FONT_DISPLAY
	var mid := canvas.size.y * 0.5
	if value is bool:
		var on: bool = value
		var track := Rect2(canvas.size.x - 78.0, mid - 19.0, 78.0, 38.0)
		var groove := StyleBoxFlat.new()
		groove.bg_color = UiKit.SELECT_GREEN if on else Color("d6c39d")
		groove.border_color = UiKit.SELECT_GREEN_DARK if on else Color("b39c70")
		groove.set_border_width_all(3)
		groove.set_corner_radius_all(19)
		canvas.draw_style_box(groove, track)
		var knob := Vector2(track.end.x - 19.0 if on else track.position.x + 19.0, mid)
		canvas.draw_circle(knob + Vector2(0, 2), 14.0, Color(0, 0, 0, 0.18))
		canvas.draw_circle(knob, 14.0, Color.WHITE)
		var word := "ON" if on else "OFF"
		var width := font.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x
		canvas.draw_string(font, Vector2(track.position.x - 14.0 - width, mid + 9.0), word, HORIZONTAL_ALIGNMENT_LEFT, -1, 22,
			UiKit.SELECT_GREEN_DARK if on else Color(CoverStage.BROWN, 0.55))
		return
	var text := str(value).to_upper()
	var text_width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 21).x
	var tag := Rect2(canvas.size.x - text_width - 60.0, mid - 19.0, text_width + 60.0, 38.0)
	var board := StyleBoxFlat.new()
	board.bg_color = UiKit.WOOD_LIGHT if lit else UiKit.WOOD
	board.border_color = UiKit.PLANK_INK
	board.set_border_width_all(3)
	board.set_corner_radius_all(12)
	canvas.draw_style_box(board, tag)
	var baseline := Vector2(tag.position.x + 30.0, mid + 9.0)
	canvas.draw_string_outline(font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 21, 6, UiKit.PLANK_INK)
	canvas.draw_string(font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 21, UiKit.CREAM)
	for side in [-1.0, 1.0]:
		var x: float = tag.position.x + 15.0 if side < 0.0 else tag.end.x - 15.0
		canvas.draw_colored_polygon(PackedVector2Array([Vector2(x + 4.0 * side, mid), Vector2(x - 3.0 * side, mid - 6.0),
			Vector2(x - 3.0 * side, mid + 6.0)]), Color(UiKit.CREAM, 0.85))


## Text on the modal's paper. The cover's cream reads over photography and vanishes over this,
## which is what made the volume rows look disabled - they were there all along, in cream.
func _modal_copy(text: String, size_: int = 24) -> Label:
	return CoverStage.copy(text, size_, CoverStage.BROWN)


## Label, slider and a live percentage on one row. The number matters: a bare groove gives no
## idea what "a bit quieter" actually means, and this screen is often set once and left.
func _volume_row(label: String, bus: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	row.custom_minimum_size = Vector2(0, 52)
	var caption := _modal_copy(label, 24)
	caption.custom_minimum_size = Vector2(268, 0)
	caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(caption)
	var index := AudioServer.get_bus_index(bus)
	var level := AudioServer.get_bus_volume_linear(index) if index != -1 else 1.0
	var readout := _modal_copy("%d%%" % roundi(level * 100.0), 24)
	readout.custom_minimum_size = Vector2(78, 0)
	readout.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	readout.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var slider := _volume_slider(index, level)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.value_changed.connect(func(value: float) -> void:
		readout.text = "%d%%" % roundi(value * 100.0))
	row.add_child(slider)
	row.add_child(readout)
	return row


## One slider per audio bus, so music and effects can be balanced against each other. Dressed
## as a wooden groove with a paw for a knob, because the stock control is a grey line that
## belongs to a different game.
func _volume_slider(index: int, level: float) -> HSlider:
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.custom_minimum_size = Vector2(430, 46)
	slider.value = level
	slider.add_theme_stylebox_override("slider", _groove(Color("e3d6b4"), Color("c0aa7c")))
	slider.add_theme_stylebox_override("grabber_area", _groove(UiKit.SELECT_GREEN, UiKit.SELECT_GREEN_DARK))
	slider.add_theme_stylebox_override("grabber_area_highlight", _groove(UiKit.SELECT_GREEN, UiKit.SELECT_GREEN_DARK))
	var knob := PawIcon.texture(38, UiKit.WOOD_DARK)
	slider.add_theme_icon_override("grabber", knob)
	slider.add_theme_icon_override("grabber_highlight", PawIcon.texture(38, UiKit.WOOD))
	slider.value_changed.connect(func(value: float) -> void:
		if index != -1:
			AudioServer.set_bus_volume_linear(index, value))
	# Saved on release rather than on every step: dragging writes the file once, not forty times.
	slider.drag_ended.connect(func(changed: bool) -> void:
		if changed:
			Game.save_settings())
	return slider


## The bar a slider runs in: low, rounded and outlined like the rest of the paper furniture.
func _groove(fill: Color, edge: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = edge
	style.set_border_width_all(2)
	style.set_corner_radius_all(9)
	style.content_margin_top = 9
	style.content_margin_bottom = 9
	return style


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
	# Tall enough for the settings to fit without scrolling. The scroll below is the safety
	# net for a smaller window, not the way this screen is meant to be read.
	panel.position = Vector2(440, 104)
	panel.size = Vector2(1040, 872)
	var style := CoverStage.paper_style(CoverStage.PAPER, Color("c79859"), 26)
	style.content_margin_left = 48
	style.content_margin_right = 48
	style.content_margin_top = 34
	style.content_margin_bottom = 34
	panel.add_theme_stylebox_override("panel", style)
	_modal.add_child(panel)
	# Heading pinned, everything else scrolling. Settings had grown to about 900px of content
	# inside a 642px panel, so the last rows - fullscreen and the way out - fell off the
	# bottom of the screen with no way to reach them.
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	panel.add_child(column)
	column.add_child(CoverStage.heading(title, 42))
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.follow_focus = true
	column.add_child(scroll)
	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 16)
	scroll.add_child(body)
	return body


func _modal_close_button(body: VBoxContainer) -> void:
	var close := UiKit.wood_button("BACK TO THE PACK", 440)
	close.alignment = HORIZONTAL_ALIGNMENT_CENTER
	close.pressed.connect(_close_modal)
	var centre := CenterContainer.new()
	centre.add_child(close)
	body.add_child(centre)
	close.grab_focus()
	# Recursive: the volume sliders sit inside label rows, and a controller has to reach them.
	var controls: Array[Control] = []
	for child in body.find_children("*", "Control", true, false):
		if child.focus_mode == Control.FOCUS_ALL and child.is_visible_in_tree():
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
