class_name WanderBrain
extends Node
## Drives a Dog with a VIRTUAL DeviceInput: amble to random spots, pause, repeat.
## Used for the dogs on the title screen; the seed of real bots later.

@export var area := Vector2(20, 10)
@export var speed := 0.55

var _target := Vector3.ZERO
var _timer := 0.0
var _idle := 0.0


func _ready() -> void:
	_pick()


func _physics_process(delta: float) -> void:
	var dog := get_parent() as Dog
	if dog == null or not dog.alive or dog.input == null:
		return
	if _idle > 0.0:
		_idle -= delta
		dog.input.virtual_move = Vector2.ZERO
		return
	_timer -= delta
	var to := _target - dog.global_position
	to.y = 0.0
	if to.length() < 0.7 or _timer <= 0.0:
		_pick()
		_idle = randf_range(0.6, 2.2)
		return
	dog.input.virtual_move = Vector2(to.x, to.z).normalized() * speed


func _pick() -> void:
	_target = Vector3(randf_range(-area.x / 2.0, area.x / 2.0), 0.0, randf_range(-area.y / 2.0, area.y / 2.0))
	_timer = randf_range(3.0, 6.0)
