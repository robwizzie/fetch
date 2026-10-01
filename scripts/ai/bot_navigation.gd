class_name BotNavigation
extends Node3D
## Shared graph with inflated prop footprints and portal links. Rebuilds when gates change.

const CELL := 0.85
const CLEARANCE := 0.9
var _arena: Arena
var _graph := AStar3D.new()
var _cells: Dictionary = {}
var _gate_state := ""
var _poll := 0.0


func _ready() -> void:
	_arena = get_parent() as Arena
	_rebuild()


func _physics_process(delta: float) -> void:
	_poll -= delta
	if _poll > 0.0:
		return
	_poll = 0.5
	if _gates() != _gate_state:
		_rebuild()


func _gates() -> String:
	var state := ""
	for node in _arena.find_children("*", "StaticBody3D", true, false):
		if node is Gate:
			state += str((node as Gate)._shape.disabled)
	return state


func _rebuild() -> void:
	_graph.clear()
	_cells.clear()
	_gate_state = _gates()
	var half := _arena.size * 0.5
	var shapes := _arena.find_children("*", "CollisionShape3D", true, false)
	for z in range(int(ceil(_arena.size.y / CELL))):
		for x in range(int(ceil(_arena.size.x / CELL))):
			var point := Vector3(-half.x + (x + 0.5) * CELL, 0, -half.y + (z + 0.5) * CELL)
			if absf(point.x) + CLEARANCE > half.x or absf(point.z) + CLEARANCE > half.y:
				continue
			var world := _arena.to_global(point)
			var clear := true
			# Holes are not solid, but a route across one only ever ends at the rim.
			for pit in _arena.find_children("*", "Pit", true, false):
				if (pit as Pit).covers(world, CLEARANCE):
					clear = false
			for node in shapes:
				var shape := node as CollisionShape3D
				# Beds slide about, so the fixed graph leaves them to the bot's own steering.
				if shape.disabled or not shape.get_parent() is StaticBody3D or not Arena.is_solid_shape(shape) or not shape.shape is BoxShape3D:
					continue
				var extent := (shape.shape as BoxShape3D).size * 0.5
				var p := shape.to_local(world)
				var nearest := Vector2(clampf(p.x, -extent.x, extent.x), clampf(p.z, -extent.z, extent.z))
				if Vector2(p.x, p.z).distance_to(nearest) < CLEARANCE:
					clear = false
					break
			if clear:
				var id := _graph.get_available_point_id()
				_cells[Vector2i(x, z)] = id
				_graph.add_point(id, world)
	for cell: Vector2i in _cells:
		for offset: Vector2i in [Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(-1, 1)]:
			var next := cell + offset
			if not _cells.has(next):
				continue
			if offset.x != 0 and offset.y != 0 and (not _cells.has(cell + Vector2i(offset.x, 0)) or not _cells.has(cell + Vector2i(0, offset.y))):
				continue
			_graph.connect_points(_cells[cell], _cells[next])
	for node in _arena.find_children("*", "Area3D", true, false):
		if node is Portal and is_instance_valid(node.partner):
			var entrance := _graph.get_closest_point(node.global_position)
			var exit_id := _graph.get_closest_point(node.partner.global_position)
			if entrance >= 0 and exit_id >= 0 and entrance != exit_id and not _graph.are_points_connected(entrance, exit_id):
				_graph.connect_points(entrance, exit_id)


## The doorway whose graph link starts at (or next to) this route point.
func portal_near(point: Vector3) -> Portal:
	var best: Portal = null
	var best_distance := CELL * 3.0
	for node in _arena.find_children("*", "Area3D", true, false):
		if node is Portal:
			var d := (node as Portal).global_position.distance_to(Vector3(point.x, 0, point.z))
			if d < best_distance:
				best = node
				best_distance = d
	return best


func route(from: Vector3, to: Vector3) -> PackedVector3Array:
	if _graph.get_point_count() == 0:
		return PackedVector3Array()
	return _graph.get_point_path(_graph.get_closest_point(from), _graph.get_closest_point(to))
