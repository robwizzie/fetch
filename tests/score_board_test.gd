extends Node
## The between-rounds standings. Built as 3D geometry in its own viewport, so what is asserted
## here is the structure: a plaque per side, a point per pip, the right side crowned, and a
## camera framed for however many rows there are.

var failed := false


func _ready() -> void:
	Sfx.enabled = false
	Music.enabled = false
	Game.clear_players()
	for i in 4:
		var slot := PlayerSlot.new()
		slot.index = i
		slot.device = DeviceInput.VIRTUAL
		slot.dog = Game.dogs[i]
		Game.slots.append(slot)

	var board := RoundBoard.new()
	add_child(board)
	await get_tree().process_frame
	_check(board.get("_stage") != null, "the board owns a 3D stage")
	_check(board.get("_stage_view") is SubViewport, "the stage renders into its own viewport")
	var view: SubViewport = board.get("_stage_view")
	_check(view.own_world_3d, "the stage has its own world, so arena lighting cannot reach it")
	_check(view.transparent_bg, "the stage composites over the frozen arena")

	var stage: ScoreStage = board.get("_stage")
	var sides: Array = [
		{"label": "P1  SHADOW", "color": Color(0.25, 0.55, 1.0), "score": 3, "winner": true},
		{"label": "P2  GOOSE", "color": Color(0.95, 0.3, 0.3), "score": 1, "winner": false},
		{"label": "P3  LUNA", "color": Color(0.3, 0.85, 0.45), "score": 0, "winner": false},
	]
	board.show_board("SHADOW WINS THE ROUND!", sides, 5, "Press to continue")
	await get_tree().process_frame
	_check(board.visible, "showing the board makes it visible")

	var rows: Array[Node3D] = stage.get("_rows")
	_check(rows.size() == sides.size(), "one plaque per side")
	for i in rows.size():
		var side: Dictionary = sides[i]
		var bones := _count_bones(rows[i])
		_check(bones == int(side["score"]), "%s shows %d points, found %d" % [side["label"], side["score"], bones])
		var crowned := _has_trophy(rows[i])
		_check(crowned == (i == 0), "%s crowned: %s" % [side["label"], crowned])

	# Rebuilding replaces the rows rather than stacking a second set on top.
	board.show_board("AGAIN", sides, 5, "Press to continue")
	await get_tree().process_frame
	var again: Array[Node3D] = stage.get("_rows")
	_check(again.size() == sides.size(), "a second round rebuilds rather than accumulates")

	# Everything has to sit on the plaque. Points used to start at a fixed offset and step by a
	# fixed amount, which bunched them left of centre at first-to-3 and ran them clean off the
	# end of the plaque at first-to-10.
	var half := ScoreStage.PLAQUE_WIDTH * 0.5
	for slots: int in [3, 5, 7, 10]:
		var radius := stage.pip_radius(slots)
		for i in slots:
			var x := stage.pip_x(i, slots)
			_check(x - radius > -half, "first-to-%d: point %d clears the left edge" % [slots, i])
			_check(x + radius < half, "first-to-%d: point %d stays on the plaque" % [slots, i])
		if slots > 1:
			var gap: float = stage.pip_x(1, slots) - stage.pip_x(0, slots)
			_check(gap > radius * 2.0, "first-to-%d: points do not overlap" % slots)
		# However many there are, they cover the same span, so the plaque never looks lopsided.
		var span: float = stage.pip_x(slots - 1, slots) - stage.pip_x(0, slots)
		_check(span > ScoreStage.PLAQUE_WIDTH * 0.2, "first-to-%d: points spread across the plaque" % slots)

	# The board has to fill its own picture. A fixed frame left four rows covering less than
	# half the width, which is what made the standings look small and lost in empty space.
	for count: int in [2, 3, 4]:
		var content := stage.content_size(count)
		var covered := ScoreStage.PLAQUE_WIDTH / content.x
		_check(covered > 0.85, "%d rows: plaques fill %.0f%% of the frame width" % [count, covered * 100.0])

	# Two packs and four dogs both have to fit in frame.
	var camera := view.get_camera_3d()
	_check(camera != null, "the stage has a camera")
	stage.frame_camera(camera, 2)
	var two := camera.size
	stage.frame_camera(camera, 4)
	_check(camera.size > two, "four rows frame wider than two")
	# The viewport is reshaped to the content, so the camera's own aspect matches what it is
	# being asked to show rather than cropping or padding it.
	board._fit_stage(4)
	var view_aspect := float(view.size.x) / float(view.size.y)
	var want_aspect := stage.content_size(4).x / stage.content_size(4).y
	_check(absf(view_aspect - want_aspect) < 0.08,
		"the stage viewport matches the shape of four rows (%.2f vs %.2f)" % [view_aspect, want_aspect])
	_check(camera.projection == Camera3D.PROJECTION_ORTHOGONAL, "the stage is framed flat-on")

	# A press dismisses it, which is what hands the match back its banner_finished.
	var dismissed := [false]
	board.dismissed.connect(func() -> void: dismissed[0] = true)
	board.set("_time", RoundBoard.SKIP_AFTER + 0.1)
	board._finish()
	_check(dismissed[0], "finishing reports back so the match can move on")
	_check(not board.visible, "a dismissed board hides itself")

	if not failed:
		print("[score-board] PASSED: 3D stage, a plaque per side, a bone per point, crowning and framing")
	get_tree().quit(1 if failed else 0)


## Every slot on a plaque is a bone, won or not; the won ones carry the "point" flag. Counting
## those counts the score, without depending on how either state happens to be built.
func _count_bones(row: Node3D) -> int:
	var total := 0
	for child in row.get_children():
		if child.get_meta("point", false):
			total += 1
	return total


func _has_trophy(row: Node3D) -> bool:
	for child in row.get_children():
		if child is Sprite3D:
			return true
	return false


func _check(ok: bool, message: String) -> void:
	if not ok:
		failed = true
		push_error("[score-board] " + message)
