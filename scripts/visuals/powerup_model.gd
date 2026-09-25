class_name PowerupModel
extends Node3D
## One sealed treat tin in the arena; the same tin, opened, in the field guide.
## The wrapper never reveals the rolled kind through its colour or silhouette.

const INK := Color("453354")
const CREAM := Color("fff0cb")
const CORAL := Color("ec796b")
const GOLD := Color("f5c66b")

var lid: Node3D


func setup(revealed_kind: StringName = &"") -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	var tint := CORAL if revealed_kind == &"" else PowerupKinds.color(revealed_kind)
	var shell := Mats.mesh(self, rounded_box(Vector3(0.76, 0.62, 0.66), 0.11), INK, Vector3(0, 0.39, 0))
	shell.material_override = Mats.plain(INK, 0.48)
	Mats.mesh(self, rounded_box(Vector3(0.79, 0.12, 0.69), 0.05), GOLD, Vector3(0, 0.13, 0))
	# The broad enamel label and cream seal read even at arena-camera distance.
	Mats.mesh(self, rounded_box(Vector3(0.58, 0.40, 0.045), 0.02), CREAM, Vector3(0, 0.41, 0.337))
	Mats.mesh(self, rounded_box(Vector3(0.12, 0.60, 0.025), 0.012), tint, Vector3(-0.29, 0.41, 0.335))
	Mats.mesh(self, rounded_box(Vector3(0.12, 0.60, 0.025), 0.012), tint, Vector3(0.29, 0.41, 0.335))
	lid = Node3D.new()
	lid.name = "Lid"
	lid.position.y = 0.73
	add_child(lid)
	Mats.mesh(lid, rounded_box(Vector3(0.84, 0.16, 0.74), 0.065), tint)
	Mats.mesh(lid, rounded_box(Vector3(0.87, 0.045, 0.77), 0.02), GOLD, Vector3(0, -0.055, 0))
	var glyph: StringName = &"mystery" if revealed_kind == &"" else revealed_kind
	_label(self, glyph, Vector3(0, 0.42, 0.366), Vector3.ZERO, 0.0027, INK)
	# A real top-facing seal, not a floating icon drawn through the box.
	Mats.mesh(lid, Mats.cylinder(0.255, 0.012), CREAM, Vector3(0, 0.086, 0))
	_label(lid, glyph, Vector3(0, 0.096, 0), Vector3(-90, 0, 0), 0.0028, INK)
	# A small paw stamp on the back makes the turning package feel finished.
	_label(self, &"paw", Vector3(0, 0.4, -0.337), Vector3(0, 180, 0), 0.0020, GOLD)
	if revealed_kind != &"":
		lid.position = Vector3(0, 0.92, -0.12)
		lid.rotation_degrees.x = -14
		var reward := Sprite3D.new()
		reward.texture = PowerupIcon.badge(revealed_kind, 192)
		reward.pixel_size = 0.0042
		reward.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		reward.position = Vector3(0, 1.40, 0)
		add_child(reward)


static func _label(parent: Node3D, kind: StringName, at: Vector3, angles: Vector3, pixels: float, tint: Color) -> void:
	var label := Sprite3D.new()
	label.texture = PowerupIcon.texture(kind, 128, tint)
	label.pixel_size = pixels
	label.position = at
	label.rotation_degrees = angles
	label.shaded = false
	parent.add_child(label)


## Rounded edges with continuous normals; no overlapping spheres at the corners.
static func rounded_box(dimensions: Vector3, radius: float) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var half := dimensions * 0.5
	var core := half - Vector3.ONE * radius
	var normals: Array[Vector3] = [Vector3.RIGHT, Vector3.LEFT, Vector3.UP, Vector3.DOWN, Vector3.FORWARD, Vector3.BACK]
	for normal in normals:
		var u := Vector3.UP if absf(normal.y) < 0.5 else Vector3.RIGHT
		var v := normal.cross(u)
		for row in 8:
			for col in 8:
				for offset: Vector2i in [Vector2i(0, 0), Vector2i(0, 1), Vector2i(1, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]:
					var cube := normal + u * (float(col + offset.x) / 4.0 - 1.0) + v * (float(row + offset.y) / 4.0 - 1.0)
					var point := cube * half
					var inner := point.clamp(-core, core)
					var outward := (point - inner).normalized()
					surface.set_normal(outward)
					surface.add_vertex(inner + outward * radius)
	return surface.commit()
