extends Control
## "Select your dog": press a join button on any device to claim a slot, left/right to pick
## a dog, confirm to ready up, back to un-ready / leave. When everyone is ready, confirm again
## to continue. Each joined slot polls its own DeviceInput, so any mix of pads/keyboards works.
## Cards use each dog's own colour (like the boards); the player colour is the border and tag.

const MIN_PLAYERS := 2

var _panels: Array[Control] = []
var _inputs: Dictionary = {}
var _footer: Label


func _ready() -> void:
	UiKit.backdrop(self)
	Game.reset_scores()
	for slot in Game.slots:
		slot.ready = false
		_inputs[slot] = DeviceInput.new(slot.device)

	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 18)
	root.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(root)

	root.add_child(UiKit.title("SELECT YOUR DOG", 78, UiKit.YELLOW))

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
		var inp: DeviceInput = _inputs[slot]
		if not slot.ready:
			if inp.just_pressed(&"left"):
				_cycle(slot, -1)
			if inp.just_pressed(&"right"):
				_cycle(slot, 1)
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
				Sfx.play("ui", 0.8)
			else:
				Game.remove_player(slot)
				_inputs.erase(slot)
				Sfx.play("bounce")
			_refresh_all()


func _cycle(slot: PlayerSlot, dir: int) -> void:
	var i := Game.dogs.find(slot.dog)
	slot.dog = Game.dogs[wrapi(i + dir, 0, Game.dogs.size())]
	Sfx.play("ui")
	_refresh_all()


func _all_ready() -> bool:
	if Game.slots.size() < MIN_PLAYERS:
		return false
	for s in Game.slots:
		if not s.ready:
			return false
	return true


func _refresh_all() -> void:
	for i in _panels.size():
		var holder := _panels[i]
		for c in holder.get_children():
			c.queue_free()
		var slot := _slot_for_index(i)
		if slot:
			_fill_player_card(holder, slot)
		else:
			_fill_empty_card(holder, i)
	if _all_ready():
		_footer.text = "Everyone's ready!  Press A / Enter to continue"
	elif Game.slots.size() < MIN_PLAYERS:
		_footer.text = "Need %d+ players.   Join:  gamepad A / Start  ·  Space (WASD)  ·  Enter (Arrows)" % MIN_PLAYERS
	else:
		_footer.text = "Left / Right: pick a dog   ·   A / Enter: ready   ·   B / Esc: un-ready or leave"


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
	v.add_child(UiKit.label("Press A / Space / Enter\nto join", 24, Color(1, 1, 1, 0.45)))


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
	var dev := UiKit.label(DeviceInput.describe(slot.device), 17, Color(1, 1, 1, 0.85))
	dev.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	dev.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(dev)
	v.add_child(head)

	v.add_child(UiKit.title(dog.display_name.to_upper(), 46, UiKit.CREAM))
	v.add_child(UiKit.dog_portrait(dog, slot.color, Vector2(340, 250), 1.0, 0.0, true))

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

	if slot.ready:
		var ready := UiKit.chip("READY!", UiKit.YELLOW, 30)
		var c := CenterContainer.new()
		c.add_child(ready)
		v.add_child(c)
		ready.pivot_offset = Vector2(60, 22)
		ready.rotation_degrees = -4.0
		Juice.pop(ready, 1.5, 0.35)
	else:
		v.add_child(UiKit.label("◀  ▶  choose   ·   A / Enter = ready", 19, Color(1, 1, 1, 0.75)))
