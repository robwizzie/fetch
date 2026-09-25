class_name HotPotato
extends LastDogStanding
## Hot Potato Bone: normal rules, plus one toy is the hot bone. Its fuse runs down while it is in
## play, and when it pops, whoever is holding it - or whoever held it last - is out. Then a new
## fuse starts. Passing it on means throwing it, and a throw is still a throw.

const FUSE_MIN := 11.0
const FUSE_MAX := 18.0
## The countdown shows, and ticks faster, over the last few seconds.
const SHOW_COUNTDOWN := 5.0

var hot: Toy
var fuse := 0.0
var last_holder: Dog
var _marker: Node3D
var _count: Label3D
var _tick_clock := 0.0
var _rng := RandomNumberGenerator.new()


func on_round_start(_dogs: Array[Dog]) -> void:
	_rng.randomize()
	if is_instance_valid(_marker):
		_marker.queue_free()
	hot = null
	last_holder = null
	if game_match.toys.is_empty():
		return
	hot = game_match.toys[0]
	fuse = _rng.randf_range(FUSE_MIN, FUSE_MAX)
	_build_marker()


func _build_marker() -> void:
	_marker = Node3D.new()
	_marker.name = "HotBoneMarker"
	game_match.actors.add_child(_marker)
	var glow := Mats.mesh(_marker, Mats.torus(0.42, 0.5), Color("ff6a3d"))
	glow.material_override = Mats.unlit(Color(1.0, 0.42, 0.2, 0.85))
	glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var flame := Mats.mesh(_marker, Mats.sphere(0.12), Color("ffcf5a"), Vector3(0, 0.62, 0))
	flame.material_override = Mats.unlit(Color("ffcf5a"))
	_count = Label3D.new()
	_count.font = UiKit.FONT_DISPLAY
	_count.font_size = 96
	_count.outline_size = 24
	_count.pixel_size = 0.008
	_count.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_count.no_depth_test = true
	_count.modulate = Color("ffcf5a")
	_count.outline_modulate = Color(0.2, 0.05, 0.02)
	_count.position = Vector3(0, 1.3, 0)
	_marker.add_child(_count)


func tick(delta: float, dogs: Array[Dog]) -> void:
	if not is_instance_valid(hot):
		return
	if is_instance_valid(hot.holder):
		last_holder = hot.holder
	fuse -= delta
	var at := hot.global_position
	_marker.global_position = Vector3(at.x, 0.05 if hot.state != Toy.State.HELD else 1.6, at.z)
	_marker.rotation.y += delta * (3.0 + (SHOW_COUNTDOWN - fuse) * 1.5)
	_count.visible = fuse <= SHOW_COUNTDOWN
	_count.text = str(ceili(maxf(fuse, 0.0)))
	if fuse <= SHOW_COUNTDOWN:
		_tick_clock -= delta
		if _tick_clock <= 0.0:
			_tick_clock = clampf(fuse / SHOW_COUNTDOWN, 0.15, 1.0) * 0.6
			Sfx.play_at("tick", at, 1.3 + (1.0 - fuse / SHOW_COUNTDOWN) * 0.6, -3.0)
	if fuse <= 0.0:
		_pop(dogs)


func _pop(dogs: Array[Dog]) -> void:
	var victim := hot.holder if is_instance_valid(hot.holder) else last_holder
	if not is_instance_valid(victim) or not victim.alive:
		# Nobody has touched it: the dog nearest the bone is "it".
		var best := INF
		for dog in dogs:
			if dog.alive and dog.global_position.distance_to(hot.global_position) < best:
				best = dog.global_position.distance_to(hot.global_position)
				victim = dog
	Juice.burst(game_match.actors, hot.global_position + Vector3.UP * 0.6, Color("ff8a3d"), 26, 7.0)
	Juice.float_text(game_match.actors, hot.global_position + Vector3.UP * 2.0, "HOT!", Color("ff8a3d"), 1.1)
	Sfx.play_at("blast", hot.global_position)
	fuse = _rng.randf_range(FUSE_MIN, FUSE_MAX)
	last_holder = null
	if is_instance_valid(victim) and victim.alive:
		victim.eliminate(hot)


func bot_should_throw_now(_dog: Dog, toy: Toy) -> bool:
	return toy == hot and fuse < 6.0


func hud_hint() -> String:
	return "Don't be holding the hot bone when it pops · Last dog standing wins"
