extends Node
## Opening fairness, mixed loadouts and delayed arena treat lifecycle.

var failed := false


func _ready() -> void:
	Sfx.enabled = false
	# The arena loop asserts on a normal scored round; the practice round is covered on its own.
	Game.tutorial_shown = true
	Game.mixed_toys = true
	Game.powerups_enabled = true
	Game.clear_players()
	for i in 4:
		var slot := PlayerSlot.new()
		slot.index = i
		slot.device = DeviceInput.VIRTUAL
		slot.dog = Game.dogs[i]
		Game.slots.append(slot)
	for arena_data in Game.arenas:
		Game.selected_arena = arena_data
		var game_match: Node = load("res://scenes/match/match.tscn").instantiate()
		add_child(game_match)
		await get_tree().physics_frame
		_check(game_match.toys.size() == 6, "six arena toys")
		var kinds: Array[StringName] = []
		for toy: Toy in game_match.toys:
			kinds.append(toy.data.id)
			_check(game_match.arena.is_clear_position(toy.global_position, toy.data.radius + 0.2), "toy clears obstacles")
		_check(kinds.size() == 6 and kinds.count(kinds[0]) == 1, "mixed toy box uses distinct toys")
		# No toy is a free pickup, and no dog is meaningfully closer to the pile than the rest.
		var nearest: Array[float] = []
		for i in game_match.dogs.size():
			var dog: Dog = game_match.dogs[i]
			_check(dog.held_toy == null, "dogs start empty-handed")
			_check(game_match.arena.is_clear_position(dog.global_position, dog.data.body_radius + 0.2), "dog starts outside props")
			var closest := INF
			for toy: Toy in game_match.toys:
				var gap := Vector2(dog.position.x - toy.position.x, dog.position.z - toy.position.z).length()
				closest = minf(closest, gap)
			_check(closest >= game_match.MIN_TOY_SPAWN_DISTANCE - 0.9, "no toy starts in a dog's lap in " + arena_data.display_name)
			nearest.append(closest)
		var shortest: float = nearest.min()
		var longest: float = nearest.max()
		_check(longest - shortest <= 3.0, "opening run is comparable for every dog in " + arena_data.display_name)
		# Nobody should be able to learn the spots. Two consecutive draws landing close together is
		# ordinary luck, so this averages over several rounds' worth: what must not happen is a
		# layout that is fixed.
		var draws := 8
		var previous: Array[Vector3] = game_match._toy_spawn_points(6)
		var shifted := 0.0
		for _d in draws:
			var next: Array[Vector3] = game_match._toy_spawn_points(6)
			for i in previous.size():
				shifted += previous[i].distance_to(next[i])
			previous = next
		_check(shifted / float(previous.size() * draws) > 1.0, "toy placement is redrawn every round in " + arena_data.display_name)
		while game_match.phase == game_match.Phase.COUNTDOWN:
			await get_tree().process_frame
		game_match._treat_clock = 0.0
		await get_tree().physics_frame
		await get_tree().physics_frame
		_check(get_tree().get_nodes_in_group("powerups").is_empty(), "first round has no powerups")
		game_match.round_number = 2
		# Belts persist for the whole match, so each arena in this loop has to start clean or
		# it inherits whatever the previous one collected.
		for player in Game.slots:
			player.powerups.clear()
		game_match.dogs[0].apply_powerups()
		Game.powerups_enabled = false
		await get_tree().physics_frame
		_check(get_tree().get_nodes_in_group("powerups").is_empty(), "powerup setting is respected")
		Game.powerups_enabled = true
		await get_tree().physics_frame
		await get_tree().physics_frame
		var treats := get_tree().get_nodes_in_group("powerups")
		_check(treats.size() == 1, "one delayed treat spawns")
		var collected: StringName = &""
		if not treats.is_empty():
			var treat := treats[0] as Powerup
			_check(game_match.arena.is_clear_position(treat.position, 0.8), "treat clears obstacles")
			_check(PowerupKinds.ALL.has(treat.kind), "a crate holds one of the real power-ups")
			collected = treat.kind
			treat.age = 0.7
			game_match.dogs[0].global_position = treat.global_position
			await get_tree().physics_frame
			await get_tree().physics_frame
			var belt: Array[StringName] = game_match.dogs[0].slot.powerups
			_check(belt.size() == 1 and belt[0] == collected, "walking over a crate banks what was inside it")
			_check(get_tree().get_nodes_in_group("powerups").is_empty(), "a collected crate stops being collectable")
		game_match.start_round()
		await get_tree().process_frame
		# The whole point of the belt: a power-up is an investment across the match.
		_check(game_match.dogs[0].slot.powerups.has(collected), "power-ups carry into the next round")
		_check(game_match.dogs[0].powerup_status().contains(PowerupKinds.display_name(collected)), "the carried power-up shows in the HUD")
		_check(get_tree().get_nodes_in_group("powerups").is_empty(), "round clears old treats")
		game_match.queue_free()
		await get_tree().process_frame
	await _practice_round_is_free()
	if not failed:
		print("[match-rules] PASSED: empty starts, six toys, fair placement, delayed treats, collection, reset and a free practice round")
	get_tree().quit(1 if failed else 0)


func _check(ok: bool, message: String) -> void:
	if not ok:
		failed = true
		push_error("[match-rules] " + message)


## The practice round must cost nothing: no points, no round consumed, and the real round only
## starts once every pen has been stepped on. A regression here would quietly hand out a point.
func _practice_round_is_free() -> void:
	Game.tutorial_shown = false
	Game.random_arena_each_round = false
	Game.selected_arena = Game.arenas[0]
	Game.reset_scores()
	var game_match: Node = load("res://scenes/match/match.tscn").instantiate()
	add_child(game_match)
	await get_tree().process_frame
	await get_tree().physics_frame
	_check(game_match.phase == game_match.Phase.TUTORIAL, "a fresh session opens on the practice round")
	_check(game_match.round_number == 0, "the practice round does not consume a round")
	var pens: Array = game_match.get("_pens")
	_check(pens.size() == Game.slots.size(), "every player gets a pen")
	# Booths must not touch: there has to be open ground between every pair.
	var tightest := INF
	for i in pens.size():
		for j in range(i + 1, pens.size()):
			var a: Node3D = pens[i]
			var b: Node3D = pens[j]
			var apart := Vector2(a.global_position.x - b.global_position.x, a.global_position.z - b.global_position.z).length()
			tightest = minf(tightest, apart - 5.0)
	_check(tightest > 0.5, "practice booths are separated by open ground")
	# Nothing in a booth can put a dog out, not even a point-blank lethal throw.
	var victim: Dog = game_match.dogs[0]
	var practice_toy: Toy = game_match.toys[0]
	practice_toy.set_physics_process(false)
	practice_toy.state = Toy.State.FLYING
	practice_toy.thrower = game_match.dogs[1]
	practice_toy.global_position = victim.global_position - Vector3(0, 0, 1.2) + Vector3(0, Toy.FLY_HEIGHT, 0)
	practice_toy.velocity = Vector3(0, 0, 18.0)
	_check(not victim.hit_by(practice_toy), "a lethal throw in the booth does not land")
	_check(victim.alive, "nobody can be knocked out during practice")
	# Nobody is ready yet, so the match must still be waiting.
	await get_tree().create_timer(0.4).timeout
	_check(game_match.phase == game_match.Phase.TUTORIAL, "the match waits until everyone checks in")
	# The walls dropping IS the start of the warm-up: the same dogs play on from where they
	# stand. A respawn or a second countdown here would make it a separate round again.
	var before_ids: Array[int] = []
	for dog in game_match.dogs:
		before_ids.append(dog.get_instance_id())
	for pen in pens:
		if is_instance_valid(pen):
			pen._set_ready()
	await get_tree().create_timer(1.4).timeout
	_check(game_match.phase != game_match.Phase.TUTORIAL, "checking in drops the pens")
	_check(game_match.phase == game_match.Phase.PLAYING, "the walls dropping starts play, with no second countdown")
	var after_ids: Array[int] = []
	for dog in game_match.dogs:
		after_ids.append(dog.get_instance_id())
	_check(before_ids == after_ids, "the warm-up carries on with the same dogs, not respawned ones")
	# The warm-up is a real fight now: dogs can bonk each other out. It just is not a round.
	_check(game_match.practice_round, "a warm-up round runs once the pens open")
	_check(game_match.round_number == 0, "the warm-up does not consume a round")
	var total := 0
	for slot in Game.slots:
		total += slot.score
	_check(total == 0, "the warm-up scores nothing")
	# Everyone leaves the booths and is back in play for the real round.
	var still_safe := 0
	for dog in game_match.dogs:
		if is_instance_valid(dog) and dog.practice_safe:
			still_safe += 1
	_check(still_safe == 0, "practice safety is lifted once the walls drop")
	_check((game_match.get("_pens") as Array).is_empty(), "the booths are gone once the match starts")
	# Win the warm-up outright: the board must still read nil-nil afterwards, and the first
	# scored round begins only now.
	# The match sets ROUND_OVER before calling _end_round; _finish_round only acts in that phase.
	game_match.phase = game_match.Phase.ROUND_OVER
	game_match._end_round(Game.slots[0])
	game_match._finish_round()
	await get_tree().process_frame
	_check(not game_match.practice_round, "the warm-up hands over to the real match")
	_check(game_match.round_number == 1, "the first scored round is round 1")
	var after := 0
	for slot in Game.slots:
		after += slot.score
	_check(after == 0, "winning the warm-up is worth no points")
	game_match.queue_free()
	await get_tree().process_frame
