extends Node
## On-screen controls name the buttons printed on what each player is holding, and only those.
##   godot --headless --path . res://tests/controls_test.tscn

var _failed := false


func _ready() -> void:
	Sfx.enabled = false
	Game.arcade_hints = Game.ArcadeHints.NEVER
	# Godot maps pad buttons by position, so throw (the left face button) has three names.
	_check(DeviceInput.pad_glyph(&"throw", DeviceInput.PadFamily.XBOX).begins_with("X"), "Xbox throw is X")
	_check(DeviceInput.pad_glyph(&"throw", DeviceInput.PadFamily.PLAYSTATION).begins_with("Square"), "PlayStation throw is Square")
	_check(DeviceInput.pad_glyph(&"throw", DeviceInput.PadFamily.NINTENDO).begins_with("Y"), "Switch throw is Y")
	_check(DeviceInput.pad_glyph(&"dash", DeviceInput.PadFamily.XBOX).begins_with("A"), "Xbox dash is A")
	_check(DeviceInput.pad_glyph(&"dash", DeviceInput.PadFamily.PLAYSTATION).begins_with("Cross"), "PlayStation dash is Cross")
	_check(DeviceInput.pad_glyph(&"dash", DeviceInput.PadFamily.NINTENDO).begins_with("B"), "Switch dash is B")
	_check(DeviceInput.pad_glyph(&"pause", DeviceInput.PadFamily.PLAYSTATION) == "Options", "PlayStation pause is Options")
	_check(DeviceInput.pad_glyph(&"throw", DeviceInput.PadFamily.ARCADE) == "Button 1", "a cabinet says Button 1")
	for family in DeviceInput.PadFamily.values():
		for action in [&"move", &"throw", &"dash", &"confirm", &"back", &"pause"]:
			_check(not DeviceInput.pad_glyph(action, family).is_empty(), "every pad family names %s" % action)

	# Keyboards name their real keys, including every alternative the input code accepts.
	_check(DeviceInput.glyph(&"dash", DeviceInput.KEYBOARD_WASD) == "Shift or E", "WASD dash lists both keys")
	_check(DeviceInput.glyph(&"throw", DeviceInput.KEYBOARD_ARROWS) == "Enter", "Arrows throw is Enter")
	_check(DeviceInput.controls_line(DeviceInput.KEYBOARD_WASD).contains("Esc pause"), "the line includes pause")

	# Shared prompts speak only to the humans who joined, without repeats; bots say nothing.
	var wasd := _slot(DeviceInput.KEYBOARD_WASD, false)
	var arrows := _slot(DeviceInput.KEYBOARD_ARROWS, false)
	var bot := _slot(DeviceInput.VIRTUAL, true)
	_check(DeviceInput.button_label(&"throw", [wasd]) == "Space", "one keyboard player sees only Space")
	_check(DeviceInput.button_label(&"throw", [wasd, bot]) == "Space", "a CPU adds nothing to the prompt")
	_check(DeviceInput.button_label(&"throw", [wasd, arrows]) == "Space  /  Enter", "two layouts, two keys")
	_check(DeviceInput.button_label(&"throw", [wasd, _slot(DeviceInput.KEYBOARD_WASD, false)]) == "Space", "no repeats")
	_check(DeviceInput.button_label(&"throw", []).contains("Space"), "before anyone joins, the keyboards are listed")

	# The match HUD shows each player's own line.
	Game.clear_players()
	Game.slots.append(wasd)
	Game.slots.append(bot)
	var hud: Node = load("res://scenes/ui/hud.tscn").instantiate()
	add_child(hud)
	var hint := hud._control_hint(Game.slots) as String
	_check(hint.begins_with(wasd.label) and hint.contains("Space"), "the HUD names P1's keys")
	_check(not hint.contains("Enter") and not hint.contains("stick"), "and nothing nobody is using")
	hud.queue_free()

	if not _failed:
		print("[controls] PASSED: printed labels per pad family, keyboard keys, joined-only prompts, per-player HUD")
	get_tree().quit(1 if _failed else 0)


func _slot(device: int, is_bot: bool) -> PlayerSlot:
	var slot := PlayerSlot.new()
	slot.device = device
	slot.is_bot = is_bot
	slot.dog = Game.dogs[0]
	return slot


func _check(ok: bool, message: String) -> void:
	if not ok:
		_failed = true
		push_error("[controls] FAILED: " + message)
