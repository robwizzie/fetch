extends Node
## "Game feel" helpers: camera shake, hit-stop, pop/squash tweens, floating text, particle bursts.
## Everything is one call so gameplay code stays readable: Juice.shake(10), Juice.hitstop().

var _shake_amount := 0.0
var _shake_decay := 7.0
var _hitstop_active := false


func _process(delta: float) -> void:
	var cam := get_viewport().get_camera_2d()
	if cam == null:
		return
	if _shake_amount > 0.05:
		cam.offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * _shake_amount
		_shake_amount = lerpf(_shake_amount, 0.0, minf(1.0, _shake_decay * delta))
	elif cam.offset != Vector2.ZERO:
		cam.offset = Vector2.ZERO
		_shake_amount = 0.0


func shake(amount: float = 8.0) -> void:
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


## Scales a node up then eases it back to 1. Works for Node2D and Control.
func pop(node: Node, amount: float = 1.3, time: float = 0.18) -> void:
	if not is_instance_valid(node):
		return
	node.scale = Vector2.ONE * amount
	var t := create_tween()
	t.tween_property(node, "scale", Vector2.ONE, time).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Cartoon squash & stretch, e.g. on throw or landing.
func squash(node: Node, squash_scale: Vector2 = Vector2(1.25, 0.75), time: float = 0.2) -> void:
	if not is_instance_valid(node):
		return
	node.scale = squash_scale
	var t := create_tween()
	t.tween_property(node, "scale", Vector2.ONE, time).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


## Spawns a rising, fading label in world space ("BONK!", "CATCH!").
func float_text(parent: Node, pos: Vector2, text: String, color: Color = Color.WHITE, size: int = 48) -> void:
	if not is_instance_valid(parent):
		return
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0.05, 0.05, 0.1))
	l.add_theme_constant_override("outline_size", 10)
	l.position = pos
	l.rotation = randf_range(-0.18, 0.18)
	l.z_index = 100
	parent.add_child(l)
	var t := create_tween()
	t.tween_property(l, "position:y", pos.y - 90.0, 0.9).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(l, "modulate:a", 0.0, 0.5).set_delay(0.45)
	t.tween_callback(l.queue_free)


## One-shot particle burst in world space.
func burst(parent: Node, pos: Vector2, color: Color, count: int = 16, speed: float = 320.0) -> void:
	if not is_instance_valid(parent):
		return
	var p := CPUParticles2D.new()
	p.position = pos
	p.amount = count
	p.one_shot = true
	p.explosiveness = 1.0
	p.lifetime = 0.55
	p.direction = Vector2.RIGHT
	p.spread = 180.0
	p.initial_velocity_min = speed * 0.4
	p.initial_velocity_max = speed
	p.gravity = Vector2.ZERO
	p.damping_min = speed * 1.5
	p.damping_max = speed * 2.0
	p.scale_amount_min = 4.0
	p.scale_amount_max = 9.0
	p.color = color
	p.z_index = 50
	p.emitting = true
	parent.add_child(p)
	get_tree().create_timer(1.2).timeout.connect(p.queue_free)
