class_name Highlights
extends RefCounted
## Spots the knockouts worth shouting about. The match tells it about every knockout; it says
## which kind of great moment that was, if any, so the HUD can call it out and Progress can
## count it towards hats. Remembers who bonked whom for revenge, for the whole match.

## Two knockouts by one dog this close together are one play.
const MULTI_WINDOW := 0.7
## A throw this long, thrower to victim, is a long shot.
const LONG_SHOT := 13.0

const TEXT := {
	&"double": "DOUBLE BONK!", &"triple": "TRIPLE BONK!", &"return": "RETURN TO SENDER!",
	&"revenge": "REVENGE!", &"bank": "BANK SHOT!", &"hole": "INTO THE HOLE!",
	&"long": "LONG SHOT!", &"sky": "SKY BONK!",
}

## Victim slot -> the slot that last bonked it.
var _last_bonker: Dictionary = {}
## Slot -> [time of last knockout (msec), knockouts in the current streak].
var _streaks: Dictionary = {}


## The kind of moment this knockout was, or &"" for an ordinary one. [param credited] is whoever
## earned it (null for nobody); [param by] the toy, if a toy did it.
func classify(victim: Dog, by: Node, credited: Dog, sudden_death: bool) -> StringName:
	var kind := &""
	if credited == null:
		kind = &"sky" if sudden_death and by == null and not victim.is_falling() else &""
	else:
		var now := Time.get_ticks_msec()
		var streak: Array = _streaks.get(credited.slot, [-100000, 0])
		var count: int = streak[1] + 1 if now - int(streak[0]) <= MULTI_WINDOW * 1000.0 else 1
		_streaks[credited.slot] = [now, count]
		var toy := by as Toy
		if count >= 3:
			kind = &"triple"
		elif count == 2:
			kind = &"double"
		elif toy != null and toy.caught_from == victim:
			kind = &"return"
		elif _last_bonker.get(credited.slot) == victim.slot:
			kind = &"revenge"
		elif victim.is_falling():
			kind = &"hole"
		elif toy != null and toy.bounces > 0:
			kind = &"bank"
		elif credited.global_position.distance_to(victim.global_position) >= LONG_SHOT:
			kind = &"long"
		_last_bonker[victim.slot] = credited.slot
	return kind


static func text(kind: StringName) -> String:
	return TEXT.get(kind, "")
