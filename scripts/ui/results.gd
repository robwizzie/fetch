extends Control
## Match over: the whole pack on a podium in 3D (see PodiumStage), a card under each dog with
## its points and its match, and the ways out along the bottom.

const CARD_WIDTH := 300.0

var _stage: PodiumStage
var _view: SubViewport
var _cards: Array[Control] = []


func _ready() -> void:
	Music.play("victory")
	var winner := Game.last_match_winner
	var standings := _standings()

	var frame := SubViewportContainer.new()
	frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	frame.stretch = true
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(frame)
	_view = SubViewport.new()
	_view.own_world_3d = true
	_view.msaa_3d = Viewport.MSAA_4X
	frame.add_child(_view)
	_stage = PodiumStage.new()
	_view.add_child(_stage)
	_stage.build(standings)
	_stage.camera.make_current()

	var heading := VBoxContainer.new()
	heading.set_anchors_preset(Control.PRESET_CENTER_TOP)
	heading.grow_horizontal = Control.GROW_DIRECTION_BOTH
	heading.offset_top = 22
	heading.alignment = BoxContainer.ALIGNMENT_BEGIN
	heading.add_theme_constant_override("separation", 0)
	heading.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(heading)
	heading.add_child(UiKit.title("BEST IN SHOW", 34, Color(1, 1, 1, 0.7)))
	if winner:
		# In teams the pack won, not the dog that happened to be left standing.
		if Game.team_mode and winner.team >= 0:
			heading.add_child(UiKit.title("%s WINS!" % Game.team_name(winner.team), 104, Game.team_color(winner.team)))
		else:
			heading.add_child(UiKit.title("%s WINS!" % winner.dog.display_name.to_upper(), 112, winner.dog.card_color))
		heading.add_child(UiKit.label(DogTalk.match_brag(), 26, UiKit.CREAM))
	else:
		heading.add_child(UiKit.title("ALL TUCKERED OUT", 96, UiKit.ACCENT))

	var awards := _awards(standings)
	for i in standings.size():
		var card := _card(standings[i], awards.get(standings[i].slot, ""))
		add_child(card)
		_cards.append(card)

	var actions := HBoxContainer.new()
	actions.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	actions.grow_horizontal = Control.GROW_DIRECTION_BOTH
	actions.grow_vertical = Control.GROW_DIRECTION_BEGIN
	actions.offset_bottom = -30
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("separation", 18)
	add_child(actions)
	var again := UiKit.wood_button("Play Again", 330)
	again.pressed.connect(func() -> void:
		Game.reset_scores()
		Game.goto(Game.SCENE_MATCH))
	# Three separate exits, because "again" and "change something" are different wants and a
	# cabinet should not make you walk back through the whole menu to reach either.
	var settings := UiKit.button("Change Settings", 300)
	settings.pressed.connect(func() -> void: Game.goto(Game.SCENE_MATCH_SETUP))
	var change := UiKit.button("Change Dogs", 260)
	change.pressed.connect(func() -> void: Game.goto(Game.SCENE_DOG_SELECT))
	var menu := UiKit.button("Back to Menu", 260)
	menu.pressed.connect(func() -> void: Game.goto(Game.SCENE_MAIN_MENU))
	var buttons: Array[Button] = [again, settings, change, menu]
	for button in buttons:
		actions.add_child(button)
	for i in buttons.size():
		buttons[i].focus_neighbor_left = buttons[i].get_path_to(buttons[wrapi(i - 1, 0, buttons.size())])
		buttons[i].focus_neighbor_right = buttons[i].get_path_to(buttons[(i + 1) % buttons.size()])
	again.grab_focus()
	Sfx.play("fanfare")
	# Players are still mashing from the last round board: hold the buttons a beat so nobody
	# restarts the match before they have seen who won.
	for button in buttons:
		button.disabled = true
	await get_tree().create_timer(0.6).timeout
	for button in buttons:
		if is_instance_valid(button):
			button.disabled = false


## Hangs each card under the front of its podium, wherever the window's shape puts it.
func _process(_delta: float) -> void:
	if _stage == null or _stage.camera == null:
		return
	var scale_to_screen := size / Vector2(_view.size).max(Vector2.ONE)
	for i in _cards.size():
		var card := _cards[i]
		var anchor := _stage.camera.unproject_position(_stage.card_anchor(i)) * scale_to_screen
		card.position = Vector2(anchor.x - card.size.x * 0.5, anchor.y + 14.0)


## Every dog, best first, with its placing. Dogs level on points share a placing - a pack shares
## its pack's score, so a winning pack stands on the top step together.
func _standings() -> Array:
	var slots := Game.slots.duplicate()
	# score_for reads the pack's board in teams and the player's own otherwise; sorting on
	# slot.score alone showed every player on nil in a team match.
	slots.sort_custom(func(a: PlayerSlot, b: PlayerSlot) -> bool:
		if Game.score_for(a) != Game.score_for(b):
			return Game.score_for(a) > Game.score_for(b)
		return a.index < b.index)
	var out: Array = []
	for slot in slots:
		var place := 1
		for other in slots:
			if Game.score_for(other) > Game.score_for(slot):
				place += 1
		var color: Color = Game.team_color(slot.team) if Game.team_mode and slot.team >= 0 else slot.color
		out.append({"slot": slot, "place": place, "color": color})
	return out


## One standout per dog, where the match gave it one: who bonked the most, who caught the most,
## who spent the most time in the doghouse. Ties win nothing - an award is for the one dog.
func _awards(standings: Array) -> Dictionary:
	var awards := {}
	var categories := [
		["knockouts", "TOP BONKER"],
		["catches", "SAFE PAWS"],
		["bonked", "NAP CHAMPION"],
	]
	for category in categories:
		var field: String = category[0]
		var best: PlayerSlot = null
		var best_value := 0
		var tied := false
		for entry in standings:
			var slot: PlayerSlot = entry.slot
			var value: int = slot.get(field)
			if value > best_value:
				best = slot
				best_value = value
				tied = false
			elif value == best_value and value > 0:
				tied = true
		if best != null and not tied and not awards.has(best):
			awards[best] = category[1]
	for i in standings.size():
		var slot: PlayerSlot = standings[i].slot
		if not awards.has(slot):
			awards[slot] = DogTalk.placing(standings[i].place, standings.size())
	return awards


func _card(entry: Dictionary, award: String) -> Control:
	var slot: PlayerSlot = entry.slot
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(CARD_WIDTH, 0)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_theme_stylebox_override("panel", UiKit.panel_style(entry.color, Color(0.07, 0.12, 0.09, 0.9)))
	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 2)
	card.add_child(column)
	column.add_child(UiKit.title(award, 24, UiKit.YELLOW if entry.place == 1 else UiKit.CREAM))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	row.add_child(UiKit.chip(slot.label, slot.color, 18))
	var points: int = Game.score_for(slot)
	var side := "  ·  %s" % Game.team_name(slot.team) if Game.team_mode and slot.team >= 0 else ""
	var name_line := UiKit.label("%s  ·  %d %s%s" % [slot.dog.display_name, points, "point" if points == 1 else "points", side], 22, UiKit.CREAM)
	name_line.autowrap_mode = TextServer.AUTOWRAP_OFF
	row.add_child(name_line)
	column.add_child(row)
	var story := UiKit.label("%d %s  ·  %d %s" % [slot.knockouts, "bonk" if slot.knockouts == 1 else "bonks",
		slot.catches, "catch" if slot.catches == 1 else "catches"], 18, Color(1, 1, 1, 0.65))
	story.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(story)
	return card
