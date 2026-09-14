class_name GameModeData
extends Resource
## Describes a game mode. The rules live in a GameMode script (scripts/modes/).
## Modes with [member fully_implemented] = false show in menus as "coming soon".

@export var id: StringName = &"last_dog_standing"
@export var display_name: String = "Last Dog Standing"
@export_multiline var description: String = "Classic free-for-all. Last dog standing wins the round."
@export var mode_script: Script
@export var default_points_to_win: int = 5
@export var team_based: bool = false
@export var fully_implemented: bool = false
@export var swatch: Color = Color(0.95, 0.4, 0.4)
