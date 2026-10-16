class_name GoldenBall
extends LastDogStanding
## Golden Ball: one toy each round is golden. While it is in your mouth, your time banks - one
## dog, or one pack in teams. First to CLAIM_TIME takes the round; on the clock, whoever banked
## most wins. So the holder runs and keeps it, everyone else bonks them or whacks it loose - and
## throwing it is giving it away. Bonked dogs come back after a moment (GameMode.RESPAWN_TIME)
## with their time kept: the round is a chase for the ball, never decided by the last dog up.
## Carrying it slows you a touch (CARRY_SLOW), so a chase can be won.

const CLAIM_TIME := 8.0
const CARRY_SLOW := 0.88

var golden: Toy
var banked: Dictionary = {}
var _marker: Node3D
var _ring: MeshInstance3D
var _label: Label3D
var _gauge: ChargeMeter
var _carrier: Dog
var _winner: PlayerSlot
var _cheer := 0.0


func on_round_start(_dogs: Array[Dog]) -> void:
	banked.clear()
	_winner = null
	golden = null
	if is_instance_valid(_marker):
		_marker.queue_free()
	for toy in game_match.toys:
		if is_instance_valid(toy) and not toy.ephemeral:
			golden = toy
			break
	if golden == null:
		return
	# Gold and glowing, so it is never mistaken for an ordinary toy.
	var gold := StandardMaterial3D.new()
	gold.albedo_color = Color(1.0, 0.82, 0.3)
	gold.metallic = 0.6
	gold.roughness = 0.3
	gold.emission_enabled = true
	gold.emission = Color(1.0, 0.75, 0.25)
	gold.emission_energy_multiplier = 0.7
	for mesh in golden.model.find_children("*", "MeshInstance3D", true, false):
		(mesh as MeshInstance3D).material_override = gold
	_marker = Node3D.new()
	_marker.name = "GoldenBallMarker"
	game_match.actors.add_child(_marker)
	_ring = Mats.mesh(_marker, Mats.torus(0.5, 0.62), Palette.GOLD)
	_ring.material_override = Mats.unlit(Color(1.0, 0.84, 0.3, 0.9))
	_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_label = Label3D.new()
	_label.font = UiKit.FONT_DISPLAY
	_label.font_size = 64
	_label.outline_size = 18
	_label.pixel_size = 0.008
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.no_depth_test = true
	_label.position = Vector3(0, 1.5, 0)
	_label.modulate = Color("ffe08a")
	_label.outline_modulate = Color(0.25, 0.16, 0.02)
	_label.text = "GOLDEN BALL"
	_marker.add_child(_label)
	# The holder's progress, as a gold gauge filling round their feet.
	_gauge = ChargeMeter.new()
	_marker.add_child(_gauge)
	_gauge.setup(Palette.GOLD, 0.55)
	_gauge.hide_meter()


## The side holding the golden ball right now, or null.
func holder() -> PlayerSlot:
	if not is_instance_valid(golden) or not is_instance_valid(golden.holder) or not golden.holder.alive:
		return null
	return golden.holder.slot


func _key(slot: PlayerSlot) -> int:
	return slot.team if Game.team_mode and slot.team >= 0 else 100 + slot.index


func tick(delta: float, _dogs: Array[Dog]) -> void:
	if not is_instance_valid(golden) or not is_instance_valid(_marker):
		return
	var at := golden.global_position
	# Round the holder's feet while carried; round the ball itself while it is loose.
	if golden.state == Toy.State.HELD and is_instance_valid(golden.holder):
		at = golden.holder.global_position
	_marker.global_position = Vector3(at.x, 0.05, at.z)
	_ring.rotation.y += delta * 2.0
	var owner := holder()
	var carrier := golden.holder if owner != null else null
	if carrier != _carrier:
		if is_instance_valid(_carrier):
			_carrier.clear_slow(_marker)
		_carrier = carrier
		if is_instance_valid(_carrier):
			_carrier.set_slow(_marker, CARRY_SLOW)
	if owner == null:
		_label.text = "GOLDEN BALL"
		_label.modulate = Color("ffe08a")
		_gauge.hide_meter()
		return
	var key := _key(owner)
	banked[key] = float(banked.get(key, 0.0)) + delta
	_gauge.set_charge(minf(1.0, banked[key] / CLAIM_TIME), Vector3.FORWARD)
	_label.modulate = owner.color.lightened(0.2)
	_label.text = "%s  %.1f / %d" % [owner.label, banked[key], int(CLAIM_TIME)]
	_cheer -= delta
	if _cheer <= 0.0:
		_cheer = 1.0
		Sfx.play_at("tick", at, 1.0 + banked[key] / CLAIM_TIME, -8.0)
	if banked[key] >= CLAIM_TIME:
		_winner = owner


func is_round_over(_dogs: Array[Dog]) -> bool:
	return _winner != null


func round_winner(_dogs: Array[Dog]) -> PlayerSlot:
	return _winner


func respawns() -> bool:
	return true


func respawn_avoid() -> Array[Vector3]:
	var avoid: Array[Vector3] = []
	if is_instance_valid(golden):
		avoid.append(golden.global_position)
	return avoid


func timeout_winner(dogs: Array[Dog]) -> PlayerSlot:
	var best_key := -1
	var best := 0.0
	for key in banked:
		if banked[key] > best:
			best = banked[key]
			best_key = key
	if best_key < 0:
		return null
	for key in banked:
		if key != best_key and best - banked[key] <= 0.05:
			return null
	for dog in dogs:
		if _key(dog.slot) == best_key:
			return dog.slot
	return null


## Loose: everyone goes for it. Held by a rival: go and get it back. Held by us: keep away from
## whoever is nearest.
func bot_goal(dog: Dog) -> Vector3:
	if not is_instance_valid(golden):
		return Vector3.INF
	if golden.holder == dog:
		var nearest: Dog = null
		for other in game_match.dogs:
			if is_instance_valid(other) and other.alive and other != dog and not dog.slot.allied_with(other.slot):
				if nearest == null or dog.global_position.distance_to(other.global_position) < dog.global_position.distance_to(nearest.global_position):
					nearest = other
		if nearest == null:
			return Vector3.INF
		var away := Vector3(dog.global_position.x - nearest.global_position.x, 0, dog.global_position.z - nearest.global_position.z).normalized()
		var half: Vector2 = game_match.arena.size * 0.5
		var spot := dog.global_position + away * 4.0
		return Vector3(clampf(spot.x, -half.x + 1.5, half.x - 1.5), 0, clampf(spot.z, -half.y + 1.5, half.y - 1.5))
	if is_instance_valid(golden.holder) and golden.holder.slot.allied_with(dog.slot):
		return Vector3.INF
	return golden.global_position


func hud_status(dog: Dog) -> String:
	if not is_instance_valid(golden):
		return ""
	if golden.holder == dog:
		return "HOLD ON! %.1f / %d" % [float(banked.get(_key(dog.slot), 0.0)), int(CLAIM_TIME)]
	if is_instance_valid(golden.holder) and golden.holder.slot.allied_with(dog.slot):
		return "PROTECT YOUR PACK-MATE"
	return "GET THE GOLDEN BALL"


func bot_keeps(_dog: Dog, toy: Toy) -> bool:
	return toy == golden


func hud_hint() -> String:
	return "Keep the golden ball in your mouth for %d seconds · bonked? Back in a moment, time kept" % int(CLAIM_TIME)
