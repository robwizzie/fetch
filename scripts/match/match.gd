extends Node
## Runs one match: brief countdowns, bounded rounds, pause, and an immediate rematch loop.

enum Phase { TUTORIAL, COUNTDOWN, PLAYING, ROUND_OVER, MATCH_OVER }

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
var _coach: TutorialCoach
var _pens: Array[ReadyPen] = []
var dogs: Array[Dog] = []
var toys: Array[Toy] = []
var mode: GameMode
var phase := Phase.COUNTDOWN
var round_number := 0
var round_time_left := ROUND_SECONDS
var _round_winner: PlayerSlot
## The warm-up round after the pens open. It plays exactly like a real round - dogs can be
## bonked out and someone wins it - but nothing it produces goes on the board.
var practice_round := false
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
	# A brand new session gets a practice round first. It is not a round: nothing is scored,
	# the round counter does not move, and nobody can be knocked out behind the walls.
	if not Game.tutorial_shown and round_number == 0:
		Game.tutorial_shown = true
		_start_tutorial()
	else:
		start_round()


func _physics_process(delta: float) -> void:
	if get_tree().paused or phase != Phase.PLAYING:
		return
	# Safety net: a toy that somehow leaves the arena comes back to a toy spawn.
	for toy in toys:
		if toy.state != Toy.State.HELD and arena.is_outside(toy.global_position):
			toy.drop(arena.get_toy_spawn_position(0))
	if Game.powerups_enabled and round_number >= Game.treats_from_round:
		_treat_clock -= delta
		if _treat_clock <= 0.0 and _treat_count < MAX_TREATS_PER_ROUND:
			_spawn_treat()
			_treat_clock = _treat_delay(false)
	round_time_left = maxf(0.0, round_time_left - delta)
	hud.update_match(dogs, round_time_left, round_number)
	if practice_round:
		hud.practice_clock()
	if round_time_left <= 0.0:
		phase = Phase.ROUND_OVER
		_end_round(null, "Time's up! Draw — no points")


func _process(delta: float) -> void:
	if get_tree().paused or _result_delay <= 0.0:
		return
	_result_delay -= delta / maxf(Engine.time_scale, 0.001)
	if _result_delay <= 0.0:
		if practice_round:
			hud.banner(_result_text, _result_color, 1.65)
		else:
			hud.round_board(_result_text, _standings(), Game.points_to_win, "Press to continue")


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
	if not practice_round:
		round_number += 1
	round_time_left = ROUND_SECONDS
	phase = Phase.COUNTDOWN
	# Round 1's arena is already up; later rounds draw a fresh one when shuffling.
	if Game.random_arena_each_round and round_number > 1 and not practice_round:
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
	_spawn_round_toys()
	mode.on_round_start(dogs)
	hud.update_match(dogs, round_time_left, round_number)
	if Game.random_arena_each_round:
		hud.announce(arena_data.display_name.to_upper())
	hud.countdown(round_number)


## Every dog starts empty and every toy starts out in the open, away from the pack.
func _spawn_round_toys() -> void:
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


func _begin_play() -> void:
	if phase != Phase.COUNTDOWN:
		return
	phase = Phase.PLAYING
	_maybe_coach()
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


## The practice round. Each player gets a walled pen with a toy and a pad to stand on when
## they are done learning; the real first round only begins once everyone has stepped on one.
## Nothing here is scored.
func _start_tutorial() -> void:
	phase = Phase.TUTORIAL
	# Arena furniture is off while the pens are up. A portal that happens to sit inside someone's
	# pen would warp them out of it, and a dog that cannot get back to its pad can never check
	# in - which leaves the match stuck on the practice round forever.
	_set_furniture_active(false)
	_clear_actors()
	_pens.clear()
	actors.process_mode = Node.PROCESS_MODE_PAUSABLE
	var count := Game.slots.size()
	var half := arena.size * 0.5
	var pen_size := Vector2(5.0, 4.6)
	for i in count:
		var slot := Game.slots[i]
		var centre := Vector3(_pen_spot(i, count).x * half.x, 0.0, _pen_spot(i, count).y * half.y)
		var dog: Dog = DOG_SCENE.instantiate()
		dog.setup(slot)
		dog.position = centre + Vector3(0, 0, -pen_size.y * 0.22)
		dog.facing = Vector3(0, 0, 1)
		actors.add_child(dog)
		dog.practice_safe = true
		dogs.append(dog)
		# A toy each, so throwing and catching can actually be tried in here.
		var practice: ToyData = Game.toys[i % Game.toys.size()]
		_spawn_toy(centre + Vector3(0, 0, pen_size.y * 0.02), practice)
		var pen := ReadyPen.new()
		arena.add_child(pen)
		pen.build(slot, centre, pen_size)
		pen.dog = dog
		pen.readied.connect(_on_pen_ready)
		_pens.append(pen)
		if slot.is_bot:
			pen.auto_ready_after(randf_range(4.0, 8.0))

	hud.update_match(dogs, ROUND_SECONDS, 1)
	hud.practice_clock()
	hud.announce("PRACTICE — nothing is scored")
	_coach = TutorialCoach.new()
	_coach.setup(dogs)
	hud.add_child(_coach)
	_coach.watch_events()
	_coach.finished.connect(func() -> void: _coach = null)


## Booths sit apart with clear ground between them and an open middle, so nobody can reach a
## neighbour and the arena still reads as one space. Fractions of the arena half-extents, so
## the layout holds on every map.
func _pen_spot(index: int, count: int) -> Vector2:
	var spots: Array[Vector2] = []
	match count:
		1:
			spots = [Vector2(0.0, 0.0)]
		2:
			spots = [Vector2(-0.58, 0.0), Vector2(0.58, 0.0)]
		3:
			spots = [Vector2(-0.62, -0.46), Vector2(0.62, -0.46), Vector2(0.0, 0.48)]
		_:
			spots = [Vector2(-0.62, -0.46), Vector2(0.62, -0.46), Vector2(-0.62, 0.46), Vector2(0.62, 0.46)]
	return spots[index % spots.size()]


func _on_pen_ready(_pen: ReadyPen) -> void:
	for pen in _pens:
		if is_instance_valid(pen) and not pen.is_ready:
			return
	_finish_tutorial()


## Everyone has checked in: drop the walls and start the match for real.
func _finish_tutorial() -> void:
	if phase != Phase.TUTORIAL:
		return
	_dismiss_coach()
	_set_furniture_active(true)
	for pen in _pens:
		if is_instance_valid(pen):
			pen.open()
	_pens.clear()
	# Safety comes off with the walls: the warm-up is a real fight, bonks and all. It simply
	# does not score, which is what makes it safe to lose.
	for dog in dogs:
		if is_instance_valid(dog):
			dog.practice_safe = false
	Sfx.play("whistle", 1.0, -3.0)
	_begin_warmup()


## The warm-up starts where the pens end: the same dogs, standing where they were, playing on
## from the moment the walls drop. No respawn and no second countdown - the walls coming down
## IS the start. It scores nothing, so losing it costs nothing.
func _begin_warmup() -> void:
	practice_round = true
	_treat_clock = _treat_delay(true)
	_treat_count = 0
	round_time_left = ROUND_SECONDS
	# The pen toys have done their job. Anything still in a mouth stays there; the rest make way
	# for the arena's normal scatter.
	var kept: Array[Toy] = []
	for toy in toys:
		if not is_instance_valid(toy):
			continue
		if toy.state == Toy.State.HELD:
			kept.append(toy)
		else:
			toy.queue_free()
	toys = kept
	_spawn_round_toys()
	# Bots were kept calm in their pens; now they have somewhere to be.
	for dog in dogs:
		if is_instance_valid(dog) and dog.slot.is_bot and dog.get_node_or_null("BotBrain") == null:
			var brain := BotBrain.new()
			brain.name = "BotBrain"
			dog.add_child(brain)
	mode.on_round_start(dogs)
	hud.practice_clock()
	phase = Phase.PLAYING
	Events.round_started.emit(round_number)


## Portals and switches are the only arena pieces that move a dog without being asked, so they
## are the ones that have to be inert while everyone is penned in learning the buttons.
func _set_furniture_active(active: bool) -> void:
	if arena == null:
		return
	for node in arena.find_children("*", "Area3D", true, false):
		if node is Portal or node is SwitchPad:
			var area := node as Area3D
			area.monitoring = active
			area.visible = active


func _maybe_coach() -> void:
	pass


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


func _dismiss_coach() -> void:
	if is_instance_valid(_coach):
		_coach.dismiss()
		_coach = null


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
	_dismiss_coach()
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
		if practice_round:
			pass
		elif Game.team_mode and winner.team >= 0:
			Game.team_scores[winner.team] += 1
		else:
			winner.score += 1
		hud.refresh_scores()
	Events.round_over.emit(winner)
	Sfx.play("fanfare" if winner else "tick")
	var text := "%s wins the round!" % winner.dog.display_name if winner else "Draw! Fetch again."
	if winner and Game.team_mode and winner.team >= 0:
		text = "%s wins the round!" % Game.team_name(winner.team)
	if practice_round:
		text = "Warm-up over - no points. Here we go!"
	if not message.is_empty():
		text = message
	var color := winner.color if winner else UiKit.CREAM
	if winner and Game.team_mode and winner.team >= 0:
		color = Game.team_color(winner.team)
	_round_winner = winner
	_result_text = text
	_result_color = color
	_result_delay = 0.8 if winner else 0.1


## One bar per side for the round board: packs when teams are on, dogs otherwise.
func _standings() -> Array:
	var sides: Array = []
	if Game.team_mode:
		for team in Game.TEAM_NAMES.size():
			sides.append({
				"label": Game.team_name(team),
				"color": Game.team_color(team),
				"score": Game.team_scores[team],
				"winner": _round_winner != null and _round_winner.team == team,
			})
		return sides
	for slot in Game.slots:
		sides.append({
			"label": "%s  %s" % [slot.label, slot.dog.display_name.to_upper()],
			"color": slot.color,
			"score": slot.score,
			"winner": slot == _round_winner,
		})
	return sides


func _finish_round() -> void:
	if phase != Phase.ROUND_OVER:
		return
	var winner := _round_winner
	if practice_round:
		# The warm-up is done. Round 1 starts now, with the board still at nil-nil.
		practice_round = false
		start_round()
		return
	if winner and Game.score_for(winner) >= Game.points_to_win:
		phase = Phase.MATCH_OVER
		Game.matches_played += 1
		Game.last_match_winner = winner
		Events.match_over.emit(winner)
		Game.goto(Game.SCENE_RESULTS)
	else:
		start_round()
