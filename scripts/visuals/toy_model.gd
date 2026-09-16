class_name ToyModel
extends Node3D
## Compact dog-toy silhouettes, with matte rubber, stitched rope and clear colours.

var data: ToyData


func setup(p_data: ToyData) -> void:
	data = p_data
	for child in get_children():
		child.queue_free()
	var r := data.radius
	var c := data.color
	match data.id:
		&"frisbee":
			Mats.mesh(self, Mats.cylinder(r, r * 0.15, r * 0.92), c)
			Mats.mesh(self, Mats.torus(r * 0.72, r), c.lightened(0.16), Vector3(0, r * 0.075, 0))
			Mats.mesh(self, Mats.cylinder(r * 0.39, r * 0.017), Color(1.0, 0.91, 0.70), Vector3(0, r * 0.089, 0))
		&"bone":
			Mats.mesh(self, Mats.capsule(r * 0.29, r * 1.8), c, Vector3.ZERO, Vector3(0, 0, 90))
			for x in [-1.0, 1.0]:
				for z in [-1.0, 1.0]:
					Mats.mesh(self, _sphere(r * 0.40), c, Vector3(x * r * 0.70, 0, z * r * 0.29))
			Mats.mesh(self, Mats.torus(r * 0.27, r * 0.33), c.darkened(0.12), Vector3.ZERO, Vector3(0, 0, 90))
		&"rope_toy":
			# Three visible twisted strands distinguish it from the bone at game scale.
			for strand in 3:
				var color := [c, Color(0.98, 0.68, 0.31), Color(0.93, 0.92, 0.82)][strand] as Color
				for step in 12:
					var x := lerpf(-r * 0.67, r * 0.67, step / 11.0)
					var phase := step * 0.82 + strand * TAU / 3.0
					Mats.mesh(self, _sphere(r * 0.145), color, Vector3(x, sin(phase) * r * 0.14, cos(phase) * r * 0.14))
			for side in [-1.0, 1.0]:
				Mats.mesh(self, _sphere(r * 0.29), c, Vector3(side * r * 0.75, 0, 0))
				Mats.mesh(self, Mats.torus(r * 0.19, r * 0.29), Color(0.96, 0.79, 0.51), Vector3(side * r * 0.75, 0, 0), Vector3(0, 0, 90))
				for i in 3:
					Mats.mesh(self, Mats.capsule(r * 0.06, r * 0.36), c.lightened(i * 0.14), Vector3(side * r * 1.0, (i - 1) * r * 0.10, 0), Vector3(0, 0, 90 + (i - 1) * 15))
		&"squeaky_chicken":
			Mats.mesh(self, _sphere(r * 0.64), c, Vector3(0, 0, r * 0.18), Vector3.ZERO, Vector3(0.82, 0.82, 1.20))
			Mats.mesh(self, Mats.capsule(r * 0.18, r * 0.69), c, Vector3(0, r * 0.13, -r * 0.46), Vector3(-35, 0, 0))
			Mats.mesh(self, _sphere(r * 0.34), c, Vector3(0, r * 0.38, -r * 0.69))
			Mats.mesh(self, Mats.cylinder(r * 0.16, r * 0.31, 0.0), Color(1.0, 0.39, 0.08), Vector3(0, r * 0.30, -r * 0.99), Vector3(-90, 0, 0))
			for i in 3:
				Mats.mesh(self, _sphere(r * 0.12), Color(0.88, 0.12, 0.12), Vector3(0, r * 0.69, -r * (0.54 + i * 0.14)), Vector3.ZERO, Vector3(0.6, 1.5, 1))
			for side in [-1.0, 1.0]:
				Mats.mesh(self, _sphere(r * 0.08), Color(0.06, 0.03, 0.03), Vector3(side * r * 0.23, r * 0.47, -r * 0.90))
				Mats.mesh(self, _sphere(r * 0.32), c.darkened(0.11), Vector3(side * r * 0.41, r * 0.02, r * 0.19), Vector3.ZERO, Vector3(0.3, 0.65, 1.1))
				Mats.mesh(self, Mats.capsule(r * 0.10, r * 0.45), Color(1.0, 0.4, 0.1), Vector3(side * r * 0.28, -r * 0.10, r * 0.80), Vector3(90, 0, 0))
		&"super_ball":
			var ball := Mats.mesh(self, _sphere(r), c)
			var rubber := Mats.flat(c, 0.35)
			rubber.metallic_specular = 0.45
			ball.material_override = rubber
			for angle in [0.0, 60.0, 120.0]:
				Mats.mesh(self, Mats.torus(r * 0.955, r * 1.012), Color(1.0, 0.81, 0.33), Vector3.ZERO, Vector3(angle, 0, 30))
		_:
			Mats.mesh(self, _sphere(r), c)
			# Each curved seam is a single smooth ribbon, hugging the ball surface.
			for side in [-1.0, 1.0]:
				Mats.mesh(self, _tennis_seam(r, side), Color(0.98, 0.98, 0.85))


func _sphere(radius: float) -> SphereMesh:
	var sphere := SphereMesh.new()
	sphere.radius = radius
	sphere.height = radius * 2.0
	sphere.radial_segments = 24
	sphere.rings = 12
	return sphere


func _tennis_seam(radius: float, side: float) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var pairs: Array[Vector3] = []
	for i in 49:
		var angle := i * TAU / 48.0
		var center := Vector3(sin(angle) * 0.81, cos(angle), side * (0.46 + 0.19 * cos(angle * 2.0))).normalized()
		var ahead := Vector3(sin(angle + 0.01) * 0.81, cos(angle + 0.01), side * (0.46 + 0.19 * cos((angle + 0.01) * 2.0))).normalized()
		var across := center.cross(ahead - center).normalized() * 0.035
		pairs.append((center - across).normalized() * radius * 1.008)
		pairs.append((center + across).normalized() * radius * 1.008)
	for i in 48:
		for index in [i * 2, i * 2 + 2, i * 2 + 1, i * 2 + 1, i * 2 + 2, i * 2 + 3]:
			surface.set_normal(pairs[index].normalized())
			surface.add_vertex(pairs[index])
	return surface.commit()
