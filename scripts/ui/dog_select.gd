extends Control
## "Select your dog": press a join button on any device to claim a slot, left/right to pick
## a dog, throw to ready up, back to un-ready / leave. When everyone is ready, throw again
## to continue. Each joined slot polls its own DeviceInput, so any mix of pads/keyboards works.

const MIN_PLAYERS := 2

var _panels: Array[PanelContainer] = []
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
	root.add_theme_constant_override("separation", 20)
	root.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(root)

	root.add_child(UiKit.title("SELECT YOUR DOG", 72, UiKit.ACCENT))

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 24)
	root.add_child(row)
	for i in Game.MAX_PLAYERS:
		var panel := PanelContainer.new()
		panel.custom_minimum_size = Vector2(380, 620)
		row.add_child(panel)
		_panels.append(panel)

	_footer = UiKit.label("", 24, Color(1, 1, 1, 0.75))
	root.add_child(_footer)
	_refresh_all()


func _unhandled_input(event: InputEvent) -> void:
	var device := DeviceInput.join_device_from_event(event)
	if device != DeviceInput.NONE and Game.get_slot_by_device(device) == null:
		var slot := Game.add_player(device)
		if slot:
			var inp := DeviceInput.new(device)
			inp.just_pressed(&"throw")  # swallow the press that joined so it doesn't also ready up
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
		if inp.just_pressed(&"throw"):
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
		var panel := _panels[i]
		for c in panel.get_children():
			c.queue_free()
		var slot := _slot_for_index(i)
		if slot:
			_fill_player_panel(panel, slot)
		else:
			_fill_empty_panel(panel, i)
	if _all_ready():
		_footer.text = "Everyone's ready!  Press THROW to continue"
	elif Game.slots.size() < MIN_PLAYERS:
		_footer.text = "Need %d+ players.  Join: gamepad A / Start  ·  Space (WASD)  ·  Enter (Arrows)" % MIN_PLAYERS
	else:
		_footer.text = "Left / Right: pick a dog  ·  Throw: ready  ·  Back: un-ready / leave"


func _slot_for_index(i: int) -> PlayerSlot:
	for s in Game.slots:
		if s.index == i:
			return s
	return null


func _fill_empty_panel(panel: PanelContainer, i: int) -> void:
	panel.add_theme_stylebox_override("panel", UiKit.panel_style(Color(1, 1, 1, 0.12), Color(0.08, 0.1, 0.16, 0.6)))
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(v)
	v.add_child(UiKit.label("P%d" % (i + 1), 40, Color(1, 1, 1, 0.3)))
	v.add_child(UiKit.label("Press A / Space / Enter\nto join", 26, Color(1, 1, 1, 0.4)))


func _fill_player_panel(panel: PanelContainer, slot: PlayerSlot) -> void:
	var dog := slot.dog
	panel.add_theme_stylebox_override("panel", UiKit.panel_style(slot.color))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	panel.add_child(v)

	var header := UiKit.label("%s  ·  %s" % [slot.label, DeviceInput.describe(slot.device)], 20, slot.color)
	v.add_child(header)
	v.add_child(UiKit.title(dog.display_name.to_upper(), 44, Color.WHITE))

	v.add_child(UiKit.dog_portrait(dog, slot.color, Vector2(340, 230), 1.3, 0.6))

	var stats := VBoxContainer.new()
	stats.add_theme_constant_override("separation", 4)
	stats.add_child(UiKit.stat_row("Speed", dog.speed_rating, slot.color))
	stats.add_child(UiKit.stat_row("Throw", dog.throw_rating, slot.color))
	stats.add_child(UiKit.stat_row("Catch", dog.catch_rating, slot.color))
	stats.add_child(UiKit.stat_row("Dash", dog.dash_rating, slot.color))
	v.add_child(stats)

	var desc := UiKit.label(dog.description, 22, Color(1, 1, 1, 0.85))
	desc.custom_minimum_size = Vector2(0, 70)
	v.add_child(desc)

	var status := UiKit.label("READY!" if slot.ready else "◀  ▶  choose   ·   throw = ready", 26 if slot.ready else 20, UiKit.ACCENT if slot.ready else Color(1, 1, 1, 0.6))
	v.add_child(status)
	if slot.ready:
		status.pivot_offset = Vector2(170, 15)
		Juice.pop(status, 1.4, 0.3)
