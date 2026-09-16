class_name DogModel
extends Node3D
## Gameplay-facing renderer. Authored, rigged 3D scenes are the production path.
## The isolated procedural fallback is a temporary placeholder, not reference artwork.

var data: DogData
var player_color := Color.WHITE
var asset_report: Dictionary = {}
var uses_authored_model := false
var _fallback: ProceduralDogModel
var _imported: Node3D
var _socket: Node3D
var _player: AnimationPlayer
var _target_basis := Basis.IDENTITY
var _speed01 := 0.0
var _dashing := false
var _catching := false
var _knocked_out := false
var _victory := false
var _one_shot := ""
var _active_state := ""


func setup(p_data: DogData, p_color: Color) -> void:
	data = p_data
	player_color = p_color
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_fallback = null
	_imported = null
	_socket = null
	_player = null
	uses_authored_model = false
	_dashing = false
	_catching = false
	_knocked_out = false
	_victory = false
	_one_shot = ""
	_active_state = ""
	transform = Transform3D.IDENTITY
	_target_basis = Basis.IDENTITY
	var scene := DogAssetValidator.load_model_scene(data)
	var candidate: Node = scene.instantiate() if scene != null else null
	asset_report = DogAssetValidator.inspect(data, candidate)
	if candidate != null and asset_report.valid:
		_imported = candidate as Node3D
		add_child(_imported)
		_imported.position = data.model_offset
		_imported.rotation_degrees = data.model_rotation_degrees
		_imported.scale = Vector3.ONE * data.model_import_scale
		scale = Vector3.ONE * data.model_scale
		_socket = DogAssetValidator.find_socket(_imported, data)
		if _socket == null:
			var skeleton := DogAssetValidator.find_socket_skeleton(_imported, data)
			var attachment := BoneAttachment3D.new()
			attachment.name = "RuntimeMouthAttachment"
			attachment.bone_name = data.mouth_socket_bone
			skeleton.add_child(attachment)
			var marker := Marker3D.new()
			marker.name = "MouthSocket"
			attachment.add_child(marker)
			_socket = marker
		_player = DogAssetValidator.find_animation_player(_imported, data)
		# Each dog owns animation resources; loop corrections never modify shared imports.
		for library_name in _player.get_animation_library_list():
			var original := _player.get_animation_library(library_name)
			_player.remove_animation_library(library_name)
			_player.add_animation_library(library_name, original.duplicate(true))
		for state in DogAssetValidator.STATES:
			var animation := _player.get_animation(_clip(state))
			animation.loop_mode = Animation.LOOP_LINEAR if state in ["idle", "run", "dash", "win"] else Animation.LOOP_NONE
		_player.animation_finished.connect(_animation_finished)
		uses_authored_model = true
		_set_animation("idle")
	else:
		if candidate != null:
			candidate.free()
		_fallback = ProceduralDogModel.new()
		_fallback.name = "TemporaryPlaceholder"
		add_child(_fallback)
		_fallback.setup(data, player_color)


func height() -> float:
	if _fallback != null:
		return _fallback.height()
	return data.model_height * data.model_scale if data != null else 1.45


## Full world transform, including the animated rig and per-model import correction.
## Weapon grip offsets are applied by the weapon, not hard-coded into the dog renderer.
func get_mouth_transform() -> Transform3D:
	if _fallback != null:
		return _fallback.get_mouth_transform()
	if is_instance_valid(_socket):
		return _socket.global_transform
	return global_transform


func update_motion(facing: Vector3, speed01: float, delta: float = 1.0 / 60.0) -> void:
	if _fallback != null:
		_fallback.update_motion(facing, speed01, delta)
		return
	if _knocked_out or _victory:
		return
	_speed01 = clampf(speed01, 0.0, 1.0)
	if facing.length_squared() > 0.001:
		_target_basis = Basis.looking_at(facing, Vector3.UP)
	quaternion = quaternion.slerp(_target_basis.get_rotation_quaternion(), 1.0 - exp(-18.0 * delta))
	_update_animation()
	if _active_state == "run":
		_player.speed_scale = lerpf(0.65, 1.35, _speed01)


func set_dashing(value: bool) -> void:
	_dashing = value
	if _fallback != null:
		_fallback.set_dashing(value)
	else:
		_update_animation()


func set_catching(value: bool) -> void:
	_catching = value
	if _fallback != null:
		_fallback.set_catching(value)
	elif value:
		_one_shot = "catch"
		_set_animation("catch", true)
	else:
		_update_animation()


func squash() -> void:
	# Authored characters use their catch pose instead of global mesh deformation.
	if _fallback != null:
		_fallback.squash()
	else:
		_one_shot = "catch"
		_set_animation("catch", true)


func play_throw() -> void:
	if _fallback != null or _knocked_out:
		return
	_one_shot = "throw"
	_set_animation("throw", true)


func play_knocked_out(direction: Vector3) -> void:
	_knocked_out = true
	_catching = false
	_one_shot = ""
	if _fallback != null:
		_fallback.play_knocked_out(direction)
	else:
		_set_animation("ko", true)


func play_victory() -> void:
	if _knocked_out:
		return
	_victory = true
	_one_shot = ""
	if _fallback == null:
		_set_animation("win", true)


func _clip(state: String) -> StringName:
	return StringName(data.model_animations.get(state, state))


func _set_animation(state: String, restart: bool = false) -> void:
	if _player == null or (state == _active_state and not restart):
		return
	_active_state = state
	_player.speed_scale = 1.0
	_player.play(_clip(state), 0.08 if state in ["throw", "catch", "dash", "ko"] else 0.15)


func _update_animation() -> void:
	if _player == null or _knocked_out or _victory or not _one_shot.is_empty():
		return
	_set_animation("dash" if _dashing else ("run" if _speed01 > 0.08 else "idle"))


func _animation_finished(clip: StringName) -> void:
	if not _one_shot.is_empty() and clip == _clip(_one_shot):
		_one_shot = ""
		_update_animation()
