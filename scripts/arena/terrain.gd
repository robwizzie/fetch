class_name Terrain
extends RefCounted
## Walkable elevation. Gameplay still runs on the XZ plane — nothing jumps and nothing falls —
## but a prop in the "ramps" group reports a deck height over its own footprint, and dogs and
## toys ride that surface. Props register themselves; there is no height map to keep in sync.

const GROUP := &"ramps"


## Deck height in metres at a point, or 0 on the flat. Safe to call on a node outside the tree.
static func ground_height(node: Node3D, at: Vector3) -> float:
	if not node.is_inside_tree():
		return 0.0
	var top := 0.0
	for candidate in node.get_tree().get_nodes_in_group(GROUP):
		var ramp := candidate as Obstacle
		if ramp == null:
			continue
		top = maxf(top, ramp.surface_height(at))
	return top
