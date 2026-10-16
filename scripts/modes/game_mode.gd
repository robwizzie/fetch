class_name GameMode
extends RefCounted
## Base class for round rules. A mode decides when a round ends and who won it.
## Subclass, override the hooks, and reference the script from a GameModeData .tres.

var game_match: Node
## The mode of the match in progress, so bots can ask it where to go.
static var current: GameMode


func setup(p_match: Node) -> void:
	game_match = p_match
	current = self


## Every physics frame while a round is being played.
func tick(_delta: float, _dogs: Array[Dog]) -> void:
	pass


## Who takes the round when the clock runs out. Null is a draw, which is the default.
func timeout_winner(_dogs: Array[Dog]) -> PlayerSlot:
	return null


## Somewhere this mode wants a bot to be, or Vector3.INF for no opinion.
func bot_goal(_dog: Dog) -> Vector3:
	return Vector3.INF


## True when a bot holding [param toy] should hang on to it rather than throw (Golden Ball).
func bot_keeps(_dog: Dog, _toy: Toy) -> bool:
	return false


## True when a bot holding [param toy] should get rid of it right away.
func bot_should_throw_now(_dog: Dog, _toy: Toy) -> bool:
	return false


func on_round_start(_dogs: Array[Dog]) -> void:
	pass


## How long a knocked-out dog waits before coming back, in modes that respawn.
const RESPAWN_TIME := 2.5


## True when knocked-out dogs come back during the round (no ghosts, no deciding replay).
## Modes won by an objective respawn: a bonk is a setback, and the round is a race for the goal.
func respawns() -> bool:
	return false


## Whether the arena's usual spread of toys is laid out at the whistle.
func spawns_round_toys() -> bool:
	return true


## Whether mystery crates, supply drops and sudden death's sky drops happen in this mode.
func allows_treats() -> bool:
	return true


## Whether a downed dog in teams leaves a ring a pack-mate can revive it from. Respawning
## modes bring everyone back anyway.
func allows_revives() -> bool:
	return not respawns()


func allows_supply_drops() -> bool:
	return true


func allows_sudden_death() -> bool:
	return true


## Seconds on the round clock.
func round_seconds(default: float) -> float:
	return default


## True when a bot should leave [param toy] alone rather than fetch it (the hot potato).
func bot_avoids(_dog: Dog, _toy: Toy) -> bool:
	return false


func on_dog_eliminated(dog: Dog) -> void:
	if respawns():
		schedule_respawn(dog)


## Back in after RESPAWN_TIME, at the start spot furthest from any rival - unless the round has
## been decided in the meantime.
func schedule_respawn(dog: Dog) -> void:
	game_match.get_tree().create_timer(RESPAWN_TIME, false).timeout.connect(func() -> void:
		if not is_instance_valid(dog) or dog.alive or game_match.phase != game_match.Phase.PLAYING:
			return
		dog.revive(respawn_spot(dog)))


## A respawn spot this close to the objective is only used when every spot is.
const OBJECTIVE_CLEARANCE := 4.0


## Places a respawning dog should not come back on top of - the mode's objective, so nobody is
## handed the ball or the bed by being bonked.
func respawn_avoid() -> Array[Vector3]:
	return []


func respawn_spot(dog: Dog) -> Vector3:
	var arena: Arena = game_match.arena
	var best := Vector3.ZERO
	var best_score := -INF
	var avoid := respawn_avoid()
	for i in maxi(1, arena.spawn_points.get_child_count()):
		var spot := arena.get_spawn_position(i)
		# Keeping clear of the objective comes first; then as far from any rival as possible.
		var clear_of := INF
		for point in avoid:
			clear_of = minf(clear_of, Vector2(point.x - spot.x, point.z - spot.z).length())
		var gap := 30.0
		for other in game_match.dogs:
			if is_instance_valid(other) and other != dog and other.alive and not other.slot.allied_with(dog.slot):
				gap = minf(gap, Vector2(other.global_position.x - spot.x, other.global_position.z - spot.z).length())
		var score := gap + (100.0 if clear_of >= OBJECTIVE_CLEARANCE else clear_of)
		if score > best_score:
			best_score = score
			best = spot
	return arena.clear_pickup_position(best, dog.data.body_radius + 0.25)


func is_round_over(_dogs: Array[Dog]) -> bool:
	return false


## Slot that won the round, or null for a draw.
func round_winner(_dogs: Array[Dog]) -> PlayerSlot:
	return null


## What a dog's HUD card says while it plays, when the mode has something better to say than
## the toy in its mouth. Empty for the usual line.
func hud_status(_dog: Dog) -> String:
	return ""


func hud_hint() -> String:
	return ""
