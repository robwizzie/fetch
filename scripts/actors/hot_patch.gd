class_name HotPatch
extends Node3D
## Hot Dog: a short-lived patch of fire left along a throw. Any rival who runs into it is
## bonked, credited to whoever threw; the thrower and their pack-mates are safe, and so is a
## dog mid-dash (it hops the flames) or underground. Bounded, so a long volley cannot flood
## the scene.

const LIFETIME := 1.7
## A beat after landing before it can catch anyone, so a throw cannot bonk the dog it
## was thrown past on the same frame it lands.
const ARM_TIME := 0.12
const LIMIT := 90
var radius := 0.55
var age := 0.0
var thrower: Dog
var _art: Node3D
var _flames: CPUParticles3D


static func spawn(parent: Node, at: Vector3, by: Dog, size: float = 0.55) -> HotPatch:
	var patches := parent.get_tree().get_nodes_in_group("hot_patches")
	if patches.size() >= LIMIT:
		patches[0].remove_from_group("hot_patches")
		patches[0].queue_free()
	var patch := HotPatch.new()
	patch.radius = size
	patch.thrower = by
	parent.add_child(patch)
	patch.global_position = Vector3(at.x, Terrain.ground_height(patch, at) + 0.05, at.z)
	return patch


func _ready() -> void:
	add_to_group("hot_patches")
	add_to_group("combat_effects")
	_art = Node3D.new()
	add_child(_art)
	# Embers and a hot core: soft-edged discs, unlit so they glow on any floor. Patches overlap
	# along a throw, so the trail reads as one streak rather than a row of rings.
	for layer in [[1.0, Color(1.0, 0.36, 0.1, 0.55)], [0.7, Color(1.0, 0.52, 0.16, 0.85)], [0.38, Color(1.0, 0.88, 0.45, 0.95)]]:
		var disc := MeshInstance3D.new()
		disc.mesh = Mats.cylinder(radius * float(layer[0]), 0.012)
		disc.material_override = Mats.unlit(layer[1])
		disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		disc.position.y = 0.004 * (1.0 - float(layer[0]))
		_art.add_child(disc)
	_art.scale = Vector3(0.1, 1, 0.1)
	_flames = CPUParticles3D.new()
	_flames.amount = 10
	_flames.lifetime = 0.45
	_flames.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	_flames.emission_sphere_radius = radius * 0.6
	_flames.direction = Vector3.UP
	_flames.spread = 12.0
	_flames.gravity = Vector3(0, 2.5, 0)
	_flames.initial_velocity_min = 0.6
	_flames.initial_velocity_max = 1.4
	_flames.scale_amount_min = 0.5
	_flames.scale_amount_max = 1.0
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1.0, 0.85, 0.35, 1.0))
	ramp.set_color(1, Color(1.0, 0.25, 0.05, 0.0))
	_flames.color_ramp = ramp
	_flames.mesh = Mats.sphere(0.09)
	var flame_material := Mats.unlit(Color.WHITE)
	flame_material.vertex_color_use_as_albedo = true
	flame_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_flames.mesh.material = flame_material
	add_child(_flames)


func _physics_process(delta: float) -> void:
	age += delta
	if age >= LIFETIME:
		queue_free()
		return
	var spread := minf(1.0, age / 0.1) * minf(1.0, (LIFETIME - age) / 0.4)
	var flicker := 1.0 + sin(age * 31.0 + global_position.x * 7.0) * 0.06
	_art.scale = Vector3(spread * flicker, 1.0, spread * flicker)
	_flames.emitting = age < LIFETIME - 0.35
	if age < ARM_TIME:
		return
	for node in get_tree().get_nodes_in_group("dogs"):
		var dog := node as Dog
		if not dog.alive or dog.round_locked or dog == thrower:
			continue
		if is_instance_valid(thrower) and dog.slot.allied_with(thrower.slot):
			continue
		var gap := Vector2(dog.global_position.x - global_position.x, dog.global_position.z - global_position.z)
		if gap.length() > radius * spread + dog.effective_radius() * 0.5:
			continue
		dog.burn(self, thrower if is_instance_valid(thrower) else null)
