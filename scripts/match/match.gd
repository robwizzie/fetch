extends Node
## Runs one match: brief countdowns, bounded rounds, pause, and an immediate rematch loop.

enum Phase { COUNTDOWN, PLAYING, ROUND_OVER, MATCH_OVER }

const DOG_SCENE := preload("res://scenes/actors/dog.tscn")
const TOY_SCENE := preload("res://scenes/actors/toy.tscn")
## Crates arrive late in the first round of the first match and steadily sooner after that:
## new players get a clean fight to learn on, experienced ones get the toys early.
const TREAT_FIRST_DELAY := 26.0
const TREAT_REPEAT_DELAY := 15.0
const TREAT_MIN_DELAY := 7.0
## How much each played round and each finished match pulls the timer forward.
const TREAT_ROUND_RUSH := 3.5
const TREAT_MATCH_RUSH := 2.5
const MAX_TREATS_PER_ROUND := 3
const ROUND_SECONDS := 55.0
## No toy starts within this many metres of any dog's spawn: the opening move is a decision,
## not a free pickup. Relaxed in steps only if an arena leaves nowhere else to put one.
const MIN_TOY_SPAWN_DISTANCE := 5.0

var arena: Arena
var arena_data: ArenaData
var dogs: Array[Dog] = []
var toys: Array[Toy] = []
var mode: GameMode
var phase := Phase.COUNTDOWN
var round_number := 0
var round_time_left := ROUND_SECONDS
var _round_winner: PlayerSlot
var _treat_clock := TREAT_FIRST_DELAY
var _treat_count := 0
var _result_delay := 0.0
var _result_text := ""
var _result_color := Color.WHITE

@onready var arena_holder: Node3D = $ArenaHolder
@onready var actors: Node3D = $Actors
@onready var hud: Hud = $HUD


func _ready() -> void:
	# The match can hear pause while its simulation and countdown are suspended.
	process_mode = Node.PROCESS_MODE_ALWAYS
	arena_holder.process_mode = Node.PROCESS_MODE_PAUSABLE
	hud.process_mode = Node.PROCESS_MODE_PAUSABLE
	if Game.slots.is_empty():
		Game.debug_fill_players(2)
	mode = Game.selected_mode.mode_script.new()
	mode.setup(self)
	_install_arena(Game.random_arena() if Game.random_arena_each_round else Game.selected_arena)
	hud.setup(Game.slots, mode.hud_hint())
	hud.resume_requested.connect(func() -> void: set_paused(false))
	hud.quit_requested.connect(_return_to_menu)
	hud.countdown_finished.connect(_begin_play)
	hud.banner_finished.connect(_finish_round)
	Events.dog_eliminated.connect(_on_dog_eliminated)
	Music.play("match")
	start_round()


func _physics_process(delta: float) -> void:
	if get_tree().paused or phase != Phase.PLAYING:
		return
	# Safety net: a toy that somehow leaves the arena comes back to a toy spawn.
	for toy in toys:
		if toy.state != Toy.State.HELD and arena.is_outside(toy.global_position):
			toy.drop(arena.get_toy_spawn_position(0))
	if Game.powerups_enabled and round_number >= 2:
		_treat_clock -= delta
		if _treat_clock <= 0.0 and _treat_count < MAX_TREATS_PER_ROUND:
			_spawn_treat()
			_treat_clock = _treat_delay(false)
	round_time_left = maxf(0.0, round_time_left - delta)
	hud.update_match(dogs, round_time_left, round_number)
	if round_time_left <= 0.0:
		phase = Phase.ROUND_OVER
		_end_round(null, "Time's up! Draw — no points")


func _process(delta: float) -> void:
	if get_tree().paused or _result_delay <= 0.0:
		return
	_result_delay -= delta / maxf(Engine.time_scale, 0.001)
	if _result_delay <= 0.0:
		hud.banner(_result_text, _result_color, 1.65)


func _unhandled_input(event: InputEvent) -> void:
	if DeviceInput.is_pause_event(event):
		set_paused(not get_tree().paused)
		get_viewport().set_input_as_handled()


func set_paused(paused: bool) -> void:
	if phase == Phase.MATCH_OVER:
		return
	if paused:
		Juice.reset_time_effects()
	get_tree().paused = paused
	hud.show_pause(paused)


func _return_to_menu() -> void:
	get_tree().paused = false
	Game.goto(Game.SCENE_MAIN_MENU)


func _exit_tree() -> void:
	Juice.reset_time_effects()
	if get_tree().paused:
		get_tree().paused = false


func start_round() -> void:
	Juice.reset_time_effects()
	_result_delay = 0.0
	_treat_clock = _treat_delay(true)
	_treat_count = 0
	round_number += 1
	round_time_left = ROUND_SECONDS
	phase = Phase.COUNTDOWN
	# Round 1's arena is already up; later rounds draw a fresh one when shuffling.
	if Game.random_arena_each_round and round_number > 1:
		_install_arena(Game.random_arena(arena_data))
	_clear_actors()
	actors.process_mode = Node.PROCESS_MODE_DISABLED
	for i in Game.slots.size():
		var slot := Game.slots[i]
		var dog: Dog = DOG_SCENE.instantiate()
		dog.setup(slot)
		dog.position = arena.clear_pickup_position(arena.get_spawn_position(i), slot.dog.body_radius + 0.25)
		dog.facing = (Vector3.ZERO - dog.position).normalized()
		actors.add_child(dog)
		if slot.is_bot:
			dog.add_child(BotBrain.new())
		dogs.append(dog)
	# Every dog starts empty and every toy starts out in the open, away from the pack.
	var available: Array[ToyData] = []
	for item in Game.toys:
		if item.fully_implemented:
			available.append(item)
	var count := maxi(1, arena.toy_spawns.get_child_count())
	var points := _toy_spawn_points(count)
	for i in count:
		var item := Game.selected_toy
		if Game.mixed_toys and not available.is_empty():
			item = available[(i + round_number - 1) % available.size()]
		var at := arena.clear_pickup_position(points[i], item.radius + 0.25)
		_spawn_toy(at, item)
	mode.on_round_start(dogs)
	hud.update_match(dogs, round_time_left, round_number)
	if Game.random_arena_each_round:
		hud.announce(arena_data.display_name.to_upper())
	hud.countdown(round_number)


func _begin_play() -> void:
	if phase != Phase.COUNTDOWN:
		return
	phase = Phase.PLAYING
	actors.process_mode = Node.PROCESS_MODE_PAUSABLE
	Sfx.play("whistle")
	Events.round_started.emit(round_number)


func _spawn_toy(at: Vector3, item: ToyData = null) -> Toy:
	var toy: Toy = TOY_SCENE.instantiate()
	toy.setup(item if item else Game.selected_toy)
	toy.position = at
	actors.add_child(toy)
	toys.append(toy)
	return toy


## Seconds until the next crate. Experience pulls it forward; it never goes below the floor.
func _treat_delay(first: bool) -> float:
	var base := TREAT_FIRST_DELAY if first else TREAT_REPEAT_DELAY
	var rush := float(maxi(0, round_number - 1)) * TREAT_ROUND_RUSH + float(Game.matches_played) * TREAT_MATCH_RUSH
	return maxf(TREAT_MIN_DELAY, base - rush)


func _spawn_treat() -> void:
	var pickup := Powerup.new()
	# A mystery: the kind is rolled here and stays hidden until a dog opens the crate.
	pickup.kind = PowerupKinds.random_kind()
	# Crates land out in the open, away from the walls, so reaching one is a real decision.
	var half := arena.size * 0.5
	var angle := randf() * TAU
	var preferred := Vector3(cos(angle) * half.x * 0.5, 0.0, sin(angle) * half.y * 0.45)
	pickup.position = arena.clear_pickup_position(preferred)
	actors.add_child(pickup)
	_treat_count += 1
	hud.announce("Shield treat! Blocks one hit." if pickup.kind == &"shield" else "Zoomies treat! Run and dash faster.")


## Toys are laid out symmetrically about both arena axes: four in a quad plus a pair on one
## axis. Spawns sit in the four corners, so every dog sees an identical arrangement and no
## opening run is shorter than another. The quad and pair are redrawn every round, and the
## pair swaps axes, so the spots still change. Props can nudge a toy off its mirror, so a few
## draws are scored and the most balanced one is kept.
func _toy_spawn_points(count: int) -> Array[Vector3]:
	var spawns: Array[Vector3] = []
	for i in Game.slots.size():
		spawns.append(arena.get_spawn_position(i))
	var best: Array[Vector3] = []
	var best_score := INF
	for attempt in 6:
		var layout := _symmetric_layout(count)
		var score := _layout_imbalance(layout, spawns)
		if best.is_empty() or score < best_score:
			best_score = score
			best = layout
		if best_score <= 0.9:
			break
	return best


func _symmetric_layout(count: int) -> Array[Vector3]:
	var half := arena.size * 0.5
	# Kept well inside the corners so nothing lands within reach of a starting dog.
	var quad_x := randf_range(0.18, 0.38) * half.x
	var quad_z := randf_range(0.18, 0.42) * half.y
	var pair_reach := randf_range(0.26, 0.50)
	var sideways := randf() < 0.5
	var raw: Array[Vector3] = [
		Vector3(quad_x, 0.0, quad_z),
		Vector3(-quad_x, 0.0, quad_z),
		Vector3(quad_x, 0.0, -quad_z),
		Vector3(-quad_x, 0.0, -quad_z),
	]
	if sideways:
		raw.append(Vector3(pair_reach * half.x, 0.0, 0.0))
		raw.append(Vector3(-pair_reach * half.x, 0.0, 0.0))
	else:
		raw.append(Vector3(0.0, 0.0, pair_reach * half.y))
		raw.append(Vector3(0.0, 0.0, -pair_reach * half.y))
	var points: Array[Vector3] = []
	for i in count:
		points.append(arena.clear_pickup_position(raw[i % raw.size()], 0.7))
	return points


## How lopsided a layout is: the spread between the best and worst opening run. A layout that
## drops a toy in someone's lap is rejected outright.
func _layout_imbalance(points: Array[Vector3], spawns: Array[Vector3]) -> float:
	if spawns.is_empty():
		return 0.0
	var shortest := INF
	var longest := 0.0
	for spawn in spawns:
		var nearest := INF
		for at in points:
			nearest = minf(nearest, Vector2(at.x - spawn.x, at.z - spawn.z).length())
		if nearest < MIN_TOY_SPAWN_DISTANCE:
			return INF
		shortest = minf(shortest, nearest)
		longest = maxf(longest, nearest)
	return longest - shortest


## Replaces the live arena, taking the new scene's camera with it. The outgoing camera is
## only freed at the end of the frame, so the incoming one has to claim the viewport itself.
func _install_arena(data: ArenaData) -> void:
	if data == null:
		return
	arena_data = data
	if is_instance_valid(arena):
		arena.queue_free()
		arena_holder.remove_child(arena)
	arena = data.scene.instantiate()
	arena_holder.add_child(arena)
	var camera := arena.get_node_or_null("Camera") as Camera3D
	if camera != null:
		camera.make_current()


func _clear_actors() -> void:
	dogs.clear()
	toys.clear()
	for c in actors.get_children():
		c.queue_free()


func _on_dog_eliminated(dog: Node, _by: Node) -> void:
	if phase != Phase.PLAYING:
		return
	mode.on_dog_eliminated(dog)
	hud.update_match(dogs, round_time_left, round_number)
	if mode.is_round_over(dogs):
		phase = Phase.ROUND_OVER
		_end_round(mode.round_winner(dogs))


func _end_round(winner: PlayerSlot, message: String = "") -> void:
	# Lock the result immediately: collision changes must wait until callbacks finish.
	for dog in dogs:
		dog.round_locked = true
		if winner and dog.slot == winner:
			dog.model.play_victory()
	for toy in toys:
		toy.call_deferred("set_physics_process", false)
	for pickup in get_tree().get_nodes_in_group("powerups"):
		pickup.set_deferred("process_mode", Node.PROCESS_MODE_DISABLED)
	if winner:
		winner.score += 1
		hud.refresh_scores()
	Events.round_over.emit(winner)
	Sfx.play("fanfare" if winner else "tick")
	var text := "%s wins the round!" % winner.dog.display_name if winner else "Draw! Fetch again."
	if not message.is_empty():
		text = message
	var color := winner.color if winner else UiKit.CREAM
	_round_winner = winner
	_result_text = text
	_result_color = color
	_result_delay = 0.8 if winner else 0.1


func _finish_round() -> void:
	if phase != Phase.ROUND_OVER:
		return
	var winner := _round_winner
	if winner and winner.score >= Game.points_to_win:
		phase = Phase.MATCH_OVER
		Game.matches_played += 1
		Game.last_match_winner = winner
		Events.match_over.emit(winner)
		Game.goto(Game.SCENE_RESULTS)
	else:
		start_round()
