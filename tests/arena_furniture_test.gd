extends Node
## Portals and switch-driven gates: the interactive furniture in Warp Yard.
##
## These are the only arena pieces that move a body without the body asking, so a regression here
## either strands a dog inside geometry or bounces it between portals forever.

var failed := false
var game_match: Node


func _ready() -> void:
	Sfx.enabled = false
	Game.tutorial_shown = true
	Game.powerups_enabled = false
	Game.random_arena_each_round = false
	Game.clear_players()
	for i in 4:
		var slot := PlayerSlot.new()
		slot.index = i
		slot.device = DeviceInput.VIRTUAL
		slot.dog = Game.dogs[i]
		Game.slots.append(slot)
	var warp: ArenaData = null
	for arena_data in Game.arenas:
		if arena_data.id == &"warp_yard":
			warp = arena_data
	_check(warp != null, "Warp Yard is registered")
	if warp == null:
		get_tree().quit(1)
		return
	Game.selected_arena = warp
	game_match = load("res://scenes/match/match.tscn").instantiate()
	add_child(game_match)
	await get_tree().physics_frame
	# Actors are frozen through the countdown, so nothing overlaps anything until play starts.
	while game_match.phase != game_match.Phase.PLAYING:
		await get_tree().process_frame
	await get_tree().physics_frame

	var portals: Array[Portal] = []
	for node in game_match.arena.find_children("*", "Area3D", true, false):
		if node is Portal:
			portals.append(node)
	var gates: Array[Gate] = []
	for node in game_match.arena.find_children("*", "StaticBody3D", true, false):
		if node is Gate:
			gates.append(node)
	var switches: Array[SwitchPad] = []
	for node in game_match.arena.find_children("*", "Area3D", true, false):
		if node is SwitchPad:
			switches.append(node)
	_check(portals.size() == 4, "the yard has two portal pairs")
	_check(gates.size() == 2, "the yard has two gates")
	_check(switches.size() == 2, "both halves get a switch")

	# Every portal must know its partner, and the pairing must be mutual: a one-way link is a
	# trap, because whatever went through can never come back.
	for portal in portals:
		_check(portal.partner != null, "%s is linked" % portal.name)
		if portal.partner != null:
			_check(portal.partner.partner == portal, "%s's link is two-way" % portal.name)
			_check(portal.partner != portal, "%s does not link to itself" % portal.name)

	await _a_dog_travels(portals)
	await _a_throw_travels(portals)
	await _a_switch_moves_the_gates(switches, gates)
	await _a_closed_gate_blocks(gates)

	if not failed:
		print("[arena-furniture] PASSED: linked portals, dog and toy transit, no ping-pong, switches and gate collision")
	get_tree().quit(1 if failed else 0)


## Four bots share this arena and will happily wander onto a switch mid-assertion, which would
## make every gate check a coin flip. Park everyone the test is not driving.
func _park_everyone_except(keep: Dog) -> void:
	for dog: Dog in game_match.dogs:
		if dog == keep or not is_instance_valid(dog):
			continue
		dog.process_mode = Node.PROCESS_MODE_DISABLED
		dog.global_position = Vector3(0, -40, 0)


func _check(ok: bool, message: String) -> void:
	if not ok:
		failed = true
		push_error("[arena-furniture] " + message)


## A dog that walks in comes out at the far end, and does NOT get grabbed straight back.
func _a_dog_travels(portals: Array[Portal]) -> void:
	var portal: Portal = portals[0]
	var dog: Dog = game_match.dogs[0]
	var exit_portal: Portal = portal.partner
	dog.velocity = Vector3(0, 0, 4.0)
	dog.global_position = portal.global_position
	await get_tree().physics_frame
	await get_tree().physics_frame
	var landed := Vector2(dog.global_position.x - exit_portal.global_position.x,
		dog.global_position.z - exit_portal.global_position.z).length()
	_check(landed < exit_portal.radius + 2.0, "a dog walking into a portal comes out of its partner")
	_check(dog.alive, "warping does not hurt")
	# The exit must not immediately fire and send them back where they came from.
	var was_at := dog.global_position
	for _i in 4:
		await get_tree().physics_frame
	var drift := Vector2(dog.global_position.x - was_at.x, dog.global_position.z - was_at.z).length()
	_check(drift < 3.0, "a dog is not bounced straight back through the portal it came out of")


## A throw keeps going after the warp, which is the whole point: aim through one, hit someone
## standing by the other.
func _a_throw_travels(portals: Array[Portal]) -> void:
	var portal: Portal = portals[2]
	var exit_portal: Portal = portal.partner
	var toy: Toy = game_match.toys[0]
	toy.state = Toy.State.FLYING
	toy.thrower = game_match.dogs[1]
	toy.velocity = Vector3(0, 0, 14.0)
	toy.global_position = portal.global_position + Vector3(0, Toy.FLY_HEIGHT, 0)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var gap := Vector2(toy.global_position.x - exit_portal.global_position.x,
		toy.global_position.z - exit_portal.global_position.z).length()
	_check(gap < exit_portal.radius + 3.5, "a thrown toy comes out of the far portal")
	_check(toy.velocity.z > 0.0, "the throw keeps its heading through the warp")


## Standing on a paw switch moves both gates; standing on it again moves them back.
func _a_switch_moves_the_gates(switches: Array[SwitchPad], gates: Array[Gate]) -> void:
	var pad: SwitchPad = switches[0]
	var dog: Dog = game_match.dogs[2]
	_park_everyone_except(dog)
	# This one is a bot too: left to itself it wanders onto the pad mid-assertion. Stop it
	# steering and drive it by hand, so every press in this test is one the test made.
	dog.set_physics_process(false)
	await get_tree().physics_frame
	var before: Array[bool] = []
	for gate in gates:
		before.append(gate.is_open)
	dog.global_position = pad.global_position
	await get_tree().physics_frame
	await get_tree().physics_frame
	for i in gates.size():
		var gate: Gate = gates[i]
		_check(gate.is_open != before[i], "stepping on a switch moves %s" % gate.name)
	# Walk off, wait out the re-arm, and step back on: the gates return.
	dog.global_position = pad.global_position + Vector3(-3.4, 0, 0)
	await get_tree().create_timer(SwitchPad.REARM + 0.3).timeout
	dog.global_position = pad.global_position
	# Re-entry into an area a body has just left takes longer to report than a first entry:
	# two physics frames is not enough, and a short wait is what makes this reliable.
	await get_tree().create_timer(0.3).timeout
	for i in gates.size():
		var gate: Gate = gates[i]
		_check(gate.is_open == before[i], "a second press puts %s back" % gate.name)


## A gate is real geometry when it is up and nothing at all when it is down. Toys are placed with
## is_clear_position, so a gate that never blocks would let a toy spawn inside it.
func _a_closed_gate_blocks(gates: Array[Gate]) -> void:
	var gate: Gate = gates[0]
	_park_everyone_except(null)
	await get_tree().physics_frame
	gate.set_open(false)
	await get_tree().create_timer(Gate.TRAVEL + 0.2).timeout
	_check(not game_match.arena.is_clear_position(gate.global_position, 0.4), "a closed gate blocks the way")
	gate.set_open(true)
	await get_tree().create_timer(Gate.TRAVEL + 0.2).timeout
	_check(game_match.arena.is_clear_position(gate.global_position, 0.4), "an open gate lets everyone through")
