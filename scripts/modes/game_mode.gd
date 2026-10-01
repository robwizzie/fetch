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


func on_dog_eliminated(_dog: Dog) -> void:
	pass


func is_round_over(_dogs: Array[Dog]) -> bool:
	return false


## Slot that won the round, or null for a draw.
func round_winner(_dogs: Array[Dog]) -> PlayerSlot:
	return null


func hud_hint() -> String:
	return ""
