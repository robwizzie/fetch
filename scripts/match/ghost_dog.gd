class_name GhostDog
extends Node3D
## Free-for-all, when ghosts are on: a knocked-out player floats back in as a see-through ghost of
## their dog until the round is over. It drifts over everything (but not out of the arena), its
## bark is a "BOO!" that startles any dog near it into a stumble, and its throw button nudges a
## loose toy along the floor. It can't pick anything up, can't hurt anyone with a toy and can't
## score - it's there so being out is still something to do, not 40 seconds of watching.

const SPEED := 5.0
const SPOOK_RADIUS := 2.4
const SPOOK_COOLDOWN := 3.5
const NUDGE_RADIUS := 1.7
const NUDGE_SPEED := 6.5
const NUDGE_COOLDOWN := 1.2

var slot: PlayerSlot
var input: DeviceInput
var facing := Vector3.FORWARD
var _model: DogModel
var _arena: Arena
var _spook_clock := 0.0
var _nudge_clock := 0.0
var _velocity := Vector3.ZERO


func setup(p_slot: PlayerSlot, p_input: DeviceInput, arena: Arena) -> void:
	slot = p_slot
	input = p_input
	_arena = arena


func _ready() -> void:
	add_to_group(&"ghosts")
	_model = DogModel.new()
	add_child(_model)
	_model.setup(slot.dog, slot.color)
	_model.position.y = 0.55
	_haunt(_model)
	var tag := Label3D.new()
	tag.text = "%s · GHOST" % slot.label
	tag.font = UiKit.FONT_DISPLAY
	tag.font_size = 40
	tag.pixel_size = 0.006
	tag.outline_size = 10
	tag.modulate = slot.color.lightened(0.5)
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tag.no_depth_test = true
	tag.position = Vector3(0, _model.height() + 1.0, 0)
	add_child(tag)
	Juice.burst(get_parent(), global_position + Vector3.UP, Color(0.85, 0.95, 1.0, 0.8), 20, 3.0)


## Every surface of the dog turned into the same pale, see-through, unlit stuff.
func _haunt(root: Node) -> void:
	var ghostly := StandardMaterial3D.new()
	ghostly.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ghostly.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ghostly.albedo_color = Color(slot.color.lightened(0.65), 0.42)
	ghostly.cull_mode = BaseMaterial3D.CULL_BACK
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		mesh.material_override = ghostly
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _physics_process(delta: float) -> void:
	_spook_clock = maxf(0.0, _spook_clock - delta)
	_nudge_clock = maxf(0.0, _nudge_clock - delta)
	var move2 := input.move_vector()
	var move := Vector3(move2.x, 0, move2.y)
	if move.length() > 0.1:
		facing = move.normalized()
	_velocity = _velocity.lerp(move * SPEED, 1.0 - exp(-8.0 * delta))
	global_position += _velocity * delta
	if _arena != null:
		var half := _arena.size * 0.5 - Vector2(0.6, 0.6)
		var local := _arena.to_local(global_position)
		global_position = _arena.to_global(Vector3(clampf(local.x, -half.x, half.x), 0, clampf(local.z, -half.y, half.y)))
	_model.position.y = 0.55 + sin(Time.get_ticks_msec() * 0.004) * 0.12
	_model.update_motion(facing, _velocity.length() / SPEED * 0.6, delta)
	if input.just_pressed(&"bark"):
		_spook()
	if input.just_pressed(&"throw"):
		_nudge()


func _spook() -> void:
	if _spook_clock > 0.0:
		return
	_spook_clock = SPOOK_COOLDOWN
	Sfx.play_at("whistle", global_position, 0.6, -4.0)
	Juice.float_text(get_parent(), global_position + Vector3(0, 2.2, 0), "BOO!", Color(0.85, 0.95, 1.0), 0.9)
	Juice.burst(get_parent(), global_position + Vector3.UP, Color(0.85, 0.95, 1.0, 0.8), 16, 4.0)
	for node in get_tree().get_nodes_in_group("dogs"):
		var dog := node as Dog
		if dog != null and dog.alive and Vector2(dog.global_position.x - global_position.x, dog.global_position.z - global_position.z).length() < SPOOK_RADIUS:
			dog.spook(global_position)


## A loose toy near the ghost slides off the way it is facing. It stays a floor toy - a nudge
## never makes a dangerous throw.
func _nudge() -> void:
	if _nudge_clock > 0.0:
		return
	for node in get_tree().get_nodes_in_group("toys"):
		var toy := node as Toy
		if toy == null or toy.state != Toy.State.IDLE or toy.ephemeral:
			continue
		if Vector2(toy.global_position.x - global_position.x, toy.global_position.z - global_position.z).length() < NUDGE_RADIUS:
			_nudge_clock = NUDGE_COOLDOWN
			toy.velocity = facing * NUDGE_SPEED
			Sfx.play_at("bounce", toy.global_position, 1.3, -6.0)
			return
