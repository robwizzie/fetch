class_name DogBed
extends AnimatableBody3D
## Living Room gimmick: a big squashy dog bed on the floor. It is solid - toys bounce off it and
## dogs hide behind it - but a thrown toy hitting it sends it sliding across the boards, so the
## cover moves. Knock one into a rival's lane, or knock yours out of the way.

@export var size := Vector3(1.9, 0.55, 1.5)
@export var fabric := Color("c85f5a")
@export var lining := Color("f1dfc3")

## How much of a toy's speed the bed takes, the fastest it can go, and how quickly it stops.
const TAKE := 0.4
const MAX_SPEED := 8.0
const FRICTION := 7.0

var slide := Vector3.ZERO
var _visual: Node3D


func _ready() -> void:
	add_to_group("gimmicks")
	sync_to_physics = false
	collision_layer = 1
	collision_mask = 1 | 2
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.position.y = size.y * 0.5
	add_child(shape)
	_visual = Node3D.new()
	add_child(_visual)
	# A low base, a plump bolster on all four sides, and a pale cushion sunk in the middle with a
	# paw print on it: a dog bed from above, not a box.
	var bolster := 0.34
	ArenaArt.block(_visual, Vector3(size.x, 0.22, size.z), fabric.darkened(0.12), Vector3(0, 0.11, 0), Vector3.ZERO, 0.08)
	for side in [-1.0, 1.0]:
		ArenaArt.block(_visual, Vector3(size.x, size.y, bolster), fabric, Vector3(0, size.y * 0.5, side * (size.z - bolster) * 0.5), Vector3.ZERO, 0.16)
		ArenaArt.block(_visual, Vector3(bolster, size.y * 0.92, size.z - bolster * 1.6), fabric, Vector3(side * (size.x - bolster) * 0.5, size.y * 0.46, 0), Vector3.ZERO, 0.16)
	ArenaArt.block(_visual, Vector3(size.x - bolster * 1.7, 0.16, size.z - bolster * 1.7), lining, Vector3(0, 0.3, 0), Vector3.ZERO, 0.07)
	ArenaArt.paw(_visual, Vector3(0, 0.39, 0), 0.4, fabric.lightened(0.2))
	Mats.contact_shadow(self, maxf(size.x, size.z) * 0.55)


## A toy struck the bed: it takes some of the toy's momentum and slides with it.
func take_hit(toy_velocity: Vector3) -> void:
	var push := Vector3(toy_velocity.x, 0, toy_velocity.z) * TAKE
	slide = (slide + push).limit_length(MAX_SPEED)
	var squash := _visual.create_tween()
	squash.tween_property(_visual, "scale", Vector3(1.08, 0.8, 1.08), 0.06)
	squash.tween_property(_visual, "scale", Vector3.ONE, 0.25).set_trans(Tween.TRANS_BACK)
	Sfx.play_at("land", global_position, 1.4, -6.0)


func _physics_process(delta: float) -> void:
	if slide.length_squared() < 0.0004:
		slide = Vector3.ZERO
		return
	var collision := move_and_collide(slide * delta)
	if collision != null:
		var normal := collision.get_normal()
		normal.y = 0.0
		# Soft furniture: it thumps to a stop against a wall or a dog rather than bouncing.
		slide = slide.bounce(normal.normalized()) * 0.25 if normal.length_squared() > 0.001 else Vector3.ZERO
	slide = slide.move_toward(Vector3.ZERO, FRICTION * delta)
