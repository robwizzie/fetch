extends Node
## Runs one match: brief countdowns, bounded rounds, pause, and an immediate rematch loop.

enum Phase { TUTORIAL, COUNTDOWN, PLAYING, ROUND_OVER, MATCH_OVER }

const DOG_SCENE := preload("res://scenes/actors/dog.tscn")
const TOY_SCENE := preload("res://scenes/actors/toy.tscn")
## The practice round always plays on bare ground. Finding the buttons and learning a map are
## two things at once, and a prop to get wedged behind is the last thing a first-timer needs.
## It is a scene rather than a data/arenas entry, so it never appears in the arena picker.
const TRAINING_SCENE := preload("res://scenes/arenas/training_yard.tscn")
## Crates are a budget, not a drip. A round gets two (three with a bigger pack) and that is
## all it gets however long the dogs survive, so a long scrap never ends buried in treats.
## The first lands right after the whistle - playtests showed most rounds were decided before a
## later crate ever arrived - and the rest follow on a steady gap.
const TREAT_FIRST_DELAY := 1.5
## A brand new session's first crate waits a little longer, while everyone finds the buttons.
const TREAT_FIRST_DELAY_NEW := 3.0
const TREAT_GAP := 5.0
const TREATS_SMALL_PACK := 2
const TREATS_BIG_PACK := 3
## Crates keep this far from any dog and from one another, so every drop is a new trip.
const TREAT_DOG_CLEARANCE := 3.0
const TREAT_SPREAD := 6.0
const TREAT_TOY_CLEARANCE := 1.6
## Points behind the leader before the mercy shield kicks in.
const COMEBACK_GAP := 2
const ROUND_SECONDS := 55.0
## Sudden death starts with this many seconds on the clock, and an overtime that somehow never
## produces a knockout gives up as a draw after this long.
const SUDDEN_DEATH_AT := 10.0
const OVERTIME_LIMIT := 25.0
## Toys on the floor that the sky will add to, at most.
const SKY_TOY_CAP := 14
## Supply drops: a dog empty-pawed this long, with no loose toy within reach, gets one dropped
## nearby. Playtests had dogs toy-less for most of their time alive - hunting, not playing.
const RESUPPLY_AFTER := 2.0
const RESUPPLY_REACH := 4.5
## No toy starts within this many metres of any dog's spawn: the opening move is a decision,
## not a free pickup. Relaxed in steps only if an arena leaves nowhere else to put one.
const MIN_TOY_SPAWN_DISTANCE := 5.0

var arena: Arena
var arena_data: ArenaData
## Sudden death: on, the clock to the next drop, and how long overtime has run.
var highlights := Highlights.new()
var replay: Replay
var _replay_clock := 0.0
var sudden_death := false
## The last knockout was a dog bonking itself; if it decides the round, nobody scores.
var _drop_clock := 0.0
var overtime := 0.0
## Seconds to the next check for toys stranded out of every dog's reach.
var _reach_clock := 0.5
## One lesson card per human in the practice pens.
var _cards: Array[PracticeCard] = []
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
## Where this round's crates have already landed, so the next one goes somewhere else.
var _treat_spots: Array[Vector3] = []
var _result_delay := 0.0
## True while the bare training yard is up, so the chosen arena can take over afterwards.
var _training_yard := false
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
	# A brand new session opens on the practice round, and that runs on the training yard
	# whatever arena was picked. So does the first scored round; see start_round().
	_training_yard = not Game.tutorial_shown and round_number == 0
	_install_arena(_training_arena() if _training_yard else _chosen_arena())
	hud.setup(Game.slots, mode.hud_hint())
	hud.resume_requested.connect(func() -> void: set_paused(false))
	hud.quit_requested.connect(_return_to_menu)
	hud.countdown_finished.connect(_begin_play)
	hud.banner_finished.connect(_finish_round)
	replay = Replay.new()
	replay.name = "Replay"
	add_child(replay)
	replay.finished.connect(_after_replay)
	Input.joy_connection_changed.connect(_on_joy_connection_changed)
	Events.dog_eliminated.connect(_on_dog_eliminated)
	Events.toy_caught.connect(_on_toy_caught)
	Music.play("match")
	# A brand new session gets a practice round first. It is not a round: nothing is scored,
	# the round counter does not move, and nobody can be knocked out behind the walls.
	if _training_yard:
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
	_reach_clock -= delta
	if _reach_clock <= 0.0:
		_reach_clock = 0.5
		_rescue_stranded_toys()
	if Game.powerups_enabled and round_number >= Game.first_treat_round():
		_treat_clock -= delta
		if _treat_clock <= 0.0 and _treat_count < treats_per_round():
			_spawn_treat()
			_treat_clock = TREAT_GAP
	round_time_left = maxf(0.0, round_time_left - delta)
	if not practice_round and round_time_left <= SUDDEN_DEATH_AT:
		_run_sudden_death(delta)
	_resupply(delta)
	_replay_clock += delta
	replay.record(_replay_clock, dogs, toys, actors)
	hud.update_match(dogs, round_time_left, round_number)
	if practice_round:
		hud.practice_clock()
	# The warm-up runs the mode's rules too (a fuse that burns, a bed that banks time) - it just
	# scores nothing, which _end_round takes care of.
	mode.tick(delta, dogs)
	# A mode can decide a round on its own clock (a bed held long enough), not just on a KO.
	if phase == Phase.PLAYING and mode.is_round_over(dogs):
		phase = Phase.ROUND_OVER
		_end_round(mode.round_winner(dogs))
		return
	if round_time_left <= 0.0:
		var decided := mode.timeout_winner(dogs) if not practice_round else null
		if decided != null:
			phase = Phase.ROUND_OVER
			_end_round(decided, "Time's up! %s takes it" % decided.dog.display_name)
		elif practice_round or overtime >= OVERTIME_LIMIT:
			phase = Phase.ROUND_OVER
			_end_round(null, "Time's up! Everybody's in the doghouse")
		else:
			# No draws: the clock running out is the start of overtime, not the end of the round.
			overtime += delta


func _process(delta: float) -> void:
	if get_tree().paused or _result_delay <= 0.0:
		return
	_result_delay -= delta / maxf(Engine.time_scale, 0.001)
	if _result_delay <= 0.0:
		if practice_round:
			hud.banner(_result_text, _result_color, 1.65)
		elif Game.replays and _round_winner != null and replay.has_moment():
			# The knockout that won it, once more, slowly and from close up.
			actors.visible = false
			hud.show_replay(true)
			replay.play(arena.get_node_or_null("Camera") as Camera3D)
		else:
			_show_round_board()


func _after_replay() -> void:
	actors.visible = true
	hud.show_replay(false)
	_show_round_board()


func _show_round_board() -> void:
	hud.round_board(_result_text, _standings(), Game.points_to_win,
		"NEXT ROUND  -  %s to go now" % DeviceInput.button_label(&"confirm", Game.slots))


func _unhandled_input(event: InputEvent) -> void:
	if replay != null and replay.is_playing() and (event.is_action_pressed("ui_accept") or DeviceInput.join_device_from_event(event) != DeviceInput.NONE):
		replay.skip()
		get_viewport().set_input_as_handled()
		return
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


## A player's pad dropping out leaves their dog frozen for everyone to hit: stop the game until
## it is back.
func _on_joy_connection_changed(device: int, connected: bool) -> void:
	if connected or get_tree().paused:
		return
	for slot in Game.slots:
		if not slot.is_bot and slot.device == device:
			set_paused(true)
			return


func _return_to_menu() -> void:
	get_tree().paused = false
	Game.goto(Game.SCENE_MAIN_MENU)


func _exit_tree() -> void:
	Juice.reset_time_effects()
	if get_tree().paused:
		get_tree().paused = false


func start_round() -> void:
	_empty_time.clear()
	Juice.reset_time_effects()
	_result_delay = 0.0
	_treat_clock = _treat_delay()
	_treat_count = 0
	_treat_spots.clear()
	if not practice_round:
		round_number += 1
		_grant_comeback_shields()
	round_time_left = ROUND_SECONDS
	if replay != null:
		replay.clear()
	sudden_death = false
	overtime = 0.0
	phase = Phase.COUNTDOWN
	# Round 1's arena is already up; later rounds draw a fresh one when shuffling.
	# The warm-up AND the first scored round both play on the bare training yard: round one is
	# still about finding your feet, and a first win should come from the game rather than from
	# knowing a map. The arena people chose arrives with round two.
	if _training_yard and round_number > 1 and not practice_round:
		_training_yard = false
		_install_arena(_chosen_arena())
	elif Game.random_arena_each_round and round_number > 1 and not practice_round:
		_install_arena(Game.random_arena(arena_data))
	else:
		# Same arena as last round: put back anything the last round moved.
		for node in arena.find_children("*", "", true, false):
			if node.has_method("reset_for_round"):
				node.call("reset_for_round")
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
	_update_crowns()
	hud.update_match(dogs, round_time_left, round_number)
	if Game.random_arena_each_round:
		hud.announce(arena_data.display_name.to_upper())
	hud.countdown(round_number)


## A mercy shield for anyone who has fallen well behind, provided they have a slot free for it.
## It costs the leader nothing and keeps a runaway match worth playing out.
func _grant_comeback_shields() -> void:
	if not Game.powerups_enabled:
		return
	var best := 0
	for slot in Game.slots:
		best = maxi(best, Game.score_for(slot))
	for slot in Game.slots:
		slot.normalize_powerups()
		if best - Game.score_for(slot) < COMEBACK_GAP:
			continue
		if slot.powerups.size() >= PowerupKinds.MAX_SLOTS:
			continue
		slot.take_powerup(PowerupKinds.SHIELD)


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
	actors.process_mode = Node.PROCESS_MODE_PAUSABLE
	for dog in dogs:
		if is_instance_valid(dog):
			dog.show_belt_parade()
	Sfx.play("whistle")
	Events.round_started.emit(round_number)


func _spawn_toy(at: Vector3, item: ToyData = null) -> Toy:
	var toy: Toy = TOY_SCENE.instantiate()
	toy.setup(item if item else Game.selected_toy)
	toy.position = at
	actors.add_child(toy)
	toys.append(toy)
	return toy


## Seconds until a round's first crate.
func _treat_delay() -> float:
	return TREAT_FIRST_DELAY_NEW if Game.matches_played == 0 and round_number <= 1 else TREAT_FIRST_DELAY


## The whole round's allowance of crates.
func treats_per_round() -> int:
	return TREATS_BIG_PACK if Game.slots.size() >= 3 else TREATS_SMALL_PACK


func _spawn_treat() -> void:
	var pickup := Powerup.new()
	# A mystery: the kind is rolled here and stays hidden until a dog opens the crate.
	pickup.kind = PowerupKinds.random_kind()
	pickup.position = _treat_position()
	actors.add_child(pickup)
	_treat_spots.append(pickup.position)
	_treat_count += 1
	hud.announce("TREAT DROP!  Sniff it out for a mystery power-up.")


## Somewhere open, clear of every dog, and as far as possible from where this round's other
## crates landed. Forty random draws are scored and the best kept: that spreads drops across
## the whole lawn instead of stacking them on one ring, and never hands one to a dog standing
## on the spot.
func _treat_position() -> Vector3:
	var half := arena.size * 0.5
	var best := Vector3.ZERO
	var best_score := -INF
	# Plenty of draws: on a crowded map (ice holes, snow banks) most land on something.
	for attempt in 40:
		var candidate := Vector3(randf_range(-0.78, 0.78) * half.x, 0.0, randf_range(-0.7, 0.7) * half.y)
		if not arena.is_clear_position(candidate, 0.85):
			continue
		var near_dog := INF
		for dog in dogs:
			if is_instance_valid(dog) and dog.alive:
				near_dog = minf(near_dog, _flat_distance(candidate, dog.global_position))
		var near_crate := INF
		for spot in _treat_spots:
			near_crate = minf(near_crate, _flat_distance(candidate, spot))
		for node in get_tree().get_nodes_in_group("powerups"):
			near_crate = minf(near_crate, _flat_distance(candidate, (node as Node3D).global_position))
		# A crate sat on a loose toy hides the toy and makes one trip win both.
		for toy in toys:
			if is_instance_valid(toy) and toy.state == Toy.State.IDLE and _flat_distance(candidate, toy.global_position) < TREAT_TOY_CLEARANCE:
				near_dog = minf(near_dog, 0.0)
		var score := minf(near_crate, TREAT_SPREAD * 2.0) * 1.5 + minf(near_dog, TREAT_DOG_CLEARANCE * 2.0)
		if near_dog < TREAT_DOG_CLEARANCE:
			score -= 20.0
		if near_crate < TREAT_SPREAD:
			score -= 10.0
		if score > best_score:
			best_score = score
			best = candidate
	if best_score == -INF:
		return arena.clear_pickup_position(Vector3.ZERO)
	return best


static func _flat_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


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
	_lock_camera_wide(true)
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
	hud.announce("Try each move, then stand on your pad")
	var camera := arena.get_node_or_null("Camera") as Camera3D
	for i in _pens.size():
		var slot := Game.slots[i]
		if slot.is_bot:
			continue
		var card := PracticeCard.new()
		card.setup(slot, dogs[i], _pens[i], camera)
		hud.add_child(card)
		_cards.append(card)


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
	# Play is starting, so the camera goes back to following the pack.
	_lock_camera_wide(false)
	_treat_clock = _treat_delay()
	_treat_count = 0
	_treat_spots.clear()
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


## Holds the camera on the whole arena, or hands it back to its normal follow behaviour.
func _lock_camera_wide(locked: bool) -> void:
	if arena == null:
		return
	var camera := arena.get_node_or_null("Camera") as ArenaCamera
	if camera != null:
		camera.locked_wide = locked


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


## Whatever the setup screen settled on for this match.
func _chosen_arena() -> ArenaData:
	return Game.random_arena() if Game.random_arena_each_round else Game.selected_arena


## A stand-in record for the training yard, built in code so the bare map stays out of the
## content folder and therefore out of every menu that lists arenas.
func _training_arena() -> ArenaData:
	var data := ArenaData.new()
	data.id = &"training_yard"
	data.display_name = "Training Yard"
	data.description = "Bare ground for finding the buttons."
	data.scene = TRAINING_SCENE
	return data


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
	for card in _cards:
		if is_instance_valid(card):
			card.dismiss()
	_cards.clear()


func _clear_actors() -> void:
	dogs.clear()
	toys.clear()
	for c in actors.get_children():
		c.queue_free()


func _on_dog_eliminated(dog: Node, by: Node) -> void:
	if phase != Phase.PLAYING:
		return
	if practice_round and Game.scoring == Game.Scoring.BONKS and dog is Dog and by is Toy and (by as Toy).thrower == dog:
		# The warm-up scores nothing, but the dog's own line is left to this callout.
		hud.callout("SELF-BONK!", (dog as Dog).slot.color)
	if not practice_round and dog is Dog:
		var victim := dog as Dog
		victim.slot.bonked += 1
		# Whoever threw it - or whacked them down a hole - gets the bonk, unless it was their own
		# toy or a pack-mate's.
		var credited := victim.knocked_out_by(by)
		if credited != null and credited.slot.allied_with(victim.slot):
			credited = null
		if credited != null:
			credited.slot.knockouts += 1
			_progress(credited.slot, &"bonks")
		_progress(victim.slot, &"times_bonked")
		var self_bonk := by is Toy and (by as Toy).thrower == victim
		if self_bonk and Game.scoring == Game.Scoring.BONKS:
			# Racing to a bonk total, bonking yourself costs you one - it is your bone that
			# goes, not a gift to somebody else. Played for rounds it costs nothing: the round
			# is simply won by whoever is left standing.
			var was: int = Game.score_for(victim.slot)
			Game.add_points(victim.slot, -1)
			hud.callout("SELF-BONK!", victim.slot.color)
			if Game.score_for(victim.slot) < was:
				hud.lose_bone(victim.slot, was)
		elif credited != null and Game.scoring == Game.Scoring.BONKS:
			Game.add_points(credited.slot, 1)
			Juice.float_text(actors, credited.global_position + Vector3(0, 2.4, 0), "+1", credited.slot.color.lightened(0.3), 1.0)
		hud.refresh_scores()
		_update_crowns()
		_offer_revive(victim)
		_maybe_haunt(victim)
		var kind := highlights.classify(victim, by, credited, sudden_death)
		if kind != &"" and not self_bonk:
			_call_out(kind, credited, victim)
		# Bonks scoring ends the match the moment somebody reaches the goal.
		if Game.scoring == Game.Scoring.BONKS and credited != null and Game.score_for(credited.slot) >= Game.points_to_win:
			phase = Phase.ROUND_OVER
			_end_round(credited.slot, "%s reaches %d bonks!" % [_side_name(credited.slot), Game.points_to_win])
			return
	mode.on_dog_eliminated(dog)
	hud.update_match(dogs, round_time_left, round_number)
	# Finish the collision batch first: a blast can eliminate several dogs simultaneously.
	call_deferred("_check_round_end")


func _on_toy_caught(_toy: Node, by: Node) -> void:
	if phase == Phase.PLAYING and not practice_round and by is Dog:
		(by as Dog).slot.catches += 1
		_progress((by as Dog).slot, &"catches")


## A match played, and won - by people, if a person was on the winning side.
func _record_match(winner: PlayerSlot) -> void:
	if not Game.slots.any(func(s: PlayerSlot) -> bool: return not s.is_bot):
		return
	Progress.record(&"matches")
	var human_won := false
	for slot in Game.slots:
		if not slot.is_bot and slot.allied_with(winner):
			human_won = true
			Progress.record_win_with(slot.dog)
	if human_won:
		Progress.record(&"wins")
	Progress.save_progress()


## Lifetime stats count what people do, not what the CPUs do.
func _progress(slot: PlayerSlot, stat: StringName, amount: int = 1) -> void:
	if slot != null and not slot.is_bot:
		Progress.record(stat, amount)


## Big text across the arena in the scorer's colour, a sting, and a count towards hats.
func _call_out(kind: StringName, credited: Dog, victim: Dog) -> void:
	var color := credited.slot.color if credited != null else Color(1.0, 0.55, 0.35)
	hud.callout(Highlights.text(kind), color)
	var counted := {&"bank": &"bank_bonks", &"hole": &"hole_bonks", &"return": &"returns",
		&"revenge": &"revenges", &"double": &"doubles", &"triple": &"doubles", &"long": &"long_shots"}
	if credited != null and counted.has(kind):
		_progress(credited.slot, counted[kind])
	Events.highlight.emit(kind, credited.slot if credited != null else null, victim.slot)


## A toy that has come to rest where no dog can get to it - wedged between a prop and the fence,
## in a gap narrower than a dog - is lost to the round, and a round with its toys lost can only
## time out. It hops back out to the nearest spot a dog can reach.
func _rescue_stranded_toys() -> void:
	# Judged by the biggest dog in the match: a toy only the corgi can squeeze in for is still
	# lost to everyone else.
	var biggest := 0.0
	for dog in dogs:
		if is_instance_valid(dog):
			biggest = maxf(biggest, dog.effective_radius())
	if biggest <= 0.0:
		return
	for toy in toys:
		if not is_instance_valid(toy) or toy.state != Toy.State.IDLE or toy.ephemeral or toy.velocity.length() > 0.3:
			continue
		if _reachable(toy.global_position, biggest, biggest + toy.data.radius + 0.1):
			continue
		var spot := arena.clear_pickup_position(toy.global_position, biggest + 0.3)
		Juice.burst(actors, toy.global_position + Vector3.UP * 0.3, Color(1, 1, 1, 0.8), 8, 2.0)
		toy.global_position = Vector3(spot.x, toy.global_position.y, spot.z)
		toy.velocity = Vector3.ZERO


## True when a dog of [param body] radius can stand somewhere within [param reach] of [param at].
func _reachable(at: Vector3, body: float, reach: float) -> bool:
	if arena.is_clear_position(at, body):
		return true
	for ring in [reach * 0.5, reach]:
		for step in 12:
			var angle := TAU * float(step) / 12.0
			if arena.is_clear_position(at + Vector3(cos(angle), 0, sin(angle)) * ring, body):
				return true
	return false


## Toys fall from the sky on rings aimed at where the dogs are going, faster as the clock runs
## down and faster again in overtime, until somebody is out.
func _run_sudden_death(delta: float) -> void:
	if not sudden_death:
		sudden_death = true
		_drop_clock = 0.4
		hud.banner("SUDDEN DEATH!", Color(1.0, 0.42, 0.3), 1.3)
		Sfx.play("whistle", 0.8, -2.0)
		Music.duck(1.2, 6.0)
	_drop_clock -= delta
	if _drop_clock > 0.0:
		return
	var pressure := 1.0 - clampf(round_time_left / SUDDEN_DEATH_AT, 0.0, 1.0)
	_drop_clock = lerpf(1.1, 0.5, pressure) if round_time_left > 0.0 else 0.32
	var targets: Array[Dog] = []
	for dog in dogs:
		if is_instance_valid(dog) and dog.alive and not dog.is_burrowed():
			targets.append(dog)
	if targets.is_empty():
		return
	for i in (2 if round_time_left <= 0.0 else 1):
		var dog: Dog = targets.pick_random()
		var lead := dog.velocity * randf_range(0.3, 0.7)
		var scatter := Vector3(randf_range(-1.0, 1.0), 0, randf_range(-1.0, 1.0)) * 0.9
		var at := arena.clear_pickup_position(dog.global_position + lead + scatter, 0.5)
		var drop := SkyDrop.new()
		var falling: ToyData = Game.toys.filter(func(t: ToyData) -> bool: return t.fully_implemented).pick_random()
		drop.setup(self, falling)
		actors.add_child(drop)
		drop.global_position = Vector3(at.x, 0, at.z)


var _empty_time: Dictionary = {}


## A dog with nothing in its mouth and nothing loose nearby gets a toy dropped beside it, on a
## harmless green ring, so a round is spent playing rather than searching.
func _resupply(delta: float) -> void:
	for dog in dogs:
		if not is_instance_valid(dog) or not dog.alive or dog.held_toy != null:
			_empty_time.erase(dog)
			continue
		_empty_time[dog] = float(_empty_time.get(dog, 0.0)) + delta
		if float(_empty_time[dog]) < RESUPPLY_AFTER:
			continue
		if toys.size() + get_tree().get_nodes_in_group(SkyDrop.GROUP).size() >= SKY_TOY_CAP:
			return
		var near := false
		for toy in toys:
			if is_instance_valid(toy) and toy.state == Toy.State.IDLE and not toy.ephemeral \
					and Vector2(toy.global_position.x - dog.global_position.x, toy.global_position.z - dog.global_position.z).length() < RESUPPLY_REACH:
				near = true
				break
		if near:
			continue
		# Next one for this dog no sooner than another RESUPPLY_AFTER plus the fall.
		_empty_time[dog] = -1.0
		var offset := Vector3(randf_range(-1.0, 1.0), 0.0, randf_range(-1.0, 1.0)).normalized() * 2.4
		var at := arena.clear_pickup_position(dog.global_position + offset, 0.6)
		var drop := SkyDrop.new()
		drop.harmless = true
		var falling: ToyData = Game.toys.filter(func(t: ToyData) -> bool: return t.fully_implemented).pick_random()
		drop.setup(self, falling)
		actors.add_child(drop)
		drop.global_position = Vector3(at.x, 0, at.z)


## Where a sky drop leaves its toy, unless the floor is already full of them.
func drop_toy(at: Vector3, item: ToyData) -> void:
	if phase != Phase.PLAYING or toys.size() >= SKY_TOY_CAP:
		return
	_spawn_toy(arena.clear_pickup_position(at + Vector3(0, 0.3, 0), 0.6), item)


## Free-for-all with ghosts on: a knocked-out player comes back as a ghost once the tumble is
## over, and haunts the arena until the round ends. People only - a CPU just waits.
func _maybe_haunt(victim: Dog) -> void:
	if not Game.ghosts or Game.team_mode or victim.slot.is_bot or victim.input == null:
		return
	get_tree().create_timer(1.3, false).timeout.connect(func() -> void:
		if phase != Phase.PLAYING or not is_instance_valid(victim) or victim.alive:
			return
		var ghost := GhostDog.new()
		ghost.setup(victim.slot, victim.input, arena)
		actors.add_child(ghost)
		ghost.global_position = Vector3(victim.global_position.x, 0, victim.global_position.z))


## Team play, the Boomerang Fu way: a downed dog with a pack-mate still standing leaves a ring
## where it lies, and the pack-mate who stands in it long enough brings it back.
func _offer_revive(victim: Dog) -> void:
	if not Game.team_mode or victim.slot.team < 0:
		return
	if not dogs.any(func(d: Dog) -> bool: return is_instance_valid(d) and d.alive and d != victim and d.slot.allied_with(victim.slot)):
		return
	var spot := ReviveSpot.new()
	spot.setup(victim)
	actors.add_child(spot)
	var lies := victim.global_position + victim.model.ko_spot
	spot.global_position = Vector3(lies.x, 0, lies.z)
	spot.revived.connect(_on_revived)


func _on_revived(spot: ReviveSpot, by: Dog) -> void:
	if phase != Phase.PLAYING or not is_instance_valid(spot.dog):
		return
	var at := arena.clear_pickup_position(spot.global_position, spot.dog.effective_radius() + 0.1)
	spot.dog.revive(at)
	_progress(by.slot, &"revives")
	hud.callout("REVIVED!", by.slot.color)
	Events.dog_revived.emit(spot.dog, by)
	hud.update_match(dogs, round_time_left, round_number)


func _side_name(slot: PlayerSlot) -> String:
	return Game.team_name(slot.team) if Game.team_mode and slot.team >= 0 else slot.dog.display_name


## Whoever is in front wears the crown - every one of them, if they are level - in place of their
## hat. Nobody wears it until somebody has scored.
func _update_crowns() -> void:
	var best := 0
	for slot in Game.slots:
		best = maxi(best, Game.score_for(slot))
	for dog in dogs:
		if is_instance_valid(dog) and dog.model != null:
			dog.model.set_crown(best > 0 and Game.score_for(dog.slot) == best)


func _check_round_end() -> void:
	if phase != Phase.PLAYING:
		return
	if mode.is_round_over(dogs):
		phase = Phase.ROUND_OVER
		_end_round(mode.round_winner(dogs))


func _end_round(winner: PlayerSlot, message: String = "") -> void:
	_dismiss_coach()
	# Lock the result immediately: collision changes must wait until callbacks finish.
	for dog in dogs:
		dog.round_locked = true
		if winner and dog.slot.allied_with(winner):
			dog.model.play_victory()
	for toy in toys:
		toy.call_deferred("set_physics_process", false)
	for pickup in get_tree().get_nodes_in_group("powerups"):
		pickup.set_deferred("process_mode", Node.PROCESS_MODE_DISABLED)
	for effect in get_tree().get_nodes_in_group("combat_effects"):
		effect.set_deferred("process_mode", Node.PROCESS_MODE_DISABLED)
	if winner:
		# Rounds scoring pays the round's winner, however the others went out. Bonks scoring
		# has already paid out, one bonk at a time.
		if not practice_round and Game.scoring == Game.Scoring.ROUNDS:
			Game.add_points(winner, 1)
		hud.refresh_scores()
		_update_crowns()
	Events.round_over.emit(winner)
	Sfx.play("fanfare" if winner else "tick")
	var text := DogTalk.round_win(winner.dog.display_name) if winner else DogTalk.draw()
	if winner and Game.team_mode and winner.team >= 0:
		text = DogTalk.round_win(Game.team_name(winner.team))
	if not message.is_empty():
		text = message
	if practice_round:
		text = "Warm-up over - no points. Here we go!"
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
		_record_match(winner)
		Events.match_over.emit(winner)
		Game.goto(Game.SCENE_RESULTS)
	else:
		start_round()
