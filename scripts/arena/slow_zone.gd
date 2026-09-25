@tool
class_name SlowZone
extends Area3D
## A round area that slows dogs while inside (kiddie pool, mud, rug). Toys fly over it.

enum Look { POOL, RUG, MUD, TIDEPOOL }

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
			_build_pool()
		Look.RUG:
			_build_rug()
		Look.MUD:
			_build_puddle()
		Look.TIDEPOOL:
			_build_tidepool()


func _disc(r: float, height: float, tint: Color, y: float) -> MeshInstance3D:
	var mesh := Mats.mesh_plain(_visual, Mats.cylinder(r, height), tint, Vector3(0, y, 0))
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mesh


func _build_pool() -> void:
	# Two soft inflated courses and a pale lip give the pool a fitted, toy-like silhouette.
	Mats.contact_shadow(_visual, radius + 0.22)
	for course in 2:
		var ring := Mats.mesh(_visual, Mats.torus(radius * 0.96, radius + 0.23), color.darkened(0.13 if course == 0 else 0.0), Vector3(0, 0.10 + course * 0.12, 0))
		ring.scale.y = 0.48
	var lip := Mats.mesh(_visual, Mats.torus(radius * 0.98, radius + 0.18), color.lightened(0.34), Vector3(0, 0.27, 0))
	lip.scale.y = 0.26
	var water := _disc(radius, 0.04, color.lerp(Color("83c7c2"), 0.6), 0.19)
	# This shallow water surface otherwise self-shadows at the tiny scene scale.
	(water.material_override as StandardMaterial3D).disable_receive_shadows = true
	for i in 2:
		var ripple := Mats.mesh(_visual, Mats.torus(radius * (0.30 + i * 0.22), radius * (0.30 + i * 0.22) + 0.017), color.lightened(0.42), Vector3(-radius * 0.17, 0.216 + i * 0.002, -radius * 0.12))
		ripple.scale = Vector3(1.0, 0.15, 0.72)
		ripple.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		(ripple.material_override as StandardMaterial3D).disable_receive_shadows = true
	for i in 3:
		var glint := ArenaArt.block(_visual, Vector3(0.16 + i * 0.035, 0.012, 0.028), Color("d9f1e5"), Vector3(radius * 0.35 + i * 0.09, 0.221, -radius * 0.42 + i * 0.11), Vector3(0, -25, 0), 0.01)
		glint.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _build_tidepool() -> void:
	_disc(radius + 0.12, 0.04, Color("b79f72"), 0.045)
	_disc(radius, 0.028, color.lerp(Color("4ba6a0"), 0.55), 0.075)
	for i in 12:
		var angle := TAU * float(i) / 12.0
		var r := 0.22 + (i % 3) * 0.035
		var rock := Mats.mesh(_visual, Mats.sphere(r), Color("9eaa9b").lightened((i % 3) * 0.035),
			Vector3(cos(angle) * (radius + 0.035), 0.105, sin(angle) * (radius + 0.035)), Vector3(0, rad_to_deg(angle), 0))
		rock.scale = Vector3(1.15, 0.57, 0.82)
	var ripple := Mats.mesh(_visual, Mats.torus(radius * 0.53, radius * 0.53 + 0.018), Color("a7d9c4"), Vector3(-0.12, 0.097, -0.08))
	ripple.scale = Vector3(1, 0.15, 0.76)
	ripple.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# A tiny five-armed sea star supplies a warm focal detail at the shore.
	var star_pos := Vector3(radius * 0.65, 0.13, radius * 0.67)
	for i in 5:
		var angle := TAU * i / 5.0
		ArenaArt.block(_visual, Vector3(0.23, 0.035, 0.075), Color("db9678"), star_pos + Vector3(cos(angle), 0, sin(angle)) * 0.07,
			Vector3(0, -rad_to_deg(angle), 0), 0.016)


func _build_rug() -> void:
	_disc(radius, 0.045, color.darkened(0.18), 0.038)
	_disc(radius * 0.965, 0.012, color, 0.066)
	_disc(radius * 0.85, 0.009, Color("d1b582"), 0.076)
	_disc(radius * 0.80, 0.009, color.darkened(0.08), 0.086)
	_disc(radius * 0.73, 0.009, color.lightened(0.08), 0.096)
	for i in 32:
		var angle := TAU * i / 32.0
		var stitch := ArenaArt.block(_visual, Vector3(0.12, 0.008, 0.025), Color("e4c89a"),
			Vector3(cos(angle) * radius * 0.92, 0.08, sin(angle) * radius * 0.92), Vector3(0, -rad_to_deg(angle), 0), 0.008)
		stitch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for i in 8:
		var angle := TAU * i / 8.0
		var motif := ArenaArt.block(_visual, Vector3(0.2, 0.008, 0.2), color.lightened(0.30), Vector3(cos(angle) * radius * 0.61, 0.11, sin(angle) * radius * 0.61), Vector3(0, 45 - rad_to_deg(angle), 0), 0.018)
		motif.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _build_puddle() -> void:
	_disc(radius, 0.018, color.darkened(0.14), 0.04)
	_disc(radius * 0.91, 0.015, color, 0.055)
	for i in 4:
		var angle := TAU * i / 4.0 + 0.3
		var splash := Mats.mesh_plain(_visual, Mats.cylinder(radius * 0.23, 0.014), color,
			Vector3(cos(angle) * radius * 0.72, 0.063, sin(angle) * radius * 0.72))
		splash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if color.b > color.r + 0.1:
		# The kitchen spill includes the tipped water bowl that caused it.
		var bowl := Node3D.new()
		_visual.add_child(bowl)
		bowl.position = Vector3(radius * 0.64, 0.17, -radius * 0.45)
		bowl.rotation_degrees.z = -18
		Mats.mesh(bowl, Mats.cylinder(0.30, 0.23, 0.39), Color("dc9a6e"))
		Mats.mesh(bowl, Mats.cylinder(0.32, 0.015), Color("6b6d65"), Vector3(0, 0.124, 0))
		Mats.mesh(bowl, Mats.torus(0.32, 0.4), Color("f1c994"), Vector3(0, 0.13, 0), Vector3.ZERO, Vector3(1, 0.4, 1))
		var shine := Mats.mesh(_visual, Mats.torus(radius * 0.38, radius * 0.38 + 0.015), color.lightened(0.4), Vector3(-radius * 0.2, 0.08, radius * 0.15))
		shine.scale = Vector3(1, 0.15, 0.6)
		shine.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _on_body_entered(body: Node3D) -> void:
	if body is Dog:
		body.set_slow(self, slow_factor)


func _on_body_exited(body: Node3D) -> void:
	if body is Dog:
		body.clear_slow(self)


func _exit_tree() -> void:
	if Engine.is_editor_hint():
		return
	for body in get_overlapping_bodies():
		if is_instance_valid(body) and body is Dog:
			body.clear_slow(self)
