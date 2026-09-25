class_name MudPatch
extends Node3D
## Short-lived terrain with explicit slow ownership, cover checks and a bounded scene budget.

const LIFETIME := 3.2
const LIMIT := 32
var radius := 0.7
var age := 0.0
var _affected: Array[Dog] = []
var _art: Node3D


static func spawn(parent: Node, at: Vector3, size: float = 0.7) -> MudPatch:
	var patches := parent.get_tree().get_nodes_in_group("mud_patches")
	if patches.size() >= LIMIT:
		(patches[0] as MudPatch).clear_effect()
		patches[0].remove_from_group("mud_patches")
		patches[0].queue_free()
	var patch := MudPatch.new()
	patch.radius = size
	parent.add_child(patch)
	patch.global_position = Vector3(at.x, Terrain.ground_height(patch, at) + 0.055, at.z)
	return patch


func _ready() -> void:
	add_to_group("mud_patches")
	add_to_group("combat_effects")
	_art = Node3D.new()
	add_child(_art)
	for i in 4:
		var angle := i * TAU / 4.0
		var puddle := Mats.mesh_plain(_art, Mats.cylinder(radius * 0.67, 0.014), Color("74553d"),
			Vector3(cos(angle) * radius * 0.28, i * 0.002, sin(angle) * radius * 0.24))
		puddle.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var sheen := Mats.mesh_plain(_art, Mats.cylinder(radius * 0.36, 0.008), Color("a7845a"), Vector3(-radius * 0.16, 0.016, 0))
	sheen.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_art.scale = Vector3(0.1, 1, 0.1)


func _physics_process(delta: float) -> void:
	age += delta
	if age >= LIFETIME:
		clear_effect()
		queue_free()
		return
	var spread := minf(1.0, age / 0.12) * minf(1.0, (LIFETIME - age) / 0.55)
	_art.scale = Vector3(spread, 1.0, spread)
	var inside: Array[Dog] = []
	for node in get_tree().get_nodes_in_group("dogs"):
		var dog := node as Dog
		if not dog.alive or dog.round_locked:
			continue
		var gap := Vector2(dog.global_position.x - global_position.x, dog.global_position.z - global_position.z)
		if gap.length() > radius * spread + dog.effective_radius() * 0.5:
			continue
		if not CombatRules.clear_between(self, global_position + Vector3.UP * 0.5, dog.global_position + Vector3.UP * 0.5):
			continue
		inside.append(dog)
		dog.set_slow(self, 0.65)
	for dog in _affected:
		if is_instance_valid(dog) and not inside.has(dog):
			dog.clear_slow(self)
	_affected = inside


func clear_effect() -> void:
	for dog in _affected:
		if is_instance_valid(dog):
			dog.clear_slow(self)
	_affected.clear()


func _exit_tree() -> void:
	clear_effect()
