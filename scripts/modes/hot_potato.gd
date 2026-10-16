class_name HotPotato
extends LastDogStanding
## Hot Potato: a game of tag with a bomb. There is one toy in the yard - the hot potato - and it
## starts in a random dog's mouth with a fuse nobody can see. Whoever has it is IT. Throwing it
## does not bonk anyone: hit a rival and it lands in *their* mouth, and now they are IT (with a
## beat of hot hands before they can fling it back). Miss, and you are still IT until someone
## else picks it up - so a wild throw buys nothing. A dash dodges it.
##
## It heats from yellow to angry red as the fuse burns and ticks faster towards the end; the
## last three seconds count down over IT's head. When it blows, IT is out, and a beat later the
## potato turns up in another dog's mouth on a fresh fuse. Last dog standing wins the round.
##
## Nothing else muddies it: no other toys, no crates, no supply drops, no sky drops, no clock.

const FUSE_MIN := 6.0
const FUSE_MAX := 11.0
## The fuse counts down in numbers over IT's head for this long.
const SHOW_COUNTDOWN := 3.0
## Ticking starts, slow, this long before it blows, and speeds up.
const TICK_FROM := 6.0
## Between a blast and the potato turning up in the next dog's mouth.
const REDEAL := 1.3

var hot: Toy
var fuse := 0.0
var fuse_total := 1.0
## Whoever had it last. Still IT while the potato lies loose.
var it: Dog
var _dealing := 0.0
var _it_label: Label3D
var _heat_material: StandardMaterial3D
var _tick_clock := 0.0
var _shown_it: Dog
var _rng := RandomNumberGenerator.new()


func spawns_round_toys() -> bool:
	return false


func allows_treats() -> bool:
	return false


func allows_supply_drops() -> bool:
	return false


func allows_sudden_death() -> bool:
	return false


## A blast is final: pack-mates reviving the dog who was IT would keep a round going for ever.
func allows_revives() -> bool:
	return false


## Every blast takes a dog out, so the round always ends on its own: no clock to run down.
func round_seconds(_default: float) -> float:
	return 999.0


func on_round_start(dogs: Array[Dog]) -> void:
	_rng.randomize()
	if is_instance_valid(hot):
		game_match.toys.erase(hot)
		hot.queue_free()
	if is_instance_valid(_it_label):
		_it_label.queue_free()
	it = null
	_shown_it = null
	var bone: ToyData = null
	for item in Game.toys:
		if item.id == &"bone":
			bone = item
	hot = game_match._spawn_toy(Vector3.ZERO, bone if bone != null else Game.toys[0])
	hot.tag_only = true
	_heat_material = StandardMaterial3D.new()
	_heat_material.emission_enabled = true
	_heat_material.roughness = 0.5
	for mesh in hot.model.find_children("*", "MeshInstance3D", true, false):
		(mesh as MeshInstance3D).material_override = _heat_material
	_it_label = Label3D.new()
	_it_label.font = UiKit.FONT_DISPLAY
	_it_label.font_size = 92
	_it_label.outline_size = 22
	_it_label.pixel_size = 0.008
	_it_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_it_label.no_depth_test = true
	_it_label.outline_modulate = Color(0.2, 0.04, 0.02)
	game_match.actors.add_child(_it_label)
	_deal(dogs)


## Into a random dog's mouth, on a fresh fuse nobody can see.
func _deal(dogs: Array[Dog]) -> void:
	var standing := dogs.filter(func(dog: Dog) -> bool: return is_instance_valid(dog) and dog.alive)
	if standing.is_empty() or not is_instance_valid(hot):
		return
	var lucky := standing[_rng.randi() % standing.size()] as Dog
	hot.visible = true
	hot.process_mode = Node.PROCESS_MODE_INHERIT
	hot.global_position = lucky.global_position
	hot.pick_up(lucky)
	it = lucky
	fuse_total = _rng.randf_range(FUSE_MIN, FUSE_MAX)
	fuse = fuse_total
	_tick_clock = 0.0
	Juice.burst(game_match.actors, lucky.global_position + Vector3.UP * 0.8, Color("ff8a3d"), 20, 4.0)
	Juice.float_text(game_match.actors, lucky.global_position + Vector3.UP * 2.2, "YOU'RE IT!", Color("ffb36b"), 0.9)
	Sfx.play_at("fuse", lucky.global_position, 1.0, -4.0)


func tick(delta: float, dogs: Array[Dog]) -> void:
	if not is_instance_valid(hot):
		return
	if _dealing > 0.0:
		_dealing -= delta
		_it_label.visible = false
		if _dealing <= 0.0:
			_deal(dogs)
		return
	if is_instance_valid(hot.holder):
		it = hot.holder
	if it != _shown_it:
		_on_new_it()
	fuse -= delta
	var heat := clampf(1.0 - fuse / fuse_total, 0.0, 1.0)
	_heat(heat)
	if is_instance_valid(it):
		_it_label.visible = true
		_it_label.global_position = it.global_position + Vector3(0, 2.45 + sin(Time.get_ticks_msec() * 0.012) * 0.08, 0)
		_it_label.text = str(ceili(maxf(fuse, 0.01))) if fuse <= SHOW_COUNTDOWN else "IT!"
		_it_label.modulate = Color(1.0, 0.85, 0.4).lerp(Color(1.0, 0.25, 0.15), heat)
		_it_label.font_size = 92 + (int((SHOW_COUNTDOWN - fuse) * 18.0) if fuse <= SHOW_COUNTDOWN else 0)
	if fuse <= TICK_FROM:
		_tick_clock -= delta
		if _tick_clock <= 0.0:
			_tick_clock = clampf(fuse / TICK_FROM, 0.12, 1.0) * 0.55
			Sfx.play_at("tick", hot.global_position, 1.2 + heat * 0.8, -4.0)
	if fuse <= 0.0:
		_blow(dogs)


## The potato goes from warm yellow to angry, pulsing red as the fuse burns - fast enough by
## the end that everyone can feel it coming without a number until the very last seconds.
func _heat(heat: float) -> void:
	var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() * (0.006 + heat * 0.03))
	var colour := Color(1.0, 0.86, 0.35).lerp(Color(1.0, 0.18, 0.08), heat)
	_heat_material.albedo_color = colour
	_heat_material.emission = colour
	_heat_material.emission_energy_multiplier = 0.4 + heat * 1.6 + pulse * heat * 1.2


func _on_new_it() -> void:
	var was := _shown_it
	_shown_it = it
	if not is_instance_valid(it) or not is_instance_valid(was):
		return
	Juice.float_text(game_match.actors, it.global_position + Vector3.UP * 2.0, "TAG!", Color("ffb36b"), 0.9)
	Juice.burst(game_match.actors, it.global_position + Vector3.UP * 0.8, Color("ff8a3d"), 14, 4.5)
	Sfx.play_at("squeak", it.global_position, 0.8, -3.0)


func _blow(dogs: Array[Dog]) -> void:
	var at := hot.global_position
	var victim := it
	if not is_instance_valid(victim) or not victim.alive:
		# Nobody is IT (should not happen): the dog nearest the potato takes it.
		var best := INF
		for dog in dogs:
			if dog.alive and dog.global_position.distance_to(at) < best:
				best = dog.global_position.distance_to(at)
				victim = dog
	if is_instance_valid(victim):
		at = victim.global_position
	Juice.shake(0.4)
	Juice.burst(game_match.actors, at + Vector3.UP * 0.7, Color("fff1c4"), 28, 9.0)
	Juice.burst(game_match.actors, at + Vector3.UP * 0.7, Color("ff7a3d"), 30, 6.0)
	Juice.float_text(game_match.actors, at + Vector3.UP * 2.2, "KABOOM!", Color(1.0, 0.6, 0.3), 1.2)
	Sfx.play_at("blast", at, 0.85, 1.0)
	if is_instance_valid(hot.holder):
		hot.holder.held_toy = null
	hot.drop(at)
	hot.visible = false
	hot.process_mode = Node.PROCESS_MODE_DISABLED
	it = null
	_shown_it = null
	_dealing = REDEAL
	if is_instance_valid(victim) and victim.alive:
		victim.eliminate(null, Vector3.BACK)


## Not IT: leave the potato alone - picking it up makes you IT.
func bot_avoids(dog: Dog, toy: Toy) -> bool:
	return toy == hot and dog != it


## IT and empty-pawed: go and get it back. Not IT: keep clear of whoever is.
func bot_goal(dog: Dog) -> Vector3:
	if not is_instance_valid(hot) or _dealing > 0.0:
		return Vector3.INF
	if dog == it:
		return hot.global_position if hot.holder != dog else Vector3.INF
	if not is_instance_valid(it):
		return Vector3.INF
	var away := Vector3(dog.global_position.x - it.global_position.x, 0, dog.global_position.z - it.global_position.z)
	if away.length() > 7.0:
		return Vector3.INF
	away = away.normalized() if away.length() > 0.05 else Vector3.RIGHT
	var half: Vector2 = game_match.arena.size * 0.5
	var spot := dog.global_position + away * 4.0
	return Vector3(clampf(spot.x, -half.x + 1.5, half.x - 1.5), 0, clampf(spot.z, -half.y + 1.5, half.y - 1.5))


## Holding the potato: get rid of it at the first decent shot.
func bot_should_throw_now(_dog: Dog, toy: Toy) -> bool:
	return toy == hot


func hud_status(dog: Dog) -> String:
	if _dealing > 0.0:
		return "WHO'S NEXT?"
	if dog == it:
		return "YOU'RE IT! TAG SOMEONE" if dog.held_toy == hot else "YOU'RE IT! GET THE POTATO"
	return "STAY AWAY FROM IT · DASH TO DODGE"


func hud_hint() -> String:
	return "Tag a rival with the hot potato before it blows · last dog standing wins"
