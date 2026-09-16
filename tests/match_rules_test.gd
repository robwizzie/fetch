extends Node
## Opening fairness, mixed loadouts and delayed arena treat lifecycle.

var failed := false


func _ready() -> void:
	Sfx.enabled = false
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
		# Nobody should be able to learn the spots: two draws must not land in the same places.
		var first: Array[Vector3] = game_match._toy_spawn_points(6)
		var second: Array[Vector3] = game_match._toy_spawn_points(6)
		var shifted := 0.0
		for i in first.size():
			shifted += first[i].distance_to(second[i])
		_check(shifted / float(first.size()) > 1.0, "toy placement is redrawn every round in " + arena_data.display_name)
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
	if not failed:
		print("[match-rules] PASSED: empty starts, six toys, fair placement, delayed treats, collection and reset")
	get_tree().quit(1 if failed else 0)


func _check(ok: bool, message: String) -> void:
	if not ok:
		failed = true
		push_error("[match-rules] " + message)
