class_name ModelPreview
extends TextureRect
## A live 3D model on a menu, turning slowly on the spot.
##
## Dog select used a cropped bitmap of the reference sheet, which meant the thing you picked
## was never quite the thing you played. This renders the real model in its own little world,
## so the card shows the dog that walks out of the pen — and the same widget does duty for
## toys and power-ups in the galleries.
##
## The model lives in a SubViewport with own_world_3d, so menu lighting is ours alone and no
## arena can reach in and change it.

## Degrees per second, for the subjects that do turn. Dogs stand still: a dog revolving on the
## spot reads as a display model, not as the animal you are about to play.
const SPIN := 34.0
## How far the subject is turned when it is not spinning - just off square, so it has depth.
const RESTING_YAW := -24.0
## Framing: the subject fills this much of the frame in whichever direction binds first. The
## rest is breathing room - a dog jammed into the corners of its card reads as a mistake.
const FILL := 0.9
## How far the camera looks down on the subject. The projection is orthographic, so this only
## changes the angle you see it from - never its size, and never where it sits in frame once
## _frame() has accounted for it.
const TILT := 6.0
## How much of the leftover room goes underneath rather than above. Small: the subject should
## look like it is standing on the bottom of the card, not posed in the middle of it.
const GROUND_SHARE := 0.22
## Slack left around a dog for its tail to swing into, as a fraction of its height.
const WAG_ROOM := 0.05
## The render target is the card's own shape at this multiple, so nothing is letterboxed and
## the edges stay crisp on a big screen.
const SUPERSAMPLE := 1.5
const MAX_RESOLUTION := 1200

var _view: SubViewport
var _pivot: Node3D
var _camera: Camera3D
var _spin := true
## The subject's own box, kept so the shot can be re-framed when the card changes shape.
var _bounds := AABB()
## True while the subject is turning, when the box it sweeps matters rather than the box it
## happens to occupy right now.
var _swept := false


func _init(size: Vector2i = Vector2i(420, 420)) -> void:
	_view = SubViewport.new()
	_view.size = size
	_view.own_world_3d = true
	_view.transparent_bg = true
	# Only while it is actually on screen: a gallery left open in the background should not be
	# paying for a 3D pass per card.
	_view.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	_view.msaa_3d = Viewport.MSAA_4X
	add_child(_view)

	_pivot = Node3D.new()
	_view.add_child(_pivot)

	# A warm key with a cool fill, matching the cover's light rather than the arena's.
	var key := DirectionalLight3D.new()
	key.light_energy = 1.25
	key.light_color = Palette.SUN_COLOR
	key.rotation_degrees = Vector3(-30, 38, 0)
	_view.add_child(key)
	var fill := DirectionalLight3D.new()
	fill.light_energy = 0.45
	fill.light_color = Palette.AMBIENT_COLOR
	fill.rotation_degrees = Vector3(-14, -128, 0)
	_view.add_child(fill)
	var world := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_CANVAS
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Palette.AMBIENT_COLOR
	env.ambient_light_energy = 0.95
	world.environment = env
	_view.add_child(world)

	_camera = Camera3D.new()
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_view.add_child(_camera)
	_camera.make_current()

	texture = _view.get_texture()
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stretch_mode = TextureRect.STRETCH_SCALE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# The render target follows the card's shape, so the framing below can use every pixel of
	# it. Fixed-shape targets were letterboxed inside their panels, which is dead space the
	# subject could have been using.
	resized.connect(_match_card)


## Re-cuts the render target to the shape of the card and re-frames the shot for it.
func _match_card() -> void:
	if size.x < 1.0 or size.y < 1.0:
		return
	var wanted := Vector2i((size * SUPERSAMPLE).clamp(Vector2(16, 16), Vector2(MAX_RESOLUTION, MAX_RESOLUTION)))
	if wanted == _view.size:
		return
	_view.size = wanted
	if _bounds.size.length() > 0.0:
		_frame(_bounds)


## Puts a dog's authored model on the turntable, falling back to the procedural one when a
## dog has no model yet, so a card is never empty.
func show_dog(data: DogData, hat: HatData = null) -> void:
	_clear()
	var model := DogModel.new()
	model.setup(data, Color.WHITE)
	model.set_hat(hat)
	_pivot.add_child(model)
	# Face the camera rather than away from it: the models are authored facing +Z.
	model.rotation_degrees = Vector3(0, 180, 0)
	set_spinning(false)
	# Framed on the dog's own shape rather than on its height alone, so a long corgi and a
	# tall retriever each fill their card instead of both being sized by one number.
	_frame(_dog_bounds(model, maxf(0.4, data.model_height * data.model_scale)))
	_ground(maxf(0.2, _bounds.size.y * 0.3))
	_liven(model)


## A toy, sized from its own radius so a tennis ball and a frisbee both fill the frame.
func show_toy(data: ToyData) -> void:
	_clear()
	var model := ToyModel.new()
	model.setup(data)
	_pivot.add_child(model)
	# A toy is modelled around its middle rather than standing on its base, and it keeps
	# turning, so what is framed is the box it sweeps.
	_swept = true
	_frame(_subject_bounds())


## A hat on its own, turning, for the hat cupboard and the new-hat reveal.
func show_hat(hat: HatData) -> void:
	_clear()
	var model := HatModel.new()
	model.build(hat)
	_pivot.add_child(model)
	model.scale = Vector3.ONE * 2.2
	_swept = true
	_frame(_subject_bounds())


## The real treat tin, opened to show the power inside for the field guide.
func show_powerup(kind: StringName) -> void:
	_clear()
	var model := PowerupModel.new()
	model.setup(kind)
	_pivot.add_child(model)
	_swept = true
	_frame(_subject_bounds())


## Stops the turntable, for a still where movement would be a distraction.
func set_spinning(on: bool) -> void:
	_spin = on
	if not on:
		_pivot.rotation_degrees.y = RESTING_YAW


## A shadow under the subject, sized to it. Without one it reads as hovering in the middle of
## the card rather than standing on anything.
func _ground(radius: float) -> void:
	Mats.contact_shadow(_pivot, radius)


func _clear() -> void:
	for child in _pivot.get_children():
		_pivot.remove_child(child)
		child.queue_free()
	_pivot.rotation_degrees = Vector3.ZERO
	_bounds = AABB()
	_swept = false


## Gives a dog something to do while it stands there: a tail that swishes and a blink. Only
## the authored rigs have the bones for it; the procedural placeholder is left alone.
func _liven(model: DogModel) -> void:
	var skeletons := DogAssetValidator.find_skeletons(model)
	if skeletons.is_empty():
		return
	var skeleton := skeletons[0]
	var motion := MenuDogMotion.new()
	# The rig hangs off nodes that have been turned and scaled, so hand it the direction that
	# is actually up from where it sits.
	motion.up = (_relative(skeleton, _pivot).basis.inverse() * Vector3.UP).normalized()
	motion.phase = randf() * TAU
	skeleton.add_child(motion)


## The room a dog takes up, in the turntable's own space.
##
## Neither of the obvious measurements is in metres on its own. A skinned mesh's bounds are in
## the space the artist modelled in, and the nodes carrying it are scaled by whatever the
## import needed - for these rigs a hundredth - with the skin's bind matrices making up the
## difference. What is true of the mesh bounds is their *shape*, so they are scaled to the
## height the dog is actually delivered at, which is the one number the data does know.
func _dog_bounds(model: Node3D, height: float) -> AABB:
	var box := AABB()
	var found := false
	var skinned := false
	for node in model.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		if mesh.mesh == null:
			continue
		var skin := mesh.skin != null
		if skinned and not skin:
			continue
		# The first skinned mesh throws away anything measured off the node chain, because
		# the two are in different spaces and merging them would mean nothing.
		var part := mesh.get_aabb() if skin else _relative(mesh, model) * mesh.get_aabb()
		if skin and not skinned:
			skinned = true
			found = false
		box = part if not found else box.merge(part)
		found = true
	if not found or box.size.y <= 0.0:
		return AABB(Vector3(-height * 0.4, 0.0, -height * 0.4), Vector3(height * 0.8, height, height * 0.8))
	var to_metres := height / box.size.y
	var standing := AABB(box.position * to_metres, box.size * to_metres)
	# A wagging tail swings wider than the pose it was measured in. Room for it across the
	# floor only: the dog still has to stand on the bottom edge.
	var room := height * WAG_ROOM
	standing.position -= Vector3(room, 0.0, room)
	standing.size += Vector3(room * 2.0, 0.0, room * 2.0)
	# Only the turntable's own turn matters from here: a dog's box is symmetric about its
	# spine, so which way it faces does not change how much room it needs.
	return Transform3D(Basis.from_euler(Vector3(0, deg_to_rad(RESTING_YAW), 0)), Vector3.ZERO) * standing


## Every visible piece of a built-in-code subject, in the turntable's own space. Toys and
## crates are modelled in metres with honest node transforms, so this is simply their sum.
func _subject_bounds() -> AABB:
	var bounds := AABB()
	var found := false
	for node in _pivot.find_children("*", "VisualInstance3D", true, false):
		var visual := node as VisualInstance3D
		var own := _sprite_box(visual as Sprite3D) if visual is Sprite3D else visual.get_aabb()
		if own.size == Vector3.ZERO:
			continue
		var box := _relative(visual, _view) * own
		bounds = box if not found else bounds.merge(box)
		found = true
	if not found:
		return AABB(Vector3(-0.5, 0, -0.5), Vector3(1, 1, 1))
	if _swept:
		# A turning subject passes through every yaw, so frame the cylinder it sweeps.
		var radius := 0.0
		for i in 8:
			var corner := bounds.get_endpoint(i)
			radius = maxf(radius, Vector2(corner.x, corner.z).length())
		bounds = AABB(Vector3(-radius, bounds.position.y, -radius), Vector3(radius * 2.0, bounds.size.y, radius * 2.0))
	return bounds


## A sprite's own bounds are empty until it has been drawn once, which is never the case while
## a card is still being built - so a reward medallion measured that way is framed out of the
## shot entirely. Measured from the texture instead. A billboard always faces the camera, so
## what it covers is the same whichever way the turntable is pointing.
func _sprite_box(sprite: Sprite3D) -> AABB:
	if sprite == null or sprite.texture == null:
		return AABB()
	var half := Vector2(sprite.texture.get_size()) * sprite.pixel_size * 0.5
	return AABB(Vector3(-half.x, -half.y, 0.0), Vector3(half.x * 2.0, half.y * 2.0, 0.0))


## The transform of a node relative to one of its ancestors, composed by hand: a preview is
## framed before it is ever added to a tree, where global_transform means nothing yet.
func _relative(node: Node3D, ancestor: Node) -> Transform3D:
	var result := Transform3D.IDENTITY
	var walk: Node = node
	while walk != null and walk != ancestor:
		if walk is Node3D:
			result = (walk as Node3D).transform * result
		walk = walk.get_parent()
	return result


## Fits the shot to the subject's box: as large as the frame will take, standing on the
## bottom of it.
##
## Framed from the bottom edge rather than from the subject's middle, because the two pull in
## opposite directions: LOWERING the camera raises the subject in frame. Aiming at the middle
## and then nudging down - which reads as the obvious thing to do - pushes the dog further up
## the card, which is exactly the wrong way.
##
## The tilt has to be paid for too. A camera looking down from this far back carries the
## ground line a third of the way up the card before the subject is even placed, so putting
## the camera where the untilted maths says leaves every dog hovering over a gap.
func _frame(bounds: AABB) -> void:
	_bounds = bounds
	var span := _projected(bounds)
	var aspect := float(_view.size.x) / float(_view.size.y)
	# An orthographic camera's size is its height, so width has to be converted before the two
	# can be compared. Whichever needs more room decides the shot.
	_camera.size = maxf(span.size.y / FILL, span.size.x / (FILL * aspect))
	var depth := bounds.size.length() * 2.0 + 1.0
	var tilt := deg_to_rad(TILT)
	var margin := _camera.size * (1.0 - FILL) * GROUND_SHARE
	# Raised by the drop to the subject's feet plus the lift the tilt adds, so the feet land
	# just inside the bottom edge whatever the shot is of.
	_camera.position = Vector3(span.get_center().x,
		(span.position.y + _camera.size * 0.5 - margin + depth * sin(tilt)) / cos(tilt), depth)
	_camera.rotation_degrees = Vector3(-TILT, 0, 0)


## The subject's box as the camera sees it: x across the frame, y up it. Rect2 is read the way
## it is drawn, so position.y is the lowest point and end.y the highest. Only the tilt matters
## here, because the camera never rolls or yaws.
func _projected(bounds: AABB) -> Rect2:
	var up := Vector3(0, cos(deg_to_rad(TILT)), -sin(deg_to_rad(TILT)))
	var left := INF
	var right := -INF
	var bottom := INF
	var top := -INF
	for i in 8:
		var corner := bounds.get_endpoint(i)
		left = minf(left, corner.x)
		right = maxf(right, corner.x)
		var height := corner.dot(up)
		bottom = minf(bottom, height)
		top = maxf(top, height)
	return Rect2(left, bottom, right - left, top - bottom)


## Where the subject actually sits in the finished frame, as fractions of it: (0, 0) is the
## top-left corner and (1, 1) the bottom-right. A card with the dog filling most of it and
## standing on the bottom reads as 0.8-ish tall with an end.y just short of 1.
##
## This is what the gallery test asserts on, because it is what a player sees. The old version
## measured the camera against an untilted frame and reported dogs standing on the bottom edge
## while the cards showed them floating.
func frame_fit() -> Rect2:
	var span := _projected(_bounds)
	var half_height := _camera.size * 0.5
	var half_width := half_height * float(_view.size.x) / float(_view.size.y)
	var eye := _camera.position.y * cos(deg_to_rad(TILT)) - _camera.position.z * sin(deg_to_rad(TILT))
	var left := (span.position.x - _camera.position.x + half_width) / (half_width * 2.0)
	var top := (half_height - (span.position.y + span.size.y - eye)) / (half_height * 2.0)
	return Rect2(left, top, span.size.x / (half_width * 2.0), span.size.y / (half_height * 2.0))


func _process(delta: float) -> void:
	if _spin and is_instance_valid(_pivot):
		_pivot.rotation_degrees.y = fmod(_pivot.rotation_degrees.y + SPIN * delta, 360.0)
