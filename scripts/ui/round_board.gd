class_name RoundBoard
extends Control
## The between-rounds scoreboard: one bar per side, a pip for every point on the way to the
## win, and a crown on whoever is ahead. It sits over the frozen arena so the round that just
## finished is still visible behind it.
##
## Works the same for a free-for-all (one bar per dog) and for teams (one bar per pack).

signal dismissed

## How long the board stays up on its own. Long enough to read the pips, short enough that
## nobody reaches for the button.
const DWELL := 3.2
## Below this the board is left alone; a press only skips once the numbers have landed.
const SKIP_AFTER := 0.6

var _time := 0.0
var _rows: VBoxContainer
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

	_rows = VBoxContainer.new()
	_rows.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_rows.add_theme_constant_override("separation", 14)
	_rows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(_rows)

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
	_headline.text = headline
	_continue.text = prompt
	for child in _rows.get_children():
		child.queue_free()
	var best := 0
	for side in sides:
		best = maxi(best, int(side.get("score", 0)))
	for side in sides:
		_rows.add_child(_bar(side, target, best))
	Juice.pop(_headline, 1.25, 0.35)


## One side's bar: a name plate in their colour, then a pip per point.
func _bar(side: Dictionary, target: int, best: int) -> Control:
	var color: Color = side.get("color", UiKit.CREAM)
	var score: int = int(side.get("score", 0))
	var bar := PanelContainer.new()
	# Shrink-centre, or the VBox stretches every bar the full width of the screen.
	bar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	bar.custom_minimum_size = Vector2(700, 70)
	var style := CoverStage.paper_style(Color(color, 0.82), color.lightened(0.35), 16)
	style.shadow_size = 0
	bar.add_theme_stylebox_override("panel", style)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(row)

	var margin := Control.new()
	margin.custom_minimum_size = Vector2(6, 0)
	row.add_child(margin)

	var name_label := UiKit.label(str(side.get("label", "")), 27, Color(1, 1, 1, 0.97))
	name_label.custom_minimum_size = Vector2(238, 54)
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	row.add_child(name_label)

	# A paw marks whoever is ahead, so the standings read without counting pips. The UI fonts
	# carry no emoji, so this is the drawn paw rather than a character.
	var crown := TextureRect.new()
	crown.custom_minimum_size = Vector2(40, 54)
	crown.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	crown.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	crown.texture = UiKit.paw_texture()
	crown.modulate = UiKit.YELLOW
	crown.visible = score >= best and best > 0
	crown.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(crown)

	var pips := HBoxContainer.new()
	# Takes whatever width is left after the name, so the pips sit across the bar instead of
	# bunching up against the name plate.
	pips.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pips.add_theme_constant_override("separation", 7)
	pips.alignment = BoxContainer.ALIGNMENT_CENTER
	pips.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(pips)
	for i in maxi(1, target):
		pips.add_child(_pip(i < score, color))
	var tail := Control.new()
	tail.custom_minimum_size = Vector2(10, 0)
	row.add_child(tail)

	if bool(side.get("winner", false)):
		bar.modulate = Color(1.18, 1.18, 1.18)
		Juice.pop(bar, 1.1, 0.45)
	return bar


func _pip(filled: bool, color: Color) -> Control:
	var dot := Panel.new()
	dot.custom_minimum_size = Vector2(30, 30)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(1, 1, 1, 0.92) if filled else color.darkened(0.42)
	style.corner_radius_top_left = 15
	style.corner_radius_top_right = 15
	style.corner_radius_bottom_left = 15
	style.corner_radius_bottom_right = 15
	dot.add_theme_stylebox_override("panel", style)
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return dot


func _process(delta: float) -> void:
	if not visible or _done:
		return
	_time += delta
	if _time >= DWELL:
		_finish()


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
	dismissed.emit()
