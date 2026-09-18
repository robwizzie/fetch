class_name PowerupKinds
extends RefCounted
## The power-up table. Crates are a mystery until they open, so every kind here is a possible
## outcome and they are all worth keeping: there is no dud to be disappointed by.
##
## Slots live on [PlayerSlot] and persist for the whole match, so a pickup is an investment
## rather than a ten-second buff. Effects are read by Dog and Toy at the point of use.

const MAX_SLOTS := 3

const SHIELD := &"shield"
const ZOOMIES := &"zoomies"
const BIG_CATCH := &"big_catch"
const CANNON := &"cannon"
const SPRINGS := &"springs"
const LITTLE_LEGS := &"little_legs"
const QUICK_PAWS := &"quick_paws"
const LONG_REACH := &"long_reach"

const ALL: Array[StringName] = [SHIELD, ZOOMIES, BIG_CATCH, CANNON, SPRINGS,
	LITTLE_LEGS, QUICK_PAWS, LONG_REACH]


static func display_name(kind: StringName) -> String:
	match kind:
		SHIELD: return "SHIELD"
		ZOOMIES: return "ZOOMIES"
		BIG_CATCH: return "SOFT PAWS"
		CANNON: return "CANNON"
		SPRINGS: return "SPRINGS"
		LITTLE_LEGS: return "LITTLE LEGS"
		QUICK_PAWS: return "QUICK PAWS"
		LONG_REACH: return "LONG REACH"
	return "TREAT"


static func blurb(kind: StringName) -> String:
	match kind:
		SHIELD: return "Soaks one hit, then it is gone"
		ZOOMIES: return "Run faster, dash sooner"
		BIG_CATCH: return "A bigger, longer catch"
		CANNON: return "Throws fly harder"
		SPRINGS: return "Dash further, more often"
		LITTLE_LEGS: return "A smaller target to hit"
		QUICK_PAWS: return "Catch again sooner"
		LONG_REACH: return "Whack from further away"
	return ""


static func color(kind: StringName) -> Color:
	match kind:
		SHIELD: return Color("6fd4ea")
		ZOOMIES: return Color("ffd160")
		BIG_CATCH: return Color("8ee06a")
		CANNON: return Color("ff8a5c")
		SPRINGS: return Color("c78bff")
		LITTLE_LEGS: return Color("ff9ecb")
		QUICK_PAWS: return Color("7fe3c4")
		LONG_REACH: return Color("f2c94c")
	return Color.WHITE


## One glyph per kind, drawn on the HUD chip and the opened crate.
static func glyph(kind: StringName) -> String:
	match kind:
		SHIELD: return "S"
		ZOOMIES: return "Z"
		BIG_CATCH: return "P"
		CANNON: return "C"
		SPRINGS: return "J"
		LITTLE_LEGS: return "L"
		QUICK_PAWS: return "Q"
		LONG_REACH: return "R"
	return "?"


static func random_kind(rng: RandomNumberGenerator = null) -> StringName:
	if rng == null:
		return ALL[randi() % ALL.size()]
	return ALL[rng.randi() % ALL.size()]


## How many of a kind a slot list holds. Duplicates stack, so a second Zoomies is still a win.
static func count(slots: Array, kind: StringName) -> int:
	var total := 0
	for entry in slots:
		if entry == kind:
			total += 1
	return total
