extends Node
## Physics regressions for floor weapons, fair wall interactions and distinct toy rules.
## godot --headless --path . res://tests/weapon_test.tscn

const DOG_SCENE := preload("res://scenes/actors/dog.tscn")
const TOY_SCENE := preload("res://scenes/actors/toy.tscn")
var _failed := false
var _arena: Node3D


func _ready() -> void:
	Sfx.enabled = false
	seed(9314)
	await _wall_safety()
	await _swept_collisions()
	await _toy_specials()
	await _charged_throws()
	await _toy_collisions()
	await _powerups()
	await _whacking()
	await get_tree().create_timer(0.15, true, false, true).timeout
	if not _failed:
		print("[weapons] PASSED: safe walking/holding, blocked throws, sweeps, four lethal toys, catching, charged throws, toy caroms, whacking and power-up belts")
	get_tree().quit(1 if _failed else 0)


func _new_arena() -> void:
	if is_instance_valid(_arena):
		_arena.queue_free()
		await get_tree().process_frame
	_arena = Node3D.new()
	add_child(_arena)
	Engine.time_scale = 1.0
	await get_tree().physics_frame


func _dog(at: Vector3, index: int = 0) -> Dog:
	var slot := PlayerSlot.new()
	slot.index = index
	slot.device = DeviceInput.VIRTUAL
	slot.dog = Game.dogs[index % Game.dogs.size()]
	var dog := DOG_SCENE.instantiate() as Dog
	dog.setup(slot)
	dog.position = at
	_arena.add_child(dog)
	_check(not dog.model.asset_report.is_empty(), "dog renderer initializes successfully")
	dog._spawn_grace = 0.0
	dog.set_physics_process(false)
	return dog


func _toy(id: StringName, at: Vector3 = Vector3.ZERO) -> Toy:
	var toy := TOY_SCENE.instantiate() as Toy
	for candidate in Game.toys:
		if candidate.id == id:
			toy.setup(candidate)
			break
	toy.position = at
	_arena.add_child(toy)
	return toy


func _wall(x: float) -> void:
	var wall := StaticBody3D.new()
	wall.collision_layer = 1
	wall.collision_mask = 0
	wall.position = Vector3(x, 1, 0)
	var collider := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.4, 3.0, 12.0)
	collider.shape = box
	wall.add_child(collider)
	_arena.add_child(wall)


func _wall_safety() -> void:
	await _new_arena()
	_wall(0.0)
	var dog := _dog(Vector3(-2, 0, 0))
	dog.set_physics_process(true)
	dog.input.virtual_move = Vector2.RIGHT
	await get_tree().create_timer(0.75).timeout
	_check(dog.alive and dog.held_toy == null, "unarmed walking into a wall never bonks")
	var toy := _toy(&"tennis_ball", Vector3(-4, 0.32, 0))
	toy.pick_up(dog)
	toy.velocity = Vector3.RIGHT * 40.0
	await get_tree().create_timer(0.3).timeout
	_check(dog.alive and not toy.is_dangerous(), "held toy against a wall is harmless")
	_check(not dog.hit_by(toy), "held state cannot directly cause damage")
	dog.input.virtual_move = Vector2.ZERO
	dog._throw()
	await get_tree().create_timer(0.55).timeout
	_check(dog.alive, "point-blank blocked throw cannot immediately self-bonk")
	_check(toy.bounces >= 1, "blocked throw still resolves a wall collision")
	toy.state = Toy.State.IDLE
	toy.velocity = Vector3.RIGHT * 30.0
	_check(not dog.hit_by(toy), "idle toys stay harmless even with residual velocity")
	toy.pick_up(dog)
	_check(dog.held_toy == toy and not dog.hit_by(toy), "a pickup ends harmlessly at the mouth attachment")
	_check(toy.global_position.distance_to(dog.get_hold_position()) < 0.02, "held toy follows the mouth")
	dog.set_physics_process(false)
	dog.model.update_motion(Vector3.LEFT, 0.4, 0.016)
	toy._process(0.016)
	_check(toy.global_basis.is_equal_approx(dog.get_hold_transform().basis), "held toy uses animated mouth orientation")
	dog.round_locked = true
	dog._throw()
	_check(dog.held_toy == toy and toy.state == Toy.State.HELD, "round lock blocks new throws")
	toy.drop(Vector3.ZERO)
	_check(not dog.try_pickup(toy), "round lock blocks new pickups")
	dog.round_locked = false


func _swept_collisions() -> void:
	await _new_arena()
	var victim := _dog(Vector3.ZERO, 1)
	var thrower := _dog(Vector3(-8, 0, 0))
	var toy := _toy(&"tennis_ball", Vector3(-5, Toy.FLY_HEIGHT, 0))
	toy.set_physics_process(false)
	toy.state = Toy.State.FLYING
	toy.thrower = thrower
	toy.velocity = Vector3.RIGHT * 180.0
	await get_tree().physics_frame
	toy._slide(0.07)
	_check(not victim.alive, "fast projectile sweep hits a dog between frames")

	await _new_arena()
	_wall(0.0)
	victim = _dog(Vector3(0.95, 0, 0), 1)
	thrower = _dog(Vector3(-7, 0, 0))
	toy = _toy(&"super_ball", Vector3(-3, Toy.FLY_HEIGHT, 0))
	toy.set_physics_process(false)
	toy.state = Toy.State.FLYING
	toy.thrower = thrower
	toy.velocity = Vector3.RIGHT * 150.0
	await get_tree().physics_frame
	toy._slide(0.07)
	_check(victim.alive, "wall clips sweep before a dog on the far side")
	_check(toy.bounces == 1, "super ball reflects at the actual wall")

	await _new_arena()
	_wall(6.0)
	thrower = _dog(Vector3.ZERO)
	toy = _toy(&"tennis_ball", Vector3(0, 0.32, -3))
	toy.pick_up(thrower)
	thrower.facing = Vector3.RIGHT
	thrower._throw(1.0)
	await get_tree().create_timer(1.2).timeout
	_check(not thrower.alive, "a distant ricochet can fairly hit its thrower after separation")


func _toy_specials() -> void:
	_check(Game.toys.size() == 4, "four toys available")
	for data in Game.toys:
		_check(data.fully_implemented, data.display_name + " has no prototype special")
	await _new_arena()
	var thrower := _dog(Vector3.ZERO)
	var frisbee := _toy(&"frisbee", Vector3(0, 0.38, -3))
	frisbee.pick_up(thrower)
	thrower.facing = Vector3.RIGHT
	thrower._throw()
	# Well past the point where the old return special used to snap it back.
	await get_tree().create_timer(1.2).timeout
	_check(thrower.held_toy == null, "frisbee never returns to its thrower")
	_check(frisbee.state == Toy.State.FLYING and frisbee.velocity.x > 0.0, "frisbee keeps flying outward")
	# Friction alone ends the flight; nothing carries it back to a dog. A tap is soft enough
	# that the frisbee is spent well inside this window.
	await get_tree().create_timer(3.8).timeout
	_check(frisbee.state == Toy.State.IDLE, "frisbee settles on the ground like every other toy")
	_check(thrower.held_toy == null, "a settled frisbee has to be walked over like any other toy")
	_check(frisbee.data.flat_spin, "frisbee still spins flat in flight")

	# Catching, decided outright: an armed catch window turns a lethal toy into a pickup.
	await _new_arena()
	var pitcher := _dog(Vector3(-6, 0, 0))
	var catcher := _dog(Vector3.ZERO, 1)
	var ball := _toy(&"tennis_ball", Vector3(-3, Toy.FLY_HEIGHT, 0))
	ball.set_physics_process(false)
	ball.state = Toy.State.FLYING
	ball.thrower = pitcher
	ball.velocity = Vector3.RIGHT * 14.0
	_check(ball.is_dangerous(), "the incoming ball is lethal before the catch")
	catcher._throw_or_catch()
	_check(catcher._catch_buffer > 0.0, "throw with empty paws arms a catch window")
	ball._try_hit(catcher)
	_check(catcher.alive, "an armed catch is not an elimination")
	_check(catcher.held_toy == ball and ball.holder == catcher, "the caught toy ends up in the mouth")
	_check(not ball.is_dangerous(), "a caught toy stops being dangerous")

	# Every toy in the box eliminates on a clean hit. Toys that only shoved or disarmed were
	# removed for being unreadable at the table, and nothing should quietly reintroduce one.
	for data in Game.toys:
		await _new_arena()
		thrower = _dog(Vector3(-5, 0, 0))
		var victim := _dog(Vector3.ZERO, 1)
		var shot := _toy(data.id, Vector3(-1, Toy.FLY_HEIGHT, 0))
		shot.set_physics_process(false)
		shot.state = Toy.State.FLYING
		shot.thrower = thrower
		shot.velocity = Vector3.RIGHT * 17.0
		shot._try_hit(victim)
		_check(not victim.alive, "%s eliminates on a clean hit" % data.display_name)

	await _new_arena()
	_wall(0.0)
	thrower = _dog(Vector3(-6, 0, 0))
	var bone := _toy(&"bone", Vector3(-1.5, Toy.FLY_HEIGHT, 0))
	bone.set_physics_process(false)
	bone.state = Toy.State.FLYING
	bone.thrower = thrower
	bone.velocity = Vector3.RIGHT * 16.0
	await get_tree().physics_frame
	bone._slide(0.1)
	_check(bone.state == Toy.State.IDLE and bone.velocity.is_zero_approx(), "heavy bone stops on the first wall")


## Holding the throw button winds a shot up. A tap has to throw exactly as hard as it always
## did - that is what keeps every existing toy number meaningful - and a full wind-up adds
## exactly the charge bonus on top.
func _charged_throws() -> void:
	await _new_arena()
	var dog := _dog(Vector3.ZERO)
	dog.facing = Vector3.RIGHT
	var tapped := _toy(&"tennis_ball", Vector3(0, 0.32, -3))
	tapped.pick_up(dog)
	dog._throw()
	var tap_speed := tapped.velocity.length()
	_check(tapped.is_dangerous(), "a tap still throws something that can bonk")

	var charged := _toy(&"tennis_ball", Vector3(0, 0.32, 3))
	charged.pick_up(dog)
	dog._action_lockout = 0.0
	dog._throw_or_catch()
	_check(charged.state == Toy.State.HELD, "a press with a toy in the mouth does not throw it")
	_check(dog._charging and dog.charge_ratio() == 0.0, "it starts a wind-up at nothing")
	dog._advance_charge(Dog.CHARGE_TIME * 0.5)
	_check(absf(dog.charge_ratio() - 0.5) < 0.01, "the wind-up fills over CHARGE_TIME")
	dog._advance_charge(Dog.CHARGE_TIME)
	_check(dog.charge_ratio() == 1.0, "and stops at full")
	dog._release_throw()
	_check(charged.state == Toy.State.FLYING, "releasing the button is the throw")
	_check(dog.charge_ratio() == 0.0, "and clears the wind-up")
	_check(is_equal_approx(charged.velocity.length(), tap_speed * (Dog.FULL_POWER / Dog.TAP_POWER)),
		"a full wind-up throws harder than a tap by exactly the power range")
	# The point of the tap being soft: it is a close-quarters lob, not a cross-arena shot.
	var reach := (tap_speed - tapped.data.danger_speed) / tapped.data.friction * tap_speed * 0.5
	_check(reach < 8.0, "a tap runs out of danger within a few metres (%.1f m)" % reach)

	# Losing the toy mid-wind-up cancels it, and the release that follows must throw nothing.
	var bully := _dog(Vector3(-1.2, 0, 0), 1)
	var third := _toy(&"tennis_ball", Vector3(0, 0.32, -5))
	third.pick_up(dog)
	dog._action_lockout = 0.0
	dog._throw_or_catch()
	dog._advance_charge(0.2)
	_check(dog.charge_ratio() > 0.0, "the wind-up is running")
	dog.receive_whack(Vector3.RIGHT, bully)
	_check(dog.charge_ratio() == 0.0, "being disarmed cancels the wind-up")
	dog._release_throw()
	_check(third.state == Toy.State.IDLE, "and the release that follows throws nothing")


## Toys are solid to each other. A throw into a loose toy shunts it, a hard enough shunt sends
## it off as a live carom still credited to the dog who started the chain, and a slow roll
## leaves a resting toy a pickup.
func _toy_collisions() -> void:
	await _new_arena()
	var thrower := _dog(Vector3(-8, 0, 0))
	var resting := _toy(&"tennis_ball", Vector3(0, 0.32, 0))
	resting.set_physics_process(false)
	var shot := _toy(&"tennis_ball", Vector3(-2, Toy.FLY_HEIGHT, 0))
	shot.set_physics_process(false)
	shot.state = Toy.State.FLYING
	shot.thrower = thrower
	shot.velocity = Vector3.RIGHT * 24.0
	await get_tree().physics_frame
	shot._slide(0.12)
	_check(resting.velocity.x > 0.0, "a throw into a loose toy shoves it along")
	_check(resting.state == Toy.State.FLYING and resting.is_dangerous(), "a hard shunt arms the struck toy")
	_check(resting.thrower == thrower, "the carom is credited to whoever started the chain")
	_check(shot.velocity.x < 24.0, "and the toy that struck it gives up the speed it handed over")

	# A toy rolling gently into another is not a throw: nothing lethal comes out of a nudge.
	await _new_arena()
	var rolling := _toy(&"tennis_ball", Vector3(-1.2, 0.32, 0))
	rolling.set_physics_process(false)
	var parked := _toy(&"tennis_ball", Vector3(0, 0.32, 0))
	parked.set_physics_process(false)
	rolling.velocity = Vector3.RIGHT * 2.0
	await get_tree().physics_frame
	rolling._slide(0.4)
	_check(parked.velocity.x > 0.0, "a slow roll still shoves the toy it meets")
	_check(parked.state == Toy.State.IDLE, "but never arms it")

	# A toy in the mouth is not in the way: carrying one past a loose toy has to be free.
	await _new_arena()
	var carrier := _dog(Vector3.ZERO)
	var held := _toy(&"tennis_ball", Vector3(0, 0.32, -3))
	held.pick_up(carrier)
	await get_tree().physics_frame
	_check(held.shape.disabled, "a held toy is not solid to anything")


func _powerups() -> void:
	await _new_arena()
	var dog := _dog(Vector3.ZERO)
	var toy := _toy(&"tennis_ball", Vector3(-2, Toy.FLY_HEIGHT, 0))
	toy.set_physics_process(false)
	toy.state = Toy.State.FLYING
	toy.velocity = Vector3.RIGHT * 18.0

	# Power-ups live on the slot, not the dog, so they survive into the next round.
	dog.slot.powerups.clear()
	dog.apply_powerups()
	_check(dog.shield_charges == 0, "a dog with an empty belt has no shield")
	_check(dog.collect_powerup(PowerupKinds.SHIELD) == &"", "the first pickup displaces nothing")
	_check(dog.shield_charges == 1, "a collected shield arms a charge")
	_check(dog.hit_by(toy) and dog.alive, "shield absorbs a dangerous hit")
	_check(dog.shield_charges == 0 and not toy.is_dangerous(), "shield spends its charge and defuses the toy")
	# A shield is spent, not rented: it leaves the belt, so it cannot come back next round.
	_check(not dog.slot.has_powerup(PowerupKinds.SHIELD), "an absorbed shield comes off the belt")
	dog.apply_powerups()
	_check(dog.shield_charges == 0, "a spent shield does not return next round")
	# A belt holds each kind once: a second shield is a dud pickup, so it is refused outright
	# rather than quietly doubling up.
	dog.slot.powerups.clear()
	dog.collect_powerup(PowerupKinds.SHIELD)
	dog.collect_powerup(PowerupKinds.SHIELD)
	_check(dog.slot.powerup_count(PowerupKinds.SHIELD) == 1, "a second shield is not added to the belt")
	_check(dog.shield_charges == 1, "and it still arms exactly one charge")

	# Same rule for every kind: one of each, so every crate you open is something new.
	dog.slot.powerups.clear()
	dog.collect_powerup(PowerupKinds.ZOOMIES)
	var once := dog._speed_mult
	dog.collect_powerup(PowerupKinds.ZOOMIES)
	_check(dog._speed_mult == once, "a duplicate zoomies changes nothing")
	_check(dog.slot.powerups.size() == 1, "and does not take a slot")
	dog._start_dash()
	_check(dog._dash_cooldown < dog.data.dash_cooldown, "zoomies shortens dash recovery")
	_check(dog.powerup_status().contains("ZOOMIES"), "the belt is readable by the HUD")

	# The belt is capped, and a full one swaps out its oldest - in place, starting at slot one,
	# so the other sockets never shuffle along.
	dog.slot.clear_powerups()
	dog.collect_powerup(PowerupKinds.SHIELD)
	dog.collect_powerup(PowerupKinds.TELEPAWTHY)
	dog.collect_powerup(PowerupKinds.DIG)
	_check(dog.slot.powerups.size() == PowerupKinds.MAX_SLOTS, "the belt fills to its cap")
	var displaced := dog.collect_powerup(PowerupKinds.GHOST_PUP)
	_check(displaced == PowerupKinds.SHIELD, "a full belt pushes out the oldest power-up")
	var expected: Array[StringName] = [PowerupKinds.GHOST_PUP, PowerupKinds.TELEPAWTHY, PowerupKinds.DIG]
	_check(dog.slot.powerups == expected, "the fourth pickup takes slot one and the others stay put")
	_check(dog.collect_powerup(PowerupKinds.ZOOMIES) == PowerupKinds.TELEPAWTHY, "the fifth replaces the next oldest")
	expected = [PowerupKinds.GHOST_PUP, PowerupKinds.ZOOMIES, PowerupKinds.DIG]
	_check(dog.slot.powerups == expected, "in slot two")
	_check(dog.collect_powerup(PowerupKinds.BANK_SHOT) == PowerupKinds.DIG, "then slot three")
	_check(dog.collect_powerup(PowerupKinds.SHIELD) == PowerupKinds.GHOST_PUP, "and round again to slot one")
	_check(dog.slot.powerups.size() == PowerupKinds.MAX_SLOTS, "the belt never exceeds its cap")
	_check(not dog.slot.has_powerup(PowerupKinds.GHOST_PUP), "the displaced power-up is really gone")
	_check(dog.slot.powerups[0] == PowerupKinds.SHIELD, "the new power-up is on the belt")
	dog.slot.clear_powerups()
	dog.slot.powerups.assign([PowerupKinds.MUD_TRACK, PowerupKinds.DIG, PowerupKinds.ZOOMIES])
	_check(dog.slot.take_powerup(PowerupKinds.SHIELD) == PowerupKinds.MUD_TRACK, "a belt set up directly also replaces slot one first")

	# Every kind a crate can roll has to actually do something: a stat on the dog, or a
	# behaviour snapshotted onto the throw.
	var probe := _toy(&"tennis_ball", Vector3(0, 0.32, 6))
	for kind in PowerupKinds.ALL:
		dog.slot.powerups.clear()
		dog.slot.powerups.append(kind)
		dog.apply_powerups()
		probe.power_effects.launch(dog)
		dog._start_dash()
		var left_decoy := is_instance_valid(dog._decoy)
		if left_decoy:
			dog._decoy.poof()
		var changed := left_decoy or probe.power_effects.scatter or probe.power_effects.bank or dog.shield_charges > 0 \
			or dog._speed_mult != 1.0 or dog._dash_mult != 1.0 or dog._cooldown_mult != 1.0 or dog.ghost or dog.digger \
			or probe.power_effects.blast or probe.power_effects.mud or probe.power_effects.steer
		dog._dash_timer = 0.0
		dog._surface()
		_check(changed, "%s changes the dog or its throws" % PowerupKinds.display_name(kind))
	probe.power_effects.reset()

	# A saved belt with duplicates in it (older saves, direct edits) is repaired on spawn.
	dog.slot.powerups.assign([PowerupKinds.SHIELD, PowerupKinds.SHIELD, PowerupKinds.ZOOMIES, PowerupKinds.ZOOMIES])
	dog.apply_powerups()
	_check(dog.slot.powerups.size() == 2 and dog.shield_charges == 1, "a belt never holds two of one kind")
	for i in 3:
		dog.slot.take_powerup(PowerupKinds.SHIELD)
	_check(dog.slot.powerup_count(PowerupKinds.SHIELD) == 1, "repeated shield grants stay at one")
	dog.slot.powerups.clear()
	dog.apply_powerups()
	dog.invincible = false
	await _audit_regressions()
	await _behaviour_powers()


## The runtime-reproduced bugs from docs/research/BOOMERANG_FU_AUDIT.md.
func _audit_regressions() -> void:
	# Dogs are always their true size, including through a frozen countdown.
	await _new_arena()
	var holder := Node3D.new()
	holder.process_mode = Node.PROCESS_MODE_DISABLED
	_arena.add_child(holder)
	var frozen_slot := PlayerSlot.new()
	frozen_slot.device = DeviceInput.VIRTUAL
	frozen_slot.dog = Game.dogs[0]
	var frozen := DOG_SCENE.instantiate() as Dog
	frozen.setup(frozen_slot)
	holder.add_child(frozen)
	await get_tree().process_frame
	_check(frozen.model.scale.is_equal_approx(Vector3.ONE * frozen.data.model_scale), "a dog spawned during the countdown is its real size")

	# Swipes respect cover exactly as throws do.
	await _new_arena()
	_wall(0.0)
	var bully := _dog(Vector3(-0.8, 0, 0))
	var victim := _dog(Vector3(0.8, 0, 0), 1)
	bully.facing = Vector3.RIGHT
	_check(bully._whack_target() == null, "a swipe cannot reach through a wall")
	bully._throw_or_catch()
	_check(victim.dizzy_time <= 0.0, "so nobody behind cover goes dizzy")

	# Overlapping slows belong to their sources: leaving one keeps the other.
	var zone_a := Node.new()
	var zone_b := Node.new()
	_arena.add_child(zone_a)
	_arena.add_child(zone_b)
	victim.set_slow(zone_a, 0.5)
	victim.set_slow(zone_b, 0.7)
	victim.clear_slow(zone_b)
	_check(is_equal_approx(victim.speed_scale, 0.5), "leaving one slow zone keeps the other in force")
	victim.clear_slow(zone_a)
	_check(is_equal_approx(victim.speed_scale, 1.0), "and leaving both restores full speed")


## Squeaky Blast and Mud Track change what a throw does rather than a number on the dog.
func _behaviour_powers() -> void:
	await _new_arena()
	_wall(3.0)
	var thrower := _dog(Vector3(-6, 0, 0))
	var victim := _dog(Vector3(1.6, 0, 1.4), 1)
	thrower.slot.powerups.assign([PowerupKinds.SQUEAKY_BLAST])
	var toy := _toy(&"tennis_ball", Vector3(-6, 0.32, -3))
	toy.pick_up(thrower)
	thrower.facing = Vector3.RIGHT
	thrower._throw(1.0)
	_check(toy.power_effects.blast, "a Squeaky Blast throw carries the blast")
	thrower.slot.powerups.clear()
	_check(toy.power_effects.blast, "and a belt change never rewrites a toy in flight")
	var fused := false
	for i in 60:
		await get_tree().physics_frame
		fused = fused or toy.power_effects.fuse_left > 0.0
		if not victim.alive:
			break
	_check(fused, "the first impact arms a fuse rather than going off at once")
	_check(not victim.alive, "the burst puts out a rival in range")

	# A catch defuses it.
	await _new_arena()
	_wall(3.0)
	thrower = _dog(Vector3(-6, 0, 0))
	var catcher := _dog(Vector3(0, 0, 0), 1)
	toy = _toy(&"tennis_ball", Vector3(-6, 0.32, -3))
	toy.pick_up(thrower)
	thrower.slot.powerups.assign([PowerupKinds.SQUEAKY_BLAST])
	thrower._throw(1.0)
	toy.power_effects.impact()
	toy.pick_up(catcher)
	_check(toy.power_effects.fuse_left < 0.0 and not toy.power_effects.blast, "catching a fused toy defuses it")

	# Walls block the burst.
	await _new_arena()
	_wall(0.0)
	thrower = _dog(Vector3(-8, 0, 4))
	var hidden := _dog(Vector3(1.2, 0, 0), 1)
	toy = _toy(&"tennis_ball", Vector3(-0.8, Toy.FLY_HEIGHT, 0))
	toy.set_physics_process(false)
	toy.state = Toy.State.FLYING
	toy.thrower = thrower
	toy.power_effects.blast = true
	toy.power_effects.detonate()
	_check(hidden.alive, "a wall between the burst and a dog protects it")

	# Mud Track lays a bounded trail of patches that slow, then clear.
	await _new_arena()
	thrower = _dog(Vector3(-8, 0, 0))
	thrower.slot.powerups.assign([PowerupKinds.MUD_TRACK])
	toy = _toy(&"frisbee", Vector3(-8, 0.32, -3))
	toy.pick_up(thrower)
	thrower.facing = Vector3.RIGHT
	thrower._throw(1.0)
	for i in 20:
		await get_tree().physics_frame
	var patches := get_tree().get_nodes_in_group("mud_patches")
	_check(patches.size() >= 3, "a Mud Track throw leaves a trail (%d patches)" % patches.size())
	_check(patches.size() <= MudPatch.LIMIT, "and the trail is capped")
	var walker := _dog((patches[0] as Node3D).global_position, 1)
	for i in 3:
		await get_tree().physics_frame
	_check(walker.speed_scale < 1.0, "standing in mud slows a dog")
	while toy.state == Toy.State.FLYING:
		await get_tree().physics_frame
	await get_tree().create_timer(MudPatch.LIFETIME + 0.3).timeout
	_check(is_equal_approx(walker.speed_scale, 1.0), "and the slow lifts when the mud dries up")
	_check(get_tree().get_nodes_in_group("mud_patches").is_empty(), "every patch clears itself")
	await _combining_powers()


## Scatter Fetch, Bank Shot, Good Decoy, and how the throw powers combine.
func _combining_powers() -> void:
	# Scatter: one press, three toys; the side ones vanish instead of becoming pickups.
	await _new_arena()
	var thrower := _dog(Vector3(-6, 0, 0))
	thrower.slot.powerups.assign([PowerupKinds.SCATTER_FETCH, PowerupKinds.SQUEAKY_BLAST])
	var toy := _toy(&"tennis_ball", Vector3(-6, 0.32, -3))
	toy.pick_up(thrower)
	thrower.facing = Vector3.RIGHT
	thrower._throw(0.5)
	await get_tree().physics_frame
	var flying := 0
	var side_toys: Array[Toy] = []
	for node in get_tree().get_nodes_in_group("toys"):
		var t := node as Toy
		if t.state == Toy.State.FLYING:
			flying += 1
		if t.ephemeral:
			side_toys.append(t)
	_check(flying == 3 and side_toys.size() == 2, "Scatter Fetch throws three toys at once (%d)" % flying)
	_check(side_toys.all(func(t: Toy) -> bool: return t.power_effects.blast and t.power_effects.volley == toy.power_effects.volley),
		"the side toys carry the same powers and volley")
	_check(toy.power_effects.trail_colors().size() == 2, "a two-power throw trails both colours")
	await get_tree().create_timer(Toy.EPHEMERAL_LIFE + ToyPowerEffects.FUSE + 0.5).timeout
	var left := 0
	for node in get_tree().get_nodes_in_group("toys"):
		if (node as Toy).ephemeral:
			left += 1
	_check(left == 0, "side toys never stay behind as pickups")
	_check(is_instance_valid(toy), "the real toy stays in play")

	# One volley is one hit: a shield soaks it and the second toy of the volley passes through.
	await _new_arena()
	thrower = _dog(Vector3(-8, 0, 0))
	var victim := _dog(Vector3.ZERO, 1)
	victim.slot.powerups.assign([PowerupKinds.SHIELD])
	victim.apply_powerups()
	var first := _toy(&"tennis_ball", Vector3(-1, Toy.FLY_HEIGHT, 0))
	var second := _toy(&"tennis_ball", Vector3(-1, Toy.FLY_HEIGHT, 0.3))
	for shot in [first, second]:
		shot.set_physics_process(false)
		shot.state = Toy.State.FLYING
		shot.thrower = thrower
		shot.velocity = Vector3.RIGHT * 17.0
		shot.power_effects.volley = 999
	first._try_hit(victim)
	second._try_hit(victim)
	_check(victim.alive and victim.shield_charges == 0, "a volley pops a shield once and does not also knock out")

	# Bank Shot: the first wall bounce is faster than the throw that reached it.
	await _new_arena()
	_wall(3.0)
	thrower = _dog(Vector3(-8, 0, 4))
	thrower.slot.powerups.assign([PowerupKinds.BANK_SHOT, PowerupKinds.SQUEAKY_BLAST])
	var banker := _toy(&"tennis_ball", Vector3(0, Toy.FLY_HEIGHT, 0))
	banker.set_physics_process(false)
	banker.state = Toy.State.FLYING
	banker.thrower = thrower
	banker.power_effects.launch(thrower)
	banker.velocity = Vector3.RIGHT * 20.0
	await get_tree().physics_frame
	banker._slide(0.2)
	_check(banker.velocity.x < 0.0 and banker.velocity.length() > 20.0 * banker.data.bounciness * 1.3, "a Bank Shot comes off the wall faster")
	_check(banker.power_effects.fuse_left < 0.0, "with Squeaky Blast, the bank itself does not arm the fuse")

	# Good Decoy: a dash leaves a copy that pops on its own.
	await _new_arena()
	var dasher := _dog(Vector3.ZERO)
	dasher.slot.powerups.assign([PowerupKinds.GOOD_DECOY])
	dasher._start_dash()
	_check(get_tree().get_nodes_in_group("decoys").size() == 1, "a dash leaves one decoy")
	dasher._dash_cooldown = 0.0
	dasher._start_dash()
	_check(get_tree().get_nodes_in_group("decoys").size() == 1, "a new dash replaces the old decoy")
	await get_tree().create_timer(Decoy.LIFETIME + 0.3).timeout
	_check(get_tree().get_nodes_in_group("decoys").is_empty(), "the decoy goes on its own")
	await _new_powers()


## Telepawthy, Ghost Pup and Dig!: the Boomerang Fu-style powers.
func _new_powers() -> void:
	# Telepawthy bends a throw toward the stick, but never far enough to come back.
	await _new_arena()
	var thrower := _dog(Vector3(-8, 0, 0))
	thrower.slot.powerups.assign([PowerupKinds.TELEPAWTHY])
	var toy := _toy(&"tennis_ball", Vector3(0, Toy.FLY_HEIGHT, 0))
	toy.set_physics_process(false)
	toy.state = Toy.State.FLYING
	toy.thrower = thrower
	toy.power_effects.launch(thrower)
	toy.velocity = Vector3.RIGHT * 18.0
	thrower.input.virtual_move = Vector2(0, 1)
	for i in 10:
		toy.power_effects.steer_toward(1.0 / 60.0)
	_check(toy.velocity.z > 1.0, "a Telepawthy throw bends toward the stick")
	_check(is_equal_approx(toy.velocity.length(), 18.0), "and keeps its speed")
	thrower.input.virtual_move = Vector2(-1, 0)
	for i in 400:
		toy.power_effects.steer_toward(1.0 / 60.0)
	_check(toy.velocity.x > -17.0, "but can never be turned right round to come back")
	_check(toy.power_effects.trail_colors().has(PowerupKinds.color(PowerupKinds.TELEPAWTHY)), "a steerable throw trails its colour")
	var plain := _toy(&"tennis_ball", Vector3(0, Toy.FLY_HEIGHT, 3))
	plain.set_physics_process(false)
	plain.state = Toy.State.FLYING
	plain.thrower = thrower
	plain.velocity = Vector3.RIGHT * 18.0
	thrower.input.virtual_move = Vector2(0, 1)
	plain.power_effects.steer_toward(0.2)
	_check(plain.velocity.z == 0.0, "a normal throw ignores the stick")
	thrower.input.virtual_move = Vector2.ZERO

	# Ghost Pup: invisible anywhere, shown by a throw or a dash.
	await _new_arena()
	var ghost := _dog(Vector3.ZERO)
	ghost.slot.powerups.assign([PowerupKinds.GHOST_PUP])
	ghost.apply_powerups()
	await get_tree().process_frame
	_check(ghost.concealed and not ghost.model.visible and not ghost.ring.visible, "a Ghost Pup is invisible in the open")
	ghost.reveal()
	await get_tree().process_frame
	_check(not ghost.concealed and ghost.model.visible, "a throw or dash gives it away")
	await get_tree().create_timer(Dog.REVEAL_TIME + 0.1).timeout
	_check(ghost.concealed, "and it fades out again")
	ghost.slot.clear_powerups()
	ghost.apply_powerups()
	await get_tree().process_frame
	_check(not ghost.concealed, "losing Ghost Pup shows the dog for good")

	# Dig!: a longer dash, underground and untouchable the whole way.
	await _new_arena()
	var digger := _dog(Vector3(-4, 0, 0))
	# Same breed, so the only difference between the two dashes is the power.
	var walker := _dog(Vector3(-4, 0, 4), Game.dogs.size())
	digger.slot.powerups.assign([PowerupKinds.DIG])
	digger.apply_powerups()
	for dog: Dog in [digger, walker]:
		dog.facing = Vector3.RIGHT
		dog.set_physics_process(true)
		dog._start_dash()
	_check(not digger.model.visible and digger._mound.visible, "a dig goes underground")
	for i in 11:
		await get_tree().physics_frame
	_check(digger.invincible and not walker.invincible, "a burrow stays protected after a normal dash's cover is gone")
	var shot := _toy(&"tennis_ball", Vector3(digger.global_position.x - 2, Toy.FLY_HEIGHT, 0))
	shot.set_physics_process(false)
	shot.state = Toy.State.FLYING
	shot.thrower = walker
	shot.velocity = Vector3.RIGHT * 18.0
	_check(not digger.hit_by(shot) and digger.alive, "nothing hits a dog underground")
	for i in 30:
		await get_tree().physics_frame
	_check(digger.model.visible and not digger._mound.visible, "and it pops back up")
	_check(digger.global_position.x - (-4.0) > (walker.global_position.x - (-4.0)) * 1.5, "having gone much further than a dash")


## A bare-pawed dog swipes: an armed rival is disarmed, an empty-pawed one goes dizzy.
func _whacking() -> void:
	await _new_arena()
	var bully := _dog(Vector3.ZERO)
	var victim := _dog(Vector3(0, 0, -1.0), 1)
	bully.facing = Vector3(0, 0, -1)
	var toy := _toy(&"tennis_ball", Vector3(4, 0.32, 4))
	toy.pick_up(victim)
	_check(bully._whack_target() == victim, "a rival in front and in range is whackable")
	bully._throw_or_catch()
	_check(victim.held_toy == null and toy.state == Toy.State.IDLE, "whacking an armed dog disarms it")
	_check(victim.alive and victim.dizzy_time <= 0.0, "being disarmed is not an elimination and not dizzying")
	_check(bully._whack_cooldown > 0.0, "a whack goes on cooldown")

	# Reaching past both gates: the whack's own cooldown, and the short lockout that stops one
	# press being read as several. This test drives the action directly, frame by frame.
	bully._whack_cooldown = 0.0
	bully._action_lockout = 0.0
	bully._throw_or_catch()
	_check(victim.dizzy_time > 0.0, "whacking an empty-pawed dog makes it dizzy")
	_check(victim.alive, "a whack never eliminates")
	victim.input.virtual_buttons[&"throw"] = true
	victim._catch_buffer = 0.0
	_check(victim.dizzy_time > 0.0, "a dizzy dog stays dizzy")

	# Out of range, or facing away, falls through to the catch window instead.
	bully._whack_cooldown = 0.0
	bully.facing = Vector3(0, 0, 1)
	_check(bully._whack_target() == null, "a dog behind you is not whackable")
	bully.global_position = Vector3(0, 0, 6.0)
	bully.facing = Vector3(0, 0, -1)
	_check(bully._whack_target() == null, "a dog out of range is not whackable")


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failed = true
		push_error("[weapons] FAILED: " + message)
