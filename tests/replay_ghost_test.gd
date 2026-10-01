extends Node
## The final-bonk replay and free-for-all ghosts.
##   godot --headless --path . res://tests/replay_ghost_test.tscn

var _failed := false


func _ready() -> void:
	Sfx.enabled = false
	Music.enabled = false
	Game.tutorial_shown = true
	Game.powerups_enabled = false
	Game.random_arena_each_round = false
	Game.selected_arena = Game.arenas[0]
	Game.team_mode = false
	Game.scoring = Game.Scoring.ROUNDS
	Game.points_to_win = 5
	await _replay()
	await _ghosts()
	Game.ghosts = false
	Game.replays = true
	if not _failed:
		print("[replay-ghost] PASSED: a deciding knockout replays and can be skipped; ghosts haunt, spook and nudge, and only when switched on")
	get_tree().quit(1 if _failed else 0)


func _seat(count: int) -> void:
	Game.clear_players()
	for i in count:
		var slot := PlayerSlot.new()
		slot.index = i
		slot.device = DeviceInput.VIRTUAL
		slot.dog = Game.dogs[i]
		Game.slots.append(slot)
	Game.reset_scores()


func _start() -> Node:
	var game_match: Node = load("res://scenes/match/match.tscn").instantiate()
	add_child(game_match)
	return game_match


func _until_playing(game_match: Node) -> void:
	while game_match.phase != game_match.Phase.PLAYING:
		await get_tree().process_frame
	for dog in game_match.dogs:
		dog._spawn_grace = 0.0


func _replay() -> void:
	Game.replays = true
	_seat(2)
	var game_match := _start()
	await _until_playing(game_match)
	# Let a little of the round be recorded, then decide it with a knockout.
	await get_tree().create_timer(0.6).timeout
	var toy: Toy = game_match.toys[0]
	toy.set_physics_process(false)
	toy.thrower = game_match.dogs[0]
	toy.velocity = Vector3(10, 0, 0)
	game_match.dogs[1].eliminate(toy)
	var waited := 0.0
	while not game_match.replay.is_playing() and waited < 4.0:
		await get_tree().process_frame
		waited += get_process_delta_time()
	_check(game_match.replay.is_playing(), "the knockout that won the round is replayed")
	_check(Engine.time_scale < 1.0, "in slow motion")
	_check(not game_match.actors.visible, "with the real dogs out of the way")
	_check(game_match.replay._puppets.size() == 2, "re-run by stand-ins for every dog")
	game_match.replay.skip()
	await get_tree().process_frame
	_check(not game_match.replay.is_playing() and game_match.actors.visible, "and can be skipped")
	_check(is_equal_approx(Engine.time_scale, 1.0), "skipping puts the game back to full speed")
	game_match.queue_free()
	await get_tree().process_frame


func _ghosts() -> void:
	Game.replays = false
	for on in [false, true]:
		Game.ghosts = on
		_seat(3)
		var game_match := _start()
		await _until_playing(game_match)
		var out: Dog = game_match.dogs[0]
		var toy: Toy = game_match.toys[0]
		toy.set_physics_process(false)
		toy.thrower = game_match.dogs[1]
		out.eliminate(toy)
		await get_tree().create_timer(1.6).timeout
		var ghosts := get_tree().get_nodes_in_group(&"ghosts")
		if not on:
			_check(ghosts.is_empty(), "no ghosts unless they are switched on")
		else:
			_check(ghosts.size() == 1, "a knocked-out player comes back as a ghost")
			if ghosts.size() == 1:
				var ghost := ghosts[0] as GhostDog
				var near: Dog = game_match.dogs[2]
				near.set_physics_process(false)
				near.global_position = ghost.global_position + Vector3(1.0, 0, 0)
				ghost._spook()
				_check(near._stagger_time > 0.0 and near.alive, "BOO! startles a dog without knocking it out")
				var loose: Toy = game_match.toys[1]
				loose.state = Toy.State.IDLE
				loose.global_position = ghost.global_position + Vector3(0, loose.global_position.y, 0.8)
				ghost.facing = Vector3.RIGHT
				ghost._nudge()
				_check(loose.velocity.length() > 1.0 and loose.state == Toy.State.IDLE, "a nudge slides a loose toy but never makes it dangerous")
		game_match.queue_free()
		await get_tree().process_frame


func _check(ok: bool, message: String) -> void:
	if not ok:
		_failed = true
		push_error("[replay-ghost] FAILED: " + message)
