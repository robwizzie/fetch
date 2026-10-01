class_name Hud
extends CanvasLayer
## In-match overlay: live score/status, round clock, simple control hints and pause.

signal resume_requested
signal quit_requested
signal countdown_finished
signal banner_finished

@onready var scores: HBoxContainer = %Scores
@onready var center: Label = %Center
var _replay_frame: Control
var _callout: Label
var _pause_controls: VBoxContainer
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
var _effects_layer: Control
var _awards: Dictionary = {}


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
	Events.powerup_collected.connect(_show_powerup_award)


func setup(slots: Array[PlayerSlot], mode_hint: String) -> void:
	_slots = slots
	# Controls live on each player's own card now (and in the pause menu); the floor gets only
	# the goal.
	hint.text = "%s · First to %d" % [mode_hint, Game.points_to_win]
	hint.offset_top = -50
	for child in _pause_controls.get_children():
		child.queue_free()
	_pause_controls.add_child(_controls_card(slots))
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
			var dot := dots.get_child(i) as ColorRect
			if dot != null:
				dot.color = UiKit.YELLOW if i < Game.score_for(slot) else Color(1, 1, 1, 0.18)
		var count := dots.get_node_or_null("Count") as Label
		if count != null:
			count.text = "%d / %d" % [Game.score_for(slot), Game.points_to_win]
		(dots.get_node("Tally") as Label).text = "%d bonk%s · out %d" % [slot.knockouts, "" if slot.knockouts == 1 else "s", slot.bonked]
		if Game.score_for(slot) > 0:
			Juice.pop(chip, 1.15)


## A self-bonk took a point off [param slot]: the bone it cost pops off that player's card and
## snaps, and the card flashes red and shudders. [param was] is the score before the loss.
func lose_bone(slot: PlayerSlot, was: int) -> void:
	if not _chips.has(slot):
		return
	var chip: PanelContainer = _chips[slot]
	var dots: HBoxContainer = chip.get_node("VBox/Dots")
	# Off the pip that just went dark, or the running count when the goal is a number.
	var source: Control = dots.get_node_or_null("Count")
	if source == null and was - 1 < dots.get_child_count():
		source = dots.get_child(maxi(was - 1, 0)) as Control
	if source == null:
		source = chip
	var at := source.get_global_rect().get_center()
	BoneBreak.play(self_layer(), at)
	# A red wash over the card that fades: the card's own tint is reset every frame (it dims
	# while its dog is out), so it cannot carry the flash itself.
	var wash := Panel.new()
	wash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var red := StyleBoxFlat.new()
	red.bg_color = Color(1.0, 0.22, 0.18, 0.7)
	red.set_corner_radius_all(12)
	wash.add_theme_stylebox_override("panel", red)
	chip.add_child(wash)
	var flash := wash.create_tween().set_ignore_time_scale(true)
	flash.tween_property(wash, "modulate:a", 0.0, 0.8).set_delay(0.15)
	flash.tween_callback(wash.queue_free)
	var home := chip.position
	var shake := chip.create_tween().set_ignore_time_scale(true)
	for i in 6:
		shake.tween_property(chip, "position:x", home.x + (7.0 if i % 2 == 0 else -7.0) * (1.0 - i / 6.0), 0.04)
	shake.tween_property(chip, "position:x", home.x, 0.04)


## A full-screen control on this layer for loose effects to live on.
func self_layer() -> Control:
	if not is_instance_valid(_effects_layer):
		_effects_layer = Control.new()
		_effects_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
		_effects_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_effects_layer)
	return _effects_layer


func countdown(round_number: int) -> void:
	_clear_awards()
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
	_stack_under_cards()
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
	socket.custom_minimum_size = Vector2(34, 34)
	# A drawn icon rather than a letter: a belt has to be readable in the corner of an eye.
	var glyph := TextureRect.new()
	glyph.name = "Glyph"
	glyph.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	glyph.offset_left = 4
	glyph.offset_top = 4
	glyph.offset_right = -4
	glyph.offset_bottom = -4
	glyph.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	glyph.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
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
		style.bg_color = PowerupKinds.color(kind).darkened(0.64)
		style.border_color = PowerupKinds.color(kind)
	style.set_border_width_all(2)
	socket.add_theme_stylebox_override("panel", style)
	var glyph := socket.get_node("Glyph") as TextureRect
	glyph.texture = null if kind == &"" else PowerupIcon.texture(kind, 64, PowerupKinds.color(kind).lightened(0.28))
	glyph.visible = kind != &""
	socket.tooltip_text = "Empty power-up slot" if kind == &"" else PowerupKinds.display_name(kind) + " · " + PowerupKinds.blurb(kind)


## A small award below the recipient's score connects the reveal to their belt.
## Each player owns their own toast so simultaneous pickups remain readable.
func _show_powerup_award(node: Node, kind: StringName) -> void:
	var dog := node as Dog
	if dog == null or not _chips.has(dog.slot):
		return
	var chip: PanelContainer = _chips[dog.slot]
	if _awards.has(dog.slot):
		var old: Control = _awards[dog.slot]
		old.hide()
		old.queue_free()
	var award := PanelContainer.new()
	award.name = "PowerupAward"
	award.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color("302c3c")
	style.border_color = PowerupKinds.color(kind)
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	style.shadow_color = Color(0.05, 0.03, 0.09, 0.25)
	style.shadow_size = 6
	award.add_theme_stylebox_override("panel", style)
	# Kept outside the chip's container layout, so an award never shifts the scoreboard.
	add_child(award)
	award.position = chip.global_position + Vector2(0, chip.size.y + 8)
	award.custom_minimum_size.x = chip.size.x
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	award.add_child(row)
	var icon := TextureRect.new()
	icon.texture = PowerupIcon.badge(kind, 96)
	icon.custom_minimum_size = Vector2(44, 44)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(icon)
	var copy := VBoxContainer.new()
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy.add_theme_constant_override("separation", 1)
	row.add_child(copy)
	var title := UiKit.title(PowerupKinds.display_name(kind), 23, PowerupKinds.color(kind))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	copy.add_child(title)
	var detail := UiKit.label(PowerupKinds.blurb(kind), 16, UiKit.CREAM)
	detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	copy.add_child(detail)
	_awards[dog.slot] = award
	var reveal := award.create_tween()
	reveal.tween_property(award, "modulate:a", 1.0, 0.16).from(0.0)
	reveal.parallel().tween_property(award, "position:y", award.position.y, 0.24).from(award.position.y - 12).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	reveal.tween_interval(2.4)
	reveal.tween_property(award, "modulate:a", 0.0, 0.25)
	reveal.tween_callback(func() -> void:
		if _awards.get(dog.slot) == award:
			_awards.erase(dog.slot)
		award.queue_free())


func _clear_awards() -> void:
	for award: Control in _awards.values():
		if is_instance_valid(award):
			award.hide()
			award.queue_free()
	_awards.clear()


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
	# A long goal (first to 15 bonks) would be a row of pips wider than the card; it is a number.
	var pips := Game.points_to_win <= 7
	for i in (Game.points_to_win if pips else 0):
		var dot := ColorRect.new()
		dot.custom_minimum_size = Vector2(24, 10)
		dots.add_child(dot)
	if not pips:
		var count := UiKit.label("", 18, UiKit.YELLOW)
		count.name = "Count"
		count.autowrap_mode = TextServer.AUTOWRAP_OFF
		count.add_theme_font_override("font", UiKit.FONT_DISPLAY)
		dots.add_child(count)
	# This match's story so far: rivals bonked and times out.
	var tally := UiKit.label("", 15, Color(1, 1, 1, 0.8))
	tally.name = "Tally"
	tally.autowrap_mode = TextServer.AUTOWRAP_OFF
	tally.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tally.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	dots.add_child(tally)
	vbox.add_child(dots)
	vbox.add_child(_wind_up_bar())
	var status := UiKit.label("FIND A TOY · DASH READY", 16, UiKit.CREAM)
	status.name = "Status"
	status.autowrap_mode = TextServer.AUTOWRAP_OFF
	status.add_theme_font_override("font", UiKit.FONT_UI)
	vbox.add_child(status)
	return chip


## A thin power bar under the score dots. It is only there while a throw is being wound up,
## so the chip stays quiet the rest of the time.
func _wind_up_bar() -> Control:
	var bar := Control.new()
	bar.name = "WindUp"
	bar.custom_minimum_size = Vector2(0, 8)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.modulate.a = 0.0
	var track := ColorRect.new()
	track.name = "Track"
	track.color = Color(0, 0, 0, 0.38)
	track.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bar.add_child(track)
	var fill := ColorRect.new()
	fill.name = "Fill"
	fill.color = UiKit.YELLOW
	fill.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	fill.offset_right = 0.0
	bar.add_child(fill)
	return bar


func _build_clock() -> void:
	_clock = UiKit.label("ROUND 1  ·  0:45", 26, UiKit.CREAM)
	_clock.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_clock.offset_left = -340
	_clock.offset_right = 340
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


## The clock and the announcement hang just under the player cards, however tall the cards
## are - fixed offsets put the clock over the bottom of the cards once they grew a key row.
func _stack_under_cards() -> void:
	var top := scores.position.y + scores.size.y + 4.0
	_clock.offset_top = top
	_clock.offset_bottom = top + 36.0
	_announcement.offset_top = top + 38.0
	_announcement.offset_bottom = top + 74.0


## Letterbox bars and a REPLAY tag while the final bonk is shown again.
func show_replay(on: bool) -> void:
	if on and not is_instance_valid(_replay_frame):
		_replay_frame = Control.new()
		_replay_frame.set_anchors_preset(Control.PRESET_FULL_RECT)
		_replay_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_replay_frame)
		for top in [true, false]:
			var bar := ColorRect.new()
			bar.color = Color(0, 0, 0, 0.88)
			bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
			bar.set_anchors_preset(Control.PRESET_TOP_WIDE if top else Control.PRESET_BOTTOM_WIDE)
			bar.custom_minimum_size = Vector2(0, 110)
			if not top:
				bar.grow_vertical = Control.GROW_DIRECTION_BEGIN
			_replay_frame.add_child(bar)
		var tag := UiKit.title("REPLAY", 54, Color(1.0, 0.36, 0.3))
		tag.position = Vector2(48, 24)
		_replay_frame.add_child(tag)
		var hint := UiKit.label("%s to skip" % DeviceInput.button_label(&"confirm", Game.slots), 20, Color(1, 1, 1, 0.7))
		hint.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
		hint.grow_horizontal = Control.GROW_DIRECTION_BEGIN
		hint.grow_vertical = Control.GROW_DIRECTION_BEGIN
		hint.offset_right = -40
		hint.offset_bottom = -40
		hint.autowrap_mode = TextServer.AUTOWRAP_OFF
		_replay_frame.add_child(hint)
	elif not on and is_instance_valid(_replay_frame):
		_replay_frame.queue_free()
		_replay_frame = null
	scores.visible = not on


## A great moment, called out big across the top of the arena with a sting.
func callout(text: String, color: Color) -> void:
	if is_instance_valid(_callout):
		_callout.queue_free()
	_callout = UiKit.title(text, 84, color.lightened(0.15))
	_callout.add_theme_constant_override("outline_size", 16)
	_callout.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_callout.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_callout.offset_top = 250
	_callout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_callout)
	_callout.pivot_offset = Vector2(_callout.get_minimum_size().x * 0.5, 50)
	_callout.rotation_degrees = randf_range(-6.0, 6.0)
	var label := _callout
	label.scale = Vector2.ONE * 0.3
	var show := label.create_tween()
	show.tween_property(label, "scale", Vector2.ONE * 1.1, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	show.tween_property(label, "scale", Vector2.ONE, 0.1)
	show.tween_interval(0.9)
	show.tween_property(label, "modulate:a", 0.0, 0.3)
	show.tween_callback(label.queue_free)
	Sfx.play("fanfare", 1.5, -5.0)
	Sfx.play("treat", 1.3, -4.0)


func announce(text: String) -> void:
	_announcement.text = text
	_announcement_time = 3.0
	_announcement.show()


func update_match(dogs: Array[Dog], seconds: float, round_number: int) -> void:
	var remaining := ceili(seconds)
	_clock.text = "ROUND %d  ·  %d:%02d" % [round_number, remaining / 60, remaining % 60]
	_clock.add_theme_color_override("font_color", UiKit.YELLOW if remaining <= 10 else UiKit.CREAM)
	if round_number > 0 and seconds <= 10.0:
		# Sudden death, then overtime: the clock says so, in red, pulsing.
		var pulse := 0.75 + 0.25 * sin(Time.get_ticks_msec() * 0.012)
		_clock.text = "ROUND %d  ·  %s" % [round_number, "OVERTIME!" if seconds <= 0.0 else "SUDDEN DEATH  0:%02d" % remaining]
		_clock.add_theme_color_override("font_color", Color(1.0, 0.42, 0.3, pulse))
	# The controls line teaches the warm-up and the first round, then gets off the floor: two
	# lines of small print over the near wall is the last thing a round two needs.
	hint.modulate.a = move_toward(hint.modulate.a, 1.0 if round_number <= 1 else 0.0, 0.02)
	for dog in dogs:
		if not _chips.has(dog.slot):
			continue
		var chip: PanelContainer = _chips[dog.slot]
		var status: Label = chip.get_node("VBox/Status")
		chip.modulate = Color.WHITE if dog.alive else Color(0.7, 0.7, 0.7, 0.65)
		var charge := dog.charge_ratio() if dog.alive else 0.0
		var wind_up: Control = chip.get_node("VBox/WindUp")
		wind_up.modulate.a = lerpf(wind_up.modulate.a, 1.0 if charge > 0.0 else 0.0, 0.3)
		var fill: ColorRect = wind_up.get_node("Fill")
		fill.offset_right = wind_up.size.x * charge
		fill.color = Color.WHITE if charge >= 1.0 else UiKit.YELLOW
		if not dog.alive and get_tree().get_nodes_in_group(&"ghosts").any(func(g: Node) -> bool: return (g as GhostDog).slot == dog.slot):
			status.text = "GHOST · %s BOO! · %s NUDGE A TOY" % [DeviceInput.short_glyph(&"bark", dog.slot.device).to_upper(), DeviceInput.short_glyph(&"throw", dog.slot.device).to_upper()]
		elif not dog.alive and not get_tree().get_nodes_in_group(ReviveSpot.GROUP).filter(func(s: Node) -> bool: return (s as ReviveSpot).dog == dog).is_empty():
			status.text = "DOWN · A PACK-MATE CAN REVIVE YOU"
		elif not dog.alive:
			status.text = "DOGHOUSE · BACK NEXT ROUND"
		else:
			var toy_status := dog.held_toy.data.display_name.to_upper() if dog.held_toy else "FIND A TOY"
			if charge >= 1.0:
				toy_status = "MAX POWER!"
			elif charge > 0.0:
				toy_status = "WINDING UP"
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
	card.grow_horizontal = Control.GROW_DIRECTION_BOTH
	card.grow_vertical = Control.GROW_DIRECTION_BOTH
	card.custom_minimum_size = Vector2(620, 0)
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
	_pause_controls = VBoxContainer.new()
	box.add_child(_pause_controls)
	box.add_child(UiKit.label("%s to resume" % DeviceInput.button_label(&"pause", Game.slots), 20, Color(1, 1, 1, 0.7)))
	_pause_overlay.hide()


## Everyone's controls, one row per device in use, drawn as keys. Players sharing a layout share
## a row. The pause menu is where a lost player looks, so the answer has to be there.
func _controls_card(slots: Array[PlayerSlot]) -> VBoxContainer:
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	var seen: Array[int] = []
	for slot in slots:
		if slot.is_bot or slot.device == DeviceInput.VIRTUAL or seen.has(slot.device):
			continue
		seen.append(slot.device)
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", 7)
		for other in slots:
			if other.device == slot.device and not other.is_bot:
				row.add_child(UiKit.chip(other.label, other.color, 18))
		for pair in [[&"move", "move"], [&"throw", "throw / catch"], [&"dash", "dash"], [&"bark", "bark"]]:
			var spacer := Control.new()
			spacer.custom_minimum_size = Vector2(8, 0)
			row.add_child(spacer)
			row.add_child(UiKit.keycaps(pair[0], slot.device, 17))
			var word := UiKit.label(pair[1], 18, UiKit.CREAM)
			word.autowrap_mode = TextServer.AUTOWRAP_OFF
			row.add_child(word)
		column.add_child(row)
	if not seen.is_empty():
		column.add_child(UiKit.label("Hold throw for a harder throw  ·  one hit from a flying toy and you're out", 17, UiKit.YELLOW))
	return column


func show_pause(paused: bool) -> void:
	_pause_overlay.visible = paused
	if paused:
		# Over everything else on the HUD - the round board and practice cards are added after
		# the pause menu, so without this they drew on top of it.
		_pause_overlay.move_to_front()
		_resume.grab_focus()
	else:
		_resume.release_focus()
