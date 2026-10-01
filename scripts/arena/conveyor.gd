@tool
class_name Conveyor
extends Node3D
## Kitchen gimmick: a conveyor belt set into the floor. Everything standing on it rides along
## its local +X - dogs, and toys lying loose - so a belt is a fast lane one way and a slog the
## other. A dog can always walk off the side or against the flow, just slowly. Toys carried
## off the end keep skidding a little way. Thrown toys fly over it.
##
## The carry goes through the body's own collision (move_and_collide for dogs, the toy's
## velocity for toys), so a belt can never push anyone through a wall or a prop: lay one with
## open floor past both ends and it never pins anybody against anything.

## Belt length (local X, the way it runs) and width (local Z), in metres.
@export var length := 9.0:
	set(v):
		length = v
		_rebuild()
@export var width := 1.7:
	set(v):
		width = v
		_rebuild()
## Belt speed in metres per second. A dog walks at about 7.
@export var speed := 2.8
@export var frame_color := Color("c9cfd4")
@export var belt_color := Color("3d4148")
@export var arrow_color := Color("ffcf5a")

const ARROW_GAP := 1.1
const DECK_Y := 0.05

var _visual: Node3D
var _arrows: Array[Node3D] = []
var _scroll := 0.0
## Spacing actually used, stretched so the arrows tile the belt end to end.
var _gap := ARROW_GAP


func _ready() -> void:
	if not Engine.is_editor_hint():
		add_to_group("gimmicks")
	_rebuild()


## The way the belt runs, flat on the floor.
func direction() -> Vector3:
	var x := global_transform.basis.x
	x.y = 0.0
	return x.normalized()


## True when a point on the floor is on the belt, padded by [param margin].
func covers(point: Vector3, margin: float = 0.0) -> bool:
	var local := to_local(Vector3(point.x, global_position.y, point.z))
	return absf(local.x) <= length * 0.5 + margin and absf(local.z) <= width * 0.5 + margin


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	var flow := direction() * speed
	for node in get_tree().get_nodes_in_group("dogs"):
		var dog := node as Dog
		if dog == null or not dog.alive or dog.round_locked or not dog.can_process() or dog.is_burrowed():
			continue
		if covers(dog.global_position):
			# Through the dog's own collider: walls and props stop the ride, nothing tunnels.
			dog.move_and_collide(flow * delta)
	for node in get_tree().get_nodes_in_group("toys"):
		var toy := node as Toy
		if toy == null or toy.state != Toy.State.IDLE or not toy.can_process():
			continue
		if covers(toy.global_position):
			# Top the toy up to belt speed along the flow; whatever it was doing sideways it
			# keeps, and its own friction slows it once it rolls off the end.
			var along := toy.velocity.dot(direction())
			if along < speed:
				toy.velocity += direction() * minf(speed - along, speed * 8.0 * delta + toy.data.friction * delta)


func _process(delta: float) -> void:
	if _arrows.is_empty():
		return
	# Engine.is_editor_hint() still animates, so the belt is visibly running in the editor too.
	_scroll = fposmod(_scroll + speed * delta, _gap)
	var span := length - 0.5
	for i in _arrows.size():
		var x := fposmod(float(i) * _gap + _scroll, span) - span * 0.5
		var arrow := _arrows[i]
		arrow.position.x = x
		# Arrows shrink into the rollers at each end rather than popping in and out.
		var edge := minf(x + span * 0.5, span * 0.5 - x)
		arrow.scale = Vector3.ONE * clampf(edge / 0.45, 0.0, 1.0)
		arrow.visible = edge > 0.0


func _rebuild() -> void:
	if not is_inside_tree():
		return
	if is_instance_valid(_visual):
		_visual.queue_free()
	_arrows.clear()
	_visual = Node3D.new()
	add_child(_visual)
	# Steel frame, a dark rubber belt sunk into it, and a roller drum at each end.
	var frame := ArenaArt.block(_visual, Vector3(length + 0.3, 0.07, width + 0.34), frame_color.darkened(0.25), Vector3(0, 0.035, 0), Vector3.ZERO, 0.03)
	frame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for side: float in [-1.0, 1.0]:
		var rail := ArenaArt.block(_visual, Vector3(length + 0.3, 0.1, 0.16), frame_color, Vector3(0, 0.06, side * (width * 0.5 + 0.09)), Vector3.ZERO, 0.03)
		rail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		# Hazard chevrons on the end caps tell you which end you are carried to.
		var drum := Mats.mesh(_visual, Mats.cylinder(0.11, width), frame_color.lightened(0.1), Vector3(side * (length * 0.5 + 0.02), 0.06, 0), Vector3(90, 0, 0))
		drum.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var belt := Mats.mesh_plain(_visual, Mats.box(Vector3(length - 0.1, 0.02, width)), belt_color, Vector3(0, DECK_Y + 0.02, 0))
	belt.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Ribs across the belt are drawn on the scrolling arrows' layer below; the arrows are what
	# move, so it is obvious from across the room which way it is running.
	var count := maxi(2, int(round((length - 0.5) / ARROW_GAP)))
	_gap = (length - 0.5) / float(count)
	for i in count:
		var arrow := Node3D.new()
		arrow.position = Vector3(0, DECK_Y + 0.035, 0)
		_visual.add_child(arrow)
		var rib := Mats.mesh_plain(arrow, Mats.box(Vector3(0.06, 0.006, width * 0.92)), belt_color.lightened(0.12), Vector3(-_gap * 0.5, 0, 0))
		rib.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		for side: float in [-1.0, 1.0]:
			var stroke := MeshInstance3D.new()
			stroke.mesh = Mats.box(Vector3(0.62, 0.008, 0.16))
			stroke.material_override = Mats.unlit(arrow_color)
			stroke.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			stroke.position = Vector3(-0.2, 0, side * 0.2)
			stroke.rotation_degrees.y = side * 40.0
			arrow.add_child(stroke)
		_arrows.append(arrow)
