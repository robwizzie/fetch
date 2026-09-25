extends Node3D
## Quiet floor inlays and non-colliding perimeter scenery. The playable routes stay clear.

@export_enum("Courtyard", "Rooftop") var theme := "Courtyard"


func _ready() -> void:
	if theme == "Courtyard":
		_courtyard()
	else:
		_rooftop()


func _flat(dimensions: Vector3, tint: Color, at: Vector3) -> void:
	var mesh := Mats.mesh_plain(self, Mats.box(dimensions), tint, at)
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _courtyard() -> void:
	# Broad stone routes form a readable cross through the four garden islands.
	_flat(Vector3(27.5, 0.018, 3.0), Color("d8cba8"), Vector3(0, 0.046, 0))
	_flat(Vector3(3.0, 0.02, 17.5), Color("d8cba8"), Vector3(0, 0.048, 0))
	for edge in [-1.0, 1.0]:
		_flat(Vector3(27.4, 0.023, 0.075), Color("baad8b"), Vector3(0, 0.05, edge * 1.5))
		_flat(Vector3(0.075, 0.023, 17.4), Color("baad8b"), Vector3(edge * 1.5, 0.05, 0))
	Mats.mesh_plain(self, Mats.cylinder(2.35, 0.022), Color("b6b39a"), Vector3(0, 0.062, 0))
	Mats.mesh_plain(self, Mats.cylinder(2.2, 0.024), Color("e3d6b4"), Vector3(0, 0.075, 0))
	for petal in 8:
		var a := float(petal) * TAU / 8.0
		var m := Mats.mesh_plain(self, Mats.cylinder(0.4, 0.013), Color("cbbf99"), Vector3(cos(a) * 0.78, 0.092, sin(a) * 0.78))
		m.rotation.y = -a
		m.scale = Vector3(1.6, 1, 0.72)
	Mats.mesh_plain(self, Mats.cylinder(0.36, 0.016), Color("b2a682"), Vector3(0, 0.102, 0))
	# A walled garden backdrop with slatted trellises, entirely beyond the arena boundary.
	for side in [-1.0, 1.0]:
		var x: float = side * 9.1
		ArenaArt.block(self, Vector3(5.5, 0.62, 1.15), Color("aaa889"), Vector3(x, 0.31, -10.4), Vector3.ZERO, 0.13)
		for stem in 5:
			var px := x - 2.1 + stem * 1.05
			Mats.mesh(self, Mats.sphere(0.8), Color("749470"), Vector3(px, 0.99, -10.4), Vector3.ZERO, Vector3(1.0, 0.75, 0.7))
		for post in [-1.0, 1.0]:
			ArenaArt.block(self, Vector3(0.18, 2.55, 0.18), Color("718376"), Vector3(x + post * 2.55, 1.25, -10.4))
		ArenaArt.block(self, Vector3(5.5, 0.17, 0.36), Color("718376"), Vector3(x, 2.5, -10.4))
		for rail in 7:
			ArenaArt.block(self, Vector3(0.1, 0.11, 0.85), Color("92a08a"), Vector3(x - 2.25 + rail * 0.75, 2.62, -10.4))
	_label("SUNFLOWER COURT", Vector3(0, 1.5, -10.0), Color("5d7764"), Color("fff0c6"))
	for x in [-14.9, 14.9]:
		for z in [-6.7, 0.0, 6.7]:
			_lantern(Vector3(x, 0, z), Color("718376"), Color("ffe0a0"), 1.6)


func _rooftop() -> void:
	# Deck islands break up the slate without disguising the solid cover pieces.
	for x in [-6.3, 6.3]:
		_flat(Vector3(5.8, 0.026, 4.4), Color("546b7c"), Vector3(x, 0.05, 0))
		for z in [-1.97, 1.97]:
			_flat(Vector3(5.3, 0.031, 0.055), Color("819692"), Vector3(x, 0.057, z))
	for z in [-4.65, 4.65]:
		_flat(Vector3(6.15, 0.026, 2.45), Color("4c6574"), Vector3(0, 0.05, z))
	# Amber insets are on the parapet side of the arena edge and never look like pickups.
	for x in [-14.7, 14.7]:
		for z in [-5.0, 0.0, 5.0]:
			_flat(Vector3(0.065, 0.035, 1.0), Color("c9b886"), Vector3(x, 0.065, z))
	var skyline := [4.0, 5.3, 3.2, 6.0, 4.8, 3.7, 5.6, 4.2, 6.5, 3.3, 4.8]
	for i in skyline.size():
		var x := -20.0 + i * 4.0
		var h: float = skyline[i]
		var z := -15.4 - (i % 3) * 0.7
		var tone := Color("34475d") if i % 2 == 0 else Color("415569")
		ArenaArt.block(self, Vector3(3.45, h, 3.0), tone, Vector3(x, h * 0.5 - 0.8, z), Vector3.ZERO, 0.12)
		ArenaArt.block(self, Vector3(3.55, 0.14, 3.1), tone.lightened(0.07), Vector3(x, h - 0.78, z))
		for row in int(h / 1.0) - 1:
			for col in 3:
				if (i + col * 2 + row) % 4 == 0:
					continue
				var window := Mats.mesh_plain(self, Mats.box(Vector3(0.35, 0.43, 0.035)), Color("d8bc84"), Vector3(x - 0.85 + col * 0.85, row + 0.35, z + 1.52))
				window.material_override = Mats.unlit(Color("ad9675"))
	# A festoon across the rear parapet frames play without crossing the sightline.
	for x in [-14.6, 0.0, 14.6]:
		ArenaArt.block(self, Vector3(0.12, 2.8, 0.12), Color("566b78"), Vector3(x, 1.4, -9.1))
	for half in [-1.0, 1.0]:
		var start := Vector3(0, 2.76, -9.1)
		var previous := start
		for segment in range(1, 21):
			var t := segment / 20.0
			var point := Vector3(half * 14.6 * t, 2.76 - sin(t * PI) * 0.75, -9.1)
			_line(previous, point, Color("394f60"), 0.021)
			if segment % 2 == 1:
				var bulb := Mats.mesh(self, Mats.sphere(0.085), Color("ffe0a1"), point + Vector3(0, -0.09, 0))
				bulb.material_override = Mats.unlit(Color("f3d59c"))
			previous = point
	_label("THE WOOFTOP", Vector3(0, 1.45, -9.15), Color("465d70"), Color("edd8a6"))
	for x in [-15.8, 15.8]:
		for z in [-6.3, 6.3]:
			_lantern(Vector3(x, 0, z), Color("536a78"), Color("e3bf86"), 1.25)


func _line(from: Vector3, to: Vector3, tint: Color, width: float) -> void:
	var line := Mats.mesh(self, Mats.cylinder(width, from.distance_to(to)), tint, (from + to) * 0.5)
	line.quaternion = Quaternion(Vector3.UP, (to - from).normalized())


func _lantern(at: Vector3, tint: Color, light_tint: Color, height: float) -> void:
	ArenaArt.block(self, Vector3(0.4, 0.14, 0.4), tint, at + Vector3(0, 0.07, 0))
	ArenaArt.block(self, Vector3(0.1, height, 0.1), tint, at + Vector3(0, height * 0.5, 0))
	ArenaArt.block(self, Vector3(0.36, 0.43, 0.36), light_tint, at + Vector3(0, height, 0))
	ArenaArt.block(self, Vector3(0.46, 0.1, 0.46), tint, at + Vector3(0, height + 0.24, 0))


func _label(text: String, at: Vector3, plate_color: Color, ink: Color) -> void:
	var support_height := at.y - 0.22
	for x in [-1.9, 1.9]:
		ArenaArt.block(self, Vector3(0.11, support_height, 0.11), plate_color.darkened(0.12),
			Vector3(at.x + x, support_height * 0.5, at.z - 0.04))
	ArenaArt.block(self, Vector3(5.2, 0.75, 0.16), plate_color, at, Vector3.ZERO, 0.12)
	var label := Label3D.new()
	label.text = text
	label.font = UiKit.FONT_DISPLAY
	label.font_size = 58
	label.pixel_size = 0.0035
	label.modulate = ink
	label.outline_size = 0
	label.position = at + Vector3(0, 0, 0.095)
	add_child(label)
