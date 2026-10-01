extends Node
## The dog select, driven the way a player does it: a cursor per player over the pack, a press
## to pick, and the seats along the bottom for adding and removing CPUs.
##
## Everything here is done with direction and confirm/back alone, which is all a cabinet panel
## is guaranteed to have (an unmapped encoder's confirm is "any button").
##
## Then the same screen with packs of 12, 24 and 40 dogs (copies of the real ones, never written
## to data/): the grid has to fit, every dog has to be reachable by stick, and the dog under the
## cursor has to stay on screen.

var failed := false
var lobby: Node


func _ready() -> void:
	Sfx.enabled = false
	Music.enabled = false
	Game.clear_players()
	lobby = load("res://scenes/ui/dog_select.tscn").instantiate()
	add_child(lobby)
	await get_tree().process_frame

	var human := Game.add_player(DeviceInput.VIRTUAL)
	human.dog = Game.dogs[0]
	lobby._inputs[human] = DeviceInput.new(DeviceInput.VIRTUAL)
	lobby._refresh_all()
	await get_tree().process_frame
	_check(lobby._cursors.has(human), "a player who sits down gets a cursor")
	_check(lobby._cursors[human].row == lobby.ROSTER, "and it starts on the pack")

	# Hovering shows the dog on your seat; pressing locks it in.
	await _press(human, &"right")
	_check(human.dog == Game.dogs[1] and not human.ready, "hovering a dog previews it without picking it")
	await _press(human, &"confirm")
	_check(human.ready and human.dog == Game.dogs[1], "confirm picks the dog under the cursor")
	_check(lobby._tiles[1].get_node("Tokens").get_child_count() > 0, "a picked dog carries its player's token")
	await _press(human, &"back")
	_check(not human.ready, "back puts the pick down again")
	await _press(human, &"confirm")

	# Down to the seats: every empty seat is an ADD CPU button.
	await _press(human, &"down")
	_check(lobby._cursors[human].row == lobby.SEATS, "down moves the cursor to the seats")
	_check(_targets("add") == 3, "each empty seat offers a CPU")
	await _press(human, &"confirm")
	_check(Game.slots.size() == 2 and Game.slots.any(func(s: PlayerSlot) -> bool: return s.is_bot), "pressing ADD CPU seats one")
	_check(Game.slots.filter(func(s: PlayerSlot) -> bool: return s.is_bot)[0].ready, "a CPU is ready without being asked")
	_check(lobby._all_ready() and lobby._banner.visible, "everyone picked: the READY banner is up")
	_check(not lobby.get("_continue").disabled, "and the way on is open")

	# Fill the pack from the seat row, then take a CPU away again.
	while _targets("add") > 0:
		_aim(human, "add")
		await _press(human, &"confirm")
	_check(Game.slots.size() == Game.MAX_PLAYERS, "the pack fills to four")
	_check(_targets("add") == 0, "a full pack offers no more seats")
	var before := Game.slots.size()
	_aim(human, "cpu")
	var cpu_seat: int = lobby._seat_targets[lobby._cursors[human].col].seat
	var cpu: PlayerSlot = lobby._slot_for_index(cpu_seat)
	var old_dog := cpu.dog
	await _press(human, &"confirm")
	_check(cpu.dog != old_dog, "CHANGE gives a CPU a different dog")
	_aim(human, "remove")
	await _press(human, &"confirm")
	_check(Game.slots.size() == before - 1, "REMOVE sends a CPU home")
	_check(Game.slots.has(human), "and never the human pressing it")
	lobby._remove_bot()
	lobby._remove_bot()
	lobby._remove_bot()
	_check(Game.slots.size() == 1 and Game.slots[0] == human, "every CPU can go; the human stays")

	# Back with nothing picked gives up the seat.
	await _press(human, &"up")
	await _press(human, &"back")
	await _press(human, &"back")
	_check(not Game.slots.has(human), "back with nothing picked leaves the seat")

	_check_join_wording()
	lobby.queue_free()
	await get_tree().process_frame
	await _big_pack(12)
	await _big_pack(24)
	await _big_pack(40)
	if not failed:
		print("[lobby] PASSED: cursor picks, hover previews, seat-row CPUs, ready banner, leaving, cabinet join wording, grid navigation and scrolling with 12/24/40 dogs")
	get_tree().quit(1 if failed else 0)


## A pack of [param count] dogs: the grid fits its area, the cursor gets round all of it in two
## dimensions and off the bottom onto the seats, and whatever it is on is on screen.
func _big_pack(count: int) -> void:
	var originals: Array[DogData] = Game.dogs.duplicate()
	for i in range(originals.size(), count):
		var fake: DogData = originals[i % originals.size()].duplicate()
		fake.id = StringName("test_fake_%d" % i)
		fake.display_name = "Fake %d" % i
		Game.dogs.append(fake)
	Game.clear_players()
	lobby = load("res://scenes/ui/dog_select.tscn").instantiate()
	add_child(lobby)
	await get_tree().process_frame
	var human := Game.add_player(DeviceInput.VIRTUAL)
	human.dog = Game.dogs[0]
	lobby._inputs[human] = DeviceInput.new(DeviceInput.VIRTUAL)
	lobby._refresh_all()
	await get_tree().process_frame
	var tag := "[%d dogs] " % count
	var tiles: Array = lobby._tiles
	var cols: int = lobby._columns
	var area: Rect2 = lobby.GRID_AREA
	var tile_size: Vector2 = lobby._tile_size
	_check(tiles.size() == count + 1, tag + "a tile per dog plus Random")
	_check(cols <= lobby.MAX_COLUMNS and lobby._rows > 1, tag + "the pack is laid out in rows")
	_check(tile_size.x >= 120.0 and tile_size.y >= 120.0, tag + "tiles stay big enough to read (%s)" % tile_size)
	_check(lobby._visible_rows * (tile_size.y + lobby.GAP) - lobby.GAP <= area.size.y + 0.5, tag + "the rows on screen fit the grid's area")
	for i in tiles.size():
		var spot: Vector2 = lobby._tile_spots[i]
		_check(spot.x >= -0.5 and spot.x + tile_size.x <= area.size.x + 0.5, tag + "tile %d fits across the screen" % i)
	_check(lobby._scrolls() == (count > 29), tag + "only a pack too big for three rows of ten scrolls")

	var cursor: Dictionary = lobby._cursors[human]
	cursor.col = 0
	# Left and right go round within a row.
	await _press(human, &"left")
	_check(cursor.col == cols - 1, tag + "left from the first dog wraps to the end of its row")
	await _press(human, &"right")
	_check(cursor.col == 0, tag + "and right wraps back")
	# Down a row and back up keeps the column.
	await _press(human, &"down")
	_check(cursor.row == lobby.ROSTER and cursor.col == cols, tag + "down moves to the dog below")
	_check(human.dog == Game.dogs[cols] and not human.ready, tag + "and previews it")
	await _press(human, &"up")
	_check(cursor.col == 0, tag + "up comes back")

	# Snake through the whole grid: every tile is reached and is on screen when it is.
	var visited := {0: true}
	var rows: int = lobby._rows
	for row in rows:
		var in_row := mini(cols, tiles.size() - row * cols)
		for step in in_row - 1:
			await _press(human, &"right" if row % 2 == 0 else &"left")
			visited[cursor.col] = true
		if row < rows - 1:
			await _press(human, &"down")
			visited[cursor.col] = true
			_check(cursor.row == lobby.ROSTER and cursor.col / cols == row + 1, tag + "down from row %d reaches row %d" % [row, row + 1])
			await get_tree().create_timer(0.25).timeout
			_check(_tile_shown(cursor.col), tag + "the cursor's dog on row %d is on screen" % (row + 1))
	_check(visited.size() == tiles.size(), tag + "every tile is reachable (%d of %d)" % [visited.size(), tiles.size()])
	if lobby._scrolls():
		_check(lobby._scroll_row > 0, tag + "walking down the pack scrolls it")

	# Off the bottom row onto the seats, and back up to the dog nearest above.
	await _press(human, &"down")
	_check(cursor.row == lobby.SEATS, tag + "down from the bottom row reaches the seats")
	var seat_x: float = lobby._cursor_x(cursor)
	await _press(human, &"up")
	var bottom_row: int = mini(lobby._scroll_row + lobby._visible_rows, rows) - 1
	_check(cursor.row == lobby.ROSTER and cursor.col / cols == bottom_row, tag + "up from the seats lands on the bottom row on screen")
	_check(cursor.col == lobby._nearest_tile(bottom_row, seat_x), tag + "on the dog nearest above the seat button")

	# Back to the top: a scrolled pack scrolls back.
	for i in rows:
		await _press(human, &"up")
	await get_tree().create_timer(0.25).timeout
	_check(cursor.col / cols == 0 and lobby._scroll_row == 0 and _tile_shown(cursor.col), tag + "up to the top row scrolls back to it")

	# A dog off the first screen can be picked and carries the token.
	var far := count - 1
	cursor.col = far
	lobby._follow(cursor)
	await _press(human, &"confirm")
	_check(human.ready and human.dog == Game.dogs[far], tag + "the last dog can be picked")
	await get_tree().process_frame
	_check(tiles[far].get_node("Tokens").get_child_count() > 0, tag + "and wears its player's token")
	await get_tree().create_timer(0.25).timeout
	_check(_tile_shown(far), tag + "and is on screen")
	await _press(human, &"back")
	# Random, the last tile, picks a real dog.
	cursor.col = tiles.size() - 1
	lobby._follow(cursor)
	await _press(human, &"confirm")
	_check(human.ready and cursor.col < count and human.dog == Game.dogs[cursor.col], tag + "Random picks a dog and the cursor follows it")

	lobby.queue_free()
	Game.clear_players()
	Game.dogs.assign(originals)
	await get_tree().process_frame


## Whether tile [param index] is inside the grid's on-screen area, by where it actually is.
func _tile_shown(index: int) -> bool:
	var view: Rect2 = lobby._grid_view.get_global_rect().grow(1.0)
	# From the tile's place rather than its global rect: the hover pop scales a lit tile up a
	# little past its slot, which is fine and not what is being tested.
	var tile: Control = lobby._tiles[index]
	var rect := Rect2(lobby._grid_body.global_position + tile.position, tile.size)
	return lobby._tile_on_screen(index) and view.encloses(rect)


func _targets(kind: String) -> int:
	return lobby._seat_targets.filter(func(t: Dictionary) -> bool: return t.kind == kind).size()


## Puts the player's cursor on the first seat button of [param kind].
func _aim(slot: PlayerSlot, kind: String) -> void:
	for i in lobby._seat_targets.size():
		if lobby._seat_targets[i].kind == kind:
			lobby._cursors[slot].row = lobby.SEATS
			lobby._cursors[slot].col = i
			return


## One press and release of a direction or a button, which is what just_pressed needs to see.
func _press(slot: PlayerSlot, action: StringName) -> void:
	var inp: DeviceInput = lobby._inputs[slot]
	var directions := {&"left": Vector2.LEFT, &"right": Vector2.RIGHT, &"up": Vector2.UP, &"down": Vector2.DOWN}
	if directions.has(action):
		inp.virtual_move = directions[action]
	else:
		inp.virtual_buttons[action] = true
	await get_tree().process_frame
	await get_tree().process_frame
	inp.virtual_move = Vector2.ZERO
	inp.virtual_buttons[action] = false
	await get_tree().process_frame


## A cabinet has no Space and no Enter, so the prompts must not offer them.
func _check_join_wording() -> void:
	Game.arcade_hints = Game.ArcadeHints.ALWAYS
	var arcade: String = lobby._join_wording()
	_check(not arcade.contains("Space") and not arcade.contains("Enter"),
		"cabinet prompts do not mention keys a cabinet does not have")
	Game.arcade_hints = Game.ArcadeHints.NEVER
	var desk: String = lobby._join_wording()
	_check(desk.contains("Space") or desk.contains("Enter"), "a desktop still gets its keys named")
	Game.arcade_hints = Game.ArcadeHints.AUTO


func _check(ok: bool, message: String) -> void:
	if not ok:
		failed = true
		push_error("[lobby] " + message)
