class_name ScoreStage
extends Node3D
## The between-rounds standings, built as real geometry rather than flat rectangles.
##
## Each side gets a plaque that swings in on its edge; its points are bones that drop onto the
## plaque and bounce. The point just won lands last, after a beat, so everyone watches it
## arrive. A paw trophy spins over whoever is ahead.
##
## Lives in its own SubViewport (see RoundBoard), so it composites over the frozen arena
## without the match camera or lighting having any say in how it looks.

## Plaque geometry, in metres. The camera below is framed around these numbers.
const PLAQUE_WIDTH := 7.6
const PLAQUE_HEIGHT := 1.12
const PLAQUE_DEPTH := 0.42
const ROW_GAP := 1.52
## The plaque divided into zones, as fractions of its width. Points used to start at a fixed
## offset and step by a fixed amount, which bunched them left of centre at first-to-3 and ran
## them 1.33m off the end of the plaque at first-to-10. Spreading them across a zone means any
## target fills the same space.
const NAME_ZONE := Vector2(0.04, 0.42)
const PIP_ZONE := Vector2(0.46, 0.86)
const TROPHY_AT := 0.92
## Points never draw larger than this, however few there are.
const PIP_RADIUS := 0.17
## A bone is this much wider than its radius, end to end. Slot spacing is worked out from it,
## so a row of bones is evenly spaced whatever the target is.
const BONE_SPAN := 2.76
## Breathing room around the plaques when the camera frames them.
const FRAME_MARGIN := 1.1

var _rows: Array[Node3D] = []


func build(sides: Array, target: int) -> void:
	for row in _rows:
		if is_instance_valid(row):
			row.queue_free()
	_rows.clear()
	_light()
	var total := sides.size()
	var best := 0
	for side in sides:
		best = maxi(best, int(side.get("score", 0)))
	for i in total:
		var side: Dictionary = sides[i]
		var y := (float(total - 1) * 0.5 - float(i)) * ROW_GAP
		_rows.append(_plaque(side, target, best, y, i))


## A key light from the front-left and a soft fill, so the plaques read as solid without the
## arena's own lighting reaching in.
func _light() -> void:
	if has_node("Key"):
		return
	var key := DirectionalLight3D.new()
	key.name = "Key"
	key.light_energy = 1.15
	key.light_color = Palette.SUN_COLOR
	key.rotation_degrees = Vector3(-38, 32, 0)
	add_child(key)
	var env := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_CANVAS
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Palette.AMBIENT_COLOR
	environment.ambient_light_energy = 1.1
	env.environment = environment
	add_child(env)


func _plaque(side: Dictionary, target: int, best: int, y: float, index: int) -> Node3D:
	var color: Color = side.get("color", UiKit.CREAM)
	var score: int = int(side.get("score", 0))
	var winner: bool = bool(side.get("winner", false))
	var row := Node3D.new()
	row.position = Vector3(0, y, 0)
	add_child(row)

	var board := Mats.mesh(row, Mats.box(Vector3(PLAQUE_WIDTH, PLAQUE_HEIGHT, PLAQUE_DEPTH)), color)
	Mats.mesh(row, Mats.box(Vector3(PLAQUE_WIDTH + 0.14, 0.13, PLAQUE_DEPTH + 0.14)),
		color.lightened(0.34), Vector3(0, PLAQUE_HEIGHT * 0.5, 0))
	Mats.mesh(row, Mats.box(Vector3(PLAQUE_WIDTH + 0.14, 0.13, PLAQUE_DEPTH + 0.14)),
		color.darkened(0.34), Vector3(0, -PLAQUE_HEIGHT * 0.5, 0))

	# Label3D centres its text on its own origin, so placing it at the left edge put half of a
	# wide name out past the plaque. It sits in the middle of its zone instead, and wraps
	# rather than spilling if a name is longer than the zone.
	var name_pixel := 0.0072
	var name_zone := _zone_span(NAME_ZONE)
	var name_tag := Label3D.new()
	name_tag.text = str(side.get("label", ""))
	name_tag.font = UiKit.FONT_DISPLAY
	name_tag.font_size = 50
	name_tag.pixel_size = name_pixel
	name_tag.width = name_zone.y / name_pixel
	name_tag.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_tag.modulate = Color(1, 1, 1, 0.98)
	name_tag.outline_size = 12
	name_tag.outline_modulate = color.darkened(0.6)
	name_tag.position = Vector3(name_zone.x, 0.02, PLAQUE_DEPTH * 0.5 + 0.02)
	row.add_child(name_tag)

	# Every slot is a bone, won or not, so the row reads as one evenly spaced set either way.
	# Sockets used to be small discs, which left the one bone on a plaque looking out of step.
	var slots := maxi(1, target)
	var radius := pip_radius(slots)
	for p in slots:
		var at := Vector3(pip_x(p, slots), 0.02, PLAQUE_DEPTH * 0.5 + 0.12)
		var won := p < score
		var bone := _bone(row, color, at, radius, won)
		if won:
			# The point just won arrives last, after the others have settled.
			var late := winner and p == score - 1
			_stamp_in(bone, 0.34 + float(index) * 0.07 + float(p) * 0.09 + (0.55 if late else 0.0), late)

	if score >= best and best > 0:
		_trophy(row, color)

	# The plaque swings in on its left edge rather than sliding: it reads as being set down.
	row.rotation_degrees = Vector3(0, 74, 0)
	row.position.x = -2.4
	var swing := row.create_tween()
	swing.tween_interval(float(index) * 0.1)
	swing.set_parallel(true)
	swing.tween_property(row, "rotation_degrees", Vector3.ZERO, 0.44).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	swing.tween_property(row, "position:x", 0.0, 0.44).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if winner:
		swing.chain().tween_property(board, "scale", Vector3(1.0, 1.14, 1.14), 0.16).set_trans(Tween.TRANS_BACK)
		swing.chain().tween_property(board, "scale", Vector3.ONE, 0.22).set_trans(Tween.TRANS_BOUNCE)
	return row


## The middle of a zone and its width, in plaque-local metres.
func _zone_span(zone: Vector2) -> Vector2:
	var from := -PLAQUE_WIDTH * 0.5 + PLAQUE_WIDTH * zone.x
	var to := -PLAQUE_WIDTH * 0.5 + PLAQUE_WIDTH * zone.y
	return Vector2((from + to) * 0.5, to - from)


## Where the nth of `slots` points sits, spread evenly across the pip zone.
func pip_x(index: int, slots: int) -> float:
	var span := _zone_span(PIP_ZONE)
	var step := span.y / float(maxi(1, slots))
	return span.x - span.y * 0.5 + (float(index) + 0.5) * step


## Points shrink to fit once there are enough of them to crowd, so first-to-10 reads as well
## as first-to-3 without running off the end. A bone is BONE_SPAN radii wide, and a fifth of
## the step is left as the gap between neighbours.
func pip_radius(slots: int) -> float:
	var step := _zone_span(PIP_ZONE).y / float(maxi(1, slots))
	return minf(PIP_RADIUS, step * 0.8 / BONE_SPAN)


## A dog biscuit: two knuckles and a shaft. Both states are the same shape - a point already
## won is a pale biscuit standing proud of the plaque and rimmed, an empty slot is the same
## biscuit sunk dark and flat into it - so the slots line up however the score reads.
##
## A won point is outlined in a dark shade of its own plaque colour. The bone is nearly white,
## so without it the point vanishes against a pale plaque; P4 is yellow.
func _bone(parent: Node3D, color: Color, at: Vector3, radius: float, won: bool) -> Node3D:
	var bone := Node3D.new()
	bone.name = "Point" if won else "Socket"
	# What the board is actually saying, kept off the geometry so counting points never turns
	# into counting meshes.
	bone.set_meta("point", won)
	bone.position = at
	parent.add_child(bone)
	if not won:
		# Same silhouette, pressed flat into the plaque instead of sitting on it.
		bone.scale.z = 0.3
		bone.position.z -= radius * 0.26
	var tint := Color(0.99, 0.97, 0.90) if won else color.darkened(0.44)
	var edge := color.darkened(0.66)
	# Thin. At a third of a knuckle's radius the rim swallowed the shape and the bone read as
	# a fat blob rather than a biscuit.
	var ink := radius * 0.07
	var parts: Array[MeshInstance3D] = [
		Mats.mesh(bone, Mats.box(Vector3(radius * 1.9, radius * 0.78, radius * 0.78)), tint),
	]
	for side in [-1.0, 1.0]:
		for lift in [-1.0, 1.0]:
			parts.append(Mats.mesh(bone, Mats.sphere(radius * 0.46), tint,
				Vector3(side * radius * 0.92, lift * radius * 0.34, 0)))
	if won:
		for part in parts:
			Mats.outline(part, ink, edge)
	return bone


## A point lands in its own socket and is stamped into place. Points used to fall in from above
## the plaque, which meant a new one spent its whole animation over the rows above before
## arriving - it read as being taken off another player rather than earned by this one - and on
## a board of stacked rows there is nowhere to fall from that does not cross somebody.
func _stamp_in(bone: Node3D, delay: float, emphasise: bool) -> void:
	bone.scale = Vector3.ZERO
	var stamp := bone.create_tween()
	stamp.tween_interval(delay)
	stamp.tween_property(bone, "scale", Vector3.ONE, 0.30 if emphasise else 0.2) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if emphasise:
		# The point just won turns in as it lands, so it is the one everybody watches.
		stamp.parallel().tween_property(bone, "rotation_degrees", Vector3.ZERO, 0.42) \
			.from(Vector3(0, 0, -200.0)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## A spinning paw over whoever is ahead.
func _trophy(parent: Node3D, color: Color) -> void:
	var trophy := Sprite3D.new()
	trophy.texture = UiKit.paw_texture()
	trophy.modulate = UiKit.YELLOW
	trophy.pixel_size = 0.0075
	trophy.no_depth_test = true
	trophy.render_priority = 6
	trophy.position = Vector3(-PLAQUE_WIDTH * 0.5 + PLAQUE_WIDTH * TROPHY_AT, 0.06, PLAQUE_DEPTH * 0.5 + 0.3)
	parent.add_child(trophy)
	var spin := trophy.create_tween().set_loops()
	spin.tween_property(trophy, "scale", Vector3(1.16, 1.16, 1.16), 0.7).set_trans(Tween.TRANS_SINE)
	spin.tween_property(trophy, "scale", Vector3.ONE, 0.7).set_trans(Tween.TRANS_SINE)


## How much world the plaques occupy, including a margin. The viewport is shaped to match
## this, so the board fills its frame instead of sitting in the middle of empty space - at four
## rows the plaques were covering less than half the width of the picture.
func content_size(rows: int) -> Vector2:
	return Vector2(PLAQUE_WIDTH * FRAME_MARGIN, maxf(2.4, float(rows) * ROW_GAP + 0.5))


## Frames however many rows there are, so two packs and four dogs both sit correctly. Assumes
## the viewport already has the aspect content_size asks for.
func frame_camera(camera: Camera3D, rows: int) -> void:
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = content_size(rows).y
	camera.position = Vector3(0, 0, 11.0)
	camera.rotation_degrees = Vector3(0, -2.5, 0)
