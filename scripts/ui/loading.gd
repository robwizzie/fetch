extends Control
## ResourceLoader supplies the real progress. A ready prompt lets the cover greet players at boot.

var _path: String
var _packed: PackedScene
var _stage: CoverStage
var _status: Label
var _progress: ProgressBar
var _continue: Button
var _error := false
var _switching := false


func _ready() -> void:
	_stage = CoverStage.new()
	add_child(_stage)
	var canvas := _stage.canvas
	var x := CoverStage.COLUMN_X
	var w := CoverStage.COLUMN_WIDTH
	_put(canvas, CoverStage.copy("WELCOME TO FETCH", 23, Color(0.84, 0.9, 0.66)), Vector2(x + 2, 330), Vector2(w, 32))
	_put(canvas, CoverStage.heading("SMALL PAWS.\nBIG PLAY.", 62), Vector2(x, 372), Vector2(760, 170))
	_put(canvas, CoverStage.copy("A backyard full of friends.\nA whole new way to play fetch.", 26), Vector2(x + 2, 566), Vector2(660, 84))
	_status = CoverStage.copy("Getting the pack together…", 24, Color(0.86, 0.92, 0.7))
	_put(canvas, _status, Vector2(x + 2, 684), Vector2(w + 120, 34))
	_progress = ProgressBar.new()
	_progress.show_percentage = false
	_progress.max_value = 1.0
	_progress.add_theme_stylebox_override("background", CoverStage.paper_style(Color(0.09, 0.15, 0.09, 0.8), Color(0.55, 0.62, 0.4), 10))
	var fill := CoverStage.paper_style(CoverStage.ORANGE, Color("cf7026"), 10)
	fill.shadow_size = 0
	_progress.add_theme_stylebox_override("fill", fill)
	_put(canvas, _progress, Vector2(x + 2, 730), Vector2(w, 20))
	_continue = UiKit.wood_button("LET'S PLAY", w)
	_continue.custom_minimum_size.y = 78
	_continue.add_theme_font_override("font", UiKit.FONT_DISPLAY)
	_continue.add_theme_font_size_override("font_size", 32)
	_continue.pressed.connect(_enter)
	_continue.visible = false
	_put(canvas, _continue, Vector2(x, 782), Vector2(w, 78))
	_put(canvas, CoverStage.copy("1–4 players   •   local multiplayer   •   gamepads + keyboard", 21, Color(0.92, 0.95, 0.86)), Vector2(x + 2, 934), Vector2(700, 32))
	_path = Game.pending_scene
	_begin_load()


func _begin_load() -> void:
	var result := ResourceLoader.load_threaded_request(_path, "PackedScene")
	if result != OK:
		_fail("Couldn't open this scene. Try returning to the menu.")


func _process(_delta: float) -> void:
	if _error or _packed != null or _switching:
		return
	var progress: Array = []
	var state := ResourceLoader.load_threaded_get_status(_path, progress)
	if not progress.is_empty():
		_progress.value = float(progress[0])
	if state == ResourceLoader.THREAD_LOAD_LOADED:
		_packed = ResourceLoader.load_threaded_get(_path) as PackedScene
		if _packed == null:
			_fail("This scene couldn't be loaded. Return to the menu to try again.")
			return
		_progress.value = 1.0
		_status.text = "The pack is ready. Are you?"
		if Game.show_start_prompt:
			_continue.visible = true
			_continue.grab_focus()
		else:
			_enter.call_deferred()
	elif state == ResourceLoader.THREAD_LOAD_FAILED or state == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
		_fail("Couldn't load this scene. Return to the menu to try again.")


func _fail(message: String) -> void:
	_error = true
	_status.text = message
	_continue.text = "BACK TO MENU"
	_continue.visible = true
	_continue.grab_focus()
	push_error("FETCH scene load failed: " + _path)


func _enter() -> void:
	if _switching:
		return
	if _error:
		Game.navigation_busy = false
		Game.goto(Game.SCENE_MAIN_MENU)
		return
	if _packed == null:
		return
	_switching = true
	Game.show_start_prompt = false
	Game.navigation_busy = false
	get_tree().call_deferred("change_scene_to_packed", _packed)


func _put(parent: Control, child: Control, at: Vector2, box: Vector2) -> void:
	child.position = at
	child.size = box
	parent.add_child(child)
