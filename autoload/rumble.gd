extends Node
## Controller rumble, driven entirely from Events: a hard thump when you are bonked, a short kick
## when your throw bonks someone, a tap on a catch, a buzz when you are whacked, and a tick when
## a wind-up reaches full power. Keyboards and bots have nothing to shake, so they are skipped.
##
## Strengths are (weak motor, strong motor, seconds). Off entirely when Game.rumble is false.

const BONKED := Vector3(0.7, 1.0, 0.38)
const BONKED_SOMEONE := Vector3(0.35, 0.25, 0.12)
const CAUGHT := Vector3(0.45, 0.0, 0.09)
const WHACKED := Vector3(0.5, 0.55, 0.2)
const CHARGED := Vector3(0.3, 0.0, 0.06)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Events.dog_eliminated.connect(_on_eliminated)
	Events.toy_caught.connect(func(_toy: Node, by: Node) -> void: buzz(by, CAUGHT))
	Events.dog_whacked.connect(func(dog: Node, _by: Node) -> void: buzz(dog, WHACKED))
	Events.toy_blocked.connect(func(dog: Node, _toy: Node) -> void: buzz(dog, WHACKED))
	Events.throw_charged.connect(func(dog: Node) -> void: buzz(dog, CHARGED))
	# Nothing should still be shaking behind a pause menu or a scene change.
	Events.round_over.connect(func(_winner: PlayerSlot) -> void: stop_all())


func _on_eliminated(dog: Node, by: Node) -> void:
	buzz(dog, BONKED)
	var credited: Dog = (dog as Dog).knocked_out_by(by) if dog is Dog else null
	if credited != null and credited != dog:
		buzz(credited, BONKED_SOMEONE)


## Shakes the pad of the player behind [param dog], if they are holding one.
func buzz(dog: Node, strength: Vector3) -> void:
	if not Game.rumble or not is_instance_valid(dog) or not dog is Dog:
		return
	var slot: PlayerSlot = (dog as Dog).slot
	if slot == null or slot.is_bot or slot.device < 0:
		return
	Input.start_joy_vibration(slot.device, strength.x, strength.y, strength.z)


func stop_all() -> void:
	for device in Input.get_connected_joypads():
		Input.stop_joy_vibration(device)
