@tool
class_name Obstacle
extends StaticBody3D
## A solid prop. Pick a [member kind] and a footprint [member size]; the visual is built from
## primitives and the collider is the footprint box. Replace visuals with real models later
## by adding a child mesh and setting kind = CUSTOM.

enum Kind { BOX, CRATE, DOGHOUSE, TABLE, BUSH, COUCH, ARMCHAIR, TV, PLANT, TIRE, CUSTOM }

@export var kind := Kind.BOX:
	set(v):
		kind = v
		_rebuild()
@export var size := Vector3(2, 1.4, 2):
	set(v):
		size = v
		_rebuild()
@export var color := Color(0.8, 0.62, 0.38):
	set(v):
		color = v
		_rebuild()
@export var accent := Color(0.55, 0.38, 0.2):
	set(v):
		accent = v
		_rebuild()

var _shape: CollisionShape3D
var _visual: Node3D


func _ready() -> void:
	collision_layer = 1
	collision_mask = 0
	_rebuild()


func _rebuild() -> void:
	if not is_inside_tree():
		return
	if _shape == null:
		_shape = CollisionShape3D.new()
		_shape.shape = BoxShape3D.new()
		add_child(_shape)
	(_shape.shape as BoxShape3D).size = size
	_shape.position = Vector3(0, size.y / 2.0, 0)
	if _visual:
		_visual.queue_free()
	_visual = Node3D.new()
	add_child(_visual)
	var v := _visual
	var s := size
	match kind:
		Kind.CRATE:
			Mats.mesh(v, Mats.box(s), color, Vector3(0, s.y / 2.0, 0))
			Mats.mesh(v, Mats.box(Vector3(s.x + 0.04, 0.12, s.z + 0.04)), accent, Vector3(0, s.y * 0.2, 0))
			Mats.mesh(v, Mats.box(Vector3(s.x + 0.04, 0.12, s.z + 0.04)), accent, Vector3(0, s.y * 0.8, 0))
			Mats.mesh(v, Mats.box(Vector3(0.12, s.y + 0.04, s.z + 0.04)), accent, Vector3(0, s.y / 2.0, 0))
		Kind.DOGHOUSE:
			var body_h := s.y * 0.62
			Mats.mesh(v, Mats.box(Vector3(s.x, body_h, s.z)), color, Vector3(0, body_h / 2.0, 0))
			Mats.mesh(v, Mats.prism(Vector3(s.x * 1.2, s.y - body_h, s.z * 1.15)), accent, Vector3(0, body_h + (s.y - body_h) / 2.0, 0))
			Mats.mesh(v, Mats.box(Vector3(s.x * 0.4, body_h * 0.7, 0.1)), Color(0.12, 0.08, 0.06), Vector3(0, body_h * 0.35, s.z / 2.0))
		Kind.TABLE:
			Mats.mesh(v, Mats.box(Vector3(s.x, 0.16, s.z)), color, Vector3(0, s.y - 0.08, 0))
			for p in [Vector3(-1, 0, -1), Vector3(1, 0, -1), Vector3(-1, 0, 1), Vector3(1, 0, 1)]:
				Mats.mesh(v, Mats.cylinder(0.09, s.y - 0.16), accent, Vector3(p.x * (s.x / 2.0 - 0.25), (s.y - 0.16) / 2.0, p.z * (s.z / 2.0 - 0.25)))
		Kind.BUSH:
			var r := minf(s.x, s.z) * 0.42
			Mats.mesh(v, Mats.sphere(r), color, Vector3(0, r * 0.9, 0))
			Mats.mesh(v, Mats.sphere(r * 0.8), color, Vector3(-s.x * 0.28, r * 0.75, s.z * 0.1))
			Mats.mesh(v, Mats.sphere(r * 0.8), color.lightened(0.1), Vector3(s.x * 0.28, r * 0.8, -s.z * 0.1))
			Mats.mesh(v, Mats.sphere(r * 0.7), color.darkened(0.1), Vector3(0, r * 0.7, s.z * 0.3))
		Kind.COUCH, Kind.ARMCHAIR:
			var seat_h := s.y * 0.45
			Mats.mesh(v, Mats.box(Vector3(s.x, seat_h, s.z)), color, Vector3(0, seat_h / 2.0, 0))
			Mats.mesh(v, Mats.box(Vector3(s.x, s.y, s.z * 0.3)), color.darkened(0.12), Vector3(0, s.y / 2.0, -s.z * 0.35))
			Mats.mesh(v, Mats.box(Vector3(s.x * 0.12, s.y * 0.75, s.z)), color.darkened(0.12), Vector3(-s.x * 0.44, s.y * 0.375, 0))
			Mats.mesh(v, Mats.box(Vector3(s.x * 0.12, s.y * 0.75, s.z)), color.darkened(0.12), Vector3(s.x * 0.44, s.y * 0.375, 0))
			Mats.mesh(v, Mats.box(Vector3(s.x * 0.7, 0.14, s.z * 0.6)), accent, Vector3(0, seat_h + 0.07, s.z * 0.1))
		Kind.TV:
			Mats.mesh(v, Mats.box(Vector3(s.x, s.y * 0.35, s.z)), accent, Vector3(0, s.y * 0.175, 0))
			Mats.mesh(v, Mats.box(Vector3(s.x * 0.9, s.y * 0.62, 0.12)), color, Vector3(0, s.y * 0.35 + s.y * 0.31, 0))
			var screen := Mats.mesh(v, Mats.box(Vector3(s.x * 0.82, s.y * 0.52, 0.04)), Color(0.35, 0.6, 0.9), Vector3(0, s.y * 0.35 + s.y * 0.31, 0.06))
			screen.material_override = Mats.unlit(Color(0.4, 0.65, 0.95))
		Kind.PLANT:
			var pr := minf(s.x, s.z) * 0.4
			Mats.mesh(v, Mats.cylinder(pr, s.y * 0.4, pr * 0.8), accent, Vector3(0, s.y * 0.2, 0))
			Mats.mesh(v, Mats.sphere(pr * 1.25), color, Vector3(0, s.y * 0.72, 0))
			Mats.mesh(v, Mats.sphere(pr * 0.9), color.lightened(0.12), Vector3(pr * 0.5, s.y * 0.85, pr * 0.3))
		Kind.TIRE:
			var mi := Mats.mesh(v, Mats.torus(s.x * 0.22, s.x * 0.5), color, Vector3(0, s.y / 2.0, 0))
			mi.scale = Vector3(1, s.y / (s.x * 0.56), 1)
		Kind.CUSTOM:
			pass
		_:
			Mats.mesh(v, Mats.box(s), color, Vector3(0, s.y / 2.0, 0))
