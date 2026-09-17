class_name ReadyPen
extends Node3D
## One player's practice pen for the tutorial round: walled off from everyone else, with a toy
## to try and a pad to stand on when they have the hang of it.
##
## Walls are taller than a toy flies, so nothing crosses between pens and nobody can be
## knocked out while they are still learning which button throws.

signal readied(pen: ReadyPen)

## Just clear of a toy in flight (FLY_HEIGHT plus the largest toy radius), and no taller —
## a high wall hides the dog behind it from the overhead camera.
const WALL_HEIGHT := 1.25
const PAD_RADIUS := 0.95
## How long a dog has to stand on the pad. Long enough that walking over it by accident
## does not lock in a choice, short enough that it never feels unresponsive.
const DWELL := 0.45

var slot: PlayerSlot
var dog: Dog
var is_ready := false

var _pad: MeshInstance3D
var _pad_ring: MeshInstance3D
var _label: Label3D
var _dwell := 0.0
var _size: Vector2
var _opening := false


func build(p_slot: PlayerSlot, centre: Vector3, size: Vector2) -> void:
	slot = p_slot
	_size = size
	position = centre
	var tint := slot.color

	var walls := StaticBody3D.new()
	walls.name = "Walls"
	walls.collision_layer = 1
	walls.collision_mask = 0
	add_child(walls)
	var half := size * 0.5
	for spec in [
		[Vector3(0, WALL_HEIGHT / 2.0, -half.y), Vector3(size.x, WALL_HEIGHT, 0.3)],
		[Vector3(0, WALL_HEIGHT / 2.0, half.y), Vector3(size.x, WALL_HEIGHT, 0.3)],
		[Vector3(-half.x, WALL_HEIGHT / 2.0, 0), Vector3(0.3, WALL_HEIGHT, size.y)],
		[Vector3(half.x, WALL_HEIGHT / 2.0, 0), Vector3(0.3, WALL_HEIGHT, size.y)],
	]:
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = spec[1]
		shape.shape = box
		shape.position = spec[0]
		walls.add_child(shape)
		# Waist-high panel in the player's colour, with a pale cap so the top edge reads.
		Mats.mesh(walls, Mats.box(spec[1]), tint.darkened(0.25), spec[0])
		Mats.mesh(walls, Mats.box(Vector3(spec[1].x + 0.06, 0.12, spec[1].z + 0.06)), tint.lightened(0.3),
			spec[0] + Vector3(0, WALL_HEIGHT / 2.0, 0))

	# The ready pad, at the far end so it takes a deliberate walk to reach.
	var pad_at := Vector3(0, 0.03, half.y - 1.15)
	_pad = Mats.mesh(self, Mats.cylinder(PAD_RADIUS, 0.06), tint.darkened(0.35), pad_at)
	_pad_ring = Mats.mesh(self, Mats.torus(PAD_RADIUS * 0.82, PAD_RADIUS), tint.lightened(0.25), pad_at + Vector3(0, 0.03, 0))
	_pad_ring.material_override = Mats.unlit(tint.lightened(0.25))
	_pad_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	_label = Label3D.new()
	_label.text = "STAND HERE\nWHEN READY"
	_label.font = UiKit.FONT_DISPLAY
	_label.font_size = 40
	_label.pixel_size = 0.0042
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.modulate = tint.lightened(0.45)
	_label.outline_size = 6
	_label.outline_modulate = Color(0.06, 0.1, 0.06)
	_label.position = pad_at + Vector3(0, 1.35, 0)
	add_child(_label)


func _physics_process(delta: float) -> void:
	if is_ready or _opening:
		return
	var pulse := 1.0 + sin(Time.get_ticks_msec() * 0.005) * 0.06
	_pad_ring.scale = Vector3(pulse, 1.0, pulse)
	if not is_instance_valid(dog) or not dog.alive:
		return
	var pad_world := _pad.global_position
	var gap := Vector2(dog.global_position.x - pad_world.x, dog.global_position.z - pad_world.z).length()
	if gap <= PAD_RADIUS:
		_dwell += delta
		if _dwell >= DWELL:
			_set_ready()
	else:
		_dwell = maxf(0.0, _dwell - delta * 2.0)


## Bots do not need teaching; they take a moment so the pens do not all pop at once.
func auto_ready_after(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout
	if not is_ready and not _opening:
		_set_ready()


func _set_ready() -> void:
	if is_ready:
		return
	is_ready = true
	_label.text = "READY!"
	_label.modulate = Color(0.55, 1.0, 0.55)
	_pad.material_override = Mats.unlit(Color(0.45, 0.95, 0.45))
	_pad_ring.material_override = Mats.unlit(Color(0.6, 1.0, 0.6))
	Sfx.play("treat", 1.15, -4.0)
	Juice.burst(get_parent(), _pad.global_position + Vector3.UP * 0.4, Color(0.5, 0.95, 0.5), 18, 3.2)
	Juice.float_text(get_parent(), _pad.global_position + Vector3.UP * 1.9, "READY!", Color(0.6, 1.0, 0.6), 0.9)
	readied.emit(self)


## Drops the walls so everyone can spill out into the arena.
func open() -> void:
	if _opening:
		return
	_opening = true
	var walls := get_node_or_null("Walls")
	if walls != null:
		for shape in walls.find_children("*", "CollisionShape3D", true, false):
			(shape as CollisionShape3D).set_deferred("disabled", true)
		var tween := create_tween()
		tween.tween_property(walls, "position:y", -WALL_HEIGHT * 1.2, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	var fade := create_tween()
	fade.tween_property(_label, "modulate:a", 0.0, 0.3)
	fade.parallel().tween_property(_pad_ring, "scale", Vector3.ZERO, 0.4)
	fade.tween_callback(queue_free)
