class_name Powerup
extends Node3D
## A sealed mystery treat with a readable arrival, opening and dog-following award.
## Every possible reward shares the same wrapper; only collection reveals the kind.

## Rolled on spawn but never shown until collection.
var kind: StringName = PowerupKinds.SHIELD
var lifetime := 18.0
var age := 0.0

var _crate: PowerupModel
var _sparkles: Node3D
var _arrival: Node3D
var _halo: MeshInstance3D
var _taken := false


func _ready() -> void:
	add_to_group("powerups")
	_arrival = Node3D.new()
	add_child(_arrival)
	_crate = PowerupModel.new()
	_crate.setup()
	_arrival.add_child(_crate)
	_crate.rotation.y = -0.3
	Mats.contact_shadow(self, 0.48)

	# Quiet concentric markers keep the sealed pickup distinct from loose toys.
	_halo = Mats.mesh(self, Mats.torus(0.57, 0.605), PowerupModel.GOLD, Vector3(0, 0.035, 0))
	_halo.material_override = Mats.unlit(Color(PowerupModel.GOLD, 0.80))
	_halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var inner := Mats.mesh(self, Mats.torus(0.43, 0.45), PowerupModel.CREAM, Vector3(0, 0.04, 0))
	inner.material_override = Mats.unlit(Color(PowerupModel.CREAM, 0.48))
	inner.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_sparkles = Node3D.new()
	_arrival.add_child(_sparkles)
	for i in 3:
		var angle := float(i) * TAU / 3.0
		var spark := Mats.mesh(_sparkles, Mats.box(Vector3(0.055, 0.055, 0.055)), PowerupModel.GOLD,
			Vector3(cos(angle) * 0.58, 0.65 + float(i) * 0.16, sin(angle) * 0.58), Vector3(0, 0, 45))
		spark.material_override = Mats.unlit(PowerupModel.GOLD)
		spark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_arrival.position.y = 1.8
	_arrival.scale = Vector3.ONE * 0.35
	var drop := create_tween().set_parallel(true)
	drop.tween_property(_arrival, "position:y", 0.0, 0.46).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	drop.tween_property(_arrival, "scale", Vector3.ONE, 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	Sfx.play("pickup", 0.7, -8.0)


func _physics_process(delta: float) -> void:
	if _taken:
		return
	age += delta
	_crate.position.y = 0.16 + sin(age * 2.6) * 0.09
	_crate.rotation.y += delta * 0.65
	_sparkles.rotation.y -= delta * 0.45
	var scale := 1.0 + sin(age * 3.0) * 0.06
	_halo.scale = Vector3(scale, 1.0, scale)
	# Blink out the last couple of seconds so nobody is surprised by it vanishing.
	visible = age < lifetime - 2.5 or fmod(age, 0.3) < 0.2
	if age >= lifetime:
		queue_free()
		return
	if age < 0.5:
		return
	for node in get_tree().get_nodes_in_group("dogs"):
		var dog := node as Dog
		if not dog.alive or dog.round_locked or dog.dizzy_time > 0.0:
			continue
		var gap := Vector2(dog.global_position.x - global_position.x, dog.global_position.z - global_position.z)
		if gap.length() > dog.data.body_radius + 0.55:
			continue
		var ray := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * 0.6, dog.global_position + Vector3.UP * 0.6, 1)
		if not get_world_3d().direct_space_state.intersect_ray(ray).is_empty():
			continue
		_open(dog)
		return


## Apply the effect immediately; the visual follows the recipient so ownership is clear.
func _open(dog: Dog) -> void:
	if _taken or not dog.alive or dog.round_locked or dog.slot == null:
		return
	_taken = true
	visible = true
	remove_from_group("powerups")
	if dog.slot.has_powerup(kind):
		kind = PowerupKinds.random_new_kind(dog.slot.powerups)
	var dropped := dog.collect_powerup(kind)
	var tint := PowerupKinds.color(kind)
	var here := global_position
	_halo.hide()
	_sparkles.hide()
	var opening := create_tween().set_parallel(true)
	opening.tween_property(_crate.lid, "position:y", 1.65, 0.34).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	opening.tween_property(_crate.lid, "rotation:z", -0.6, 0.34)
	opening.tween_property(_crate, "scale", Vector3(1.12, 0.88, 1.12), 0.12)
	opening.chain().tween_property(_arrival, "scale", Vector3.ONE * 0.01, 0.24).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	opening.chain().tween_callback(queue_free)

	Sfx.play("treat")
	Juice.burst(get_parent(), here + Vector3.UP * 0.65, tint, 14, 3.2)
	_award(dog, kind, dropped)
	Events.powerup_collected.emit(dog, kind)


func _award(dog: Dog, reward: StringName, dropped: StringName) -> void:
	var root := Node3D.new()
	root.name = "PowerupAward"
	dog.add_child(root)
	var top := 1.55 * dog.data.model_scale + 0.95
	root.position = Vector3(0, top, 0)
	var badge := Sprite3D.new()
	badge.texture = PowerupIcon.badge(reward, 128)
	badge.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	badge.pixel_size = 0.006
	badge.no_depth_test = true
	badge.render_priority = 8
	root.add_child(badge)
	# The medallion already says which treat this is - it is the same icon as the belt and the
	# field guide - so the line beside it says what it DOES instead of repeating the name.
	# Nobody reads the scoreboard mid-scrap, and the name alone never told anyone anything.
	var effect := _plaque(root, PowerupKinds.tag(reward), UiKit.FONT_DISPLAY, 34, 0.0088, 0.68)
	effect.modulate = PowerupKinds.color(reward)
	# Everything stacks upwards. Below the medallion is where the dog's own name tag lives,
	# and two labels fighting over that space read as neither.
	if dropped != &"":
		var note := _plaque(root, "SWAPPED " + PowerupKinds.display_name(dropped), UiKit.FONT_UI, 24, 0.005, 0.95)
		note.modulate = Color(1, 1, 1, 0.8)
	var reveal := root.create_tween()
	reveal.tween_property(root, "scale", Vector3.ONE, 0.26).from(Vector3.ONE * 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# Long enough to read a short line of it without holding up the round.
	reveal.tween_interval(1.5)
	reveal.tween_property(root, "position:y", top + 0.35, 0.25)
	reveal.parallel().tween_property(root, "scale", Vector3.ONE * 0.01, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	reveal.tween_callback(root.queue_free)


## One line of the award, outlined so it survives any arena underneath it.
func _plaque(parent: Node3D, text: String, font: Font, size: int, pixels: float, height: float) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.font = font
	label.font_size = size
	label.pixel_size = pixels
	label.outline_size = 10
	label.outline_modulate = PowerupModel.INK
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.render_priority = 8
	label.position.y = height
	parent.add_child(label)
	return label
