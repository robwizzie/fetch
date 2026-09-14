class_name ArenaCamera
extends Camera3D
## Fixed perspective camera looking down at the arena, Boomerang Fu style.
## Tune [member pitch_degrees], [member height] and [member fov] per arena in the inspector.

@export var pitch_degrees := 56.0:
	set(v):
		pitch_degrees = v
		_apply()
@export var height := 17.0:
	set(v):
		height = v
		_apply()
## Point on the ground the camera looks at.
@export var look_target := Vector3(0, 0, 0.3):
	set(v):
		look_target = v
		_apply()


func _ready() -> void:
	_apply()


func _apply() -> void:
	var back := height / tan(deg_to_rad(pitch_degrees))
	position = look_target + Vector3(0, height, back)
	look_at(look_target, Vector3.UP)
