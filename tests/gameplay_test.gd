extends Node
## Regression coverage for pause, one-way throws, round timeouts and live practice AI.
## godot --headless --path . res://tests/gameplay_test.tscn

var _failed := false
var _rounds := 0
var _last_winner: PlayerSlot
var _eliminations := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Sfx.enabled = DisplayServer.get_name() != "headless"
	seed(617)
	Game.mixed_toys = false
	Game.powerups_enabled = false
	Events.round_over.connect(func(winner: PlayerSlot) -> void:
		_rounds += 1
		_last_winner = winner)
	Events.dog_eliminated.connect(func(_dog: Node, _toy: Node) -> void: _eliminations += 1)
	_check_pause_events()
	_make_players(false)
	var game_match: Node = load("res://scenes/match/match.tscn").instantiate()
	add_child(game_match)
	await get_tree().create_timer(0.1).timeout
	game_match.set_paused(true)
	var countdown_text: String = game_match.hud.center.text
	await get_tree().create_timer(0.8, true).timeout
	_check(game_match.hud.center.text == countdown_text, "pause suspends countdown")
	game_match.set_paused(false)
	await _wait_for_play(game_match)
	game_match.set_paused(true)
	var frozen_time: float = game_match.round_time_left
	var frozen_position: Vector3 = game_match.dogs[0].global_position
	game_match.dogs[0].input.virtual_move = Vector2.RIGHT
	await get_tree().create_timer(0.4, true).timeout
	_check(is_equal_approx(game_match.round_time_left, frozen_time), "pause suspends round clock")
	_check(game_match.dogs[0].global_position == frozen_position, "pause suspends movement")
	game_match.dogs[0].input.virtual_move = Vector2.ZERO
	game_match.set_paused(false)

	var dog: Dog = game_match.dogs[0]
	var opponent: Dog = game_match.dogs[1]
	dog.global_position = Vector3(-4, 0, -3)
	opponent.global_position = Vector3(8, 0, 5)
	dog.facing = Vector3.RIGHT
	_check(dog.held_toy == null and opponent.held_toy == null, "round starts empty-handed")
	var toy: Toy = game_match.toys[0]
	# Opening toy placement is randomised per round, so park the rest well clear of the test
	# dog: only the thrown toy should be able to end up in its mouth.
	for other: Toy in game_match.toys:
		if other != toy:
			other.drop(Vector3(11.0, 0.0, 6.4))
	toy.pick_up(dog)
	dog._throw()
	_check(toy.state == Toy.State.FLYING and toy.thrower == dog, "a throw sends the toy out under its thrower")
	# A throw is one-way: holding throw must not bring the toy back. The toy is aimed
	# at the far wall, so it cannot bounce back within this window on its own either.
	dog.input.virtual_buttons[&"throw"] = true
	await get_tree().create_timer(1.1).timeout
	dog.input.virtual_buttons[&"throw"] = false
	_check(dog.held_toy != toy, "holding throw never returns your toy")
	_check(toy.holder == null, "a thrown toy stays out in the arena")
	# Whoever picks the toy up next owns it; the previous thrower keeps no claim.
	if opponent.held_toy:
		opponent.held_toy.drop(opponent.global_position)
	toy.pick_up(opponent)
	_check(toy.holder == opponent and toy.thrower == null, "pickup transfers toy ownership")
	game_match.round_time_left = 0.05
	await get_tree().create_timer(0.15).timeout
	_check(_rounds == 1 and _last_winner == null, "timeout announces a draw")
	_check(Game.slots[0].score == 0 and Game.slots[1].score == 0, "timeout awards no arbitrary points")
	game_match.queue_free()
	await get_tree().process_frame

	for arena in Game.arenas:
		Game.selected_arena = arena
		_make_players(true)
		_rounds = 0
		_eliminations = 0
		game_match = load("res://scenes/match/match.tscn").instantiate()
		add_child(game_match)
		var elapsed := 0.0
		while _rounds == 0 and elapsed < 35.0:
			await get_tree().create_timer(0.2).timeout
			elapsed += 0.2
		_check(_rounds > 0 and _last_winner != null, "bots finish a scored round in " + arena.display_name)
		_check(_eliminations >= 3, "bots throw, fetch and eliminate rivals in " + arena.display_name)
		print("[gameplay] bots: %s, %.1fs, %d eliminations" % [arena.display_name, elapsed, _eliminations])
		game_match.queue_free()
		await get_tree().process_frame
	if not _failed:
		print("[gameplay] PASSED: pause, one-way throws, fair timeout, bots in both arenas")
	get_tree().quit(1 if _failed else 0)


func _make_players(bots: bool) -> void:
	Game.clear_players()
	Game.points_to_win = 5
	for i in (4 if bots else 2):
		var slot := PlayerSlot.new()
		slot.index = i
		slot.device = DeviceInput.VIRTUAL
		slot.is_bot = bots
		slot.dog = Game.dogs[i]
		slot.ready = true
		Game.slots.append(slot)


func _wait_for_play(game_match: Node) -> void:
	while game_match.phase == game_match.Phase.COUNTDOWN:
		await get_tree().process_frame


func _check_pause_events() -> void:
	var escape := InputEventKey.new()
	escape.physical_keycode = KEY_ESCAPE
	escape.pressed = true
	_check(DeviceInput.is_pause_event(escape), "Escape pauses")
	var pad := InputEventJoypadButton.new()
	pad.pressed = true
	pad.button_index = JOY_BUTTON_START
	_check(DeviceInput.is_pause_event(pad), "Start pauses")
	pad.button_index = JOY_BUTTON_B
	_check(not DeviceInput.is_pause_event(pad), "B does not abandon a match")


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failed = true
		push_error("[gameplay] FAILED: " + message)
