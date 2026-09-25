@tool
extends Obstacle
## Authored furniture for the courtyard and roof. All decoration stays inside the solid
## footprint and participates in the normal obstacle fade when it hides a player.

@export_enum("Sunflower Bed", "Bench", "Roof Planter", "Vent") var prop_style := "Sunflower Bed":
	set(value):
		prop_style = value
		_rebuild()


func _rebuild() -> void:
	super._rebuild()
	if not is_inside_tree() or _visual == null or kind != Kind.CUSTOM:
		return
	match prop_style:
		"Sunflower Bed":
			_planter(true)
		"Roof Planter":
			_planter(false)
		"Bench":
			_bench()
		"Vent":
			_vent()
	if not Engine.is_editor_hint():
		_prepare_occlusion_materials()


func _planter(sunflowers: bool) -> void:
	var bed_h := size.y * 0.42
	_block(Vector3(size.x, bed_h, size.z), accent, Vector3(0, bed_h * 0.5, 0), 0.12)
	_block(Vector3(size.x + 0.03, 0.13, size.z + 0.03), accent.lightened(0.12), Vector3(0, bed_h, 0))
	_block(Vector3(size.x - 0.24, 0.08, size.z - 0.24), Color("5d5142"), Vector3(0, bed_h + 0.045, 0))
	var count := maxi(3, int(size.x / 0.85))
	for i in count:
		var x := lerpf(-size.x * 0.36, size.x * 0.36, float(i) / float(count - 1))
		var z := -0.1 if i % 2 == 0 else 0.13
		var leaf_y := bed_h + size.y * 0.18
		Mats.mesh(_visual, Mats.sphere(0.43), color, Vector3(x, leaf_y, z), Vector3.ZERO, Vector3(1, 0.7, 1.15))
		Mats.mesh(_visual, Mats.sphere(0.27), color.lightened(0.13), Vector3(x - 0.16, leaf_y + 0.13, z + 0.14))
		if sunflowers:
			var flower := Node3D.new()
			flower.position = Vector3(x, size.y * 0.91 + (0.05 if i % 2 == 0 else -0.06), z)
			flower.rotation_degrees.x = -34
			_visual.add_child(flower)
			Mats.mesh(_visual, Mats.cylinder(0.033, size.y * 0.42), Color("517043"), Vector3(x, bed_h + size.y * 0.24, z))
			for petal in 8:
				var a := float(petal) * TAU / 8.0
				Mats.mesh(flower, Mats.sphere(0.12), Color("efc256") if petal % 2 == 0 else Color("f6d47a"),
					Vector3(cos(a) * 0.17, sin(a) * 0.17, 0), Vector3(0, 0, rad_to_deg(a)), Vector3(1.35, 0.75, 0.48))
			Mats.mesh(flower, Mats.sphere(0.115), Color("765240"), Vector3(0, 0, 0.048), Vector3.ZERO, Vector3(1, 1, 0.5))
		else:
			for blade in 3:
				Mats.mesh(_visual, Mats.sphere(0.22), color.lightened(float(blade) * 0.05),
					Vector3(x + (blade - 1) * 0.13, leaf_y + 0.17, z), Vector3(0, 0, (blade - 1) * 24), Vector3(0.6, 1.65, 0.7))


func _bench() -> void:
	for x in [-size.x * 0.34, size.x * 0.34]:
		_block(Vector3(0.18, size.y * 0.56, size.z * 0.76), accent, Vector3(x, size.y * 0.28, 0))
	for slat in 4:
		var z := lerpf(-size.z * 0.39, size.z * 0.39, float(slat) / 3.0)
		_block(Vector3(size.x, 0.13, size.z * 0.21), color.lightened(float(slat % 2) * 0.05), Vector3(0, size.y * 0.55, z), 0.04)
	for x in [-size.x * 0.4, size.x * 0.4]:
		_block(Vector3(0.11, size.y * 0.6, 0.11), accent, Vector3(x, size.y * 0.7, -size.z * 0.4))
	for slat in 2:
		_block(Vector3(size.x, size.y * 0.17, 0.12), color, Vector3(0, size.y * (0.76 + slat * 0.2), -size.z * 0.4), 0.035)


func _vent() -> void:
	_block(Vector3(size.x, 0.17, size.z), accent, Vector3(0, 0.1, 0))
	_block(Vector3(size.x * 0.88, size.y * 0.8, size.z * 0.88), color, Vector3(0, size.y * 0.48, 0), 0.1)
	_block(Vector3(size.x * 0.94, 0.14, size.z * 0.94), color.lightened(0.16), Vector3(0, size.y * 0.92, 0))
	var r := minf(size.x, size.z) * 0.33
	Mats.mesh(_visual, Mats.cylinder(r, 0.026), accent.darkened(0.17), Vector3(0, size.y + 0.008, 0))
	for bar in 5:
		var x := (bar - 2) * r * 0.31
		_block(Vector3(0.042, 0.034, sqrt(maxf(0.0, r * r - x * x)) * 1.8), color, Vector3(x, size.y + 0.025, 0), 0.01)
	for slat in 4:
		_block(Vector3(size.x * 0.62, 0.045, 0.045), accent, Vector3(0, size.y * (0.3 + slat * 0.12), size.z * 0.445), 0.01)
