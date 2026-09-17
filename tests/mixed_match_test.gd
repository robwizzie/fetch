extends Node
## Full mixed-bag practice matches with real BotBrain input, including round two.
## godot --headless --path . res://tests/mixed_match_test.tscn

const ARENA_TIMEOUT := 120.0

var _failed := false
var _game_match: Node
var _records: Array[Dictionary] = []
var _scores_before: Array[int] = []
var _scored_rounds := 0
var _draws := 0
var _eliminations := 0
var _opening_round := 0
var _max_treat_count := 0
var _buff_seen := false


func _ready() -> void:
	# These suites assert on a normal scored round, so skip the one-off practice round.
	Game.tutorial_shown = true
	process_mode = Node.PROCESS_MODE_ALWAYS
	Sfx.enabled = false
	Game.mixed_toys = true
	Game.powerups_enabled = true
	Game.selected_mode = load("res://data/modes/01_last_dog_standing.tres")
	Events.round_over.connect(_on_round_over)
	Events.dog_eliminated.connect(func(_dog: Node, _toy: Node) -> void: _eliminations += 1)
	await get_tree().process_frame
	for arena_index in Game.arenas.size():
		await _run_arena(arena_index)
	if not _failed:
		print("[mixed-match] PASSED: four bots, mixed weapons, two scored rounds per arena, score locks and final-KO presentation")
	get_tree().quit(1 if _failed else 0)


func _run_arena(arena_index: int) -> void:
	seed(617 + arena_index * 17)
	Game.clear_players()
	Game.points_to_win = 99 # Keep this harness as current_scene; never navigate to results.
	for i in 4:
		var slot := PlayerSlot.new()
		slot.index = i
		slot.device = DeviceInput.VIRTUAL
		slot.is_bot = true
		slot.dog = Game.dogs[i]
		slot.ready = true
		Game.slots.append(slot)
	Game.selected_arena = Game.arenas[arena_index]
	_records.clear()
	_scores_before = [0, 0, 0, 0]
	_scored_rounds = 0
	_draws = 0
	_eliminations = 0
	_opening_round = 0
	_max_treat_count = 0
	_buff_seen = false
	_game_match = load("res://scenes/match/match.tscn").instantiate()
	add_child(_game_match)
	var started := Time.get_ticks_msec()
	var validated := 0
	while float(Time.get_ticks_msec() - started) / 1000.0 < ARENA_TIMEOUT and validated < 2:
		await get_tree().process_frame
		_inspect_live_match()
		if not _records.is_empty():
			var record: Dictionary = _records.pop_front()
			if record.winner != null:
				await _verify_celebration(record)
				validated += 1
	var elapsed := float(Time.get_ticks_msec() - started) / 1000.0
	var arena_name: String = Game.selected_arena.display_name
	_check(_scored_rounds >= 2 and validated >= 2, "two naturally scored rounds in " + arena_name)
	_check(_eliminations >= 6, "real combat produces six eliminations in " + arena_name)
	_check(_sum_scores() == _scored_rounds, "one total point per scored round in " + arena_name)
	print("[mixed-match] %s: %.1fs, %d scored rounds, %d draws, %d KOs, up to %d treats, buff=%s" % [arena_name, elapsed, _scored_rounds, _draws, _eliminations, _max_treat_count, _buff_seen])
	_game_match.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	_game_match = null
	_check(is_equal_approx(Engine.time_scale, 1.0), "arena teardown restores normal time")


func _inspect_live_match() -> void:
	if _opening_round != _game_match.round_number:
		_opening_round = _game_match.round_number
		var kinds: Dictionary = {}
		for toy in _game_match.toys:
			kinds[toy.data.resource_path] = true
		_check(kinds.size() >= 4, "mixed bag places at least four weapon kinds")
		for dog in _game_match.dogs:
			_check(dog.held_toy == null, "new-round dogs start empty")
	_max_treat_count = maxi(_max_treat_count, _game_match._treat_count)
	if _game_match.round_number == 1:
		_check(_game_match._treat_count == 0, "treats wait until later rounds")
	for dog in _game_match.dogs:
		_buff_seen = _buff_seen or (dog.slot != null and not dog.slot.powerups.is_empty())


func _on_round_over(winner: PlayerSlot) -> void:
	if not is_instance_valid(_game_match):
		return
	var scores: Array[int] = []
	for slot in Game.slots:
		scores.append(slot.score)
		var expected := 1 if slot == winner else 0
		_check(slot.score - _scores_before[slot.index] == expected, "only round winner receives one point")
	_scores_before = scores.duplicate()
	if winner:
		_scored_rounds += 1
	else:
		_draws += 1
	_records.append({"winner": winner, "scores": scores, "round": _game_match.round_number})


func _verify_celebration(record: Dictionary) -> void:
	# Let deferred collision/physics updates finish after the actual hit callback.
	await get_tree().process_frame
	await get_tree().process_frame
	var camera: ArenaCamera = _game_match.arena.get_node("Camera")
	_check(camera._final_focus and camera._focus_left > 0.0, "final KO gets a camera highlight")
	_check(Engine.time_scale < 1.0, "final KO enters slow motion")
	_check(_game_match.phase == _game_match.Phase.ROUND_OVER, "round result locks before celebration")
	var winner_dog: Dog
	for dog in _game_match.dogs:
		_check(dog.round_locked, "all dogs lock during celebration")
		if dog.slot == record.winner:
			winner_dog = dog
	for toy in _game_match.toys:
		_check(not toy.is_physics_processing(), "weapon physics stops after final KO")
		_check(toy.is_processing(), "weapon render attachment still processes")
	_check(winner_dog != null and winner_dog.alive, "winner remains alive")
	var held := winner_dog.held_toy
	if held == null:
		# Combat is complete. Exercise the held victory pose even when the final
		# attack left the winner empty-handed; no combat or score outcome is altered.
		for toy in _game_match.toys:
			if toy.state == Toy.State.IDLE:
				held = toy
				held.pick_up(winner_dog)
				break
	_check(held != null, "celebration has a held-weapon attachment to verify")
	_check(not winner_dog.hit_by(_game_match.toys[0]), "post-result impacts cannot eliminate winner")
	await get_tree().create_timer(0.3, true, false, true).timeout
	if held:
		_check(held.state == Toy.State.HELD and not held.is_physics_processing() and held.is_processing(), "HELD state keeps render processing while physics is stopped")
		_check(held.global_position.distance_to(winner_dog.get_hold_position()) < 0.04, "held item follows animated mouth during victory")
	await get_tree().create_timer(0.65, true, false, true).timeout
	_check(is_equal_approx(Engine.time_scale, 1.0), "final KO slow motion recovers before next countdown")
	_check(camera._focus_left == 0.0, "final KO camera emphasis expires")
	for slot in Game.slots:
		_check(slot.score == record.scores[slot.index], "celebration cannot award extra points")
	_check(_game_match.round_number == record.round, "celebration remains visible before new round")


func _sum_scores() -> int:
	var total := 0
	for slot in Game.slots:
		total += slot.score
	return total


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failed = true
		push_error("[mixed-match] FAILED: " + message)
