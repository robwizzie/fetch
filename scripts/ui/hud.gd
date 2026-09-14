class_name Hud
extends CanvasLayer
## In-match overlay: score chips per player, countdown, round banner, mode hint.

@onready var scores: HBoxContainer = %Scores
@onready var center: Label = %Center
@onready var hint: Label = %Hint

var _slots: Array[PlayerSlot] = []
var _chips: Dictionary = {}


func _ready() -> void:
	# Soft vignette so the arena edges fall off like Boomerang Fu
	var vignette := ColorRect.new()
	vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = "shader_type canvas_item; void fragment() { vec2 uv = UV - 0.5; uv.x *= 1.25; float d = length(uv) * 1.6; COLOR = vec4(0.03, 0.04, 0.09, smoothstep(0.62, 1.25, d) * 0.6); }"
	var mat := ShaderMaterial.new()
	mat.shader = sh
	vignette.material = mat
	add_child(vignette)
	move_child(vignette, 0)
	center.add_theme_font_override("font", UiKit.FONT_DISPLAY)


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
			dot.color = UiKit.YELLOW if i < slot.score else Color(1, 1, 1, 0.18)
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
	style.bg_color = Color(slot.dog.card_color_dark, 0.92)
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
	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 8)
	name_row.add_child(UiKit.chip(slot.label, slot.color, 18))
	var name_label := Label.new()
	name_label.text = slot.dog.display_name.to_upper()
	name_label.add_theme_font_override("font", UiKit.FONT_DISPLAY)
	name_label.add_theme_color_override("font_color", UiKit.CREAM)
	name_label.add_theme_color_override("font_outline_color", UiKit.INK)
	name_label.add_theme_constant_override("outline_size", 6)
	name_label.add_theme_font_size_override("font_size", 26)
	name_row.add_child(name_label)
	vbox.add_child(name_row)
	var dots := HBoxContainer.new()
	dots.name = "Dots"
	dots.add_theme_constant_override("separation", 6)
	for i in Game.points_to_win:
		var dot := ColorRect.new()
		dot.custom_minimum_size = Vector2(24, 10)
		dots.add_child(dot)
	vbox.add_child(dots)
	return chip
