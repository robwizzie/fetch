extends Control
## Match over: winner, standings, play again or back to the menu.


func _ready() -> void:
	Music.play("victory")
	UiKit.backdrop(self)
	var winner := Game.last_match_winner
	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_CENTER)
	root.grow_horizontal = Control.GROW_DIRECTION_BOTH
	root.grow_vertical = Control.GROW_DIRECTION_BOTH
	root.alignment = BoxContainer.ALIGNMENT_CENTER
	root.add_theme_constant_override("separation", 16)
	add_child(root)

	root.add_child(UiKit.title("MATCH RESULTS", 34, Color(1, 1, 1, 0.6)))
	if winner:
		root.add_child(UiKit.title("%s WINS!" % winner.dog.display_name.to_upper(), 120, winner.dog.card_color))
		root.add_child(UiKit.dog_portrait(winner.dog, winner.color, Vector2(460, 320), 1.0, 0.6))
	else:
		root.add_child(UiKit.title("GAME OVER", 110, UiKit.ACCENT))

	var standings := Game.slots.duplicate()
	standings.sort_custom(func(a: PlayerSlot, b: PlayerSlot) -> bool: return a.score > b.score)
	var table := VBoxContainer.new()
	table.add_theme_constant_override("separation", 6)
	root.add_child(table)
	var place := 1
	for s in standings:
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", 14)
		row.add_child(UiKit.title("%d" % place, 34, UiKit.YELLOW if place == 1 else Color(1, 1, 1, 0.6)))
		row.add_child(UiKit.chip(s.label, s.color, 20))
		var l := UiKit.label("%s   ·   %d %s" % [s.dog.display_name, s.score, "point" if s.score == 1 else "points"], 28, UiKit.CREAM)
		l.autowrap_mode = TextServer.AUTOWRAP_OFF
		row.add_child(l)
		table.add_child(row)
		place += 1

	var again := UiKit.button("Play Again")
	again.pressed.connect(func() -> void:
		Game.reset_scores()
		Game.goto(Game.SCENE_MATCH))
	root.add_child(again)
	var change := UiKit.button("Change Dogs / Arena")
	change.pressed.connect(func() -> void: Game.goto(Game.SCENE_DOG_SELECT))
	root.add_child(change)
	var menu := UiKit.button("Back to Menu")
	menu.pressed.connect(func() -> void: Game.goto(Game.SCENE_MAIN_MENU))
	root.add_child(menu)
	again.grab_focus()
	Sfx.play("fanfare")
