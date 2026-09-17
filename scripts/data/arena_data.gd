class_name ArenaData
extends Resource
## Points at an arena scene and describes it for the menus.
## To add an arena: make a scene using scripts/arena/arena.gd, then add a .tres in res://data/arenas/.

@export var id: StringName = &"backyard"
@export var display_name: String = "Backyard"
@export_multiline var description: String = "Grass, a doghouse and a kiddie pool."
@export var scene: PackedScene
## Tints the menu card, and is the fallback when no thumbnail has been rendered.
@export var swatch: Color = Color(0.45, 0.7, 0.3)
## A picture of the map, rendered by tools/build_arena_thumbnails.gd.
@export var thumbnail: Texture2D
