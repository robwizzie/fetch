extends Control
## Live controller readout. Arcade encoder boards rarely have an SDL mapping, so Godot reports
## raw hardware indices and the usual button names mean nothing — this shows what the hardware
## actually sends so bindings can be set from fact rather than guesswork.

const AXES := [JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y, JOY_AXIS_RIGHT_X, JOY_AXIS_RIGHT_Y]

var _devices: VBoxContainer
var _pressed: Label
var _last: Label
var _seen: Array[String] = []


func _ready() -> void:
	UiKit.backdrop(self)
	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.alignment = BoxContainer.ALIGNMENT_CENTER
	root.add_theme_constant_override("separation", 14)
	add_child(root)
	root.add_child(UiKit.title("CONTROLLER TEST", 64, UiKit.ACCENT))
	root.add_child(_line("Press every button and push the stick. Whatever the machine sends shows up here.",
		22, Color(1, 1, 1, 0.75)))

	_devices = VBoxContainer.new()
	_devices.add_theme_constant_override("separation", 4)
	root.add_child(_devices)

	_pressed = _line("", 30, UiKit.CREAM)
	_pressed.custom_minimum_size = Vector2(0, 44)
	root.add_child(_pressed)

	_last = _line("", 22, Color(0.75, 0.95, 0.75))
	_last.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_last.custom_minimum_size = Vector2(0, 120)
	root.add_child(_last)

	var back := UiKit.button("Back")
	back.pressed.connect(func() -> void: Game.goto(Game.SCENE_MAIN_MENU))
	root.add_child(_centred(back))
	back.grab_focus()
	_refresh_devices()
	Input.joy_connection_changed.connect(func(_d: int, _c: bool) -> void: _refresh_devices())


## A full-width, centred, non-wrapping line. The root VBox supplies the width.
func _line(text: String, size: int, color: Color) -> Label:
	var label := UiKit.label(text, size, color)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	return label


func _centred(control: Control) -> CenterContainer:
	var box := CenterContainer.new()
	box.add_child(control)
	return box


func _refresh_devices() -> void:
	for child in _devices.get_children():
		child.queue_free()
	var pads := Input.get_connected_joypads()
	if pads.is_empty():
		_devices.add_child(_line("No controllers detected.", 24, Color(1, 0.7, 0.6)))
		return
	for device in pads:
		# "Mapped" means Godot knows the layout and button names are meaningful; unmapped means
		# raw indices, which is normal for an arcade board.
		var mapped := "mapped" if Input.is_joy_known(device) else "UNMAPPED (raw indices)"
		_devices.add_child(_line("Pad %d — %s  ·  %s" % [device, Input.get_joy_name(device), mapped], 22, UiKit.CREAM))


func _process(_delta: float) -> void:
	var live: Array[String] = []
	for device in Input.get_connected_joypads():
		for button in range(0, 32):
			if Input.is_joy_button_pressed(device, button):
				var tag := "pad%d button %d" % [device, button]
				live.append(tag)
				if not _seen.has(tag):
					_seen.append(tag)
		for axis in AXES:
			var value := Input.get_joy_axis(device, axis)
			if absf(value) > 0.4:
				live.append("pad%d axis %d %+.2f" % [device, axis, value])
	_pressed.text = "  ".join(live) if not live.is_empty() else "— press something —"
	if not _seen.is_empty():
		_last.text = "Buttons seen so far:\n" + ", ".join(_seen)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		Game.goto(Game.SCENE_MAIN_MENU)
