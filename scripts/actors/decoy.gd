class_name Decoy
extends Node3D
## Good Decoy: a dash leaves a copy of the dog standing where it was, idling, ring and all.
## It cannot be hurt and blocks nothing; a dangerous toy passing through pops it, and so does
## time. Bots may fall for it (see BotBrain); people have to look twice.

const LIFETIME := 2.5

var dog: Dog
var _age := 0.0
var _model: DogModel
var _popped := false


func setup(p_dog: Dog) -> void:
	dog = p_dog


func _ready() -> void:
	add_to_group("decoys")
	add_to_group("combat_effects")
	_model = DogModel.new()
	add_child(_model)
	_model.setup(dog.data, dog.slot.color)
	_model.quaternion = dog.model.quaternion
	var ring := MeshInstance3D.new()
	ring.mesh = dog.ring.mesh
	ring.material_override = dog.ring.material_override
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ring.position = dog.ring.position
	add_child(ring)
	Mats.contact_shadow(self, dog.data.body_radius * 0.85)


func _physics_process(delta: float) -> void:
	_age += delta
	if _age >= LIFETIME or not is_instance_valid(dog) or not dog.alive:
		poof()
		return
	for node in get_tree().get_nodes_in_group("toys"):
		var toy := node as Toy
		if toy == null or not toy.is_dangerous() or toy.thrower == dog:
			continue
		var gap := Vector2(toy.global_position.x - global_position.x, toy.global_position.z - global_position.z)
		if gap.length() < dog.data.body_radius + toy.data.radius:
			poof()
			return


## Gone in a puff: the tell that it was never the real dog.
func poof() -> void:
	if _popped:
		return
	_popped = true
	remove_from_group("decoys")
	var color := dog.slot.color if is_instance_valid(dog) else Color.WHITE
	Juice.burst(get_parent(), global_position + Vector3.UP * 0.6, Color(1, 1, 1, 0.85), 14, 3.5)
	Juice.burst(get_parent(), global_position + Vector3.UP * 0.6, color, 10, 2.5)
	Juice.float_text(get_parent(), global_position + Vector3.UP * 1.5, "POOF!", Color(0.9, 0.93, 1.0), 0.6)
	Sfx.play_at("squeak", global_position, 1.6, -8.0)
	queue_free()
