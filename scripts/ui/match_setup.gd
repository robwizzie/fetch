extends Control
## Choose mode, arena, toy and points-to-win, then start the match.
## Modes/toys that aren't fully implemented are selectable so they're visible, but Start explains why not.

var _mode_row: CarouselRow
var _arena_row: CarouselRow
var _toy_row: CarouselRow
var _points_row: CarouselRow
var _start: Button
var _desc: Label

const POINT_OPTIONS := [3, 5, 7, 10]


func _ready() -> void:
	UiKit.backdrop(self)
	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_CENTER)
	root.grow_horizontal = Control.GROW_DIRECTION_BOTH
	root.grow_vertical = Control.GROW_DIRECTION_BOTH
	root.alignment = BoxContainer.ALIGNMENT_CENTER
	root.add_theme_constant_override("separation", 14)
	add_child(root)

	root.add_child(UiKit.title("SET UP THE MATCH", 72, UiKit.ACCENT))
	root.add_child(UiKit.label("%d dogs ready to play" % Game.slots.size(), 24, Color(1, 1, 1, 0.7)))

	_mode_row = _row(root, "Mode", Game.modes.map(func(m: GameModeData) -> String:
		return m.display_name + ("" if m.fully_implemented else "  (coming soon)")), Game.modes.find(Game.selected_mode))
	_arena_row = _row(root, "Arena", Game.arenas.map(func(a: ArenaData) -> String: return a.display_name), Game.arenas.find(Game.selected_arena))
	_toy_row = _row(root, "Toy", Game.toys.map(func(t: ToyData) -> String:
		return t.display_name + ("" if t.fully_implemented else "  (prototype)")), Game.toys.find(Game.selected_toy))
	_points_row = _row(root, "First to", POINT_OPTIONS.map(func(p: int) -> String: return "%d points" % p), maxi(POINT_OPTIONS.find(Game.points_to_win), 0))

	_desc = UiKit.label("", 22, Color(1, 1, 1, 0.75))
	_desc.custom_minimum_size = Vector2(900, 90)
	root.add_child(_desc)

	_start = UiKit.button("FETCH!", 900)
	_start.pressed.connect(_on_start)
	root.add_child(_start)
	var back := UiKit.button("Back", 900)
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


func _apply() -> void:
	Game.selected_mode = Game.modes[_mode_row.index]
	Game.selected_arena = Game.arenas[_arena_row.index]
	Game.selected_toy = Game.toys[_toy_row.index]
	Game.points_to_win = POINT_OPTIONS[_points_row.index]
	_desc.text = "%s\n%s  ·  %s" % [Game.selected_mode.description, Game.selected_arena.description, Game.selected_toy.description]
	var ok := Game.selected_mode.fully_implemented and Game.selected_mode.mode_script != null
	_start.text = "FETCH!" if ok else "That mode isn't built yet"
	_start.disabled = not ok


func _on_start() -> void:
	if Game.slots.is_empty():
		Game.debug_fill_players(2)
	Game.reset_scores()
	Game.goto(Game.SCENE_MATCH)
