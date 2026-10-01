extends Control
## Choose mode, arena, toy and points-to-win, then start the match.
## Only playable content appears here; prototypes remain visible in the galleries.

var _mode_row: CarouselRow
var _arena_row: CarouselRow
var _toy_row: CarouselRow
var _points_row: CarouselRow
var _powerups_row: CarouselRow
var _teams_row: CarouselRow
var _scoring_row: CarouselRow
var _pack: HBoxContainer
var _rules: RichTextLabel
var _fire_row: CarouselRow
var _ghost_row: CarouselRow
var _more: VBoxContainer
var _more_button: Button
var _start: Button
var _desc: Label
var _preview: TextureRect
var _preview_frame: PanelContainer
var _shuffle_grid: GridContainer
## The two columns: the rules of the match, and the park.
const LEFT_WIDTH := 800.0
const RIGHT_WIDTH := 680.0
var _playable_modes: Array[GameModeData] = []
var _playable_toys: Array[ToyData] = []

const POINT_OPTIONS := [3, 5, 7, 10]
## A bonk goal is bigger than a round goal: several bonks happen every round.
const BONK_OPTIONS := [5, 10, 15, 20]
const DEFAULT_BONKS := 10
const SCORING_OPTIONS := ["Rounds won", "Bonks"]
## Where the carousel lands when the mode's default is not one of the options. Falling back to
## index 0 quietly turned every such match into a first-to-3.
const DEFAULT_POINTS := 5
## Auto is the party default: a brand new session gets a few clean rounds first, and every
## match after that opens with crates already dropping.
const TREAT_OPTIONS := ["Auto", "From the start", "From round 2", "Off"]
const SIDE_OPTIONS := ["Free-for-all", "Teams"]
## Who your own toys can hurt. Most groups want neither; the third is for people who enjoy pain.
const FIRE_OPTIONS := ["You", "Nobody", "You and pack-mates"]
## Free-for-all only: watch the rest of the round, or haunt it as a ghost.
const GHOST_OPTIONS := ["Watch", "Come back as a ghost"]


func _ready() -> void:
	Music.play("menu")
	UiKit.cover_backdrop(self, 0.72)
	for mode in Game.modes:
		if mode.fully_implemented and mode.mode_script != null:
			_playable_modes.append(mode)
	for toy in Game.toys:
		if toy.fully_implemented:
			_playable_toys.append(toy)
	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_CENTER)
	root.grow_horizontal = Control.GROW_DIRECTION_BOTH
	root.grow_vertical = Control.GROW_DIRECTION_BOTH
	root.alignment = BoxContainer.ALIGNMENT_CENTER
	root.add_theme_constant_override("separation", 12)
	add_child(root)

	root.add_child(UiKit.sign("SET UP THE MATCH", 46))
	_pack = HBoxContainer.new()
	_pack.alignment = BoxContainer.ALIGNMENT_CENTER
	_pack.add_theme_constant_override("separation", 14)
	root.add_child(_pack)

	# Two columns: how the match is won on the left, the park it is played in on the right.
	# One column of everything ran off the bottom of the screen once More options was open.
	var columns := HBoxContainer.new()
	columns.alignment = BoxContainer.ALIGNMENT_CENTER
	columns.add_theme_constant_override("separation", 30)
	root.add_child(columns)
	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(LEFT_WIDTH, 0)
	left.add_theme_constant_override("separation", 12)
	columns.add_child(left)
	var right := VBoxContainer.new()
	right.custom_minimum_size = Vector2(RIGHT_WIDTH, 0)
	right.add_theme_constant_override("separation", 12)
	columns.add_child(right)
	left.add_child(_column_heading("THE MATCH"))
	right.add_child(_column_heading("THE PARK"))

	# Seven carousels at once is a wall. Only the three that change how the party actually
	# plays are up front; everything else has a sensible default and waits behind a button
	# for the one person in the room who wants to fiddle with it.
	_mode_row = _row(left, "Mode", _playable_modes.map(func(m: GameModeData) -> String:
		return m.display_name), _playable_modes.find(Game.selected_mode))
	_teams_row = _row(left, "Teams", SIDE_OPTIONS, 1 if Game.team_mode else 0)
	_scoring_row = _row(left, "Win by", SCORING_OPTIONS, int(Game.scoring))
	_points_row = _row(left, "First to", [], 0)
	_fill_goal_row()

	# What the choices above actually mean, in plain words, kept up to date as they change.
	_rules = RichTextLabel.new()
	_rules.bbcode_enabled = true
	_rules.fit_content = true
	_rules.scroll_active = false
	_rules.custom_minimum_size = Vector2(LEFT_WIDTH - 44, 0)
	_rules.add_theme_font_override("normal_font", UiKit.FONT_UI)
	_rules.add_theme_font_override("bold_font", UiKit.FONT_DISPLAY)
	_rules.add_theme_font_size_override("normal_font_size", 21)
	_rules.add_theme_font_size_override("bold_font_size", 22)
	_rules.add_theme_color_override("default_color", Color(1, 1, 1, 0.85))
	var rules_box := PanelContainer.new()
	var rules_style := UiKit.panel_style(Color(UiKit.CREAM, 0.22), Color(0.03, 0.07, 0.05, 0.82))
	rules_style.set_border_width_all(2)
	rules_style.set_corner_radius_all(18)
	rules_style.content_margin_left = 22
	rules_style.content_margin_right = 22
	rules_box.add_theme_stylebox_override("panel", rules_style)
	rules_box.add_child(_rules)
	left.add_child(rules_box)

	# The arena on show until the extra options are asked for; then they take its place.
	_preview = TextureRect.new()
	_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_preview.custom_minimum_size = Vector2(RIGHT_WIDTH, 250)
	_preview_frame = PanelContainer.new()
	var frame_style := StyleBoxFlat.new()
	frame_style.bg_color = Color.WHITE
	frame_style.set_corner_radius_all(18)
	_preview_frame.add_theme_stylebox_override("panel", frame_style)
	_preview_frame.clip_children = CanvasItem.CLIP_CHILDREN_ONLY
	_preview_frame.add_child(_preview)
	right.add_child(_preview_frame)
	# Shuffling has no one picture: show the whole rotation instead.
	_shuffle_grid = GridContainer.new()
	_shuffle_grid.columns = 3
	_shuffle_grid.add_theme_constant_override("h_separation", 10)
	_shuffle_grid.add_theme_constant_override("v_separation", 10)
	for arena in Game.arenas:
		if arena.thumbnail == null:
			continue
		var cell := PanelContainer.new()
		var cell_style := StyleBoxFlat.new()
		cell_style.bg_color = Color.WHITE
		cell_style.set_corner_radius_all(12)
		cell.add_theme_stylebox_override("panel", cell_style)
		cell.clip_children = CanvasItem.CLIP_CHILDREN_ONLY
		var thumb := TextureRect.new()
		thumb.texture = arena.thumbnail
		thumb.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		thumb.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		thumb.custom_minimum_size = Vector2((RIGHT_WIDTH - 20.0) / 3.0, 118)
		cell.add_child(thumb)
		_shuffle_grid.add_child(cell)
	right.add_child(_shuffle_grid)
	_desc = UiKit.label("", 20, Color(1, 1, 1, 0.8))
	_desc.custom_minimum_size = Vector2(RIGHT_WIDTH, 0)
	right.add_child(_desc)

	_more_button = UiKit.wood_button("More options", 300, true)
	_more_button.pressed.connect(_toggle_more)
	var more_center := CenterContainer.new()
	more_center.add_child(_more_button)
	right.add_child(more_center)

	_more = VBoxContainer.new()
	_more.add_theme_constant_override("separation", 12)
	_more.visible = false
	right.add_child(_more)
	var arena_names: Array[String] = ["Shuffle every round"]
	for a in Game.arenas:
		arena_names.append(a.display_name)
	_arena_row = _row(_more, "Arena", arena_names, 0 if Game.random_arena_each_round else Game.arenas.find(Game.selected_arena) + 1)
	_toy_row = _row(_more, "Toy box", ["Mixed dog toys"] + _playable_toys.map(func(t: ToyData) -> String:
		return t.display_name), 0 if Game.mixed_toys else _playable_toys.find(Game.selected_toy) + 1)
	_powerups_row = _row(_more, "Treats", TREAT_OPTIONS, _treat_option_index())
	_fire_row = _row(_more, "Your toy can bonk", FIRE_OPTIONS, _fire_option_index())
	_ghost_row = _row(_more, "When you're out", GHOST_OPTIONS, 1 if Game.ghosts else 0)

	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 6)
	root.add_child(gap)
	# The way on is the big board; the way back sits beside it, smaller.
	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("separation", 18)
	root.add_child(actions)
	var back := UiKit.wood_button("Choose dogs", 280, true)
	back.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	back.pressed.connect(func() -> void: Game.goto(Game.SCENE_DOG_SELECT))
	actions.add_child(back)
	_start = UiKit.wood_button("FETCH!", 520)
	_start.custom_minimum_size.y = 76
	_start.add_theme_font_size_override("font_size", 38)
	_start.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_start.pressed.connect(_on_start)
	actions.add_child(_start)

	_apply()
	_start.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		Game.goto(Game.SCENE_DOG_SELECT)


func _row(parent: Control, title: String, items: Array, start: int) -> CarouselRow:
	var row := CarouselRow.new()
	row.setup(title, PackedStringArray(items), start)
	row.custom_minimum_size.x = parent.custom_minimum_size.x if parent.custom_minimum_size.x > 0.0 else RIGHT_WIDTH
	row.changed.connect(func(_i: int) -> void: _apply())
	parent.add_child(row)
	return row


## Bonks only make sense where the round is a fight to the last dog. A mode won some other way
## (a bed held, a golden ball kept) is always played for rounds.
func _bonks_allowed() -> bool:
	return Game.selected_mode != null and Game.selected_mode.id in [&"last_dog_standing", &"hot_potato"]


## The goal row counts rounds or bonks, whichever the match is played for.
func _fill_goal_row() -> void:
	var bonks := _scoring_row.index == 1 and _bonks_allowed()
	var options: Array = BONK_OPTIONS if bonks else POINT_OPTIONS
	var at := options.find(Game.points_to_win)
	if at < 0:
		at = options.find(DEFAULT_BONKS if bonks else DEFAULT_POINTS)
	var unit := "bonks" if bonks else "round wins"
	_points_row.setup("First to", PackedStringArray(options.map(func(n: int) -> String: return "%d %s" % [n, unit])), at)


## "You" is the default: your own ricochet can get you, a team-mate's cannot.
func _fire_option_index() -> int:
	if Game.friendly_fire:
		return 2
	return 0 if Game.self_fire else 1


## Reveals the rest of the settings. Kept as a plain toggle so a cabinet reaches it with the
## same button as everything else.
func _column_heading(text: String) -> Label:
	var label := UiKit.title(text, 26, UiKit.YELLOW)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	label.add_theme_constant_override("outline_size", 6)
	return label


func _toggle_more() -> void:
	_more.visible = not _more.visible
	_show_preview()
	_more_button.text = "Fewer options" if _more.visible else "More options"
	Sfx.play("ui_move")


func _treat_option_index() -> int:
	if not Game.powerups_enabled:
		return 3
	if Game.treats_from_round == Game.AUTO_TREATS:
		return 0
	return 1 if Game.treats_from_round <= 1 else 2


func _apply() -> void:
	Game.selected_mode = _playable_modes[_mode_row.index]
	Game.random_arena_each_round = _arena_row.index == 0
	if not Game.random_arena_each_round:
		Game.selected_arena = Game.arenas[_arena_row.index - 1]
	Game.mixed_toys = _toy_row.index == 0
	if not Game.mixed_toys:
		Game.selected_toy = _playable_toys[_toy_row.index - 1]
	Game.powerups_enabled = _powerups_row.index < 3
	match _powerups_row.index:
		1: Game.treats_from_round = 1
		2: Game.treats_from_round = 2
		_: Game.treats_from_round = Game.AUTO_TREATS
	var was_teams := Game.team_mode
	Game.team_mode = _teams_row.index == 1
	if Game.team_mode and not was_teams:
		for slot in Game.slots:
			slot.team = -1
	Game.assign_teams()
	Game.ghosts = _ghost_row.index == 1
	Game.self_fire = _fire_row.index != 1
	Game.friendly_fire = _fire_row.index == 2
	if not _bonks_allowed() and _scoring_row.index == 1:
		_scoring_row.setup("Win by", PackedStringArray(SCORING_OPTIONS), 0)
	var bonks := _scoring_row.index == 1
	var was := Game.scoring
	Game.scoring = Game.Scoring.BONKS if bonks else Game.Scoring.ROUNDS
	if was != Game.scoring or _points_row.items.is_empty():
		Game.points_to_win = DEFAULT_BONKS if bonks else DEFAULT_POINTS
		_fill_goal_row()
	Game.points_to_win = (BONK_OPTIONS if bonks else POINT_OPTIONS)[_points_row.index]
	_build_pack()
	_rules.text = _rules_text()
	# Shuffle has no single map to show, so the preview steps aside for it.
	if Game.random_arena_each_round:
		_preview.texture = null
	else:
		_preview.texture = Game.selected_arena.thumbnail
	_show_preview()
	var where := "A different arena every round, drawn from all %d." % Game.arenas.size() if Game.random_arena_each_round else Game.selected_arena.description
	_desc.text = "%s  ·  %s" % [where, ("Start empty-handed. Fetch a toy from the arena!" if Game.mixed_toys else Game.selected_toy.description)]
	var ok := Game.selected_mode.fully_implemented and Game.selected_mode.mode_script != null
	_start.text = "FETCH!" if ok else "That mode isn't built yet"
	if ok and not Game.teams_valid():
		ok = false
		_start.text = "Both packs need a dog - press a dog above to swap packs"
	_start.disabled = not ok


func _on_start() -> void:
	if Game.slots.is_empty():
		Game.debug_fill_players(2)
	Game.reset_scores()
	Game.goto(Game.SCENE_MATCH)


## What the current choices mean, in plain words: how a round is won, who is on whose side and
## what that changes, and how the match is won.
func _rules_text() -> String:
	var lines: Array[String] = []
	lines.append("[b]%s[/b]  %s" % [Game.selected_mode.display_name.to_upper(), Game.selected_mode.description])
	if Game.team_mode:
		var counts := [0, 0]
		for slot in Game.slots:
			if slot.team >= 0:
				counts[slot.team] += 1
		lines.append("[b]TEAMS  %d v %d[/b]  Press a dog above to swap its pack. A pack-mate's throw is a [b]pass[/b] - your toys never bonk each other - and you can [b]revive[/b] a downed pack-mate by standing in their ring." % counts)
	else:
		lines.append("[b]FREE-FOR-ALL[/b]  Every dog for itself.")
	if Game.scoring == Game.Scoring.BONKS:
		lines.append("[b]WIN BY BONKS[/b]  Every rival you bonk is a point; bonk yourself with your own toy and you lose one. Rounds keep coming until someone reaches %d." % Game.points_to_win)
	else:
		lines.append("[b]WIN BY ROUNDS[/b]  The last %s standing wins the round; first to %d round wins takes the match." % ["pack" if Game.team_mode else "dog", Game.points_to_win])
	if not _bonks_allowed():
		lines.append("[i]This mode is always played for rounds.[/i]")
	if Game.ghosts and not Game.team_mode:
		lines.append("[b]GHOSTS[/b]  Knocked out? Float back in as a ghost: bark to spook a dog into a stumble, throw to nudge a loose toy.")
	return "\n".join(lines)


## The pack along the top. In a team match each dog is a button: press it to swap its pack.
func _build_pack() -> void:
	for child in _pack.get_children():
		_pack.remove_child(child)
		child.queue_free()
	for i in Game.slots.size():
		var slot := Game.slots[i]
		var tint: Color = Game.team_color(slot.team) if Game.team_mode and slot.team >= 0 else slot.color
		var card := Button.new()
		card.flat = true
		card.focus_mode = Control.FOCUS_ALL if Game.team_mode else Control.FOCUS_NONE
		card.mouse_filter = Control.MOUSE_FILTER_STOP if Game.team_mode else Control.MOUSE_FILTER_IGNORE
		card.custom_minimum_size = Vector2(150, 0)
		var frame := PanelContainer.new()
		frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		frame.set_anchors_preset(Control.PRESET_FULL_RECT)
		frame.add_theme_stylebox_override("panel", UiKit.panel_style(tint, Color(slot.dog.card_color, 0.9)))
		card.add_child(frame)
		var column := VBoxContainer.new()
		column.mouse_filter = Control.MOUSE_FILTER_IGNORE
		column.add_theme_constant_override("separation", 2)
		frame.add_child(column)
		column.add_child(UiKit.dog_portrait(slot.dog, slot.dog.card_color, Vector2(120, 96), 1.0, 0.0, true))
		var tag := UiKit.chip(Game.team_name(slot.team) if Game.team_mode and slot.team >= 0 else slot.label, tint, 15)
		tag.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		column.add_child(tag)
		card.custom_minimum_size = Vector2(150, 150)
		if Game.team_mode:
			card.pressed.connect(func() -> void:
				slot.team = 1 - slot.team
				Sfx.play("ui_move")
				_apply()
				# The row was rebuilt: keep a controller's focus on the dog just swapped.
				(_pack.get_child(i) as Control).grab_focus())
		_pack.add_child(card)


## The arena picture shows while there is room for it: one arena chosen, extra options folded.
## Shuffling every round has no single picture, so the line under it says so instead.
func _show_preview() -> void:
	if _preview_frame == null:
		return
	_preview_frame.visible = _preview.texture != null and not _more.visible
	_shuffle_grid.visible = Game.random_arena_each_round and not _more.visible
