class_name PlayerSlot
extends RefCounted
## One joined player: which device they use, which dog they picked, and their score.

const COLORS: Array[Color] = [
	Color(0.25, 0.55, 1.0),   # P1 blue
	Color(0.95, 0.3, 0.3),    # P2 red
	Color(0.3, 0.85, 0.45),   # P3 green
	Color(1.0, 0.8, 0.2),     # P4 yellow
]

var index: int = 0
var device: int = DeviceInput.NONE
var dog: DogData
var score: int = 0
var ready: bool = false
## AI is opt-in: virtual devices are also used by scripted tests and menu dogs.
var is_bot: bool = false
## Power-ups held for the rest of the match, oldest first. Capped at PowerupKinds.MAX_SLOTS.
var powerups: Array[StringName] = []


## Adds a power-up, pushing out the oldest once the belt is full. Returns what was displaced,
## or an empty name — the HUD uses it to show the swap.
func take_powerup(kind: StringName) -> StringName:
	var dropped := &""
	if powerups.size() >= PowerupKinds.MAX_SLOTS:
		dropped = powerups.pop_front()
	powerups.append(kind)
	return dropped


func has_powerup(kind: StringName) -> bool:
	return powerups.has(kind)


func powerup_count(kind: StringName) -> int:
	return PowerupKinds.count(powerups, kind)

var color: Color:
	get:
		return COLORS[index % COLORS.size()]

var label: String:
	get:
		return "CPU %d" % (index + 1) if is_bot else "P%d" % (index + 1)
