class_name Powerup
extends Node3D
## A mystery treat. What is inside is hidden until a dog reaches it, so the run for one is a
## gamble rather than a shopping trip — you commit before you know what you are getting.
## The reveal is the payoff: the wrapper bursts, the icon flies up, and the belt updates.
##
## It is deliberately the most appetising thing on the field: a fat wrapped bonbon that bobs,
## turns and throws light around, because the whole mechanic depends on people wanting to run
## at it while somebody is aiming at them.

## Rolled on spawn but never shown until collection.
var kind: StringName = PowerupKinds.SHIELD
var lifetime := 18.0
var age := 0.0

var _crate: Node3D
var _lid: Node3D
var _halo: MeshInstance3D
var _taken := false


func _ready() -> void:
	add_to_group("powerups")
	_crate = Node3D.new()
	add_child(_crate)
	Mats.contact_shadow(self, 0.44)

	# A wrapped sweet: a fat body with twisted ends, in cream and cherry with a gold band.
	_lid = Node3D.new()
	_crate.add_child(_lid)
	var cream := Color("fff0d2")
	var cherry := Color("e8556d")
	var gold := Palette.GOLD
	var body := Mats.mesh(_lid, Mats.sphere(0.3), cream, Vector3(0, 0.42, 0))
	body.scale = Vector3(1.0, 0.86, 1.0)
	# Two stripes around the middle, so it reads as wrapped rather than as a ball.
	for lift in [-0.085, 0.085]:
		var band := Mats.mesh(_lid, Mats.torus(0.24, 0.305), cherry, Vector3(0, 0.42 + lift, 0))
		band.rotation_degrees = Vector3(90, 0, 0)
	var ribbon := Mats.mesh(_lid, Mats.torus(0.285, 0.325), gold, Vector3(0, 0.42, 0))
	ribbon.rotation_degrees = Vector3(90, 0, 0)
	# The twisted ends of the wrapper.
	for side in [-1.0, 1.0]:
		var twist := Mats.mesh(_lid, Mats.cone(0.16, 0.24), cream.darkened(0.06),
			Vector3(side * 0.34, 0.42, 0))
		twist.rotation_degrees = Vector3(0, 0, 90.0 * side)

	# A question mark on the wrapper: the contents stay secret until it opens.
	var mark := Sprite3D.new()
	mark.texture = PowerupIcon.texture(&"mystery", 128, gold)
	mark.pixel_size = 0.0042
	mark.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	mark.no_depth_test = true
	mark.render_priority = 5
	mark.position = Vector3(0, 0.42, 0)
	_lid.add_child(mark)

	# A pool of warm light under it and a ring on the floor: visible across the arena, which is
	# the point - people have to see it in time to decide to go for it.
	_halo = Mats.mesh(self, Mats.torus(0.5, 0.66), Color(1.0, 0.86, 0.42, 0.6), Vector3(0, 0.04, 0))
	_halo.material_override = Mats.unlit(Color(1.0, 0.86, 0.42, 0.6))
	_halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var glow := OmniLight3D.new()
	glow.light_color = Color(1.0, 0.85, 0.5)
	glow.light_energy = 1.4
	glow.omni_range = 3.2
	glow.position = Vector3(0, 0.6, 0)
	add_child(glow)

	_crate.scale = Vector3.ONE * 0.1
	var drop := create_tween()
	drop.tween_property(_crate, "scale", Vector3.ONE, 0.42).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	Sfx.play("pickup", 0.7, -8.0)


func _physics_process(delta: float) -> void:
	if _taken:
		return
	age += delta
	_crate.position.y = 0.16 + sin(age * 2.6) * 0.09
	_crate.rotation.y += delta * 0.9
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


## The reveal. The lid flies, the glyph and name pop, and only then does the dog learn what
## it grabbed.
func _open(dog: Dog) -> void:
	_taken = true
	# Out of the group immediately: the reveal animation still has to play, but nothing
	# should be able to collect or target it again.
	remove_from_group("powerups")
	# Decided on opening, not on spawning: the crate is a mystery until then, and this way it
	# can never hand over something the dog is already carrying.
	if dog.slot != null and dog.slot.has_powerup(kind):
		kind = PowerupKinds.random_new_kind(dog.slot.powerups)
	var dropped := dog.collect_powerup(kind)
	var tint := PowerupKinds.color(kind)
	var here := global_position

	_halo.visible = false
	var lid_tween := create_tween()
	lid_tween.set_parallel(true)
	lid_tween.tween_property(_lid, "position:y", 1.5, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	lid_tween.tween_property(_lid, "rotation:z", 2.6, 0.45)
	lid_tween.tween_property(_crate, "scale", Vector3(1.25, 0.6, 1.25), 0.18)
	lid_tween.chain().tween_property(_crate, "scale", Vector3.ZERO, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	lid_tween.chain().tween_callback(queue_free)

	Sfx.play("treat")
	Sfx.play("bark", randf_range(1.05, 1.18), -9.0)
	Juice.burst(get_parent(), here + Vector3.UP * 0.6, tint, 26, 5.0)
	Juice.float_text(get_parent(), here + Vector3.UP * 1.25, PowerupKinds.display_name(kind), tint, 1.0)
	# The icon flies up with the name, so the shape gets learned alongside the words.
	var badge := Sprite3D.new()
	badge.texture = PowerupIcon.texture(kind, 128, tint)
	badge.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	badge.pixel_size = 0.006
	badge.no_depth_test = true
	badge.render_priority = 8
	badge.position = here + Vector3.UP * 0.85
	get_parent().add_child(badge)
	var lift := badge.create_tween()
	lift.tween_property(badge, "scale", Vector3.ONE * 1.35, 0.22).from(Vector3.ZERO).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	lift.tween_property(badge, "position:y", here.y + 1.9, 0.75)
	lift.parallel().tween_property(badge, "modulate:a", 0.0, 0.75)
	lift.tween_callback(badge.queue_free)
	if dropped != &"":
		Juice.float_text(get_parent(), here + Vector3.UP * 0.75, "swapped " + PowerupKinds.display_name(dropped), Color(1, 1, 1, 0.75), 0.9)
	Events.powerup_collected.emit(dog, kind)
