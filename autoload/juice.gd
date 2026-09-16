extends Node
## "Game feel" helpers: camera shake, hit-stop, pop/squash tweens, floating text, particle bursts.
## Everything is one call so gameplay code stays readable: Juice.shake(0.2), Juice.hitstop().

var _shake_amount := 0.0
var _shake_decay := 10.0
var _hitstop_until := 0.0
var _hitstop_scale := 0.06
var _slowmo_until := 0.0
var _slowmo_duration := 0.0
var _slowmo_scale := 0.35
var _owns_time_scale := false
var _last_tick := 0
var _scene_id := 0
var _shake_camera: Camera3D


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_last_tick = Time.get_ticks_usec()


func _process(_delta: float) -> void:
	var tick := Time.get_ticks_usec()
	var delta := clampf(float(tick - _last_tick) / 1000000.0, 0.0, 0.05)
	_last_tick = tick
	var scene := get_tree().current_scene
	var current_id := scene.get_instance_id() if is_instance_valid(scene) else 0
	if get_tree().paused or current_id != _scene_id:
		reset_time_effects()
	_scene_id = current_id
	_update_time_effects(float(tick) / 1000000.0)
	var cam := get_viewport().get_camera_3d()
	if cam != _shake_camera and is_instance_valid(_shake_camera):
		_shake_camera.h_offset = 0.0
		_shake_camera.v_offset = 0.0
	_shake_camera = cam
	if cam == null:
		_shake_amount = 0.0
		return
	if _shake_amount > 0.002:
		cam.h_offset = randf_range(-1.0, 1.0) * _shake_amount
		cam.v_offset = randf_range(-1.0, 1.0) * _shake_amount
		_shake_amount *= exp(-_shake_decay * delta)
	elif cam.h_offset != 0.0 or cam.v_offset != 0.0:
		cam.h_offset = 0.0
		cam.v_offset = 0.0
		_shake_amount = 0.0


## Amount is in metres of camera offset; 0.3 is a solid hit.
func shake(amount: float = 0.2) -> void:
	_shake_amount = maxf(_shake_amount, amount)


## Freezes the game for a few milliseconds on impactful hits. Safe to call without await.
func hitstop(duration: float = 0.055, time_scale: float = 0.06) -> void:
	var now := float(Time.get_ticks_usec()) / 1000000.0
	_hitstop_until = maxf(_hitstop_until, now + clampf(duration, 0.0, 0.15))
	_hitstop_scale = clampf(time_scale, 0.01, 1.0)
	_owns_time_scale = true
	_update_time_effects(now)


## Hit-stop takes priority then releases into slow motion. Overlapping KOs cannot
## prematurely reset the game speed, and all deadlines use unscaled real time.
func elimination_slowmo(final_hit: bool = false) -> void:
	var now := float(Time.get_ticks_usec()) / 1000000.0
	var duration := 0.72 if final_hit else 0.25
	if now + duration >= _slowmo_until:
		_slowmo_until = now + duration
		_slowmo_duration = duration
		_slowmo_scale = 0.23 if final_hit else 0.45
	hitstop(0.065 if final_hit else 0.045)


func _update_time_effects(now: float) -> void:
	if not _owns_time_scale:
		return
	if now < _hitstop_until:
		Engine.time_scale = _hitstop_scale
	elif now < _slowmo_until:
		var remaining := (_slowmo_until - now) / maxf(_slowmo_duration, 0.001)
		Engine.time_scale = lerpf(1.0, _slowmo_scale, smoothstep(0.0, 0.55, remaining))
	else:
		Engine.time_scale = 1.0
		_owns_time_scale = false


## No pending timer can restore an obsolete time scale after restart or menu exit.
func reset_time_effects() -> void:
	_hitstop_until = 0.0
	_slowmo_until = 0.0
	_owns_time_scale = false
	Engine.time_scale = 1.0
	_shake_amount = 0.0
	if is_instance_valid(_shake_camera):
		_shake_camera.h_offset = 0.0
		_shake_camera.v_offset = 0.0


func _exit_tree() -> void:
	Engine.time_scale = 1.0


## Scales a node up then eases it back to its base scale. Works for Node3D and Control.
func pop(node: Node, amount: float = 1.3, time: float = 0.18) -> void:
	if not is_instance_valid(node):
		return
	var base: Variant = node.scale
	node.scale = base * amount
	var t := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_STOP)
	t.tween_property(node, "scale", base, time).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Spawns a rising, fading billboard label in world space ("BONK!", "CATCH!").
func float_text(parent: Node, pos: Vector3, text: String, color: Color = Color.WHITE, size: float = 1.0) -> void:
	if not is_instance_valid(parent):
		return
	var l := Label3D.new()
	l.text = text
	l.font = UiKit.FONT_DISPLAY
	l.font_size = int(72 * size)
	l.outline_size = int(20 * size)
	l.pixel_size = 0.012
	l.modulate = color
	l.outline_modulate = Color(0.05, 0.05, 0.1)
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.position = pos
	parent.add_child(l)
	var t := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_STOP)
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
	get_tree().create_timer(1.2, false).timeout.connect(p.queue_free)
