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
var selected_toy: ToyData
var selected_mode: GameModeData
var mixed_toys := true
var powerups_enabled := true
var points_to_win: int = 5
var last_match_winner: PlayerSlot

## Which content list the gallery scene shows ("dogs", "toys", "arenas", "modes").
var gallery_kind: String = "dogs"

## Startup shows the cover until confirmed; later transitions advance as soon as resources are ready.
var pending_scene: String = SCENE_MAIN_MENU
## Only the loading screen used between scenes offers this; boot goes straight to the menu.
var show_start_prompt := false
var navigation_busy := false


func _ready() -> void:
	_load_content()
	_apply_defaults()


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
