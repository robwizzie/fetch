class_name CombatRules
extends RefCounted
## Shared cover and allegiance rules for direct shots, swipes and area effects.


static func clear_between(node: Node3D, from: Vector3, to: Vector3) -> bool:
	var query := PhysicsRayQueryParameters3D.create(from, to, 1)
	return node.get_world_3d().direct_space_state.intersect_ray(query).is_empty()


static func can_hurt(attacker: Dog, victim: Dog) -> bool:
	if not is_instance_valid(attacker) or attacker.slot == null or victim.slot == null:
		return true
	if attacker == victim:
		return Game.self_fire
	return Game.friendly_fire or not victim.slot.allied_with(attacker.slot)
