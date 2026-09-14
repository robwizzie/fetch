class_name Hud
extends CanvasLayer
## In-match overlay: score chips per player, countdown, round banner, mode hint.

@onready var scores: HBoxContainer = %Scores
@onready var center: Label = %Center
@onready var hint: Label = %Hint

var _slots: Array[PlayerSlot] = []
var _chips: Dictionary = {}


func setup(slots: Array[PlayerSlot], mode_hint: String) -> void:
	_slots = slots
	hint.text = mode_hint
	for c in scores.get_children():
		c.queue_free()
	_chips.clear()
	for slot in slots:
		var chip := _make_chip(slot)
		scores.add_child(chip)
		_chips[slot] = chip
	refresh_scores()
	center.text = ""


func refresh_scores() -> void:
	for slot in _slots:
		var chip: PanelContainer = _chips[slot]
		var dots: HBoxContainer = chip.get_node("VBox/Dots")
		for i in dots.get_child_count():
			var dot: ColorRect = dots.get_child(i)
			dot.color = slot.color if i < slot.score else Color(1, 1, 1, 0.15)
		if slot.score > 0:
			Juice.pop(chip, 1.15)


func countdown(round_number: int) -> void:
	var steps := ["Round %d" % round_number, "3", "2", "1", "FETCH!"]
	for i in steps.size():
		center.text = steps[i]
		center.modulate = Color.WHITE
		center.pivot_offset = center.size / 2.0
		Juice.pop(center, 1.5, 0.3)
		Sfx.play("tick", 1.0 + i * 0.1)
		await get_tree().create_timer(0.85 if i == 0 else 0.65).timeout
		if not is_inside_tree():
			return
	center.text = ""


func banner(text: String, color: Color, seconds: float) -> void:
	center.text = text
	center.modulate = color
	center.pivot_offset = center.size / 2.0
	Juice.pop(center, 1.4, 0.4)
	await get_tree().create_timer(seconds).timeout
	if is_inside_tree():
		center.text = ""


func _make_chip(slot: PlayerSlot) -> PanelContainer:
	var chip := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.08, 0.14, 0.85)
	style.border_color = slot.color
	style.set_border_width_all(3)
	style.set_corner_radius_all(12)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	chip.add_theme_stylebox_override("panel", style)
	var vbox := VBoxContainer.new()
	vbox.name = "VBox"
	chip.add_child(vbox)
	var name_label := Label.new()
	name_label.text = "%s  %s" % [slot.label, slot.dog.display_name]
	name_label.add_theme_color_override("font_color", slot.color)
	name_label.add_theme_font_size_override("font_size", 24)
	vbox.add_child(name_label)
	var dots := HBoxContainer.new()
	dots.name = "Dots"
	dots.add_theme_constant_override("separation", 6)
	for i in Game.points_to_win:
		var dot := ColorRect.new()
		dot.custom_minimum_size = Vector2(22, 10)
		dots.add_child(dot)
	vbox.add_child(dots)
	return chip
