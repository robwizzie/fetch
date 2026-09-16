extends Node
## Real camera projection and deterministic framing/time-effect regression checks.
## godot --headless --path . res://tests/camera_test.tscn

var _failed := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Sfx.enabled = false
	await get_tree().process_frame
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	viewport.own_world_3d = true
	add_child(viewport)
	var camera := ArenaCamera.new()
	viewport.add_child(camera)
	camera.make_current()
	camera.set_process(false)
	var corners: Array[Vector3] = [
		Vector3(-12.8, 0, -7.1), Vector3(12.8, 2.4, -7.1),
		Vector3(12.8, 0, 7.1), Vector3(-12.8, 2.4, 7.1),
	]
	for viewport_size in [Vector2i(1280, 720), Vector2i(720, 1280), Vector2i(2560, 1080), Vector2i(640, 480)]:
		viewport.size = viewport_size
		await get_tree().process_frame
		var aspect := float(viewport_size.x) / float(viewport_size.y)
		var frame: Dictionary = camera._fit_points(corners, aspect)
		camera._target = frame.target
		camera.size = frame.size
		camera._place()
		_check(is_finite(camera.size) and camera.size > 0.0, "finite zoom at " + str(viewport_size))
		_check(camera._target.is_finite(), "finite target at " + str(viewport_size))
		for point in corners:
			_check(_visible(viewport, camera, point), "arena edge remains visible at " + str(viewport_size))
		var empty: Array[Vector3] = []
		var overview: Dictionary = camera._fit_points(empty, aspect)
		_check(is_finite(overview.size), "empty arena has a finite overview")
	viewport.size = Vector2i(1280, 720)
	await get_tree().process_frame
	var first := _dog(viewport, 0, Vector3(-12, 0, -6.5))
	var second := _dog(viewport, 1, Vector3(12, 0, 6.5))
	camera._update_framing(1.0 / 60.0)
	var wide := camera.size
	first.position = Vector3(3.0, 0, 0)
	second.position = Vector3(4.0, 0, 1)
	for step in 180:
		camera._update_framing(1.0 / 60.0)
	print("[camera] group zoom: %.2f -> %.2f, target=%s" % [wide, camera.size, camera._target])
	_check(camera.size < wide - 1.0, "camera closes in when dogs converge")
	_check(camera._target.x > 1.0, "camera follows group horizontally")
	_check(absf(camera.rotation.y) < 0.001, "camera keeps the movement heading fixed")
	first.position = Vector3(-12.0, 0, -6.5)
	second.position = Vector3(12.0, 0, 6.5)
	camera._update_framing(1.0 / 60.0)
	for point in camera._gather_points():
		_check(_visible(viewport, camera, point), "abruptly separating dogs remain visible")
	var toy: Toy = load("res://scenes/actors/toy.tscn").instantiate()
	toy.setup(Game.toys[0])
	viewport.add_child(toy)
	toy.set_physics_process(false)
	toy.state = Toy.State.FLYING
	toy.position = Vector3(-12.6, 0.7, 6.9)
	_check(camera._gather_points().has(toy.global_position), "airborne weapons are tracked")
	first.state = Dog.State.ELIMINATED
	Events.dog_eliminated.emit(first, toy)
	_check(camera._final_focus and camera._focus_left > 0.0, "last elimination gets an impact highlight")
	var final_deadline: float = Juice._slowmo_until
	Juice.elimination_slowmo(false)
	_check(Juice._slowmo_until >= final_deadline, "overlapping ordinary hit cannot shorten final slow motion")
	Juice._update_time_effects(Juice._hitstop_until + 0.01)
	_check(Engine.time_scale < 0.5 and Engine.time_scale > 0.1, "hit-stop releases into final-hit slow motion")
	Juice._update_time_effects(Juice._slowmo_until + 0.01)
	_check(is_equal_approx(Engine.time_scale, 1.0), "slow motion ends at normal speed")
	camera._update_framing(1.0)
	_check(camera._focus_left == 0.0, "impact focus expires in real time")
	Juice.elimination_slowmo(true)
	get_tree().paused = true
	await get_tree().process_frame
	await get_tree().process_frame
	_check(is_equal_approx(Engine.time_scale, 1.0), "pausing clears slow motion")
	get_tree().paused = false
	Juice.elimination_slowmo(true)
	Events.round_started.emit(2)
	_check(is_equal_approx(Engine.time_scale, 1.0) and camera._focus_left == 0.0, "new round clears old impact state")
	Juice.elimination_slowmo(true)
	viewport.queue_free()
	await get_tree().process_frame
	_check(is_equal_approx(Engine.time_scale, 1.0), "arena teardown restores normal game speed")
	if not _failed:
		print("[camera] PASSED: aspect-safe framing, group follow, weapons, final-hit timing, pause and teardown")
	get_tree().quit(1 if _failed else 0)


func _dog(parent: Node, index: int, at: Vector3) -> Dog:
	var slot := PlayerSlot.new()
	slot.index = index
	slot.device = DeviceInput.VIRTUAL
	slot.dog = Game.dogs[index]
	var dog: Dog = load("res://scenes/actors/dog.tscn").instantiate()
	dog.setup(slot)
	parent.add_child(dog)
	dog.position = at
	dog.set_physics_process(false)
	return dog


func _visible(viewport: SubViewport, camera: ArenaCamera, point: Vector3) -> bool:
	var projected := camera.unproject_position(point)
	return not camera.is_position_behind(point) and Rect2(Vector2.ZERO, Vector2(viewport.size)).has_point(projected)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failed = true
		push_error("[camera] FAILED: " + message)
