extends Node
## Sides and who is allowed to hurt whom: teams, friendly fire, own goals — and the rule that a
## dog penned up for the tutorial cannot be dragged out of its pen by arena furniture.

var failed := false


func _ready() -> void:
	Sfx.enabled = false
	Music.enabled = false
	Game.tutorial_shown = true
	Game.powerups_enabled = false
	Game.random_arena_each_round = false
	Game.selected_arena = Game.arenas[0]
	_seat_four()

	# --- sides -------------------------------------------------------------------------
	Game.team_mode = false
	Game.assign_teams()
	for slot in Game.slots:
		_check(slot.team == -1, "a free-for-all puts nobody on a team")
	_check(not Game.slots[0].allied_with(Game.slots[1]), "in a free-for-all everyone is an opponent")
	_check(Game.slots[0].allied_with(Game.slots[0]), "you are always on your own side")

	Game.team_mode = true
	Game.assign_teams()
	_check(Game.slots[0].allied_with(Game.slots[2]), "seats 1 and 3 share a pack")
	_check(Game.slots[1].allied_with(Game.slots[3]), "seats 2 and 4 share a pack")
	_check(not Game.slots[0].allied_with(Game.slots[1]), "neighbouring seats are opponents")

	await _fire_rules()
	await _team_round_and_scoring()
	await _tutorial_furniture_is_inert()

	if not failed:
		print("[team-rules] PASSED: sides, friendly fire, own goals, team rounds and scoring, inert tutorial furniture")
	get_tree().quit(1 if failed else 0)


func _seat_four() -> void:
	Game.clear_players()
	for i in 4:
		var slot := PlayerSlot.new()
		slot.index = i
		slot.device = DeviceInput.VIRTUAL
		slot.dog = Game.dogs[i]
		Game.slots.append(slot)


func _check(ok: bool, message: String) -> void:
	if not ok:
		failed = true
		push_error("[team-rules] " + message)


func _open_match() -> Node:
	var game_match: Node = load("res://scenes/match/match.tscn").instantiate()
	add_child(game_match)
	await get_tree().physics_frame
	while game_match.phase != game_match.Phase.PLAYING:
		await get_tree().process_frame
	return game_match


## A toy only eliminates when the settings say the thrower is allowed to hurt that dog. The
## bounce still happens either way, so a blocked hit never looks like a missed one.
func _fire_rules() -> void:
	Game.team_mode = true
	Game.assign_teams()
	var game_match: Node = await _open_match()
	var victim: Dog = game_match.dogs[0]
	var mate: Dog = game_match.dogs[2]
	var foe: Dog = game_match.dogs[1]
	var toy: Toy = game_match.toys[0]
	toy.set_physics_process(false)
	toy.state = Toy.State.FLYING
	toy.velocity = Vector3(0, 0, 18.0)

	Game.friendly_fire = false
	toy.thrower = mate
	_check(not victim.can_be_hurt_by(toy), "with friendly fire off a team-mate's toy is harmless")
	Game.friendly_fire = true
	_check(victim.can_be_hurt_by(toy), "with friendly fire on a team-mate's toy counts")
	Game.friendly_fire = false

	toy.thrower = foe
	_check(victim.can_be_hurt_by(toy), "an opponent's toy always counts")

	toy.thrower = victim
	Game.self_fire = true
	_check(victim.can_be_hurt_by(toy), "with own goals on your own toy can get you")
	Game.self_fire = false
	_check(not victim.can_be_hurt_by(toy), "with own goals off your own toy cannot")
	Game.self_fire = true

	# And the whole path, not just the predicate: a blocked hit must leave the dog standing.
	Game.friendly_fire = false
	toy.thrower = mate
	toy.global_position = victim.global_position - Vector3(0, 0, 1.0) + Vector3(0, Toy.FLY_HEIGHT, 0)
	_check(not victim.hit_by(toy), "a team-mate's throw does not land")
	_check(victim.alive, "a team-mate cannot knock you out")
	game_match.queue_free()
	await get_tree().process_frame


## In teams the round runs until one pack is out, and the point goes on the pack's board rather
## than the individual's.
func _team_round_and_scoring() -> void:
	Game.team_mode = true
	Game.reset_scores()
	var game_match: Node = await _open_match()
	var mode: GameMode = game_match.mode
	var dogs: Array[Dog] = game_match.dogs
	# One dog down from a pack of two: their team-mate is still in, so the round continues.
	dogs[0].state = Dog.State.ELIMINATED
	_check(not mode.is_round_over(dogs), "a pack with one dog left is still fighting")
	dogs[2].state = Dog.State.ELIMINATED
	_check(mode.is_round_over(dogs), "the round ends when a whole pack is out")
	var winner: PlayerSlot = mode.round_winner(dogs)
	_check(winner != null and winner.team == 1, "the surviving pack wins the round")

	game_match.practice_round = false
	game_match.phase = game_match.Phase.ROUND_OVER
	game_match._end_round(winner)
	_check(Game.team_scores[1] == 1, "the point goes on the pack's board")
	_check(winner.score == 0, "a team point is not also an individual point")
	_check(Game.score_for(winner) == 1, "the pack's score is what counts towards the win")
	game_match.queue_free()
	await get_tree().process_frame
	Game.team_mode = false
	Game.assign_teams()


## The reported bug: a portal inside someone's practice pen warped them out, and a dog that
## cannot reach its own pad can never check in, so the match was stuck forever.
func _tutorial_furniture_is_inert() -> void:
	var warp: ArenaData = null
	for arena_data in Game.arenas:
		if arena_data.id == &"warp_yard":
			warp = arena_data
	_check(warp != null, "Warp Yard is available to test against")
	if warp == null:
		return
	Game.selected_arena = warp
	Game.tutorial_shown = false
	Game.reset_scores()
	var game_match: Node = load("res://scenes/match/match.tscn").instantiate()
	add_child(game_match)
	await get_tree().process_frame
	await get_tree().physics_frame
	_check(game_match.phase == game_match.Phase.TUTORIAL, "the practice round opens")
	var live := 0
	for node in game_match.arena.find_children("*", "Area3D", true, false):
		if node is Portal or node is SwitchPad:
			if (node as Area3D).monitoring:
				live += 1
	_check(live == 0, "no portal or switch is live while the pens are up")

	# Every dog must be inside its own pen and must stay there.
	var pens: Array = game_match.get("_pens")
	for i in pens.size():
		var pen: ReadyPen = pens[i]
		var dog: Dog = pen.dog
		var local: Vector3 = pen.to_local(dog.global_position)
		var half: Vector2 = pen._size * 0.5
		_check(absf(local.x) <= half.x and absf(local.z) <= half.y, "%s starts inside its pen" % dog.name)
	# Shove one out the way a portal did, and it should be put straight back.
	var stray: ReadyPen = pens[0]
	stray.dog.global_position = stray.global_position + Vector3(9.0, 0, 0)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var back: Vector3 = stray.to_local(stray.dog.global_position)
	var bounds: Vector2 = stray._size * 0.5
	_check(absf(back.x) <= bounds.x and absf(back.z) <= bounds.y, "a dog knocked out of its pen is put back")

	# Once everyone checks in the furniture comes back to life for the warm-up.
	for pen in pens:
		if is_instance_valid(pen):
			pen._set_ready()
	await get_tree().create_timer(1.4).timeout
	var woken := 0
	for node in game_match.arena.find_children("*", "Area3D", true, false):
		if node is Portal or node is SwitchPad:
			if (node as Area3D).monitoring:
				woken += 1
	_check(woken > 0, "portals and switches wake up once the pens drop")
	game_match.queue_free()
	await get_tree().process_frame
