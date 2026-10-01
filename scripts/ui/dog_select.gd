extends Control
## "Choose your dog", laid out the way Smash does it, because everybody already knows how that
## screen works:
##
## - The whole pack in a grid across the top. Every human has a cursor in their colour; hovering
##   a dog shows it on your seat, confirm locks it in and leaves your token on it. The grid sizes
##   its tiles to the pack: a handful of dogs get big showcase cards, a big pack gets rows of
##   smaller ones, and a pack too big for even that scrolls a row at a time under the cursor.
## - A seat per player along the bottom. An empty seat says how to join and has an ADD CPU
##   button; a CPU's seat has CHANGE and REMOVE. Your cursor drops down onto those - adding and
##   removing CPUs is something you can see and point at, not a hidden stick gesture.
## - When everyone has picked, a READY TO PLAY banner, and confirm goes on.
##
## Back undoes a pick; back again gives up your seat. Each seat polls its own DeviceInput, so
## any mix of pads and keyboards works, and everything also works with the mouse.

const MIN_PLAYERS := 2
const PANEL := Vector2(418, 380)
## Roster grid and seat row, for the cursors. On the roster a cursor's col is the tile index;
## its grid row and column come from the layout, so picking code never has to know the shape.
const ROSTER := 0
const SEATS := 1
## The space the roster grid gets, between the title and the ready banner.
const GRID_AREA := Rect2(70, 106, 1780, 390)
## The biggest a tile gets: a five-dog pack should look like a showcase, not a spreadsheet.
const TILE_MAX := Vector2(280, 345)
## Tall cards suit big tiles; small ones go squarer, because the name strip does not shrink with
## the art and a tall thin tile ends up mostly label.
const ASPECT_BIG := 232.0 / 286.0
const ASPECT_SMALL := 1.0
const MAX_COLUMNS := 10
## Below three rows the tiles stop being readable from the sofa, so past that the grid scrolls.
const MAX_VISIBLE_ROWS := 3
const GAP := 14.0

var _inputs: Dictionary = {}
var _continue: Button
var _footer: Label
var _tiles: Array[Control] = []
var _panels: Array[Control] = []
## What each seat panel was last built as ("empty", "human", "cpu"), so it is only rebuilt when
## that changes and the live dog preview is not thrown away on every cursor move.
var _panel_kind: Array[String] = ["", "", "", ""]
var _previews: Array[ModelPreview] = [null, null, null, null]
var _shown_dog: Array[DogData] = [null, null, null, null]
var _shown_hat: Array[StringName] = [&"-", &"-", &"-", &"-"]
const LEVEL_NAMES := ["EASY", "NORMAL", "HARD"]
## Things a cursor can press on the seat row, rebuilt with the seats: {kind, seat, node}.
var _seat_targets: Array[Dictionary] = []
## Per human: {row, col, node: SelectCursor}.
var _cursors: Dictionary = {}
var _cursor_layer: Control
var _banner: Control
var _banner_text: Label
var _rng := RandomNumberGenerator.new()
## Grid layout, worked out once from the pack size in _plan_grid.
var _tile_size := TILE_MAX
var _columns := 1
var _rows := 1
var _visible_rows := 1
## Top-left of each tile inside _grid_body.
var _tile_spots: Array[Vector2] = []
## The first grid row on screen. Only moves when the pack is too big to show at once.
var _scroll_row := 0
var _grid_view: Control
var _grid_body: Control
var _grid_top := 0.0
var _scroll_tween: Tween
var _scroll_bar: Control
var _scroll_thumb: Panel
var _more_up: Label
var _more_down: Label


func _ready() -> void:
	Music.play("menu")
	UiKit.cover_backdrop(self, 0.72)
	Game.reset_scores()
	_rng.randomize()
	Input.joy_connection_changed.connect(_on_joy_connection_changed)
	for slot in Game.slots:
		slot.ready = slot.is_bot
		if not slot.is_bot:
			_seat_input(slot)

	var title := UiKit.sign("CHOOSE YOUR DOG", 46)
	title.set_anchors_preset(Control.PRESET_CENTER_TOP)
	title.grow_horizontal = Control.GROW_DIRECTION_BOTH
	title.offset_top = 10
	add_child(title)

	_build_grid()

	_banner = _make_banner()
	add_child(_banner)

	var seats := HBoxContainer.new()
	seats.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	seats.grow_horizontal = Control.GROW_DIRECTION_BOTH
	seats.grow_vertical = Control.GROW_DIRECTION_BEGIN
	seats.offset_bottom = -144
	seats.add_theme_constant_override("separation", 18)
	add_child(seats)
	for i in Game.MAX_PLAYERS:
		var holder := Control.new()
		holder.custom_minimum_size = PANEL
		seats.add_child(holder)
		_panels.append(holder)

	_footer = UiKit.label("", 22, Color(1, 1, 1, 0.85))
	_footer.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_footer.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_footer.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_footer.offset_bottom = -94
	_footer.autowrap_mode = TextServer.AUTOWRAP_OFF
	add_child(_footer)
	var actions := HBoxContainer.new()
	actions.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	actions.grow_horizontal = Control.GROW_DIRECTION_BOTH
	actions.grow_vertical = Control.GROW_DIRECTION_BEGIN
	actions.offset_bottom = -22
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("separation", 18)
	add_child(actions)
	var back := _mouse_button("Back", 180)
	back.pressed.connect(func() -> void: Game.goto(Game.SCENE_MAIN_MENU))
	actions.add_child(back)
	_continue = _mouse_button("Let's play!", 320)
	_continue.pressed.connect(_go_on)
	actions.add_child(_continue)

	# Cursors draw over everything else.
	_cursor_layer = Control.new()
	_cursor_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_cursor_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_cursor_layer)
	_refresh_all()


# ---------------------------------------------------------------- building

## Picks the column count that gives the biggest tiles. A layout that fits on screen always beats
## one that scrolls; only when even three rows of ten cannot hold the pack does it scroll.
func _plan_grid(count: int) -> void:
	var best_area := -1.0
	var best_fits := false
	for cols in range(1, MAX_COLUMNS + 1):
		var rows := ceili(count / float(cols))
		var shown := mini(rows, MAX_VISIBLE_ROWS)
		var fits := rows <= MAX_VISIBLE_ROWS
		var tile := _tile_for(cols, shown)
		var area := tile.x * tile.y
		# Fitting wins outright. Between two that fit, the bigger tiles; on a tie the first found,
		# which has fewer columns and so fuller rows. Between two that scroll, the most columns,
		# so there is as little to scroll through as possible.
		var better := (fits and not best_fits) or (fits == best_fits and area > best_area + 1.0) \
			or (not fits and not best_fits and absf(area - best_area) <= 1.0)
		if best_area < 0.0 or better:
			best_area = area
			best_fits = fits
			_columns = cols
			_rows = rows
			_visible_rows = shown
			_tile_size = tile


## The tile [param cols] columns and [param rows] visible rows leave room for.
func _tile_for(cols: int, rows: int) -> Vector2:
	var wide := (GRID_AREA.size.x - GAP * (cols - 1)) / cols
	var tall := minf(TILE_MAX.y, (GRID_AREA.size.y - GAP * (rows - 1)) / rows)
	var aspect := lerpf(ASPECT_SMALL, ASPECT_BIG, clampf((tall - 140.0) / (TILE_MAX.y - 140.0), 0.0, 1.0))
	var w := minf(minf(wide, TILE_MAX.x), tall * aspect)
	return Vector2(floorf(w), floorf(minf(tall, w / aspect)))


func _build_grid() -> void:
	var count := Game.dogs.size() + 1
	_plan_grid(count)
	var step := _tile_size + Vector2(GAP, GAP)
	for i in count:
		var row := i / _columns
		var in_row := mini(_columns, count - row * _columns)
		# A short last row sits in the middle, so up and down land on the dog you expect.
		var left := (GRID_AREA.size.x - (in_row * step.x - GAP)) * 0.5
		_tile_spots.append(Vector2(left + (i % _columns) * step.x, row * step.y))
	_grid_view = Control.new()
	_grid_view.position = GRID_AREA.position
	_grid_view.size = GRID_AREA.size
	_grid_view.mouse_filter = Control.MOUSE_FILTER_PASS
	# Clipped only when scrolling: otherwise the hover pop at the edges would be cut off.
	_grid_view.clip_contents = _scrolls()
	_grid_view.gui_input.connect(_on_grid_input)
	add_child(_grid_view)
	_grid_body = Control.new()
	_grid_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_grid_body.size = GRID_AREA.size
	# A pack that does not fill the area sits in the middle of it rather than hugging the title.
	_grid_top = maxf(0.0, (GRID_AREA.size.y - (_visible_rows * step.y - GAP)) * 0.5)
	_grid_body.position.y = _grid_top
	_grid_view.add_child(_grid_body)
	for i in count:
		var tile := _make_tile(i)
		tile.position = _tile_spots[i]
		tile.size = _tile_size
		_grid_body.add_child(tile)
		_tiles.append(tile)
	if _scrolls():
		_build_scroll_bar()


## A track down the right of the grid with arrows at each end, so a pack that continues
## off-screen says so.
func _build_scroll_bar() -> void:
	_scroll_bar = Control.new()
	# Hard against the grid's right edge rather than the screen's, so it reads as the grid's.
	var right := 0.0
	for spot in _tile_spots:
		right = maxf(right, spot.x + _tile_size.x)
	_scroll_bar.position = Vector2(GRID_AREA.position.x + right + 12, GRID_AREA.position.y)
	_scroll_bar.size = Vector2(22, GRID_AREA.size.y)
	_scroll_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_scroll_bar)
	_more_up = UiKit.title("▲", 20, UiKit.YELLOW)
	_more_up.size = Vector2(22, 26)
	_scroll_bar.add_child(_more_up)
	_more_down = UiKit.title("▼", 20, UiKit.YELLOW)
	_more_down.size = Vector2(22, 26)
	_more_down.position.y = GRID_AREA.size.y - 26
	_scroll_bar.add_child(_more_down)
	var track := Panel.new()
	track.position = Vector2(6, 32)
	track.size = Vector2(10, GRID_AREA.size.y - 64)
	var track_style := StyleBoxFlat.new()
	track_style.bg_color = Color(0, 0, 0, 0.3)
	track_style.set_corner_radius_all(5)
	track.add_theme_stylebox_override("panel", track_style)
	track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_scroll_bar.add_child(track)
	_scroll_thumb = Panel.new()
	_scroll_thumb.size = Vector2(10, track.size.y * _visible_rows / float(_rows))
	var thumb_style := StyleBoxFlat.new()
	thumb_style.bg_color = UiKit.CREAM
	thumb_style.set_corner_radius_all(5)
	_scroll_thumb.add_theme_stylebox_override("panel", thumb_style)
	_scroll_thumb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	track.add_child(_scroll_thumb)
	_update_scroll_bar()


func _update_scroll_bar() -> void:
	if _scroll_bar == null:
		return
	var track := _scroll_thumb.get_parent() as Control
	var room := track.size.y - _scroll_thumb.size.y
	_scroll_thumb.position.y = room * _scroll_row / float(maxi(1, _rows - _visible_rows))
	_more_up.modulate.a = 1.0 if _scroll_row > 0 else 0.2
	_more_down.modulate.a = 1.0 if _scroll_row + _visible_rows < _rows else 0.2


## The mouse wheel scrolls a big pack, so a mouse alone can reach every dog.
func _on_grid_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed):
		return
	var button := (event as InputEventMouseButton).button_index
	if button == MOUSE_BUTTON_WHEEL_UP:
		_scroll_to(_scroll_row - 1)
	elif button == MOUSE_BUTTON_WHEEL_DOWN:
		_scroll_to(_scroll_row + 1)


func _scrolls() -> bool:
	return _rows > _visible_rows


func _scroll_to(row: int) -> void:
	row = clampi(row, 0, maxi(0, _rows - _visible_rows))
	if row == _scroll_row:
		return
	_scroll_row = row
	if _scroll_tween != null:
		_scroll_tween.kill()
	_scroll_tween = _grid_body.create_tween()
	_scroll_tween.tween_property(_grid_body, "position:y", _grid_top - row * (_tile_size.y + GAP), 0.16) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_update_scroll_bar()


## Scrolls just enough to put a roster cursor's tile on screen. The grid follows whoever moved
## last; anyone else's cursor waits at the edge until they move.
func _follow(cursor: Dictionary) -> void:
	if cursor.row != ROSTER:
		return
	var row: int = cursor.col / _columns
	if row < _scroll_row:
		_scroll_to(row)
	elif row >= _scroll_row + _visible_rows:
		_scroll_to(row - _visible_rows + 1)


## Whether tile [param index] is in the rows on screen (where it will be once a scroll settles).
func _tile_on_screen(index: int) -> bool:
	var row := index / _columns
	return row >= _scroll_row and row < _scroll_row + _visible_rows


## Used by the tests and the screenshot harness: the grid's shape.
func _grid_columns() -> int:
	return _columns

func _make_tile(index: int) -> Control:
	var random := index >= Game.dogs.size()
	# A plain control holding the card and, on top of it, the row of placed tokens.
	var tile := Control.new()
	tile.size = _tile_size
	var w := _tile_size.x
	var card := PanelContainer.new()
	card.set_anchors_preset(Control.PRESET_FULL_RECT)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tile.add_child(card)
	var dog: DogData = null if random else Game.dogs[index]
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.2, 0.24, 0.22) if random else dog.card_color
	# A darker rim of the card's own colour at rest; a player's colour when a cursor is on it.
	var rim := Color(0.1, 0.12, 0.11) if random else dog.card_color.darkened(0.5)
	style.border_color = rim
	tile.set_meta("rim", rim)
	style.set_border_width_all(4)
	style.shadow_color = Color(0, 0, 0, 0.35)
	style.shadow_size = 12
	style.shadow_offset = Vector2(0, 6)
	style.set_corner_radius_all(int(clampf(w * 0.075, 10.0, 18.0)))
	var margin := clampf(w * 0.032, 5.0, 8.0)
	style.content_margin_left = margin
	style.content_margin_right = margin
	style.content_margin_top = margin
	style.content_margin_bottom = margin - 2.0
	card.add_theme_stylebox_override("panel", style)
	tile.set_meta("style", style)
	tile.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_mouse_pick(index))
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 2)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(column)
	var name_text := "RANDOM" if random else dog.display_name.to_upper()
	var name_size := _name_size(name_text, w - margin * 2.0)
	if random:
		var mark := UiKit.title("?", int(_tile_size.y * 0.5), Color(1, 1, 1, 0.75))
		mark.size_flags_vertical = Control.SIZE_EXPAND_FILL
		mark.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		column.add_child(mark)
	else:
		var art := UiKit.dog_portrait(dog, dog.card_color, Vector2(w - margin * 2.0, _tile_size.y - 60), 1.0, 0.0, true)
		# The art takes whatever the name leaves; its own minimum would push the card past the tile.
		art.custom_minimum_size = Vector2(0, 24)
		art.size_flags_vertical = Control.SIZE_EXPAND_FILL
		column.add_child(art)
	var name_label := UiKit.title(name_text, name_size, UiKit.CREAM)
	name_label.clip_text = true
	column.add_child(name_label)
	# Tokens of whoever has picked this dog sit along the bottom of the art, like coins.
	var token := _token_size()
	var tokens := HBoxContainer.new()
	tokens.name = "Tokens"
	tokens.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tokens.add_theme_constant_override("separation", -int(token * 0.22))
	tokens.position = Vector2(margin + 2.0, _tile_size.y - margin - name_size * 1.3 - token * 0.9)
	tile.add_child(tokens)
	return tile


## The name's size for this tile: a fixed share of the tile, shrunk further only if a long name
## would not fit across it.
func _name_size(text: String, room: float) -> int:
	var size_ := int(clampf(_tile_size.x * 0.12, 18.0, 30.0))
	while size_ > 14 and UiKit.FONT_DISPLAY.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_).x + size_ * 0.3 > room:
		size_ -= 1
	return size_


## Cursors shrink a little with the tiles, so on a big pack the coin covers one dog, not the
## name of the dog above it.
func _cursor_size() -> float:
	return clampf(_tile_size.x * 0.36, 50.0, SelectCursor.SIZE)


func _token_size() -> float:
	return clampf(_tile_size.x * 0.18, 30.0, 44.0)


func _make_banner() -> Control:
	var banner := PanelContainer.new()
	banner.set_anchors_preset(Control.PRESET_CENTER_TOP)
	banner.grow_horizontal = Control.GROW_DIRECTION_BOTH
	# In the strip between the grid and the seats, clear of both.
	banner.offset_top = GRID_AREA.end.y + 5
	banner.custom_minimum_size = Vector2(1500, 0)
	banner.mouse_filter = Control.MOUSE_FILTER_STOP
	var style := StyleBoxFlat.new()
	style.bg_color = Color("e8c84f")
	style.border_color = UiKit.INK
	style.set_border_width_all(4)
	style.set_corner_radius_all(14)
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	banner.add_theme_stylebox_override("panel", style)
	_banner_text = UiKit.title("READY TO PLAY!", 44, UiKit.INK)
	_banner_text.add_theme_color_override("font_outline_color", Color(1, 1, 1, 0.6))
	banner.add_child(_banner_text)
	banner.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed:
			_go_on())
	banner.visible = false
	return banner


func _refresh_all() -> void:
	_continue.disabled = not _all_ready()
	_seat_targets.clear()
	for seat in _panels.size():
		_refresh_panel(seat)
	_refresh_tokens()
	_sync_cursors()
	var ready := _all_ready()
	if ready and not _banner.visible:
		_banner.visible = true
		_banner.pivot_offset = _banner.size * 0.5
		Juice.pop(_banner, 1.08, 0.3)
		Sfx.play("whistle", 1.2, -6.0)
	_banner.visible = ready
	_banner_text.text = "READY TO PLAY!   Press %s" % DeviceInput.button_label(&"confirm", Game.slots)
	_footer.text = _footer_text()


func _footer_text() -> String:
	if Game.slots.filter(func(s: PlayerSlot) -> bool: return not s.is_bot).is_empty():
		return "Join with %s   ·   then move your cursor and press to pick a dog" % _join_wording()
	var move := DeviceInput.button_label(&"move", Game.slots)
	var confirm := DeviceInput.button_label(&"confirm", Game.slots)
	var back := DeviceInput.button_label(&"back", Game.slots)
	return "%s  move your cursor   ·   %s  pick a dog, or press + CPU   ·   %s  undo / leave" % [move, confirm, back]


func _refresh_panel(seat: int) -> void:
	var slot := _slot_for_index(seat)
	var kind := "empty" if slot == null else ("cpu" if slot.is_bot else "human")
	var holder := _panels[seat]
	if kind != _panel_kind[seat]:
		for child in holder.get_children():
			child.queue_free()
		_previews[seat] = null
		_shown_dog[seat] = null
		_shown_hat[seat] = &"-"
		_panel_kind[seat] = kind
		match kind:
			"empty": _build_empty(holder, seat)
			"human": _build_seat(holder, slot)
			"cpu": _build_seat(holder, slot)
		if kind != "empty":
			# Somebody just sat down: the seat bounces so the room notices.
			holder.pivot_offset = PANEL * 0.5
			Juice.pop(holder, 1.05, 0.25)
	match kind:
		"empty":
			_seat_targets.append({"kind": "add", "seat": seat, "node": holder.find_child("Add", true, false)})
		"human":
			_seat_targets.append({"kind": "hat", "seat": seat, "node": holder.find_child("SeatHatButton", true, false)})
		"cpu":
			_seat_targets.append({"kind": "cpu", "seat": seat, "node": holder.find_child("Change", true, false)})
			_seat_targets.append({"kind": "level", "seat": seat, "node": holder.find_child("Level", true, false)})
			_seat_targets.append({"kind": "remove", "seat": seat, "node": holder.find_child("Remove", true, false)})
	if slot != null:
		_update_seat(holder, slot, seat)


func _build_empty(holder: Control, seat: int) -> void:
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	var empty_style := UiKit.panel_style(Color(1, 1, 1, 0.18), Color(0.05, 0.09, 0.06, 0.62))
	empty_style.set_border_width_all(3)
	empty_style.set_corner_radius_all(20)
	panel.add_theme_stylebox_override("panel", empty_style)
	holder.add_child(panel)
	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 14)
	panel.add_child(column)
	column.add_child(UiKit.title("P%d" % (seat + 1), 52, Color(1, 1, 1, 0.3)))
	var join := UiKit.label("Press %s to join" % _join_wording(), 21, Color(1, 1, 1, 0.6))
	column.add_child(join)
	column.add_child(UiKit.label("— or —", 18, Color(1, 1, 1, 0.35)))
	var add := _mouse_button("+  ADD CPU", 260)
	add.name = "Add"
	add.pressed.connect(func() -> void: _add_bot(seat))
	var centre := CenterContainer.new()
	centre.add_child(add)
	column.add_child(centre)


## A seat with a dog on it, human or CPU. The parts that change are filled in by _update_seat.
func _build_seat(holder: Control, slot: PlayerSlot) -> void:
	var background := Panel.new()
	background.name = "Background"
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	holder.add_child(background)
	var column := VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_FULL_RECT)
	column.offset_left = 14
	column.offset_right = -14
	column.offset_top = 10
	column.offset_bottom = -10
	column.add_theme_constant_override("separation", 4)
	holder.add_child(column)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	head.add_child(UiKit.chip(slot.label, slot.color, 22))
	var device := UiKit.label("Computer player" if slot.is_bot else DeviceInput.describe(slot.device), 18, Color(1, 1, 1, 0.85))
	device.autowrap_mode = TextServer.AUTOWRAP_OFF
	device.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	head.add_child(device)
	column.add_child(head)
	# The character card: the dog in a pool of its own colour on the left, and on the right
	# what it is like to play - its name, its one line, and its four ratings. It follows the
	# cursor, so comparing dogs is just moving across the grid and watching your own card.
	var card := HBoxContainer.new()
	card.add_theme_constant_override("separation", 8)
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(card)
	var stage := Control.new()
	stage.custom_minimum_size = Vector2(196, 0)
	stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var light := UiKit.spotlight(slot.dog.card_color)
	light.name = "Spotlight"
	light.set_anchors_preset(Control.PRESET_FULL_RECT)
	stage.add_child(light)
	var preview := ModelPreview.new(Vector2i(240, 300))
	preview.set_anchors_preset(Control.PRESET_FULL_RECT)
	stage.add_child(preview)
	card.add_child(stage)
	_previews[slot.index] = preview
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.alignment = BoxContainer.ALIGNMENT_CENTER
	info.add_theme_constant_override("separation", 4)
	card.add_child(info)
	var name_label := UiKit.title("", 34, UiKit.CREAM)
	name_label.name = "DogName"
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	name_label.clip_text = true
	info.add_child(name_label)
	var pitch := UiKit.label("", 16, Color(1, 1, 1, 0.82))
	pitch.name = "DogPitch"
	pitch.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	pitch.custom_minimum_size = Vector2(0, 40)
	info.add_child(pitch)
	var stats := VBoxContainer.new()
	stats.name = "Stats"
	stats.add_theme_constant_override("separation", 5)
	info.add_child(stats)
	if slot.is_bot:
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", 10)
		var change := _mouse_button("◀ DOG ▶", 140)
		change.name = "Change"
		change.pressed.connect(func() -> void: _cycle(slot, 1))
		row.add_child(change)
		var level := _mouse_button(LEVEL_NAMES[slot.cpu_level], 130)
		level.name = "Level"
		level.pressed.connect(func() -> void: _cycle_level(slot))
		row.add_child(level)
		var remove := _mouse_button("✕", 70)
		remove.name = "Remove"
		remove.pressed.connect(func() -> void: _remove_bot_at(slot))
		row.add_child(remove)
		column.add_child(row)
	else:
		var hat_row := HBoxContainer.new()
		hat_row.alignment = BoxContainer.ALIGNMENT_CENTER
		hat_row.add_theme_constant_override("separation", 8)
		var hat := _mouse_button("", 250)
		hat.name = "SeatHatButton"
		hat.add_theme_font_size_override("font_size", 20)
		hat.pressed.connect(func() -> void: _cycle_hat(slot))
		hat_row.add_child(hat)
		var bark := HBoxContainer.new()
		bark.add_theme_constant_override("separation", 5)
		bark.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		bark.add_child(UiKit.keycaps(&"bark", slot.device, 15))
		bark.add_child(_word("bark", 17, Color(1, 1, 1, 0.7)))
		hat_row.add_child(bark)
		column.add_child(hat_row)
		var status := HBoxContainer.new()
		status.name = "Status"
		status.alignment = BoxContainer.ALIGNMENT_CENTER
		status.add_theme_constant_override("separation", 10)
		column.add_child(status)


func _update_seat(holder: Control, slot: PlayerSlot, seat: int) -> void:
	var dog := slot.dog
	var background := holder.get_node("Background") as Panel
	var style := StyleBoxFlat.new()
	style.bg_color = dog.card_color_dark if slot.ready or slot.is_bot else dog.card_color_dark.darkened(0.35)
	style.border_color = slot.color
	style.set_border_width_all(6 if slot.ready and not slot.is_bot else 4)
	style.set_corner_radius_all(20)
	style.shadow_color = Color(0, 0, 0, 0.35)
	style.shadow_size = 14
	style.shadow_offset = Vector2(0, 7)
	background.add_theme_stylebox_override("panel", style)
	var light := holder.find_child("Spotlight", true, false) as TextureRect
	if light != null:
		var gradient := (light.texture as GradientTexture2D).gradient
		gradient.colors = PackedColorArray([Color(dog.card_color.lightened(0.15), 0.55), Color(dog.card_color, 0.18), Color(dog.card_color, 0.0)])
	(holder.find_child("DogName", true, false) as Label).text = dog.display_name.to_upper()
	var pitch := holder.find_child("DogPitch", true, false) as Label
	if pitch.text != dog.description:
		pitch.text = dog.description
		var stats := holder.find_child("Stats", true, false)
		for child in stats.get_children():
			child.queue_free()
		for rating in [["Speed", dog.speed_rating], ["Throw", dog.throw_rating], ["Catch", dog.catch_rating], ["Dash", dog.dash_rating]]:
			stats.add_child(_stat_row(rating[0], rating[1], dog.card_color.lightened(0.2)))
	if (_shown_dog[seat] != dog or _shown_hat[seat] != slot.hat) and _previews[seat] != null:
		_shown_dog[seat] = dog
		_shown_hat[seat] = slot.hat
		_previews[seat].show_dog(dog, Game.hat(slot.hat))
	var hat_button := holder.find_child("SeatHatButton", true, false) as Button
	if hat_button != null:
		var worn := Game.hat(slot.hat)
		hat_button.text = "◀  %s  ▶" % (worn.display_name.to_upper() if worn != null else "NO HAT")
	var level_button := holder.find_child("Level", true, false) as Button
	if level_button != null:
		level_button.text = LEVEL_NAMES[slot.cpu_level]
	var status := holder.find_child("Status", true, false)
	if status == null:
		return
	for child in status.get_children():
		child.queue_free()
	if slot.ready:
		var stamp := UiKit.chip("READY!", UiKit.YELLOW, 28)
		status.add_child(stamp)
		status.add_child(UiKit.keycaps(&"back", slot.device, 15))
		status.add_child(_word("change", 17, Color(1, 1, 1, 0.7)))
	else:
		status.add_child(_word("CHOOSING…", 22, Color(1, 1, 1, 0.75)))
		status.add_child(UiKit.keycaps(&"confirm", slot.device, 15))
		status.add_child(_word("pick", 17, Color(1, 1, 1, 0.7)))


## One rating on a seat's card: its name and five pips, filled up to the rating.
func _stat_row(title: String, rating: int, color: Color) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	var name_label := _word(title, 16, Color(1, 1, 1, 0.85))
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	name_label.custom_minimum_size = Vector2(52, 0)
	row.add_child(name_label)
	for i in 5:
		var pip := Panel.new()
		pip.custom_minimum_size = Vector2(19, 12)
		pip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var style := StyleBoxFlat.new()
		style.bg_color = color if i < rating else Color(0, 0, 0, 0.35)
		style.set_corner_radius_all(4)
		pip.add_theme_stylebox_override("panel", style)
		row.add_child(pip)
	return row


func _word(text: String, size_: int, color: Color) -> Label:
	var label := UiKit.label(text, size_, color)
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	return label


## Each picked dog gets its player's token on its roster tile.
func _refresh_tokens() -> void:
	for i in _tiles.size():
		var tokens := _tiles[i].get_node("Tokens")
		for child in tokens.get_children():
			child.queue_free()
		if i >= Game.dogs.size():
			continue
		for slot in Game.slots:
			if slot.ready and slot.dog == Game.dogs[i]:
				tokens.add_child(SelectCursor.make(slot.label.replace("CPU ", "C"), slot.color, _token_size(), false))


# ---------------------------------------------------------------- cursors

func _sync_cursors() -> void:
	for slot in _cursors.keys():
		if not Game.slots.has(slot):
			(_cursors[slot].node as Node).queue_free()
			_cursors.erase(slot)
	for slot in Game.slots:
		if slot.is_bot or _cursors.has(slot):
			continue
		var node := SelectCursor.make(slot.label, slot.color, _cursor_size())
		_cursor_layer.add_child(node)
		_cursors[slot] = {"row": ROSTER, "col": maxi(0, Game.dogs.find(slot.dog)), "node": node}
	for slot in _cursors:
		var cursor: Dictionary = _cursors[slot]
		if cursor.row == SEATS and (_seat_targets.is_empty() or cursor.col >= _seat_targets.size()):
			cursor.row = ROSTER if _seat_targets.is_empty() else SEATS
			cursor.col = clampi(cursor.col, 0, maxi(0, _seat_targets.size() - 1)) if cursor.row == SEATS else 0


func _process(_delta: float) -> void:
	for slot in Game.slots.duplicate():
		if slot.is_bot or not _inputs.has(slot) or not _cursors.has(slot):
			continue
		_drive(slot, _inputs[slot])
	_place_cursors()
	_highlight()


func _drive(slot: PlayerSlot, inp: DeviceInput) -> void:
	var cursor: Dictionary = _cursors[slot]
	var moved := false
	if inp.just_pressed(&"left"):
		moved = _step(cursor, -1)
	if inp.just_pressed(&"right"):
		moved = _step(cursor, 1) or moved
	if inp.just_pressed(&"up"):
		moved = _climb(cursor, -1) or moved
	if inp.just_pressed(&"down"):
		moved = _climb(cursor, 1) or moved
	if moved:
		_follow(cursor)
		Sfx.play("ui_move", 1.0 + 0.1 * slot.index, -8.0)
		# Hovering a dog shows it on your seat, until you have locked one in.
		if cursor.row == ROSTER and not slot.ready and cursor.col < Game.dogs.size():
			slot.dog = Game.dogs[cursor.col]
			_refresh_all()
	if inp.just_pressed(&"confirm"):
		_press(slot, cursor)
	# Bark has nothing to do on this screen, so it tries on the next hat.
	if inp.just_pressed(&"bark"):
		_cycle_hat(slot)
	if inp.just_pressed(&"back"):
		if slot.ready:
			slot.ready = false
			Sfx.play("ui_back")
			_refresh_all()
		else:
			_leave(slot)


## Left and right go round within a grid row, the way a row of cards on a table would; the seat
## row goes round its buttons.
func _step(cursor: Dictionary, direction: int) -> bool:
	if cursor.row == SEATS:
		if _seat_targets.is_empty():
			return false
		cursor.col = wrapi(cursor.col + direction, 0, _seat_targets.size())
		return true
	var row: int = cursor.col / _columns
	var first := row * _columns
	var in_row := mini(_columns, _tiles.size() - first)
	cursor.col = first + wrapi(cursor.col - first + direction, 0, in_row)
	return true


## Up and down: grid row to grid row, off the bottom row onto the seats, and from the seats back
## up into the bottom row on screen. Every move keeps the cursor roughly above or below where it
## was.
func _climb(cursor: Dictionary, direction: int) -> bool:
	var x := _cursor_x(cursor)
	if cursor.row == SEATS:
		if direction > 0:
			return false
		cursor.row = ROSTER
		cursor.col = _nearest_tile(mini(_scroll_row + _visible_rows, _rows) - 1, x)
		return true
	var row: int = cursor.col / _columns + direction
	if row < 0:
		return false
	if row >= _rows:
		if _seat_targets.is_empty():
			return false
		cursor.row = SEATS
		var best := 0
		for i in _seat_targets.size():
			if absf(_cursor_x({"row": SEATS, "col": i}) - x) < absf(_cursor_x({"row": SEATS, "col": best}) - x):
				best = i
		cursor.col = best
		return true
	cursor.col = _nearest_tile(row, x)
	return true


## The tile in grid [param row] whose middle is closest to screen x [param x].
func _nearest_tile(row: int, x: float) -> int:
	var first := row * _columns
	var best := first
	for i in range(first, mini(first + _columns, _tiles.size())):
		if absf(_tile_middle_x(i) - x) < absf(_tile_middle_x(best) - x):
			best = i
	return best


## From the layout rather than the node, so a tile mid-pop or mid-scroll still counts as where
## it belongs.
func _tile_middle_x(index: int) -> float:
	return GRID_AREA.position.x + _tile_spots[index].x + _tile_size.x * 0.5


func _cursor_x(cursor: Dictionary) -> float:
	if cursor.row == ROSTER:
		return _tile_middle_x(clampi(cursor.col, 0, _tiles.size() - 1))
	return _cursor_point(cursor).x


func _press(slot: PlayerSlot, cursor: Dictionary) -> void:
	if cursor.row == ROSTER:
		if _all_ready():
			_go_on()
			return
		_pick(slot, cursor.col)
		return
	if cursor.col >= _seat_targets.size():
		return
	var target: Dictionary = _seat_targets[cursor.col]
	match target.kind:
		"add":
			_add_bot(target.seat)
		"cpu":
			var cpu := _slot_for_index(target.seat)
			if cpu != null:
				_cycle(cpu, 1)
		"level":
			var cpu := _slot_for_index(target.seat)
			if cpu != null:
				_cycle_level(cpu)
		"hat":
			# Your own hat is yours to change; someone else's is not.
			if target.seat == slot.index:
				_cycle_hat(slot)
			else:
				Sfx.play("ui_back")
		"remove":
			var cpu := _slot_for_index(target.seat)
			if cpu != null:
				_remove_bot_at(cpu)


func _pick(slot: PlayerSlot, col: int) -> void:
	if col >= Game.dogs.size():
		var free := _free_dogs(slot)
		if free.is_empty():
			return
		col = Game.dogs.find(free[_rng.randi_range(0, free.size() - 1)])
		if _cursors.has(slot):
			_cursors[slot].col = col
			# The dice may land off-screen; go and show it.
			_follow(_cursors[slot])
	var dog := Game.dogs[col]
	# Two players are never the same dog. Another player's locked-in pick is theirs; a CPU
	# just moves over to a dog nobody has.
	var holder := _holder_of(dog, slot)
	if holder != null and not holder.is_bot:
		_refuse(col)
		return
	if holder != null:
		var free := _free_dogs(holder, dog)
		if free.is_empty():
			_refuse(col)
			return
		holder.dog = free[0]
	slot.dog = dog
	slot.ready = true
	Sfx.play("catch", 1.2)
	# Locking in is the first time a player hears their dog's voice.
	Sfx.bark(dog.breed, 1.0, -5.0)
	_refresh_all()
	var tile := _tiles[col]
	tile.pivot_offset = tile.size * 0.5
	Juice.pop(tile, 1.06, 0.2)


## Where a cursor's tip points: the top middle of a roster tile, the left edge of a seat button.
## Players on the same tile fan out so every cursor stays visible.
func _cursor_point(cursor: Dictionary) -> Vector2:
	if cursor.row == ROSTER:
		var tile := _tiles[clampi(cursor.col, 0, _tiles.size() - 1)]
		var rect := tile.get_global_rect()
		# The top edge, so the token hangs above the art instead of over the dog's face.
		# The coin hangs above its tip, so on a small tile the tip goes further in: low enough that
		# the coin overlaps its own dog rather than the name of the one in the row above.
		var coin := _cursor_size()
		var point := rect.position + Vector2(rect.size.x * (0.42 if rect.size.x > 200.0 else 0.3),
			maxf(rect.size.y * 0.1, coin * 0.95 - 14.0))
		# A cursor on a row scrolled out of sight waits at the edge of the grid, above or below
		# its dog, instead of floating over the title or the seats.
		if _scrolls():
			var view := _grid_view.get_global_rect()
			point.y = clampf(point.y, view.position.y + 8.0, view.end.y - 8.0)
		return point
	if cursor.col >= _seat_targets.size():
		return Vector2.ZERO
	var node: Control = _seat_targets[cursor.col].node
	if node == null:
		return Vector2.ZERO
	var target_rect := node.get_global_rect()
	return target_rect.position + Vector2(target_rect.size.x * 0.5, target_rect.size.y * 0.5)


func _place_cursors() -> void:
	var stacked: Dictionary = {}
	for slot in _cursors:
		var cursor: Dictionary = _cursors[slot]
		var key := "%d:%d" % [cursor.row, cursor.col]
		var nth: int = stacked.get(key, 0)
		stacked[key] = nth + 1
		var node: SelectCursor = cursor.node
		node.target = _cursor_point(cursor) - _cursor_layer.global_position + Vector2(-34.0 + 34.0 * nth, 22.0 * nth)
		# Parked at the edge while its dog is scrolled away: faded, so it reads as "over there".
		var away: bool = cursor.row == ROSTER and not _tile_on_screen(cursor.col)
		node.modulate.a = lerpf(node.modulate.a, 0.5 if away else 1.0, 0.3)


## Tiles and seat buttons under a cursor light up in that player's colour.
func _highlight() -> void:
	var lit: Dictionary = {}
	for slot in _cursors:
		var cursor: Dictionary = _cursors[slot]
		if cursor.row == ROSTER:
			lit[_tiles[clampi(cursor.col, 0, _tiles.size() - 1)]] = slot.color
		elif cursor.col < _seat_targets.size() and _seat_targets[cursor.col].node != null:
			lit[_seat_targets[cursor.col].node] = slot.color
	for tile in _tiles:
		var style: StyleBoxFlat = tile.get_meta("style")
		var on := lit.has(tile)
		style.border_color = lit[tile] if on else tile.get_meta("rim")
		style.set_border_width_all(8 if on else 4)
		tile.scale = tile.scale.lerp(Vector2.ONE * (1.04 if on else 1.0), 0.3)
		tile.pivot_offset = tile.size * 0.5
	for target in _seat_targets:
		var node: Control = target.node
		if node == null:
			continue
		node.modulate = Color(1.25, 1.25, 1.1) if lit.has(node) else Color.WHITE
		node.pivot_offset = node.size * 0.5
		node.scale = node.scale.lerp(Vector2.ONE * (1.08 if lit.has(node) else 1.0), 0.3)


# ---------------------------------------------------------------- seats

func _seat_input(slot: PlayerSlot) -> DeviceInput:
	var inp := DeviceInput.new(slot.device)
	# A button still down from the screen we came from (B out of setup, A into here) is
	# not a fresh press: without this it would kick the player out or ready them up.
	for action in [&"confirm", &"back", &"left", &"right", &"up", &"down"]:
		inp.just_pressed(action)
	_inputs[slot] = inp
	return inp


func _unhandled_input(event: InputEvent) -> void:
	var device := DeviceInput.join_device_from_event(event)
	if device != DeviceInput.NONE and Game.get_slot_by_device(device) == null:
		var slot := Game.add_player(device)
		if slot:
			_seat_input(slot)
			Sfx.play("catch")
			_refresh_all()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel") and Game.slots.is_empty():
		Game.goto(Game.SCENE_MAIN_MENU)


## A pad unplugged before its player picked would hold the lobby forever, since only that pad
## can pick or leave. Let it go; plugging back in and pressing A rejoins.
func _on_joy_connection_changed(device: int, connected: bool) -> void:
	if connected:
		return
	var slot := Game.get_slot_by_device(device)
	if slot == null or slot.is_bot or slot.ready:
		return
	_leave(slot)


func _leave(slot: PlayerSlot) -> void:
	Game.remove_player(slot)
	_inputs.erase(slot)
	Sfx.play("bounce")
	_refresh_all()


func _go_on() -> void:
	if _all_ready():
		Game.goto(Game.SCENE_MATCH_SETUP)


func _cycle(slot: PlayerSlot, dir: int) -> void:
	var i := Game.dogs.find(slot.dog)
	for step in range(1, Game.dogs.size()):
		var next := Game.dogs[wrapi(i + dir * step, 0, Game.dogs.size())]
		if _holder_of(next, slot) == null:
			slot.dog = next
			break
	Sfx.play("ui_move")
	_refresh_all()


func _cycle_level(slot: PlayerSlot) -> void:
	slot.cpu_level = (slot.cpu_level + 1) % LEVEL_NAMES.size()
	Sfx.play("ui_move", 0.9 + 0.15 * slot.cpu_level)
	_refresh_all()


## Through the hats this machine has earned, then bareheaded, and round again.
func _cycle_hat(slot: PlayerSlot) -> void:
	var options: Array[StringName] = [&""]
	for hat in Progress.unlocked_hats():
		options.append(hat.id)
	slot.hat = options[wrapi(options.find(slot.hat) + 1, 0, options.size())]
	Sfx.play("pickup", 1.1)
	_refresh_all()


## Who else has [param dog]: a player who has locked it in, or a CPU. Hovering is not holding.
func _holder_of(dog: DogData, besides: PlayerSlot) -> PlayerSlot:
	for other in Game.slots:
		if other != besides and other.dog == dog and (other.is_bot or other.ready):
			return other
	return null


func _free_dogs(for_slot: PlayerSlot, also_skip: DogData = null) -> Array[DogData]:
	var out: Array[DogData] = []
	for dog in Game.dogs:
		if dog != also_skip and _holder_of(dog, for_slot) == null:
			out.append(dog)
	return out


## That dog is somebody's: the tile shakes its head.
func _refuse(col: int) -> void:
	Sfx.play("ui_back")
	var tile := _tiles[col]
	var shake := tile.create_tween()
	for i in 4:
		shake.tween_property(tile, "rotation_degrees", 3.0 if i % 2 == 0 else -3.0, 0.04)
	shake.tween_property(tile, "rotation_degrees", 0.0, 0.04)
	var taken := UiKit.title("TAKEN", int(clampf(tile.size.x * 0.15, 22.0, 34.0)), UiKit.YELLOW)
	taken.size = Vector2(tile.size.x, 0)
	taken.position = Vector2(0, tile.size.y * 0.35)
	tile.add_child(taken)
	var fade := taken.create_tween()
	fade.tween_interval(0.5)
	fade.tween_property(taken, "modulate:a", 0.0, 0.3)
	fade.tween_callback(taken.queue_free)


func _all_ready() -> bool:
	if Game.slots.size() < MIN_PLAYERS:
		return false
	for s in Game.slots:
		if not s.ready:
			return false
	return Game.slots.any(func(s: PlayerSlot) -> bool: return not s.is_bot)


## How to describe the join button. A cabinet has no Space or Enter, and saying so is noise.
func _join_wording() -> String:
	if DeviceInput.any_arcade(Game.slots) or DeviceInput.any_arcade_connected():
		return "any button on your panel"
	# Only what is actually plugged in, each named as printed on it.
	var ways: Array[String] = []
	for device in Input.get_connected_joypads():
		var way := "%s (pad)" % DeviceInput.short_glyph(&"confirm", device)
		if not ways.has(way):
			ways.append(way)
	ways.append("Space")
	ways.append("Enter")
	return " / ".join(ways)


func _slot_for_index(i: int) -> PlayerSlot:
	for s in Game.slots:
		if s.index == i:
			return s
	return null


func _mouse_button(text: String, width: float) -> Button:
	var b := UiKit.wood_button(text, width)
	b.icon = null
	b.alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.add_theme_font_size_override("font_size", 24)
	# Joining and picking are per-device; global UI accept must not consume their presses.
	b.focus_mode = Control.FOCUS_NONE
	return b


## A click on a dog picks it for the first human, sitting a keyboard player down if nobody has.
func _mouse_pick(index: int) -> void:
	var human: PlayerSlot = null
	for slot in Game.slots:
		if not slot.is_bot:
			human = slot
			break
	if human == null:
		_join_keyboard()
		for slot in Game.slots:
			if not slot.is_bot:
				human = slot
				break
	if human == null:
		return
	if _cursors.has(human):
		_cursors[human].row = ROSTER
		_cursors[human].col = index
		_follow(_cursors[human])
	_pick(human, index)


func _join_keyboard() -> void:
	for device in [DeviceInput.KEYBOARD_WASD, DeviceInput.KEYBOARD_ARROWS]:
		if Game.get_slot_by_device(device) == null:
			var slot := Game.add_player(device)
			if slot:
				_seat_input(slot)
				Sfx.play("catch")
				_refresh_all()
			return


## Sends the most recently added CPU home. Humans are never removed this way - a player
## leaves with their own back button, so nobody can be kicked out by someone else's stick.
func _remove_bot() -> void:
	for i in range(Game.slots.size() - 1, -1, -1):
		var slot: PlayerSlot = Game.slots[i]
		if slot.is_bot:
			_remove_bot_at(slot)
			return


func _remove_bot_at(slot: PlayerSlot) -> void:
	if not slot.is_bot:
		return
	Game.remove_player(slot)
	Sfx.play("ui_back")
	_refresh_all()


## Seats a CPU, in [param seat] when that is free, otherwise in the first free one. It brings a
## dog nobody else has, so a new CPU is never a copy of you.
func _add_bot(seat: int = -1) -> void:
	if Game.slots.size() >= Game.MAX_PLAYERS:
		return
	var index := seat if seat >= 0 and _slot_for_index(seat) == null else -1
	if index < 0:
		for i in Game.MAX_PLAYERS:
			if _slot_for_index(i) == null:
				index = i
				break
	if index < 0:
		return
	var bot := PlayerSlot.new()
	bot.index = index
	bot.device = DeviceInput.VIRTUAL
	bot.is_bot = true
	bot.ready = true
	bot.dog = Game.dogs[index % Game.dogs.size()]
	for dog in Game.dogs:
		if not Game.slots.any(func(s: PlayerSlot) -> bool: return s.dog == dog):
			bot.dog = dog
			break
	Game.slots.append(bot)
	Game.slots.sort_custom(func(a: PlayerSlot, b: PlayerSlot) -> bool: return a.index < b.index)
	Events.player_joined.emit(bot)
	Sfx.play("catch", 0.9)
	_refresh_all()
