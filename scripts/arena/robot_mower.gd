class_name RobotMower
extends Node3D
## Agility Park gimmick: a robot lawnmower crosses the park along one lane on a timer. It beeps
## and lights its lane first, then trundles across. A dog it clips is knocked aside - dizzy if
## its paws were empty, disarmed if not - but never knocked out. Loose toys get shunted along.

## The lane runs along X at this Z, from one side of the park to the other.
@export var lane_z := 0.0
## Half the park's width; the mower parks just outside it between runs.
@export var half_width := 16.5
@export var speed := 5.0
## Seconds parked between runs, and seconds of warning before each.
@export var rest := 9.0
@export var warning := 1.6

enum Phase { RESTING, WARNING, DRIVING }

const SIZE := Vector3(1.5, 0.7, 1.2)

var phase := Phase.RESTING
var heading := 1.0
var _timer := 0.0
var _body: Node3D
var _lamp: MeshInstance3D
var _lane: MeshInstance3D
var _lane_material: StandardMaterial3D
var _beep := 0.0
var _hit: Dictionary = {}


func _ready() -> void:
	add_to_group("gimmicks")
	_timer = rest * 0.5
	_build()
	_park()


func _build() -> void:
	# The warning strip: an amber band down the lane, dark until a run is coming.
	_lane = MeshInstance3D.new()
	_lane.mesh = Mats.box(Vector3(half_width * 2.0, 0.01, SIZE.z + 0.3))
	_lane_material = Mats.unlit(Color(1.0, 0.75, 0.2, 0.0))
	_lane.material_override = _lane_material
	_lane.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_lane.position = Vector3(0, 0.03, lane_z)
	add_child(_lane)
	_body = Node3D.new()
	add_child(_body)
	ArenaArt.block(_body, Vector3(SIZE.x, SIZE.y * 0.6, SIZE.z), Color("e2593f"), Vector3(0, SIZE.y * 0.45, 0), Vector3.ZERO, 0.12)
	ArenaArt.block(_body, Vector3(SIZE.x * 0.7, 0.22, SIZE.z * 0.8), Color("3c3f45"), Vector3(0, SIZE.y * 0.82, 0), Vector3.ZERO, 0.08)
	for x in [-0.5, 0.5]:
		for z in [-0.52, 0.52]:
			var wheel := Mats.mesh(_body, Mats.cylinder(0.2, 0.16), Color("2a2c30"), Vector3(x, 0.2, z), Vector3(90, 0, 0))
			wheel.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	_lamp = Mats.mesh(_body, Mats.sphere(0.12), Color.WHITE, Vector3(0, SIZE.y + 0.06, 0))
	_lamp.material_override = Mats.unlit(Color("ffb33c"))
	# A paw print on the lid: it is a dog park's mower.
	ArenaArt.paw(_body, Vector3(0, SIZE.y * 0.95, 0), 0.22, Color("fff1d6"))


## Parked and resting at the start of every round, never already mid-lane at the whistle.
func reset_for_round() -> void:
	phase = Phase.RESTING
	heading = 1.0
	_timer = rest * 0.5
	_hit.clear()
	_lane_material.albedo_color.a = 0.0
	_lamp.visible = false
	_park()


func _park() -> void:
	_body.position = Vector3(-heading * (half_width + 1.4), 0, lane_z)
	_body.rotation.y = 0.0 if heading > 0.0 else PI


func _physics_process(delta: float) -> void:
	_timer -= delta
	match phase:
		Phase.RESTING:
			_lane_material.albedo_color.a = 0.0
			_lamp.visible = false
			if _timer <= 0.0:
				phase = Phase.WARNING
				_timer = warning
		Phase.WARNING:
			var blink := fmod(_timer * 5.0, 1.0) < 0.5
			_lane_material.albedo_color.a = 0.28 if blink else 0.1
			_lamp.visible = blink
			_beep -= delta
			if _beep <= 0.0:
				_beep = 0.4
				Sfx.play_at("tick", _body.global_position, 1.6, -4.0)
			if _timer <= 0.0:
				phase = Phase.DRIVING
				_hit.clear()
		Phase.DRIVING:
			_lane_material.albedo_color.a = 0.14
			_lamp.visible = fmod(_timer * 4.0, 1.0) < 0.5
			_body.position.x += heading * speed * delta
			_body.position.y = sin(Time.get_ticks_msec() * 0.03) * 0.015
			_bump_things()
			if absf(_body.position.x) > half_width + 1.4:
				phase = Phase.RESTING
				_timer = rest
				heading = -heading
				_park()


func _bump_things() -> void:
	var centre := _body.global_position
	for node in get_tree().get_nodes_in_group("dogs"):
		var dog := node as Dog
		if dog == null or not dog.alive or not dog.can_process() or _hit.has(dog.get_instance_id()):
			continue
		if _touches(dog.global_position, dog.effective_radius()):
			_hit[dog.get_instance_id()] = true
			var side := signf(dog.global_position.z - centre.z)
			side = 1.0 if side == 0.0 else side
			dog.receive_whack(Vector3(heading * 0.6, 0, side).normalized(), null)
			Sfx.play_at("whack", dog.global_position, 0.8, -3.0)
	for node in get_tree().get_nodes_in_group("toys"):
		var toy := node as Toy
		if toy == null or toy.state != Toy.State.IDLE:
			continue
		if _touches(toy.global_position, toy.data.radius):
			toy.velocity = Vector3(heading * speed * 1.4, 0, signf(toy.global_position.z - centre.z) * 2.0)


func _touches(point: Vector3, radius: float) -> bool:
	var local := point - _body.global_position
	return absf(local.x) < SIZE.x * 0.5 + radius and absf(local.z) < SIZE.z * 0.5 + radius


## Where the mower is right now, for tests.
func mower_position() -> Vector3:
	return _body.global_position
