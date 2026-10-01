extends Node
## Executes the real Godot GLB importer + runtime renderer, including animated world sockets.

var _failures := 0


func _ready() -> void:
	for dog in Game.dogs:
		var readiness := DogAssetValidator.inspect(dog)
		_check(readiness.valid or not readiness.errors.is_empty(), "%s has an actionable readiness result" % dog.display_name)
	var missing := Game.dogs[0].duplicate() as DogData
	missing.model_scene = null
	missing.model_scene_path = "res://tests/fixtures/not_delivered.glb"
	var fallback := DogModel.new()
	add_child(fallback)
	fallback.setup(missing, Color.WHITE)
	_check(not fallback.uses_authored_model, "missing assets render safe gameplay placeholder")
	fallback.position = Vector3(4, 0, 7)
	fallback.update_motion(Vector3.RIGHT, 1.0, 1.0)
	var fallback_local := fallback.to_local(fallback.get_mouth_transform().origin)
	_check(fallback_local.x > 0.3 and fallback_local.y > 0.1, "placeholder mouth moves and rotates with the animated head")
	fallback.queue_free()

	var data := DogData.new()
	data.model_scene_path = "res://tests/fixtures/rig_contract.glb"
	var report := DogAssetValidator.inspect(data)
	_check(report.valid, "actual imported skinned GLB meets contract: %s" % str(report.errors))
	_check(not report.likeness_reviewed, "a valid GLB does not imply approved likeness")
	if not report.valid:
		get_tree().quit(1)
		return
	var imported := DogModel.new()
	add_child(imported)
	imported.setup(data, Color.WHITE)
	_check(imported.uses_authored_model, "valid rig uses authored renderer")
	imported.position = Vector3(3, 1, 5)
	await get_tree().process_frame
	await get_tree().process_frame
	var mouth_before := imported.get_mouth_transform().origin
	_check(mouth_before.distance_to(imported.global_position) > 0.5, "mouth uses actual rig socket, not dog origin")
	imported._tree.advance(0.16)
	await get_tree().process_frame
	var mouth_after := imported.get_mouth_transform().origin
	_check(mouth_before.distance_to(mouth_after) > 0.03, "mouth follows animated bone in world space")
	imported.update_motion(Vector3.FORWARD, 1.0, 0.1)
	_check(imported._active_state == "run", "locomotion selects run")
	imported.play_throw()
	_check(imported._active_state == "throw", "throw plays one-shot")
	# Frame-sized steps, as in play: the step that fires a one-shot does not also run it.
	for i in 10:
		imported._tree.advance(0.05)
	await get_tree().process_frame
	_check(imported._active_state == "run", "throw returns to queued locomotion")
	imported.set_dashing(true)
	_check(imported._active_state == "dash", "dash selects authored dash clip")
	imported.set_dashing(false)
	imported.play_knocked_out(Vector3.FORWARD)
	_check(imported._active_state == "ko", "KO interrupts locomotion")
	imported.update_motion(Vector3.RIGHT, 1.0, 0.1)
	_check(imported._active_state == "ko", "KO holds terminal state")
	imported.queue_free()

	var bad := data.duplicate() as DogData
	bad.mouth_socket_bone = &"MissingBone"
	var invalid_socket := DogAssetValidator.inspect(bad)
	_check(not invalid_socket.valid, "missing mouth bone is rejected")
	bad = data.duplicate() as DogData
	bad.model_animations = data.model_animations.duplicate()
	bad.model_animations["throw"] = &"not_exported"
	var invalid_animation := DogAssetValidator.inspect(bad)
	_check(not invalid_animation.valid, "missing animation is rejected")
	var safe := DogModel.new()
	add_child(safe)
	safe.setup(bad, Color.WHITE)
	_check(not safe.uses_authored_model, "invalid imported model safely falls back")
	safe.queue_free()
	var studio: Node = load("res://scenes/ui/model_review.tscn").instantiate()
	add_child(studio)
	await get_tree().process_frame
	_check(studio.get("_model") != null, "model studio loads with visible runtime model")
	studio.queue_free()
	await get_tree().process_frame
	for dog in Game.dogs:
		await _check_motion(dog)
	print("[asset-pipeline] %s (%d failures)" % ["PASSED" if _failures == 0 else "FAILED", _failures])
	get_tree().quit(0 if _failures == 0 else 1)


## The generated clips on the real pack. Each of these was broken once: the rig is Z-up, so the
## win hop slid the dog along the floor, and a run arc that ignored how the legs stand at rest
## dug paws into the ground; a throw also froze the legs mid-stride.
func _check_motion(data: DogData) -> void:
	var model := DogModel.new()
	add_child(model)
	model.setup(data, Color.WHITE)
	if not model.uses_authored_model:
		model.queue_free()
		return
	var skeleton := model.find_child("Skeleton3D", true, false) as Skeleton3D
	var player := model._player
	var height := func(bone: String) -> float:
		return (skeleton.global_transform * skeleton.get_bone_global_pose(skeleton.find_bone(bone))).origin.y
	model._tree.active = false
	skeleton.reset_bone_poses()
	var floor_y: float = height.call("backleg2")
	var hips_rest: float = height.call("Hips")
	var lowest := INF
	var highest := -INF
	player.play(data.model_animations.get("run", &"run"))
	for i in 24:
		player.seek(player.current_animation_length * i / 24.0, true)
		for paw in ["frontleg2", "R_frontleg2", "backleg2", "R_backleg2"]:
			var y: float = height.call(paw) - floor_y if paw.begins_with("back") else 0.0
			lowest = minf(lowest, y)
			highest = maxf(highest, y)
	_check(lowest > -0.06, "%s: run keeps hind paws out of the floor (lowest %.2f m)" % [data.display_name, lowest])
	_check(highest > 0.05, "%s: run lifts the paws clear on the swing" % data.display_name)
	var hop := -INF
	player.play(data.model_animations.get("win", &"win"))
	for i in 20:
		player.seek(player.current_animation_length * i / 20.0, true)
		hop = maxf(hop, height.call("Hips") - hips_rest)
	_check(hop > 0.08, "%s: the win hop leaves the ground (%.2f m)" % [data.display_name, hop])
	player.stop()
	model._tree.active = true
	model.update_motion(Vector3.FORWARD, 1.0, 0.1)
	for i in 8:
		model._tree.advance(0.05)
	model.play_throw()
	var leg := skeleton.find_bone("backleg")
	var poses: Array[Quaternion] = []
	for i in 6:
		model._tree.advance(0.05)
		poses.append(skeleton.get_bone_pose_rotation(leg))
	_check(poses[0].angle_to(poses[5]) > 0.05, "%s: hind legs keep running through a throw" % data.display_name)
	model.queue_free()
	await get_tree().process_frame


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error("[asset-pipeline] " + message)
	else:
		print("[asset-pipeline] OK: " + message)
