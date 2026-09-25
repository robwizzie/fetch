class_name Sprinkler
extends Node3D
## Backyard gimmick: a lawn sprinkler in the paddling pool sweeps a jet of water round the yard.
## A dog caught in the jet is shoved along it - never hurt, never disarmed - so the sweep is
## something to time a run around, or to use to knock a rival off their line.

## Seconds for one full turn.
@export var period := 7.0
## How far the jet reaches over open ground. Props cut it short.
@export var reach := 5.6
## Shove speed, in metres per second, handed to a dog in the jet.
@export var push := 7.5

const HEAD_HEIGHT := 0.55
## A dog is only shoved once per pass of the jet.
const RESHOVE := 0.6

var angle := 0.0
var _head: Node3D
var _spray: CPUParticles3D
var _length := 0.0
var _cooldown: Dictionary = {}


func _ready() -> void:
	add_to_group("gimmicks")
	var post := Mats.mesh(self, Mats.cylinder(0.07, HEAD_HEIGHT), Color("9aa3ad"), Vector3(0, HEAD_HEIGHT * 0.5, 0))
	post.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	Mats.mesh(self, Mats.cylinder(0.26, 0.08), Color("5c8a4a"), Vector3(0, 0.04, 0))
	_head = Node3D.new()
	_head.position = Vector3(0, HEAD_HEIGHT, 0)
	add_child(_head)
	Mats.mesh(_head, Mats.sphere(0.14), Color("f2c14e"))
	Mats.mesh(_head, Mats.cylinder(0.045, 0.34), Color("e0e4ea"), Vector3(0, 0.02, -0.18), Vector3(80, 0, 0))
	_spray = CPUParticles3D.new()
	_spray.amount = 70
	_spray.lifetime = 0.55
	_spray.local_coords = false
	_spray.direction = Vector3(0, 0.32, -1)
	_spray.spread = 4.0
	_spray.gravity = Vector3(0, -9.0, 0)
	_spray.scale_amount_min = 0.6
	_spray.scale_amount_max = 1.2
	_spray.mesh = Mats.sphere(0.06)
	var water := Mats.unlit(Color(0.72, 0.9, 1.0, 0.8))
	_spray.mesh.material = water
	_spray.position = Vector3(0, 0.05, -0.34)
	_head.add_child(_spray)


func _physics_process(delta: float) -> void:
	angle = wrapf(angle + TAU * delta / period, 0.0, TAU)
	_head.rotation.y = angle
	var dir := jet_direction()
	var from := global_position + Vector3.UP * HEAD_HEIGHT
	# Props and walls stop the water, so cover works against the sprinkler too.
	var query := PhysicsRayQueryParameters3D.create(from, from + dir * reach, 1)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	_length = from.distance_to(hit.position) if not hit.is_empty() else reach
	# Particle speed matched to the jet so the spray lands where the water actually reaches.
	var speed := clampf(_length * 2.2, 3.0, 13.0)
	_spray.initial_velocity_min = speed * 0.9
	_spray.initial_velocity_max = speed
	for key in _cooldown.keys():
		_cooldown[key] -= delta
		if _cooldown[key] <= 0.0:
			_cooldown.erase(key)
	for node in get_tree().get_nodes_in_group("dogs"):
		var dog := node as Dog
		if dog == null or not dog.alive or not dog.can_process() or _cooldown.has(dog.get_instance_id()):
			continue
		if in_jet(dog.global_position, dog.effective_radius()):
			_cooldown[dog.get_instance_id()] = RESHOVE
			dog.shove(dir * push)
			Juice.burst(get_parent(), dog.global_position + Vector3.UP * 0.6, Color(0.75, 0.92, 1.0), 10, 3.0)
			Sfx.play_at("splat", dog.global_position, 1.3, -6.0)


## Straight out of the nozzle, flat on the floor.
func jet_direction() -> Vector3:
	return Vector3(-sin(angle), 0.0, -cos(angle))


## True when a body of this radius at this point is in the water's path.
func in_jet(point: Vector3, radius: float) -> bool:
	var offset := point - global_position
	offset.y = 0.0
	var along := offset.dot(jet_direction())
	if along < 0.4 or along > _length + radius:
		return false
	return (offset - jet_direction() * along).length() < radius + 0.3
