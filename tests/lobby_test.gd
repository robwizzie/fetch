extends Node
## Managing the pack from a panel with no mouse and no keyboard.
##
## On a cabinet the stick is the only input whose meaning is certain — an unmapped encoder
## reports raw button indices, so "button A" names nothing in particular — which is why adding
## and removing CPUs lives on up/down rather than on a button.

var failed := false
var lobby: Node


func _ready() -> void:
	Sfx.enabled = false
	Music.enabled = false
	Game.clear_players()
	lobby = load("res://scenes/ui/dog_select.tscn").instantiate()
	add_child(lobby)
	await get_tree().process_frame

	# One human sits down. Everything after this is done from their stick alone.
	var human := Game.add_player(DeviceInput.VIRTUAL)
	human.dog = Game.dogs[0]
	lobby._inputs[human] = DeviceInput.new(DeviceInput.VIRTUAL)
	lobby._refresh_all()
	await get_tree().process_frame
	_check(Game.slots.size() == 1, "a player can sit down")

	await _push(human, Vector2.UP)
	_check(Game.slots.size() == 2, "up seats a CPU")
	_check(Game.slots[1].is_bot, "the new seat is a CPU")
	_check(Game.slots[1].ready, "a CPU is ready without being asked")

	await _push(human, Vector2.UP)
	await _push(human, Vector2.UP)
	_check(Game.slots.size() == Game.MAX_PLAYERS, "the pack fills to four")
	await _push(human, Vector2.UP)
	_check(Game.slots.size() == Game.MAX_PLAYERS, "a full pack takes no more")

	await _push(human, Vector2.DOWN)
	_check(Game.slots.size() == 3, "down sends a CPU home")
	await _push(human, Vector2.DOWN)
	await _push(human, Vector2.DOWN)
	_check(Game.slots.size() == 1, "every CPU can be sent home")
	# The human who is doing the pushing must survive it.
	_check(Game.slots[0] == human and not Game.slots[0].is_bot, "down never removes a human")
	await _push(human, Vector2.DOWN)
	_check(Game.slots.size() == 1, "down on a lobby with no CPUs does nothing")

	# A second human joining must not be mistaken for a CPU, and CPUs must fill around them.
	var second := Game.add_player(DeviceInput.KEYBOARD_ARROWS)
	second.dog = Game.dogs[1]
	lobby._inputs[second] = DeviceInput.new(DeviceInput.KEYBOARD_ARROWS)
	lobby._refresh_all()
	await _push(human, Vector2.UP)
	_check(Game.slots.size() == 3, "a CPU fills the seat next to two humans")
	var humans := 0
	for slot in Game.slots:
		if not slot.is_bot:
			humans += 1
	_check(humans == 2, "both humans are still seated")
	await _push(human, Vector2.DOWN)
	await _push(human, Vector2.DOWN)
	_check(Game.slots.size() == 2, "sending CPUs home leaves the humans alone")

	_check_join_wording()

	if not failed:
		print("[lobby] PASSED: stick-driven CPUs, humans protected, cabinet join wording")
	get_tree().quit(1 if failed else 0)


## One flick of the stick and back to centre, which is what just_pressed needs to see.
func _push(slot: PlayerSlot, direction: Vector2) -> void:
	var inp: DeviceInput = lobby._inputs[slot]
	inp.virtual_move = direction
	await get_tree().process_frame
	await get_tree().process_frame
	inp.virtual_move = Vector2.ZERO
	await get_tree().process_frame


## A cabinet has no Space and no Enter, so the prompts must not offer them.
func _check_join_wording() -> void:
	Game.arcade_hints = Game.ArcadeHints.ALWAYS
	var arcade: String = lobby._join_wording()
	_check(not arcade.contains("Space") and not arcade.contains("Enter"),
		"cabinet prompts do not mention keys a cabinet does not have")
	Game.arcade_hints = Game.ArcadeHints.NEVER
	var desk: String = lobby._join_wording()
	_check(desk.contains("Space") or desk.contains("Enter"), "a desktop still gets its keys named")
	Game.arcade_hints = Game.ArcadeHints.AUTO


func _check(ok: bool, message: String) -> void:
	if not ok:
		failed = true
		push_error("[lobby] " + message)
