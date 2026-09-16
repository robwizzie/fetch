class_name ProceduralDogModel
extends Node3D
## Temporary gameplay placeholder. This geometry does not match the character sheets.
## Kept isolated so authored, skinned GLB assets replace it without gameplay changes.

enum Ears { FLOPPY, LONG_FLOPPY, UPRIGHT, ROSE }
enum Tail { STRAIGHT, FLUFFY, THIN, BOB }

## Toon ink line for the silhouette masses.
const OUTLINE_INK := Color(0.09, 0.08, 0.11)
const OUTLINE_WEIGHT := 0.021
const EYE_BLACK := Color(0.035, 0.025, 0.025)
const IRIS := Color(0.34, 0.15, 0.055)
const PINK := Color(0.98, 0.36, 0.43)
const MOUTH := Color(0.13, 0.045, 0.05)
const CREAM := Color(1.0, 0.94, 0.82)

var data: DogData
var player_color := Color.WHITE
var _spec: Dictionary
var _walk_phase := 0.0
var _dashing := false
var _catching := false
var _knocked_out := false
var _target_basis := Basis.IDENTITY
var _body: Node3D
var _body_y := 0.0
var _head: Node3D
var _head_y := 0.0
var _legs: Array[Node3D] = []
var _ears: Array[Node3D] = []
var _eyes: Array[Node3D] = []
var _tail: Node3D
var _catch_bubble: MeshInstance3D
var _dizzy_stars: Node3D
var _meshes: Array[MeshInstance3D] = []
var _materials: Dictionary = {}
var _brindle: ShaderMaterial
var _squash_tween: Tween
var _mouth_socket: Marker3D


## Compact bodies, oversized heads and paws stay readable from the arena camera.
static func breed_spec(breed: DogData.Breed) -> Dictionary:
	var s := {body_r = 0.32, body_len = 1.0, body_sx = 1.0, leg_r = 0.105,
		leg_len = 0.34, head_r = 0.39, head_s = Vector3(1.04, 1.04, 0.96),
		snout_r = 0.19, ears = Ears.FLOPPY, ear_size = 0.19, tail = Tail.STRAIGHT,
		chest = false, blaze = false, tan_points = false, socks = false, fluffy = false}
	match breed:
		DogData.Breed.PITBULL:
			s.merge({body_r = 0.37, body_len = 1.02, body_sx = 1.08, leg_r = 0.12,
				head_r = 0.43, head_s = Vector3(1.12, 1.0, 0.96), snout_r = 0.225,
				ears = Ears.UPRIGHT, ear_size = 0.16, tail = Tail.THIN,
				chest = true, blaze = true, socks = true}, true)
		DogData.Breed.CORGI:
			s.merge({body_r = 0.29, body_len = 1.12, leg_r = 0.105, leg_len = 0.18,
				head_r = 0.38, snout_r = 0.175, ears = Ears.UPRIGHT, ear_size = 0.205,
				tail = Tail.BOB, chest = true, blaze = true, tan_points = true,
				socks = true, fluffy = true}, true)
		DogData.Breed.SPANIEL:
			s.merge({body_r = 0.285, body_len = 0.99, leg_r = 0.098, leg_len = 0.27,
				head_r = 0.375, snout_r = 0.17, ears = Ears.LONG_FLOPPY, ear_size = 0.22,
				tail = Tail.FLUFFY, chest = true, tan_points = true, socks = true,
				fluffy = true}, true)
		DogData.Breed.DACHSHUND: # Kept for older/custom DogData resources.
			s.merge({body_r = 0.26, body_len = 1.35, leg_len = 0.19,
				head_r = 0.34, ears = Ears.LONG_FLOPPY, tan_points = true, socks = true}, true)
		DogData.Breed.GOLDEN:
			s.merge({body_r = 0.345, body_len = 1.09, leg_len = 0.35,
				head_r = 0.405, ear_size = 0.235, tail = Tail.FLUFFY,
				chest = true, fluffy = true}, true)
	return s


func height() -> float:
	if _spec.is_empty():
		return 1.4
	var ear_extra: float = _spec.ear_size * 1.25 if _spec.ears == Ears.UPRIGHT else 0.0
	return (_body_y + _head_y + _spec.head_r + ear_extra) * data.model_scale


func setup(p_data: DogData, p_color: Color) -> void:
	data = p_data
	player_color = p_color
	_spec = breed_spec(data.breed)
	_knocked_out = false
	_build()
	scale = Vector3.ONE * data.model_scale


func _sphere(radius: float) -> SphereMesh:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 28
	mesh.rings = 16
	return mesh


func _capsule(radius: float, length: float) -> CapsuleMesh:
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = maxf(length, radius * 2.0)
	mesh.radial_segments = 24
	mesh.rings = 10
	return mesh


func _material(color: Color, glossy: bool = false) -> StandardMaterial3D:
	var key := str(color) + str(glossy)
	if not _materials.has(key):
		var mat := StandardMaterial3D.new()
		mat.albedo_color = color
		mat.roughness = 0.23 if glossy else 0.87
		mat.metallic_specular = 0.7 if glossy else 0.22
		_materials[key] = mat
	return _materials[key]


## Inverted-hull ink line, applied only to the masses that make up the silhouette. Putting it
## on every fur tuft turns the dog into noise; on the big shapes it reads as a cartoon and
## separates a dark dog from a dark arena.
func _ink(mi: MeshInstance3D, weight: float = 1.0) -> MeshInstance3D:
	Mats.outline(mi, OUTLINE_WEIGHT * weight, OUTLINE_INK)
	return mi


func _m(parent: Node3D, mesh: Mesh, color: Color, pos: Vector3 = Vector3.ZERO, rot: Vector3 = Vector3.ZERO, scl: Vector3 = Vector3.ONE, glossy: bool = false) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _brindle if _brindle != null and color == data.fur_color else _material(color, glossy)
	mi.position = pos
	mi.rotation_degrees = rot
	mi.scale = scl
	parent.add_child(mi)
	_meshes.append(mi)
	return mi


func _make_brindle() -> void:
	_brindle = null
	if data.breed != DogData.Breed.PITBULL:
		return
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
uniform vec4 coat : source_color;
uniform vec4 stripe : source_color;
varying vec3 local_pos;
float hash(vec3 p) { return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453); }
float noise(vec3 p) {
	vec3 i = floor(p); vec3 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash(i), hash(i + vec3(1,0,0)), f.x), mix(hash(i + vec3(0,1,0)), hash(i + vec3(1,1,0)), f.x), f.y),
		mix(mix(hash(i + vec3(0,0,1)), hash(i + vec3(1,0,1)), f.x), mix(hash(i + vec3(0,1,1)), hash(i + vec3(1,1,1)), f.x), f.y), f.z);
}
void vertex() { local_pos = VERTEX; }
void fragment() {
	float broad = noise(local_pos * vec3(13.0, 6.0, 16.0));
	float wisps = noise(local_pos * vec3(35.0, 16.0, 48.0));
	float bands = smoothstep(0.43, 0.69, broad * 0.76 + wisps * 0.24);
	ALBEDO = mix(coat.rgb, stripe.rgb, bands * 0.8);
	ROUGHNESS = 0.91; SPECULAR = 0.18;
}
"""
	_brindle = ShaderMaterial.new()
	_brindle.shader = shader
	_brindle.set_shader_parameter("coat", data.fur_color)
	_brindle.set_shader_parameter("stripe", data.secondary_color)


func _build() -> void:
	for child in get_children():
		child.queue_free()
	_meshes.clear()
	_legs.clear()
	_ears.clear()
	_eyes.clear()
	_materials.clear()
	_make_brindle()
	var s := _spec
	var fur := data.fur_color
	var mark := data.markings_color
	var tan := data.secondary_color
	var r: float = s.body_r
	var length: float = s.body_len
	var hr: float = s.head_r
	_body_y = s.leg_len + r * 0.73
	_body = Node3D.new()
	_body.position.y = _body_y
	add_child(_body)
	_ink(_m(_body, _capsule(r, length), fur, Vector3.ZERO, Vector3(90, 0, 0), Vector3(s.body_sx, 1, 1)))
	# Soft shoulder and rump masses break the old straight sausage silhouette.
	_ink(_m(_body, _sphere(r * 0.91), fur, Vector3(0, 0.015, -length * 0.24), Vector3.ZERO, Vector3(s.body_sx, 1.04, 0.90)))
	if s.chest:
		_m(_body, _sphere(r * 0.83), tan if s.tan_points else mark, Vector3(0, -r * 0.16, -length * 0.37), Vector3.ZERO, Vector3(0.86, 1.0, 0.6))
		if data.breed == DogData.Breed.CORGI:
			_m(_body, _sphere(r * 0.72), mark, Vector3(0, -r * 0.52, -length * 0.20), Vector3.ZERO, Vector3(1.0, 0.72, 1.5))
	_build_legs()

	_head = Node3D.new()
	_head_y = r * 0.67
	_head.position = Vector3(0, _head_y, -length * 0.43)
	_body.add_child(_head)
	_ink(_m(_head, _sphere(hr), fur, Vector3.ZERO, Vector3.ZERO, s.head_s))
	if s.fluffy:
		# Rounded cheek feathering gives the spaniel and retriever their own outline.
		for side in [-1.0, 1.0]:
			for i in 3:
				var col := mark if data.breed == DogData.Breed.CORGI else fur
				_m(_head, _sphere(hr * 0.24), col, Vector3(side * hr * (0.69 + i * 0.065), -hr * (0.27 + i * 0.115), -hr * 0.21), Vector3(0, 0, side * 24), Vector3(0.95, 0.72, 1.0))
	if s.tan_points:
		for side in [-1.0, 1.0]:
			_m(_head, _sphere(hr * 0.26), tan, Vector3(side * hr * 0.56, -hr * 0.26, -hr * 0.63), Vector3.ZERO, Vector3(0.95, 0.90, 0.40))
	if s.blaze:
		_m(_head, _sphere(hr * 0.26), mark, Vector3(0, hr * 0.43, -hr * 0.79), Vector3(-24, 0, 0), Vector3(0.30, 1.58, 0.30))
	_build_face()
	_build_ears()
	_build_tail()
	_build_bandana()

	_catch_bubble = MeshInstance3D.new()
	_catch_bubble.mesh = _sphere(length * 0.76)
	_catch_bubble.material_override = Mats.unlit(Color(player_color, 0.20))
	_catch_bubble.position = Vector3(0, _body_y, -length * 0.15)
	_catch_bubble.visible = false
	_catch_bubble.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_catch_bubble)


func _build_legs() -> void:
	var s := _spec
	var r: float = s.body_r
	var hip_x: float = r * 0.62 * s.body_sx
	var hip_z: float = s.body_len * 0.5 - r * 0.66
	for p in [Vector3(-hip_x, -r * 0.35, -hip_z), Vector3(hip_x, -r * 0.35, -hip_z), Vector3(-hip_x, -r * 0.35, hip_z), Vector3(hip_x, -r * 0.35, hip_z)]:
		var pivot := Node3D.new()
		pivot.position = p
		_body.add_child(pivot)
		var total: float = _body_y + p.y
		var leg_col := data.secondary_color if s.tan_points else data.fur_color
		_ink(_m(pivot, _capsule(s.leg_r, total), leg_col, Vector3(0, -total * 0.40, 0)), 0.8)
		_m(pivot, _sphere(s.leg_r * 1.38), data.fur_color, Vector3(0, -0.04, 0.025), Vector3.ZERO, Vector3(1, 1.45, 1))
		var paw_col := data.markings_color if s.socks else data.fur_color
		var paw_y: float = -total + s.leg_r * 0.65
		_ink(_m(pivot, _sphere(s.leg_r * 1.32), paw_col, Vector3(0, paw_y, -s.leg_r * 0.32), Vector3.ZERO, Vector3(1.02, 0.69, 1.23)), 0.8)
		# Three soft toes read as paws in the close-up turntable.
		for toe in 3:
			_m(pivot, _sphere(s.leg_r * 0.43), paw_col, Vector3((toe - 1) * s.leg_r * 0.66, paw_y - s.leg_r * 0.12, -s.leg_r * 1.18), Vector3.ZERO, Vector3(0.85, 0.96, 0.88))
		_legs.append(pivot)


func _build_face() -> void:
	var hr: float = _spec.head_r
	var sr: float = _spec.snout_r
	for side in [-1.0, 1.0]:
		var eye := Node3D.new()
		eye.position = Vector3(side * hr * 0.43, hr * 0.24, -hr * 0.80)
		eye.rotation_degrees.y = -side * 9.0
		_head.add_child(eye)
		var er := hr * 0.245
		_m(eye, _sphere(er * 1.13), data.secondary_color if _spec.tan_points else data.fur_color, Vector3(0, 0.008, 0.005), Vector3.ZERO, Vector3(1.07, 1.13, 0.57))
		_m(eye, _sphere(er), CREAM, Vector3.ZERO, Vector3.ZERO, Vector3(0.97, 1.06, 0.55))
		_m(eye, _sphere(er * 0.80), IRIS, Vector3(0, 0.003, -er * 0.43), Vector3.ZERO, Vector3(0.94, 1.04, 0.50), true)
		_m(eye, _sphere(er * 0.55), EYE_BLACK, Vector3(0, 0.008, -er * 0.76), Vector3.ZERO, Vector3(0.95, 1.06, 0.31), true)
		_m(eye, _sphere(er * 0.20), Color.WHITE, Vector3(-er * 0.23, er * 0.37, -er * 0.91))
		_m(eye, _sphere(er * 0.075), Color.WHITE, Vector3(er * 0.26, -er * 0.25, -er * 0.91))
		_eyes.append(eye)
		var brow_col := data.secondary_color if _spec.tan_points else data.fur_color.lightened(0.09)
		_m(_head, _sphere(hr * 0.145), brow_col, Vector3(side * hr * 0.43, hr * 0.62, -hr * 0.68), Vector3(0, 0, side * 13), Vector3(0.93, 0.63, 0.42))

	var muzzle_color := data.markings_color
	var muzzle_z := -hr * 0.86
	# The grip lives in the moving head, at the open mouth, and inherits its motion.
	_mouth_socket = Marker3D.new()
	_mouth_socket.name = "MouthSocket"
	_mouth_socket.position = Vector3(0, -hr * 0.38, muzzle_z - sr * 0.63)
	_head.add_child(_mouth_socket)
	# Open mouth sits behind the two rounded muzzle cheeks, with a visible lower jaw.
	_m(_head, _sphere(sr * 0.84), MOUTH, Vector3(0, -hr * 0.40, muzzle_z - sr * 0.22), Vector3.ZERO, Vector3(1.02, 0.66, 0.50))
	_m(_head, _sphere(sr * 0.84), muzzle_color, Vector3(0, -hr * 0.55, muzzle_z + sr * 0.015), Vector3.ZERO, Vector3(1.0, 0.36, 0.60))
	for side in [-1.0, 1.0]:
		_ink(_m(_head, _sphere(sr * 0.62), muzzle_color, Vector3(side * sr * 0.40, -hr * 0.20, muzzle_z - sr * 0.20), Vector3.ZERO, Vector3(1.02, 0.84, 0.96)), 0.6)
		for spot in 3:
			_m(_head, _sphere(sr * 0.038), muzzle_color.darkened(0.36), Vector3(side * sr * (0.41 + (spot % 2) * 0.20), -hr * 0.20 - (spot / 2) * sr * 0.17, muzzle_z - sr * 0.88))
	_m(_head, _sphere(sr * 0.37), EYE_BLACK, Vector3(0, -hr * 0.05, muzzle_z - sr * 0.70), Vector3.ZERO, Vector3(1.20, 0.76, 0.70), true)
	for side in [-1.0, 1.0]:
		_m(_head, _sphere(sr * 0.085), Color(0.012, 0.009, 0.012), Vector3(side * sr * 0.21, -hr * 0.06, muzzle_z - sr * 1.06), Vector3.ZERO, Vector3(1.1, 0.72, 0.5))
	_m(_head, _sphere(sr * 0.50), PINK, Vector3(0, -hr * 0.48, muzzle_z - sr * 0.60), Vector3(-12, 0, 0), Vector3(0.77, 0.75, 0.35))
	_m(_head, _capsule(sr * 0.016, sr * 0.40), PINK.darkened(0.2), Vector3(0, -hr * 0.47, muzzle_z - sr * 0.78), Vector3.ZERO)


## Convex rounded triangular ear, with an inset pink inner ear; no cone-shaped horns.
func _ear_mesh(width: float, length: float, depth: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var points := PackedVector3Array([
		Vector3(-width, 0, 0), Vector3(-width * 0.62, length * 0.70, 0),
		Vector3(-width * 0.13, length, depth * 0.2), Vector3(width * 0.15, length * 0.98, depth * 0.2),
		Vector3(width * 0.66, length * 0.62, 0), Vector3(width, 0, 0)])
	var front := Vector3(0, length * 0.40, -depth)
	var back := Vector3(0, length * 0.42, depth)
	for i in points.size():
		var next := (i + 1) % points.size()
		for vertex in [front, points[i], points[next], back, points[next], points[i]]:
			st.add_vertex(vertex)
	st.generate_normals()
	return st.commit()


func _build_ears() -> void:
	var hr: float = _spec.head_r
	var e: float = _spec.ear_size
	for side in [-1.0, 1.0]:
		var pivot := Node3D.new()
		_head.add_child(pivot)
		if _spec.ears == Ears.UPRIGHT:
			pivot.position = Vector3(side * hr * 0.69, hr * 0.65, 0.015)
			pivot.rotation_degrees = Vector3(-9, side * 8, -side * 16)
			_ink(_m(pivot, _ear_mesh(e, e * 2.20, e * 0.38), data.fur_color), 0.85)
			var inner := Color(0.64, 0.34, 0.32) if data.breed == DogData.Breed.PITBULL else data.secondary_color
			_m(pivot, _ear_mesh(e * 0.67, e * 1.68, e * 0.13), inner, Vector3(0, e * 0.19, -e * 0.29))
			if data.breed == DogData.Breed.CORGI:
				_m(pivot, _ear_mesh(e * 0.40, e * 1.26, e * 0.07), Color(0.83, 0.61, 0.58), Vector3(0, e * 0.26, -e * 0.40))
		else:
			pivot.position = Vector3(side * hr * 0.90, hr * 0.48, -hr * 0.015)
			pivot.rotation_degrees = Vector3(-8, side * 7, side * 8)
			var long_ear: bool = _spec.ears == Ears.LONG_FLOPPY
			var ear_col := data.secondary_color if data.breed == DogData.Breed.GOLDEN else data.fur_color
			_ink(_m(pivot, _sphere(e), ear_col, Vector3(side * e * 0.16, -e * 0.78, 0), Vector3(0, 0, -side * 10), Vector3(0.79, 1.60 if long_ear else 1.42, 0.65)), 0.85)
			if _spec.fluffy:
				for i in 4:
					_m(pivot, _capsule(e * 0.23, e * 1.25), ear_col, Vector3(side * (i - 1.5) * e * 0.30, -e * (1.04 + sin(i * 1.7) * 0.15), -e * 0.36), Vector3(-5, 0, side * (i - 1.5) * 10))
		_ears.append(pivot)


func _build_tail() -> void:
	var r: float = _spec.body_r
	_tail = Node3D.new()
	_tail.position = Vector3(0, r * 0.38, _spec.body_len * 0.5 - r * 0.20)
	_tail.rotation_degrees.x = 57
	_body.add_child(_tail)
	var tail_r := r * (0.34 if _spec.tail == Tail.FLUFFY else 0.22)
	var tail_len := r * (1.55 if _spec.tail == Tail.FLUFFY else 1.70)
	var tip_col := data.secondary_color if data.breed == DogData.Breed.SPANIEL else data.fur_color
	if _spec.tail == Tail.BOB:
		_ink(_m(_tail, _sphere(r * 0.36), data.fur_color, Vector3(0, r * 0.26, 0), Vector3.ZERO, Vector3(1.0, 1.15, 1.0)), 0.75)
		_m(_tail, _sphere(r * 0.27), tip_col, Vector3(0, r * 0.52, -r * 0.05), Vector3.ZERO, Vector3(1.0, 0.95, 1.0))
		return
	# Stacked segments, each leaning a little further back, so the tail arcs instead of
	# standing up like an antenna.
	var segments := 3
	var segment_len := tail_len / float(segments)
	var joint := _tail
	for i in segments:
		var next := Node3D.new()
		next.position.y = 0.0 if i == 0 else segment_len
		next.rotation_degrees.x = -11.0 if i > 0 else 0.0
		joint.add_child(next)
		joint = next
		var taper := tail_r * (1.0 - i * 0.09)
		_ink(_m(joint, _capsule(taper, segment_len * 1.6), data.fur_color, Vector3(0, segment_len * 0.5, 0)), 0.75)
		if _spec.tail == Tail.FLUFFY and i > 0:
			for side in [-1.0, 1.0]:
				_m(joint, _capsule(taper * 0.86, segment_len * 1.5), tip_col, Vector3(side * taper * 0.52, segment_len * 0.5, -taper * 0.18), Vector3(-14, 0, -side * 10))
	_m(joint, _sphere(tail_r * 0.86), tip_col, Vector3(0, segment_len * 1.02, -segment_len * 0.1), Vector3(-22, 0, 0), Vector3(1, 1.25, 1))


func _build_bandana() -> void:
	var hr: float = _spec.head_r
	var r: float = _spec.body_r
	var neck_z: float = -_spec.body_len * 0.38
	var col := data.bandana_color
	_m(_body, Mats.torus(hr * 0.62, hr * 0.78), col, Vector3(0, r * 0.30, neck_z), Vector3(16, 0, 0), Vector3(1.10, 0.66, 1.0))
	var bib := Node3D.new()
	# The bib hangs DOWN the chest from the collar. Projecting it forward is what used to
	# park it across the dog's muzzle.
	bib.position = Vector3(0, -r * 0.34, neck_z - hr * 0.34)
	bib.rotation_degrees.x = -22
	_body.add_child(bib)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var points := [Vector3(-hr * 0.72, hr * 0.22, 0.03), Vector3(hr * 0.72, hr * 0.22, 0.03), Vector3(0, -hr * 0.74, -0.05)]
	for i in [0, 1, 2]:
		st.add_vertex(points[i])
	st.generate_normals()
	var mi := _m(bib, st.commit(), col)
	var fabric := _material(col).duplicate() as StandardMaterial3D
	fabric.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = fabric
	if data.breed == DogData.Breed.CORGI:
		for p in [Vector2(-0.15, 0.015), Vector2(0.13, 0.015), Vector2(0, -0.10), Vector2(-0.09, -0.14), Vector2(0.03, -0.22)]:
			_flower(bib, Vector3(p.x, p.y, -0.051), hr * 0.12)
	else:
		_paw(bib, Vector3(0, -hr * 0.20, -0.06), hr * 0.30)
	# The tied bow also keeps the dog's identity legible when running away.
	var knot_pos := Vector3(0, r * 0.50, neck_z + hr * 0.60)
	_m(_body, _sphere(hr * 0.13), col, knot_pos)
	for side in [-1.0, 1.0]:
		_m(_body, _sphere(hr * 0.23), col, knot_pos + Vector3(side * hr * 0.23, hr * 0.04, 0), Vector3(0, 0, -side * 24), Vector3(1, 0.50, 0.55))


func _paw(parent: Node3D, pos: Vector3, radius: float) -> void:
	_m(parent, _sphere(radius * 0.43), CREAM, pos + Vector3(0, -radius * 0.18, -0.01), Vector3.ZERO, Vector3(1.15, 0.92, 0.14))
	for i in 4:
		var angle := deg_to_rad(-65.0 + i * 43.0)
		_m(parent, _sphere(radius * 0.23), CREAM, pos + Vector3(sin(angle) * radius * 0.66, cos(angle) * radius * 0.66, -0.01), Vector3(0, 0, -rad_to_deg(angle)), Vector3(0.77, 1.07, 0.18))


func _flower(parent: Node3D, pos: Vector3, radius: float) -> void:
	for i in 5:
		var angle := i * TAU / 5.0
		_m(parent, _sphere(radius * 0.49), CREAM, pos + Vector3(cos(angle) * radius * 0.57, sin(angle) * radius * 0.57, -0.008), Vector3.ZERO, Vector3(1, 1, 0.16))
	_m(parent, _sphere(radius * 0.33), Color(1, 0.78, 0.22), pos + Vector3(0, 0, -0.02), Vector3.ZERO, Vector3(1, 1, 0.25))


func update_motion(facing: Vector3, speed01: float, delta: float = 1.0 / 60.0) -> void:
	if is_instance_valid(_dizzy_stars):
		_dizzy_stars.rotation.y += delta * 7.0
		if is_instance_valid(_body):
			_body.rotation.z = sin(Time.get_ticks_msec() * 0.011) * 0.12
	if _knocked_out:
		return
	speed01 = clampf(speed01, 0.0, 1.0)
	if facing.length_squared() > 0.001:
		_target_basis = Basis.looking_at(facing, Vector3.UP)
	quaternion = quaternion.slerp(_target_basis.get_rotation_quaternion(), minf(1.0, 18.0 * delta))
	_walk_phase += (0.35 + speed01 * 20.0) * delta
	var t := Time.get_ticks_msec() * 0.001
	var swing := sin(_walk_phase) * 0.65 * speed01
	for i in _legs.size():
		_legs[i].rotation.x = -1.1 if _catching and i < 2 else (swing if (i == 0 or i == 3) else -swing)
	_body.position.y = _body_y + absf(sin(_walk_phase)) * 0.065 * speed01 + sin(t * 2.2) * 0.009
	_body.rotation.x = (-0.23 if _dashing else 0.0) + sin(_walk_phase) * 0.025 * speed01
	_head.position.y = _head_y + absf(sin(_walk_phase + 0.5)) * 0.028 * speed01
	_head.rotation.z = sin(t * 1.7) * 0.04 * (1.0 - speed01 * 0.7)
	_head.rotation.x = -0.10 if _catching else (-0.055 if _dashing else 0.0)
	_tail.rotation.y = sin(t * 10.0) * (0.28 + speed01 * 0.35)
	for i in _ears.size():
		_ears[i].rotation.x = deg_to_rad(-9.0) + sin(_walk_phase - 0.5) * (0.13 if _spec.ears == Ears.UPRIGHT else 0.32) * speed01
	# Brief offset blinks avoid a mechanical stare without hiding action feedback.
	var blink_clock := fmod(t + float(data.breed) * 0.71, 4.2)
	var blink := 1.0 - sin(blink_clock / 0.14 * PI) * 0.93 if blink_clock < 0.14 and not _catching else 1.0
	for eye in _eyes:
		eye.scale.y = blink


## Seeing stars: a ring of sparks over the head plus a wobble, driven from Dog.
func set_dizzy(on: bool) -> void:
	if on == (_dizzy_stars != null and is_instance_valid(_dizzy_stars)):
		return
	if not on:
		if is_instance_valid(_dizzy_stars):
			_dizzy_stars.queue_free()
		_dizzy_stars = null
		if is_instance_valid(_body):
			_body.rotation.z = 0.0
		return
	_dizzy_stars = Node3D.new()
	_dizzy_stars.position = Vector3(0, height() + 0.22, 0)
	add_child(_dizzy_stars)
	for i in 3:
		var star := Mats.mesh(_dizzy_stars, Mats.sphere(0.075), Color(1.0, 0.86, 0.3), Vector3(0.30, 0, 0).rotated(Vector3.UP, TAU * float(i) / 3.0))
		star.material_override = Mats.unlit(Color(1.0, 0.88, 0.35))
		star.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func set_dashing(v: bool) -> void:
	_dashing = v
	if _squash_tween != null:
		_squash_tween.kill()
	scale = (Vector3(0.91, 0.87, 1.16) if v else Vector3.ONE) * data.model_scale


func get_mouth_transform() -> Transform3D:
	return _mouth_socket.global_transform if is_instance_valid(_mouth_socket) else global_transform


func set_catching(v: bool) -> void:
	_catching = v
	_catch_bubble.visible = v


func squash() -> void:
	if _squash_tween != null:
		_squash_tween.kill()
	scale = Vector3(1.17, 0.80, 1.17) * data.model_scale
	_squash_tween = create_tween()
	_squash_tween.tween_property(self, "scale", Vector3.ONE * data.model_scale, 0.25).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


func play_knocked_out(dir: Vector3) -> void:
	_knocked_out = true
	_catch_bubble.visible = false
	for mesh in _meshes:
		mesh.transparency = 0.45
	var tween := create_tween().set_parallel(true)
	tween.tween_property(self, "rotation:z", PI / 2.0, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "rotation:y", rotation.y + TAU, 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "position", position + dir * 1.2 + Vector3(0, 0.1, 0), 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
