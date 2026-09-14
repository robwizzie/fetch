extends Node
## Runs one match: instantiates the chosen arena, spawns dogs and toys for each round,
## runs the countdown, asks the GameMode who won, tracks points, hands off to results.

enum Phase { COUNTDOWN, PLAYING, ROUND_OVER, MATCH_OVER }

const DOG_SCENE := preload("res://scenes/actors/dog.tscn")
const TOY_SCENE := preload("res://scenes/actors/toy.tscn")
const EXTRA_GROUND_TOYS := 1

var arena: Arena
var dogs: Array[Dog] = []
var toys: Array[Toy] = []
var mode: GameMode
var phase := Phase.COUNTDOWN
var round_number := 0

@onready var arena_holder: Node2D = $ArenaHolder
@onready var actors: Node2D = $Actors
@onready var hud: Hud = $HUD


func _ready() -> void:
	if Game.slots.is_empty():
		Game.debug_fill_players(2)
	mode = Game.selected_mode.mode_script.new()
	mode.setup(self)
	arena = Game.selected_arena.scene.instantiate()
	arena_holder.add_child(arena)
	hud.setup(Game.slots, mode.hud_hint())
	Events.dog_eliminated.connect(_on_dog_eliminated)
	start_round()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		Game.goto(Game.SCENE_MAIN_MENU)


func start_round() -> void:
	round_number += 1
	phase = Phase.COUNTDOWN
	_clear_actors()
	actors.process_mode = Node.PROCESS_MODE_DISABLED

	for i in Game.slots.size():
		var slot := Game.slots[i]
		var dog: Dog = DOG_SCENE.instantiate()
		dog.setup(slot)
		dog.position = arena.get_spawn_position(i)
		dog.facing = (arena.size / 2.0 - dog.position).normalized()
		actors.add_child(dog)
		dogs.append(dog)
		# Everyone starts holding a toy so the action begins immediately.
		var toy := _spawn_toy(dog.get_hold_position())
		toy.pick_up(dog)

	for i in EXTRA_GROUND_TOYS:
		_spawn_toy(arena.get_toy_spawn_position(i))

	mode.on_round_start(dogs)
	await hud.countdown(round_number)
	if not is_inside_tree() or phase != Phase.COUNTDOWN:
		return
	phase = Phase.PLAYING
	actors.process_mode = Node.PROCESS_MODE_INHERIT
	Sfx.play("whistle")
	Events.round_started.emit(round_number)


func _spawn_toy(at: Vector2) -> Toy:
	var toy: Toy = TOY_SCENE.instantiate()
	toy.setup(Game.selected_toy)
	toy.position = at
	actors.add_child(toy)
	toys.append(toy)
	return toy


func _clear_actors() -> void:
	dogs.clear()
	toys.clear()
	for c in actors.get_children():
		c.queue_free()


func _on_dog_eliminated(dog: Node, _by: Node) -> void:
	if phase != Phase.PLAYING:
		return
	mode.on_dog_eliminated(dog)
	if mode.is_round_over(dogs):
		phase = Phase.ROUND_OVER
		_end_round(mode.round_winner(dogs))


func _end_round(winner: PlayerSlot) -> void:
	if winner:
		winner.score += 1
		hud.refresh_scores()
	Events.round_over.emit(winner)
	Sfx.play("fanfare" if winner else "tick")
	var text := "%s wins the round!" % winner.dog.display_name if winner else "Nobody wins. Ruff."
	var color := winner.color if winner else Color.WHITE
	await hud.banner(text, color, 2.2)
	if not is_inside_tree():
		return
	if winner and winner.score >= Game.points_to_win:
		phase = Phase.MATCH_OVER
		Game.last_match_winner = winner
		Events.match_over.emit(winner)
		Game.goto(Game.SCENE_RESULTS)
	else:
		start_round()
