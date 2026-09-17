@tool
class_name Portal
extends Area3D
## One end of a two-way warp. Dogs and toys that enter come out of the linked portal still
## travelling the way they were going, so a throw can be aimed through one and land somewhere
## nobody is watching.
##
## Portals are placed in pairs: each one points `link` at the other. Only one of the pair needs
## the NodePath filled in — the partner is told about it on ready.

## Where whatever went in comes out. Leave empty on one of the pair; the other will claim it.
@export var link: NodePath:
	set(v):
		link = v
		_relink()
@export var radius := 1.15:
	set(v):
		radius = v
		_rebuild()
## The ring colour. A pair reads as a pair because both ends share it.
@export var color := Color(0.65, 0.45, 1.0):
	set(v):
		color = v
		_rebuild()

## How far past the exit ring something is placed. Enough that it is outside the exit's own
## trigger, so a warp cannot immediately re-trigger and bounce the dog back and forth.
const EXIT_PUSH := 0.35
## A body that just came out of this portal ignores it for this long. Belt and braces for the
## case where something exits slowly and lingers inside the ring.
const REENTRY_BLOCK := 0.45

var partner: Portal

var _shape: CollisionShape3D
var _visual: Node3D
var _swirl: MeshInstance3D
var _blocked: Dictionary = {}


func _ready() -> void:
	collision_layer = 8
	# Dogs (2) and toys (4) both travel through.
	collision_mask = 2 | 4
	monitorable = false
	_rebuild()
	if Engine.is_editor_hint():
		return
	_relink()
	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	if _swirl != null:
		_swirl.rotate_y(delta * 1.9)
	for body in _blocked.keys():
		_blocked[body] -= delta
		if _blocked[body] <= 0.0 or not is_instance_valid(body):
			_blocked.erase(body)


func _relink() -> void:
	if Engine.is_editor_hint() or not is_inside_tree():
		return
	if link.is_empty():
		return
	var other := get_node_or_null(link) as Portal
	if other == null:
		push_warning("Portal %s has no partner at %s" % [name, link])
		return
	partner = other
	# Two-way without needing the path filled in at both ends.
	if other.partner == null:
		other.partner = self


func _rebuild() -> void:
	if not is_inside_tree():
		return
	if _shape == null:
		_shape = CollisionShape3D.new()
		_shape.shape = CylinderShape3D.new()
		add_child(_shape)
	var cylinder := _shape.shape as CylinderShape3D
	cylinder.radius = radius
	cylinder.height = 2.2
	_shape.position.y = 1.1
	if _visual != null:
		_visual.queue_free()
	_visual = Node3D.new()
	add_child(_visual)
	# A raised stone lip so the hole reads as a hole and not a painted circle.
	Mats.mesh(_visual, Mats.torus(radius, radius + 0.3), color.darkened(0.45), Vector3(0, 0.08, 0))
	var mouth := Mats.mesh(_visual, Mats.cylinder(radius, 0.05), color.darkened(0.7), Vector3(0, 0.05, 0))
	mouth.material_override = Mats.unlit(color.darkened(0.75))
	_swirl = Mats.mesh(_visual, Mats.torus(radius * 0.42, radius * 0.86), color.lightened(0.3), Vector3(0, 0.1, 0))
	_swirl.material_override = Mats.unlit(color.lightened(0.35))
	_swirl.scale = Vector3(1.0, 0.35, 1.0)
	_swirl.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# A soft column of light so the pair can be spotted across the arena.
	var beam := Mats.mesh(_visual, Mats.cylinder(radius * 0.72, 1.5), color, Vector3(0, 0.78, 0))
	beam.material_override = Mats.glass(Color(color, 0.16))
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _on_body_entered(body: Node3D) -> void:
	if partner == null or not is_instance_valid(partner) or _blocked.has(body):
		return
	if body is Dog and not (body as Dog).alive:
		return
	var mover := body as CharacterBody3D
	if mover == null:
		return
	# Keep the heading, move the position: a toy thrown into a portal keeps flying.
	var heading := Vector3(mover.velocity.x, 0.0, mover.velocity.z)
	if heading.length() < 0.05:
		heading = Vector3(0, 0, 1)
	var exit_at := partner.global_position + heading.normalized() * (partner.radius + EXIT_PUSH)
	exit_at.y = mover.global_position.y
	partner.block(body)
	Juice.burst(get_parent(), global_position + Vector3.UP * 0.6, color.lightened(0.2), 16, 3.0)
	mover.global_position = exit_at
	Juice.burst(get_parent(), exit_at + Vector3.UP * 0.6, partner.color.lightened(0.2), 16, 3.0)
	Sfx.play("squeak", 1.35, -6.0)


## Stops this portal grabbing a body that has just come out of it.
func block(body: Node3D) -> void:
	_blocked[body] = REENTRY_BLOCK
