class_name PracticeCard
extends PanelContainer
## One player's lesson for the practice pens: their own keys, drawn as keys, beside their own
## pen, ticking off as they actually do each thing.
##
## It replaced a single shared prompt at the bottom of the screen. That one listed everybody's
## keys at once ("WASD / Arrow keys"), and ticked a step off as soon as any one dog had done it,
## so a second player could be told they had learned to throw without ever having thrown.
##
## Nothing here is compulsory: the pen opens when its pad is stood on, whatever is ticked.

const WIDTH := 360.0
## Gap between the card and the pen it describes, in pixels.
const GAP := 22.0

var slot: PlayerSlot
var dog: Dog
var pen: ReadyPen
var camera: Camera3D

## Step key -> its row, in the order they are taught.
var _rows: Dictionary = {}
var _done: Dictionary = {}
var _order: Array[String] = []
var _ready_row: Control


func setup(p_slot: PlayerSlot, p_dog: Dog, p_pen: ReadyPen, p_camera: Camera3D) -> void:
	slot = p_slot
	dog = p_dog
	pen = p_pen
	camera = p_camera
	Events.toy_thrown.connect(_on_thrown)
	Events.toy_caught.connect(_on_caught)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(WIDTH, 0)
	add_theme_stylebox_override("panel", UiKit.panel_style(slot.color, Color(0.06, 0.11, 0.08, 0.92)))
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 7)
	add_child(column)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	head.add_child(UiKit.chip(slot.label, slot.color, 20))
	var device := UiKit.label(DeviceInput.family_name(slot.device), 18, Color(1, 1, 1, 0.75))
	device.autowrap_mode = TextServer.AUTOWRAP_OFF
	head.add_child(device)
	column.add_child(head)
	var device_id := slot.device
	_add_step(column, "move", UiKit.keycaps(&"move", device_id), "Move")
	_add_step(column, "pickup", null, "Run over your toy to pick it up")
	_add_step(column, "throw", UiKit.keycaps(&"throw", device_id), "Throw  ·  hold it for a harder throw")
	_add_step(column, "catch", UiKit.keycaps(&"throw", device_id), "Catch: same button, paws empty, as a toy flies at you")
	_add_step(column, "dash", UiKit.keycaps(&"dash", device_id), "Dash  ·  nothing can hit you mid-dash")
	var rule := UiKit.label("One hit from a flying toy and you're out!", 17, UiKit.YELLOW)
	rule.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(rule)
	_ready_row = _row(null, "Done? Stand on your pad to start", slot.color.lightened(0.4))
	column.add_child(_ready_row)
	_refresh()


func _add_step(column: VBoxContainer, key: String, keys: Control, text: String) -> void:
	var row := _row(keys, text, UiKit.CREAM)
	column.add_child(row)
	_rows[key] = row
	_done[key] = false
	_order.append(key)


func _row(keys: Control, text: String, color: Color) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var tick := UiKit.label("•", 20, Color(1, 1, 1, 0.4))
	tick.name = "Tick"
	tick.custom_minimum_size = Vector2(20, 0)
	tick.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(tick)
	if keys != null:
		row.add_child(keys)
	var words := UiKit.label(text, 18, color)
	words.name = "Words"
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	words.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	words.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	row.add_child(words)
	return row


func _process(_delta: float) -> void:
	if not is_instance_valid(dog) or not is_instance_valid(pen):
		return
	var changed := false
	if not _done.move and dog.velocity.length() > 0.6:
		changed = _tick("move")
	if not _done.pickup and dog.held_toy != null:
		changed = _tick("pickup")
	if not _done.dash and not dog.dash_ready():
		changed = _tick("dash")
	if changed:
		_refresh()
	_place()


func _on_thrown(_toy: Node, by: Node) -> void:
	if by == dog and not _done.throw:
		_tick("throw")
		_refresh()


func _on_caught(_toy: Node, by: Node) -> void:
	if by == dog and not _done.catch:
		_tick("catch")
		_refresh()


func _tick(key: String) -> bool:
	_done[key] = true
	Sfx.play("ui", 1.3, -6.0)
	var row: Control = _rows[key]
	row.pivot_offset = row.size * 0.5
	Juice.pop(row, 1.08, 0.2)
	return true


## Done steps go green and quiet; the next one to try is the bright one.
func _refresh() -> void:
	var current := ""
	for key in _order:
		if not _done[key]:
			current = key
			break
	for key in _order:
		var row: Control = _rows[key]
		var tick: Label = row.get_node("Tick")
		var words: Label = row.get_node("Words")
		if _done[key]:
			tick.text = "✓"
			tick.add_theme_color_override("font_color", Color(0.5, 0.95, 0.5))
			row.modulate = Color(1, 1, 1, 0.55)
			words.add_theme_color_override("font_color", UiKit.CREAM)
		elif key == current:
			tick.text = "▶"
			tick.add_theme_color_override("font_color", UiKit.YELLOW)
			row.modulate = Color.WHITE
			words.add_theme_color_override("font_color", UiKit.YELLOW)
		else:
			tick.text = "•"
			tick.add_theme_color_override("font_color", Color(1, 1, 1, 0.4))
			row.modulate = Color(1, 1, 1, 0.8)
			words.add_theme_color_override("font_color", UiKit.CREAM)
	# Once everything has been tried, the way out is what matters.
	var finished := current.is_empty()
	var ready_words: Label = _ready_row.get_node("Words")
	ready_words.add_theme_font_size_override("font_size", 21 if finished else 18)
	(_ready_row.get_node("Tick") as Label).text = "▶" if finished else "•"


## Beside the pen, on whichever side has the room, and never off the screen.
func _place() -> void:
	if camera == null:
		return
	var viewport := get_viewport_rect().size
	var half := pen.footprint() * 0.5
	var left_edge := camera.unproject_position(pen.global_position + Vector3(-half.x, 0, 0))
	var right_edge := camera.unproject_position(pen.global_position + Vector3(half.x, 0, 0))
	var middle := camera.unproject_position(pen.global_position)
	var x := left_edge.x - GAP - size.x if middle.x < viewport.x * 0.5 else right_edge.x + GAP
	var y := middle.y - size.y * 0.5
	position = Vector2(clampf(x, 8.0, viewport.x - size.x - 8.0), clampf(y, 8.0, viewport.y - size.y - 8.0))


func dismiss() -> void:
	var fade := create_tween()
	fade.tween_property(self, "modulate:a", 0.0, 0.3)
	fade.tween_callback(queue_free)
