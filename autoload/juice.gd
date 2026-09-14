extends Node
## "Game feel" helpers: camera shake, hit-stop, pop/squash tweens, floating text, particle bursts.
## Everything is one call so gameplay code stays readable: Juice.shake(10), Juice.hitstop().

var _shake_amount := 0.0
var _shake_decay := 7.0
var _hitstop_active := false


func _process(delta: float) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	if _shake_amount > 0.002:
		cam.h_offset = randf_range(-1.0, 1.0) * _shake_amount
		cam.v_offset = randf_range(-1.0, 1.0) * _shake_amount
		_shake_amount = lerpf(_shake_amount, 0.0, minf(1.0, _shake_decay * delta))
	elif cam.h_offset != 0.0 or cam.v_offset != 0.0:
		cam.h_offset = 0.0
		cam.v_offset = 0.0
		_shake_amount = 0.0


## Amount is in metres of camera offset; 0.3 is a solid hit.
func shake(amount: float = 0.2) -> void:
	_shake_amount = maxf(_shake_amount, amount)


## Freezes the game for a few milliseconds on impactful hits. Safe to call without await.
func hitstop(duration: float = 0.08, time_scale: float = 0.05) -> void:
	if _hitstop_active:
		return
	_hitstop_active = true
	Engine.time_scale = time_scale
	await get_tree().create_timer(duration, true, false, true).timeout
	Engine.time_scale = 1.0
	_hitstop_active = false


## Scales a node up then eases it back to its base scale. Works for Node3D and Control.
func pop(node: Node, amount: float = 1.3, time: float = 0.18) -> void:
	if not is_instance_valid(node):
		return
	var base: Variant = node.scale
	node.scale = base * amount
	var t := create_tween()
	t.tween_property(node, "scale", base, time).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Spawns a rising, fading billboard label in world space ("BONK!", "CATCH!").
func float_text(parent: Node, pos: Vector3, text: String, color: Color = Color.WHITE, size: float = 1.0) -> void:
	if not is_instance_valid(parent):
		return
	var l := Label3D.new()
	l.text = text
	l.font_size = int(72 * size)
	l.outline_size = int(20 * size)
	l.pixel_size = 0.012
	l.modulate = color
	l.outline_modulate = Color(0.05, 0.05, 0.1)
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.position = pos
	parent.add_child(l)
	var t := create_tween()
	t.tween_property(l, "position:y", pos.y + 1.6, 0.9).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(l, "modulate:a", 0.0, 0.5).set_delay(0.45)
	t.tween_callback(l.queue_free)


## One-shot particle burst in world space. Speed in metres per second.
func burst(parent: Node, pos: Vector3, color: Color, count: int = 16, speed: float = 5.0) -> void:
	if not is_instance_valid(parent):
		return
	var p := CPUParticles3D.new()
	p.position = pos
	p.amount = count
	p.one_shot = true
	p.explosiveness = 1.0
	p.lifetime = 0.55
	p.direction = Vector3.UP
	p.spread = 180.0
	p.initial_velocity_min = speed * 0.4
	p.initial_velocity_max = speed
	p.gravity = Vector3(0, -6.0, 0)
	p.damping_min = speed * 0.8
	p.damping_max = speed * 1.2
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.4
	p.color = color
	p.mesh = Mats.sphere(0.12)
	var pm := Mats.unlit(Color.WHITE)
	pm.vertex_color_use_as_albedo = true
	p.mesh.material = pm
	p.emitting = true
	parent.add_child(p)
	get_tree().create_timer(1.2).timeout.connect(p.queue_free)
