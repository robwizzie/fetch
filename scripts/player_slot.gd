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

var color: Color:
	get:
		return COLORS[index % COLORS.size()]

var label: String:
	get:
		return "P%d" % (index + 1)
