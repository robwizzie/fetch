class_name TutorialCoach
extends Control
## Teaches the controls during the first round of a session, the way a party game should:
## the round plays normally and the prompts sit over it, ticking off as people work each one
## out. Nothing blocks and nothing waits — every step also times out, so a table that already
## knows the game is never held up.

signal finished

## Each step: the control, how it is phrased, and how long before it gives up waiting.
## Built at runtime so the button names match whatever people are actually holding —
## an arcade cabinet says "Button 1", a console pad says "X".
func _steps() -> Array[Dictionary]:
	var move := DeviceInput.button_label(&"move", Game.slots)
	var throw := DeviceInput.button_label(&"throw", Game.slots)
	var dash := DeviceInput.button_label(&"dash", Game.slots)
	return [
		{"key": "move", "title": "MOVE", "hint": move, "timeout": 7.0},
		{"key": "pickup", "title": "FETCH A TOY", "hint": "Run over a toy to pick it up", "timeout": 14.0},
		{"key": "throw", "title": "THROW IT", "hint": throw, "timeout": 12.0},
		{"key": "catch", "title": "CATCH", "hint": "Press throw with empty paws as one flies at you", "timeout": 11.0},
		{"key": "dash", "title": "DASH", "hint": "%s — you cannot be hit mid-dash" % dash, "timeout": 10.0},
		{"key": "whack", "title": "WHACK", "hint": "Empty paws beside a rival: they drop it, or go dizzy", "timeout": 10.0},
		# No action to perform — the one rule everybody has to leave the booth knowing.
		{"key": "info", "title": "ONE HIT AND YOU'RE OUT", "hint": "Any toy flying fast bonks whoever it touches — including the one who threw it", "timeout": 6.0},
	]


var STEPS: Array[Dictionary] = []

var _index := 0
var _elapsed := 0.0
var _done := false
var _dogs: Array[Dog] = []
var _panel: PanelContainer
var _title: Label
var _hint: Label
var _progress: Label
var _tick: Label


func setup(dogs: Array[Dog]) -> void:
	_dogs = dogs


func _ready() -> void:
	STEPS = _steps()
	name = "TutorialCoach"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	offset_top = -340
	offset_bottom = -222
	_panel = PanelContainer.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.13, 0.08, 0.88)
	style.border_color = UiKit.YELLOW
	style.set_border_width_all(3)
	style.set_corner_radius_all(18)
	style.content_margin_left = 34
	style.content_margin_right = 34
	style.content_margin_top = 14
	style.content_margin_bottom = 14
	_panel.add_theme_stylebox_override("panel", style)
	_panel.custom_minimum_size = Vector2(720, 0)
	add_child(_panel)

	var rows := VBoxContainer.new()
	rows.alignment = BoxContainer.ALIGNMENT_CENTER
	rows.add_theme_constant_override("separation", 2)
	_panel.add_child(rows)

	var head := HBoxContainer.new()
	head.alignment = BoxContainer.ALIGNMENT_CENTER
	head.add_theme_constant_override("separation", 12)
	rows.add_child(head)
	_tick = UiKit.label("", 30, Color(0.45, 0.95, 0.45))
	head.add_child(_tick)
	_title = UiKit.title("", 38, UiKit.YELLOW)
	_title.autowrap_mode = TextServer.AUTOWRAP_OFF
	head.add_child(_title)
	_progress = UiKit.label("", 19, Color(1, 1, 1, 0.5))
	_progress.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_progress.autowrap_mode = TextServer.AUTOWRAP_OFF
	_progress.custom_minimum_size = Vector2(54, 0)
	head.add_child(_progress)

	_hint = UiKit.label("", 22, UiKit.CREAM)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.autowrap_mode = TextServer.AUTOWRAP_OFF
	rows.add_child(_hint)
	_show_step()


func _process(delta: float) -> void:
	if _done or _dogs.is_empty():
		return
	_elapsed += delta
	var step: Dictionary = STEPS[_index]
	if _satisfied(step.key) or _elapsed >= float(step.timeout):
		_complete(_satisfied(step.key))


## Watches the dogs rather than hooking every action, so nothing in gameplay needs to know the
## tutorial exists.
func _satisfied(key: String) -> bool:
	for dog in _dogs:
		if not is_instance_valid(dog) or not dog.alive:
			continue
		match key:
			"move":
				if dog.velocity.length() > 0.6:
					return true
			"pickup":
				if dog.held_toy != null:
					return true
			"throw":
				if _thrown:
					return true
			"catch":
				if _caught:
					return true
			"dash":
				if not dog.dash_ready():
					return true
			"whack":
				if _whacked:
					return true
	return false


var _thrown := false
var _caught := false
var _whacked := false


func watch_events() -> void:
	Events.toy_thrown.connect(func(_toy: Node, _by: Node) -> void: _thrown = true)
	Events.toy_caught.connect(func(_toy: Node, _by: Node) -> void: _caught = true)
	Events.dog_whacked.connect(func(_dog: Node, _by: Node) -> void: _whacked = true)


func _complete(earned: bool) -> void:
	if earned:
		_tick.text = "✓"
		Sfx.play("ui", 1.3, -4.0)
		_panel.pivot_offset = _panel.size * 0.5
		Juice.pop(_panel, 1.06, 0.2)
	_index += 1
	_elapsed = 0.0
	if _index >= STEPS.size():
		_finish()
		return
	await get_tree().create_timer(0.55 if earned else 0.15).timeout
	if not _done:
		_show_step()


func _show_step() -> void:
	var step: Dictionary = STEPS[_index]
	_tick.text = ""
	_title.text = step.title
	_hint.text = step.hint
	_progress.text = "%d / %d" % [_index + 1, STEPS.size()]
	modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.25)


func _finish() -> void:
	if _done:
		return
	_done = true
	_title.text = "GOOD DOG!"
	_hint.text = "That's everything — go win the round."
	_progress.text = ""
	_tick.text = "✓"
	Sfx.play("fanfare", 1.1, -6.0)
	var tween := create_tween()
	tween.tween_interval(1.9)
	tween.tween_property(self, "modulate:a", 0.0, 0.5)
	tween.tween_callback(func() -> void:
		finished.emit()
		queue_free())


## Ends the tutorial early — used when the round finishes before the steps do.
func dismiss() -> void:
	if _done:
		return
	_done = true
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.3)
	tween.tween_callback(func() -> void:
		finished.emit()
		queue_free())
