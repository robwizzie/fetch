extends Node
## One dog-themed gimmick per arena: the sprinkler, the robot mower, tall grass, sliding dog beds.
##   godot --headless --path . res://tests/gimmick_test.tscn

const DOG_SCENE := preload("res://scenes/actors/dog.tscn")
const TOY_SCENE := preload("res://scenes/actors/toy.tscn")
var _failed := false
var _arena: Node3D


func _ready() -> void:
	Sfx.enabled = false
	await _sprinkler()
	await _mower()
	await _grass()
	await _dog_bed()
	await _every_arena_has_one()
	if not _failed:
		print("[gimmicks] PASSED: sprinkler shoves, mower knocks dizzy, grass hides, dog beds slide, one per arena")
	get_tree().quit(1 if _failed else 0)


func _new_arena() -> void:
	if is_instance_valid(_arena):
		_arena.queue_free()
		await get_tree().process_frame
	_arena = Node3D.new()
	add_child(_arena)
	await get_tree().physics_frame


func _dog(at: Vector3, index: int = 0) -> Dog:
	var slot := PlayerSlot.new()
	slot.index = index
	slot.device = DeviceInput.VIRTUAL
	slot.dog = Game.dogs[index % Game.dogs.size()]
	var dog := DOG_SCENE.instantiate() as Dog
	dog.setup(slot)
	dog.position = at
	_arena.add_child(dog)
	dog._spawn_grace = 0.0
	return dog


func _sprinkler() -> void:
	await _new_arena()
	var sprinkler := Sprinkler.new()
	_arena.add_child(sprinkler)
	sprinkler.set_physics_process(false)
	sprinkler.angle = 0.0
	var dog := _dog(Vector3(0, 0, -3.0))
	dog.set_physics_process(false)
	await get_tree().physics_frame
	sprinkler._physics_process(0.0)
	_check(dog._weapon_impulse.z < -1.0, "the jet shoves a dog along it")
	_check(dog.alive and dog.dizzy_time <= 0.0, "and never hurts or dizzies it")
	var dry := _dog(Vector3(3.0, 0, 0), 1)
	dry.set_physics_process(false)
	sprinkler._physics_process(0.0)
	_check(dry._weapon_impulse.is_zero_approx(), "a dog out of the jet stays dry")


func _mower() -> void:
	await _new_arena()
	var mower := RobotMower.new()
	mower.half_width = 8.0
	_arena.add_child(mower)
	var dog := _dog(Vector3(0, 0, 0.3))
	dog.set_physics_process(false)
	mower.phase = RobotMower.Phase.WARNING
	mower._timer = 0.05
	var dizzied := false
	for i in 200:
		await get_tree().physics_frame
		if dog.dizzy_time > 0.0:
			dizzied = true
			break
	_check(dizzied, "the mower knocks an empty-pawed dog dizzy")
	_check(dog.alive, "and never knocks it out")
	for i in 400:
		await get_tree().physics_frame
		if mower.phase == RobotMower.Phase.RESTING:
			break
	_check(mower.phase == RobotMower.Phase.RESTING and absf(mower.mower_position().x) > 8.0, "it finishes its run and parks off the field")


func _grass() -> void:
	await _new_arena()
	var grass := TallGrass.new()
	_arena.add_child(grass)
	var dog := _dog(Vector3(0.3, 0, 0))
	dog.set_physics_process(false)
	var toy := TOY_SCENE.instantiate() as Toy
	toy.setup(Game.toys[0])
	_arena.add_child(toy)
	toy.pick_up(dog)
	for i in 4:
		await get_tree().physics_frame
	_check(dog.concealed and not dog.model.visible and not dog.ring.visible, "a dog in tall grass disappears")
	_check(not toy.model.visible, "and so does the toy in its mouth")
	dog.facing = Vector3.RIGHT
	dog._throw()
	await get_tree().process_frame
	_check(not dog.concealed and dog.model.visible, "throwing from cover gives you away")
	dog.global_position = Vector3(6, 0, 0)
	await get_tree().create_timer(Dog.REVEAL_TIME + 0.1).timeout
	_check(not dog.concealed, "out of the grass, a dog is seen")


func _dog_bed() -> void:
	await _new_arena()
	var bed := DogBed.new()
	_arena.add_child(bed)
	var thrower := _dog(Vector3(-8, 0, 3))
	thrower.set_physics_process(false)
	var toy := TOY_SCENE.instantiate() as Toy
	toy.setup(Game.toys[0])
	toy.position = Vector3(-3, Toy.FLY_HEIGHT, 0)
	_arena.add_child(toy)
	toy.set_physics_process(false)
	toy.state = Toy.State.FLYING
	toy.thrower = thrower
	toy.velocity = Vector3.RIGHT * 18.0
	await get_tree().physics_frame
	toy._slide(0.2)
	for i in 30:
		await get_tree().physics_frame
	_check(bed.global_position.x > 0.3, "a thrown toy sends the dog bed sliding (%.2f m)" % bed.global_position.x)
	_check(toy.velocity.x < 0.0, "and the toy bounces off it")


func _every_arena_has_one() -> void:
	for data in Game.arenas:
		var arena: Node = data.scene.instantiate()
		add_child(arena)
		await get_tree().physics_frame
		var found := not arena.find_children("*", "Portal", true, false).is_empty()
		for node in get_tree().get_nodes_in_group("gimmicks"):
			if arena.is_ancestor_of(node):
				found = true
		_check(found, "%s has its gimmick" % data.display_name)
		arena.queue_free()
		await get_tree().process_frame


func _check(ok: bool, message: String) -> void:
	if not ok:
		_failed = true
		push_error("[gimmicks] FAILED: " + message)
