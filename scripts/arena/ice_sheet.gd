@tool
class_name IceSheet
extends Node3D
## Frozen Pond gimmick: a sheet of ice over the middle of the arena. A dog standing on it has
## next to no grip - it gets going slowly, stops slowly, turns slowly and keeps sliding - and a
## whack sends it a long way, which is how dogs end up in the open water cut into the ice.
## Loose toys skid further on it too. Step back onto the snow and the grip comes straight back.
##
## Grip is owned the way slows are (Dog.set_traction / clear_traction), so the ice and a slow
## zone, or two sheets, never cancel each other.

## Footprint of the sheet in metres (x by z), centred on this node. The corners are rounded.
@export var size := Vector2(15.0, 9.4):
	set(v):
		size = v
		_rebuild()
@export var corner := 2.2:
	set(v):
		corner = v
		_rebuild()
## How much of its usual grip a dog keeps on the ice.
@export_range(0.05, 1.0) var traction := 0.2
@export var ice := Color("80bcd6")

## Share of a loose toy's floor friction the ice gives back, so toys skid further.
const TOY_GLIDE := 0.65

var _visual: Node3D
var _on_ice: Dictionary = {}


func _ready() -> void:
	if not Engine.is_editor_hint():
		add_to_group("gimmicks")
	_rebuild()


## True when [param point] stands on the ice (rounded corners included).
func covers(point: Vector3) -> bool:
	var local := to_local(Vector3(point.x, global_position.y, point.z))
	var half := size * 0.5
	var r := minf(corner, minf(half.x, half.y))
	var q := Vector2(absf(local.x) - (half.x - r), absf(local.z) - (half.y - r))
	if q.x <= 0.0 or q.y <= 0.0:
		return absf(local.x) <= half.x and absf(local.z) <= half.y
	return q.length() <= r


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	# Dogs are rebuilt every round; forget the ones that have gone.
	for id: int in _on_ice.keys():
		if not is_instance_id_valid(id):
			_on_ice.erase(id)
	for node in get_tree().get_nodes_in_group("dogs"):
		var dog := node as Dog
		if dog == null:
			continue
		var id := dog.get_instance_id()
		var inside := dog.alive and covers(dog.global_position)
		if inside and not _on_ice.has(id):
			_on_ice[id] = true
			dog.set_traction(self, traction)
		elif not inside and _on_ice.has(id):
			_on_ice.erase(id)
			dog.clear_traction(self)
	for node in get_tree().get_nodes_in_group("toys"):
		var toy := node as Toy
		if toy == null or toy.state != Toy.State.IDLE or toy.velocity.length_squared() < 0.04:
			continue
		if covers(toy.global_position):
			# Hand back most of what the floor took this frame: the toy skates on.
			toy.velocity += toy.velocity.normalized() * toy.data.friction * TOY_GLIDE * delta


func _exit_tree() -> void:
	if Engine.is_editor_hint():
		return
	for id: int in _on_ice:
		var dog := instance_from_id(id) as Dog
		if dog != null:
			dog.clear_traction(self)
	_on_ice.clear()


func _rebuild() -> void:
	if not is_inside_tree():
		return
	if is_instance_valid(_visual):
		_visual.queue_free()
	_visual = Node3D.new()
	add_child(_visual)
	var half := size * 0.5
	var r := minf(corner, minf(half.x, half.y))
	# A frosted lip of packed snow, then the clear ice inset inside it.
	_rounded(Vector2(size.x + 0.5, size.y + 0.5), r + 0.25, Color("cfdbe8"), 0.022, 0.03)
	_rounded(size, r, ice, 0.034, 0.02)
	_rounded(size - Vector2(0.7, 0.7), r - 0.35, ice.lightened(0.16), 0.038, 0.006)
	var rng := RandomNumberGenerator.new()
	rng.seed = 41
	# Darker, deeper patches where the pond is clear: the ice reads as something you see into.
	for i in 9:
		var at := Vector3(rng.randf_range(-half.x + 1.5, half.x - 1.5), 0.043, rng.randf_range(-half.y + 1.2, half.y - 1.2))
		if not covers(to_global(at)):
			continue
		var patch := _flat(Mats.cylinder(rng.randf_range(0.7, 1.4), 0.004), ice.darkened(0.12).lerp(Color("4f9ec4"), 0.35), at)
		patch.scale = Vector3(rng.randf_range(1.2, 1.9), 1, rng.randf_range(0.6, 1.0))
		patch.rotation.y = rng.randf_range(0.0, PI)
	# Sheen: long pale diagonal glints that catch the light from the camera's side.
	for i in 6:
		var x := lerpf(-half.x + 2.6, half.x - 2.6, float(i) / 5.0)
		var z := (0.9 if i % 2 == 0 else -1.4)
		for streak in 2:
			var glint := _flat(Mats.box(Vector3(3.2 - streak * 1.1, 0.004, 0.13 - streak * 0.05)), Color(1, 1, 1, 0.55),
				Vector3(x + streak * 0.35, 0.047, z + streak * 0.32))
			glint.material_override = Mats.unlit(Color(1, 1, 1, 0.42 - streak * 0.12))
			glint.rotation_degrees.y = 32.0
	# Skate marks: thin white curves scratched across the sheet.
	for i in 7:
		var centre := Vector3(rng.randf_range(-half.x + 2.0, half.x - 2.0), 0.046, rng.randf_range(-half.y + 1.5, half.y - 1.5))
		var radius := rng.randf_range(1.6, 3.2)
		var start := rng.randf_range(0.0, TAU)
		for step in 7:
			var angle := start + float(step) * 0.16
			var at := centre + Vector3(cos(angle), 0, sin(angle)) * radius
			if not covers(to_global(at)):
				continue
			var mark := _flat(Mats.box(Vector3(0.5, 0.003, 0.025)), Color("f4fbff"), at)
			mark.rotation.y = -angle + PI * 0.5
	# Snow drifting in over the edge breaks up the outline so it reads as a pond, not a mat.
	for i in 22:
		var angle := TAU * float(i) / 22.0 + rng.randf_range(-0.08, 0.08)
		var edge := Vector3(cos(angle) * (half.x + 0.05), 0.03, sin(angle) * (half.y + 0.05))
		var drift := _flat(Mats.sphere(rng.randf_range(0.18, 0.34)), Color("d7e1ec"), edge)
		drift.scale = Vector3(1.8, 0.1, 0.7)
		drift.rotation.y = -angle


## A flat rounded rectangle: a cross of two boxes and a disc in each corner.
func _rounded(dimensions: Vector2, r: float, tint: Color, y: float, thickness: float) -> void:
	r = clampf(r, 0.05, minf(dimensions.x, dimensions.y) * 0.5)
	_flat(Mats.box(Vector3(dimensions.x - r * 2.0, thickness, dimensions.y)), tint, Vector3(0, y, 0))
	_flat(Mats.box(Vector3(dimensions.x, thickness, dimensions.y - r * 2.0)), tint, Vector3(0, y, 0))
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			_flat(Mats.cylinder(r, thickness), tint, Vector3(sx * (dimensions.x * 0.5 - r), y, sz * (dimensions.y * 0.5 - r)))


func _flat(m: Mesh, tint: Color, at: Vector3) -> MeshInstance3D:
	var mi := Mats.mesh_plain(_visual, m, tint, at)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material := mi.material_override as StandardMaterial3D
	if material != null:
		# Ice is the one glossy floor in the game: a little specular so the key light glints.
		material.roughness = 0.35
		material.metallic_specular = 0.5
	return mi
