extends Control
## Choose mode, arena, toy and points-to-win, then start the match.
## Only playable content appears here; prototypes remain visible in the galleries.

var _mode_row: CarouselRow
var _arena_row: CarouselRow
var _toy_row: CarouselRow
var _points_row: CarouselRow
var _powerups_row: CarouselRow
var _start: Button
var _desc: Label
var _preview: TextureRect
var _playable_modes: Array[GameModeData] = []
var _playable_toys: Array[ToyData] = []

const POINT_OPTIONS := [3, 5, 7, 10]
## Holding treats back a round keeps the opening fight clean; starting them in round 1 makes
## power-ups part of the scramble from the first whistle.
const TREAT_OPTIONS := ["From round 2", "From the start", "Off"]


func _ready() -> void:
	Music.play("menu")
	UiKit.backdrop(self)
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
	root.add_theme_constant_override("separation", 14)
	add_child(root)

	root.add_child(UiKit.title("SET UP THE MATCH", 72, UiKit.ACCENT))
	root.add_child(UiKit.label("%d dogs ready to play" % Game.slots.size(), 24, Color(1, 1, 1, 0.7)))

	_mode_row = _row(root, "Mode", _playable_modes.map(func(m: GameModeData) -> String:
		return m.display_name), _playable_modes.find(Game.selected_mode))
	var arena_names: Array[String] = ["Shuffle every round"]
	for a in Game.arenas:
		arena_names.append(a.display_name)
	_arena_row = _row(root, "Arena", arena_names, 0 if Game.random_arena_each_round else Game.arenas.find(Game.selected_arena) + 1)
	_toy_row = _row(root, "Toy box", ["Mixed dog toys"] + _playable_toys.map(func(t: ToyData) -> String:
		return t.display_name), 0 if Game.mixed_toys else _playable_toys.find(Game.selected_toy) + 1)
	_powerups_row = _row(root, "Treats", TREAT_OPTIONS, _treat_option_index())
	_points_row = _row(root, "First to", POINT_OPTIONS.map(func(p: int) -> String: return "%d points" % p), maxi(POINT_OPTIONS.find(Game.points_to_win), 0))

	_preview = TextureRect.new()
	_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_preview.custom_minimum_size = Vector2(420, 172)
	var preview_box := CenterContainer.new()
	preview_box.add_child(_preview)
	root.add_child(preview_box)

	_desc = UiKit.label("", 22, Color(1, 1, 1, 0.75))
	_desc.custom_minimum_size = Vector2(900, 90)
	root.add_child(_desc)

	_start = UiKit.wood_button("FETCH!", 900)
	_start.pressed.connect(_on_start)
	root.add_child(_start)
	var back := UiKit.wood_button("Choose dogs", 900)
	back.pressed.connect(func() -> void: Game.goto(Game.SCENE_DOG_SELECT))
	root.add_child(back)

	_apply()
	_start.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		Game.goto(Game.SCENE_DOG_SELECT)


func _row(parent: Control, title: String, items: Array, start: int) -> CarouselRow:
	var row := CarouselRow.new()
	row.setup(title, PackedStringArray(items), start)
	row.changed.connect(func(_i: int) -> void: _apply())
	parent.add_child(row)
	return row


func _treat_option_index() -> int:
	if not Game.powerups_enabled:
		return 2
	return 1 if Game.treats_from_round <= 1 else 0


func _apply() -> void:
	Game.selected_mode = _playable_modes[_mode_row.index]
	Game.random_arena_each_round = _arena_row.index == 0
	if not Game.random_arena_each_round:
		Game.selected_arena = Game.arenas[_arena_row.index - 1]
	Game.mixed_toys = _toy_row.index == 0
	if not Game.mixed_toys:
		Game.selected_toy = _playable_toys[_toy_row.index - 1]
	Game.powerups_enabled = _powerups_row.index < 2
	Game.treats_from_round = 1 if _powerups_row.index == 1 else 2
	Game.points_to_win = POINT_OPTIONS[_points_row.index]
	# Shuffle has no single map to show, so the preview steps aside for it.
	if Game.random_arena_each_round:
		_preview.texture = null
		_preview.visible = false
	else:
		_preview.texture = Game.selected_arena.thumbnail
		_preview.visible = Game.selected_arena.thumbnail != null
	var where := "A different arena every round, drawn from all %d." % Game.arenas.size() if Game.random_arena_each_round else Game.selected_arena.description
	_desc.text = "%s\n%s  ·  %s" % [Game.selected_mode.description, where, ("Start empty-handed. Fetch a toy from the arena!" if Game.mixed_toys else Game.selected_toy.description)]
	var ok := Game.selected_mode.fully_implemented and Game.selected_mode.mode_script != null
	_start.text = "FETCH!" if ok else "That mode isn't built yet"
	_start.disabled = not ok


func _on_start() -> void:
	if Game.slots.is_empty():
		Game.debug_fill_players(2)
	Game.reset_scores()
	Game.goto(Game.SCENE_MATCH)
