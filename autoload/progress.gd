extends Node
## Lifetime progress on this machine: what the pack has done across every match, and the hats
## that has earned. One shared profile, like a couch console's - anyone who plays adds to it.
##
## The match does the counting (it knows which rounds score and who is human); this keeps the
## totals, works out what they unlock, saves, and remembers what was unlocked during the match
## just played so the results screen can show it off.

const DEFAULT_PATH := "user://progress.cfg"

## Swap for a scratch file in tests so they never touch the real profile.
var path := DEFAULT_PATH
var stats: Dictionary = {}
## Distinct dogs that have won a match, for "win with every dog".
var dogs_won: Array[StringName] = []
## Hats unlocked since the results screen last showed them.
var fresh_unlocks: Array[HatData] = []


func _ready() -> void:
	# A test scene plays real matches; it must never earn hats on the real profile.
	for argument in OS.get_cmdline_args():
		if argument.begins_with("res://tests/"):
			path = "user://progress_test.cfg"
	load_progress()


func load_progress() -> void:
	stats.clear()
	dogs_won.clear()
	fresh_unlocks.clear()
	var config := ConfigFile.new()
	if config.load(path) != OK:
		return
	for key in config.get_section_keys("stats") if config.has_section("stats") else PackedStringArray():
		stats[StringName(key)] = int(config.get_value("stats", key, 0))
	for id in config.get_value("dogs", "won", []):
		dogs_won.append(StringName(id))


func save_progress() -> void:
	var config := ConfigFile.new()
	for key in stats:
		config.set_value("stats", String(key), stats[key])
	config.set_value("dogs", "won", dogs_won.map(func(id: StringName) -> String: return String(id)))
	config.save(path)


func stat(key: StringName) -> int:
	if key == &"dogs_won":
		return dogs_won.size()
	return int(stats.get(key, 0))


## Adds to a lifetime stat and notes any hat that just came free.
func record(key: StringName, amount: int = 1) -> void:
	var before := _unlocked_ids()
	stats[key] = stat(key) + amount
	_note_unlocks(before)


func record_win_with(dog: DogData) -> void:
	var before := _unlocked_ids()
	if not dogs_won.has(dog.id):
		dogs_won.append(dog.id)
	_note_unlocks(before)


func is_unlocked(hat: HatData) -> bool:
	return hat.stat == &"" or stat(hat.stat) >= hat.threshold


func unlocked_hats() -> Array[HatData]:
	var out: Array[HatData] = []
	for hat in Game.hats:
		if is_unlocked(hat):
			out.append(hat)
	return out


## Wipes the profile. Used by tests on their scratch file.
func reset() -> void:
	stats.clear()
	dogs_won.clear()
	fresh_unlocks.clear()
	save_progress()


func _unlocked_ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for hat in unlocked_hats():
		out.append(hat.id)
	return out


func _note_unlocks(before: Array[StringName]) -> void:
	for hat in unlocked_hats():
		if not before.has(hat.id):
			fresh_unlocks.append(hat)
