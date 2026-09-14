class_name CarouselRow
extends Button
## A focusable "< value >" row. Left/right (keyboard, dpad or stick) or pressing it cycles values.

signal changed(index: int)

var title := ""
var items: PackedStringArray = []
var index := 0


func setup(p_title: String, p_items: PackedStringArray, start: int = 0) -> void:
	title = p_title
	items = p_items
	index = clampi(start, 0, maxi(items.size() - 1, 0))
	custom_minimum_size = Vector2(900, 0)
	alignment = HORIZONTAL_ALIGNMENT_CENTER
	_refresh()


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
	Sfx.play("ui")
	pivot_offset = size / 2.0
	Juice.pop(self, 1.04, 0.1)
	changed.emit(index)


func _refresh() -> void:
	var value := items[index] if not items.is_empty() else "-"
	text = "%s      ◀   %s   ▶" % [title, value]
