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
## Where the pips start, measured from the plaque's left edge, leaving room for the name.
const PIP_START := 3.15
const PIP_STEP := 0.62
const PIP_RADIUS := 0.2

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

	var name_tag := Label3D.new()
	name_tag.text = str(side.get("label", ""))
	name_tag.font = UiKit.FONT_DISPLAY
	name_tag.font_size = 68
	name_tag.pixel_size = 0.0072
	name_tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	name_tag.modulate = Color(1, 1, 1, 0.98)
	name_tag.outline_size = 12
	name_tag.outline_modulate = color.darkened(0.6)
	name_tag.position = Vector3(-PLAQUE_WIDTH * 0.5 + 0.4, 0.02, PLAQUE_DEPTH * 0.5 + 0.02)
	row.add_child(name_tag)

	# Points as bones on the plaque: filled ones are bright, the rest are sockets waiting.
	for p in maxi(1, target):
		var at := Vector3(-PLAQUE_WIDTH * 0.5 + PIP_START + float(p) * PIP_STEP, 0.02, PLAQUE_DEPTH * 0.5 + 0.12)
		if p < score:
			var bone := _bone(row, color, at)
			# The point just won arrives last, after the others have settled.
			var late := winner and p == score - 1
			_drop_in(bone, at, 0.34 + float(index) * 0.07 + float(p) * 0.09 + (0.55 if late else 0.0), late)
		else:
			var socket := Mats.mesh(row, Mats.cylinder(PIP_RADIUS * 0.82, 0.07), color.darkened(0.45), at)
			socket.rotation_degrees = Vector3(90, 0, 0)

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


## A dog biscuit: two knuckles and a shaft, which reads as a point at this size.
func _bone(parent: Node3D, color: Color, at: Vector3) -> Node3D:
	var bone := Node3D.new()
	bone.position = at
	parent.add_child(bone)
	var pale := Color(0.99, 0.97, 0.90)
	Mats.mesh(bone, Mats.box(Vector3(PIP_RADIUS * 1.9, PIP_RADIUS * 0.78, PIP_RADIUS * 0.78)), pale)
	for side in [-1.0, 1.0]:
		for lift in [-1.0, 1.0]:
			Mats.mesh(bone, Mats.sphere(PIP_RADIUS * 0.46), pale,
				Vector3(side * PIP_RADIUS * 0.92, lift * PIP_RADIUS * 0.34, 0))
	return bone


## Drops a bone onto the plaque with a bounce. A won point lands harder and flashes.
func _drop_in(bone: Node3D, at: Vector3, delay: float, emphasise: bool) -> void:
	bone.position = at + Vector3(0, 3.4, 0)
	bone.scale = Vector3.ONE * (1.5 if emphasise else 1.0)
	var drop := bone.create_tween()
	drop.tween_interval(delay)
	drop.tween_property(bone, "position", at, 0.30).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	if emphasise:
		drop.parallel().tween_property(bone, "scale", Vector3.ONE, 0.30).set_trans(Tween.TRANS_BACK)
		drop.tween_property(bone, "rotation_degrees", Vector3(0, 0, 360), 0.5).set_trans(Tween.TRANS_QUAD)


## A spinning paw over whoever is ahead.
func _trophy(parent: Node3D, color: Color) -> void:
	var trophy := Sprite3D.new()
	trophy.texture = UiKit.paw_texture()
	trophy.modulate = UiKit.YELLOW
	trophy.pixel_size = 0.0075
	trophy.no_depth_test = true
	trophy.render_priority = 6
	trophy.position = Vector3(PLAQUE_WIDTH * 0.5 - 0.55, 0.06, PLAQUE_DEPTH * 0.5 + 0.3)
	parent.add_child(trophy)
	var spin := trophy.create_tween().set_loops()
	spin.tween_property(trophy, "scale", Vector3(1.16, 1.16, 1.16), 0.7).set_trans(Tween.TRANS_SINE)
	spin.tween_property(trophy, "scale", Vector3.ONE, 0.7).set_trans(Tween.TRANS_SINE)


## Frames however many rows there are, so two packs and four dogs both sit correctly.
func frame_camera(camera: Camera3D, rows: int) -> void:
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = maxf(3.6, float(rows) * ROW_GAP + 1.5)
	camera.position = Vector3(0.35, 0, 11.0)
	camera.rotation_degrees = Vector3(0, -2.5, 0)
