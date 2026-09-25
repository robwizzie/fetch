class_name ToyPowerEffects
extends Node3D
## One launch snapshot. A belt swap never rewrites a flying shot. Catch/pickup defuses it.
##
## How the throw powers combine:
##   Blast + Bank     the fuse arms on the impact AFTER the bank, so the banked shot is the threat.
##   Blast + Scatter  every toy in the volley carries a fuse; the volley still counts as one hit.
##   Mud + Scatter    three trails, all inside MudPatch.LIMIT.
##   Bank + Scatter   the side toys bank too.
##   Mud + Bank       mud all the way, round the corner.
##   Steer + anything the thrower bends the main toy; Scatter's side toys fly straight.

const FUSE := 0.48
const BLAST_RADIUS := 2.4
const MUD_SPACING := 1.15
## Speed kept by a toy the moment its blast arms.
const ARM_DAMPING := 0.12
## Speed multiplier on a Bank Shot's first wall bounce, and the most it may reach.
const BANK_BOOST := 1.45
const BANK_MAX_SPEED := 42.0
## Telepawthy: how fast the thrower's stick can bend a throw, and the most it can bend it in
## total. The budget stays well short of a U-turn - a steered toy can curl round a couch, but
## it can never be brought back to the dog that threw it.
const STEER_RATE := 4.2
const STEER_BUDGET := 1.75
var blast := false
var mud := false
var scatter := false
var bank := false
var steer := false
var _steered := 0.0
## Every toy launched by one press shares this id, so one volley is one hit on any dog.
var volley := 0
var _banked := false
static var _next_volley := 1
var fuse_left := -1.0
var _spent := false
var _mud_distance := 0.0
var _warning: MeshInstance3D
var _toy: Toy


func _ready() -> void:
	_toy = get_parent() as Toy
	_warning = Mats.mesh(self, Mats.torus(0.88, 1.0), Color("ffb56c"))
	_warning.material_override = Mats.unlit(Color(1.0, 0.55, 0.24, 0.8))
	_warning.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_warning.visible = false


func launch(dog: Dog) -> void:
	reset()
	blast = dog.slot.has_powerup(PowerupKinds.SQUEAKY_BLAST)
	mud = dog.slot.has_powerup(PowerupKinds.MUD_TRACK)
	scatter = dog.slot.has_powerup(PowerupKinds.SCATTER_FETCH)
	bank = dog.slot.has_powerup(PowerupKinds.BANK_SHOT)
	steer = dog.slot.has_powerup(PowerupKinds.TELEPAWTHY)
	volley = _next_volley
	_next_volley += 1


## The side toys of a Scatter Fetch carry the main toy's snapshot, minus the scatter itself.
func copy_from(other: ToyPowerEffects) -> void:
	reset()
	blast = other.blast
	mud = other.mud
	bank = other.bank
	volley = other.volley


## The trail colours for this shot: one per throw power it carries.
func trail_colors() -> Array[Color]:
	var colors: Array[Color] = []
	for kind in PowerupKinds.THROW_POWERS:
		var on := (kind == PowerupKinds.SQUEAKY_BLAST and blast) or (kind == PowerupKinds.MUD_TRACK and mud) \
			or (kind == PowerupKinds.SCATTER_FETCH and scatter) or (kind == PowerupKinds.BANK_SHOT and bank) \
			or (kind == PowerupKinds.TELEPAWTHY and steer)
		if on:
			colors.append(PowerupKinds.color(kind))
	return colors


## Called on a wall bounce, after the bounce has been applied. Returns true if this was the bank,
## which then does not count as the impact that arms a blast.
func bank_bounce() -> bool:
	if not bank or _banked:
		return false
	_banked = true
	var speed := minf(_toy.velocity.length() * BANK_BOOST, BANK_MAX_SPEED)
	_toy.velocity = _toy.velocity.normalized() * speed
	Juice.burst(_toy.get_parent(), _toy.global_position, PowerupKinds.color(PowerupKinds.BANK_SHOT), 12, 4.0)
	Sfx.play_at("charged", _toy.global_position, 1.3, -6.0)
	return true


func reset() -> void:
	blast = false
	mud = false
	scatter = false
	bank = false
	steer = false
	_steered = 0.0
	_banked = false
	volley = 0
	fuse_left = -1.0
	_spent = false
	_mud_distance = 0.0
	if is_instance_valid(_warning):
		_warning.hide()


## Telepawthy: bends a flying toy toward wherever its thrower is pushing the stick.
func steer_toward(delta: float) -> void:
	if not steer or _steered >= STEER_BUDGET:
		return
	var dog := _toy.thrower
	if not is_instance_valid(dog) or not dog.alive or dog.input == null:
		return
	var stick := dog.input.move_vector()
	if stick.length() < 0.35:
		return
	var heading := Vector2(_toy.velocity.x, _toy.velocity.z)
	if heading.length_squared() < 0.01:
		return
	var turn := heading.angle_to(stick)
	var step := clampf(turn, -STEER_RATE * delta, STEER_RATE * delta)
	step = clampf(step, -(STEER_BUDGET - _steered), STEER_BUDGET - _steered)
	_steered += absf(step)
	var bent := heading.rotated(step)
	_toy.velocity = Vector3(bent.x, 0.0, bent.y)


func travel(from: Vector3, to: Vector3) -> void:
	if not mud:
		return
	var length := from.distance_to(to)
	if length < 0.001:
		return
	var next := MUD_SPACING - _mud_distance
	while next <= length:
		MudPatch.spawn(_toy.get_parent(), from.lerp(to, next / length))
		next += MUD_SPACING
	_mud_distance = fmod(_mud_distance + length, MUD_SPACING)


## The first impact arms the fuse and kills the toy's speed, so the burst goes off where the
## toy struck rather than wherever a hard ricochet carried it. A dog brave enough to grab the
## squeaking toy before it goes defuses it (pickup resets the snapshot).
func impact() -> void:
	if blast and not _spent and fuse_left < 0.0:
		fuse_left = FUSE
		_toy.velocity *= ARM_DAMPING
		_warning.show()
		Sfx.play_at("fuse", _toy.global_position, 1.0, -5.0)


## Driven by Toy's physics tick so round locks and pauses suspend both together.
func tick(delta: float) -> void:
	if fuse_left < 0.0:
		return
	fuse_left -= delta
	var progress := 1.0 - maxf(fuse_left, 0.0) / FUSE
	_warning.global_position = Vector3(_toy.global_position.x,
		Terrain.ground_height(self, _toy.global_position) + 0.075, _toy.global_position.z)
	_warning.scale = Vector3.ONE * BLAST_RADIUS * (0.7 + progress * 0.3)
	# Squeezing faster and faster as it is about to go, like a squeaky toy being wrung.
	# Runs after the toy's own visual update, so it is not reset the same frame.
	var squeeze := absf(sin(progress * progress * 34.0))
	_toy.model.scale = Vector3(1.0 + squeeze * 0.22, 1.0 - squeeze * 0.18, 1.0 + squeeze * 0.22)
	if fuse_left <= 0.0:
		detonate()


func detonate() -> void:
	if _spent or not blast or _toy.state == Toy.State.HELD:
		return
	_spent = true
	fuse_left = -1.0
	_warning.hide()
	var origin := _toy.global_position
	# Resolve all victims before emitting any KO/round-end can disable the scene on a later tick.
	for node in get_tree().get_nodes_in_group("dogs"):
		var dog := node as Dog
		if not dog.alive or _toy._hit_dogs.has(dog.get_instance_id()):
			continue
		var gap := Vector2(origin.x - dog.global_position.x, origin.z - dog.global_position.z)
		if gap.length() > BLAST_RADIUS + dog.effective_radius():
			continue
		if not CombatRules.clear_between(self, origin, dog.global_position + Vector3.UP * Toy.FLY_HEIGHT):
			continue
		if dog.hit_by_blast(_toy, origin):
			_toy._hit_dogs.append(dog.get_instance_id())
	Sfx.play_at("blast", origin, 1.0, -2.0)
	Juice.shake(0.18)
	Juice.burst(_toy.get_parent(), origin, Color("ffbd75"), 18, 5.0)
	var wave := Mats.mesh(_toy.get_parent(), Mats.torus(0.90, 1.0), Color("ffdf9c"),
		Vector3(origin.x, Terrain.ground_height(self, origin) + 0.1, origin.z))
	wave.material_override = Mats.unlit(Color(1, 0.8, 0.5, 0.8))
	wave.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var tween := wave.create_tween()
	tween.tween_property(wave, "scale", Vector3.ONE * BLAST_RADIUS, 0.18).from(Vector3.ONE * 0.2)
	tween.parallel().tween_property(wave.material_override, "albedo_color:a", 0.0, 0.25)
	tween.tween_callback(wave.queue_free)
	if mud:
		MudPatch.spawn(_toy.get_parent(), origin, 1.3)
		Sfx.play_at("splat", origin, 0.8, -4.0)
	_toy.velocity *= 0.25
	if not _toy.is_dangerous():
		_toy._settle()
