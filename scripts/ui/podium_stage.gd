class_name PodiumStage
extends Node3D
## The end-of-match ceremony, as a little 3D set rather than a menu: every dog stands on a
## podium in its player colour at the height its placing earned, the winner celebrates under a
## spotlight with a crown, last place sees stars, and confetti comes down over the lot.
##
## Lives in its own SubViewport (see the results screen), so the match's camera, light and
## environment have no say in how it looks. The results screen hangs each dog's card under its
## podium using [method card_anchor].

## Podium footprint and spacing, in metres. The camera below is framed around these numbers.
const PODIUM_WIDTH := 2.0
const PODIUM_DEPTH := 1.7
const SPACING := 2.55
## How tall each placing stands. Ties share a height.
const HEIGHTS := [1.35, 0.95, 0.62, 0.36]
## Left-to-right order of placings on the stage, by how many dogs there are: the winner in the
## middle, runner-up on its left, third on its right, fourth out on the end.
const ORDER := {1: [0], 2: [0, 1], 3: [1, 0, 2], 4: [1, 0, 2, 3]}

var camera: Camera3D
var _anchors: Array[Vector3] = []
var _crown: Node3D
var _models: Array[DogModel] = []


## [param entries] are dictionaries of {slot: PlayerSlot, place: int (1 = winner), color: Color},
## already sorted best first. Returns nothing; read the anchors back with [method card_anchor].
func build(entries: Array) -> void:
	_set_dressing()
	_anchors.clear()
	_models.clear()
	var count := entries.size()
	var order: Array = ORDER.get(clampi(count, 1, 4), [0, 1, 2, 3])
	var lowest_place := 1
	for entry in entries:
		lowest_place = maxi(lowest_place, int(entry.place))
	for column in count:
		var rank: int = order[column] if column < order.size() else column
		var entry: Dictionary = entries[rank]
		var place: int = entry.place
		var x := (float(column) - float(count - 1) * 0.5) * SPACING
		var height: float = HEIGHTS[clampi(place - 1, 0, HEIGHTS.size() - 1)]
		_podium(Vector3(x, 0, 0), height, entry.color, place)
		var winner := place == 1
		var last := count > 2 and place == lowest_place and place > 1
		_dog(entry.slot, Vector3(x, height, 0.05), x, winner, last)
		_anchors.append(Vector3(x, 0.0, PODIUM_DEPTH * 0.5))
	# Anchors follow the stage left to right; hand them back in standings order.
	var by_rank: Array[Vector3] = []
	by_rank.resize(count)
	for column in count:
		var rank: int = order[column] if column < order.size() else column
		by_rank[rank] = _anchors[column]
	_anchors = by_rank
	_confetti(entries)


## Where the card for the dog at [param rank] (0 = best) should hang: the front foot of its
## podium, in world space.
func card_anchor(rank: int) -> Vector3:
	return _anchors[rank] if rank >= 0 and rank < _anchors.size() else Vector3.ZERO


func _process(delta: float) -> void:
	# Keeps the idle dogs breathing and their stars turning; the winner's celebration runs itself.
	for model in _models:
		if is_instance_valid(model):
			model.update_motion(Vector3(0, 0, 1), 0.0, delta)


## The set: a lawn stage with a hedge behind it, bunting overhead, a camera and the lights.
func _set_dressing() -> void:
	var env := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("1d3326")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Palette.AMBIENT_COLOR
	environment.ambient_light_energy = 0.55
	environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	environment.fog_enabled = true
	environment.fog_light_color = Color("1d3326")
	environment.fog_density = 0.035
	environment.fog_sky_affect = 0.0
	env.environment = environment
	add_child(env)
	var key := DirectionalLight3D.new()
	key.light_color = Palette.SUN_COLOR
	key.light_energy = 0.85
	key.rotation_degrees = Vector3(-42, -28, 0)
	key.shadow_enabled = true
	key.shadow_opacity = 0.7
	key.directional_shadow_max_distance = 40.0
	add_child(key)
	var fill := DirectionalLight3D.new()
	fill.light_color = Color("a9c4ff")
	fill.light_energy = 0.3
	fill.rotation_degrees = Vector3(-25, 150, 0)
	add_child(fill)
	# The lawn: a mown checkerboard like the arenas', on a raised wooden stage.
	ArenaArt.block(self, Vector3(14.0, 0.4, 6.4), Palette.WOOD_DARK, Vector3(0, -0.2, 0.2), Vector3.ZERO, 0.12)
	for col in 10:
		for row in 4:
			var tint := Palette.GRASS.lightened(0.05) if (col + row) % 2 == 0 else Palette.GRASS.darkened(0.06)
			var tile := Mats.mesh_plain(self, Mats.box(Vector3(1.32, 0.02, 1.48)), tint, Vector3(-5.94 + col * 1.32, 0.01, -2.02 + row * 1.48))
			tile.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	Mats.mesh_plain(self, Mats.box(Vector3(80, 0.2, 60)), Color("223a2a"), Vector3(0, -0.5, -10))
	# A hedge across the back and a couple of trees, so the dogs stand in a park, not a void.
	for i in 9:
		var x := -8.0 + i * 2.0
		Mats.mesh(self, Mats.sphere(1.25), Palette.LEAF.darkened(0.25 + 0.06 * float(i % 2)), Vector3(x, 0.9, -3.6), Vector3.ZERO, Vector3(1.0, 0.95, 0.8))
	for side in [-1.0, 1.0]:
		Mats.mesh(self, Mats.cylinder(0.2, 2.8, 0.14), Color("816550"), Vector3(side * 7.6, 1.4, -2.6))
		Mats.mesh(self, Mats.sphere(1.6), Palette.LEAF.darkened(0.12), Vector3(side * 7.6, 3.4, -2.6))
	camera = Camera3D.new()
	camera.fov = 32.0
	camera.near = 0.5
	camera.far = 80.0
	add_child(camera)
	camera.look_at_from_position(Vector3(0, 3.1, 11.5), Vector3(0, 1.25, 0), Vector3.UP)


func _podium(at: Vector3, height: float, color: Color, place: int) -> void:
	ArenaArt.block(self, Vector3(PODIUM_WIDTH, height, PODIUM_DEPTH), color, at + Vector3(0, height * 0.5, 0), Vector3.ZERO, 0.1)
	# A lighter cap so the top edge reads against the hedge.
	ArenaArt.block(self, Vector3(PODIUM_WIDTH + 0.08, 0.12, PODIUM_DEPTH + 0.08), color.lightened(0.3), at + Vector3(0, height - 0.04, 0), Vector3.ZERO, 0.05)
	var number := Label3D.new()
	number.text = str(place)
	number.font = UiKit.FONT_DISPLAY
	number.font_size = 160
	# Sized to its own step, so the short ones' numbers stay on the front face.
	number.pixel_size = minf(0.0042, height * 0.68 / 160.0)
	number.outline_size = 28
	number.outline_modulate = color.darkened(0.55)
	number.modulate = UiKit.YELLOW if place == 1 else UiKit.CREAM
	number.position = at + Vector3(0, height * 0.46, PODIUM_DEPTH * 0.5 + 0.02)
	number.shaded = false
	add_child(number)


func _dog(slot: PlayerSlot, at: Vector3, x: float, winner: bool, last: bool) -> void:
	var model := DogModel.new()
	add_child(model)
	model.setup(slot.dog, slot.color)
	# Everyone keeps their hat on the podium; the winner trades theirs for the crown.
	if not winner:
		model.set_hat(Game.hat(slot.hat))
	model.position = at
	# Turned a little in towards the winner, the way people stand on a podium.
	var facing := Vector3(-x * 0.06, 0, 1).normalized()
	model.update_motion(facing, 0.0, 1.0)
	if winner:
		model.play_victory()
		_crown_on(model, at, slot.dog)
		var spot := SpotLight3D.new()
		spot.light_color = Color("fff1c8")
		spot.light_energy = 7.0
		spot.spot_angle = 18.0
		spot.spot_range = 14.0
		spot.shadow_enabled = false
		add_child(spot)
		spot.look_at_from_position(at + Vector3(0, 7.5, 3.0), at, Vector3.UP)
	else:
		if last:
			model.set_dizzy(true)
		_models.append(model)


## A gold crown on the winner's head - on it, riding the head bone through every hop of the
## celebration, set at a slight angle. The placeholder model has no head bone, so it floats
## just above that one instead.
func _crown_on(model: DogModel, at: Vector3, _data: DogData) -> void:
	_crown = Node3D.new()
	_crown.name = "Crown"
	var head := model.head_top_anchor()
	if head != null:
		head.add_child(_crown)
		# Sunk a little so the band sits in the fur rather than balancing on top of it.
		# Set back a touch from the very top - the top of a dog's head is just behind the brow -
		# so the band clears the eyes.
		_crown.position = Vector3(0, -0.06, 0.05)
		_crown.rotation_degrees = Vector3(-10, 0, 8)
		_crown.scale = Vector3.ONE * 0.72
	else:
		_crown.position = at + Vector3(0, model.height() + 0.05, 0)
		add_child(_crown)
	var gold := Palette.GOLD.lightened(0.1)
	Mats.mesh(_crown, Mats.cylinder(0.3, 0.16, 0.32), gold, Vector3(0, 0.08, 0))
	for i in 5:
		var angle := TAU * float(i) / 5.0
		var tip := Vector3(cos(angle) * 0.27, 0.27, sin(angle) * 0.27)
		Mats.mesh(_crown, Mats.cone(0.085, 0.24), gold, tip)
		Mats.mesh(_crown, Mats.sphere(0.05), Color("e94b5a") if i % 2 == 0 else Color("4fb3e8"), tip + Vector3(0, 0.14, 0))
	# The crown arrives: dropped onto the head with a bounce once the screen is up.
	var settle := _crown.position
	_crown.position = settle + Vector3(0, 1.2, 0)
	var drop := _crown.create_tween()
	drop.tween_interval(0.45)
	drop.tween_property(_crown, "position", settle, 0.4).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)


## Confetti in the players' colours, already falling when the screen appears.
func _confetti(entries: Array) -> void:
	var particles := CPUParticles3D.new()
	particles.amount = 260
	particles.lifetime = 5.0
	particles.preprocess = 4.0
	particles.position = Vector3(0, 6.5, 0.5)
	particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	particles.emission_box_extents = Vector3(7.5, 0.2, 2.5)
	particles.direction = Vector3(0, -1, 0)
	particles.spread = 25.0
	particles.gravity = Vector3(0, -1.6, 0)
	particles.initial_velocity_min = 0.2
	particles.initial_velocity_max = 0.8
	particles.angular_velocity_min = -280.0
	particles.angular_velocity_max = 280.0
	particles.particle_flag_rotate_y = true
	particles.damping_min = 0.4
	particles.damping_max = 1.0
	var piece := QuadMesh.new()
	piece.size = Vector2(0.13, 0.08)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	piece.material = material
	particles.mesh = piece
	var colors := Gradient.new()
	colors.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT
	var palette: Array[Color] = [UiKit.YELLOW, UiKit.CREAM]
	for entry in entries:
		palette.append(entry.color)
	var offsets := PackedFloat32Array()
	var tints := PackedColorArray()
	for i in palette.size():
		offsets.append(float(i) / float(palette.size()))
		tints.append(palette[i].lightened(0.1))
	colors.offsets = offsets
	colors.colors = tints
	particles.color_initial_ramp = colors
	add_child(particles)
