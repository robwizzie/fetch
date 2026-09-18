extends Node
## Setting up a match and getting out of one, from a cabinet.
##
## Two things this guards. The setup screen must not throw seven carousels at a room that only
## wants to play, and the results screen has to report the score that actually decided the
## match — in teams that is the pack's board, and reading the player's own showed everyone on
## nil no matter who won.

var failed := false


func _ready() -> void:
	Sfx.enabled = false
	Music.enabled = false
	_seat_four()
	await _setup_hides_the_fiddly_bits()
	await _results_report_the_right_score()
	if not failed:
		print("[setup-flow] PASSED: essentials up front, options on request, team scores on the results board")
	get_tree().quit(1 if failed else 0)


func _seat_four() -> void:
	Game.clear_players()
	for i in 4:
		var slot := PlayerSlot.new()
		slot.index = i
		slot.device = DeviceInput.VIRTUAL
		slot.dog = Game.dogs[i]
		Game.slots.append(slot)


## Only the settings that change how the party plays are visible at rest; the rest are one
## button away and keep working once revealed.
func _setup_hides_the_fiddly_bits() -> void:
	var setup: Node = load("res://scenes/ui/match_setup.tscn").instantiate()
	add_child(setup)
	await get_tree().process_frame
	var more: VBoxContainer = setup.get("_more")
	_check(more != null, "the extra settings live in their own box")
	_check(not more.visible, "the extra settings start hidden")
	_check(more.get_child_count() >= 4, "arena, toy box, treats and fire are all in there")
	# The three that stay up front.
	for name in ["_mode_row", "_teams_row", "_points_row"]:
		var row: Control = setup.get(name)
		_check(row != null and row.visible, "%s is visible without asking" % name)
	# ...and none of the fiddly ones are.
	for name in ["_arena_row", "_toy_row", "_powerups_row", "_fire_row"]:
		var row: Control = setup.get(name)
		_check(row != null, "%s exists" % name)
		_check(not row.is_visible_in_tree(), "%s is tucked away" % name)

	setup._toggle_more()
	await get_tree().process_frame
	_check(more.visible, "asking for more options shows them")
	for name in ["_arena_row", "_toy_row", "_powerups_row", "_fire_row"]:
		var row: Control = setup.get(name)
		_check(row.is_visible_in_tree(), "%s is reachable once revealed" % name)
	setup._toggle_more()
	await get_tree().process_frame
	_check(not more.visible, "and they fold away again")

	# Whatever is chosen still lands on Game, revealed or not.
	setup._teams_row.index = 1
	setup._points_row.index = 0
	setup._apply()
	_check(Game.team_mode, "choosing two packs takes effect")
	_check(Game.points_to_win == 3, "choosing a target takes effect")
	setup.queue_free()
	await get_tree().process_frame


## The board a match was won on is the board the results screen shows.
func _results_report_the_right_score() -> void:
	Game.team_mode = true
	Game.assign_teams()
	Game.reset_scores()
	Game.team_scores = [4, 1]
	Game.last_match_winner = Game.slots[0]
	_check(Game.score_for(Game.slots[0]) == 4, "a pack member reads the pack's score")
	_check(Game.slots[0].score == 0, "and not their own, which teams never fills in")
	var results: Node = load("res://scenes/ui/results.tscn").instantiate()
	add_child(results)
	await get_tree().process_frame
	var shown := _labels(results)
	_check(_mentions(shown, "4 points"), "the winning pack's score is on the board")
	_check(_mentions(shown, Game.team_name(0)), "the winning pack is named")
	_check(not _mentions(shown, "0 points   ·   %s" % Game.team_name(0)), "no pack member is reported on nil")
	# Getting back out: again, change the settings, change the dogs, or leave.
	var buttons := _buttons(results)
	for want in ["Play Again", "Change Settings", "Change Dogs", "Back to Menu"]:
		_check(_mentions(buttons, want), "the results screen offers '%s'" % want)
	results.queue_free()
	await get_tree().process_frame
	Game.team_mode = false
	Game.assign_teams()


func _labels(node: Node) -> Array[String]:
	var out: Array[String] = []
	for child in node.find_children("*", "Label", true, false):
		out.append((child as Label).text)
	return out


func _buttons(node: Node) -> Array[String]:
	var out: Array[String] = []
	for child in node.find_children("*", "Button", true, false):
		out.append((child as Button).text)
	return out


func _mentions(haystack: Array[String], needle: String) -> bool:
	for entry in haystack:
		if entry.contains(needle):
			return true
	return false


func _check(ok: bool, message: String) -> void:
	if not ok:
		failed = true
		push_error("[setup-flow] " + message)
