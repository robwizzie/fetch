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
## The mixer the settings screen exposes. Levels are remembered like everything else there.
const AUDIO_BUSES: Array[String] = ["Master", "Music", "SFX"]
const TEAM_NAMES: Array[String] = ["RED PACK", "BLUE PACK"]
const TEAM_COLORS: Array[Color] = [Color(0.95, 0.36, 0.32), Color(0.36, 0.56, 0.95)]
## Red against blue is fine for most, but orange against blue holds up for every common type.
const TEAM_COLORS_COLORBLIND: Array[Color] = [Color("e69f00"), Color("3d8fe0")]

var dogs: Array[DogData] = []
var toys: Array[ToyData] = []
var arenas: Array[ArenaData] = []
var modes: Array[GameModeData] = []
var hats: Array[HatData] = []

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
## Comfort and accessibility, set in Settings and remembered.
## Controller rumble on hits, catches and full wind-ups.
var rumble := true
## The slow-motion beat on a knockout. Some players find it disorienting; hit-stop stays.
var knockout_slowmo := true
var screen_shake := true
## The slow, close replay of the knockout that decided a round.
var replays := true
## Free-for-all: knocked-out players float around as ghosts until the next round. A match
## option, off unless chosen on the setup screen.
var ghosts := false
## A player palette chosen to stay distinct for the common kinds of colour blindness.
var colorblind_colors := false
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
## How a match is won. ROUNDS: the last dog (or pack) standing takes the round, first to
## points_to_win rounds wins. BONKS (the Boomerang Fu way): every rival bonked is a point,
## bonking yourself loses one, first to points_to_win bonks wins.
enum Scoring { ROUNDS, BONKS }
var scoring: Scoring = Scoring.ROUNDS
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
			if index != JOY_BUTTON_B and not DeviceInput.is_dpad_button(index):
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
	# Tests and capture scenes are always silent, whatever the saved settings say. The Master
	# bus is muted rather than Sfx/Music switched off, so a test that saves settings can never
	# write "sound off" into the player's real profile.
	if is_test_run():
		AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), true)


## True when a scene under res://tests/ is what is running.
static func is_test_run() -> bool:
	for argument in OS.get_cmdline_args():
		if argument.begins_with("res://tests/"):
			return true
	return false


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
		rumble = config.get_value("comfort", "rumble", rumble)
		knockout_slowmo = config.get_value("comfort", "knockout_slowmo", knockout_slowmo)
		screen_shake = config.get_value("comfort", "screen_shake", screen_shake)
		replays = config.get_value("comfort", "replays", replays)
		colorblind_colors = config.get_value("comfort", "colorblind_colors", colorblind_colors)
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
	for bus in AUDIO_BUSES:
		var index := AudioServer.get_bus_index(bus)
		if index != -1:
			AudioServer.set_bus_volume_linear(index, config.get_value("audio", bus.to_lower() + "_volume", 1.0))


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
	for bus in AUDIO_BUSES:
		var index := AudioServer.get_bus_index(bus)
		if index != -1:
			config.set_value("audio", bus.to_lower() + "_volume", AudioServer.get_bus_volume_linear(index))
	config.set_value("input", "arcade_hints", int(arcade_hints))
	config.set_value("match", "treats_from_round", treats_from_round)
	config.set_value("comfort", "rumble", rumble)
	config.set_value("comfort", "knockout_slowmo", knockout_slowmo)
	config.set_value("comfort", "screen_shake", screen_shake)
	config.set_value("comfort", "replays", replays)
	config.set_value("comfort", "colorblind_colors", colorblind_colors)
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
	for r in _load_dir("res://data/hats"):
		hats.append(r)
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
	# Two players are never the same dog: a new seat starts on one nobody has.
	for dog in dogs:
		if not slots.any(func(s: PlayerSlot) -> bool: return s.dog == dog):
			slot.dog = dog
			break
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
		s.knockouts = 0
		s.catches = 0
		s.bonked = 0
		s.clear_powerups()
	team_scores = [0, 0]
	assign_teams()


## Seats alternate sides, so two players sitting next to each other are opponents and a
## four-player cabinet splits two against two without anybody choosing. Goes by position in the
## list rather than seat number: seats keep their number when someone leaves, and two dogs on
## seats 0 and 2 would otherwise both land on the same pack.
##
## Packs chosen on the setup screen (1v1, 2v1, 3v1, 2v2 - any split) are kept, as long as both
## packs still have somebody in them; otherwise seats alternate again.
func assign_teams() -> void:
	if not team_mode:
		for s in slots:
			s.team = -1
		return
	var counts := [0, 0]
	var chosen := true
	for s in slots:
		if s.team < 0 or s.team >= TEAM_NAMES.size():
			chosen = false
		else:
			counts[s.team] += 1
	if chosen and counts[0] > 0 and counts[1] > 0:
		return
	for i in slots.size():
		slots[i].team = i % TEAM_NAMES.size()


## True when every pack has at least one dog, so a team match can start.
func teams_valid() -> bool:
	if not team_mode:
		return true
	var counts := [0, 0]
	for s in slots:
		if s.team >= 0 and s.team < counts.size():
			counts[s.team] += 1
	return counts[0] > 0 and counts[1] > 0


## Adds (or, negative, takes away) points for whichever side [param slot] is on. Never below nil.
func add_points(slot: PlayerSlot, amount: int) -> void:
	if slot == null:
		return
	if team_mode and slot.team >= 0:
		team_scores[slot.team] = maxi(0, team_scores[slot.team] + amount)
	else:
		slot.score = maxi(0, slot.score + amount)


## What a side is called, and what colour it flies. Falls back to the player's own colour in a
## free-for-all, where the "team" is one dog.
func hat(id: StringName) -> HatData:
	for h in hats:
		if h.id == id:
			return h
	return null


func team_name(team: int) -> String:
	return TEAM_NAMES[team] if team >= 0 and team < TEAM_NAMES.size() else ""


func team_color(team: int) -> Color:
	var colors := TEAM_COLORS_COLORBLIND if colorblind_colors else TEAM_COLORS
	return colors[team] if team >= 0 and team < colors.size() else UiKit.CREAM


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


## A complete match with one human and three opponents, through the normal screens.
##
## Practice seats the CPUs for you but still goes to the dog select: which dog you play is
## part of every route into a match, the way a fighting game never starts without one. It
## used to skip straight to the setup screen, where choosing a dog meant finding a button.
func start_practice(device: int = DeviceInput.KEYBOARD_WASD) -> void:
	clear_players()
	var player := add_player(device)
	if player:
		# Left un-ready on purpose: the human picks their dog and confirms it like everyone else.
		player.ready = false
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
	points_to_win = 5
	goto(SCENE_DOG_SELECT)


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
