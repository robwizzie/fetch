@tool
class_name SwingBoard
extends AnimatableBody3D
## A wall on a pivot. A SwitchPad swings it a quarter turn, so the line a throw bounces along
## changes the moment someone steps on the switch - or hits the switch with a toy. Solid to dogs
## and toys alike; it sweeps dogs aside as it turns.

@export var length := 3.2:
	set(v):
		length = v
		_rebuild()
@export var height := 1.15
@export var color := Color("f2c84b")
@export var accent := Color("3f86e0")
## Starting angle in degrees about the pivot; a switch adds or takes away a quarter turn.
@export var angle := 45.0
## How far one throw of the switch turns it.
@export var swing := 90.0

const THICKNESS := 0.3
const TURN_TIME := 0.38

var _home_angle := 0.0
var _turned := false
var _tween: Tween
var _visual: Node3D


func _ready() -> void:
	collision_layer = 1
	collision_mask = 0
	sync_to_physics = false
	_home_angle = angle
	rotation_degrees.y = angle
	_rebuild()


func _rebuild() -> void:
	if not is_inside_tree():
		return
	for child in get_children():
		child.queue_free()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(length, height, THICKNESS)
	shape.shape = box
	shape.position.y = height * 0.5
	add_child(shape)
	_visual = Node3D.new()
	add_child(_visual)
	# A striped agility board on a post, with an arrow on top showing it turns.
	var stripes := 5
	for i in stripes:
		var x := -length * 0.5 + (float(i) + 0.5) * length / float(stripes)
		ArenaArt.block(_visual, Vector3(length / float(stripes) - 0.02, height * 0.82, THICKNESS), color if i % 2 == 0 else accent,
			Vector3(x, height * 0.45, 0), Vector3.ZERO, 0.04)
	ArenaArt.block(_visual, Vector3(length + 0.1, 0.12, THICKNESS + 0.08), color.lightened(0.3), Vector3(0, height * 0.88, 0), Vector3.ZERO, 0.04)
	Mats.mesh(_visual, Mats.cylinder(0.24, height + 0.3), Color("ececec"), Vector3(0, (height + 0.3) * 0.5, 0))
	var cap := Mats.mesh(_visual, Mats.cylinder(0.32, 0.12), accent, Vector3(0, height + 0.36, 0))
	cap.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ArenaArt.block(_visual, Vector3(0.12, 0.05, 0.5), Color.WHITE, Vector3(0, height + 0.44, 0))
	Mats.contact_shadow(self, length * 0.5, Vector3(0, 0.024, 0))


func toggle() -> void:
	set_open(not _turned)


## "Open" is the turned position, so a SwitchPad in HOLD mode can drive it like a gate.
func set_open(turned: bool) -> void:
	if turned == _turned:
		return
	_turned = turned
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "rotation_degrees:y", _home_angle + (swing if turned else 0.0), TURN_TIME) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	Sfx.play_at("bounce", global_position, 0.7, -6.0)


func reset_for_round() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_turned = false
	rotation_degrees.y = _home_angle
