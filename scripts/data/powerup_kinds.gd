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

const ALL: Array[StringName] = [SHIELD, ZOOMIES, BIG_CATCH, CANNON, SPRINGS]


static func display_name(kind: StringName) -> String:
	match kind:
		SHIELD: return "SHIELD"
		ZOOMIES: return "ZOOMIES"
		BIG_CATCH: return "SOFT PAWS"
		CANNON: return "CANNON"
		SPRINGS: return "SPRINGS"
	return "TREAT"


static func blurb(kind: StringName) -> String:
	match kind:
		SHIELD: return "Soaks one hit each round"
		ZOOMIES: return "Run faster, dash sooner"
		BIG_CATCH: return "A bigger, longer catch"
		CANNON: return "Throws fly harder"
		SPRINGS: return "Dash further, more often"
	return ""


static func color(kind: StringName) -> Color:
	match kind:
		SHIELD: return Color("6fd4ea")
		ZOOMIES: return Color("ffd160")
		BIG_CATCH: return Color("8ee06a")
		CANNON: return Color("ff8a5c")
		SPRINGS: return Color("c78bff")
	return Color.WHITE


## One glyph per kind, drawn on the HUD chip and the opened crate.
static func glyph(kind: StringName) -> String:
	match kind:
		SHIELD: return "S"
		ZOOMIES: return "Z"
		BIG_CATCH: return "P"
		CANNON: return "C"
		SPRINGS: return "J"
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
