@tool
class_name ArenaArt
extends RefCounted
## Shared, deliberately simple craftsmanship: chamfered edges catch the light without
## adding noisy textures. The bevel always stays within the authored collision footprint.

static var _boxes: Dictionary = {}


static func rounded_box(dimensions: Vector3, bevel: float = 0.06) -> ArrayMesh:
	var key := "%s:%s" % [dimensions, bevel]
	if _boxes.has(key):
		return _boxes[key]
	var half := dimensions * 0.5
	var b := minf(bevel, minf(half.x, minf(half.y, half.z)) * 0.8)
	var inner := half - Vector3.ONE * b
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Six broad faces, twelve small bevel faces, and the eight corner caps.
	for axis in 3:
		var u := (axis + 1) % 3
		var v := (axis + 2) % 3
		for side in [-1.0, 1.0]:
			var points: Array[Vector3] = []
			for corner in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
				var p := Vector3.ZERO
				p[axis] = half[axis] * side
				p[u] = inner[u] * corner.x
				p[v] = inner[v] * corner.y
				points.append(p)
			_face(st, points)
	for axis in 3:
		var u := (axis + 1) % 3
		var v := (axis + 2) % 3
		for su in [-1.0, 1.0]:
			for sv in [-1.0, 1.0]:
				var points: Array[Vector3] = []
				for corner in [Vector2(-1, 0), Vector2(1, 0), Vector2(1, 1), Vector2(-1, 1)]:
					var p := Vector3.ZERO
					p[axis] = inner[axis] * corner.x
					p[u] = (half[u] if corner.y == 0 else inner[u]) * su
					p[v] = (inner[v] if corner.y == 0 else half[v]) * sv
					points.append(p)
				_face(st, points)
	for sx in [-1.0, 1.0]:
		for sy in [-1.0, 1.0]:
			for sz in [-1.0, 1.0]:
				_face(st, [Vector3(half.x * sx, inner.y * sy, inner.z * sz),
					Vector3(inner.x * sx, half.y * sy, inner.z * sz),
					Vector3(inner.x * sx, inner.y * sy, half.z * sz)])
	var result := st.commit()
	_boxes[key] = result
	return result


static func _face(st: SurfaceTool, points: Array[Vector3]) -> void:
	var normal := (points[1] - points[0]).cross(points[2] - points[0]).normalized()
	var center := Vector3.ZERO
	for p in points:
		center += p
	if normal.dot(center) < 0.0:
		points.reverse()
		normal = -normal
	# Godot's front faces use clockwise winding.
	for i in range(1, points.size() - 1):
		for index in [0, i + 1, i]:
			st.set_normal(normal)
			st.add_vertex(points[index])


static func block(parent: Node3D, dimensions: Vector3, tint: Color, pos: Vector3 = Vector3.ZERO,
		rot_deg: Vector3 = Vector3.ZERO, bevel: float = 0.06) -> MeshInstance3D:
	return Mats.mesh(parent, rounded_box(dimensions, bevel), tint, pos, rot_deg)


static func rod(parent: Node3D, from: Vector3, to: Vector3, radius: float, tint: Color) -> MeshInstance3D:
	var mesh := Mats.mesh(parent, Mats.cylinder(radius, from.distance_to(to)), tint, (from + to) * 0.5)
	mesh.quaternion = Quaternion(Vector3.UP, (to - from).normalized())
	return mesh


static func flower(parent: Node3D, pos: Vector3, tint: Color, radius: float = 0.11) -> void:
	for i in 5:
		var angle := TAU * float(i) / 5.0
		Mats.mesh(parent, Mats.sphere(radius), tint, pos + Vector3(cos(angle), 0, sin(angle)) * radius,
			Vector3.ZERO, Vector3(1, 0.5, 1))
	Mats.mesh(parent, Mats.sphere(radius * 0.6), Color("f4ca65"), pos + Vector3(0, radius * 0.35, 0), Vector3.ZERO, Vector3(1, 0.6, 1))


static func paw(parent: Node3D, pos: Vector3, radius: float, tint: Color) -> void:
	var pad := Mats.mesh_plain(parent, Mats.cylinder(radius * 0.48, 0.012), tint, pos)
	pad.scale.z = 0.8
	pad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for i in 3:
		var toe := Mats.mesh_plain(parent, Mats.cylinder(radius * 0.2, 0.012), tint,
			pos + Vector3((i - 1) * radius * 0.43, 0, -radius * (0.65 if i == 1 else 0.48)))
		toe.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
