@tool
class_name Gate
extends StaticBody3D
## A wall panel that drops into the floor when its switch is thrown, opening a route that was
## shut a moment ago. Blocks dogs and toys alike while it is up.
##
## Gates do not decide anything themselves: a SwitchPad points at them.

@export var size := Vector3(4.0, 1.3, 0.45):
	set(v):
		size = v
		_rebuild()
@export var color := Color(0.58, 0.4, 0.24):
	set(v):
		color = v
		_rebuild()
## Gates that start down, so a switch closes them instead of opening them.
@export var starts_open := false

const TRAVEL := 0.55

var is_open := false

var _shape: CollisionShape3D
var _visual: Node3D
var _tween: Tween


func _ready() -> void:
	collision_layer = 1
	collision_mask = 0
	_rebuild()
	if Engine.is_editor_hint():
		return
	is_open = starts_open
	if is_open:
		# Straight to the open position, no animation on the first frame.
		_visual.position.y = -size.y * 1.05
		_shape.set_deferred("disabled", true)


func _rebuild() -> void:
	if not is_inside_tree():
		return
	if _shape == null:
		_shape = CollisionShape3D.new()
		_shape.shape = BoxShape3D.new()
		add_child(_shape)
	(_shape.shape as BoxShape3D).size = size
	_shape.position.y = size.y * 0.5
	if _visual != null:
		_visual.queue_free()
	_visual = Node3D.new()
	add_child(_visual)
	# Slatted panel so it reads as a gate rather than a slab, with a bright cap on top.
	var slats := maxi(2, int(size.y / 0.34))
	for i in slats:
		var y := size.y * (float(i) + 0.5) / float(slats)
		var shade := color.lerp(color.darkened(0.3), float(i % 2) * 0.55)
		Mats.mesh(_visual, Mats.box(Vector3(size.x, size.y / float(slats) - 0.05, size.z)), shade, Vector3(0, y, 0))
	Mats.mesh(_visual, Mats.box(Vector3(size.x + 0.12, 0.12, size.z + 0.12)), color.lightened(0.32), Vector3(0, size.y, 0))
	# Posts at each end so the panel looks held up by something.
	for side in [-1.0, 1.0]:
		Mats.mesh(_visual, Mats.box(Vector3(0.26, size.y + 0.2, size.z + 0.16)), color.darkened(0.42),
			Vector3(side * (size.x * 0.5 + 0.13), (size.y + 0.2) * 0.5, 0))


func set_open(open: bool) -> void:
	if open == is_open:
		return
	is_open = open
	if _tween != null and _tween.is_valid():
		_tween.kill()
	# Collision goes the instant it opens, and only once it has finished closing, so a gate
	# never shuts on top of a dog that already made it through.
	if open:
		_shape.set_deferred("disabled", true)
	_tween = create_tween()
	_tween.tween_property(_visual, "position:y", -size.y * 1.05 if open else 0.0, TRAVEL) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	if not open:
		_tween.tween_callback(func() -> void: _shape.set_deferred("disabled", false))
	Sfx.play("bounce", 0.6 if open else 0.75, -8.0)


func toggle() -> void:
	set_open(not is_open)
