class_name ToyModel
extends Node3D
## Small, tactile dog toys: broad colour blocking, soft moulded edges and clean seams.
## All detail belongs to the visual mesh; the actor keeps its original collision radius.

var data: ToyData
var _materials: Dictionary = {}


func setup(p_data: ToyData) -> void:
	data = p_data
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_materials.clear()
	match data.id:
		&"frisbee": _frisbee()
		&"bone": _bone()
		&"rope_toy": _rope()
		&"squeaky_chicken": _chicken()
		&"super_ball": _super_ball()
		_: _tennis_ball()


func _frisbee() -> void:
	var r := data.radius
	# One continuous turned profile gives the lip a real rolled edge and recessed centre.
	var profile: Array[Vector2] = [
		Vector2(0, -0.04), Vector2(0.70, -0.04), Vector2(0.86, -0.13),
		Vector2(0.95, -0.13), Vector2(1.00, -0.08), Vector2(1.015, 0.02),
		Vector2(0.985, 0.12), Vector2(0.93, 0.16), Vector2(0.86, 0.14),
		Vector2(0.79, 0.065), Vector2(0.66, 0.035), Vector2(0, 0.035),
	]
	_rim(_part(_lathe(profile, r), data.color, Vector3.ZERO, Vector3.ONE, 0.4))
	_part(_ring(r * 0.903, r * 0.945), data.color.lightened(0.38), Vector3(0, r * 0.15, 0), Vector3(1, 0.36, 1), 0.45)
	# A raised cream paw stamp stays readable while the disc spins.
	_paw_stamp(Vector3(0, r * 0.057, 0), r * 0.54, Color("fff0c6"))


func _bone() -> void:
	var r := data.radius
	var bone := Color("efe3c6")
	# The cartoon bone: a slim round shaft with two fat knobs at each end. The knobs carry the
	# silhouette - with the shaft as wide as they were, the old single pillow shape read as a
	# cushion from the game camera.
	var shaft := CapsuleMesh.new()
	shaft.radius = r * 0.2
	shaft.height = r * 1.7
	shaft.radial_segments = 24
	shaft.rings = 6
	var bar := _part(shaft, bone, Vector3.ZERO, Vector3.ONE, 0.6)
	bar.rotation.z = PI * 0.5
	_rim(bar)
	for end in [-1.0, 1.0]:
		for side in [-1.0, 1.0]:
			# A touch flattened and splayed outwards, the way a drawn bone flares.
			var knob := _part(_sphere(r * 0.3), bone, Vector3(end * r * 0.8, 0, side * r * 0.24), Vector3(1.0, 0.9, 1.0), 0.6)
			_rim(knob)
	# A soft shade down the shaft so it reads as round, not a flat stick.
	_part(_sphere(r * 0.06), Color("d8c8a3"), Vector3(0, r * 0.17, 0), Vector3(9.0, 0.4, 1.4), 0.7)


func _rope() -> void:
	var r := data.radius
	var colors: Array[Color] = [Color("5e78d8"), Color("efab58"), Color("fff0ce")]
	for strand in 3:
		var phase := strand * TAU / 3.0
		var points: Array[Vector3] = []
		for step in 65:
			var t := step / 64.0
			var angle := t * TAU * 2.4 + phase
			points.append(Vector3(lerpf(-0.77, 0.77, t), sin(angle) * 0.13, cos(angle) * 0.13) * r)
		_part(_tube(points, r * 0.105), colors[strand], Vector3.ZERO, Vector3.ONE, 0.95)
	for side in [-1.0, 1.0]:
		# Two overlapping continuous loops bind each end into a soft, woven knot.
		for strand in 2:
			var knot: Array[Vector3] = []
			for step in 49:
				var angle := step * TAU / 48.0
				knot.append(Vector3(side * (0.75 + sin(angle * 2.0 + strand * PI) * 0.085), cos(angle) * 0.225, sin(angle) * 0.235) * r)
			_part(_tube(knot, r * 0.105), colors[strand], Vector3.ZERO, Vector3.ONE, 0.95)
		for strand in 5:
			var spread := (strand - 2) * 0.075
			var tassel: Array[Vector3] = []
			for step in 9:
				var t := step / 8.0
				tassel.append(Vector3(side * (0.86 + t * 0.35), spread * 0.2 - sin(t * PI * 0.5) * 0.045, spread * (0.35 + t)) * r)
			_part(_tube(tassel, r * 0.048, 8), colors[strand % 3], Vector3.ZERO, Vector3.ONE, 0.95)
			_part(_sphere(r * 0.048), colors[strand % 3], tassel.back(), Vector3.ONE, 0.95)


func _chicken() -> void:
	var r := data.radius
	var yellow := Color("ffd047")
	var orange := Color("f48237")
	var red := Color("de4b40")
	_part(_sphere(r * 0.62), yellow, Vector3(0, -r * 0.03, r * 0.20), Vector3(0.78, 1.05, 1.22), 0.56)
	# Bent rubber neck connects the head into the body instead of a separate straight peg.
	var neck: Array[Vector3] = []
	for step in 17:
		var t := step / 16.0
		neck.append(Vector3(0, lerpf(0.0, 0.44, t), lerpf(-0.19, -0.72, t)) * r)
	_part(_tube(neck, r * 0.205), yellow, Vector3.ZERO, Vector3.ONE, 0.56)
	_part(_sphere(r * 0.34), yellow, Vector3(0, r * 0.49, -r * 0.72), Vector3(0.90, 1.10, 1.0), 0.56)
	# A flattened open beak, white eye patches and dangling wattle read from above.
	_part(_sphere(r * 0.21), orange, Vector3(0, r * 0.41, -r * 1.025), Vector3(0.86, 0.40, 1.15), 0.5)
	_part(_sphere(r * 0.17), orange.darkened(0.12), Vector3(0, r * 0.33, -r * 1.01), Vector3(0.85, 0.25, 1.0), 0.55)
	_part(_sphere(r * 0.12), red, Vector3(0, r * 0.20, -r * 0.95), Vector3(0.68, 1.2, 0.7), 0.6)
	for i in 3:
		_part(_sphere(r * 0.12), red, Vector3(0, r * (0.81 + sin(i * PI * 0.5) * 0.045), -r * (0.58 + i * 0.14)), Vector3(0.65, 1.18, 0.93), 0.6)
	for side in [-1.0, 1.0]:
		_part(_sphere(r * 0.125), Color("fff9df"), Vector3(side * r * 0.23, r * 0.59, -r * 0.875), Vector3(0.76, 1.0, 0.65), 0.45)
		_part(_sphere(r * 0.064), Color("302a35"), Vector3(side * r * 0.27, r * 0.60, -r * 0.931), Vector3(0.73, 1.0, 0.6), 0.35)
		_part(_sphere(r * 0.019), Color.WHITE, Vector3(side * r * 0.271, r * 0.625, -r * 0.957), Vector3.ONE, 0.35)
		var wing := _part(_sphere(r * 0.35), Color("eaaa31"), Vector3(side * r * 0.43, r * 0.02, r * 0.18), Vector3(0.32, 0.72, 1.13), 0.65)
		wing.rotation_degrees.x = -17
		# Broad webbed feet make the silhouette unmistakably a rubber chicken.
		_part(_sphere(r * 0.20), orange, Vector3(side * r * 0.25, -r * 0.35, r * 0.92), Vector3(0.76, 0.43, 1.38), 0.6)
		for toe in 3:
			_part(_sphere(r * 0.085), orange, Vector3(side * r * 0.25 + (toe - 1) * r * 0.09, -r * 0.35, r * 1.14), Vector3(0.65, 0.62, 1.25), 0.6)
	_part(_sphere(r * 0.19), yellow, Vector3(0, r * 0.24, r * 0.83), Vector3(0.74, 0.85, 1.12), 0.56)


func _tennis_ball() -> void:
	var r := data.radius
	_rim(_part(_sphere(r), Color("acd345"), Vector3.ZERO, Vector3.ONE, 0.94))
	for side in [-1.0, 1.0]:
		# The darker channel seats the ivory seam in the felt instead of floating above it.
		_part(_tennis_seam(r * 1.003, side, 0.051), Color("a9bf45"), Vector3.ZERO, Vector3.ONE, 0.95)
		_part(_tennis_seam(r * 1.008, side, 0.026), Color("fff9d9"), Vector3.ZERO, Vector3.ONE, 0.85)


func _super_ball() -> void:
	var r := data.radius
	# Flush, gently spiralling rubber panels catch the light without the old orbital hoops.
	var colors: Array[Color] = [Color("774cc1"), Color("b18ee4"), Color("774cc1"), Color("59cdc4"), Color("774cc1"), Color("b18ee4")]
	_rim(_part(_sphere(r * 0.997), Color("fce6a8"), Vector3.ZERO, Vector3.ONE, 0.4))
	for panel in 6:
		_part(_ball_panel(r, panel * TAU / 6.0 + 0.019, (panel + 1) * TAU / 6.0 - 0.019), colors[panel], Vector3.ZERO, Vector3.ONE, 0.3)


func _part(mesh: Mesh, color: Color, at: Vector3 = Vector3.ZERO, size: Vector3 = Vector3.ONE, roughness: float = 0.65) -> MeshInstance3D:
	var key := "%s:%s" % [color.to_html(), roughness]
	if not _materials.has(key):
		var material := Mats.plain(color, roughness)
		material.metallic_specular = 0.36 if roughness < 0.6 else 0.18
		_materials[key] = material
	var part := MeshInstance3D.new()
	part.mesh = mesh
	part.material_override = _materials[key]
	part.position = at
	part.scale = size
	add_child(part)
	return part


## A dark rim around a toy's main form. Several toys sit within a shade of a floor colour
## somewhere in the set - a bone is all but invisible on kitchen lino and courtyard stone -
## and a toy nobody can pick out of the ground is a toy nobody goes for. Only the main form is
## rimmed; stamps and seams stay clean.
func _rim(part: MeshInstance3D) -> MeshInstance3D:
	Mats.outline(part, data.radius * 0.055, Color(0.19, 0.15, 0.13))
	return part


func _paw_stamp(at: Vector3, size: float, color: Color) -> void:
	_part(_sphere(size * 0.30), color, at + Vector3(0, 0, size * 0.13), Vector3(1.1, 0.045, 0.85))
	for i in 3:
		_part(_sphere(size * 0.145), color, at + Vector3((i - 1) * size * 0.29, 0, -size * (0.23 + (0.09 if i == 1 else 0.0))), Vector3(0.83, 0.06, 1.0))


func _sphere(radius: float) -> SphereMesh:
	var sphere := SphereMesh.new()
	sphere.radius = radius
	sphere.height = radius * 2.0
	sphere.radial_segments = 32
	sphere.rings = 16
	return sphere


func _ring(inner: float, outer: float) -> TorusMesh:
	var ring := TorusMesh.new()
	ring.inner_radius = inner
	ring.outer_radius = outer
	ring.rings = 64
	ring.ring_segments = 10
	return ring


func _lathe(profile: Array[Vector2], radius: float) -> ArrayMesh:
	var vertices: Array[Vector3] = []
	var normals: Array[Vector3] = []
	for row in profile.size():
		var tangent := profile[mini(row + 1, profile.size() - 1)] - profile[maxi(row - 1, 0)]
		for col in 65:
			var angle := col * TAU / 64.0
			vertices.append(Vector3(cos(angle) * profile[row].x, profile[row].y, sin(angle) * profile[row].x) * radius)
			normals.append(Vector3(cos(angle) * tangent.y, -tangent.x, sin(angle) * tangent.y).normalized())
	return _grid_mesh(vertices, normals, 65, profile.size())


func _pillow(contour: Array[Vector2], radius: float, height: float) -> ArrayMesh:
	var outline: Array[Vector2] = []
	for i in contour.size():
		for step in 4:
			outline.append(contour[i].cubic_interpolate(contour[(i + 1) % contour.size()], contour[posmod(i - 1, contour.size())], contour[(i + 2) % contour.size()], step / 4.0))
	var vertices: Array[Vector3] = []
	var normals: Array[Vector3] = []
	for row in 17:
		var angle := lerpf(-PI * 0.5, PI * 0.5, row / 16.0)
		for col in outline.size() + 1:
			var index := col % outline.size()
			var p := outline[index] * radius
			var tangent := outline[(index + 1) % outline.size()] - outline[posmod(index - 1, outline.size())]
			var out := Vector2(tangent.y, -tangent.x).normalized()
			vertices.append(Vector3(p.x * cos(angle), height * sin(angle), p.y * cos(angle)))
			normals.append(Vector3(out.x * cos(angle), sin(angle) * p.dot(out) / height, out.y * cos(angle)).normalized())
	return _grid_mesh(vertices, normals, outline.size() + 1, 17)


func _tube(points: Array[Vector3], radius: float, sides: int = 10) -> ArrayMesh:
	var vertices: Array[Vector3] = []
	var normals: Array[Vector3] = []
	for row in points.size():
		var tangent := (points[mini(row + 1, points.size() - 1)] - points[maxi(row - 1, 0)]).normalized()
		var reference := Vector3.UP if absf(tangent.dot(Vector3.UP)) < 0.9 else Vector3.FORWARD
		var across := tangent.cross(reference).normalized()
		var up := across.cross(tangent).normalized()
		for col in sides + 1:
			var angle := col * TAU / float(sides)
			var normal := across * cos(angle) + up * sin(angle)
			vertices.append(points[row] + normal * radius)
			normals.append(normal)
	return _grid_mesh(vertices, normals, sides + 1, points.size())


func _ball_panel(radius: float, start: float, end: float) -> ArrayMesh:
	var vertices: Array[Vector3] = []
	var normals: Array[Vector3] = []
	for row in 25:
		var latitude := lerpf(-PI * 0.5, PI * 0.5, row / 24.0)
		for col in 13:
			var longitude := lerpf(start, end, col / 12.0) + sin(latitude * 2.0) * 0.35
			var normal := Vector3(cos(latitude) * cos(longitude), sin(latitude), cos(latitude) * sin(longitude))
			vertices.append(normal * radius)
			normals.append(normal)
	return _grid_mesh(vertices, normals, 13, 25)


func _tennis_seam(radius: float, side: float, width: float) -> ArrayMesh:
	var vertices: Array[Vector3] = []
	var normals: Array[Vector3] = []
	for i in 65:
		var angle := i * TAU / 64.0
		var center := Vector3(sin(angle) * 0.81, cos(angle), side * (0.46 + 0.19 * cos(angle * 2.0))).normalized()
		var ahead := Vector3(sin(angle + 0.01) * 0.81, cos(angle + 0.01), side * (0.46 + 0.19 * cos((angle + 0.01) * 2.0))).normalized()
		var across := center.cross(ahead - center).normalized() * width
		for direction in [-1.0, 1.0]:
			var normal: Vector3 = (center + across * direction).normalized()
			vertices.append(normal * radius)
			normals.append(normal)
	return _grid_mesh(vertices, normals, 2, 65)


func _grid_mesh(vertices: Array[Vector3], normals: Array[Vector3], columns: int, rows: int) -> ArrayMesh:
	var indices := PackedInt32Array()
	for row in rows - 1:
		for col in columns - 1:
			var a := row * columns + col
			var b := a + 1
			var c := a + columns
			var d := c + 1
			# Godot treats clockwise faces as front-facing.
			indices.append_array(PackedInt32Array([a, b, c, b, d, c]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array(vertices)
	arrays[Mesh.ARRAY_NORMAL] = PackedVector3Array(normals)
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh
