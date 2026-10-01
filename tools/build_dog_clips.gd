extends Node
## Bakes the seven gameplay clips onto an authored dog rig and saves a wrapper scene.
##
## Generated GLBs arrive with at most a stock locomotion cycle, and the game needs
## idle/run/throw/catch/dash/ko/win. Hand animation is the right long-term answer; this fills
## the gap so an authored dog is playable the day it lands, and each clip can be replaced
## individually later by re-exporting it from Blender under the same name.
##
##   godot --headless --path . res://tools/build_dog_clips.tscn -- --dog=shadow --walk="<clip>"
##
## Poses are written in the dog's own frame - pitch up, yaw left, roll right, offsets in metres
## up and forward - and converted onto each bone here. Meshy rigs come out of Blender Z-up with
## the body along the skeleton's Y, so keying a bone's local axes directly (what this tool used
## to do) turned every hop into a slide and every flop onto the side into a spin on the spot.
## Works on any rig that uses the quadruped bone names Meshy produces.

const SKELETON_PATH := "Armature/Skeleton3D"

var dog_id := "shadow"
var walk_clip := ""
var _to_skeleton := Basis.IDENTITY
var _rotation_to_skeleton := Basis.IDENTITY


func _ready() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--dog="):
			dog_id = argument.trim_prefix("--dog=")
		elif argument.begins_with("--walk="):
			walk_clip = argument.trim_prefix("--walk=")
	var source := "res://assets/models/dogs/%s/%s.glb" % [dog_id, dog_id]
	if not ResourceLoader.exists(source):
		push_error("No GLB at " + source)
		get_tree().quit(1)
		return
	var root: Node3D = load(source).instantiate()
	add_child(root)
	var skeleton := root.get_node_or_null(SKELETON_PATH) as Skeleton3D
	var player := root.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if skeleton == null or player == null:
		push_error("Expected %s and an AnimationPlayer in %s" % [SKELETON_PATH, source])
		get_tree().quit(1)
		return

	# Dog space -> skeleton space. Includes the export scale, so offsets can be written in metres.
	_to_skeleton = skeleton.global_transform.basis.inverse()
	_rotation_to_skeleton = skeleton.global_transform.basis.orthonormalized().inverse()

	var library := player.get_animation_library(&"")
	if walk_clip.is_empty():
		for existing in library.get_animation_list():
			walk_clip = existing
			break
	print("[clips] source walk clip: %s" % walk_clip)

	# The delivered cycle is authored for long-legged proportions and sinks a chibi body into
	# the ground when retargeted, so run is rebuilt here. The original stays in the library
	# under its own name for comparison.
	_replace(library, "run", _complete_clip(_run(skeleton), skeleton))
	_replace(library, "idle", _complete_clip(_idle(skeleton), skeleton))
	_replace(library, "throw", _complete_clip(_throw(skeleton), skeleton))
	_replace(library, "catch", _complete_clip(_catch(skeleton), skeleton))
	_replace(library, "dash", _complete_clip(_dash(skeleton), skeleton))
	_replace(library, "ko", _complete_clip(_ko(skeleton), skeleton))
	_replace(library, "win", _complete_clip(_win(skeleton), skeleton))

	for node in _descendants(root):
		node.owner = root
	var packed := PackedScene.new()
	if packed.pack(root) != OK:
		push_error("Could not pack the wrapper scene")
		get_tree().quit(1)
		return
	var target := "res://assets/models/dogs/%s/%s.tscn" % [dog_id, dog_id]
	var err := ResourceSaver.save(packed, target)
	print("[clips] %s -> %s (%s)" % [str(library.get_animation_list()), target, error_string(err)])
	get_tree().quit(0 if err == OK else 1)


## Every bone any clip moves. Each clip keys all of them, at rest where it has nothing to say:
## the player holds an unkeyed bone wherever the last clip left it, so a dog that dashed kept
## its hind legs kicked out behind it through the next idle and throw.
const POSED_BONES := ["Hips", "chest", "head", "tailstart",
	"frontleg", "frontleg0", "frontleg1", "R_frontleg", "R_frontleg0", "R_frontleg1",
	"backleg", "backleg0", "backleg1", "R_backleg", "R_backleg0", "R_backleg1"]


func _complete_clip(animation: Animation, skeleton: Skeleton3D) -> Animation:
	_complete(animation, skeleton)
	return animation


func _complete(animation: Animation, skeleton: Skeleton3D) -> void:
	for bone in POSED_BONES:
		var path := NodePath("%s:%s" % [SKELETON_PATH, bone])
		if animation.find_track(path, Animation.TYPE_ROTATION_3D) < 0:
			_turn(animation, skeleton, bone, [[0.0, Vector3.ZERO]])
	var hips := NodePath("%s:Hips" % SKELETON_PATH)
	if animation.find_track(hips, Animation.TYPE_POSITION_3D) < 0:
		_move(animation, skeleton, "Hips", [[0.0, Vector3.ZERO]])
	if animation.find_track(hips, Animation.TYPE_SCALE_3D) < 0:
		_squash(animation, skeleton, "Hips", [[0.0, Vector3.ONE]])


func _replace(library: AnimationLibrary, name_: String, animation: Animation) -> void:
	if library.has_animation(StringName(name_)):
		library.remove_animation(StringName(name_))
	library.add_animation(StringName(name_), animation)


func _descendants(node: Node) -> Array[Node]:
	var out: Array[Node] = []
	for child in node.get_children():
		out.append(child)
		out.append_array(_descendants(child))
	return out


# ---------------------------------------------------------------- track helpers
#
# Every pose below is in the dog's frame, not the bone's: Vector3(pitch up, yaw left, roll right)
# in degrees. "Pitch up" swings a bone's far end upward and forward, so on a leg it reaches the
# paw forward and on the head it lifts the nose. Offsets are metres (x left, y up, z forward).
# All tracks are cubic: linear keys between a handful of poses are what made the old clips tick
# from pose to pose like a wind-up toy.

## Keys a bone's rotation relative to rest. [param keys] is [[time, Vector3 degrees], ...].
func _turn(animation: Animation, skeleton: Skeleton3D, bone: String, keys: Array) -> void:
	var index := skeleton.find_bone(bone)
	if index < 0:
		return
	var rest := skeleton.get_bone_rest(index).basis.get_rotation_quaternion()
	var parent := skeleton.get_bone_parent(index)
	var frame := Quaternion.IDENTITY
	if parent >= 0:
		frame = skeleton.get_bone_global_rest(parent).basis.orthonormalized().get_rotation_quaternion()
	var to_skeleton := Quaternion(_rotation_to_skeleton)
	var track := _track(animation, Animation.TYPE_ROTATION_3D, bone)
	for key in keys:
		var degrees: Vector3 = key[1]
		var dog := Quaternion(Vector3.UP, deg_to_rad(degrees.y)) \
			* Quaternion(Vector3.RIGHT, deg_to_rad(-degrees.x)) \
			* Quaternion(Vector3.BACK, deg_to_rad(degrees.z))
		# The same turn, about the same pivot, seen from the parent's rest frame.
		var in_skeleton := to_skeleton * dog * to_skeleton.inverse()
		animation.rotation_track_insert_key(track, float(key[0]), (frame.inverse() * in_skeleton * frame * rest).normalized())


## Keys a bone's position as an offset from rest, in metres in the dog's frame.
func _move(animation: Animation, skeleton: Skeleton3D, bone: String, keys: Array) -> void:
	var index := skeleton.find_bone(bone)
	if index < 0:
		return
	var rest := skeleton.get_bone_rest(index).origin
	var parent := skeleton.get_bone_parent(index)
	var frame := Basis.IDENTITY
	if parent >= 0:
		frame = skeleton.get_bone_global_rest(parent).basis
	var track := _track(animation, Animation.TYPE_POSITION_3D, bone)
	for key in keys:
		var offset: Vector3 = key[1]
		animation.position_track_insert_key(track, float(key[0]), rest + frame.inverse() * (_to_skeleton * offset))


## Keys a bone's scale for squash and stretch. Factors are (width, height, length) of the dog.
func _squash(animation: Animation, skeleton: Skeleton3D, bone: String, keys: Array) -> void:
	var index := skeleton.find_bone(bone)
	if index < 0:
		return
	var rest := skeleton.get_bone_rest(index).basis.get_scale()
	var m := _rotation_to_skeleton
	var track := _track(animation, Animation.TYPE_SCALE_3D, bone)
	for key in keys:
		var f: Vector3 = key[1]
		var mapped := m.x.abs() * f.x + m.y.abs() * f.y + m.z.abs() * f.z
		animation.scale_track_insert_key(track, float(key[0]), rest * mapped)


## Samples [param pose] (cycle position 0..1 -> degrees) around a loop, ending where it began.
func _cycle_turn(animation: Animation, skeleton: Skeleton3D, bone: String, samples: int, pose: Callable) -> void:
	var keys := []
	for i in samples + 1:
		var t := float(i) / float(samples)
		keys.append([t * animation.length, pose.call(fmod(t, 1.0))])
	_turn(animation, skeleton, bone, keys)


func _cycle_move(animation: Animation, skeleton: Skeleton3D, bone: String, samples: int, offset: Callable) -> void:
	var keys := []
	for i in samples + 1:
		var t := float(i) / float(samples)
		keys.append([t * animation.length, offset.call(fmod(t, 1.0))])
	_move(animation, skeleton, bone, keys)


func _track(animation: Animation, type: Animation.TrackType, bone: String) -> int:
	var track := animation.add_track(type)
	animation.track_set_path(track, NodePath("%s:%s" % [SKELETON_PATH, bone]))
	animation.track_set_interpolation_type(track, Animation.INTERPOLATION_CUBIC)
	return track


func _new(length: float, loop: bool) -> Animation:
	var animation := Animation.new()
	animation.length = length
	animation.loop_mode = Animation.LOOP_LINEAR if loop else Animation.LOOP_NONE
	return animation


## Left legs and right legs, so a pose can splay them outward symmetrically.
const LEFT_LEGS := ["frontleg", "backleg"]
const RIGHT_LEGS := ["R_frontleg", "R_backleg"]


# ---------------------------------------------------------------- the clips
#
# The tail and ears are left to DogPoseMotion, which wags and flaps them live from speed and
# mood. Keying them here as well made the two fight.

## Standing about: a slow breath through the chest, a little weight shift from paw to paw, and a
## head that settles rather than freezes.
func _idle(skeleton: Skeleton3D) -> Animation:
	var a := _new(2.4, true)
	_cycle_move(a, skeleton, "Hips", 8, func(t: float) -> Vector3:
		return Vector3(0, -0.006 * (0.5 - 0.5 * cos(TAU * t * 2.0)), 0))
	_cycle_turn(a, skeleton, "Hips", 8, func(t: float) -> Vector3:
		return Vector3(0, 0, 1.4 * sin(TAU * t)))
	_cycle_turn(a, skeleton, "chest", 8, func(t: float) -> Vector3:
		return Vector3(1.8 * (0.5 - 0.5 * cos(TAU * t * 2.0)), 0, -1.0 * sin(TAU * t)))
	_cycle_turn(a, skeleton, "head", 8, func(t: float) -> Vector3:
		return Vector3(-1.5 * (0.5 - 0.5 * cos(TAU * t * 2.0)) + 1.0, 0, 2.0 * sin(TAU * t + 0.6)))
	return a


const RUN_REACH_FRONT := 28.0
const RUN_REACH_BACK := 24.0
const RUN_FOLD_FRONT0 := 20.0
const RUN_FOLD_FRONT1 := 34.0
const RUN_FOLD_BACK0 := -24.0
const RUN_FOLD_BACK1 := 30.0
const RUN_BOB := 0.045


## A leg's joints in the dog's side plane: (forward, up) for the hip, knee, ankle and paw, in
## metres. Every leg joint here bends about the dog's sideways axis, so a leg is a planar chain
## and its paw can be placed with a few lines of trigonometry instead of a physics pass.
func _leg_points(skeleton: Skeleton3D, bone: String) -> Array[Vector2]:
	var points: Array[Vector2] = []
	var to_dog := skeleton.global_transform
	for joint in [bone, bone + "0", bone + "1", bone + "2"]:
		var index := skeleton.find_bone(joint)
		if index < 0:
			return []
		var at := to_dog * skeleton.get_bone_global_rest(index).origin
		points.append(Vector2(at.z, at.y))
	return points


## Where the paw ends up, relative to the hip, for pitch-up angles at the three joints.
func _paw(points: Array[Vector2], top: float, knee: float, ankle: float) -> Vector2:
	var hip := points[0]
	var a := deg_to_rad(top)
	var b := a + deg_to_rad(knee)
	var c := b + deg_to_rad(ankle)
	return (points[1] - hip).rotated(a) + (points[2] - points[1]).rotated(b) + (points[3] - points[2]).rotated(c)


## Fits a leg's stance: the centre of its swing and a constant knee bend that keep the paw on the
## floor from the front of the stride to the back, with the body bobbing as the run clip moves it.
## Rigs stand their legs at very different angles (Posey's hind legs rake back nearly 30 degrees),
## and an arc that is merely centred on vertical digs the paw in, while one centred on the rest
## pose lifts it off at one end. Returns Vector2(centre, knee bend) in degrees.
func _fit_stance(points: Array[Vector2], reach: float, offset: float, bob: Callable) -> Vector2:
	if points.is_empty():
		return Vector2.ZERO
	var floor_ := _paw(points, 0.0, 0.0, 0.0).y
	var best := Vector2.ZERO
	var best_error := INF
	for centre_step in range(-40, 41):
		for bend_step in range(-30, 31):
			var centre := float(centre_step)
			var bend := float(bend_step)
			var error := absf(bend) * 0.00002
			for i in 12:
				var t := float(i) / 12.0
				# Stance is the half of the cycle with no paw lift (see _run).
				if -sin(TAU * (t + offset)) > 0.0:
					continue
				var top := centre + reach * cos(TAU * (t + offset))
				var drop: float = _paw(points, top, bend, -bend).y + bob.call(t) - floor_
				error += drop * drop
			if error < best_error:
				best_error = error
				best = Vector2(centre, bend)
	return best


## A bouncy diagonal trot. Front-left moves with back-right. Each leg reaches forward, plants,
## sweeps back under the body, then folds at the lower joint to lift the paw clear on the way
## forward again. The body rides highest when the legs are spread and lowest when they pass
## under it; the head counters that so the face stays steady.
func _run(skeleton: Skeleton3D) -> Animation:
	var a := _new(0.5, true)
	const SAMPLES := 12
	# Lowest when the legs are spread: a leg swinging through an arc is shorter at its ends, and
	# the body has to come down with it for the planted paws to stay on the floor.
	var bob := func(t: float) -> float:
		return RUN_BOB * (0.5 - 0.5 * cos(TAU * t * 2.0)) - RUN_BOB * 0.7
	for leg in [["frontleg", 0.0, true], ["R_backleg", 0.0, false], ["R_frontleg", 0.5, true], ["backleg", 0.5, false]]:
		var bone: String = leg[0]
		var offset: float = leg[1]
		var front: bool = leg[2]
		var reach := RUN_REACH_FRONT if front else RUN_REACH_BACK
		# Fitted per rig so the planted paw stays on the floor through the stance.
		var fit := _fit_stance(_leg_points(skeleton, bone), reach, offset, bob)
		var centre := fit.x
		var bend := fit.y
		_cycle_turn(a, skeleton, bone, SAMPLES, func(t: float) -> Vector3:
			return Vector3(centre + reach * cos(TAU * (t + offset)), 0, 0))
		# Lifting the paw: only while the leg travels forward (the swing), never while planted.
		_cycle_turn(a, skeleton, bone + "0", SAMPLES, func(t: float) -> Vector3:
			var lift := maxf(0.0, -sin(TAU * (t + offset)))
			return Vector3(bend + (RUN_FOLD_FRONT0 if front else RUN_FOLD_BACK0) * lift, 0, 0))
		_cycle_turn(a, skeleton, bone + "1", SAMPLES, func(t: float) -> Vector3:
			var lift := maxf(0.0, -sin(TAU * (t + offset)))
			return Vector3(-bend + (RUN_FOLD_FRONT1 if front else RUN_FOLD_BACK1) * lift, 0, 0))
	_cycle_move(a, skeleton, "Hips", SAMPLES, func(t: float) -> Vector3:
		return Vector3(0, bob.call(t), 0))
	_cycle_turn(a, skeleton, "Hips", SAMPLES, func(t: float) -> Vector3:
		return Vector3(0, 0, 2.5 * cos(TAU * t)))
	_cycle_turn(a, skeleton, "chest", SAMPLES, func(t: float) -> Vector3:
		return Vector3(-3.0 - 2.5 * sin(TAU * t * 2.0), 2.0 * cos(TAU * t), 0))
	_cycle_turn(a, skeleton, "head", SAMPLES, func(t: float) -> Vector3:
		return Vector3(2.0 - 3.0 * cos(TAU * t * 2.0), -2.0 * cos(TAU * t), 0))
	return a


## The release. The wind-up is the hold (DogModel and DogPoseMotion rock the dog back, head
## tucked, while it charges), so this starts at the snap: the head flings up and forward to let
## the toy go, the chest and front paws come up with it, then it all drops back past neutral and
## settles. Under 0.4 s, so DogModel plays it whole rather than trimming a wind-up off the front.
func _throw(skeleton: Skeleton3D) -> Animation:
	var a := _new(0.38, false)
	_turn(a, skeleton, "head", [[0.0, Vector3(-14, 0, 0)], [0.06, Vector3(26, 0, 0)], [0.17, Vector3(-7, 0, 0)], [0.27, Vector3(3, 0, 0)], [0.38, Vector3.ZERO]])
	_turn(a, skeleton, "chest", [[0.0, Vector3(-6, 0, 0)], [0.07, Vector3(10, 0, 0)], [0.19, Vector3(-3, 0, 0)], [0.38, Vector3.ZERO]])
	for bone in ["frontleg", "R_frontleg"]:
		_turn(a, skeleton, bone, [[0.0, Vector3(-4, 0, 0)], [0.07, Vector3(16, 0, 0)], [0.2, Vector3(-3, 0, 0)], [0.38, Vector3.ZERO]])
	_move(a, skeleton, "Hips", [[0.0, Vector3.ZERO], [0.07, Vector3(0, 0.015, 0.03)], [0.2, Vector3(0, -0.01, 0)], [0.38, Vector3.ZERO]])
	return a


## A snap at the toy: the dog pops up off its front paws, head up and mouth first, then drops
## back onto its paws with a small squash.
func _catch(skeleton: Skeleton3D) -> Animation:
	var a := _new(0.4, false)
	_turn(a, skeleton, "head", [[0.0, Vector3.ZERO], [0.07, Vector3(24, 0, 0)], [0.2, Vector3(10, 0, 0)], [0.31, Vector3(-4, 0, 0)], [0.4, Vector3.ZERO]])
	_turn(a, skeleton, "chest", [[0.0, Vector3.ZERO], [0.08, Vector3(13, 0, 0)], [0.22, Vector3(4, 0, 0)], [0.4, Vector3.ZERO]])
	for bone in ["frontleg", "R_frontleg"]:
		_turn(a, skeleton, bone, [[0.0, Vector3.ZERO], [0.08, Vector3(32, 0, 0)], [0.22, Vector3(10, 0, 0)], [0.4, Vector3.ZERO]])
		_turn(a, skeleton, bone + "1", [[0.0, Vector3.ZERO], [0.08, Vector3(-30, 0, 0)], [0.24, Vector3(-6, 0, 0)], [0.4, Vector3.ZERO]])
	_move(a, skeleton, "Hips", [[0.0, Vector3.ZERO], [0.08, Vector3(0, 0.04, 0)], [0.25, Vector3(0, -0.015, 0)], [0.4, Vector3.ZERO]])
	_squash(a, skeleton, "Hips", [[0.0, Vector3.ONE], [0.08, Vector3(0.96, 1.06, 0.96)], [0.25, Vector3(1.05, 0.93, 1.05)], [0.4, Vector3.ONE]])
	return a


## Flat out: front paws reaching, back paws kicked out behind, body low and long, with a quick
## flutter so the pose is in motion rather than a still.
func _dash(skeleton: Skeleton3D) -> Animation:
	var a := _new(0.24, true)
	const SAMPLES := 6
	_cycle_turn(a, skeleton, "chest", SAMPLES, func(t: float) -> Vector3:
		return Vector3(2.0 + 2.0 * sin(TAU * t), 0, 0))
	_cycle_turn(a, skeleton, "head", SAMPLES, func(t: float) -> Vector3:
		return Vector3(12.0 - 2.0 * sin(TAU * t), 0, 0))
	for bone in ["frontleg", "R_frontleg"]:
		_cycle_turn(a, skeleton, bone, SAMPLES, func(t: float) -> Vector3:
			return Vector3(52.0 + 5.0 * sin(TAU * t), 0, 0))
		_cycle_turn(a, skeleton, bone + "1", SAMPLES, func(_t: float) -> Vector3:
			return Vector3(14.0, 0, 0))
	for bone in ["backleg", "R_backleg"]:
		_cycle_turn(a, skeleton, bone, SAMPLES, func(t: float) -> Vector3:
			return Vector3(-50.0 - 5.0 * sin(TAU * t), 0, 0))
	_cycle_move(a, skeleton, "Hips", SAMPLES, func(t: float) -> Vector3:
		return Vector3(0, 0.03 + 0.01 * sin(TAU * t), 0))
	return a


## Bonked. DogModel throws the whole body through the air and onto its side (it knows which way
## the toy came from; a clip cannot), so this is what the body does on the way: snapped back by
## the hit, limbs flung out, then landing limp - legs splayed, head lolling, out cold.
func _ko(skeleton: Skeleton3D) -> Animation:
	var a := _new(0.9, false)
	_turn(a, skeleton, "head", [[0.0, Vector3.ZERO], [0.06, Vector3(34, 0, 0)], [0.24, Vector3(18, 10, 0)], [0.44, Vector3(-16, 16, 6)], [0.6, Vector3(-10, 14, 4)], [0.9, Vector3(-13, 15, 5)]])
	_turn(a, skeleton, "chest", [[0.0, Vector3.ZERO], [0.06, Vector3(14, 0, 0)], [0.44, Vector3(-4, 0, 0)], [0.9, Vector3(-2, 0, 0)]])
	for bone in LEFT_LEGS + RIGHT_LEGS:
		var front: bool = bone.contains("front")
		var outward := -1.0 if bone in LEFT_LEGS else 1.0
		var swing := 38.0 if front else -34.0
		_turn(a, skeleton, bone, [
			[0.0, Vector3.ZERO],
			[0.1, Vector3(swing * 1.3, 0, outward * 30.0)],
			[0.44, Vector3(swing, 0, outward * 22.0)],
			[0.58, Vector3(swing * 0.85, 0, outward * 18.0)],
			[0.9, Vector3(swing * 0.9, 0, outward * 19.0)]])
		_turn(a, skeleton, bone + "1", [[0.0, Vector3.ZERO], [0.1, Vector3(-18, 0, 0)], [0.44, Vector3(-8, 0, 0)], [0.9, Vector3(-10, 0, 0)]])
	_turn(a, skeleton, "tailstart", [[0.0, Vector3.ZERO], [0.1, Vector3(25, 0, 0)], [0.44, Vector3(-30, 0, 0)], [0.9, Vector3(-26, 0, 0)]])
	return a


## Celebration: hopping on the spot. Crouch, spring up with the front paws tucked and the nose
## in the air, hang for a beat, land soft and squash. Two hops a loop.
func _win(skeleton: Skeleton3D) -> Animation:
	var a := _new(1.0, true)
	var hop := func(keys: Array) -> Array:
		var out := []
		for half in 2:
			for key in keys:
				if half == 1 and key[0] == 0.0:
					continue
				out.append([key[0] + 0.5 * half, key[1]])
		return out
	_move(a, skeleton, "Hips", hop.call([[0.0, Vector3(0, -0.03, 0)], [0.1, Vector3(0, 0.07, 0)], [0.22, Vector3(0, 0.16, 0)], [0.34, Vector3(0, 0.09, 0)], [0.44, Vector3(0, 0.0, 0)], [0.5, Vector3(0, -0.03, 0)]]))
	_squash(a, skeleton, "Hips", hop.call([[0.0, Vector3(1.07, 0.9, 1.07)], [0.1, Vector3(0.95, 1.08, 0.95)], [0.24, Vector3(1.0, 1.0, 1.0)], [0.44, Vector3(0.98, 1.03, 0.98)], [0.5, Vector3(1.07, 0.9, 1.07)]]))
	_turn(a, skeleton, "chest", hop.call([[0.0, Vector3(-4, 0, 0)], [0.12, Vector3(9, 0, 0)], [0.24, Vector3(12, 0, 0)], [0.42, Vector3(2, 0, 0)], [0.5, Vector3(-4, 0, 0)]]))
	_turn(a, skeleton, "head", hop.call([[0.0, Vector3(8, 0, 0)], [0.14, Vector3(18, 0, 0)], [0.26, Vector3(14, 0, 0)], [0.44, Vector3(10, 0, 0)], [0.5, Vector3(8, 0, 0)]]))
	for bone in ["frontleg", "R_frontleg"]:
		_turn(a, skeleton, bone, hop.call([[0.0, Vector3(0, 0, 0)], [0.12, Vector3(30, 0, 0)], [0.24, Vector3(44, 0, 0)], [0.4, Vector3(10, 0, 0)], [0.5, Vector3(0, 0, 0)]]))
		_turn(a, skeleton, bone + "1", hop.call([[0.0, Vector3(0, 0, 0)], [0.14, Vector3(-40, 0, 0)], [0.26, Vector3(-48, 0, 0)], [0.42, Vector3(-8, 0, 0)], [0.5, Vector3(0, 0, 0)]]))
	for bone in ["backleg", "R_backleg"]:
		_turn(a, skeleton, bone, hop.call([[0.0, Vector3(6, 0, 0)], [0.12, Vector3(-18, 0, 0)], [0.26, Vector3(-10, 0, 0)], [0.44, Vector3(2, 0, 0)], [0.5, Vector3(6, 0, 0)]]))
	return a
