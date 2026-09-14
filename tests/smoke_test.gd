extends Node
## Headless end-to-end check. Run with:
##   godot --headless --path . res://tests/smoke_test.tscn
## Instantiates every UI scene, then plays a real match with virtual (scripted) players
## until one dog wins a round. Exits 0 on success, 1 on failure.

const UI_SCENES := [
	"res://scenes/ui/main_menu.tscn",
	"res://scenes/ui/dog_select.tscn",
	"res://scenes/ui/match_setup.tscn",
	"res://scenes/ui/results.tscn",
	"res://scenes/ui/gallery.tscn",
]
const TIMEOUT_SEC := 75.0

var _match: Node
var _elapsed := 0.0
var _round_started := false
var _throw_timer := 0.0
var _rounds_won := 0
var _eliminations := 0
var _caught := 0
var _phase := "ui"
var _target_throw_timer := 0.0
var _failed := false
## Stuck detection for the scripted shooter (it has no pathfinding; props can pin it).
var _last_shooter_pos := Vector3.ZERO
var _stuck_time := 0.0
var _detour_timer := 0.0
var _detour_dir := Vector2.ZERO


## Flat (XZ) direction from one node to another as a 2D input vector (x = right, y = down/toward camera).
static func dir_to(from: Node3D, to: Node3D) -> Vector2:
	var d := to.global_position - from.global_position
	return Vector2(d.x, d.z).normalized()


func _ready() -> void:
	print("[smoke] content: dogs=%d toys=%d arenas=%d modes=%d" % [Game.dogs.size(), Game.toys.size(), Game.arenas.size(), Game.modes.size()])
	_check(Game.dogs.size() == 5, "expected 5 dogs")
	_check(Game.toys.size() == 6, "expected 6 toys")
	_check(Game.arenas.size() == 2, "expected 2 arenas")
	_check(Game.modes.size() == 7, "expected 7 modes")
	_check(Game.selected_mode != null and Game.selected_mode.fully_implemented, "a playable default mode")

	Game.debug_fill_players(2)
	Game.last_match_winner = Game.slots[0]
	for path in UI_SCENES:
		var scene: PackedScene = load(path)
		_check(scene != null, "load " + path)
		var inst := scene.instantiate()
		add_child(inst)
		await get_tree().process_frame
		inst.queue_free()
		await get_tree().process_frame
		print("[smoke] ok: " + path)

	Game.clear_players()
	for i in 3:
		var slot := Game.add_player(DeviceInput.VIRTUAL - i)
		slot.dog = Game.dogs[i]
	for slot in Game.slots:
		slot.device = DeviceInput.VIRTUAL
	Game.points_to_win = 2
	Events.round_started.connect(func(_n: int) -> void: _round_started = true)
	Events.round_over.connect(func(w: PlayerSlot) -> void:
		_rounds_won += 1
		print("[smoke] round over, winner: %s" % (w.dog.display_name if w else "draw")))
	Events.dog_eliminated.connect(func(_d: Node, _t: Node) -> void: _eliminations += 1)
	Events.toy_caught.connect(func(_t: Node, _d: Node) -> void: _caught += 1)
	Events.match_over.connect(func(w: PlayerSlot) -> void:
		print("[smoke] MATCH OVER, winner %s with %d points" % [w.dog.display_name, w.score])
		_finish())

	_phase = "match"
	_match = load("res://scenes/match/match.tscn").instantiate()
	add_child(_match)


var _debug_timer := 0.0


func _physics_process(delta: float) -> void:
	_elapsed += delta
	_debug_timer += delta
	if _debug_timer > 4.0 and _phase == "match" and OS.get_cmdline_user_args().has("--verbose"):
		_debug_timer = 0.0
		for d in _match.dogs:
			print("[smoke]   %s alive=%s pos=%s held=%s" % [d.data.display_name, d.alive, d.global_position.snapped(Vector3(0.1, 0.1, 0.1)), d.held_toy != null])
		for t in _match.toys:
			print("[smoke]   toy state=%d pos=%s speed=%.1f" % [t.state, t.global_position.snapped(Vector3(0.1, 0.1, 0.1)), t.velocity.length()])
	if _elapsed > TIMEOUT_SEC:
		_fail("timed out (rounds won: %d, eliminations: %d, catches: %d)" % [_rounds_won, _eliminations, _caught])
	if _phase != "match" or not _round_started:
		return
	# Scripted play: dog 0 re-arms from the nearest idle toy, otherwise aims at the nearest
	# living opponent and throws every 1.2 s. The target attempts exactly one catch.
	var dogs: Array[Dog] = _match.dogs
	var alive: Array[Dog] = []
	for d in dogs:
		if d.alive:
			alive.append(d)
	if alive.size() < 2:
		return
	# Roles are dynamic so the test keeps going even if the shooter eats a ricochet.
	var shooter: Dog = alive[0]
	var target: Dog = alive[1]
	shooter.input.virtual_buttons[&"throw"] = false
	if shooter.held_toy == null:
		var nearest: Toy = null
		for t in _match.toys:
			if t.state == Toy.State.IDLE and (nearest == null or t.global_position.distance_to(shooter.global_position) < nearest.global_position.distance_to(shooter.global_position)):
				nearest = t
		if nearest:
			shooter.input.virtual_move = dir_to(shooter, nearest)
		_throw_timer = 0.0
	else:
		shooter.input.virtual_move = dir_to(shooter, target)
		_throw_timer += delta
		if _throw_timer > 1.2:
			_throw_timer = 0.0
			shooter.input.virtual_buttons[&"throw"] = true
	# If the shooter is pushing against a prop, sidestep for a moment (props block the straight line).
	var moved := shooter.global_position.distance_to(_last_shooter_pos)
	_last_shooter_pos = shooter.global_position
	if _detour_timer > 0.0:
		_detour_timer -= delta
		shooter.input.virtual_move = _detour_dir
	elif shooter.input.virtual_move != Vector2.ZERO and moved < 0.01:
		_stuck_time += delta
		if _stuck_time > 0.5:
			_stuck_time = 0.0
			var m := shooter.input.virtual_move
			_detour_dir = Vector2(-m.y, m.x) * (1.0 if randf() < 0.5 else -1.0)
			_detour_timer = 0.9
	else:
		_stuck_time = 0.0
	# The target first throws its own toy away (you can't catch while holding), then tries to
	# catch: press when an incoming toy will reach it within the buffered catch window.
	target.input.virtual_buttons[&"throw"] = false
	var side := Vector2(-dir_to(shooter, target).y, dir_to(shooter, target).x)
	target.input.virtual_move = side
	if target.held_toy != null:
		_target_throw_timer += delta
		if _target_throw_timer > 0.5:
			_target_throw_timer = 0.0
			target.input.virtual_buttons[&"throw"] = true
	elif _caught == 0:
		for t in _match.toys:
			if _incoming(t, target):
				target.input.virtual_buttons[&"throw"] = true
				break


## True when a dangerous toy is flying at the dog and will arrive inside its catch window.
static func _incoming(t: Toy, dog: Dog) -> bool:
	if not t.is_dangerous() or not t.can_be_caught_by(dog):
		return false
	var to_dog := dog.global_position - t.global_position
	to_dog.y = 0.0
	var speed := t.velocity.length()
	var dir := t.velocity / speed
	var along := to_dog.dot(dir)
	if along <= 0.0:
		return false
	var lateral := (to_dog - dir * along).length()
	if lateral > dog.data.body_radius + t.data.radius:
		return false
	var time_to_impact := along / speed
	return time_to_impact < dog.data.catch_window * 0.75 or along < dog.data.catch_radius


func _finish() -> void:
	if _failed:
		return
	_check(_eliminations >= 2, "at least two eliminations happened (got %d)" % _eliminations)
	_check(_rounds_won >= 2, "at least two rounds were won (got %d)" % _rounds_won)
	_check(_caught >= 1, "at least one catch happened (got %d)" % _caught)
	if _failed:
		return
	print("[smoke] PASSED in %.1fs (eliminations=%d, catches=%d)" % [_elapsed, _eliminations, _caught])
	get_tree().quit(0)


func _check(cond: bool, what: String) -> void:
	if not cond:
		_fail("check failed: " + what)


func _fail(msg: String) -> void:
	if _failed:
		return
	_failed = true
	push_error("[smoke] FAILED: " + msg)
	printerr("[smoke] FAILED: " + msg)
	get_tree().quit(1)
