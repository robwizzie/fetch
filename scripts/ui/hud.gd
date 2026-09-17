class_name Hud
extends CanvasLayer
## In-match overlay: live score/status, round clock, simple control hints and pause.

signal resume_requested
signal quit_requested
signal countdown_finished
signal banner_finished

@onready var scores: HBoxContainer = %Scores
@onready var center: Label = %Center
@onready var hint: Label = %Hint

var _slots: Array[PlayerSlot] = []
var _chips: Dictionary = {}
var _clock: Label
var _announcement: Label
var _announcement_time := 0.0
var _pause_overlay: Control
var _resume: Button
var _countdown_steps: Array = []
var _countdown_index := 0
var _sequence_time := 0.0
var _banner_time := 0.0
var _board: RoundBoard


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
	center.add_theme_font_size_override("font_size", 88)
	_build_clock()
	_build_pause()


func setup(slots: Array[PlayerSlot], mode_hint: String) -> void:
	_slots = slots
	hint.text = "%s · First to %d
%s" % [mode_hint, Game.points_to_win, _control_hint(slots)]
	hint.offset_top = -74
	hint.offset_left = -850
	hint.offset_right = 850
	hint.add_theme_font_override("font", UiKit.FONT_UI)
	hint.add_theme_color_override("font_color", UiKit.CREAM)
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
	_announcement_time = 0.0
	_announcement.hide()
	_countdown_steps = ["ROUND %d" % round_number, "3", "2", "1", "FETCH!"] if round_number == 1 else ["ROUND %d" % round_number, "READY?", "FETCH!"]
	_countdown_index = 0
	_banner_time = 0.0
	center.add_theme_font_size_override("font_size", 88)
	_show_countdown_step()


func _show_countdown_step() -> void:
	center.text = _countdown_steps[_countdown_index]
	center.modulate = Color.WHITE
	center.pivot_offset = center.size / 2.0
	Juice.pop(center, 1.5, 0.3)
	Sfx.play("tick", 1.0 + _countdown_index * 0.1)
	_sequence_time = 0.65 if _countdown_index == 0 else 0.5


## Owned by the HUD: pausing freezes the sequence and leaving the match cancels it cleanly.
func _process(delta: float) -> void:
	if _announcement_time > 0.0:
		_announcement_time -= delta
		_announcement.visible = _announcement_time > 0.0
	if not _countdown_steps.is_empty():
		_sequence_time -= delta
		if _sequence_time <= 0.0:
			_countdown_index += 1
			if _countdown_index < _countdown_steps.size():
				_show_countdown_step()
			else:
				_countdown_steps.clear()
				center.text = ""
				countdown_finished.emit()
	if _banner_time > 0.0:
		_banner_time -= delta
		if _banner_time <= 0.0:
			center.text = ""
			banner_finished.emit()


## The between-rounds standings. Replaces the plain banner whenever there is a board worth
## showing, and reports back through banner_finished so the match flow is unchanged.
func round_board(headline: String, sides: Array, target: int, prompt: String) -> void:
	if _board == null:
		_board = RoundBoard.new()
		add_child(_board)
		_board.dismissed.connect(func() -> void: banner_finished.emit())
	_board.show_board(headline, sides, target, prompt)


func banner(text: String, color: Color, seconds: float) -> void:
	_countdown_steps.clear()
	_banner_time = seconds
	center.text = text
	center.add_theme_font_size_override("font_size", 70)
	center.modulate = color
	center.pivot_offset = center.size / 2.0
	Juice.pop(center, 1.4, 0.4)


## One power-up socket: an empty outline until something fills it.
func _belt_slot() -> Panel:
	var socket := Panel.new()
	socket.custom_minimum_size = Vector2(28, 28)
	var glyph := Label.new()
	glyph.name = "Glyph"
	glyph.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	glyph.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	glyph.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	glyph.add_theme_font_override("font", UiKit.FONT_DISPLAY)
	glyph.add_theme_font_size_override("font_size", 17)
	glyph.add_theme_color_override("font_color", UiKit.INK)
	socket.add_child(glyph)
	_paint_slot(socket, &"")
	return socket


func _paint_slot(socket: Panel, kind: StringName) -> void:
	var style := StyleBoxFlat.new()
	style.set_corner_radius_all(8)
	if kind == &"":
		style.bg_color = Color(1, 1, 1, 0.07)
		style.border_color = Color(1, 1, 1, 0.22)
	else:
		style.bg_color = PowerupKinds.color(kind)
		style.border_color = PowerupKinds.color(kind).lightened(0.4)
	style.set_border_width_all(2)
	socket.add_theme_stylebox_override("panel", style)
	var glyph := socket.get_node("Glyph") as Label
	glyph.text = "" if kind == &"" else PowerupKinds.glyph(kind)


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
	var belt := HBoxContainer.new()
	belt.name = "Belt"
	belt.add_theme_constant_override("separation", 5)
	for i in PowerupKinds.MAX_SLOTS:
		belt.add_child(_belt_slot())
	vbox.add_child(belt)
	var dots := HBoxContainer.new()
	dots.name = "Dots"
	dots.add_theme_constant_override("separation", 6)
	for i in Game.points_to_win:
		var dot := ColorRect.new()
		dot.custom_minimum_size = Vector2(24, 10)
		dots.add_child(dot)
	vbox.add_child(dots)
	var status := UiKit.label("FIND A TOY · DASH READY", 16, UiKit.CREAM)
	status.name = "Status"
	status.autowrap_mode = TextServer.AUTOWRAP_OFF
	status.add_theme_font_override("font", UiKit.FONT_UI)
	vbox.add_child(status)
	return chip


func _build_clock() -> void:
	_clock = UiKit.label("ROUND 1  ·  0:45", 26, UiKit.CREAM)
	_clock.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_clock.offset_left = -190
	_clock.offset_right = 190
	_clock.offset_top = 126
	_clock.offset_bottom = 164
	_clock.add_theme_font_override("font", UiKit.FONT_UI)
	_clock.add_theme_color_override("font_outline_color", UiKit.INK)
	_clock.add_theme_constant_override("outline_size", 8)
	add_child(_clock)
	_announcement = UiKit.label("", 24, UiKit.YELLOW)
	_announcement.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_announcement.offset_left = -430
	_announcement.offset_right = 430
	_announcement.offset_top = 168
	_announcement.offset_bottom = 204
	_announcement.add_theme_color_override("font_outline_color", UiKit.INK)
	_announcement.add_theme_constant_override("outline_size", 7)
	add_child(_announcement)
	_announcement.hide()


## The practice round has no clock and no score, so the timer says so instead of counting.
func practice_clock() -> void:
	_clock.text = "PRACTICE ROUND"
	_clock.add_theme_color_override("font_color", UiKit.YELLOW)


func announce(text: String) -> void:
	_announcement.text = text
	_announcement_time = 3.0
	_announcement.show()


func update_match(dogs: Array[Dog], seconds: float, round_number: int) -> void:
	var remaining := ceili(seconds)
	_clock.text = "ROUND %d  ·  %d:%02d" % [round_number, remaining / 60, remaining % 60]
	_clock.add_theme_color_override("font_color", UiKit.YELLOW if remaining <= 10 else UiKit.CREAM)
	for dog in dogs:
		if not _chips.has(dog.slot):
			continue
		var chip: PanelContainer = _chips[dog.slot]
		var status: Label = chip.get_node("VBox/Status")
		chip.modulate = Color.WHITE if dog.alive else Color(0.7, 0.7, 0.7, 0.65)
		if not dog.alive:
			status.text = "OUT · BACK NEXT ROUND"
		else:
			var toy_status := dog.held_toy.data.display_name.to_upper() if dog.held_toy else "FIND A TOY"
			if dog.dizzy_time > 0.0:
				toy_status = "SEEING STARS"
			status.text = "%s · %s" % [toy_status, "DASH READY" if dog.dash_ready() else "DASH RECHARGING"]
		var belt := chip.get_node("VBox/Belt")
		for i in belt.get_child_count():
			var socket := belt.get_child(i) as Panel
			var held: StringName = dog.slot.powerups[i] if i < dog.slot.powerups.size() else &""
			if socket.get_meta("kind", &"") != held:
				socket.set_meta("kind", held)
				_paint_slot(socket, held)
				if held != &"":
					socket.pivot_offset = socket.size * 0.5
					Juice.pop(socket, 1.5, 0.3)


func _control_hint(slots: Array[PlayerSlot]) -> String:
	var layouts: Array[String] = []
	for slot in slots:
		if slot.is_bot:
			continue
		var line := DeviceInput.controls_line(slot.device)
		if not layouts.has(line):
			layouts.append(line)
	layouts.append("Esc / Start pause")
	return "   |   ".join(layouts)


func _build_pause() -> void:
	_pause_overlay = Control.new()
	_pause_overlay.name = "PauseMenu"
	_pause_overlay.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	_pause_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_pause_overlay)
	var shade := ColorRect.new()
	shade.color = Color(0.04, 0.08, 0.06, 0.8)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pause_overlay.add_child(shade)
	var card := PanelContainer.new()
	card.set_anchors_preset(Control.PRESET_CENTER)
	card.offset_left = -310
	card.offset_right = 310
	card.offset_top = -220
	card.offset_bottom = 220
	card.add_theme_stylebox_override("panel", UiKit.panel_style(UiKit.YELLOW, Color(0.13, 0.2, 0.13, 0.98)))
	_pause_overlay.add_child(card)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 16)
	card.add_child(box)
	box.add_child(UiKit.title("PAWS FOR A BREAK", 48, UiKit.YELLOW))
	box.add_child(UiKit.label("Your round will be right here.", 23, UiKit.CREAM))
	_resume = UiKit.wood_button("KEEP PLAYING", 540)
	_resume.pressed.connect(func() -> void: resume_requested.emit())
	box.add_child(_resume)
	var leave := UiKit.wood_button("MAIN MENU", 540)
	leave.pressed.connect(func() -> void: quit_requested.emit())
	box.add_child(leave)
	box.add_child(UiKit.label("Esc / Start to resume", 20, Color(1, 1, 1, 0.7)))
	_pause_overlay.hide()


func show_pause(paused: bool) -> void:
	_pause_overlay.visible = paused
	if paused:
		_resume.grab_focus()
	else:
		_resume.release_focus()
