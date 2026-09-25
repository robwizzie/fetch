@tool
class_name Portal
extends Area3D
## One end of a two-way warp, set upright into an arena wall like a glowing doorway.
##
## The node sits on the inner face of a wall, at floor level, with its local +Z pointing into
## the arena. A dog that walks into the doorway, or a toy that would otherwise bounce off that
## stretch of wall, comes out of the linked doorway. The exit is relative: whatever went in
## heading into one wall comes out heading away from the other, at the same offset along it, so
## a pair on opposite walls plays like the arena wraps round and a throw can be banked through.
##
## Portals are placed in pairs: each one points `link` at the other. Only one of the pair needs
## the NodePath filled in — the partner is told about it on ready. `monitoring` doubles as the
## on/off switch, so the match can make them inert during the practice round.

## Where whatever went in comes out. Leave empty on one of the pair; the other will claim it.
@export var link: NodePath:
	set(v):
		link = v
		_relink()
## Half the doorway's width along the wall.
@export var radius := 1.15:
	set(v):
		radius = v
		_rebuild()
## The doorway's glow. A pair reads as a pair because both ends share it.
@export var color := Color(0.65, 0.45, 1.0):
	set(v):
		color = v
		_rebuild()

const HEIGHT := 1.45
## How far the glowing curtain leans back into the rock, in degrees from upright.
const CURTAIN_LEAN := 40.0
## How far in front of the exit face something is placed: clear of the wall and of the exit's
## own mouth, so nothing is caught straight back.
const EXIT_PUSH := 0.3
## A body that just came out of this portal ignores it for this long.
const REENTRY_BLOCK := 0.45
## How hard a dog has to be heading into the doorway to go through, as a dot product with the
## wall normal. A dog strolling along the wall past it stays put.
const INTO_WALL := 0.35

var partner: Portal

var _shape: CollisionShape3D
var _visual: Node3D
var _flash := 0.0
var _strips: Array[MeshInstance3D] = []
var _glow: OmniLight3D
var _blocked: Dictionary = {}
var _time := 0.0


func _ready() -> void:
	add_to_group("portals")
	collision_layer = 8
	collision_mask = 0
	monitorable = false
	_rebuild()
	if Engine.is_editor_hint():
		return
	_relink()


## Into the arena, flattened onto the floor.
func normal() -> Vector3:
	var n := global_basis.z
	n.y = 0.0
	return n.normalized()


## Along the wall, flattened onto the floor.
func tangent() -> Vector3:
	var t := global_basis.x
	t.y = 0.0
	return t.normalized()


func is_active() -> bool:
	return monitoring and partner != null and is_instance_valid(partner) and partner.monitoring


func _process(delta: float) -> void:
	_time += delta
	# Ribbons shimmer out of step with each other, like light running down a waterfall.
	for i in _strips.size():
		var strip := _strips[i]
		var shimmer := minf(1.0, 0.72 + 0.28 * sin(_time * 4.0 + float(i) * 1.3) + _flash * 0.1)
		(strip.material_override as StandardMaterial3D).albedo_color = Color(color.lightened(0.2), shimmer)
	if _glow != null:
		_flash = maxf(0.0, _flash - delta * 8.0)
		_glow.light_energy = 1.3 + sin(_time * 3.1) * 0.15 + _flash
	for body in _blocked.keys():
		_blocked[body] -= delta
		if _blocked[body] <= 0.0 or not is_instance_valid(body):
			_blocked.erase(body)


func _physics_process(_delta: float) -> void:
	if Engine.is_editor_hint() or not is_active():
		return
	# Dogs are pressed against the wall by their own collision, so they are caught by standing in
	# the doorway and pushing into it. Toys ask on impact instead (see [method catch_toy]).
	for node in get_tree().get_nodes_in_group("dogs"):
		var dog := node as Dog
		if dog == null or not dog.alive or dog.round_locked or _blocked.has(dog):
			continue
		var push := dog.push_velocity
		push.y = 0.0
		if push.length() < 0.5 or push.normalized().dot(-normal()) < INTO_WALL:
			continue
		var local := _local(dog.global_position)
		if absf(local.x) > radius or local.y > dog.effective_radius() + 0.2 or local.y < -0.5:
			continue
		_send(dog, dog.global_position, dog.effective_radius())


## Called by a toy that is about to bounce off a wall at [param point]. Returns true when a
## portal took it, in which case the toy has already been moved and redirected.
static func catch_toy(toy: Toy, point: Vector3) -> bool:
	for node in toy.get_tree().get_nodes_in_group("portals"):
		var portal := node as Portal
		if not portal.is_active() or portal._blocked.has(toy):
			continue
		if toy.velocity.dot(portal.normal()) >= 0.0:
			continue
		var local := portal._local(point)
		if absf(local.x) > portal.radius or absf(local.y) > 0.6:
			continue
		portal._send(toy, toy.global_position, toy.data.radius)
		return true
	return false


## x: offset along the wall, y: distance out from its face.
func _local(world: Vector3) -> Vector2:
	var offset := world - global_position
	return Vector2(offset.dot(tangent()), offset.dot(normal()))


func _send(mover: CharacterBody3D, from: Vector3, body_radius: float) -> void:
	# The rotation that takes "into this wall" to "out of the partner's wall".
	var turn := _heading_angle(-normal(), partner.normal())
	var along := clampf(_local(from).x, -radius + body_radius * 0.5, radius - body_radius * 0.5)
	var lateral := tangent().rotated(Vector3.UP, turn) * along
	var exit_at := partner.global_position + lateral + partner.normal() * (body_radius + EXIT_PUSH)
	exit_at.y = mover.global_position.y
	mover.velocity = mover.velocity.rotated(Vector3.UP, turn)
	if mover is Dog:
		var dog := mover as Dog
		dog.facing = dog.facing.rotated(Vector3.UP, turn)
		dog.push_velocity = dog.push_velocity.rotated(Vector3.UP, turn)
	partner.block(mover)
	block(mover)
	var height := Vector3.UP * 0.7
	Juice.burst(get_parent(), from + height, color.lightened(0.25), 16, 3.0)
	mover.global_position = exit_at
	Juice.burst(get_parent(), exit_at + height, partner.color.lightened(0.25), 16, 3.0)
	partner.flare()
	flare()
	Sfx.play_at("warp", exit_at, randf_range(0.95, 1.08), -5.0)


static func _heading_angle(from: Vector3, to: Vector3) -> float:
	return atan2(from.cross(to).y, from.dot(to))


## Stops this portal grabbing a body that has just come out of it.
func block(body: Node3D) -> void:
	_blocked[body] = REENTRY_BLOCK


## A brief brightening as something passes through, so both ends of a warp are noticed.
func flare() -> void:
	_flash = 2.8


func _relink() -> void:
	if Engine.is_editor_hint() or not is_inside_tree():
		return
	if link.is_empty():
		return
	var other := get_node_or_null(link) as Portal
	if other == null:
		push_warning("Portal %s has no partner at %s" % [name, link])
		return
	partner = other
	# Two-way without needing the path filled in at both ends.
	if other.partner == null:
		other.partner = self


func _rebuild() -> void:
	if not is_inside_tree():
		return
	if _shape == null:
		# A token volume so the doorway still exists as a physics object for editors and
		# layer queries. Transit is decided in code, not by overlap.
		_shape = CollisionShape3D.new()
		_shape.shape = BoxShape3D.new()
		add_child(_shape)
	(_shape.shape as BoxShape3D).size = Vector3(radius * 2.0, HEIGHT, 0.4)
	_shape.position = Vector3(0, HEIGHT * 0.5, 0.2)
	if _visual != null:
		_visual.queue_free()
	_visual = Node3D.new()
	add_child(_visual)
	_strips.clear()
	# A doggy door: the glowing flap is the doorway of a little kennel front built into the fence,
	# its roof painted in the pair's colour so matching doors can be spotted across the yard.
	# Everything stands behind the wall line, so it never takes floor from the arena.
	var wood := Color("a8764f")
	var trim := Color("f1e3c6")
	var roof := color.darkened(0.15)
	var width := radius * 2.0 + 0.7
	ArenaArt.block(_visual, Vector3(width, HEIGHT + 0.15, 0.7), wood, Vector3(0, (HEIGHT + 0.15) * 0.5, -1.0), Vector3.ZERO, 0.06)
	for side in [-1.0, 1.0]:
		ArenaArt.block(_visual, Vector3(0.24, HEIGHT + 0.1, 0.3), trim, Vector3(side * (radius + 0.14), (HEIGHT + 0.1) * 0.5, -0.12), Vector3.ZERO, 0.04)
	ArenaArt.block(_visual, Vector3(radius * 2.0 + 0.52, 0.2, 0.3), trim, Vector3(0, HEIGHT + 0.08, -0.12), Vector3.ZERO, 0.04)
	# Pitched roof, ridge along the fence: from above you see the slope facing the arena.
	for side in [-1.0, 1.0]:
		ArenaArt.block(_visual, Vector3(width + 0.4, 0.14, 0.78), roof,
			Vector3(0, HEIGHT + 0.45, -0.75 + side * 0.3), Vector3(side * 32.0, 0, 0), 0.04)
	ArenaArt.block(_visual, Vector3(width + 0.5, 0.12, 0.14), roof.darkened(0.2), Vector3(0, HEIGHT + 0.66, -0.75), Vector3.ZERO, 0.03)
	# A paw print on the ground outside, like a welcome mat: this is a door for dogs.
	ArenaArt.paw(_visual, Vector3(0, 0.03, 1.05), 0.2, color.lightened(0.45))
	# The curtain: glowing vertical ribbons on a shallow curve across the doorway, bright at the
	# floor and fading upward. Curved, so from above it reads as a lit arc rather than a line.
	var ribbon := GradientTexture2D.new()
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 0.95))
	fade.set_color(1, Color(1, 1, 1, 0.0))
	ribbon.gradient = fade
	ribbon.fill_from = Vector2(0, 1)
	ribbon.fill_to = Vector2(0, 0)
	ribbon.width = 4
	ribbon.height = 64
	# Leaned back into the rock: an upright sheet is edge-on to a top-down camera, a sloped one
	# faces it, so the opening glows from above the way a doorway does from the side.
	var curtain := Node3D.new()
	curtain.rotation_degrees.x = -CURTAIN_LEAN
	_visual.add_child(curtain)
	var count := 11
	for i in count:
		var t := float(i) / float(count - 1) * 2.0 - 1.0
		var strip := MeshInstance3D.new()
		var quad := QuadMesh.new()
		quad.size = Vector2(radius * 2.0 / float(count) * 1.25, HEIGHT * (0.85 + 0.15 * (1.0 - absf(t))))
		strip.mesh = quad
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		mat.albedo_texture = ribbon
		mat.albedo_color = color.lightened(0.2)
		strip.material_override = mat
		strip.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		# Bowed into the rock: edges flush with the wall line, middle set back.
		strip.position = Vector3(t * radius, quad.size.y * 0.5, -0.32 * (1.0 - t * t))
		strip.rotation.y = -atan(0.64 * t / radius)
		curtain.add_child(strip)
		_strips.append(strip)
	# A soft pool of light on the floor in front: what the doorway looks like from above.
	var spill := Mats.contact_shadow(_visual, radius * 1.1, Vector3(0, -0.03, 0.45))
	spill.scale = Vector3(1.0, 1.0, 0.75)
	var spill_mat := spill.material_override as StandardMaterial3D
	spill_mat.albedo_color = Color(color, 0.5)
	spill_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_glow = OmniLight3D.new()
	_glow.light_color = color
	_glow.omni_range = 3.6
	_glow.light_energy = 1.3
	_glow.shadow_enabled = false
	_glow.position = Vector3(0, 0.9, 0.8)
	_visual.add_child(_glow)
