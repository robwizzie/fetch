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
	imported._player.advance(0.16)
	await get_tree().process_frame
	var mouth_after := imported.get_mouth_transform().origin
	_check(mouth_before.distance_to(mouth_after) > 0.03, "mouth follows animated bone in world space")
	imported.update_motion(Vector3.FORWARD, 1.0, 0.1)
	_check(imported._active_state == "run", "locomotion selects run")
	imported.play_throw()
	_check(imported._active_state == "throw", "throw plays one-shot")
	imported._player.advance(0.5)
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
	print("[asset-pipeline] %s (%d failures)" % ["PASSED" if _failures == 0 else "FAILED", _failures])
	get_tree().quit(0 if _failures == 0 else 1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error("[asset-pipeline] " + message)
	else:
		print("[asset-pipeline] OK: " + message)
