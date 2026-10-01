class_name ReviveSpot
extends Node3D
## Team play: where a downed dog lies, a ring in its pack's colour. A pack-mate standing in it
## brings the dog back - the ring fills while they stay, drains slowly when they step out, and
## enemies can see exactly where to go to stop it. Rivals standing in it do nothing.

signal revived(spot: ReviveSpot, by: Dog)

const GROUP := &"revive_spots"
const RADIUS := 1.15
## Seconds of standing in the ring to bring a pack-mate back.
const REVIVE_TIME := 2.2
const DRAIN := 0.5

var dog: Dog
var progress := 0.0
var _ring: MeshInstance3D
var _fill: MeshInstance3D
var _fill_material: StandardMaterial3D
var _label: Label3D
var _done := false


func setup(p_dog: Dog) -> void:
	dog = p_dog


func _ready() -> void:
	add_to_group(GROUP)
	var color := Game.team_color(dog.slot.team) if dog.slot.team >= 0 else dog.slot.color
	_ring = Mats.mesh(self, Mats.torus(RADIUS - 0.09, RADIUS), color, Vector3(0, 0.05, 0))
	_ring.material_override = Mats.unlit(Color(color, 0.85))
	_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_fill = Mats.mesh(self, Mats.cylinder(RADIUS - 0.09, 0.01), color, Vector3(0, 0.04, 0))
	_fill_material = Mats.unlit(Color(color.lightened(0.3), 0.45))
	_fill.material_override = _fill_material
	_fill.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_fill.scale = Vector3(0.02, 1, 0.02)
	_label = Label3D.new()
	_label.text = "REVIVE!"
	_label.font = UiKit.FONT_DISPLAY
	_label.font_size = 56
	_label.outline_size = 14
	_label.pixel_size = 0.007
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.no_depth_test = true
	_label.modulate = color.lightened(0.35)
	_label.outline_modulate = Color(0.08, 0.06, 0.1)
	_label.position = Vector3(0, 1.6, 0)
	add_child(_label)


## The pack-mate standing in the ring, or null.
func rescuer() -> Dog:
	for node in get_tree().get_nodes_in_group("dogs"):
		var other := node as Dog
		if other == null or other == dog or not other.alive or other.round_locked or other.is_burrowed():
			continue
		if not other.slot.allied_with(dog.slot):
			continue
		if Vector2(other.global_position.x - global_position.x, other.global_position.z - global_position.z).length() < RADIUS + 0.2:
			return other
	return null


func _physics_process(delta: float) -> void:
	if _done or not is_instance_valid(dog) or dog.alive:
		queue_free()
		return
	if dog.round_locked:
		return
	var helper := rescuer()
	if helper != null:
		progress = minf(REVIVE_TIME, progress + delta)
	else:
		progress = maxf(0.0, progress - delta * DRAIN)
	var t := progress / REVIVE_TIME
	_fill.scale = Vector3(maxf(t, 0.02), 1, maxf(t, 0.02))
	_ring.scale = Vector3.ONE * (1.0 + 0.05 * sin(Time.get_ticks_msec() * 0.01)) if helper != null else Vector3.ONE
	_label.text = "REVIVING…" if helper != null else "REVIVE!"
	if progress >= REVIVE_TIME and helper != null:
		_done = true
		revived.emit(self, helper)
		queue_free()
