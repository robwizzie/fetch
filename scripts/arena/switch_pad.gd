@tool
class_name SwitchPad
extends Area3D
## A big paw-button on the floor. Step on it — or hit it with a toy from across the arena — and
## every gate it points at swaps state. Whoever controls the switch controls the route.

signal thrown(pad: SwitchPad)

enum Mode {
	## Each trigger flips the gates. Someone has to come back and flip them again.
	TOGGLE,
	## Gates stay open only while somebody is standing on the pad.
	HOLD,
}

## The gates this switch drives.
@export var gates: Array[NodePath] = []
@export var mode := Mode.TOGGLE
@export var radius := 0.9:
	set(v):
		radius = v
		_rebuild()
@export var color := Color(1.0, 0.72, 0.2):
	set(v):
		color = v
		_rebuild()

## Stops a dog jittering on the edge of the pad from strobing the gates.
const REARM := 0.7
const PRESS_DEPTH := 0.07

var _shape: CollisionShape3D
var _visual: Node3D
var _cap: MeshInstance3D
var _cooldown := 0.0
var _occupants := 0


func _ready() -> void:
	collision_layer = 8
	collision_mask = 2 | 4
	monitorable = false
	_rebuild()
	if Engine.is_editor_hint():
		return
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _process(delta: float) -> void:
	_cooldown = maxf(0.0, _cooldown - delta)
	if _cap == null:
		return
	var pressed := _occupants > 0
	var want := -PRESS_DEPTH if pressed else 0.0
	_cap.position.y = lerpf(_cap.position.y, 0.09 + want, delta * 14.0)


func _rebuild() -> void:
	if not is_inside_tree():
		return
	if _shape == null:
		_shape = CollisionShape3D.new()
		_shape.shape = CylinderShape3D.new()
		add_child(_shape)
	var cylinder := _shape.shape as CylinderShape3D
	cylinder.radius = radius
	cylinder.height = 1.6
	_shape.position.y = 0.8
	if _visual != null:
		_visual.queue_free()
	_visual = Node3D.new()
	add_child(_visual)
	Mats.mesh(_visual, Mats.cylinder(radius + 0.16, 0.08), color.darkened(0.55), Vector3(0, 0.04, 0))
	_cap = Mats.mesh(_visual, Mats.cylinder(radius, 0.1), color, Vector3(0, 0.09, 0))
	# The paw rides on the cap so it sinks with it when the pad is stood on.
	var paw := Mats.mesh(_cap, Mats.cylinder(radius * 0.34, 0.03), color.lightened(0.45), Vector3(0, 0.06, 0.08))
	paw.material_override = Mats.unlit(color.lightened(0.5))
	paw.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for i in 4:
		var angle := PI * (0.22 + 0.19 * float(i))
		var toe := Mats.mesh(_cap, Mats.cylinder(radius * 0.14, 0.03), color.lightened(0.45),
			Vector3(cos(angle) * radius * 0.46, 0.06, -sin(angle) * radius * 0.46 - 0.16))
		toe.material_override = Mats.unlit(color.lightened(0.5))
		toe.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _on_body_entered(body: Node3D) -> void:
	if body is Dog:
		if not (body as Dog).alive:
			return
		_occupants += 1
		if mode == Mode.HOLD:
			_set_gates(true)
			return
	_fire()


func _on_body_exited(body: Node3D) -> void:
	if body is Dog:
		_occupants = maxi(0, _occupants - 1)
		if mode == Mode.HOLD and _occupants == 0:
			_set_gates(false)


func _fire() -> void:
	if _cooldown > 0.0:
		return
	_cooldown = REARM
	for gate in _gate_nodes():
		gate.toggle()
	Sfx.play("treat", 0.9, -5.0)
	Juice.burst(get_parent(), global_position + Vector3.UP * 0.4, color, 14, 2.6)
	thrown.emit(self)


func _set_gates(open: bool) -> void:
	for gate in _gate_nodes():
		gate.set_open(open)


func _gate_nodes() -> Array[Gate]:
	var out: Array[Gate] = []
	for path in gates:
		var node := get_node_or_null(path) as Gate
		if node != null:
			out.append(node)
	return out
