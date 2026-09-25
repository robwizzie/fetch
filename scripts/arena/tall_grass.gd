class_name TallGrass
extends Node3D
## Pup Beach gimmick: a clump of tall dune grass. A dog standing in it disappears - body, ring,
## name and the toy in its mouth - until it throws or dashes out. Moving through it is not
## silent: the blades thrash round the dog, so a sharp eye can still track a rustle.

@export var radius := 1.4
@export var tint := Color("b9b46a")

const BLADES := 46
## Faster than this and the grass gives the dog away.
const RUSTLE_SPEED := 1.2

var _blades: Array[Node3D] = []
var _phase: Array[float] = []
var _shake: Array[float] = []
var _inside: Dictionary = {}
var _rustle_clock := 0.0


func _ready() -> void:
	add_to_group("gimmicks")
	var rng := RandomNumberGenerator.new()
	rng.seed = int(absf(global_position.x) * 131.0 + absf(global_position.z) * 17.0) + 5
	var base := Mats.contact_shadow(self, radius * 0.95)
	(base.material_override as StandardMaterial3D).albedo_color = Color(0.35, 0.3, 0.12, 0.3)
	for i in BLADES:
		var at := Vector2.from_angle(rng.randf() * TAU) * sqrt(rng.randf()) * radius
		var height := rng.randf_range(1.15, 1.65)
		var pivot := Node3D.new()
		pivot.position = Vector3(at.x, 0, at.y)
		pivot.rotation.y = rng.randf() * TAU
		add_child(pivot)
		var shade := tint.lerp(Color("7f9a4f"), rng.randf() * 0.6).lightened(rng.randf_range(-0.08, 0.1))
		var blade := Mats.mesh(pivot, Mats.box(Vector3(0.09, height, 0.03)), shade, Vector3(0, height * 0.5, 0))
		blade.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		_blades.append(pivot)
		_phase.append(rng.randf() * TAU)
		_shake.append(0.0)


func _physics_process(delta: float) -> void:
	var t := Time.get_ticks_msec() * 0.001
	var rustlers: Array[Vector3] = []
	for node in get_tree().get_nodes_in_group("dogs"):
		var dog := node as Dog
		if dog == null:
			continue
		var gap := Vector2(dog.global_position.x - global_position.x, dog.global_position.z - global_position.z).length()
		var inside := dog.alive and gap < radius
		if inside != _inside.has(dog.get_instance_id()):
			dog.set_cover(self, inside)
			if inside:
				_inside[dog.get_instance_id()] = true
			else:
				_inside.erase(dog.get_instance_id())
		if gap < radius + dog.effective_radius() and dog.velocity.length() > RUSTLE_SPEED:
			rustlers.append(dog.global_position)
	for i in _blades.size():
		var pivot := _blades[i]
		for spot in rustlers:
			if pivot.global_position.distance_to(Vector3(spot.x, pivot.global_position.y, spot.z)) < 1.1:
				_shake[i] = 1.0
		_shake[i] = maxf(0.0, _shake[i] - delta * 2.5)
		var sway := sin(t * 1.3 + _phase[i]) * 0.07 + sin(t * 17.0 + _phase[i]) * 0.35 * _shake[i]
		pivot.rotation.x = sway
		pivot.rotation.z = sway * 0.6
	_rustle_clock -= delta
	if not rustlers.is_empty() and _rustle_clock <= 0.0:
		_rustle_clock = 0.28
		var spot := rustlers[0]
		Sfx.play_at("rustle", spot, randf_range(1.1, 1.35), -12.0)
		Juice.burst(get_parent(), spot + Vector3.UP * 1.2, tint.lightened(0.2), 4, 1.6)


func _exit_tree() -> void:
	for node in get_tree().get_nodes_in_group("dogs"):
		var dog := node as Dog
		if dog != null:
			dog.set_cover(self, false)
