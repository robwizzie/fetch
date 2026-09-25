class_name DogPoseMotion
extends SkeletonModifier3D
## Small reactive poses layered after the authored rig. Physics never follows animation.

var speed := 0.0
var charge := 0.0
var charging := false
var dashing := false
var celebrating := false
## Out of the round: everything goes still except, for a spaniel, the ears.
var knocked_out := false
## The spaniel's knockout joke: ears thrown straight up and flapping.
var ears_up := false
var phase := 0.0
var breed := 0
var _time := 0.0
var _bones: Dictionary = {}


func _process_modification_with_delta(delta: float) -> void:
	var rig := get_skeleton()
	if rig == null:
		return
	_time += delta
	if _bones.is_empty():
		for name_: String in ["head", "chest", "tailstart", "tail1", "tail2", "tail3", "earend", "R_earend"]:
			_bones[name_] = rig.find_bone(name_)
	if knocked_out:
		if ears_up:
			for i in 2:
				_rotate(rig, "earend" if i == 0 else "R_earend", Vector3.RIGHT,
					deg_to_rad(-75.0 + sin(_time * 22.0 + i * 1.3) * 18.0))
		return
	var anticipation := smoothstep(0.0, 1.0, charge) if charging else 0.0
	# Ears and tail have different follow-through per breed, without altering hit geometry.
	var beat := _time * (7.0 if celebrating else 4.2 + speed * 3.0) + phase
	var wag := (18.0 if celebrating else 7.0 + speed * 4.0) * (0.35 if charging or dashing else 1.0)
	for i in 4:
		var bone_name := "tailstart" if i == 0 else "tail%d" % i
		_rotate(rig, bone_name, Vector3.UP, sin(beat - i * 0.45) * deg_to_rad(wag * (1.0 + i * 0.12)))
	for i in 2:
		_rotate(rig, "earend" if i == 0 else "R_earend", Vector3.RIGHT,
			deg_to_rad(sin(beat * 1.4 - i * 0.8) * speed * (3.0 if breed == DogData.Breed.CORGI else 8.0) - anticipation * 12.0))
	_rotate(rig, "head", Vector3.RIGHT, deg_to_rad(anticipation * 24.0))
	_rotate(rig, "chest", Vector3.RIGHT, deg_to_rad(anticipation * 9.0))
	if speed < 0.08 and not charging and not celebrating:
		_rotate(rig, "head", Vector3.UP, sin(_time * 0.8 + phase) * deg_to_rad(5.0))


func _rotate(rig: Skeleton3D, name_: String, axis: Vector3, angle: float) -> void:
	var index: int = _bones.get(name_, -1)
	if index < 0:
		return
	var local_axis := axis
	var parent := rig.get_bone_parent(index)
	if parent >= 0:
		local_axis = rig.get_bone_global_pose(parent).basis.orthonormalized().inverse() * axis
	rig.set_bone_pose_rotation(index, Quaternion(local_axis.normalized(), angle) * rig.get_bone_pose_rotation(index))
