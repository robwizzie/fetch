class_name CarouselRow
extends Button
## A focusable option row: its name on the left, the current choice on the right between two
## arrow buttons. Left/right (keyboard, dpad or stick), pressing it, or clicking an arrow cycles
## the choice. A row of pips under the choice says how many there are and which one this is.

signal changed(index: int)

const HEIGHT := 64.0

var title := ""
var items: PackedStringArray = []
var index := 0
var _name: Label
var _value: Label
var _pips: Control


func setup(p_title: String, p_items: PackedStringArray, start: int = 0) -> void:
	title = p_title
	items = p_items
	index = clampi(start, 0, maxi(items.size() - 1, 0))
	custom_minimum_size = Vector2(900, HEIGHT)
	# Rows are set up again when another choice changes what they offer.
	if _value == null:
		_build()
	_refresh()


func _build() -> void:
	var rest := _style(Color(0.04, 0.09, 0.06, 0.8), Color(1, 1, 1, 0.14), 2)
	var lit := _style(Color(0.1, 0.19, 0.12, 0.92), UiKit.YELLOW, 4)
	lit.shadow_color = Color(UiKit.YELLOW, 0.28)
	lit.shadow_size = 10
	add_theme_stylebox_override("normal", rest)
	add_theme_stylebox_override("hover", lit)
	add_theme_stylebox_override("focus", lit)
	add_theme_stylebox_override("pressed", lit)
	add_theme_stylebox_override("hover_pressed", lit)
	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 28
	row.offset_right = -14
	row.add_theme_constant_override("separation", 10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(row)
	_name = UiKit.label(title, 25, Color(1, 1, 1, 0.82))
	_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_name.autowrap_mode = TextServer.AUTOWRAP_OFF
	_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name.size_flags_vertical = Control.SIZE_FILL
	row.add_child(_name)
	row.add_child(_arrow(-1))
	var middle := VBoxContainer.new()
	middle.custom_minimum_size = Vector2(300, 0)
	middle.alignment = BoxContainer.ALIGNMENT_CENTER
	middle.add_theme_constant_override("separation", 0)
	middle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(middle)
	_value = UiKit.title("", 27, UiKit.YELLOW)
	_value.autowrap_mode = TextServer.AUTOWRAP_OFF
	_value.add_theme_constant_override("outline_size", 6)
	middle.add_child(_value)
	_pips = Control.new()
	_pips.custom_minimum_size = Vector2(0, 8)
	_pips.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pips.draw.connect(_draw_pips)
	middle.add_child(_pips)
	row.add_child(_arrow(1))


func _style(bg: Color, border: Color, width: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(width)
	s.set_corner_radius_all(18)
	return s


## A round arrow button. Clicking it steps that way; it is not focusable, the row is.
func _arrow(dir: int) -> Control:
	var holder := CenterContainer.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var arrow := Control.new()
	arrow.custom_minimum_size = Vector2(40, 40)
	arrow.mouse_filter = Control.MOUSE_FILTER_STOP
	arrow.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	arrow.draw.connect(func() -> void:
		var c := arrow.size * 0.5
		var lit := has_focus() or is_hovered()
		arrow.draw_circle(c + Vector2(0, 2), 19.0, Color(0, 0, 0, 0.3))
		arrow.draw_circle(c, 19.0, UiKit.WOOD if lit else Color(1, 1, 1, 0.12))
		var tip := Vector2(7.0 * dir, 0)
		arrow.draw_colored_polygon(PackedVector2Array([c + tip, c + Vector2(-5.0 * dir, -8), c + Vector2(-5.0 * dir, 8)]),
			UiKit.CREAM if lit else Color(1, 1, 1, 0.7)))
	arrow.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			grab_focus()
			step(dir)
			arrow.accept_event())
	focus_entered.connect(arrow.queue_redraw)
	focus_exited.connect(arrow.queue_redraw)
	mouse_entered.connect(arrow.queue_redraw)
	mouse_exited.connect(arrow.queue_redraw)
	holder.add_child(arrow)
	return holder


func _draw_pips() -> void:
	var count := items.size()
	if count < 2:
		return
	var gap := 12.0 if count <= 12 else 7.0
	var left := _pips.size.x * 0.5 - gap * (count - 1) * 0.5
	for i in count:
		var spot := Vector2(left + gap * i, _pips.size.y * 0.5)
		_pips.draw_circle(spot, 3.2 if i == index else 2.4, UiKit.YELLOW if i == index else Color(1, 1, 1, 0.28))


func _gui_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_left"):
		step(-1)
		accept_event()
	elif event.is_action_pressed("ui_right"):
		step(1)
		accept_event()


func _pressed() -> void:
	step(1)


func step(dir: int) -> void:
	if items.is_empty():
		return
	index = wrapi(index + dir, 0, items.size())
	_refresh()
	Sfx.play("ui_move")
	pivot_offset = size / 2.0
	Juice.pop(self, 1.02, 0.1)
	changed.emit(index)


func _refresh() -> void:
	if _value == null:
		return
	_name.text = title
	_value.text = items[index] if not items.is_empty() else "-"
	_pips.queue_redraw()
