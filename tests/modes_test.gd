extends Node
## Hot Potato Bone and King of the Bed: the rules, and bots actually finishing rounds of each.
##   godot --headless --path . res://tests/modes_test.tscn

var _failed := false
var _rounds := 0
var _last_winner: PlayerSlot


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Sfx.enabled = false
	Game.tutorial_shown = true
	Game.powerups_enabled = false
	Game.random_arena_each_round = false
	Game.mixed_toys = false
	Game.selected_arena = Game.arenas[0]
	Events.round_over.connect(func(winner: PlayerSlot) -> void:
		_rounds += 1
		_last_winner = winner)
	_check(_mode(&"hot_potato") != null and _mode(&"king_of_the_bed") != null and _mode(&"golden_ball") != null, "the modes are registered")
	for mode in Game.modes:
		_check(mode.fully_implemented and mode.mode_script != null, "%s is playable - unfinished modes stay shelved" % mode.id)
	await _hot_potato_rules()
	await _bed_rules()
	await _golden_rules()
	for id in [&"hot_potato", &"king_of_the_bed", &"golden_ball"]:
		await _bots_finish(id)
	if not _failed:
		print("[modes] PASSED: hot bone pops its holder, bed counts only alone, golden ball banks for its holder, bots finish all three")
	get_tree().quit(1 if _failed else 0)


func _mode(id: StringName) -> GameModeData:
	for m in Game.modes:
		if m.id == id:
			return m
	return null


func _start(id: StringName, bots: bool) -> Node:
	Game.selected_mode = _mode(id)
	Game.clear_players()
	Game.points_to_win = 5
	for i in 4:
		var slot := PlayerSlot.new()
		slot.index = i
		slot.device = DeviceInput.VIRTUAL
		slot.is_bot = bots
		slot.dog = Game.dogs[i]
		slot.ready = true
		Game.slots.append(slot)
	_rounds = 0
	_last_winner = null
	var game_match: Node = load("res://scenes/match/match.tscn").instantiate()
	add_child(game_match)
	return game_match


func _until_playing(game_match: Node) -> void:
	while game_match.phase != game_match.Phase.PLAYING:
		await get_tree().process_frame
	await get_tree().physics_frame


func _hot_potato_rules() -> void:
	var game_match := _start(&"hot_potato", false)
	await _until_playing(game_match)
	var mode := game_match.mode as HotPotato
	_check(is_instance_valid(mode.hot), "a hot bone is chosen")
	var holder: Dog = game_match.dogs[1]
	holder._spawn_grace = 0.0
	mode.hot.pick_up(holder)
	mode.fuse = 0.05
	for i in 6:
		await get_tree().physics_frame
	_check(not holder.alive, "when it pops, the dog holding the hot bone is out")
	_check(game_match.dogs[0].alive and game_match.dogs[2].alive, "and nobody else")
	_check(mode.fuse > HotPotato.FUSE_MIN - 1.0, "a fresh fuse starts")
	game_match.queue_free()
	await get_tree().process_frame


func _bed_rules() -> void:
	var game_match := _start(&"king_of_the_bed", false)
	await _until_playing(game_match)
	var mode := game_match.mode as KingOfTheBed
	var dogs: Array[Dog] = game_match.dogs
	for dog in dogs:
		dog.set_physics_process(false)
		dog.global_position = Vector3(20, 0, 20)
	dogs[0].global_position = mode.bed_centre
	_check(mode.holder(dogs) == dogs[0].slot, "a dog alone on the bed holds it")
	dogs[1].global_position = mode.bed_centre + Vector3(0.5, 0, 0)
	_check(mode.holder(dogs) == null, "two rivals on the bed contest it")
	dogs[1].global_position = Vector3(20, 0, 20)
	mode.tick(3.0, dogs)
	_check(mode.timeout_winner(dogs) == dogs[0].slot, "at time-up, the most bed time wins")
	mode.tick(KingOfTheBed.CLAIM_TIME, dogs)
	_check(mode.is_round_over(dogs) and mode.round_winner(dogs) == dogs[0].slot, "holding it long enough takes the round")
	game_match.queue_free()
	await get_tree().process_frame


func _golden_rules() -> void:
	var game_match := _start(&"golden_ball", false)
	await _until_playing(game_match)
	var mode := game_match.mode as GoldenBall
	var dogs: Array[Dog] = game_match.dogs
	_check(is_instance_valid(mode.golden), "a golden ball is chosen")
	_check(mode.holder() == null, "nobody holds it at the whistle")
	dogs[2]._spawn_grace = 0.0
	mode.golden.pick_up(dogs[2])
	_check(mode.holder() == dogs[2].slot, "picking it up makes you the holder")
	mode.tick(3.0, dogs)
	_check(mode.timeout_winner(dogs) == dogs[2].slot, "at time-up, the most golden time wins")
	_check(mode.bot_keeps(dogs[2], mode.golden), "a bot hangs on to the golden ball")
	mode.tick(GoldenBall.CLAIM_TIME, dogs)
	_check(mode.is_round_over(dogs) and mode.round_winner(dogs) == dogs[2].slot, "holding it long enough takes the round")
	game_match.queue_free()
	await get_tree().process_frame


func _bots_finish(id: StringName) -> void:
	var game_match := _start(id, true)
	var elapsed := 0.0
	while _last_winner == null and elapsed < 70.0:
		await get_tree().create_timer(0.2).timeout
		elapsed += 0.2
	_check(_last_winner != null, "bots finish a decided round of %s" % id)
	print("[modes] %s: %.1fs, %d rounds" % [id, elapsed, _rounds])
	game_match.queue_free()
	await get_tree().process_frame


func _check(ok: bool, message: String) -> void:
	if not ok:
		_failed = true
		push_error("[modes] FAILED: " + message)
