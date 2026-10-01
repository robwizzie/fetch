class_name KingOfTheBed
extends LastDogStanding
## King of the Bed: one big dog bed in the middle. Lie on it alone - one dog, or one pack in
## teams - and your time banks. First to CLAIM_TIME takes the round; knocking everyone else out
## still wins it; when the clock runs out, whoever banked most wins.

const CLAIM_TIME := 8.0
const RADIUS := 1.7

var bed_centre := Vector3.ZERO
var banked: Dictionary = {}
var _bed: Node3D
var _fill: MeshInstance3D
var _fill_material: StandardMaterial3D
var _label: Label3D
var _winner: PlayerSlot
var _cheer := 0.0


func on_round_start(_dogs: Array[Dog]) -> void:
	banked.clear()
	_winner = null
	if is_instance_valid(_bed):
		_bed.queue_free()
	bed_centre = _pick_spot()
	_bed = Node3D.new()
	_bed.name = "KingsBed"
	game_match.actors.add_child(_bed)
	_bed.global_position = Vector3(bed_centre.x, 0.0, bed_centre.z)
	# A round, low, plush bed: readable as a place to stand, never solid.
	var rim := Mats.mesh(_bed, Mats.torus(RADIUS - 0.25, RADIUS), Color("8a5a3c"), Vector3(0, 0.1, 0))
	rim.scale = Vector3(1, 2.2, 1)
	var cushion := Mats.mesh(_bed, Mats.cylinder(RADIUS - 0.2, 0.08), Color("f0dcc0"), Vector3(0, 0.05, 0))
	cushion.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_fill = Mats.mesh(_bed, Mats.cylinder(RADIUS - 0.25, 0.02), Color.WHITE, Vector3(0, 0.1, 0))
	_fill_material = Mats.unlit(Color(1, 1, 1, 0.0))
	_fill.material_override = _fill_material
	_fill.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ArenaArt.paw(_bed, Vector3(0, 0.12, 0), 0.7, Color("d9b88f"))
	_label = Label3D.new()
	_label.font = UiKit.FONT_DISPLAY
	_label.font_size = 64
	_label.outline_size = 18
	_label.pixel_size = 0.008
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.no_depth_test = true
	_label.position = Vector3(0, 2.7, 0)
	_label.outline_modulate = Color(0.12, 0.08, 0.06)
	_label.text = "KING OF THE BED"
	_bed.add_child(_label)


## Near the middle, but not on water, grass, a sprinkler or anything else the arena is already
## doing there: the bed should be the one thing going on where it sits.
func _pick_spot() -> Vector3:
	var arena: Arena = game_match.arena
	var busy: Array[Vector3] = []
	for node in arena.find_children("*", "", true, false):
		if node is SlowZone or node.is_in_group("gimmicks"):
			busy.append((node as Node3D).global_position)
	for offset in [Vector3.ZERO, Vector3(0, 0, -3.2), Vector3(0, 0, 3.2), Vector3(-4.0, 0, 0), Vector3(4.0, 0, 0),
			Vector3(-4.0, 0, -3.2), Vector3(4.0, 0, 3.2)]:
		var spot := arena.clear_pickup_position(offset, RADIUS * 0.8)
		var clear := true
		for other in busy:
			if Vector2(other.x - spot.x, other.z - spot.z).length() < RADIUS + 2.6:
				clear = false
		if clear:
			return spot
	return arena.clear_pickup_position(Vector3.ZERO, RADIUS * 0.6)


## One side on the bed alone: that side's slot (any of its dogs). Null when empty or contested.
func holder(dogs: Array[Dog]) -> PlayerSlot:
	var on: Array[Dog] = []
	for dog in dogs:
		if dog.alive and Vector2(dog.global_position.x - bed_centre.x, dog.global_position.z - bed_centre.z).length() < RADIUS:
			on.append(dog)
	if on.is_empty():
		return null
	for dog in on:
		if not dog.slot.allied_with(on[0].slot):
			return null
	return on[0].slot


func _key(slot: PlayerSlot) -> int:
	return slot.team if Game.team_mode and slot.team >= 0 else 100 + slot.index


func tick(delta: float, dogs: Array[Dog]) -> void:
	if not is_instance_valid(_bed):
		return
	var king := holder(dogs)
	if king == null:
		_fill_material.albedo_color.a = move_toward(_fill_material.albedo_color.a, 0.0, delta * 2.0)
		_label.text = "KING OF THE BED"
		_label.modulate = Color("fff3d8")
		return
	var key := _key(king)
	banked[key] = float(banked.get(key, 0.0)) + delta
	var progress := minf(1.0, banked[key] / CLAIM_TIME)
	_fill_material.albedo_color = Color(king.color, 0.35 + progress * 0.4)
	_fill.scale = Vector3(progress, 1, progress)
	_label.modulate = king.color
	_label.text = "%s  %.1f / %d" % [king.label, banked[key], int(CLAIM_TIME)]
	_cheer -= delta
	if _cheer <= 0.0:
		_cheer = 1.0
		Sfx.play_at("tick", _bed.global_position, 1.0 + progress, -8.0)
	if banked[key] >= CLAIM_TIME:
		_winner = king


func is_round_over(dogs: Array[Dog]) -> bool:
	return _winner != null or super.is_round_over(dogs)


func round_winner(dogs: Array[Dog]) -> PlayerSlot:
	return _winner if _winner != null else super.round_winner(dogs)


func timeout_winner(dogs: Array[Dog]) -> PlayerSlot:
	var best_key := -1
	var best := 0.0
	for key in banked:
		if banked[key] > best:
			best = banked[key]
			best_key = key
	if best_key < 0:
		return null
	# Anyone within a twentieth of a second of the leader makes it a tie.
	for key in banked:
		if key != best_key and best - banked[key] <= 0.05:
			return null
	for dog in dogs:
		if _key(dog.slot) == best_key:
			return dog.slot
	return null


func bot_goal(_dog: Dog) -> Vector3:
	return bed_centre if is_instance_valid(_bed) else Vector3.INF


func hud_hint() -> String:
	return "Hold the dog bed alone for %d seconds · or be the last dog standing" % int(CLAIM_TIME)
