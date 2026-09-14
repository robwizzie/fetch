class_name ToyData
extends Resource
## One throwable toy. All toys share the same Toy scene; these numbers change how it flies.
## Special behaviours (knockback, squeak, ...) are dispatched on [member special] in Toy.gd.

enum Special { NONE, KNOCKBACK, SQUEAK, RICOCHET }

@export var id: StringName = &"tennis_ball"
@export var display_name: String = "Tennis Ball"
@export_multiline var description: String = "Balanced and bouncy."
@export var color: Color = Color(0.85, 0.95, 0.3)
@export var radius: float = 22.0

@export_group("Flight")
## Base speed when thrown, before the dog's throw_power multiplier.
@export var throw_speed: float = 1100.0
## Fraction of speed kept after bouncing off a wall.
@export var bounciness: float = 0.85
## After this many bounces the toy loses half its speed each bounce (prevents endless ricochets).
@export var max_bounces: int = 3
## Slow-down while flying, in pixels per second squared.
@export var friction: float = 450.0
## Below this speed the toy is harmless and can be picked up.
@export var danger_speed: float = 350.0

@export_group("Special")
@export var special: Special = Special.NONE
## False for toys that are only stat variants so far (shown as "prototype" in menus).
@export var fully_implemented: bool = true
