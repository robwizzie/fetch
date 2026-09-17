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
## Poses are expressed as degrees relative to each bone's rest, so they work on any rig that
## uses the quadruped bone names Meshy produces.

const SKELETON_PATH := "Armature/Skeleton3D"

var dog_id := "shadow"
var walk_clip := ""


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

	# Skeleton-local units per metre, so offsets below can be written in metres.
	var scale: float = skeleton.global_transform.basis.get_scale().x
	var per_metre: float = 1.0 / maxf(scale, 0.00001)

	var library := player.get_animation_library(&"")
	if walk_clip.is_empty():
		for existing in library.get_animation_list():
			walk_clip = existing
			break
	print("[clips] source walk clip: %s" % walk_clip)

	# The delivered cycle is authored for long-legged proportions and sinks a chibi body into
	# the ground when retargeted, so run is rebuilt here. The original stays in the library
	# under its own name for comparison.
	_replace(library, "run", _run(skeleton, per_metre))
	_replace(library, "idle", _idle(skeleton, per_metre))
	_replace(library, "throw", _throw(skeleton))
	_replace(library, "catch", _catch(skeleton))
	_replace(library, "dash", _dash(skeleton))
	_replace(library, "ko", _ko(skeleton, per_metre))
	_replace(library, "win", _win(skeleton, per_metre))

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

## Keys a bone's local rotation. [param keys] is [[time, Vector3 degrees], ...], relative to rest.
func _rotate(animation: Animation, skeleton: Skeleton3D, bone: String, keys: Array) -> void:
	var index := skeleton.find_bone(bone)
	if index < 0:
		return
	var rest := skeleton.get_bone_rest(index).basis.get_rotation_quaternion()
	var track := animation.add_track(Animation.TYPE_ROTATION_3D)
	animation.track_set_path(track, NodePath("%s:%s" % [SKELETON_PATH, bone]))
	for key in keys:
		var degrees: Vector3 = key[1]
		var delta := Quaternion(Basis.from_euler(Vector3(deg_to_rad(degrees.x), deg_to_rad(degrees.y), deg_to_rad(degrees.z))))
		animation.rotation_track_insert_key(track, float(key[0]), rest * delta)


## Keys a bone's local position. Offsets are in metres and converted to skeleton units.
func _move(animation: Animation, skeleton: Skeleton3D, bone: String, per_metre: float, keys: Array) -> void:
	var index := skeleton.find_bone(bone)
	if index < 0:
		return
	var rest := skeleton.get_bone_rest(index).origin
	var track := animation.add_track(Animation.TYPE_POSITION_3D)
	animation.track_set_path(track, NodePath("%s:%s" % [SKELETON_PATH, bone]))
	for key in keys:
		var offset: Vector3 = key[1]
		animation.position_track_insert_key(track, float(key[0]), rest + offset * per_metre)


## Keys a bone's local scale, for squash and stretch on impacts.
func _squash(animation: Animation, skeleton: Skeleton3D, bone: String, keys: Array) -> void:
	var index := skeleton.find_bone(bone)
	if index < 0:
		return
	var rest := skeleton.get_bone_rest(index).basis.get_scale()
	var track := animation.add_track(Animation.TYPE_SCALE_3D)
	animation.track_set_path(track, NodePath("%s:%s" % [SKELETON_PATH, bone]))
	for key in keys:
		var factor: Vector3 = key[1]
		animation.scale_track_insert_key(track, float(key[0]), rest * factor)


func _new(length: float, loop: bool) -> Animation:
	var animation := Animation.new()
	animation.length = length
	animation.loop_mode = Animation.LOOP_LINEAR if loop else Animation.LOOP_NONE
	return animation


# ---------------------------------------------------------------- the clips

## Breathing, a slow tail sweep and a little head settle.
func _idle(skeleton: Skeleton3D, per_metre: float) -> Animation:
	var a := _new(2.4, true)
	_move(a, skeleton, "Hips", per_metre, [[0.0, Vector3.ZERO], [0.6, Vector3(0, 0.012, 0)], [1.2, Vector3.ZERO], [1.8, Vector3(0, 0.012, 0)], [2.4, Vector3.ZERO]])
	_rotate(a, skeleton, "chest", [[0.0, Vector3.ZERO], [1.2, Vector3(1.6, 0, 0)], [2.4, Vector3.ZERO]])
	_rotate(a, skeleton, "head", [[0.0, Vector3.ZERO], [0.8, Vector3(-2.5, 3.0, 0)], [1.6, Vector3(-1.0, -3.0, 0)], [2.4, Vector3.ZERO]])
	_rotate(a, skeleton, "tailstart", [[0.0, Vector3(0, -11, 0)], [0.6, Vector3(0, 11, 0)], [1.2, Vector3(0, -11, 0)], [1.8, Vector3(0, 11, 0)], [2.4, Vector3(0, -11, 0)]])
	_rotate(a, skeleton, "tail1", [[0.0, Vector3(0, 8, 0)], [0.6, Vector3(0, -8, 0)], [1.2, Vector3(0, 8, 0)], [1.8, Vector3(0, -8, 0)], [2.4, Vector3(0, 8, 0)]])
	return a


## A diagonal trot: front-left swings with back-right, and the body bobs twice a cycle.
func _run(skeleton: Skeleton3D, per_metre: float) -> Animation:
	var a := _new(0.5, true)
	var swing := 30.0
	var reach := 20.0
	# Diagonal pairs move together, which is what reads as a dog running.
	for pair in [["frontleg", "R_backleg", 1.0], ["R_frontleg", "backleg", -1.0]]:
		var lead: String = pair[0]
		var trail: String = pair[1]
		var phase: float = pair[2]
		for bone in [lead, trail]:
			_rotate(a, skeleton, bone, [
				[0.0, Vector3(swing * phase, 0, 0)],
				[0.25, Vector3(-swing * phase, 0, 0)],
				[0.5, Vector3(swing * phase, 0, 0)]])
		# Lower joints trail the upper ones so the legs fold rather than stay rigid.
		for bone in [lead + "0", trail + "0"]:
			_rotate(a, skeleton, bone, [
				[0.0, Vector3(-reach * phase, 0, 0)],
				[0.25, Vector3(reach * phase, 0, 0)],
				[0.5, Vector3(-reach * phase, 0, 0)]])
	_move(a, skeleton, "Hips", per_metre, [[0.0, Vector3(0, 0.016, 0)], [0.125, Vector3.ZERO], [0.25, Vector3(0, 0.016, 0)], [0.375, Vector3.ZERO], [0.5, Vector3(0, 0.016, 0)]])
	_rotate(a, skeleton, "chest", [[0.0, Vector3(-7, 0, 0)], [0.25, Vector3(-4, 0, 0)], [0.5, Vector3(-7, 0, 0)]])
	_rotate(a, skeleton, "head", [[0.0, Vector3(4, 0, 0)], [0.25, Vector3(1, 0, 0)], [0.5, Vector3(4, 0, 0)]])
	_rotate(a, skeleton, "tailstart", [[0.0, Vector3(-14, -16, 0)], [0.25, Vector3(-14, 16, 0)], [0.5, Vector3(-14, -16, 0)]])
	return a


## A wind-up and a sharp flick of the head, where the toy leaves the mouth.
func _throw(skeleton: Skeleton3D) -> Animation:
	var a := _new(0.42, false)
	_rotate(a, skeleton, "head", [[0.0, Vector3.ZERO], [0.13, Vector3(22, 0, 0)], [0.24, Vector3(-32, 0, 0)], [0.42, Vector3.ZERO]])
	_rotate(a, skeleton, "chest", [[0.0, Vector3.ZERO], [0.13, Vector3(8, 0, 0)], [0.24, Vector3(-10, 0, 0)], [0.42, Vector3.ZERO]])
	_rotate(a, skeleton, "tailstart", [[0.0, Vector3.ZERO], [0.24, Vector3(0, 18, 0)], [0.42, Vector3.ZERO]])
	return a


## A snap upward, front legs reaching.
func _catch(skeleton: Skeleton3D) -> Animation:
	var a := _new(0.36, false)
	_rotate(a, skeleton, "head", [[0.0, Vector3.ZERO], [0.10, Vector3(-28, 0, 0)], [0.36, Vector3.ZERO]])
	_rotate(a, skeleton, "chest", [[0.0, Vector3.ZERO], [0.10, Vector3(-12, 0, 0)], [0.36, Vector3.ZERO]])
	_rotate(a, skeleton, "frontleg", [[0.0, Vector3.ZERO], [0.10, Vector3(-24, 0, 0)], [0.36, Vector3.ZERO]])
	_rotate(a, skeleton, "R_frontleg", [[0.0, Vector3.ZERO], [0.10, Vector3(-24, 0, 0)], [0.36, Vector3.ZERO]])
	return a


## Stretched low and forward, held for the length of the lunge.
func _dash(skeleton: Skeleton3D) -> Animation:
	var a := _new(0.3, true)
	_rotate(a, skeleton, "chest", [[0.0, Vector3(-16, 0, 0)], [0.3, Vector3(-16, 0, 0)]])
	_rotate(a, skeleton, "head", [[0.0, Vector3(12, 0, 0)], [0.3, Vector3(12, 0, 0)]])
	_rotate(a, skeleton, "frontleg", [[0.0, Vector3(-38, 0, 0)], [0.3, Vector3(-38, 0, 0)]])
	_rotate(a, skeleton, "R_frontleg", [[0.0, Vector3(-38, 0, 0)], [0.3, Vector3(-38, 0, 0)]])
	_rotate(a, skeleton, "backleg", [[0.0, Vector3(34, 0, 0)], [0.3, Vector3(34, 0, 0)]])
	_rotate(a, skeleton, "R_backleg", [[0.0, Vector3(34, 0, 0)], [0.3, Vector3(34, 0, 0)]])
	_rotate(a, skeleton, "tailstart", [[0.0, Vector3(-22, 0, 0)], [0.3, Vector3(-22, 0, 0)]])
	return a


## Bonked. Five beats so the hit reads at speed: the impact snaps the body back, it leaves the
## ground, slams onto its side, bounces once, and settles. Without the snap and the bounce a
## knockout just looks like the dog lying down.
func _ko(skeleton: Skeleton3D, per_metre: float) -> Animation:
	var a := _new(1.05, false)
	_rotate(a, skeleton, "Hips", [
		[0.0, Vector3.ZERO],
		[0.06, Vector3(-30, -6, 12)],
		[0.20, Vector3(-12, 16, 50)],
		[0.40, Vector3(6, 10, 90)],
		[0.52, Vector3(1, 8, 78)],
		[0.70, Vector3(0, 8, 87)],
		[1.05, Vector3(0, 8, 85)]])
	_move(a, skeleton, "Hips", per_metre, [
		[0.0, Vector3.ZERO],
		[0.06, Vector3(0, 0.06, -0.05)],
		[0.20, Vector3(0, 0.13, -0.12)],
		[0.40, Vector3(0, -0.36, -0.18)],
		[0.52, Vector3(0, -0.27, -0.20)],
		[0.70, Vector3(0, -0.40, -0.21)],
		[1.05, Vector3(0, -0.40, -0.21)]])
	# Compress on the hit, stretch through the air, compress again on landing.
	_squash(a, skeleton, "Hips", [
		[0.0, Vector3.ONE],
		[0.06, Vector3(1.22, 0.78, 1.22)],
		[0.20, Vector3(0.90, 1.16, 0.90)],
		[0.40, Vector3(1.20, 0.82, 1.20)],
		[0.58, Vector3(0.98, 1.03, 0.98)],
		[1.05, Vector3.ONE]])
	_rotate(a, skeleton, "chest", [
		[0.0, Vector3.ZERO], [0.06, Vector3(18, 0, -8)], [0.40, Vector3(-6, 0, -18)],
		[0.70, Vector3(0, 0, -13)], [1.05, Vector3(0, 0, -12)]])
	# The head whips back on the hit, then lolls.
	_rotate(a, skeleton, "head", [
		[0.0, Vector3.ZERO], [0.06, Vector3(-40, 0, 0)], [0.22, Vector3(-16, 8, 0)],
		[0.44, Vector3(20, 0, -14)], [0.62, Vector3(12, 0, -10)], [1.05, Vector3(15, 0, -11)]])
	# Legs fly up on the way over and flop on landing.
	for bone in ["frontleg", "R_frontleg"]:
		_rotate(a, skeleton, bone, [
			[0.0, Vector3.ZERO], [0.10, Vector3(-58, 0, 0)], [0.40, Vector3(-48, 0, 0)],
			[0.58, Vector3(-36, 0, 0)], [1.05, Vector3(-40, 0, 0)]])
	for bone in ["backleg", "R_backleg"]:
		_rotate(a, skeleton, bone, [
			[0.0, Vector3.ZERO], [0.10, Vector3(50, 0, 0)], [0.40, Vector3(42, 0, 0)],
			[0.58, Vector3(30, 0, 0)], [1.05, Vector3(34, 0, 0)]])
	_rotate(a, skeleton, "tailstart", [
		[0.0, Vector3.ZERO], [0.10, Vector3(-30, 0, 0)], [0.40, Vector3(0, 0, -26)],
		[1.05, Vector3(0, 0, -22)]])
	return a


## Celebration: bouncing on the spot with a fast wag and the head held high.
func _win(skeleton: Skeleton3D, per_metre: float) -> Animation:
	var a := _new(1.2, true)
	_move(a, skeleton, "Hips", per_metre, [[0.0, Vector3.ZERO], [0.3, Vector3(0, 0.085, 0)], [0.6, Vector3.ZERO], [0.9, Vector3(0, 0.085, 0)], [1.2, Vector3.ZERO]])
	_rotate(a, skeleton, "chest", [[0.0, Vector3(-6, 0, 0)], [0.3, Vector3(6, 0, 0)], [0.6, Vector3(-6, 0, 0)], [0.9, Vector3(6, 0, 0)], [1.2, Vector3(-6, 0, 0)]])
	_rotate(a, skeleton, "head", [[0.0, Vector3(-14, 0, 0)], [0.3, Vector3(-20, 0, 0)], [0.6, Vector3(-14, 0, 0)], [0.9, Vector3(-20, 0, 0)], [1.2, Vector3(-14, 0, 0)]])
	_rotate(a, skeleton, "tailstart", [[0.0, Vector3(0, -24, 0)], [0.15, Vector3(0, 24, 0)], [0.3, Vector3(0, -24, 0)], [0.45, Vector3(0, 24, 0)], [0.6, Vector3(0, -24, 0)], [0.75, Vector3(0, 24, 0)], [0.9, Vector3(0, -24, 0)], [1.05, Vector3(0, 24, 0)], [1.2, Vector3(0, -24, 0)]])
	for bone in ["frontleg", "R_frontleg"]:
		_rotate(a, skeleton, bone, [[0.0, Vector3.ZERO], [0.3, Vector3(-30, 0, 0)], [0.6, Vector3.ZERO], [0.9, Vector3(-30, 0, 0)], [1.2, Vector3.ZERO]])
	return a
