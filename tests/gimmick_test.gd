extends Node
## One dog-themed gimmick per arena: the sprinkler, the robot mower, tall grass, sliding dog beds,
## the frozen pond's ice, the kitchen's conveyor belts and the toy room's train.
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
	await _dig_rules()
	await _ice()
	await _conveyor()
	await _toy_train()
	if not _failed:
		print("[gimmicks] PASSED: sprinkler shoves, mower knocks dizzy, grass hides, dog beds slide, one per arena, holes, crates that break, swing boards, stranded toys come back, digging under props and never up inside one, ice, conveyor belts, the toy train")
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


## Dig!: under anything in the way, never up inside it, never off the map, never for long.
func _dig_rules() -> void:
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
	var arena: Arena = game_match.arena
	var digger: Dog = game_match.dogs[0]
	var other: Dog = game_match.dogs[1]
	other.set_physics_process(false)
	other.global_position = Vector3(10, 0, 5)
	digger.input = DeviceInput.new(DeviceInput.VIRTUAL)
	digger.slot.powerups.assign([PowerupKinds.DIG])
	digger.apply_powerups()

	# Straight at the west crate (centre -3.2, -4.8; 1.7 wide): under it and out the far side.
	digger.global_position = Vector3(-6.2, 0, -4.8)
	digger.facing = Vector3.RIGHT
	digger._dash_cooldown = 0.0
	digger._start_dash()
	_check(digger.is_burrowed() and digger.collision_mask == 0, "a digging dog leaves the props behind")
	var frames := 0
	while digger.is_burrowed() and frames < 200:
		await get_tree().physics_frame
		frames += 1
	_check(digger.global_position.x > -3.2 + 0.85, "it tunnels under a crate and comes out the far side")
	_check(arena.is_clear_position(digger.global_position, digger.effective_radius()), "and comes up on open ground")
	var limit := Dog.DASH_TIME * Dog.DIG_TIME_SCALE + Dog.DIG_OVERRUN_MAX + 0.1
	_check(frames / float(Engine.physics_ticks_per_second) <= limit, "and is never under for long (%.2fs)" % (frames / float(Engine.physics_ticks_per_second)))
	_check(not digger.dash_ready() and digger._dash_cooldown >= Dog.DIG_SURFACE_REST - 0.05, "and has to stay up a moment before digging again")
	_check(digger.collision_mask != 0, "and is solid again")

	# Ending a dig right inside a crate: up beside it instead.
	digger._dash_cooldown = 0.0
	digger.global_position = Vector3(3.2, 0, 4.8)
	digger.facing = Vector3.LEFT
	digger._start_dash()
	digger.global_position = Vector3(3.2, 0, 4.8)
	digger._surface()
	_check(arena.is_clear_position(digger.global_position, digger.effective_radius()), "a dig that ends inside a crate comes up beside it")

	# Ending over a hole: up on solid ground, not down it.
	digger._dash_cooldown = 0.0
	digger._start_dash()
	digger.global_position = Vector3(3.4, 0, -4.6)
	digger._surface()
	_check(digger.alive, "a dig that ends over a hole comes up on the rim, not in it")

	# Straight at the fence: the map edge stops it underground too.
	digger._dash_cooldown = 0.0
	digger.global_position = Vector3(11.0, 0, -5.5)
	digger.facing = Vector3.RIGHT
	digger._start_dash()
	frames = 0
	while digger.is_burrowed() and frames < 200:
		await get_tree().physics_frame
		frames += 1
	_check(digger.global_position.x < arena.size.x * 0.5, "nobody digs out of the arena")
	game_match.queue_free()
	await get_tree().process_frame


## Ice takes a dog's grip and gives it back the moment it steps off; it never undoes a slow,
## and a whack on the ice carries further than one on the snow. Open water is still a hole.
func _ice() -> void:
	await _new_arena()
	var sheet := IceSheet.new()
	sheet.size = Vector2(8, 6)
	_arena.add_child(sheet)
	var pool := SlowZone.new()
	pool.radius = 1.0
	pool.position = Vector3(20, 0, 0)
	_arena.add_child(pool)
	var dog := _dog(Vector3(0, 0, 0))
	await get_tree().physics_frame
	await get_tree().physics_frame
	_check(is_equal_approx(dog.traction, sheet.traction), "a dog on the ice loses its grip (%.2f)" % dog.traction)
	dog.set_slow(pool, 0.5)
	_check(is_equal_approx(dog.speed_scale, 0.5) and dog.traction < 1.0, "ice and a slow stack rather than replace each other")
	# Same input, same time: the dog on ice has picked up far less speed.
	dog.velocity = Vector3.ZERO
	dog.clear_slow(pool)
	dog.input.virtual_move = Vector2.RIGHT
	for i in 6:
		await get_tree().physics_frame
	var icy_speed := dog.velocity.length()
	dog.input.virtual_move = Vector2.ZERO
	dog.global_position = Vector3(10, 0, 0)
	await get_tree().physics_frame
	await get_tree().physics_frame
	_check(is_equal_approx(dog.traction, 1.0), "stepping off the ice gives the grip straight back")
	dog.velocity = Vector3.ZERO
	dog.input.virtual_move = Vector2.RIGHT
	for i in 6:
		await get_tree().physics_frame
	_check(icy_speed < dog.velocity.length() * 0.6, "on ice a dog gets going slowly (%.1f vs %.1f m/s)" % [icy_speed, dog.velocity.length()])
	dog.input.virtual_move = Vector2.ZERO
	# Let go of the stick at speed: on the snow it stops dead, on the ice it slides on.
	dog.global_position = Vector3(-2, 0, 0)
	await get_tree().physics_frame
	await get_tree().physics_frame
	dog.velocity = Vector3.RIGHT * 6.0
	for i in 12:
		await get_tree().physics_frame
	_check(dog.velocity.length() > 2.0, "and keeps sliding when it lets go (%.1f m/s)" % dog.velocity.length())
	sheet.queue_free()
	await get_tree().physics_frame
	_check(is_equal_approx(dog.traction, 1.0), "an ice sheet that goes away takes its slip with it")
	var water := Pit.new()
	water.look = Pit.Look.WATER
	water.position = Vector3(-10, 0, 0)
	_arena.add_child(water)
	var swimmer := _dog(Vector3(-10.3, 0, 0), 1)
	swimmer.set_physics_process(false)
	swimmer.receive_whack(Vector3(1, 0, 0), dog)
	water._handle_dog(swimmer)
	_check(not swimmer.alive and swimmer.knocked_out_by(null) == dog, "knocked into open water is a knockout, credited to the whacker")


## A belt carries a loose toy and a dog standing still; a dog can still walk against it.
func _conveyor() -> void:
	await _new_arena()
	var belt := Conveyor.new()
	belt.length = 10.0
	# Wide enough to keep the three apart, so nobody picks the toy up on the way.
	belt.width = 3.4
	_arena.add_child(belt)
	var toy := TOY_SCENE.instantiate() as Toy
	toy.setup(Game.toys[0])
	toy.position = Vector3(-3, 0, -1.4)
	_arena.add_child(toy)
	toy.state = Toy.State.IDLE
	var rider := _dog(Vector3(-2, 0, 0))
	var walker := _dog(Vector3(3, 0, 1.3), 1)
	walker.input.virtual_move = Vector2.LEFT
	await get_tree().create_timer(0.5).timeout
	_check(toy.global_position.x > -2.2, "a loose toy rides the belt (%.2f m)" % (toy.global_position.x + 3.0))
	_check(rider.global_position.x > -1.0, "a dog standing on it is carried along (%.2f m)" % (rider.global_position.x + 2.0))
	_check(walker.global_position.x < 2.5, "a dog walking against it still gets somewhere (%.2f m)" % (3.0 - walker.global_position.x))
	# Ride it into a wall: the wall wins.
	var wall := Obstacle.new()
	wall.size = Vector3(1, 1.2, 3)
	wall.position = Vector3(4, 0, 0)
	_arena.add_child(wall)
	walker.input.virtual_move = Vector2.ZERO
	rider.global_position = Vector3(2.5, 0, 0)
	await get_tree().create_timer(1.0).timeout
	_check(rider.global_position.x < 3.5 - rider.effective_radius() + 0.05, "a belt never pushes a dog through a wall (x %.2f)" % rider.global_position.x)


## The train laps its loop, bounces a throw off a car, bumps a dog clear and starts each round
## where it was built.
func _toy_train() -> void:
	await _new_arena()
	var train := ToyTrain.new()
	_arena.add_child(train)
	await get_tree().physics_frame
	var start := train.engine_position()
	await get_tree().create_timer(0.5).timeout
	_check(train.engine_position().distance_to(start) > 1.0, "the train runs round its track")
	# Freeze it mid-lap and throw straight at a car.
	train.set_physics_process(false)
	var car := train.cars()[1]
	var thrower := _dog(Vector3(car.global_position.x, 0, car.global_position.z + 6.0))
	thrower.set_physics_process(false)
	var toy := TOY_SCENE.instantiate() as Toy
	toy.setup(Game.toys[0])
	toy.position = car.global_position + Vector3(0, Toy.FLY_HEIGHT, 3.0)
	_arena.add_child(toy)
	toy.set_physics_process(false)
	toy.state = Toy.State.FLYING
	toy.thrower = thrower
	toy.velocity = Vector3(0, 0, -18.0)
	await get_tree().physics_frame
	toy._slide(0.25)
	_check(toy.velocity.z > 0.0, "a throw bounces off a passing car")
	_check(toy.global_position.z > car.global_position.z, "and never goes through it")
	# A dog standing on the rails is bumped to the side the train is not.
	train.set_physics_process(true)
	var ahead := train.point_at(train.distance + 1.6)
	var stander := _dog(train.to_global(ahead.origin) + ahead.basis.z * 0.15, 1)
	var before := stander.global_position
	var clear := false
	for i in 90:
		await get_tree().physics_frame
		if not train.near_track(stander.global_position, ToyTrain.CAR.z * 0.5 + stander.effective_radius() - 0.05):
			clear = true
	_check(clear and stander.alive, "a dog on the track is bumped clear, not hurt")
	_check(stander.global_position.distance_to(before) < 4.0, "and only nudged aside, not flung")
	train.reset_for_round()
	var home := train.to_global(train.point_at(train.start_distance).origin)
	_check(train.engine_position().distance_to(home) < 0.01, "the train is back at the start each round")


func _check(ok: bool, message: String) -> void:
	if not ok:
		_failed = true
		push_error("[gimmicks] FAILED: " + message)
