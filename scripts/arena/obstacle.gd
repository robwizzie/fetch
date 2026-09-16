@tool
class_name Obstacle
extends StaticBody3D
## A solid prop. Pick a [member kind] and a footprint [member size]; the visual is built from
## primitives and the collider is the footprint box. Replace visuals with real models later
## by adding a child mesh and setting kind = CUSTOM.

enum Kind { BOX, CRATE, DOGHOUSE, TABLE, BUSH, COUCH, ARMCHAIR, TV, PLANT, TIRE, CUSTOM,
	RAMP, TUNNEL, WEAVE, COUNTER, FRIDGE, UMBRELLA, ROCK }

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

const OCCLUDED_OPACITY := 0.22
const OCCLUSION_CHECK_INTERVAL := 0.075
var _opacity := 1.0
var _target_opacity := 1.0
var _occlusion_timer := 0.0
var _fade_materials: Array[StandardMaterial3D] = []
var _base_colors: Array[Color] = []
var _base_transparency: Array[int] = []
var _fade_meshes: Array[MeshInstance3D] = []
var _base_shadows: Array[int] = []
var _shadow_proxies: Array[MeshInstance3D] = []


func _ready() -> void:
	collision_layer = 1
	collision_mask = 0
	_rebuild()
	set_physics_process(not Engine.is_editor_hint())


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
		Kind.RAMP:
			# Agility A-frame: two boards leaning into each other, striped at the apex.
			var lean := Vector3(s.x * 0.5, s.y, s.z)
			Mats.mesh(v, Mats.prism(lean), color, Vector3(-s.x * 0.25, s.y / 2.0, 0), Vector3(0, 0, -90))
			Mats.mesh(v, Mats.prism(lean), accent, Vector3(s.x * 0.25, s.y / 2.0, 0), Vector3(0, 0, 90))
			Mats.mesh(v, Mats.box(Vector3(s.x * 0.16, 0.1, s.z + 0.05)), Color(0.98, 0.98, 0.95), Vector3(0, s.y, 0))
		Kind.TUNNEL:
			# A ribbed play tunnel lying on its side across the lane.
			var ribs := maxi(3, int(s.x / 0.42))
			for i in ribs:
				var t := float(i) / float(maxi(1, ribs - 1))
				var tint := color if i % 2 == 0 else accent
				var ring := Mats.mesh(v, Mats.torus(s.y * 0.30, s.y * 0.5), tint, Vector3(-s.x / 2.0 + t * s.x, s.y / 2.0, 0), Vector3(0, 0, 90))
				ring.scale = Vector3(1, 1, s.z / maxf(s.y, 0.01))
		Kind.WEAVE:
			var poles := maxi(3, int(s.x / 0.55))
			for i in poles:
				var t := float(i) / float(maxi(1, poles - 1))
				var x := -s.x / 2.0 + t * s.x
				Mats.mesh(v, Mats.cylinder(0.07, s.y), color, Vector3(x, s.y / 2.0, sin(t * PI * 2.0) * s.z * 0.18))
				Mats.mesh(v, Mats.sphere(0.1), accent, Vector3(x, s.y, sin(t * PI * 2.0) * s.z * 0.18))
		Kind.COUNTER:
			Mats.mesh(v, Mats.box(Vector3(s.x, s.y - 0.1, s.z)), color, Vector3(0, (s.y - 0.1) / 2.0, 0))
			Mats.mesh(v, Mats.box(Vector3(s.x + 0.12, 0.12, s.z + 0.12)), accent, Vector3(0, s.y - 0.05, 0))
			for i in maxi(1, int(s.x / 1.1)):
				var dx := -s.x / 2.0 + (i + 0.5) * s.x / float(maxi(1, int(s.x / 1.1)))
				Mats.mesh(v, Mats.box(Vector3(0.06, s.y * 0.5, 0.04)), accent.darkened(0.2), Vector3(dx, s.y * 0.42, s.z / 2.0 + 0.02))
		Kind.FRIDGE:
			Mats.mesh(v, Mats.box(s), color, Vector3(0, s.y / 2.0, 0))
			Mats.mesh(v, Mats.box(Vector3(s.x + 0.02, 0.05, s.z + 0.02)), accent, Vector3(0, s.y * 0.63, 0))
			Mats.mesh(v, Mats.box(Vector3(0.07, s.y * 0.22, 0.07)), accent, Vector3(s.x * 0.32, s.y * 0.78, s.z / 2.0 + 0.04))
			Mats.mesh(v, Mats.box(Vector3(0.07, s.y * 0.3, 0.07)), accent, Vector3(s.x * 0.32, s.y * 0.35, s.z / 2.0 + 0.04))
		Kind.UMBRELLA:
			var pole_h := s.y * 0.72
			Mats.mesh(v, Mats.cylinder(0.07, pole_h), accent, Vector3(0, pole_h / 2.0, 0))
			Mats.mesh(v, Mats.cone(minf(s.x, s.z) * 0.62, s.y - pole_h), color, Vector3(0, pole_h + (s.y - pole_h) / 2.0, 0))
			Mats.mesh(v, Mats.sphere(0.09), accent, Vector3(0, s.y + 0.04, 0))
		Kind.ROCK:
			var rr := minf(s.x, s.z) * 0.46
			Mats.mesh(v, Mats.sphere(rr), color, Vector3(0, rr * 0.72, 0), Vector3.ZERO, Vector3(1.0, 0.72, 0.9))
			Mats.mesh(v, Mats.sphere(rr * 0.66), color.lightened(0.08), Vector3(rr * 0.5, rr * 0.55, -rr * 0.35), Vector3.ZERO, Vector3(1.0, 0.7, 1.0))
			Mats.mesh(v, Mats.sphere(rr * 0.5), color.darkened(0.1), Vector3(-rr * 0.55, rr * 0.45, rr * 0.3))
		Kind.CUSTOM:
			pass
		_:
			Mats.mesh(v, Mats.box(s), color, Vector3(0, s.y / 2.0, 0))

	if not Engine.is_editor_hint():
		_prepare_occlusion_materials()


## Alpha is applied to instance-owned materials: GeometryInstance transparency
## is unavailable in the Compatibility renderer. The physical prop stays solid.
func _prepare_occlusion_materials() -> void:
	_fade_materials.clear()
	_base_colors.clear()
	_base_transparency.clear()
	_fade_meshes.clear()
	_base_shadows.clear()
	_shadow_proxies.clear()
	_opacity = 1.0
	_target_opacity = 1.0
	for child in _visual.find_children("*", "MeshInstance3D", true, false):
		var mesh := child as MeshInstance3D
		var original := mesh.material_override as StandardMaterial3D
		if original == null:
			continue
		var material := original.duplicate() as StandardMaterial3D
		material.resource_local_to_scene = true
		mesh.material_override = material
		_fade_materials.append(material)
		_base_colors.append(original.albedo_color)
		_base_transparency.append(original.transparency)
		_fade_meshes.append(mesh)
		_base_shadows.append(mesh.cast_shadow)
		var shadow: MeshInstance3D = null
		if mesh.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
			# Transparent materials stop casting reliable shadows in GL. Keep the
			# original opaque shadow so a faded prop's occupied footprint is clear.
			shadow = MeshInstance3D.new()
			shadow.name = "OcclusionShadow"
			shadow.mesh = mesh.mesh
			shadow.material_override = original
			shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
			shadow.visible = false
			mesh.add_child(shadow)
		_shadow_proxies.append(shadow)


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint() or _fade_materials.is_empty():
		return
	_occlusion_timer -= delta
	if _occlusion_timer <= 0.0:
		_occlusion_timer = OCCLUSION_CHECK_INTERVAL
		_target_opacity = OCCLUDED_OPACITY if _blocks_live_dog() else 1.0
	var next_opacity := lerpf(_opacity, _target_opacity, 1.0 - exp(-14.0 * delta))
	if absf(next_opacity - _target_opacity) < 0.003:
		next_opacity = _target_opacity
	if is_equal_approx(_opacity, next_opacity):
		return
	_opacity = next_opacity
	var fading := _opacity < 0.999
	for i in _fade_materials.size():
		var color := _base_colors[i]
		color.a *= _opacity
		_fade_materials[i].albedo_color = color
		_fade_materials[i].transparency = BaseMaterial3D.TRANSPARENCY_ALPHA if fading else _base_transparency[i]
		_fade_meshes[i].cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if fading else _base_shadows[i]
		if is_instance_valid(_shadow_proxies[i]):
			_shadow_proxies[i].visible = fading


func _blocks_live_dog() -> bool:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return false
	for node in get_tree().get_nodes_in_group("dogs"):
		if not node is Dog or not node.alive or node.is_queued_for_deletion():
			continue
		var target: Vector3 = node.global_position + Vector3(0, 0.65, 0)
		if camera.is_position_behind(target):
			continue
		# Orthographic sight rays must start at the dog's screen coordinate,
		# rather than converging on the camera position as perspective rays do.
		var screen_point := camera.unproject_position(target)
		var origin := camera.project_ray_origin(screen_point)
		var query := PhysicsRayQueryParameters3D.create(origin, target, 1)
		var hit := get_world_3d().direct_space_state.intersect_ray(query)
		if hit.get("collider") == self:
			return true
	return false
