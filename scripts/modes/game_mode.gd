class_name GameMode
extends RefCounted
## Base class for round rules. A mode decides when a round ends and who won it.
## Subclass, override the hooks, and reference the script from a GameModeData .tres.

var game_match: Node


func setup(p_match: Node) -> void:
	game_match = p_match


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
