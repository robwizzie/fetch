@tool
class_name SlowZone
extends Area3D
## A round area that slows dogs while inside (kiddie pool, mud, rug). Toys fly over it.

enum Look { POOL, RUG, MUD }

@export var radius := 1.8:
	set(v):
		radius = v
		_rebuild()
@export var look := Look.POOL:
	set(v):
		look = v
		_rebuild()
@export var color := Color(0.3, 0.7, 1.0):
	set(v):
		color = v
		_rebuild()
@export_range(0.1, 1.0) var slow_factor := 0.55

var _shape: CollisionShape3D
var _visual: Node3D


func _ready() -> void:
	collision_layer = 8
	collision_mask = 2
	monitorable = false
	_rebuild()
	if not Engine.is_editor_hint():
		body_entered.connect(_on_body_entered)
		body_exited.connect(_on_body_exited)


func _rebuild() -> void:
	if not is_inside_tree():
		return
	if _shape == null:
		_shape = CollisionShape3D.new()
		_shape.shape = CylinderShape3D.new()
		add_child(_shape)
	(_shape.shape as CylinderShape3D).radius = radius
	(_shape.shape as CylinderShape3D).height = 2.0
	_shape.position.y = 1.0
	if _visual:
		_visual.queue_free()
	_visual = Node3D.new()
	add_child(_visual)
	match look:
		Look.POOL:
			Mats.mesh(_visual, Mats.torus(radius, radius + 0.35), color.darkened(0.35), Vector3(0, 0.12, 0))
			var water := Mats.mesh(_visual, Mats.cylinder(radius + 0.05, 0.2), color, Vector3(0, 0.1, 0))
			water.material_override = Mats.glass(Color(color, 0.85))
			var shine := Mats.mesh(_visual, Mats.torus(radius * 0.5, radius * 0.56), Color(1, 1, 1), Vector3(-radius * 0.25, 0.21, -radius * 0.25))
			shine.material_override = Mats.unlit(Color(1, 1, 1, 0.5))
			shine.scale = Vector3(1, 0.05, 0.5)
		Look.RUG:
			Mats.mesh(_visual, Mats.cylinder(radius, 0.06), color, Vector3(0, 0.03, 0))
			Mats.mesh(_visual, Mats.cylinder(radius * 0.7, 0.07), color.lightened(0.18), Vector3(0, 0.03, 0))
		Look.MUD:
			Mats.mesh(_visual, Mats.cylinder(radius, 0.05), color, Vector3(0, 0.02, 0))


func _on_body_entered(body: Node3D) -> void:
	if body is Dog:
		body.speed_scale = slow_factor


func _on_body_exited(body: Node3D) -> void:
	if body is Dog:
		body.speed_scale = 1.0
