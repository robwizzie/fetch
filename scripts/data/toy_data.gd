class_name ToyData
extends Resource
## One throwable toy. All toys share the same Toy scene; these numbers change how it flies.
## Special behaviours (knockback, squeak, ...) are dispatched on [member special] in Toy.gd.

enum Special { NONE, KNOCKBACK, SQUEAK, RICOCHET, HEAVY }

@export var id: StringName = &"tennis_ball"
@export var display_name: String = "Tennis Ball"
@export_multiline var description: String = "Balanced and bouncy."
@export var color: Color = Color(0.85, 0.95, 0.3)
@export var radius: float = 0.42

@export_group("Presentation")
## Held toys stay the size they are on the ground, so what you pick up is what you saw.
@export var held_scale: float = 1.0
## Visual resting height; negative uses the spherical collision radius.
@export var ground_height: float = -1.0
@export var held_rotation: Vector3 = Vector3.ZERO
## Discs spin flat in flight; everything else tumbles.
@export var flat_spin: bool = false

@export_group("Flight")
## Base speed when thrown, before the dog's throw_power multiplier.
@export var throw_speed: float = 14.0
## Fraction of speed kept after bouncing off a wall.
@export var bounciness: float = 0.85
## After this many bounces the toy loses half its speed each bounce (prevents endless ricochets).
@export var max_bounces: int = 3
## Slow-down while flying, in metres per second squared.
@export var friction: float = 4.6
## Below this speed the toy is harmless and can be picked up.
@export var danger_speed: float = 4.5

@export_group("Special")
@export var special: Special = Special.NONE
## Allows unfinished custom toys to be hidden from normal matches.
@export var fully_implemented: bool = true
