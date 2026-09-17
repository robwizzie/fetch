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
	await _powerups()
	await _whacking()
	await get_tree().create_timer(0.15, true, false, true).timeout
	if not _failed:
		print("[weapons] PASSED: safe walking/holding, blocked throws, sweeps, six toys, catching, whacking and power-up belts")
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
	thrower._throw()
	await get_tree().create_timer(1.2).timeout
	_check(not thrower.alive, "a distant ricochet can fairly hit its thrower after separation")


func _toy_specials() -> void:
	_check(Game.toys.size() == 6, "six toys available")
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
	# Friction alone ends the flight; nothing carries it back to a dog. At the frisbee's
	# throw speed and friction that takes a little under four seconds.
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

	await _new_arena()
	thrower = _dog(Vector3(-5, 0, 0))
	var victim := _dog(Vector3.ZERO, 1)
	var held := _toy(&"tennis_ball", Vector3(0, 0.32, 3))
	held.pick_up(victim)
	var rope := _toy(&"rope_toy", Vector3(-1, Toy.FLY_HEIGHT, 0))
	rope.set_physics_process(false)
	rope.state = Toy.State.FLYING
	rope.thrower = thrower
	rope.velocity = Vector3.RIGHT * 17.0
	rope._try_hit(victim)
	_check(victim.alive and victim.held_toy == null, "rope disarms without eliminating")
	_check(victim._weapon_impulse.length() > 9.0, "rope applies a real movement impulse")
	_check(not held.is_dangerous() and not victim.try_pickup(held), "disarmed toy is safe and cannot be instantly repicked")

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

	await _new_arena()
	thrower = _dog(Vector3(-6, 0, 0))
	victim = _dog(Vector3(1.5, 0, 0), 1)
	held = _toy(&"bone", Vector3(0, 0.36, 3))
	held.pick_up(victim)
	var chicken := _toy(&"squeaky_chicken", Vector3(0, Toy.FLY_HEIGHT, 0))
	chicken.thrower = thrower
	chicken._squeak()
	_check(victim.alive and victim.held_toy == null and victim._stagger_time > 0.0, "chicken squeak disarms and slows nearby dogs")
	victim._stagger_time = 0.0
	chicken._squeak()
	_check(is_zero_approx(victim._stagger_time), "chicken squeak fires only once per throw")


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

	# The belt is capped, and filling it swaps out the oldest.
	dog.slot.powerups.clear()
	dog.collect_powerup(PowerupKinds.SHIELD)
	dog.collect_powerup(PowerupKinds.CANNON)
	dog.collect_powerup(PowerupKinds.SPRINGS)
	_check(dog.slot.powerups.size() == PowerupKinds.MAX_SLOTS, "the belt fills to its cap")
	var displaced := dog.collect_powerup(PowerupKinds.BIG_CATCH)
	_check(displaced == PowerupKinds.SHIELD, "a full belt pushes out the oldest power-up")
	_check(dog.slot.powerups.size() == PowerupKinds.MAX_SLOTS, "the belt never exceeds its cap")
	_check(not dog.slot.has_powerup(PowerupKinds.SHIELD), "the displaced power-up is really gone")
	_check(dog.slot.has_powerup(PowerupKinds.BIG_CATCH), "the new power-up is on the belt")

	# Every kind a crate can roll has to actually do something.
	for kind in PowerupKinds.ALL:
		dog.slot.powerups.clear()
		dog.slot.powerups.append(kind)
		dog.apply_powerups()
		var changed := dog.shield_charges > 0 or dog._speed_mult != 1.0 or dog._catch_mult != 1.0 \
			or dog._throw_mult != 1.0 or dog._dash_mult != 1.0 or dog._cooldown_mult != 1.0 \
			or dog._size_mult != 1.0 or dog._catch_cooldown_mult != 1.0 or dog._reach_mult != 1.0
		_check(changed, "%s changes the dog" % PowerupKinds.display_name(kind))
	dog.slot.powerups.clear()
	dog.apply_powerups()
	dog.invincible = false


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
