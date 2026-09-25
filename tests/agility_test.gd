extends Node
## Agility Park's two crossable props. The tunnel is a route end to end and the A-frame is a
## deck you run over — but both are still walls from the side, which is the only thing that
## makes taking the obstacle a choice rather than a detour nobody would bother with.
##   godot --headless --path . res://tests/agility_test.tscn

const DOG_SCENE := preload("res://scenes/actors/dog.tscn")
const TOY_SCENE := preload("res://scenes/actors/toy.tscn")

var _failed := false
var _arena: Arena


func _ready() -> void:
	Sfx.enabled = false
	Music.enabled = false
	var data: ArenaData
	for candidate in Game.arenas:
		if candidate.id == &"agility_park":
			data = candidate
	_check(data != null, "Agility Park is registered")
	if data == null:
		get_tree().quit(1)
		return
	_arena = data.scene.instantiate()
	add_child(_arena)
	await get_tree().physics_frame
	var tunnel := _prop("Tunnel")
	var ramp := _prop("AFrame")
	_check(tunnel != null and tunnel.kind == Obstacle.Kind.TUNNEL, "the park has a tunnel")
	_check(ramp != null and ramp.kind == Obstacle.Kind.RAMP, "the park has an A-frame")
	if tunnel == null or ramp == null:
		get_tree().quit(1)
		return

	_fits_the_widest_dog(tunnel, ramp)
	_the_deck_is_where_it_is_drawn(ramp)
	await _a_dog_runs_through_the_tunnel(tunnel)
	await _the_tunnel_wall_still_stops_you(tunnel)
	await _a_dog_runs_over_the_a_frame(ramp)
	await _the_rails_still_stop_you(ramp)
	await _a_toy_rides_the_deck(ramp)

	if not _failed:
		print("[agility] PASSED: the tube is a route, the A-frame is a deck, and both are still walls from the side")
	get_tree().quit(1 if _failed else 0)


func _prop(prop_name: String) -> Obstacle:
	for node in _arena.find_children(prop_name, "StaticBody3D", true, false):
		if node is Obstacle:
			return node
	return null


func _widest_dog() -> float:
	var widest := 0.0
	for dog_data in Game.dogs:
		widest = maxf(widest, dog_data.body_radius)
	return widest


## A route nobody fits through is just a wall with extra steps.
func _fits_the_widest_dog(tunnel: Obstacle, ramp: Obstacle) -> void:
	var span := _widest_dog() * 2.0 + 0.3
	_check(tunnel.size.z - Obstacle.WALL_THICKNESS * 2.0 > span, "the widest dog fits through the tube")
	_check(ramp.size.z - Obstacle.WALL_THICKNESS * 2.0 > span, "and between the A-frame rails")


## Terrain is what dogs and toys walk on; it has to agree with the ridge that is drawn.
func _the_deck_is_where_it_is_drawn(ramp: Obstacle) -> void:
	var ridge := Terrain.ground_height(_arena, ramp.global_position)
	_check(is_equal_approx(ridge, ramp.size.y), "the deck peaks at the ridge")
	var end_of_ramp := ramp.global_position + Vector3(ramp.size.x * 0.5, 0, 0)
	_check(is_zero_approx(Terrain.ground_height(_arena, end_of_ramp)), "and meets the ground at both ends")
	_check(is_zero_approx(Terrain.ground_height(_arena, Vector3.ZERO)), "the rest of the park is flat")


func _dog_at(at: Vector3, index: int = 0) -> Dog:
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


## Walk in one end, come out the other.
func _a_dog_runs_through_the_tunnel(tunnel: Obstacle) -> void:
	var half := tunnel.size.x * 0.5
	var entrance := tunnel.global_position + Vector3(-half - 1.4, 0, 0)
	var dog := _dog_at(entrance)
	dog.input.virtual_move = Vector2.RIGHT
	var went_inside := false
	for _frame in 140:
		await get_tree().physics_frame
		if absf(dog.global_position.x - tunnel.global_position.x) < half - 0.4:
			went_inside = true
	_check(went_inside, "a dog can get inside the tube")
	_check(dog.global_position.x > tunnel.global_position.x + half, "and comes out of the far end")
	_check(absf(dog.global_position.z - tunnel.global_position.z) < tunnel.size.z * 0.5,
		"without being squeezed out of the sides")
	dog.queue_free()
	await get_tree().process_frame


## The fabric is still solid: you take the tube end to end or you go around it.
func _the_tunnel_wall_still_stops_you(tunnel: Obstacle) -> void:
	var outside := tunnel.global_position + Vector3(0, 0, -tunnel.size.z * 0.5 - 1.6)
	var dog := _dog_at(outside)
	dog.input.virtual_move = Vector2.DOWN
	for _frame in 90:
		await get_tree().physics_frame
	_check(dog.global_position.z < tunnel.global_position.z - tunnel.size.z * 0.5,
		"walking into the side of the tube is blocked")
	dog.queue_free()
	await get_tree().process_frame


## Up one side and down the other, riding the deck the whole way.
func _a_dog_runs_over_the_a_frame(ramp: Obstacle) -> void:
	var half := ramp.size.x * 0.5
	var foot := ramp.global_position + Vector3(-half - 1.2, 0, 0)
	var dog := _dog_at(foot)
	dog.input.virtual_move = Vector2.RIGHT
	var peak := 0.0
	for _frame in 160:
		await get_tree().physics_frame
		peak = maxf(peak, dog.ground_y)
	_check(peak > ramp.size.y * 0.7, "a dog climbs the A-frame deck (reached %.2f m)" % peak)
	_check(dog.global_position.x > ramp.global_position.x + half, "and runs down the far side")
	_check(is_zero_approx(dog.ground_y), "ending back on the flat")
	dog.queue_free()
	await get_tree().process_frame


## Side rails: the climb only starts at an end, so the A-frame cannot be stepped onto halfway up.
func _the_rails_still_stop_you(ramp: Obstacle) -> void:
	var beside := ramp.global_position + Vector3(0, 0, -ramp.size.z * 0.5 - 1.6)
	var dog := _dog_at(beside)
	dog.input.virtual_move = Vector2.DOWN
	for _frame in 90:
		await get_tree().physics_frame
	_check(dog.global_position.z < ramp.global_position.z - ramp.size.z * 0.5,
		"walking into the side of the A-frame is blocked")
	_check(is_zero_approx(dog.ground_y), "and nothing lifts a dog that never got on the deck")
	dog.queue_free()
	await get_tree().process_frame


## Toys ride the deck too, so a throw up the A-frame still reaches the dog standing on it.
func _a_toy_rides_the_deck(ramp: Obstacle) -> void:
	var toy := TOY_SCENE.instantiate() as Toy
	toy.setup(Game.toys[0])
	toy.position = Vector3(ramp.global_position.x, Game.toys[0].radius, ramp.global_position.z)
	_arena.add_child(toy)
	for _frame in 60:
		await get_tree().physics_frame
	_check(toy.global_position.y > ramp.size.y * 0.8, "a toy left on the deck rests on the ramp, not under it")
	toy.queue_free()
	await get_tree().process_frame


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failed = true
		push_error("[agility] FAILED: " + message)
		printerr("[agility] FAILED: " + message)
