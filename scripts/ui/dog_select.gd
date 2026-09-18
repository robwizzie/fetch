extends Control
## "Select your dog": press a join button on any device to claim a slot, left/right to pick
## a dog, confirm to ready up, back to un-ready / leave. When everyone is ready, confirm again
## to continue. Each joined slot polls its own DeviceInput, so any mix of pads/keyboards works.
## Cards use each dog's own colour (like the boards); the player colour is the border and tag.

const MIN_PLAYERS := 2

var _panels: Array[Control] = []
var _inputs: Dictionary = {}
var _footer: Label
var _continue: Button


func _ready() -> void:
	Music.play("menu")
	UiKit.backdrop(self)
	Game.reset_scores()
	for slot in Game.slots:
		slot.ready = slot.is_bot
		_inputs[slot] = DeviceInput.new(slot.device)

	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 18)
	root.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(root)

	root.add_child(UiKit.title("SELECT YOUR DOG", 78, UiKit.YELLOW))
	root.add_child(UiKit.label("Same friends. New tricks.  •  Pick your pup and ready up.", 23, UiKit.CREAM))

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 26)
	root.add_child(row)
	for i in Game.MAX_PLAYERS:
		var holder := Control.new()
		holder.custom_minimum_size = Vector2(380, 660)
		row.add_child(holder)
		_panels.append(holder)

	_footer = UiKit.label("", 24, Color(1, 1, 1, 0.8))
	root.add_child(_footer)
	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("separation", 18)
	root.add_child(actions)
	var back := _mouse_button("Back", 170)
	back.pressed.connect(func() -> void: Game.goto(Game.SCENE_MAIN_MENU))
	actions.add_child(back)
	var cpu := _mouse_button("Add CPU", 200)
	cpu.pressed.connect(_add_bot)
	actions.add_child(cpu)
	var drop := _mouse_button("Remove CPU", 220)
	drop.pressed.connect(_remove_bot)
	actions.add_child(drop)
	_continue = _mouse_button("Let's play!", 300)
	_continue.pressed.connect(func() -> void:
		if _all_ready():
			Game.goto(Game.SCENE_MATCH_SETUP))
	actions.add_child(_continue)
	_refresh_all()


func _unhandled_input(event: InputEvent) -> void:
	var device := DeviceInput.join_device_from_event(event)
	if device != DeviceInput.NONE and Game.get_slot_by_device(device) == null:
		var slot := Game.add_player(device)
		if slot:
			var inp := DeviceInput.new(device)
			inp.just_pressed(&"confirm")  # swallow the press that joined so it doesn't also ready up
			_inputs[slot] = inp
			Sfx.play("catch")
			_refresh_all()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel") and Game.slots.is_empty():
		Game.goto(Game.SCENE_MAIN_MENU)


func _process(_delta: float) -> void:
	for slot in Game.slots.duplicate():
		if slot.is_bot:
			continue
		var inp: DeviceInput = _inputs[slot]
		if not slot.ready:
			if inp.just_pressed(&"left"):
				_cycle(slot, -1)
			if inp.just_pressed(&"right"):
				_cycle(slot, 1)
		# Anyone at the panel can change the pack, ready or not: push up for another CPU,
		# down to send one home.
		if inp.just_pressed(&"up"):
			_add_bot()
		if inp.just_pressed(&"down"):
			_remove_bot()
		if inp.just_pressed(&"confirm"):
			if not slot.ready:
				slot.ready = true
				Sfx.play("catch", 1.2)
				_refresh_all()
			elif _all_ready():
				Game.goto(Game.SCENE_MATCH_SETUP)
		if inp.just_pressed(&"back"):
			if slot.ready:
				slot.ready = false
				Sfx.play("ui_back")
			else:
				Game.remove_player(slot)
				_inputs.erase(slot)
				Sfx.play("bounce")
			_refresh_all()


func _cycle(slot: PlayerSlot, dir: int) -> void:
	var i := Game.dogs.find(slot.dog)
	slot.dog = Game.dogs[wrapi(i + dir, 0, Game.dogs.size())]
	Sfx.play("ui_move")
	_refresh_all()


func _all_ready() -> bool:
	if Game.slots.size() < MIN_PLAYERS:
		return false
	for s in Game.slots:
		if not s.ready:
			return false
	return Game.slots.any(func(s: PlayerSlot) -> bool: return not s.is_bot)


func _refresh_all() -> void:
	_continue.disabled = not _all_ready()
	for i in _panels.size():
		var holder := _panels[i]
		for c in holder.get_children():
			c.queue_free()
		var slot := _slot_for_index(i)
		if slot:
			_fill_player_card(holder, slot)
		else:
			_fill_empty_card(holder, i)
	# The pack line is always shown: not being able to find the CPUs is worse than repeating it.
	var pack := "Push UP for a CPU  ·  DOWN to send one home"
	if _all_ready():
		_footer.text = "Everyone's ready!  Press %s to continue   ·   %s" % [_join_wording(), pack]
	elif Game.slots.size() < MIN_PLAYERS:
		_footer.text = "Join: %s   ·   %s" % [_join_wording(), pack]
	else:
		_footer.text = "Left / Right: pick a dog   ·   %s: ready   ·   %s: un-ready or leave   ·   %s" \
			% [DeviceInput.button_label(&"confirm", Game.slots), DeviceInput.button_label(&"back", Game.slots), pack]


## How to describe the join button. A cabinet has no Space or Enter, and saying so is noise.
func _join_wording() -> String:
	if DeviceInput.any_arcade(Game.slots) or DeviceInput.any_arcade_connected():
		return "any button on your panel"
	return "A / Start  ·  Space (WASD)  ·  Enter (Arrows)"


func _slot_for_index(i: int) -> PlayerSlot:
	for s in Game.slots:
		if s.index == i:
			return s
	return null


func _fill_empty_card(holder: Control, i: int) -> void:
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.add_theme_stylebox_override("panel", UiKit.panel_style(Color(1, 1, 1, 0.1), Color(0.07, 0.09, 0.15, 0.7)))
	holder.add_child(panel)
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 16)
	panel.add_child(v)
	var paw := PawIcon.new()
	paw.color = Color(1, 1, 1, 0.12)
	paw.custom_minimum_size = Vector2(140, 140)
	var c := CenterContainer.new()
	c.add_child(paw)
	v.add_child(c)
	v.add_child(UiKit.title("P%d" % (i + 1), 44, Color(1, 1, 1, 0.3)))
	v.add_child(UiKit.label("Press %s\nto join" % _join_wording(), 22, Color(1, 1, 1, 0.45)))
	v.add_child(UiKit.label("or push UP on a joined stick\nto seat a CPU here", 20, Color(1, 1, 1, 0.34)))
	var join := _mouse_button("Join the pack", 220)
	join.pressed.connect(_join_keyboard)
	v.add_child(join)


func _fill_player_card(holder: Control, slot: PlayerSlot) -> void:
	var dog := slot.dog
	var bg := UiKit.gradient_rect(dog.card_color, dog.card_color_dark)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	holder.add_child(bg)
	var frame := PanelContainer.new()
	frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	var fs := StyleBoxFlat.new()
	fs.bg_color = Color(0, 0, 0, 0)
	fs.border_color = slot.color
	fs.set_border_width_all(5)
	fs.set_corner_radius_all(22)
	fs.content_margin_left = 16
	fs.content_margin_right = 16
	fs.content_margin_top = 12
	fs.content_margin_bottom = 12
	frame.add_theme_stylebox_override("panel", fs)
	holder.add_child(frame)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	frame.add_child(v)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	head.add_child(UiKit.chip(slot.label, slot.color, 22))
	var dev := UiKit.label("CPU • Practice pal" if slot.is_bot else DeviceInput.describe(slot.device), 17, Color(1, 1, 1, 0.85))
	dev.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	dev.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(dev)
	v.add_child(head)

	v.add_child(UiKit.title(dog.display_name.to_upper(), 46, UiKit.CREAM))
	# The portrait takes whatever height the rest of the card does not, so the card fills
	# instead of leaving dead colour under the buttons — and every dog is scaled to the same
	# height, so they read as one set.
	# The live model rather than a crop of the reference sheet: what you pick is what walks
	# out of the pen. It keeps turning so the card reads as a thing, not a picture of one.
	var portrait := PanelContainer.new()
	var frame_style := StyleBoxFlat.new()
	frame_style.bg_color = Color(1, 1, 1, 0.13)
	frame_style.border_color = slot.color.lightened(0.15)
	frame_style.set_border_width_all(3)
	frame_style.set_corner_radius_all(16)
	portrait.add_theme_stylebox_override("panel", frame_style)
	portrait.custom_minimum_size = Vector2(340, 228)
	portrait.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var preview := ModelPreview.new(Vector2i(420, 300))
	preview.show_dog(dog)
	portrait.add_child(preview)
	v.add_child(portrait)

	var stats := VBoxContainer.new()
	stats.add_theme_constant_override("separation", 5)
	var bar := dog.card_color.lightened(0.35)
	stats.add_child(UiKit.stat_row("Speed", dog.speed_rating, bar))
	stats.add_child(UiKit.stat_row("Throw", dog.throw_rating, bar))
	stats.add_child(UiKit.stat_row("Catch", dog.catch_rating, bar))
	stats.add_child(UiKit.stat_row("Dash", dog.dash_rating, bar))
	v.add_child(stats)

	var desc := UiKit.label(dog.description, 21, UiKit.CREAM)
	desc.custom_minimum_size = Vector2(0, 62)
	v.add_child(desc)

	if slot.ready and not slot.is_bot:
		# The stamp sits over the portrait rather than taking a row of its own, so a ready
		# card keeps exactly the same layout — and the same portrait size — as the others.
		var ready := UiKit.chip("READY!", UiKit.YELLOW, 30)
		var stamp := CenterContainer.new()
		stamp.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
		stamp.offset_top = -84
		stamp.mouse_filter = Control.MOUSE_FILTER_IGNORE
		portrait.add_child(stamp)
		stamp.add_child(ready)
		ready.pivot_offset = Vector2(60, 22)
		ready.rotation_degrees = -4.0
		Juice.pop(ready, 1.5, 0.35)
		var change := _mouse_button("Change dog", 230)
		change.pressed.connect(func() -> void:
			slot.ready = false
			_refresh_all())
		v.add_child(change)
	else:
		# Picking a dog and committing to it are different actions, so they get their own rows.
		var controls := HBoxContainer.new()
		controls.alignment = BoxContainer.ALIGNMENT_CENTER
		controls.add_theme_constant_override("separation", 10)
		v.add_child(controls)
		for dir in [-1, 1]:
			var arrow := _mouse_button("◀" if dir == -1 else "▶", 120)
			arrow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			arrow.pressed.connect(func() -> void: _cycle(slot, dir))
			controls.add_child(arrow)
		v.add_child(UiKit.label("UP: add a CPU   ·   DOWN: remove one", 18, Color(1, 1, 1, 0.5)))
		var ready_button := _mouse_button("Remove" if slot.is_bot else "Ready!", 200)
		ready_button.pressed.connect(func() -> void:
			if slot.is_bot:
				Game.remove_player(slot)
				_inputs.erase(slot)
			else:
				slot.ready = true
			_refresh_all())
		ready_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.add_child(ready_button)


func _mouse_button(text: String, width: float) -> Button:
	var b := UiKit.wood_button(text, width)
	b.icon = null
	b.alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.add_theme_font_size_override("font_size", 24)
	# Joining and readiness are per-device; global UI accept must not consume their presses.
	b.focus_mode = Control.FOCUS_NONE
	return b


func _join_keyboard() -> void:
	for device in [DeviceInput.KEYBOARD_WASD, DeviceInput.KEYBOARD_ARROWS]:
		if Game.get_slot_by_device(device) == null:
			var slot := Game.add_player(device)
			if slot:
				_inputs[slot] = DeviceInput.new(device)
				Sfx.play("catch")
				_refresh_all()
			return


## Sends the most recently added CPU home. Humans are never removed this way - a player
## leaves with their own back button, so nobody can be kicked out by someone else's stick.
func _remove_bot() -> void:
	for i in range(Game.slots.size() - 1, -1, -1):
		var slot: PlayerSlot = Game.slots[i]
		if slot.is_bot:
			Game.remove_player(slot)
			_inputs.erase(slot)
			Sfx.play("ui_back")
			_refresh_all()
			return


func _add_bot() -> void:
	if Game.slots.size() >= Game.MAX_PLAYERS:
		return
	# Leave room for a human and make the one-click practice route work from an empty lobby.
	if Game.slots.is_empty():
		_join_keyboard()
	var device := DeviceInput.VIRTUAL
	while Game.get_slot_by_device(device) != null:
		device -= 1
	var slot := Game.add_player(device)
	if slot:
		slot.is_bot = true
		slot.ready = true
		_inputs[slot] = DeviceInput.new(DeviceInput.VIRTUAL)
		_refresh_all()
