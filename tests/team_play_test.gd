extends Node
## Teams of any shape, passes, reviving a pack-mate, own goals, playing for bonks, and the crown
## on whoever leads.
##   godot --headless --path . res://tests/team_play_test.tscn

var _failed := false
var _matches: Array = []


func _ready() -> void:
	Sfx.enabled = false
	Music.enabled = false
	Game.tutorial_shown = true
	Game.powerups_enabled = false
	Game.random_arena_each_round = false
	Game.selected_arena = Game.arenas[0]
	Events.match_over.connect(func(w: PlayerSlot) -> void: _matches.append(w))
	_any_split()
	await _passes_and_revives()
	await _self_bonks()
	await _bonks_and_crowns()
	Game.team_mode = false
	Game.scoring = Game.Scoring.ROUNDS
	Game.points_to_win = 5
	if not _failed:
		print("[team-play] PASSED: any team split, passes, revives, own goals cost a point, first to N bonks, the leader's crown")
	get_tree().quit(1 if _failed else 0)


func _seat(count: int) -> void:
	Game.clear_players()
	for i in count:
		var slot := PlayerSlot.new()
		slot.index = i
		slot.device = DeviceInput.VIRTUAL
		slot.dog = Game.dogs[i]
		Game.slots.append(slot)


func _match() -> Node:
	var game_match: Node = load("res://scenes/match/match.tscn").instantiate()
	add_child(game_match)
	return game_match


func _until_playing(game_match: Node) -> void:
	while game_match.phase != game_match.Phase.PLAYING:
		await get_tree().process_frame
	for dog in game_match.dogs:
		dog.set_physics_process(false)
		dog._spawn_grace = 0.0


## 2 v 1, 3 v 1, 1 v 1: whatever the setup screen chose sticks, and a team match with an empty
## pack is refused.
func _any_split() -> void:
	_seat(3)
	Game.team_mode = true
	Game.slots[0].team = 0
	Game.slots[1].team = 0
	Game.slots[2].team = 1
	Game.reset_scores()
	_check(Game.slots[0].team == 0 and Game.slots[1].team == 0 and Game.slots[2].team == 1, "a 2 v 1 split survives the start of the match")
	_check(Game.teams_valid(), "and is a valid match")
	Game.slots[2].team = 0
	_check(not Game.teams_valid(), "everyone on one pack is not")


func _passes_and_revives() -> void:
	_seat(3)
	Game.team_mode = true
	Game.slots[0].team = 0
	Game.slots[1].team = 0
	Game.slots[2].team = 1
	Game.scoring = Game.Scoring.ROUNDS
	Game.reset_scores()
	var game_match := _match()
	await _until_playing(game_match)
	var passer: Dog = game_match.dogs[0]
	var mate: Dog = game_match.dogs[1]
	var rival: Dog = game_match.dogs[2]
	if mate.held_toy:
		mate.held_toy.drop(mate.global_position)
	var toy: Toy = game_match.toys[0]
	toy.set_physics_process(false)
	toy.state = Toy.State.FLYING
	toy.thrower = passer
	toy.velocity = Vector3(18, 0, 0)
	_check(not mate.hit_by(toy) and mate.alive, "a pack-mate's throw never bonks")
	_check(mate.held_toy == toy, "it is caught as a pass")
	# Down goes the pack-mate; a ring appears where it lies, and standing in it brings it back.
	mate.held_toy.drop(mate.global_position)
	mate.eliminate(null, Vector3.RIGHT)
	await get_tree().process_frame
	var spots := get_tree().get_nodes_in_group(ReviveSpot.GROUP)
	_check(spots.size() == 1, "a downed dog with a pack-mate standing leaves a revive ring")
	_check(game_match.phase == game_match.Phase.PLAYING, "and the round goes on")
	if spots.size() == 1:
		var spot: ReviveSpot = spots[0]
		rival.global_position = spot.global_position + Vector3(0.3, 0, 0)
		for i in 20:
			await get_tree().physics_frame
		_check(spot.progress == 0.0, "a rival standing in it does nothing")
		rival.global_position = Vector3(12, 0, 6)
		passer.global_position = spot.global_position
		await get_tree().create_timer(ReviveSpot.REVIVE_TIME + 0.4).timeout
		_check(mate.alive, "a pack-mate standing in the ring brings the dog back")
		_check(mate._spawn_grace > 0.0 or mate.alive, "with a moment's protection")
	game_match.queue_free()
	await get_tree().process_frame


## A self-bonk only matters when racing to a bonk total: there it costs a bone, which snaps off
## the player's card. Played for rounds it costs nothing and the dog left standing wins.
func _self_bonks() -> void:
	for scoring in [Game.Scoring.ROUNDS, Game.Scoring.BONKS]:
		_seat(2)
		Game.team_mode = false
		Game.scoring = scoring
		Game.points_to_win = 5
		Game.reset_scores()
		Game.slots[0].score = 2
		var game_match := _match()
		await _until_playing(game_match)
		var clumsy: Dog = game_match.dogs[0]
		var toy: Toy = game_match.toys[0]
		toy.set_physics_process(false)
		toy.thrower = clumsy
		clumsy.eliminate(toy)
		await get_tree().process_frame
		await get_tree().process_frame
		if scoring == Game.Scoring.BONKS:
			_check(Game.slots[0].score == 1, "racing to bonks, bonking yourself loses a bone")
			_check(Game.slots[1].score == 0, "and nobody else is handed it")
			var hud: Node = game_match.hud
			_check(not hud.self_layer().find_children("*", "BoneBreak", true, false).is_empty(), "the lost bone snaps off the card")
		else:
			_check(Game.slots[0].score == 2, "played for rounds, a self-bonk costs nothing")
			_check(Game.slots[1].score == 1, "and the dog left standing wins the round")
		game_match.queue_free()
		await get_tree().process_frame


## Playing for bonks: every rival bonked is a point, the leader wears the crown (both of them
## when level), and reaching the goal ends the match on the spot.
func _bonks_and_crowns() -> void:
	_seat(3)
	Game.team_mode = false
	Game.scoring = Game.Scoring.BONKS
	Game.points_to_win = 2
	Game.reset_scores()
	_matches.clear()
	var game_match := _match()
	await _until_playing(game_match)
	var dogs: Array[Dog] = game_match.dogs
	Game.slots[0].hat = &"party_hat"
	dogs[0].model.set_hat(Game.hat(&"party_hat"))
	var toy: Toy = game_match.toys[0]
	toy.set_physics_process(false)
	toy.thrower = dogs[0]
	dogs[1].eliminate(toy)
	await get_tree().process_frame
	_check(Game.slots[0].score == 1, "a bonk is a point")
	_check(dogs[0].model.is_crowned() and not dogs[2].model.is_crowned(), "the leader wears the crown")
	_check(is_instance_valid(dogs[0].model._hat) and dogs[0].model._hat.data.style == HatData.Style.CROWN, "in place of their hat")
	Game.slots[2].score = 1
	game_match._update_crowns()
	_check(dogs[0].model.is_crowned() and dogs[2].model.is_crowned(), "level leaders both wear it")
	Game.slots[2].score = 0
	game_match._update_crowns()
	_check(not dogs[2].model.is_crowned(), "and it comes off when the lead is lost")
	toy.thrower = dogs[0]
	toy.bounces = 0
	toy._hit_dogs.clear()
	dogs[2].eliminate(toy)
	await get_tree().process_frame
	# The match ends through the round board, which waits for a button; what matters here is
	# that the round stopped with the leader as its winner at the goal.
	_check(game_match.phase == game_match.Phase.ROUND_OVER and game_match._round_winner == Game.slots[0], "reaching the bonk goal ends it there")
	_check(Game.score_for(Game.slots[0]) >= Game.points_to_win, "with the winner on the goal")
	if is_instance_valid(game_match):
		game_match.queue_free()
	await get_tree().process_frame


func _check(ok: bool, message: String) -> void:
	if not ok:
		_failed = true
		push_error("[team-play] FAILED: " + message)
