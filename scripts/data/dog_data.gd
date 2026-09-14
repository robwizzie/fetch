class_name DogData
extends Resource
## Stats and look for one playable dog.
## To add a dog: duplicate any .tres in res://data/dogs/, change the values, done.
## Files are loaded in filename order, so prefix with a number to control menu order.

@export var id: StringName = &"shadow"
@export var display_name: String = "Shadow"
@export_multiline var description: String = "Balanced and reliable."

@export_group("Look")
@export var fur_color: Color = Color(0.12, 0.12, 0.14)
@export var accent_color: Color = Color(0.35, 0.3, 0.3)
@export var bandana_color: Color = Color(0.2, 0.5, 1.0)

@export_group("Ratings (1-5, shown on the select screen)")
@export_range(1, 5) var speed_rating: int = 3
@export_range(1, 5) var throw_rating: int = 3
@export_range(1, 5) var catch_rating: int = 3
@export_range(1, 5) var dash_rating: int = 3

@export_group("Gameplay numbers")
## Top speed in metres per second.
@export var move_speed: float = 7.0
## Multiplier applied to the toy's base throw speed.
@export var throw_power: float = 1.0
## Pressing catch while a dangerous toy is inside this radius catches it immediately.
@export var catch_radius: float = 2.0
## A catch press also stays "armed" for this many seconds: a toy that would hit the dog in that
## window is caught instead. This is the real skill window; bigger = more forgiving.
@export var catch_window: float = 0.18
## After a missed catch press the dog can't try again for this long (stops button mashing).
@export var catch_cooldown: float = 0.35
## Distance covered by one dash, in metres.
@export var dash_distance: float = 5.0
@export var dash_cooldown: float = 0.9
## Hitbox radius. Smaller dogs are harder to hit.
@export var body_radius: float = 0.72
