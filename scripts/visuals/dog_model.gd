class_name DogModel
extends Node3D
## Low-poly placeholder dog built from primitives, in the dog's own colours.
## Faces -Z. The Dog only calls setup(), update_motion(), set_dashing(), set_catching(),
## squash() and play_knocked_out(), so a real rigged model can replace this node later.

var data: DogData
var player_color := Color.WHITE

var _walk_phase := 0.0
var _speed01 := 0.0
var _dashing := false
var _knocked_out := false
var _target_basis := Basis.IDENTITY

var _body: MeshInstance3D
var _head: Node3D
var _legs: Array[MeshInstance3D] = []
var _tail: MeshInstance3D
var _catch_bubble: MeshInstance3D
var _meshes: Array[MeshInstance3D] = []


func setup(p_data: DogData, p_color: Color) -> void:
	data = p_data
	player_color = p_color
	_build()


func _build() -> void:
	for c in get_children():
		c.queue_free()
	_meshes.clear()
	_legs.clear()
	var fur := data.fur_color
	var accent := data.accent_color
	var dark := Color(0.08, 0.06, 0.06)

	_body = Mats.mesh(self, Mats.capsule(0.32, 1.05), fur, Vector3(0, 0.5, 0.05), Vector3(90, 0, 0))
	_meshes.append(_body)

	_head = Node3D.new()
	_head.position = Vector3(0, 0.78, -0.5)
	add_child(_head)
	_meshes.append(Mats.mesh(_head, Mats.sphere(0.3), fur))
	_meshes.append(Mats.mesh(_head, Mats.sphere(0.16), accent, Vector3(0, -0.07, -0.25)))         # snout
	_meshes.append(Mats.mesh(_head, Mats.sphere(0.065), dark, Vector3(0, -0.02, -0.39)))          # nose
	_meshes.append(Mats.mesh(_head, Mats.sphere(0.05), dark, Vector3(-0.13, 0.08, -0.24)))        # eyes
	_meshes.append(Mats.mesh(_head, Mats.sphere(0.05), dark, Vector3(0.13, 0.08, -0.24)))
	_meshes.append(Mats.mesh(_head, Mats.sphere(0.15), accent, Vector3(-0.27, 0.12, 0.05), Vector3(0, 0, 20), Vector3(0.6, 1.0, 0.45)))  # ears
	_meshes.append(Mats.mesh(_head, Mats.sphere(0.15), accent, Vector3(0.27, 0.12, 0.05), Vector3(0, 0, -20), Vector3(0.6, 1.0, 0.45)))
	# Tongue
	_meshes.append(Mats.mesh(_head, Mats.sphere(0.06), Color(0.95, 0.4, 0.5), Vector3(0, -0.2, -0.3), Vector3.ZERO, Vector3(0.8, 0.5, 1.4)))

	# Bandana (in the dog's own colour) around the neck
	_meshes.append(Mats.mesh(self, Mats.torus(0.25, 0.36), data.bandana_color, Vector3(0, 0.62, -0.28), Vector3(90, 0, 0)))
	_meshes.append(Mats.mesh(self, Mats.prism(Vector3(0.36, 0.3, 0.06)), data.bandana_color, Vector3(0, 0.42, -0.42), Vector3(180, 0, 0)))

	# Legs
	for p in [Vector3(-0.2, 0.2, -0.28), Vector3(0.2, 0.2, -0.28), Vector3(-0.2, 0.2, 0.32), Vector3(0.2, 0.2, 0.32)]:
		var leg := Mats.mesh(self, Mats.cylinder(0.085, 0.42), fur, p)
		_legs.append(leg)
		_meshes.append(leg)

	# Tail
	_tail = Mats.mesh(self, Mats.capsule(0.07, 0.45), fur, Vector3(0, 0.7, 0.62), Vector3(-40, 0, 0))
	_meshes.append(_tail)

	# Catch bubble (shown while the catch window is armed)
	_catch_bubble = MeshInstance3D.new()
	_catch_bubble.mesh = Mats.sphere(0.95)
	_catch_bubble.material_override = Mats.unlit(Color(player_color, 0.28))
	_catch_bubble.position = Vector3(0, 0.55, 0)
	_catch_bubble.visible = false
	_catch_bubble.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_catch_bubble)


func update_motion(facing: Vector3, speed01: float, delta: float = 1.0 / 60.0) -> void:
	if _knocked_out:
		return
	if facing.length_squared() > 0.001:
		_target_basis = Basis.looking_at(facing, Vector3.UP)
	quaternion = quaternion.slerp(_target_basis.get_rotation_quaternion(), minf(1.0, 18.0 * delta))
	_speed01 = speed01
	_walk_phase += speed01 * 22.0 * delta
	var swing := sin(_walk_phase) * 0.7 * speed01
	for i in _legs.size():
		_legs[i].rotation.x = swing if (i == 0 or i == 3) else -swing
	_body.position.y = 0.5 + absf(sin(_walk_phase)) * 0.06 * speed01
	_head.position.y = 0.78 + absf(sin(_walk_phase)) * 0.05 * speed01
	_tail.rotation.y = sin(Time.get_ticks_msec() * 0.012) * 0.5
	var lean := -0.35 if _dashing else 0.0
	_body.rotation.x = deg_to_rad(90.0) + lean


func set_dashing(v: bool) -> void:
	_dashing = v
	scale = Vector3(0.85, 0.85, 1.25) * _base_scale() if v else _base_scale()


func set_catching(v: bool) -> void:
	_catch_bubble.visible = v
	# Front paws up
	for i in 2:
		_legs[i].rotation.x = -1.2 if v else 0.0


func squash() -> void:
	scale = Vector3(1.25, 0.75, 1.25) * _base_scale()
	var t := create_tween()
	t.tween_property(self, "scale", _base_scale(), 0.25).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


func play_knocked_out(dir: Vector3) -> void:
	_knocked_out = true
	_catch_bubble.visible = false
	for m in _meshes:
		m.transparency = 0.45
	var t := create_tween().set_parallel(true)
	t.tween_property(self, "rotation:z", PI / 2.0, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(self, "rotation:y", rotation.y + TAU, 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_property(self, "position", position + dir * 1.2 + Vector3(0, 0.1, 0), 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _base_scale() -> Vector3:
	return Vector3.ONE * (data.body_radius / 0.55) if data else Vector3.ONE
