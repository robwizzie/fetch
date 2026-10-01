extends Node
## Hats, how they are earned, and the moments that earn them: lifetime stats unlock hats at their
## thresholds, unlocks survive a restart, the match calls out its great knockouts, and two
## players can never be the same dog.
##   godot --headless --path . res://tests/progress_test.tscn

var _failed := false


func _ready() -> void:
	Sfx.enabled = false
	Music.enabled = false
	_check(Progress.path != Progress.DEFAULT_PATH, "tests never write to the real profile")
	Progress.reset()
	_hats()
	await _highlights()
	await _bark()
	await _no_twins()
	Progress.reset()
	if not _failed:
		print("[progress] PASSED: hats unlock at their thresholds and persist, callouts spot great knockouts, barking, no twin dogs, CPU levels")
	get_tree().quit(1 if _failed else 0)


func _hats() -> void:
	_check(Game.hats.size() >= 9, "the hat cupboard is stocked")
	var starters := Progress.unlocked_hats()
	_check(starters.size() >= 1 and starters.all(func(h: HatData) -> bool: return h.stat == &""), "only the free hats are open on a fresh profile")
	var beanie := Game.hat(&"propeller_beanie")
	_check(beanie != null and not Progress.is_unlocked(beanie), "the propeller beanie starts locked")
	Progress.record(&"bank_bonks", 9)
	_check(not Progress.is_unlocked(beanie), "nine bank-shot bonks are not quite enough")
	Progress.record(&"bank_bonks")
	_check(Progress.is_unlocked(beanie), "ten are")
	_check(Progress.fresh_unlocks.has(beanie), "and it is waiting to be shown off on the results screen")
	var top_hat := Game.hat(&"top_hat")
	for dog in Game.dogs:
		Progress.record_win_with(dog)
		Progress.record_win_with(dog)
	_check(Progress.is_unlocked(top_hat), "winning with every dog earns the top hat")
	Progress.save_progress()
	Progress.load_progress()
	_check(Progress.is_unlocked(beanie) and Progress.is_unlocked(top_hat), "unlocks survive a restart")
	var model := DogModel.new()
	add_child(model)
	model.setup(Game.dogs[0], Color.WHITE)
	model.set_hat(beanie)
	_check(is_instance_valid(model._hat) and model._hat.get_parent() == model.head_top_anchor(), "a worn hat rides the head")
	model.queue_free()


func _match(bots: bool) -> Node:
	Game.tutorial_shown = true
	Game.random_arena_each_round = false
	Game.selected_arena = Game.arenas[0]
	Game.clear_players()
	for i in 3:
		var slot := PlayerSlot.new()
		slot.index = i
		slot.device = DeviceInput.VIRTUAL
		slot.is_bot = bots
		slot.dog = Game.dogs[i]
		Game.slots.append(slot)
	var game_match: Node = load("res://scenes/match/match.tscn").instantiate()
	add_child(game_match)
	return game_match


func _highlights() -> void:
	var game_match := _match(false)
	while game_match.phase != game_match.Phase.PLAYING:
		await get_tree().process_frame
	var dogs: Array[Dog] = game_match.dogs
	for dog in dogs:
		dog.set_physics_process(false)
		dog._spawn_grace = 0.0
	var seen: Array[StringName] = []
	Events.highlight.connect(func(kind: StringName, _by: PlayerSlot, _victim: PlayerSlot) -> void: seen.append(kind))
	var spotter := Highlights.new()
	# A wall bounce on the way in is a bank shot.
	var toy: Toy = game_match.toys[0]
	toy.thrower = dogs[0]
	toy.bounces = 1
	_check(spotter.classify(dogs[1], toy, dogs[0], false) == &"bank", "a knockout off a wall is a bank shot")
	# The next one straight after is a double.
	_check(spotter.classify(dogs[2], toy, dogs[0], false) == &"double", "two in a moment is a double")
	# Getting back at whoever got you is revenge.
	toy.bounces = 0
	var later := Highlights.new()
	later.classify(dogs[0], toy, dogs[1], false)
	_check(later.classify(dogs[1], toy, dogs[0], false) == &"revenge", "bonking whoever bonked you is revenge")
	# Catching a toy and putting its thrower out with it.
	var sender := Highlights.new()
	toy.caught_from = dogs[2]
	_check(sender.classify(dogs[2], toy, dogs[0], false) == &"return", "catch it and send it back: return to sender")
	toy.caught_from = null
	_check(Highlights.new().classify(dogs[1], null, null, true) == &"sky", "a sudden-death drop is a sky bonk")
	# And through the match for real: a knockout off a wall gets called out and counted.
	var before := Progress.stat(&"bank_bonks")
	toy.thrower = dogs[0]
	toy.bounces = 1
	dogs[1].eliminate(toy)
	await get_tree().process_frame
	_check(seen.has(&"bank"), "the match calls out the bank shot")
	_check(Progress.stat(&"bank_bonks") == before + 1, "and counts it towards the propeller beanie")
	_check(is_instance_valid(game_match.hud._callout), "with big text on screen")
	game_match.queue_free()
	await get_tree().process_frame


func _bark() -> void:
	var game_match := _match(false)
	while game_match.phase != game_match.Phase.PLAYING:
		await get_tree().process_frame
	var dog: Dog = game_match.dogs[0]
	var barks: Array[int] = [0]
	Events.dog_barked.connect(func(_d: Node) -> void: barks[0] += 1)
	dog.input.virtual_buttons[&"bark"] = true
	await get_tree().process_frame
	dog.input.virtual_buttons[&"bark"] = false
	await get_tree().process_frame
	_check(barks[0] == 1, "the bark button barks")
	dog.bark()
	_check(barks[0] == 1, "and not again straight away")
	_check(not DeviceInput.glyph(&"bark", DeviceInput.KEYBOARD_WASD).is_empty() and not DeviceInput.pad_glyph(&"bark", DeviceInput.PadFamily.XBOX).is_empty(), "every layout has a bark button")
	game_match.queue_free()
	await get_tree().process_frame


## Two players never the same dog; a CPU gives way; CPU levels and hats cycle on the seats.
func _no_twins() -> void:
	Game.clear_players()
	var lobby: Node = load("res://scenes/ui/dog_select.tscn").instantiate()
	add_child(lobby)
	await get_tree().process_frame
	var one := Game.add_player(DeviceInput.VIRTUAL)
	lobby._inputs[one] = DeviceInput.new(DeviceInput.VIRTUAL)
	var two := Game.add_player(DeviceInput.KEYBOARD_ARROWS)
	lobby._inputs[two] = DeviceInput.new(DeviceInput.KEYBOARD_ARROWS)
	_check(one.dog != two.dog, "players who sit down start on different dogs")
	lobby._refresh_all()
	lobby._pick(one, 1)
	lobby._pick(two, 1)
	_check(one.dog == Game.dogs[1] and one.ready, "the first to pick a dog gets it")
	_check(not two.ready or two.dog != Game.dogs[1], "the second player cannot have it too")
	lobby._add_bot(2)
	var cpu: PlayerSlot = lobby._slot_for_index(2)
	var cpu_dog := cpu.dog
	lobby._pick(two, Game.dogs.find(cpu_dog))
	_check(two.dog == cpu_dog and two.ready, "a player can take a CPU's dog")
	_check(cpu.dog != cpu_dog and cpu.dog != one.dog, "and the CPU moves over to a free one")
	lobby._cycle(cpu, 1)
	var dogs_in_use: Array = Game.slots.map(func(s: PlayerSlot) -> DogData: return s.dog)
	_check(dogs_in_use.size() == Game.slots.size() and dogs_in_use.filter(func(d: DogData) -> bool: return dogs_in_use.count(d) > 1).is_empty(), "changing a CPU's dog never lands on someone else's")
	var level := cpu.cpu_level
	lobby._cycle_level(cpu)
	_check(cpu.cpu_level == (level + 1) % 3, "a CPU's seat cycles its difficulty")
	lobby._cycle_hat(one)
	_check(one.hat != &"" and Progress.is_unlocked(Game.hat(one.hat)), "a player can put on a hat they have earned")
	lobby.queue_free()
	await get_tree().process_frame


func _check(ok: bool, message: String) -> void:
	if not ok:
		_failed = true
		push_error("[progress] FAILED: " + message)
