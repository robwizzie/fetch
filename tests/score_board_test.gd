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

	# Two packs and four dogs both have to fit in frame.
	var camera := view.get_camera_3d()
	_check(camera != null, "the stage has a camera")
	stage.frame_camera(camera, 2)
	var two := camera.size
	stage.frame_camera(camera, 4)
	_check(camera.size > two, "four rows frame wider than two")
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


## Points are bones; sockets are plain cylinders. Counting the bones counts the score.
func _count_bones(row: Node3D) -> int:
	var total := 0
	for child in row.get_children():
		# A bone is the only bare Node3D holding meshes; plaque parts and sockets are meshes.
		if child.get_class() == "Node3D" and (child as Node3D).get_child_count() >= 5:
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
