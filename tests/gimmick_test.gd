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
	await _holes()
	await _breakable_crate()
	await _swing_board()
	await _stranded_toy()
	if not _failed:
		print("[gimmicks] PASSED: sprinkler shoves, mower knocks dizzy, grass hides, dog beds slide, one per arena, holes, crates that break, swing boards, stranded toys come back")
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


## Walk up to a hole and you stop at the rim; get whacked in and you are out, credited to the
## whacker; dash and you hop it.
func _holes() -> void:
	await _new_arena()
	var hole := Pit.new()
	_arena.add_child(hole)
	var walker := _dog(Vector3(hole.radius - 0.2, 0, 0))
	walker.set_physics_process(false)
	hole._handle_dog(walker)
	_check(walker.alive, "walking into a hole stops at the rim")
	_check(Vector2(walker.global_position.x, walker.global_position.z).length() >= hole.radius - 0.01, "and puts you back on the edge")
	var whacker := _dog(Vector3(4, 0, 0), 1)
	whacker.set_physics_process(false)
	walker.receive_whack(Vector3(-1, 0, 0), whacker)
	walker.global_position = Vector3(0.3, 0, 0)
	hole._handle_dog(walker)
	_check(not walker.alive, "knocked into a hole is a knockout")
	_check(walker.knocked_out_by(null) == whacker, "credited to whoever knocked you in")
	var dasher := _dog(Vector3(0.2, 0, 0.1), 2)
	dasher.set_physics_process(false)
	dasher._dash_timer = 0.2
	hole._handle_dog(dasher)
	_check(dasher.alive, "a dash hops over a hole")


## Toys wear a crate down and it splinters - a charged throw counts double - and it is back
## for the next round.
func _breakable_crate() -> void:
	await _new_arena()
	var crate := Obstacle.new()
	crate.kind = Obstacle.Kind.CRATE
	crate.breakable = true
	crate.toughness = 3
	_arena.add_child(crate)
	await get_tree().physics_frame
	crate.take_hit(Vector3(8, 0, 0))
	_check(not crate._broken, "one soft hit dents a crate")
	crate.take_hit(Vector3(18, 0, 0))
	_check(crate._broken, "a wound-up hit counts double and finishes it")
	await get_tree().physics_frame
	var solid := false
	for shape in crate._shapes:
		solid = solid or not shape.disabled
	_check(not solid, "a broken crate is open ground")
	crate.reset_for_round()
	await get_tree().physics_frame
	solid = false
	for shape in crate._shapes:
		solid = solid or not shape.disabled
	_check(not crate._broken and solid, "and it is whole again next round")


func _swing_board() -> void:
	await _new_arena()
	var board := SwingBoard.new()
	_arena.add_child(board)
	var before := board.rotation_degrees.y
	board.toggle()
	await get_tree().create_timer(SwingBoard.TURN_TIME + 0.15).timeout
	_check(absf(board.rotation_degrees.y - before - board.swing) < 1.0, "a switch swings the board a quarter turn")
	board.reset_for_round()
	_check(is_equal_approx(board.rotation_degrees.y, before), "and it starts each round where it was built")


## Backyard's hedge leaves a gap to the fence narrower than a dog. A toy that settles in it comes
## back out rather than being lost to the round.
func _stranded_toy() -> void:
	if is_instance_valid(_arena):
		_arena.queue_free()
		_arena = null
	Game.tutorial_shown = true
	Game.random_arena_each_round = false
	for arena_data in Game.arenas:
		if arena_data.id == &"backyard":
			Game.selected_arena = arena_data
	Game.debug_fill_players(2)
	var game_match: Node = load("res://scenes/match/match.tscn").instantiate()
	add_child(game_match)
	while game_match.phase != game_match.Phase.PLAYING:
		await get_tree().process_frame
	var toy: Toy = game_match.toys[0]
	toy.set_physics_process(false)
	toy.state = Toy.State.IDLE
	toy.velocity = Vector3.ZERO
	toy.global_position = Vector3(12.4, toy.global_position.y, -0.9)
	await get_tree().create_timer(0.8).timeout
	var biggest := 0.0
	for dog in game_match.dogs:
		biggest = maxf(biggest, dog.effective_radius())
	_check(game_match._reachable(toy.global_position, biggest, biggest + toy.data.radius + 0.1), "a toy wedged behind the hedge comes back out where dogs can reach it")
	game_match.queue_free()
	await get_tree().process_frame


func _check(ok: bool, message: String) -> void:
	if not ok:
		_failed = true
		push_error("[gimmicks] FAILED: " + message)
