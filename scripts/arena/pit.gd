@tool
class_name Pit
extends Node3D
## A hole in the ground (Backyard: one the dogs dug themselves). Walk up to it and you stop at
## the rim - nobody falls in by accident. Get whacked, shoved by the sprinkler or mower, or
## stumble in dizzy, and you go in: that is a knockout, credited to whoever knocked you there.
## A dash hops clean over. Toys that roll in pop back out, so nothing is ever lost down one.
## The same rules make Frozen Pond's open water: [member look] only changes what it looks like.

enum Look { DIRT, WATER }

const GROUP := &"pits"
## A dog's centre may come this far inside the rim while being pushed before it is past saving.
const LIP := 0.35
## How hard a dog has to be moving under someone else's power to go over the edge.
const PUSHED := 1.2

@export var radius := 1.05:
	set(v):
		radius = v
		_rebuild()
@export var dirt := Color("6b4a2f")
## A dug hole, or a hole broken through the ice into dark water.
@export var look := Look.DIRT:
	set(v):
		look = v
		_rebuild()

var _visual: Node3D


func _ready() -> void:
	add_to_group(GROUP)
	_rebuild()


func _rebuild() -> void:
	if not is_inside_tree():
		return
	if is_instance_valid(_visual):
		_visual.queue_free()
	_visual = Node3D.new()
	add_child(_visual)
	if look == Look.WATER:
		_build_water()
		return
	# A mound of dug-out earth around a dark mouth, darker towards the middle so it reads as deep.
	var mound := Mats.mesh(_visual, Mats.torus(radius * 0.92, radius * 1.32), dirt.lightened(0.08), Vector3(0, 0.02, 0))
	mound.scale = Vector3(1, 0.55, 1)
	for i in 3:
		var depth := Mats.mesh_plain(_visual, Mats.cylinder(radius * (1.0 - i * 0.22), 0.01), dirt.darkened(0.45 + i * 0.18), Vector3(0, 0.025 + i * 0.002, 0))
		depth.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for i in 7:
		var angle := TAU * float(i) / 7.0 + 0.4
		var clod := Mats.mesh(_visual, Mats.sphere(0.13 + 0.04 * float(i % 3)), dirt.lightened(0.04 * float(i % 2)),
			Vector3(cos(angle), 0, sin(angle)) * radius * (1.38 + 0.12 * float(i % 2)), Vector3.ZERO, Vector3(1, 0.6, 1))
		clod.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## Open water: a ragged ring of broken ice around a dark, cold pool, deepest in the middle.
func _build_water() -> void:
	var water := Color("2f6f8f")
	var shelf := Mats.mesh_plain(_visual, Mats.cylinder(radius + 0.16, 0.03), Color("e3f3fa"), Vector3(0, 0.035, 0))
	shelf.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for i in 3:
		var depth := Mats.mesh_plain(_visual, Mats.cylinder(radius * (1.0 - i * 0.24), 0.01), water.darkened(0.12 + i * 0.2), Vector3(0, 0.052 + i * 0.002, 0))
		depth.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		(depth.material_override as StandardMaterial3D).roughness = 0.2
	# Ripples, so it reads as water rather than a dark rug.
	for i in 2:
		var ripple := Mats.mesh(_visual, Mats.torus(radius * (0.42 + i * 0.26), radius * (0.42 + i * 0.26) + 0.022), water.lightened(0.35), Vector3(-0.08, 0.06, 0.05))
		ripple.scale = Vector3(1, 0.12, 0.85)
		ripple.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Broken shards of the ice sheet tilted up round the edge.
	for i in 11:
		var angle := TAU * float(i) / 11.0 + 0.2 * float(i % 3)
		var at := Vector3(cos(angle), 0, sin(angle)) * (radius + 0.02 + 0.06 * float(i % 2))
		var shard := Mats.mesh(_visual, Mats.prism(Vector3(0.42 + 0.12 * float(i % 3), 0.06, 0.3)), Color("d6eef8").lightened(0.04 * float(i % 2)),
			at + Vector3(0, 0.07, 0), Vector3(0, -rad_to_deg(angle) + 90.0, 14.0 + 8.0 * float(i % 3)))
		shard.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# A floating chunk of ice, the tell that this is a hole in the pond.
	var floe := ArenaArt.block(_visual, Vector3(0.38, 0.06, 0.28), Color("e8f6fc"), Vector3(radius * 0.32, 0.07, -radius * 0.25), Vector3(0, 28, 0), 0.02)
	floe.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## True when [param point] (on the ground) is over the hole, padded by [param margin].
func covers(point: Vector3, margin: float = 0.0) -> bool:
	return Vector2(point.x - global_position.x, point.z - global_position.z).length() < radius + margin


func _physics_process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
	for node in get_tree().get_nodes_in_group("dogs"):
		var dog := node as Dog
		if dog == null or not dog.alive or dog.round_locked or not dog.can_process():
			continue
		_handle_dog(dog)
	for node in get_tree().get_nodes_in_group("toys"):
		var toy := node as Toy
		if toy != null and toy.state == Toy.State.IDLE and covers(toy.global_position, 0.1):
			# Rolled in: it comes back up over the rim, still moving the way it was going.
			var out := _outward(toy.global_position)
			toy.global_position = Vector3(global_position.x, toy.global_position.y, global_position.z) + out * (radius + 0.45)
			toy.velocity = out * maxf(2.0, toy.velocity.length() * 0.5)


func _handle_dog(dog: Dog) -> void:
	if dog.is_dashing():
		return
	var offset := Vector2(dog.global_position.x - global_position.x, dog.global_position.z - global_position.z)
	var distance := offset.length()
	if distance >= radius:
		return
	if distance < radius - LIP:
		dog.fall_into(global_position)
		return
	if dog.is_being_pushed(PUSHED) or dog.dizzy_time > 0.0:
		return
	# Walking in under your own steam: the rim stops you.
	var out := _outward(dog.global_position)
	dog.global_position = Vector3(global_position.x, dog.global_position.y, global_position.z) + out * radius
	var inward := dog.velocity.dot(-out)
	if inward > 0.0:
		dog.velocity += out * inward


func _outward(point: Vector3) -> Vector3:
	var out := Vector3(point.x - global_position.x, 0, point.z - global_position.z)
	return Vector3(1, 0, 0) if out.length_squared() < 0.0001 else out.normalized()
