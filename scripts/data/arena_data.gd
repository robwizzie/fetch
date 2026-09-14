class_name ArenaData
extends Resource
## Points at an arena scene and describes it for the menus.
## To add an arena: make a scene using scripts/arena/arena.gd, then add a .tres in res://data/arenas/.

@export var id: StringName = &"backyard"
@export var display_name: String = "Backyard"
@export_multiline var description: String = "Grass, a doghouse and a kiddie pool."
@export var scene: PackedScene
## Colour used for the swatch in menus until real thumbnails exist.
@export var swatch: Color = Color(0.45, 0.7, 0.3)
