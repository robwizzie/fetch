extends Node
## Session state shared across scenes: who has joined, what they picked, the content registry,
## and scene navigation helpers. Content is discovered by scanning the data/ folders, so adding
## a dog/toy/arena/mode is just dropping a .tres file in the right folder.

const MAX_PLAYERS := 4
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
var selected_toy: ToyData
var selected_mode: GameModeData
var points_to_win: int = 5
var last_match_winner: PlayerSlot

## Which content list the gallery scene shows ("dogs", "toys", "arenas", "modes").
var gallery_kind: String = "dogs"


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
	Engine.time_scale = 1.0
	get_tree().call_deferred("change_scene_to_file", scene_path)
