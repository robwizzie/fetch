extends Node
## Every arena in the picker, held to the same layout rules.
##
## The first four are about fairness: nobody starts wedged in a prop, nobody starts nearer a
## toy than anyone else, and every start and every pickup can actually be walked to. The last
## one is about the arena being worth playing at all — a flat box with props dotted around it
## passes all the fairness checks and is still a bad map, so a layout has to break at least one
## start-to-start sightline. That is the difference between cover and decoration.
##   godot --headless --path . res://tests/arena_layout_test.tscn

## Dogs are this wide at most; routes have to fit the biggest of them.
const WALK_RADIUS := 0.7
## How much closer to a toy one start may be than another, in metres.
const OPENING_FAIRNESS := 1.2

var _failed := false


func _ready() -> void:
	Sfx.enabled = false
	Music.enabled = false
	_check(Game.arenas.size() >= 4, "the picker has a set worth shuffling")
	for data in Game.arenas:
		var arena: Arena = data.scene.instantiate()
		add_child(arena)
		await get_tree().physics_frame
		# Warp Yard is deliberately cut in half by gates and stitched back together by portals.
		# Auditing it with the gates shut says the arena is broken when it is working exactly
		# as designed, so the furniture is put in its open state first.
		var moved := false
		for node in arena.find_children("*", "StaticBody3D", true, false):
			if node is Gate:
				(node as Gate).set_open(true)
				moved = true
		if moved:
			await get_tree().create_timer(Gate.TRAVEL + 0.1).timeout
		_audit(arena, data.display_name)
		arena.queue_free()
		await get_tree().process_frame
	if not _failed:
		print("[arena-layout] PASSED: %d arenas with safe balanced starts, connected routes and real cover" % Game.arenas.size())
	get_tree().quit(1 if _failed else 0)


func _audit(arena: Arena, name_: String) -> void:
	var starts := arena.spawn_points.get_child_count()
	var pickups := arena.toy_spawns.get_child_count()
	_check(starts >= 4, "%s seats four" % name_)
	_check(pickups >= 4, "%s lays out at least four opening toys" % name_)
	if starts < 4 or pickups < 4:
		return
	# Crates are dropped near the middle and nudged clear, so the middle does not have to be
	# empty - but whatever the nudge finds has to be near the middle and in open play, or the
	# treat that decides a round lands in a corner nobody contests.
	var crate := arena.clear_pickup_position(Vector3.ZERO)
	_check(crate.length() < 3.5, "%s has open ground near the middle for a crate (%.1f m out)" % [name_, crate.length()])

	# Filled out from P1 rather than from the origin: a prop dead in the centre is a legitimate
	# piece of level design, not a disconnected arena.
	var reachable := _reachable_floor(arena, arena.get_spawn_position(0), _portal_links(arena))
	_check(reachable.has(_cell(crate)), "%s crate ground is in open play" % name_)
	var nearest_toy: Array[float] = []
	for i in starts:
		var point := arena.get_spawn_position(i)
		_check(arena.is_clear_position(point, 1.0), "%s P%d has a safe opening" % [name_, i + 1])
		_check(reachable.has(_cell(point)), "%s P%d is joined to the rest of the arena" % [name_, i + 1])
		var closest := INF
		for j in pickups:
			closest = minf(closest, point.distance_to(arena.get_toy_spawn_position(j)))
		nearest_toy.append(closest)
	nearest_toy.sort()
	_check(nearest_toy.back() - nearest_toy.front() < OPENING_FAIRNESS,
		"%s gives every start the same run to a toy (spread %.2f m)" % [name_, nearest_toy.back() - nearest_toy.front()])

	for i in pickups:
		var point := arena.get_toy_spawn_position(i)
		_check(arena.is_clear_position(point, 0.85), "%s T%d is clear of cover" % [name_, i + 1])
		_check(reachable.has(_cell(point)), "%s T%d is reachable" % [name_, i + 1])

	# Cover, not decoration: somewhere in here two starts must not be able to see each other.
	var blocked := 0
	for i in starts:
		for j in range(i + 1, starts):
			if not _in_sight(arena, arena.get_spawn_position(i), arena.get_spawn_position(j)):
				blocked += 1
	_check(blocked > 0, "%s puts something between at least one pair of starts" % name_)


## True when nothing solid stands between two points at chest height.
func _in_sight(arena: Arena, from: Vector3, to: Vector3) -> bool:
	var query := PhysicsRayQueryParameters3D.create(from + Vector3(0, 0.7, 0), to + Vector3(0, 0.7, 0), 1)
	return arena.get_world_3d().direct_space_state.intersect_ray(query).is_empty()


func _cell(point: Vector3) -> Vector2i:
	return Vector2i(roundi(point.x * 2.0), roundi(point.z * 2.0))


## Every half-metre cell a dog can stand in, flood-filled out from [param origin]. Anything the
## fill does not reach is walled off from the rest of the arena.
## Where a portal drops you, keyed by the cell you step into. A pair is a route like any other.
func _portal_links(arena: Arena) -> Dictionary:
	var links: Dictionary = {}
	for node in arena.find_children("*", "Area3D", true, false):
		var portal := node as Portal
		if portal != null and portal.partner != null:
			links[_cell(portal.global_position)] = _cell(portal.partner.global_position)
	return links


func _reachable_floor(arena: Arena, origin: Vector3, links: Dictionary) -> Dictionary:
	var clear: Dictionary = {}
	for x in range(-int(arena.size.x), int(arena.size.x) + 1):
		for z in range(-int(arena.size.y), int(arena.size.y) + 1):
			var point := Vector3(x * 0.5, 0, z * 0.5)
			if arena.is_clear_position(point, WALK_RADIUS):
				clear[Vector2i(x, z)] = true
	var start := _cell(origin)
	var seen: Dictionary = {start: true}
	var pending: Array[Vector2i] = [start]
	var next := 0
	while next < pending.size():
		var current := pending[next]
		next += 1
		var steps: Array[Vector2i] = [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]
		for step in steps:
			var candidate: Vector2i = current + step
			if clear.has(candidate) and not seen.has(candidate):
				seen[candidate] = true
				pending.append(candidate)
		if links.has(current):
			var exit_cell: Vector2i = links[current]
			if not seen.has(exit_cell):
				seen[exit_cell] = true
				pending.append(exit_cell)
	return seen


func _check(ok: bool, message: String) -> void:
	if not ok:
		_failed = true
		push_error("[arena-layout] FAILED: " + message)
		printerr("[arena-layout] FAILED: " + message)
