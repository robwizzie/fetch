class_name DogModel
extends Node3D
## Cartoon low-poly dog built from primitives, with breed-specific proportions, ears, tail and
## markings (see [method breed_spec]) and an inverted-hull outline for a clean toon look.
## Faces -Z. Gameplay only calls setup(), update_motion(), set_dashing(), set_catching(),
## squash() and play_knocked_out(), so a rigged model can replace this node later.

enum Ears { FLOPPY, LONG_FLOPPY, UPRIGHT, ROSE }
enum Tail { STRAIGHT, FLUFFY, THIN }

const OUTLINE_COLOR := Color(0.09, 0.07, 0.12)
const OUTLINE_WIDTH := 0.028
const EYE_BLACK := Color(0.07, 0.05, 0.08)
const PINK := Color(0.98, 0.45, 0.55)
const MOUTH := Color(0.45, 0.12, 0.16)

var data: DogData
var player_color := Color.WHITE

var _spec: Dictionary
var _walk_phase := 0.0
var _dashing := false
var _knocked_out := false
var _target_basis := Basis.IDENTITY

var _body: Node3D
var _body_y := 0.0
var _head: Node3D
var _head_y := 0.0
var _legs: Array[Node3D] = []
var _ears: Array[Node3D] = []
var _tail: Node3D
var _catch_bubble: MeshInstance3D
var _meshes: Array[MeshInstance3D] = []


## Body plan per breed. Lengths in metres for a ~0.7 m tall dog; DogData.model_scale scales the whole thing.
static func breed_spec(breed: DogData.Breed) -> Dictionary:
	match breed:
		DogData.Breed.PITBULL:
			return {body_r = 0.4, body_len = 1.2, body_sx = 1.15, leg_r = 0.11, leg_len = 0.36,
				head_r = 0.4, head_s = Vector3(1.12, 0.95, 1.0), snout_r = 0.23, snout_len = 0.14,
				ears = Ears.ROSE, ear_size = 0.12, tail = Tail.THIN,
				chest = true, muzzle = true, blaze = false, saddle = false, tan_points = false, socks = false, smile = 1.2}
		DogData.Breed.CORGI:
			return {body_r = 0.3, body_len = 1.35, body_sx = 1.0, leg_r = 0.08, leg_len = 0.18,
				head_r = 0.34, head_s = Vector3(1.0, 1.0, 1.0), snout_r = 0.15, snout_len = 0.26,
				ears = Ears.UPRIGHT, ear_size = 0.15, tail = Tail.FLUFFY,
				chest = true, muzzle = true, blaze = true, saddle = true, tan_points = false, socks = true, smile = 1.0}
		DogData.Breed.DACHSHUND:
			return {body_r = 0.25, body_len = 1.6, body_sx = 1.0, leg_r = 0.07, leg_len = 0.16,
				head_r = 0.3, head_s = Vector3(1.0, 1.0, 1.05), snout_r = 0.13, snout_len = 0.4,
				ears = Ears.LONG_FLOPPY, ear_size = 0.14, tail = Tail.THIN,
				chest = true, muzzle = true, blaze = false, saddle = false, tan_points = true, socks = true, smile = 0.9}
		DogData.Breed.GOLDEN:
			return {body_r = 0.38, body_len = 1.3, body_sx = 1.0, leg_r = 0.1, leg_len = 0.42,
				head_r = 0.38, head_s = Vector3(1.0, 1.0, 1.0), snout_r = 0.2, snout_len = 0.26,
				ears = Ears.FLOPPY, ear_size = 0.19, tail = Tail.FLUFFY,
				chest = true, muzzle = true, blaze = false, saddle = false, tan_points = false, socks = false, smile = 1.25}
		_:  # LABRADOR
			return {body_r = 0.34, body_len = 1.25, body_sx = 1.0, leg_r = 0.09, leg_len = 0.4,
				head_r = 0.36, head_s = Vector3(1.0, 1.0, 1.0), snout_r = 0.19, snout_len = 0.26,
				ears = Ears.FLOPPY, ear_size = 0.15, tail = Tail.STRAIGHT,
				chest = false, muzzle = false, blaze = false, saddle = false, tan_points = false, socks = false, smile = 1.1}


## Top of the head in world units (after model_scale). Used to frame portraits.
func height() -> float:
	if _spec.is_empty():
		return 1.2
	return (_spec.leg_len + _spec.body_r * 0.82 + _spec.body_r * 0.6 + _spec.head_r * 1.05) * data.model_scale


func setup(p_data: DogData, p_color: Color) -> void:
	data = p_data
	player_color = p_color
	_spec = breed_spec(data.breed)
	_build()
	scale = Vector3.ONE * data.model_scale


func _m(parent: Node3D, mesh: Mesh, color: Color, pos: Vector3 = Vector3.ZERO, rot: Vector3 = Vector3.ZERO, scl: Vector3 = Vector3.ONE) -> MeshInstance3D:
	var mi := Mats.mesh(parent, mesh, color, pos, rot, scl)
	_meshes.append(mi)
	return mi


func _build() -> void:
	for c in get_children():
		c.queue_free()
	_meshes.clear()
	_legs.clear()
	_ears.clear()
	var s := _spec
	var fur: Color = data.fur_color
	var mark: Color = data.markings_color
	var sec: Color = data.secondary_color
	var body_r: float = s.body_r
	var body_len: float = s.body_len
	var leg_len: float = s.leg_len
	var head_r: float = s.head_r
	var snout_r: float = s.snout_r
	var snout_len: float = s.snout_len
	var body_sx: float = s.body_sx

	# ---- torso (a pivot so the whole upper body can bob)
	_body_y = leg_len + body_r * 0.82
	_body = Node3D.new()
	_body.position.y = _body_y
	add_child(_body)
	_m(_body, Mats.capsule(body_r, body_len), fur, Vector3.ZERO, Vector3(90, 0, 0), Vector3(body_sx, 1, 1))
	if s.saddle:
		_m(_body, Mats.sphere(body_r), sec, Vector3(0, body_r * 0.3, 0.05), Vector3.ZERO, Vector3(body_sx * 1.02, 0.62, body_len / (2.0 * body_r) * 0.72))
	if s.chest:
		var chest_col := mark
		_m(_body, Mats.sphere(body_r * 0.8), chest_col, Vector3(0, -body_r * 0.25, -body_len * 0.5 + body_r * 0.55), Vector3.ZERO, Vector3(body_sx * 0.95, 0.85, 0.7))

	# ---- legs (pivot at the hip so they swing)
	var hip_x := body_r * 0.55 * body_sx
	var hip_z := body_len * 0.5 - body_r * 0.85
	for p in [Vector3(-hip_x, -body_r * 0.55, -hip_z), Vector3(hip_x, -body_r * 0.55, -hip_z), Vector3(-hip_x, -body_r * 0.55, hip_z), Vector3(hip_x, -body_r * 0.55, hip_z)]:
		var pivot := Node3D.new()
		pivot.position = p
		_body.add_child(pivot)
		var total := leg_len + body_r * 0.4
		_m(pivot, Mats.cylinder(s.leg_r, total), fur, Vector3(0, -total / 2.0 + body_r * 0.2, 0))
		var paw_col := mark if (s.socks or s.tan_points) else fur
		if s.socks or s.tan_points:
			_m(pivot, Mats.cylinder(s.leg_r * 1.02, leg_len * 0.5), paw_col, Vector3(0, -total + body_r * 0.2 + leg_len * 0.25, 0))
		_m(pivot, Mats.sphere(s.leg_r * 1.25), paw_col, Vector3(0, -total + body_r * 0.2 + s.leg_r * 0.3, -s.leg_r * 0.25), Vector3.ZERO, Vector3(1.1, 0.7, 1.25))
		_legs.append(pivot)

	# ---- head
	_head = Node3D.new()
	_head_y = body_r * 0.6
	_head.position = Vector3(0, _head_y, -body_len * 0.5 - head_r * 0.25)
	_body.add_child(_head)
	_m(_head, Mats.sphere(head_r), fur, Vector3.ZERO, Vector3.ZERO, s.head_s)
	if s.blaze:
		_m(_head, Mats.sphere(head_r * 0.34), mark, Vector3(0, head_r * 0.32, -head_r * 0.74), Vector3(-20, 0, 0), Vector3(0.5, 1.25, 0.7))

	# Eyes: big cartoon eyes with white, pupil and highlight
	var eye_r := head_r * 0.25
	for sx in [-1.0, 1.0]:
		var ep := Vector3(sx * head_r * 0.42, head_r * 0.22, -head_r * 0.78)
		_m(_head, Mats.sphere(eye_r), Color.WHITE, ep)
		var pupil := Mats.mesh(_head, Mats.sphere(eye_r * 0.62), EYE_BLACK, ep + Vector3(-sx * eye_r * 0.05, 0, -eye_r * 0.55))
		Mats.mesh(_head, Mats.sphere(eye_r * 0.22), Color.WHITE, pupil.position + Vector3(-sx * eye_r * 0.2, eye_r * 0.25, -eye_r * 0.45))
		if s.tan_points:
			_m(_head, Mats.sphere(head_r * 0.11), sec, Vector3(sx * head_r * 0.4, head_r * 0.6, -head_r * 0.72))

	# Snout, nose, mouth, tongue
	var snout_col := mark if s.muzzle else fur
	if s.tan_points:
		snout_col = sec
	var snout_z := -head_r * 0.72 - snout_len * 0.5
	_m(_head, Mats.capsule(snout_r, snout_len + snout_r * 2.0), snout_col, Vector3(0, -head_r * 0.18, snout_z), Vector3(90, 0, 0))
	_m(_head, Mats.sphere(snout_r * 0.42), EYE_BLACK, Vector3(0, -head_r * 0.18 + snout_r * 0.45, snout_z - snout_len * 0.5 - snout_r * 0.75), Vector3.ZERO, Vector3(1.15, 0.85, 0.9))
	var smile: float = s.smile
	_m(_head, Mats.sphere(snout_r * 0.6 * smile), MOUTH, Vector3(0, -head_r * 0.18 - snout_r * 0.85, snout_z - snout_len * 0.1), Vector3.ZERO, Vector3(1.2, 0.45, 0.7))
	_m(_head, Mats.sphere(snout_r * 0.42 * smile), PINK, Vector3(0, -head_r * 0.18 - snout_r * 0.98, snout_z - snout_len * 0.2 - snout_r * 0.3), Vector3(15, 0, 0), Vector3(0.7, 0.4, 1.3))

	# Ears
	var ear_col := sec if (s.ears == Ears.FLOPPY and data.breed != DogData.Breed.LABRADOR) else fur
	var e: float = s.ear_size
	for sx in [-1.0, 1.0]:
		var pivot := Node3D.new()
		_head.add_child(pivot)
		match s.ears:
			Ears.FLOPPY:
				pivot.position = Vector3(sx * head_r * 0.92, head_r * 0.35, -head_r * 0.05)
				pivot.rotation_degrees = Vector3(0, 0, -sx * 12.0)
				_m(pivot, Mats.sphere(e), ear_col, Vector3(0, -e * 1.1, 0), Vector3.ZERO, Vector3(0.5, 1.6, 0.85))
			Ears.LONG_FLOPPY:
				pivot.position = Vector3(sx * head_r * 0.9, head_r * 0.3, -head_r * 0.02)
				pivot.rotation_degrees = Vector3(0, 0, -sx * 8.0)
				_m(pivot, Mats.sphere(e), ear_col, Vector3(0, -e * 1.6, 0), Vector3.ZERO, Vector3(0.45, 2.2, 0.8))
			Ears.UPRIGHT:
				pivot.position = Vector3(sx * head_r * 0.55, head_r * 0.85, -head_r * 0.05)
				pivot.rotation_degrees = Vector3(-8, 0, -sx * 22.0)
				_m(pivot, Mats.cone(e, e * 2.6), fur, Vector3(0, e * 1.0, 0))
				Mats.mesh(pivot, Mats.cone(e * 0.55, e * 1.7), PINK, Vector3(0, e * 0.85, -e * 0.35))
			Ears.ROSE:
				pivot.position = Vector3(sx * head_r * 0.82, head_r * 0.75, head_r * 0.1)
				pivot.rotation_degrees = Vector3(35, 0, -sx * 30.0)
				_m(pivot, Mats.sphere(e), fur, Vector3(0, e * 0.5, 0), Vector3.ZERO, Vector3(0.55, 1.1, 0.7))
		_ears.append(pivot)

	# Tail
	_tail = Node3D.new()
	_tail.position = Vector3(0, body_r * 0.45, body_len * 0.5 - body_r * 0.35)
	_tail.rotation_degrees = Vector3(-45, 0, 0)
	_body.add_child(_tail)
	match s.tail:
		Tail.FLUFFY:
			_m(_tail, Mats.capsule(body_r * 0.28, body_r * 1.6), fur, Vector3(0, body_r * 0.5, 0), Vector3.ZERO, Vector3(1, 1, 0.8))
			_m(_tail, Mats.sphere(body_r * 0.36), mark if data.breed == DogData.Breed.CORGI else fur, Vector3(0, body_r * 1.15, 0))
		Tail.THIN:
			_m(_tail, Mats.capsule(body_r * 0.16, body_r * 1.9), fur, Vector3(0, body_r * 0.7, 0))
		_:
			_m(_tail, Mats.capsule(body_r * 0.22, body_r * 1.7), fur, Vector3(0, body_r * 0.6, 0))

	# Bandana around the neck, in the dog's own colour
	var neck_z := -body_len * 0.5 + head_r * 0.2
	_m(_body, Mats.torus(head_r * 0.7, head_r * 1.02), data.bandana_color, Vector3(0, body_r * 0.15, neck_z), Vector3(90, 0, 0), Vector3(body_sx, 1, 1))
	_m(_body, Mats.prism(Vector3(head_r * 0.9, head_r * 0.8, 0.08)), data.bandana_color, Vector3(0, -body_r * 0.35, neck_z - head_r * 0.35), Vector3(180, 0, 0))

	# Outlines on everything except tiny details (eyes/highlights are excluded above)
	for mi in _meshes:
		Mats.outline(mi, OUTLINE_WIDTH, OUTLINE_COLOR)

	# Catch bubble (shown while the catch window is armed)
	_catch_bubble = MeshInstance3D.new()
	_catch_bubble.mesh = Mats.sphere(body_len * 0.75)
	_catch_bubble.material_override = Mats.unlit(Color(player_color, 0.28))
	_catch_bubble.position = Vector3(0, _body_y, -body_len * 0.15)
	_catch_bubble.visible = false
	_catch_bubble.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_catch_bubble)


func update_motion(facing: Vector3, speed01: float, delta: float = 1.0 / 60.0) -> void:
	if _knocked_out:
		return
	if facing.length_squared() > 0.001:
		_target_basis = Basis.looking_at(facing, Vector3.UP)
	quaternion = quaternion.slerp(_target_basis.get_rotation_quaternion(), minf(1.0, 18.0 * delta))
	_walk_phase += (0.35 + speed01 * 20.0) * delta
	var t := Time.get_ticks_msec() * 0.001
	var swing := sin(_walk_phase) * 0.75 * speed01
	for i in _legs.size():
		_legs[i].rotation.x = swing if (i == 0 or i == 3) else -swing
	var bounce := absf(sin(_walk_phase)) * 0.07 * speed01 + sin(t * 2.2) * 0.008
	_body.position.y = _body_y + bounce
	_body.rotation.x = (-0.3 if _dashing else 0.0) + sin(_walk_phase) * 0.04 * speed01
	_head.position.y = _head_y + absf(sin(_walk_phase + 0.5)) * 0.04 * speed01
	_head.rotation.z = sin(t * 1.7) * 0.05
	_tail.rotation.y = sin(t * 11.0) * (0.35 + speed01 * 0.4)
	var flop := sin(_walk_phase * 1.0) * 0.25 * speed01
	for i in _ears.size():
		var side := -1.0 if i == 0 else 1.0
		match _spec.ears:
			Ears.FLOPPY, Ears.LONG_FLOPPY:
				_ears[i].rotation.x = flop
			_:
				_ears[i].rotation.x = deg_to_rad(-8.0) + flop * 0.3 * side


func set_dashing(v: bool) -> void:
	_dashing = v
	scale = (Vector3(0.85, 0.85, 1.25) if v else Vector3.ONE) * data.model_scale


func set_catching(v: bool) -> void:
	_catch_bubble.visible = v
	for i in 2:
		_legs[i].rotation.x = -1.3 if v else 0.0


func squash() -> void:
	scale = Vector3(1.25, 0.75, 1.25) * data.model_scale
	var t := create_tween()
	t.tween_property(self, "scale", Vector3.ONE * data.model_scale, 0.25).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


func play_knocked_out(dir: Vector3) -> void:
	_knocked_out = true
	_catch_bubble.visible = false
	for m in _meshes:
		m.transparency = 0.45
	var t := create_tween().set_parallel(true)
	t.tween_property(self, "rotation:z", PI / 2.0, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(self, "rotation:y", rotation.y + TAU, 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_property(self, "position", position + dir * 1.2 + Vector3(0, 0.1, 0), 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
