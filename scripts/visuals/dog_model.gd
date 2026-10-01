class_name DogModel
extends Node3D
## Gameplay-facing renderer. Authored, rigged 3D scenes are the production path.
## The isolated procedural fallback is a temporary placeholder, not reference artwork.

## Everything below is the layer the authored clips cannot carry, because it depends on what
## the player did a frame ago rather than on a baked timeline: which way the dog is heading,
## how hard it is turning, whether it just started or stopped.
##
## How far a running dog tips into its own direction, in degrees at full speed. A dog standing
## bolt upright while it slides across the floor is what makes top-down movement look weightless.
const RUN_LEAN := 9.0
const DASH_LEAN := 10.0
## How sharply the body swings round to a new heading. Higher is snappier.
const TURN_RATE := 26.0
## Roll into a turn, in degrees per radian-per-second of turning, and the cap on it. A dog that
## corners flat reads as a turret; one that banks reads as an animal leaning on its paws.
const BANK_PER_TURN := 9.0
const MAX_BANK := 15.0
## Squash and stretch from acceleration: degrees of shape change per unit of speed change, and
## its cap. Speeding up stretches the body, stopping dead squashes it.
const SQUASH_PER_ACCEL := 0.02
const MAX_SQUASH := 0.13
## A dash flattens the body out along its line of travel.
const DASH_STRETCH := 1.14
## Run cycle speed at full pelt. The clip is played in proportion to how fast the dog is really
## moving, so the paws stop skating over the ground.
const STRIDE_SCALE := 1.25
## The follow-through a throw puts through the body, in degrees of forward lunge.
const THROW_KICK := 16.0
## How far a full wind-up rocks the body back onto its haunches, in degrees, and how much it
## crouches. Anticipation lives in the hold, so the release can be instant.
const CHARGE_LEAN := 13.0
const CHARGE_CROUCH := 0.08
## Resting breath: a slow rise and fall so a dog standing still is alive, not paused.
const BREATH := 0.014
## How far a dizzy dog rolls from side to side, in degrees, and how fast.
const DIZZY_WOBBLE := 12.0
const DIZZY_SPIN := 7.0
## The bonk launch: how far back along the throw the body is thrown, and how high it goes.
const KO_KNOCKBACK := 1.15
const KO_HOP := 0.8

var data: DogData
var player_color := Color.WHITE
var asset_report: Dictionary = {}
var uses_authored_model := false
var _fallback: ProceduralDogModel
var _imported: Node3D
var _socket: Node3D
var _player: AnimationPlayer
## Plays the clips. Legs and body come from a locomotion layer that blends idle into run by
## speed; throws and catches play over it on the head, chest and front legs only, so a dog that
## throws on the move keeps running instead of freezing mid-stride and skating; dash, KO and win
## take over the whole body.
var _tree: AnimationTree
var _run_weight := 0.0
## Empty until the first request: the transition node has no current state of its own.
var _body_state := ""
var _target_basis := Basis.IDENTITY
## Where the dog is pointing, kept apart from the rendered rotation so the lean is applied
## fresh each frame instead of winding up on itself.
var _facing_quat := Quaternion.IDENTITY
var _speed01 := 0.0
var _lean := 0.0
var _bank := 0.0
var _squash := 0.0
var _dizzy := false
var _dizzy_stars: Node3D
var _dashing := false
var _catching := false
var _knocked_out := false
var _victory := false
var _one_shot := ""
var _active_state := ""
var _size_multiplier := 1.0
var _charge_amount := 0.0
var _charging := false
var _pose: DogPoseMotion
var _release_clip: StringName = &""
var _impact_tween: Tween
## Player-coloured pass drawn only where the dog is hidden behind something (see
## assets/shaders/silhouette.gdshader). Faded in and out rather than swapped.
var _silhouette: ShaderMaterial
var _silhouette_on := false
const SILHOUETTE_SHADER := preload("res://assets/shaders/silhouette.gdshader")
const SILHOUETTE_ALPHA := 0.62


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
	_tree = null
	_run_weight = 0.0
	_body_state = ""
	uses_authored_model = false
	_dashing = false
	_catching = false
	_knocked_out = false
	_victory = false
	_one_shot = ""
	_active_state = ""
	transform = Transform3D.IDENTITY
	_target_basis = Basis.IDENTITY
	_facing_quat = Quaternion.IDENTITY
	_lean = 0.0
	_bank = 0.0
	_squash = 0.0
	_dizzy = false
	_dizzy_stars = null
	var scene := DogAssetValidator.load_model_scene(data)
	var candidate: Node = scene.instantiate() if scene != null else null
	asset_report = DogAssetValidator.inspect(data, candidate)
	if candidate != null and asset_report.valid:
		_imported = candidate as Node3D
		add_child(_imported)
		Mats.prepare_character(_imported)
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
		_anchor_grip()
		_player = DogAssetValidator.find_animation_player(_imported, data)
		# Each dog owns animation resources; loop corrections never modify shared imports.
		for library_name in _player.get_animation_library_list():
			var original := _player.get_animation_library(library_name)
			_player.remove_animation_library(library_name)
			_player.add_animation_library(library_name, original.duplicate(true))
		for state in DogAssetValidator.STATES:
			var animation := _player.get_animation(_clip(state))
			animation.loop_mode = Animation.LOOP_LINEAR if state in ["idle", "run", "dash", "win"] else Animation.LOOP_NONE
		_install_release_animation()
		_build_tree()
		var skeletons := DogAssetValidator.find_skeletons(_imported)
		if not skeletons.is_empty():
			_pose = DogPoseMotion.new()
			_pose.phase = float(data.breed) * 1.7
			_pose.breed = data.breed
			_pose.to_skeleton = _rig_frame(skeletons[0]).basis.orthonormalized().inverse()
			skeletons[0].add_child(_pose)
		uses_authored_model = true
		_update_animation()
	else:
		if candidate != null:
			candidate.free()
		_fallback = ProceduralDogModel.new()
		_fallback.name = "TemporaryPlaceholder"
		add_child(_fallback)
		_fallback.setup(data, player_color)


## Moves the socket onto DogData.mouth_grip. The offset is solved against the rest pose of the
## bone the socket rides on, so the toy lands between the teeth at rest and then follows the
## head wherever the clips take it. Every dog also gets the same grip orientation - level and
## facing out of the mouth - so one toy's held pose reads the same in every mouth, whichever
## way a rig's end bone happens to point.
func _anchor_grip() -> void:
	if data.mouth_grip == Vector3.ZERO or not is_instance_valid(_socket):
		return
	var attachment := _socket.get_parent() as BoneAttachment3D
	if attachment == null:
		return
	var skeleton := attachment.get_parent() as Skeleton3D
	var bone := skeleton.find_bone(attachment.bone_name) if skeleton != null else -1
	if bone < 0:
		return
	var bone_rest := _relative_transform(skeleton) * skeleton.get_bone_global_rest(bone)
	# Facing -Z like the dog, nose tipped down a touch so a disc sits in the bite, not on it.
	var grip := Transform3D(Basis(Vector3.RIGHT, deg_to_rad(-12.0)), data.mouth_grip)
	# The inverse also cancels the armature's export scale, so the grip is true size.
	_socket.transform = bone_rest.affine_inverse() * grip


## The skeleton's transform inside the imported scene, before this renderer turns and scales it.
func _rig_frame(skeleton: Node3D) -> Transform3D:
	var result := Transform3D.IDENTITY
	var at: Node = skeleton
	while at != null and at != _imported:
		if at is Node3D:
			result = (at as Node3D).transform * result
		at = at.get_parent()
	return result


## [param node]'s transform in this model's own space, walked up the parent chain so it works
## before the model is in the tree.
func _relative_transform(node: Node3D) -> Transform3D:
	var result := Transform3D.IDENTITY
	var at: Node = node
	while at != null and at != self:
		if at is Node3D:
			result = (at as Node3D).transform * result
		at = at.get_parent()
	return result


## Hangs the behind-walls silhouette off every surface of the body. Call once after setup;
## anything added later (dizzy stars, angel wings) stays out of it.
func setup_silhouette(color: Color) -> void:
	_silhouette = ShaderMaterial.new()
	_silhouette.shader = SILHOUETTE_SHADER
	_silhouette.set_shader_parameter("tint", Color(color.lightened(0.15), 0.0))
	_silhouette.render_priority = 1
	for node in find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		if mesh.mesh == null:
			continue
		if mesh.material_override is BaseMaterial3D:
			var own := (mesh.material_override as BaseMaterial3D).duplicate() as BaseMaterial3D
			own.next_pass = _silhouette
			mesh.material_override = own
			continue
		for i in mesh.mesh.get_surface_count():
			var material := mesh.get_active_material(i)
			if material == null:
				continue
			var copy := material.duplicate() as Material
			copy.next_pass = _silhouette
			mesh.set_surface_override_material(i, copy)


func set_silhouette(on: bool) -> void:
	if _silhouette == null or on == _silhouette_on:
		return
	_silhouette_on = on
	var tint: Color = _silhouette.get_shader_parameter("tint")
	var fade := create_tween()
	fade.tween_method(func(a: float) -> void:
		_silhouette.set_shader_parameter("tint", Color(tint, a)), tint.a, SILHOUETTE_ALPHA if on else 0.0, 0.12)


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
	if is_instance_valid(_dizzy_stars):
		_dizzy_stars.rotation.y += delta * DIZZY_SPIN
	if _knocked_out or _victory:
		return
	var was := _speed01
	_speed01 = clampf(speed01, 0.0, 1.6)
	if is_instance_valid(_pose):
		_pose.speed = _speed01
		_pose.charge = _charge_amount if _charging else 0.0
		_pose.charging = _charging
		_pose.dashing = _dashing
	if facing.length_squared() > 0.001:
		_target_basis = Basis.looking_at(facing, Vector3.UP)
	_turn_toward(delta)
	_shape_body(was, delta)
	_blend_locomotion(delta)
	_update_animation()


## Swing round to the heading, lean into the run and bank into the turn.
func _turn_toward(delta: float) -> void:
	var before := _facing_quat.get_euler().y
	_facing_quat = _facing_quat.slerp(_target_basis.get_rotation_quaternion(), 1.0 - exp(-TURN_RATE * delta))
	var turning := wrapf(_facing_quat.get_euler().y - before, -PI, PI) / maxf(delta, 0.0001)
	# Capped at full-speed strength: a dash runs at 1.5x and used to tip the dog nose-first
	# into the floor rather than into a lunge.
	var want_lean := deg_to_rad(DASH_LEAN if _dashing else RUN_LEAN) * minf(_speed01, 1.0)
	if _charging:
		# Rocked back and loading up; eased so a quick tap barely moves and a full hold sits deep.
		want_lean -= deg_to_rad(CHARGE_LEAN) * smoothstep(0.0, 1.0, _charge_amount)
	_lean = lerpf(_lean, want_lean, 1.0 - exp(-11.0 * delta))
	var want_bank := clampf(-turning * deg_to_rad(BANK_PER_TURN), -deg_to_rad(MAX_BANK), deg_to_rad(MAX_BANK))
	_bank = lerpf(_bank, want_bank * _speed01, 1.0 - exp(-12.0 * delta))
	# Seeing stars rolls the body about under you. Added on rather than folded into the bank,
	# so it reads as something happening TO the dog and clears the instant the spell ends.
	var wobble := sin(Time.get_ticks_msec() * 0.009) * deg_to_rad(DIZZY_WOBBLE) if _dizzy else 0.0
	# Assigning the quaternion rather than the basis keeps whatever scale a pop is mid-way
	# through, so none of this fights the squash-and-stretch.
	quaternion = _facing_quat * Quaternion(Vector3.RIGHT, -_lean) * Quaternion(Vector3.FORWARD, _bank + wobble)


## Squash and stretch, applied to the imported model rather than to this node, so that the
## pops and squashes gameplay fires off through Juice keep working on top of it.
func _shape_body(was: float, delta: float) -> void:
	if not is_instance_valid(_imported):
		return
	var change := (_speed01 - was) / maxf(delta, 0.0001)
	var want := clampf(change * SQUASH_PER_ACCEL, -MAX_SQUASH, MAX_SQUASH)
	_squash = lerpf(_squash, want, 1.0 - exp(-14.0 * delta))
	var stretch := DASH_STRETCH if _dashing else 1.0
	var base := data.model_import_scale
	var crouch := CHARGE_CROUCH * smoothstep(0.0, 1.0, _charge_amount) if _charging else 0.0
	var breath := sin(Time.get_ticks_msec() * 0.0024 + float(data.breed)) * BREATH * (1.0 - clampf(_speed01 * 4.0, 0.0, 1.0))
	var height := 1.0 + _squash - crouch + breath
	# Volume is kept: whatever the body loses in height it gains in girth, never in size.
	var widen := base * (1.0 - _squash * 0.55 + crouch * 0.5)
	_imported.scale = Vector3(widen / stretch, base * height, widen * stretch)


func set_dashing(value: bool) -> void:
	var landing := _dashing and not value
	_dashing = value
	if _fallback != null:
		_fallback.set_dashing(value)
	else:
		_update_animation()
	if landing and not _knocked_out:
		# Paws hit the floor: the short squash is the tell that the dash is spent and the dog
		# is open again.
		_pulse(Vector3(1.08, 0.88, 1.06))


func set_catching(value: bool) -> void:
	_catching = value
	if _fallback != null:
		_fallback.set_catching(value)
	elif value:
		_fire_action("catch")


func squash() -> void:
	if _fallback != null:
		_fallback.squash()
	else:
		_pulse(Vector3(1.07, 0.90, 1.07))


func play_throw() -> void:
	if _knocked_out:
		return
	if _fallback != null:
		_fallback.squash()
		return
	# The wind-up already rocked the body back; the release throws it forward through the
	# shot and the lean eases home on its own.
	_lean = deg_to_rad(THROW_KICK)
	_pulse(Vector3(0.94, 0.95, 1.12))
	_fire_action("throw")


func play_knocked_out(direction: Vector3) -> void:
	_knocked_out = true
	if is_instance_valid(_pose):
		# Only the ears keep moving after a knockout (see DogPoseMotion.ears_up).
		_pose.knocked_out = true
	_catching = false
	set_dizzy(false)
	if _fallback != null:
		_fallback.play_knocked_out(direction)
		return
	_abort_action()
	_set_body("ko")
	_tumble(direction)


## Down a hole: the body slides to the middle, drops out of sight spinning, and is gone.
## [param into] is the hole's centre in this model's parent's space.
func play_fall(into: Vector3) -> void:
	_knocked_out = true
	if is_instance_valid(_pose):
		_pose.knocked_out = true
	_catching = false
	set_dizzy(false)
	if _fallback == null:
		_abort_action()
		_set_body("ko")
	if _impact_tween != null:
		_impact_tween.kill()
	var base := _base_scale()
	var drop := create_tween().set_parallel(true)
	drop.tween_property(self, "position", Vector3(into.x, 0.15, into.z), 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	drop.tween_property(self, "position:y", -1.6, 0.42).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN).set_delay(0.14)
	drop.tween_property(self, "rotation:y", rotation.y + TAU * 1.5, 0.56)
	drop.tween_property(self, "scale", base * 0.55, 0.42).set_delay(0.14)
	drop.chain().tween_callback(func() -> void: visible = false)


## A bonk should throw you. The rig's ko clip plays underneath; this is the launch that sells
## the hit - up and back along the throw, then a finish that is each breed's own joke, so four
## dogs going out never look like one animation. An authored clip cannot know which way the toy
## came from, so this part has to be code.
func _tumble(direction: Vector3) -> void:
	if _impact_tween != null:
		_impact_tween.kill()
	var away := Vector3(direction.x, 0.0, direction.z)
	away = Vector3(0, 0, 1) if away.length_squared() < 0.001 else away.normalized()
	var land := away * KO_KNOCKBACK
	var base := _base_scale()
	scale = base
	var hop := KO_HOP
	var turn := TAU * (1.0 if randf() > 0.5 else -1.0)
	var flat := Vector3(0.0, rotation.y + turn, deg_to_rad(88.0))
	match data.breed:
		DogData.Breed.PITBULL:
			# Spins like a top on the way up, then drops on its side.
			flat.y = rotation.y + turn * 3.0
			hop *= 1.15
		DogData.Breed.SPANIEL:
			# Sent high, ears straight up like a pair of wings.
			hop *= 1.6
			if is_instance_valid(_pose):
				_pose.ears_up = true
		DogData.Breed.GOLDEN:
			# Flips right over onto its back: legs in the air.
			flat = Vector3(0.0, rotation.y, deg_to_rad(180.0))
		DogData.Breed.CORGI:
			# Short legs, long loaf: keeps rolling along the ground after it lands.
			flat.z = deg_to_rad(88.0)
	var fly := create_tween().set_parallel(true)
	fly.tween_property(self, "position", land + Vector3(0, hop, 0), 0.17 * hop / KO_HOP) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	fly.tween_property(self, "position", land, 0.18 * hop / KO_HOP) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN).set_delay(0.17 * hop / KO_HOP)
	fly.tween_property(self, "rotation", flat, 0.42).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	var landed := 0.35 * hop / KO_HOP
	match data.breed:
		DogData.Breed.LABRADOR:
			# Flops flat as a pancake and stays that way.
			fly.tween_property(self, "scale", Vector3(base.x * 1.3, base.y * 0.42, base.z * 1.3), 0.09).set_delay(landed)
			fly.tween_property(self, "scale", Vector3(base.x * 1.18, base.y * 0.55, base.z * 1.18), 0.3) \
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(landed + 0.09)
		DogData.Breed.CORGI:
			var roll_to := land + away * 1.4
			fly.tween_property(self, "position", roll_to, 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT).set_delay(landed)
			fly.tween_property(self, "rotation:z", flat.z + TAU * 2.0, 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT).set_delay(landed)
		_:
			# Landing knocks the air out of it before it settles.
			fly.tween_property(self, "scale", Vector3(base.x * 1.24, base.y * 0.6, base.z * 1.24), 0.07).set_delay(landed)
			fly.tween_property(self, "scale", base, 0.26).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(landed + 0.07)
	var dog := get_parent() as Node3D
	if dog != null:
		get_tree().create_timer(landed + 0.25, false).timeout.connect(func() -> void:
			if is_instance_valid(dog):
				_snooze(dog, land + Vector3(0, 0.7, 0)))


## Knocked silly, not gone: a trail of sleepy z's drifts up out of the dog in its player colour, big
## then small, swaying as they rise. The dog is having a snooze until the next round.
func _snooze(dog: Node3D, at: Vector3) -> void:
	for i in 3:
		var z := Label3D.new()
		z.text = "z" if i < 2 else "Z"
		z.font = UiKit.FONT_DISPLAY
		z.font_size = 64 + i * 22
		z.outline_size = 16
		z.pixel_size = 0.006
		z.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		z.no_depth_test = true
		z.modulate = Color(player_color.lightened(0.35), 0.0)
		z.outline_modulate = Color(0.1, 0.08, 0.14, 0.0)
		z.position = at
		dog.add_child(z)
		var drift := z.create_tween().set_parallel(true)
		var delay := 0.28 * float(i)
		var side := 0.35 if i % 2 == 0 else -0.35
		drift.tween_property(z, "modulate:a", 1.0, 0.2).set_delay(delay)
		drift.tween_property(z, "outline_modulate:a", 0.9, 0.2).set_delay(delay)
		drift.tween_property(z, "position", at + Vector3(side + 0.25 * float(i), 1.3 + 0.35 * float(i), 0), 1.4) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT).set_delay(delay)
		drift.tween_property(z, "modulate:a", 0.0, 0.4).set_delay(delay + 1.0)
		drift.tween_property(z, "outline_modulate:a", 0.0, 0.4).set_delay(delay + 1.0)
		drift.chain().tween_callback(z.queue_free)


## Whacked silly. The authored rigs have no dizzy clip, so until they do this is the whole
## tell: three stars going round over the head and the body rolling under them. Without it the
## HUD said SEEING STARS while the dog on the field looked perfectly fine.
func set_dizzy(on: bool) -> void:
	if _fallback != null:
		_fallback.set_dizzy(on)
		return
	if on == _dizzy:
		return
	_dizzy = on
	if is_instance_valid(_dizzy_stars):
		_dizzy_stars.queue_free()
	_dizzy_stars = null
	if not on or data == null:
		return
	_dizzy_stars = Node3D.new()
	_dizzy_stars.name = "DizzyStars"
	# Local units: this node is already carrying the dog's model_scale.
	_dizzy_stars.position = Vector3(0, data.model_height + 0.22, 0)
	add_child(_dizzy_stars)
	for i in 3:
		var star := Mats.mesh(_dizzy_stars, Mats.sphere(0.085), Color(1.0, 0.88, 0.35),
			Vector3(0.34, 0, 0).rotated(Vector3.UP, TAU * float(i) / 3.0))
		star.material_override = Mats.unlit(Color(1.0, 0.88, 0.35))
		star.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func play_victory() -> void:
	if _knocked_out:
		return
	_victory = true
	if is_instance_valid(_pose):
		_pose.celebrating = true
	if _fallback == null:
		_abort_action()
		_set_body("win")


func _clip(state: String) -> StringName:
	if state == "throw" and not _release_clip.is_empty():
		return _release_clip
	return StringName(data.model_animations.get(state, state))


## Bones the throw and catch clips own while they play. Everything else - hips and back legs
## especially - stays with locomotion. Ears and tail belong to DogPoseMotion.
const ACTION_BONES := ["chest", "head", "headend",
	"frontleg", "frontleg0", "frontleg1", "frontleg2", "R_frontleg", "R_frontleg0", "R_frontleg1", "R_frontleg2"]
## Cross-fades into each whole-body state: a dash and a bonk land at once, the rest ease.
const BODY_FADE := {"move": 0.14, "dash": 0.05, "ko": 0.04, "win": 0.2}
const BODY_STATES := ["move", "dash", "ko", "win"]
const ACTION_FADE_IN := 0.03
const ACTION_FADE_OUT := 0.14


func _build_tree() -> void:
	var root := AnimationNodeBlendTree.new()
	for state in ["idle", "run", "dash", "ko", "win"]:
		var clip := AnimationNodeAnimation.new()
		clip.animation = _clip(state)
		root.add_node(StringName(state), clip)
	root.add_node(&"stride", AnimationNodeTimeScale.new())
	root.connect_node(&"stride", 0, &"run")
	root.add_node(&"move", AnimationNodeBlend2.new())
	root.connect_node(&"move", 0, &"idle")
	root.connect_node(&"move", 1, &"stride")
	var body := AnimationNodeTransition.new()
	for state in BODY_STATES:
		body.add_input(state)
	root.add_node(&"body", body)
	for i in BODY_STATES.size():
		root.connect_node(&"body", i, StringName(BODY_STATES[i]))
	var shot := AnimationNodeAnimation.new()
	shot.animation = _clip("throw")
	root.add_node(&"shot", shot)
	var action := AnimationNodeOneShot.new()
	action.fadein_time = ACTION_FADE_IN
	action.fadeout_time = ACTION_FADE_OUT
	action.filter_enabled = true
	var skeletons := DogAssetValidator.find_skeletons(_imported)
	var animated_root := _player.get_node_or_null(_player.root_node)
	if not skeletons.is_empty() and animated_root != null:
		var skeleton_path := String(animated_root.get_path_to(skeletons[0]))
		for bone in ACTION_BONES:
			action.set_filter_path(NodePath("%s:%s" % [skeleton_path, bone]), true)
	root.add_node(&"action", action)
	root.connect_node(&"action", 0, &"body")
	root.connect_node(&"action", 1, &"shot")
	root.connect_node(&"output", 0, &"action")
	_tree = AnimationTree.new()
	_tree.name = "DogAnimationTree"
	_player.get_parent().add_child(_tree)
	_tree.anim_player = NodePath("../" + String(_player.name))
	_tree.root_node = _player.root_node
	_tree.tree_root = root
	_player.stop()
	_tree.active = true


## The whole-body layer: locomotion, dash, KO or celebration.
func _set_body(state: String) -> void:
	if _tree == null:
		return
	if state != _body_state or state in ["ko", "win"]:
		var body := (_tree.tree_root as AnimationNodeBlendTree).get_node(&"body") as AnimationNodeTransition
		body.xfade_time = BODY_FADE.get(state, 0.12)
		_body_state = state
		_tree.set("parameters/body/transition_request", state)
	_refresh_state()


## Throw or catch over the top of whatever the legs are doing.
func _fire_action(state: String) -> void:
	if _tree == null:
		return
	_one_shot = state
	var shot := (_tree.tree_root as AnimationNodeBlendTree).get_node(&"shot") as AnimationNodeAnimation
	shot.animation = _clip(state)
	_tree.set("parameters/action/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
	_refresh_state()


func _abort_action() -> void:
	_one_shot = ""
	if _tree != null:
		_tree.set("parameters/action/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FADE_OUT)


## Idle eases into run with speed rather than snapping at a threshold, and the stride is played
## in proportion to how fast the dog is really travelling so the paws stop skating.
func _blend_locomotion(delta: float) -> void:
	if _tree == null:
		return
	var want := smoothstep(0.03, 0.3, _speed01)
	_run_weight = lerpf(_run_weight, want, 1.0 - exp(-14.0 * delta))
	_tree.set("parameters/move/blend_amount", _run_weight)
	_tree.set("parameters/stride/scale", clampf(_speed01 * STRIDE_SCALE, 0.35, 2.0))


func _update_animation() -> void:
	if _tree == null or _knocked_out or _victory:
		return
	_set_body("dash" if _dashing else "move")


## What the dog is visibly doing, for tests and tools: the action on top while one plays,
## otherwise the body state.
func _refresh_state() -> void:
	if not _one_shot.is_empty():
		_active_state = _one_shot
	elif _body_state == "move":
		_active_state = "run" if _speed01 > 0.08 else "idle"
	else:
		_active_state = _body_state


func _process(_delta: float) -> void:
	if _tree == null or _one_shot.is_empty():
		return
	# Done once the request has been taken and the shot is no longer playing.
	if int(_tree.get("parameters/action/request")) == AnimationNodeOneShot.ONE_SHOT_REQUEST_NONE \
			and not bool(_tree.get("parameters/action/active")):
		_one_shot = ""
		_refresh_state()


func set_size_multiplier(value: float) -> void:
	_size_multiplier = value
	if _impact_tween != null:
		_impact_tween.kill()
	scale = _base_scale()


## The dog's true rendered size. Every pulse and tumble returns here.
func _base_scale() -> Vector3:
	return Vector3.ONE * _size_multiplier * (data.model_scale if uses_authored_model else 1.0)


func set_charge(value: float, held: bool) -> void:
	_charge_amount = value
	_charging = held
	if is_instance_valid(_pose):
		_pose.charge = value
		_pose.charging = held


func play_whack() -> void:
	play_throw()
	_pulse(Vector3(1.1, 0.9, 1.15))


func play_stagger() -> void:
	if _knocked_out:
		return
	_abort_action()
	_catching = false
	_lean = deg_to_rad(-20.0)
	_bank = deg_to_rad(14.0)
	_pulse(Vector3(1.14, 0.78, 1.1))
	_update_animation()


func _pulse(factor: Vector3) -> void:
	if _impact_tween != null:
		_impact_tween.kill()
	var base := _base_scale()
	scale = base * factor
	_impact_tween = create_tween()
	_impact_tween.tween_property(self, "scale", base, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Gameplay pops (catch, pickup, power-up) read as a bounce, not as the dog growing: height
## goes up, girth comes in, so the dog is always its true size.
func pop_feedback(amount: float, _time: float) -> void:
	var lift := 1.0 + (amount - 1.0) * 0.6
	var girth := 1.0 / sqrt(lift)
	_pulse(Vector3(girth, lift, girth))


## The delivered throw includes anticipation. Charge owns that now; release starts at the
## forward snap instead of playing the wind-up after the projectile has already left.
func _install_release_animation() -> void:
	_release_clip = &""
	var source := _player.get_animation(_clip("throw"))
	if source.length < 0.4:
		return
	var release := source.duplicate(true) as Animation
	var cut := 0.24
	for track in release.get_track_count():
		var type := release.track_get_type(track)
		var first: Variant
		match type:
			Animation.TYPE_ROTATION_3D: first = source.rotation_track_interpolate(track, cut)
			Animation.TYPE_POSITION_3D: first = source.position_track_interpolate(track, cut)
			Animation.TYPE_SCALE_3D: first = source.scale_track_interpolate(track, cut)
			_: continue
		for key in range(release.track_get_key_count(track) - 1, -1, -1):
			var time := release.track_get_key_time(track, key)
			if time <= cut:
				release.track_remove_key(track, key)
			else:
				release.track_set_key_time(track, key, time - cut)
		release.track_insert_key(track, 0.0, first)
	release.length = source.length - cut
	var library := AnimationLibrary.new()
	library.add_animation(&"release", release)
	_player.add_animation_library(&"fetch", library)
	_release_clip = &"fetch/release"
