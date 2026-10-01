class_name SkyDrop
extends Node3D
## Sudden death: a toy falling out of the sky. A ring on the ground marks where it will land and
## tightens as it comes down; anyone still standing in it when it lands is out. Dashing through
## (you are untouchable mid-dash) or digging under it saves you. The toy stays where it fell, so
## sudden death also rains ammunition.

const GROUP := &"sky_drops"
const WARNING := 0.9
const RADIUS := 1.0
const FALL_FROM := 11.0

var toy_data: ToyData
var game_match: Node
var _elapsed := 0.0
var _ring: MeshInstance3D
var _fill: MeshInstance3D
var _ring_material: StandardMaterial3D
var _falling: ToyModel
var _landed := false


func setup(p_match: Node, p_toy: ToyData) -> void:
	game_match = p_match
	toy_data = p_toy


func _ready() -> void:
	add_to_group(GROUP)
	_ring = Mats.mesh(self, Mats.torus(RADIUS - 0.1, RADIUS), Color.WHITE, Vector3(0, 0.05, 0))
	_ring_material = Mats.unlit(Color(1.0, 0.36, 0.25, 0.9))
	_ring.material_override = _ring_material
	_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_fill = Mats.mesh(self, Mats.cylinder(RADIUS, 0.01), Color.WHITE, Vector3(0, 0.04, 0))
	_fill.material_override = Mats.unlit(Color(1.0, 0.36, 0.25, 0.25))
	_fill.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_fill.scale = Vector3(0.05, 1, 0.05)
	_falling = ToyModel.new()
	_falling.setup(toy_data)
	_falling.position = Vector3(0, FALL_FROM, 0)
	add_child(_falling)
	Sfx.play_at("tick", global_position, 1.6, -6.0)


## True while [param point] is inside the ring of a drop that has not landed yet.
func threatens(point: Vector3, margin: float = 0.0) -> bool:
	return not _landed and Vector2(point.x - global_position.x, point.z - global_position.z).length() < RADIUS + margin


func _process(delta: float) -> void:
	if _landed:
		return
	_elapsed += delta
	var t := clampf(_elapsed / WARNING, 0.0, 1.0)
	# The ring fills in as the toy comes down, so the last moment to get out is easy to read.
	_fill.scale = Vector3(t, 1, t)
	_ring_material.albedo_color.a = 0.55 + 0.4 * sin(_elapsed * 30.0) * (1.0 - t) + 0.4 * t
	_falling.position.y = lerpf(FALL_FROM, 0.3, t * t)
	_falling.rotation.x += delta * 9.0
	if t >= 1.0:
		_land()


func _land() -> void:
	_landed = true
	Sfx.play_at("bonk", global_position, 0.8, -2.0)
	Juice.shake(0.22)
	Juice.burst(get_parent(), global_position + Vector3.UP * 0.3, Color(1, 0.85, 0.6), 20, 5.0)
	for node in get_tree().get_nodes_in_group("dogs"):
		var dog := node as Dog
		if dog == null or not dog.alive or dog.round_locked or dog.invincible or dog.is_burrowed():
			continue
		var gap := Vector2(dog.global_position.x - global_position.x, dog.global_position.z - global_position.z)
		if gap.length() < RADIUS + dog.effective_radius() * 0.5:
			dog.eliminate(null, Vector3(gap.x, 0, gap.y).normalized() if gap.length() > 0.01 else Vector3.BACK)
	if game_match != null and is_instance_valid(game_match) and game_match.has_method("drop_toy"):
		game_match.drop_toy(global_position, toy_data)
	queue_free()
