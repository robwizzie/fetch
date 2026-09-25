class_name MenuDogMotion
extends SkeletonModifier3D
## Idle life for a dog standing on a menu card: a tail that actually swishes.
##
## The authored idle clip moves the tail a couple of degrees, which reads on a long feathered
## tail like Posey's and on nobody else's. This layers a real wag over whatever the clip is
## doing. It is a SkeletonModifier3D rather than a _process() hook because a modifier runs
## after the AnimationPlayer has posed the rig, so the two compose instead of fighting over
## the same bones on alternate frames.
##
## There is deliberately no blink. The pack shares one 27-bone quadruped rig with no eyelids,
## no eye bones and no blend shapes, so nothing here can close an eye; squashing the head
## shortens the whole face, which reads as a squash and not as a blink. A real one needs the
## art to carry it - a `blink` blend shape on the head mesh, or lid geometry to rotate - and
## once a delivery has either, this is the place to drive it from.

## The tail chain, base first. Any bone the rig does not have is skipped, so a differently
## named rig quietly gets less motion rather than an error.
const TAIL_BONES: Array[StringName] = [&"tailstart", &"tail1", &"tail2", &"tail3"]
const EAR_BONES: Array[StringName] = [&"earend", &"R_earend"]

## Wag: degrees at the base of the tail, and how much more each joint out adds. The lag down
## the chain is what makes it a swish rather than a windscreen wiper.
const WAG_DEGREES := 11.0
const WAG_GAIN := 0.42
const WAG_SPEED := 5.2
const WAG_LAG := 0.5
## A wag is not metronomic: the speed drifts a little over this cycle.
const WAG_DRIFT := 0.22
const WAG_DRIFT_SPEED := 0.6
## Ears sway with it, at half the speed and a fraction of the throw.
const EAR_DEGREES := 6.0

## Which way is up in the skeleton's own space. Set by whoever builds the preview, because a
## menu model hangs off nodes that are rotated and scaled before the rig is reached.
var up := Vector3.UP
## Where in the wag this dog starts, so a row of four cards does not swish in lockstep.
var phase := 0.0

var _tail: Array[int] = []
var _ears: Array[int] = []
var _resolved := false
var _time := 0.0


func _process_modification_with_delta(delta: float) -> void:
	var skeleton := get_skeleton()
	if skeleton == null:
		return
	if not _resolved:
		_resolve(skeleton)
	_time += delta
	var speed: float = WAG_SPEED * (1.0 + sin(_time * WAG_DRIFT_SPEED + phase) * WAG_DRIFT)
	var beat := _time * speed + phase
	for i in _tail.size():
		var swing: float = sin(beat - i * WAG_LAG) * deg_to_rad(WAG_DEGREES * (1.0 + i * WAG_GAIN))
		_turn(skeleton, _tail[i], swing)
	for i in _ears.size():
		# The ears take turns rather than moving together, which is what stops the pair of
		# them reading as one flapping shape.
		var flick: float = sin(beat * 0.5 - PI * i) * deg_to_rad(EAR_DEGREES)
		_turn(skeleton, _ears[i], flick)


func _resolve(skeleton: Skeleton3D) -> void:
	_resolved = true
	for bone_name in TAIL_BONES:
		var index := skeleton.find_bone(bone_name)
		if index >= 0:
			_tail.append(index)
	for bone_name in EAR_BONES:
		var index := skeleton.find_bone(bone_name)
		if index >= 0:
			_ears.append(index)


## Rotates a bone around the model's own up axis, on top of whatever the clip posed it to.
## Done in the parent's space so the swing is always side to side, whichever way the rig
## happens to have pointed that bone.
func _turn(skeleton: Skeleton3D, bone: int, angle: float) -> void:
	var parent := skeleton.get_bone_parent(bone)
	var axis := up
	if parent >= 0:
		axis = skeleton.get_bone_global_pose(parent).basis.orthonormalized().inverse() * up
	skeleton.set_bone_pose_rotation(bone, Quaternion(axis.normalized(), angle) * skeleton.get_bone_pose_rotation(bone))
