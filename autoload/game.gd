extends Node
## Session state shared across scenes: who has joined, what they picked, the content registry,
## and scene navigation helpers. Content is discovered by scanning the data/ folders, so adding
## a dog/toy/arena/mode is just dropping a .tres file in the right folder.

const MAX_PLAYERS := 4
const SCENE_SPLASH := "res://scenes/ui/splash.tscn"
const SCENE_LOADING := "res://scenes/ui/loading.tscn"
const SCENE_MAIN_MENU := "res://scenes/ui/main_menu.tscn"
const SCENE_DOG_SELECT := "res://scenes/ui/dog_select.tscn"
const SCENE_MATCH_SETUP := "res://scenes/ui/match_setup.tscn"
const SCENE_MATCH := "res://scenes/match/match.tscn"
const SCENE_RESULTS := "res://scenes/ui/results.tscn"
const SCENE_GALLERY := "res://scenes/ui/gallery.tscn"
const SETTINGS_PATH := "user://settings.cfg"
const TEAM_NAMES: Array[String] = ["RED PACK", "BLUE PACK"]
const TEAM_COLORS: Array[Color] = [Color(0.95, 0.36, 0.32), Color(0.36, 0.56, 0.95)]

var dogs: Array[DogData] = []
var toys: Array[ToyData] = []
var arenas: Array[ArenaData] = []
var modes: Array[GameModeData] = []

var slots: Array[PlayerSlot] = []
var selected_arena: ArenaData
## When true the match draws a fresh arena for every round instead of using selected_arena.
var random_arena_each_round := true
## Matches finished this session. Crates arrive sooner the more everyone has played.
var matches_played := 0
## The control tutorial runs once per session, on the very first round played.
var tutorial_shown := false

## How control prompts are worded for gamepads. AUTO reads the pad's reported name, which is
## enough to spot the usual arcade encoders; the override exists because cabinets vary.
enum ArcadeHints { AUTO, ALWAYS, NEVER }
var arcade_hints: ArcadeHints = ArcadeHints.AUTO
## Remembered across launches so a cabinet comes up filling its screen.
var fullscreen := false
var selected_toy: ToyData
var selected_mode: GameModeData
## Two packs instead of a free-for-all. Teams are assigned by seat: odd seats against even.
var team_mode := false
var team_scores: Array[int] = [0, 0]
## Whether a toy from your own side can put you out. Off by default: hitting a team-mate by
## accident is funny once and infuriating after that.
var friendly_fire := false
## Whether your own throw can come back and bonk you. On by default - a ricochet off a wall
## into your own face is one of the best things that can happen in a round.
var self_fire := true
var mixed_toys := true
var powerups_enabled := true
## First round that drops treats, or AUTO_TREATS to let the session decide. On a brand new
## session the first match holds crates back a few rounds so nobody is learning the controls
## and the treat table at once; every match after that opens with them, because by then the
## room knows what the crates do and wants them sooner.
const AUTO_TREATS := -1
const AUTO_FIRST_MATCH_ROUND := 3
var treats_from_round: int = AUTO_TREATS


## The round crates actually start dropping in, once the auto rule has been resolved.
func first_treat_round() -> int:
	if treats_from_round >= 0:
		return treats_from_round
	return 1 if matches_played > 0 else AUTO_FIRST_MATCH_ROUND
var points_to_win: int = 5
var last_match_winner: PlayerSlot

## Which content list the gallery scene shows ("dogs", "toys", "arenas", "modes").
var gallery_kind: String = "dogs"

## Startup shows the cover until confirmed; later transitions advance as soon as resources are ready.
var pending_scene: String = SCENE_MAIN_MENU
## Only the loading screen used between scenes offers this; boot goes straight to the menu.
var show_start_prompt := false
var navigation_busy := false


## Godot's built-in ui_accept / ui_cancel ship with keyboard events only, so a gamepad can move
## the menu highlight but cannot choose anything or back out — the menus look frozen on a pad.
## These are added at runtime rather than redefined in project.godot so the keyboard defaults
## stay exactly as Godot shipped them. Buttons match what DeviceInput uses in gameplay.
func _bind_menu_gamepad() -> void:
	var bindings := {
		&"ui_accept": [JOY_BUTTON_A, JOY_BUTTON_X, JOY_BUTTON_START],
		&"ui_cancel": [JOY_BUTTON_B, JOY_BUTTON_BACK],
	}
	for action in bindings:
		_add_joy_buttons(action, bindings[action])
	# An arcade encoder usually has no SDL mapping, so Godot reports raw hardware indices and
	# "button A" means nothing: the cabinet's main button could be any number. On a cabinet
	# every action button should select anyway, so bind the lot. Index 1 is left for cancel,
	# and every menu also has an on-screen Back.
	if _has_unmapped_pad():
		var accept: Array[int] = []
		for index in range(0, 16):
			if index != JOY_BUTTON_B:
				accept.append(index)
		_add_joy_buttons(&"ui_accept", accept)


func _add_joy_buttons(action: StringName, buttons: Array) -> void:
	if not InputMap.has_action(action):
		return
	var already: Array[int] = []
	for existing in InputMap.action_get_events(action):
		if existing is InputEventJoypadButton:
			already.append((existing as InputEventJoypadButton).button_index)
	for button in buttons:
		if already.has(button):
			continue
		var event := InputEventJoypadButton.new()
		# device -1 so every connected pad drives the menus, not just the first.
		event.device = -1
		event.button_index = button
		event.pressed = true
		InputMap.action_add_event(action, event)


## True when a connected pad has no SDL mapping, which is the normal state for arcade encoder
## boards. Their button numbering is whatever the board's firmware chose.
func _has_unmapped_pad() -> bool:
	if arcade_hints == ArcadeHints.ALWAYS:
		return true
	if arcade_hints == ArcadeHints.NEVER:
		return false
	for device in Input.get_connected_joypads():
		if not Input.is_joy_known(device):
			return true
		if DeviceInput.is_arcade(device):
			return true
	return false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_bind_menu_gamepad()
	Input.joy_connection_changed.connect(func(_device: int, _connected: bool) -> void: _bind_menu_gamepad())
	_load_content()
	_apply_defaults()
	_load_settings()


## A cabinet has no keyboard and nobody wants to dig through a menu on every boot, so the
## display mode is remembered and can be toggled from anywhere: F11, or Start+Select together
## on a pad. The combo takes two buttons so it cannot be hit by accident mid-round.
func _input(event: InputEvent) -> void:
	var toggle := false
	if event is InputEventKey:
		var key := event as InputEventKey
		toggle = key.pressed and not key.echo and key.keycode == KEY_F11
	elif event is InputEventJoypadButton:
		var pad := event as InputEventJoypadButton
		toggle = pad.pressed and pad.button_index == JOY_BUTTON_START \
			and Input.is_joy_button_pressed(pad.device, JOY_BUTTON_BACK)
	if toggle:
		set_fullscreen(not is_fullscreen())
		get_viewport().set_input_as_handled()


func is_fullscreen() -> bool:
	var mode := DisplayServer.window_get_mode()
	return mode == DisplayServer.WINDOW_MODE_FULLSCREEN or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN


func set_fullscreen(on: bool) -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if on else DisplayServer.WINDOW_MODE_WINDOWED)
	fullscreen = on
	save_settings()


## Settings live in user:// so a cabinet keeps them across reboots. A missing or unreadable file
## is not an error: it just means this machine has never been set up, and a cabinet defaults to
## fullscreen because that is the only way it is ever used.
func _load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) == OK:
		fullscreen = config.get_value("display", "fullscreen", fullscreen)
		arcade_hints = config.get_value("input", "arcade_hints", int(arcade_hints)) as ArcadeHints
		treats_from_round = config.get_value("match", "treats_from_round", treats_from_round)
		points_to_win = config.get_value("match", "points_to_win", points_to_win)
	elif _has_unmapped_pad():
		# First run on a cabinet. Nobody plays an arcade machine in a window.
		fullscreen = true
	if fullscreen and not is_fullscreen():
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	# Sfx and Music load after this autoload, so their settings wait a frame for them to exist.
	_apply_audio_settings.call_deferred()


func _apply_audio_settings() -> void:
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) != OK:
		return
	var sfx := get_node_or_null(^"/root/Sfx")
	if sfx != null:
		sfx.enabled = config.get_value("audio", "sfx", true)
	var music := get_node_or_null(^"/root/Music")
	if music != null:
		music.enabled = config.get_value("audio", "music", true)


func save_settings() -> void:
	var config := ConfigFile.new()
	config.load(SETTINGS_PATH)
	config.set_value("display", "fullscreen", fullscreen)
	var sfx := get_node_or_null(^"/root/Sfx")
	if sfx != null:
		config.set_value("audio", "sfx", sfx.enabled)
	var music := get_node_or_null(^"/root/Music")
	if music != null:
		config.set_value("audio", "music", music.enabled)
	config.set_value("input", "arcade_hints", int(arcade_hints))
	config.set_value("match", "treats_from_round", treats_from_round)
	config.set_value("match", "points_to_win", points_to_win)
	config.save(SETTINGS_PATH)


func _load_content() -> void:
	for r in _load_dir("res://data/dogs"):
		dogs.append(r)
	for r in _load_dir("res://data/toys"):
		toys.append(r)
	for r in _load_dir("res://data/arenas"):
		arenas.append(r)
	for r in _load_dir("res://data/modes"):
		modes.append(r)
	print("FETCH content: %d dogs, %d toys, %d arenas, %d modes" % [dogs.size(), toys.size(), arenas.size(), modes.size()])


func _apply_defaults() -> void:
	if selected_arena == null and not arenas.is_empty():
		selected_arena = arenas[0]
	if selected_toy == null and not toys.is_empty():
		selected_toy = toys[0]
	if selected_mode == null:
		for m in modes:
			if m.fully_implemented:
				selected_mode = m
				break
	if selected_mode:
		points_to_win = selected_mode.default_points_to_win


## Loads every .tres/.res in a folder, sorted by filename. Handles the ".remap" suffix that
## exported builds add when text resources are converted to binary.
func _load_dir(path: String) -> Array:
	var out: Array = []
	var dir := DirAccess.open(path)
	if dir == null:
		push_error("Content folder missing: " + path)
		return out
	var files := dir.get_files()
	files.sort()
	for f in files:
		var fname := f.trim_suffix(".remap")
		if fname.ends_with(".tres") or fname.ends_with(".res"):
			var res := load(path.path_join(fname))
			if res:
				out.append(res)
	return out


# ---------------------------------------------------------------- players

func add_player(device: int) -> PlayerSlot:
	if get_slot_by_device(device) != null or slots.size() >= MAX_PLAYERS:
		return null
	var slot := PlayerSlot.new()
	slot.index = _first_free_index()
	slot.device = device
	slot.dog = dogs[slot.index % dogs.size()] if not dogs.is_empty() else null
	slots.append(slot)
	slots.sort_custom(func(a: PlayerSlot, b: PlayerSlot) -> bool: return a.index < b.index)
	Events.player_joined.emit(slot)
	return slot


func remove_player(slot: PlayerSlot) -> void:
	slots.erase(slot)
	Events.player_left.emit(slot)


func clear_players() -> void:
	slots.clear()


func get_slot_by_device(device: int) -> PlayerSlot:
	for s in slots:
		if s.device == device:
			return s
	return null


func reset_scores() -> void:
	for s in slots:
		s.score = 0
		s.powerups.clear()
	team_scores = [0, 0]
	assign_teams()


## Seats alternate sides, so two players sitting next to each other are opponents and a
## four-player cabinet splits two against two without anybody choosing.
func assign_teams() -> void:
	for s in slots:
		s.team = (s.index % TEAM_NAMES.size()) if team_mode else -1


## What a side is called, and what colour it flies. Falls back to the player's own colour in a
## free-for-all, where the "team" is one dog.
func team_name(team: int) -> String:
	return TEAM_NAMES[team] if team >= 0 and team < TEAM_NAMES.size() else ""


func team_color(team: int) -> Color:
	return TEAM_COLORS[team] if team >= 0 and team < TEAM_COLORS.size() else UiKit.CREAM


## Points on the board for whichever side this slot is on.
func score_for(slot: PlayerSlot) -> int:
	if slot == null:
		return 0
	if team_mode and slot.team >= 0:
		return team_scores[slot.team]
	return slot.score


## Fills empty slots with keyboard/virtual players so scenes can be run directly from the editor (F6).
func debug_fill_players(count: int) -> void:
	var devices := [DeviceInput.KEYBOARD_WASD, DeviceInput.KEYBOARD_ARROWS, DeviceInput.VIRTUAL, 0]
	for i in count:
		if slots.size() >= count:
			break
		var slot := add_player(devices[i])
		if slot:
			slot.ready = true


func _first_free_index() -> int:
	for i in MAX_PLAYERS:
		var taken := false
		for s in slots:
			if s.index == i:
				taken = true
		if not taken:
			return i
	return slots.size()


# ---------------------------------------------------------------- navigation

func goto(scene_path: String) -> void:
	if navigation_busy:
		return
	navigation_busy = true
	pending_scene = scene_path
	show_start_prompt = false
	Engine.time_scale = 1.0
	get_tree().paused = false
	get_tree().call_deferred("change_scene_to_file", SCENE_LOADING)


## A complete match with one human and three opponents, using the normal setup screen.
func start_practice(device: int = DeviceInput.KEYBOARD_WASD) -> void:
	clear_players()
	var player := add_player(device)
	if player:
		player.ready = true
	for i in range(1, MAX_PLAYERS):
		var bot := PlayerSlot.new()
		bot.index = i
		bot.device = DeviceInput.VIRTUAL
		bot.is_bot = true
		bot.ready = true
		bot.dog = dogs[i % dogs.size()]
		slots.append(bot)
	reset_scores()
	for mode in modes:
		if mode.fully_implemented and mode.mode_script != null:
			selected_mode = mode
			break
	for toy in toys:
		if toy.fully_implemented:
			selected_toy = toy
			break
	points_to_win = 3
	goto(SCENE_MATCH_SETUP)


## A random arena, avoiding an immediate repeat when there is more than one to choose from.
func random_arena(exclude: ArenaData = null) -> ArenaData:
	if arenas.is_empty():
		return selected_arena
	var pool: Array[ArenaData] = []
	for candidate in arenas:
		if candidate != exclude:
			pool.append(candidate)
	if pool.is_empty():
		pool = arenas
	return pool[randi() % pool.size()]
