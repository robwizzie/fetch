class_name RoundBoard
extends Control
## The between-rounds scoreboard: one bar per side, a pip for every point on the way to the
## win, and a crown on whoever is ahead. It sits over the frozen arena so the round that just
## finished is still visible behind it.
##
## Works the same for a free-for-all (one bar per dog) and for teams (one bar per pack).

signal dismissed

## The board waits to be dismissed: rounds should not run away from a table still arguing
## about what just happened. Only an all-bot lobby, with nobody there to press anything,
## moves on by itself after this long.
const DWELL := 3.2
## Below this a press is ignored, so whatever button someone was mashing when the round ended
## does not skip the board before the bones have landed.
const SKIP_AFTER := 0.6

## How tall the 3D stage is drawn, in pixels. Rendered at this size and scaled to fit, so the
## plaques stay crisp on a 1080p cabinet without paying for a full-screen 3D pass.
const STAGE_SIZE := Vector2i(1280, 620)

var _time := 0.0
## True when no human is playing, in which case the board advances on its own.
var _auto := true
var _stage: ScoreStage
var _stage_view: SubViewport
var _stage_rect: TextureRect
var _headline: Label
var _continue: Label
var _done := false


func _ready() -> void:
	# The HUD is a CanvasLayer, which gives a Control child no parent rect to anchor against,
	# so the board sizes itself from the viewport instead.
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	var scrim := ColorRect.new()
	scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scrim.color = Color(0.04, 0.06, 0.05, 0.55)
	scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(scrim)

	var column := VBoxContainer.new()
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 18)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(column)

	_headline = UiKit.title("", 58, UiKit.YELLOW)
	_headline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_headline.autowrap_mode = TextServer.AUTOWRAP_OFF
	column.add_child(_headline)

	# The standings are real geometry in their own little world, composited over the frozen
	# arena. Flat bars never looked like they belonged in the same game as the dogs.
	_stage_view = SubViewport.new()
	_stage_view.size = STAGE_SIZE
	_stage_view.own_world_3d = true
	_stage_view.transparent_bg = true
	# Off until the board is actually up. Left on UPDATE_ALWAYS it keeps rendering a 3D pass
	# every frame for the rest of the match behind a hidden control, which is pure waste and
	# was enough to starve a round of its own frames.
	_stage_view.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_stage_view.msaa_3d = Viewport.MSAA_4X
	add_child(_stage_view)
	_stage = ScoreStage.new()
	_stage_view.add_child(_stage)
	var camera := Camera3D.new()
	_stage_view.add_child(camera)
	_stage.frame_camera(camera, 4)
	camera.make_current()

	_stage_rect = TextureRect.new()
	_stage_rect.texture = _stage_view.get_texture()
	_stage_rect.custom_minimum_size = Vector2(STAGE_SIZE) * 0.72
	_stage_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_stage_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_stage_rect.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_stage_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(_stage_rect)

	_continue = UiKit.label("", 26, Color(1, 1, 1, 0.8))
	_continue.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_continue.autowrap_mode = TextServer.AUTOWRAP_OFF
	column.add_child(_continue)

	_fit()
	get_viewport().size_changed.connect(_fit)


func _fit() -> void:
	position = Vector2.ZERO
	size = get_viewport().get_visible_rect().size


## `sides` is one entry per bar: {label, color, score, winner}. `target` is points to win.
func show_board(headline: String, sides: Array, target: int, prompt: String) -> void:
	_time = 0.0
	_done = false
	visible = true
	_auto = true
	for slot in Game.slots:
		if not slot.is_bot and slot.device != DeviceInput.VIRTUAL:
			_auto = false
	_stage_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_headline.text = headline
	_continue.text = prompt
	var camera := _stage_view.get_camera_3d()
	if camera != null:
		_stage.frame_camera(camera, sides.size())
	_stage.build(sides, target)
	Juice.pop(_headline, 1.25, 0.35)


func _process(delta: float) -> void:
	if not visible or _done:
		return
	_time += delta
	if _auto:
		if _time >= DWELL:
			_finish()
	elif _time > SKIP_AFTER:
		# The prompt breathes once the board can be dismissed, so it reads as a button waiting
		# on you rather than a caption that happens to be there.
		_continue.modulate.a = 0.70 + sin(_time * 4.2) * 0.30


func _unhandled_input(event: InputEvent) -> void:
	if not visible or _done or _time < SKIP_AFTER:
		return
	# ui_accept is the only action bound in the InputMap; DeviceInput polls gameplay buttons
	# itself, and Game binds every pad button to ui_accept on a cabinet.
	if event.is_action_pressed(&"ui_accept"):
		_finish()
		get_viewport().set_input_as_handled()


func _finish() -> void:
	if _done:
		return
	_done = true
	visible = false
	_stage_view.render_target_update_mode = SubViewport.UPDATE_DISABLED
	dismissed.emit()
