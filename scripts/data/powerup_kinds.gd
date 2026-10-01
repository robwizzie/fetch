class_name PowerupKinds
extends RefCounted
## The power-up table. Crates are a mystery until they open, so every kind here is a possible
## outcome and they are all worth keeping: there is no dud to be disappointed by.
##
## Every kind changes how you play, not a number on a stat sheet. A 20% faster walk is not
## something anyone at the table can see; a dog turning invisible, burrowing under the lawn or
## bending a throw round a couch is. That is the Boomerang Fu rule and it is the one we keep.
##
## Slots live on [PlayerSlot] and persist for the whole match, so a pickup is an investment
## rather than a ten-second buff. Effects are read by Dog and Toy at the point of use.

const MAX_SLOTS := 3

const SHIELD := &"shield"
const ZOOMIES := &"zoomies"
const TELEPAWTHY := &"telepawthy"
const GHOST_PUP := &"ghost_pup"
const DIG := &"dig"
const SQUEAKY_BLAST := &"squeaky_blast"
const MUD_TRACK := &"mud_track"
const SCATTER_FETCH := &"scatter_fetch"
const BANK_SHOT := &"bank_shot"
const GOOD_DECOY := &"good_decoy"

const ALL: Array[StringName] = [SHIELD, ZOOMIES, TELEPAWTHY, GHOST_PUP, DIG,
	SQUEAKY_BLAST, MUD_TRACK, SCATTER_FETCH, BANK_SHOT, GOOD_DECOY]

## Powers that change what a throw does (rather than the dog). A thrown toy carries their
## colours in its trail, so everyone can read a shot before it lands.
const THROW_POWERS: Array[StringName] = [SQUEAKY_BLAST, MUD_TRACK, SCATTER_FETCH, BANK_SHOT, TELEPAWTHY]


static func display_name(kind: StringName) -> String:
	match kind:
		SHIELD: return "BUBBLE BATH"
		ZOOMIES: return "ZOOMIES"
		TELEPAWTHY: return "TELEPAWTHY"
		GHOST_PUP: return "GHOST PUP"
		DIG: return "DIG!"
		SQUEAKY_BLAST: return "SQUEAKY KABOOM"
		MUD_TRACK: return "MUDDY PAWS"
		SCATTER_FETCH: return "TRIPLE FETCH"
		BANK_SHOT: return "BANK SHOT"
		GOOD_DECOY: return "GOOD BOY DECOY"
	return "TREAT"


static func blurb(kind: StringName) -> String:
	match kind:
		SHIELD: return "A soapy bubble soaks one hit. Nobody likes bath time"
		ZOOMIES: return "Tear around at full pelt with a dash that's always ready"
		TELEPAWTHY: return "Steer your throw in mid-air with the stick"
		GHOST_PUP: return "Invisible until you throw or dash. Only your paw prints show"
		DIG: return "Your dash tunnels under the lawn - and under anything in the way - and pops up further on"
		SQUEAKY_BLAST: return "Impact arms a squeaky bomb; grab it quick to defuse"
		MUD_TRACK: return "Throws leave a mud trail that slows everyone down"
		SCATTER_FETCH: return "Every throw sends two extra toys out wide"
		BANK_SHOT: return "The first wall bounce sends a throw off even faster"
		GOOD_DECOY: return "Dashing leaves a very convincing good boy behind"
	return ""


## The same promise in two or three words, for the moment of collection. The blurb is written
## to be read on a menu; this is written to be read across a table while a round is running,
## which is a different job and a much shorter one.
static func tag(kind: StringName) -> String:
	match kind:
		SHIELD: return "SOAKS ONE HIT"
		ZOOMIES: return "RUN! RUN! RUN!"
		TELEPAWTHY: return "STEER YOUR THROW"
		GHOST_PUP: return "TURN INVISIBLE"
		DIG: return "DASH UNDERGROUND"
		SQUEAKY_BLAST: return "BOUNCE, THEN BOOM"
		MUD_TRACK: return "LEAVE A MUD TRAIL"
		SCATTER_FETCH: return "THREE AT ONCE"
		BANK_SHOT: return "BOUNCE FOR SPEED"
		GOOD_DECOY: return "DASH LEAVES A DECOY"
	return "TREAT"


static func color(kind: StringName) -> Color:
	match kind:
		SHIELD: return Color("6fd4ea")
		ZOOMIES: return Color("ffd160")
		TELEPAWTHY: return Color("c78bff")
		GHOST_PUP: return Color("dfe9f5")
		DIG: return Color("c9a06a")
		SQUEAKY_BLAST: return Color("ff9d65")
		MUD_TRACK: return Color("a07a52")
		SCATTER_FETCH: return Color("f07ad0")
		BANK_SHOT: return Color("5fb8ff")
		GOOD_DECOY: return Color("8ee06a")
	return Color.WHITE


## One glyph per kind, drawn on the HUD chip and the opened crate.
static func glyph(kind: StringName) -> String:
	match kind:
		SHIELD: return "S"
		ZOOMIES: return "Z"
		TELEPAWTHY: return "T"
		GHOST_PUP: return "G"
		DIG: return "D"
		SQUEAKY_BLAST: return "B"
		MUD_TRACK: return "M"
		SCATTER_FETCH: return "3"
		BANK_SHOT: return "K"
		GOOD_DECOY: return "Y"
	return "?"


## A kind the belt does not already hold. Falls back to any kind only when every one is taken,
## which cannot happen while MAX_SLOTS is below the size of the table.
static func random_new_kind(held: Array, rng: RandomNumberGenerator = null) -> StringName:
	var fresh: Array[StringName] = []
	for kind in ALL:
		if not held.has(kind):
			fresh.append(kind)
	if fresh.is_empty():
		return random_kind(rng)
	if rng == null:
		return fresh[randi() % fresh.size()]
	return fresh[rng.randi() % fresh.size()]


static func random_kind(rng: RandomNumberGenerator = null) -> StringName:
	if rng == null:
		return ALL[randi() % ALL.size()]
	return ALL[rng.randi() % ALL.size()]


## How many of a kind a slot list holds. A belt keeps each kind at most once, so this is 0 or
## 1 in practice - it stays a count because that is what the callers want to ask.
static func count(slots: Array, kind: StringName) -> int:
	var total := 0
	for entry in slots:
		if entry == kind:
			total += 1
	return total
