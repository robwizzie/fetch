extends Node
## Real scene navigation, startup loading, settings, practice and return-to-lobby regression.
## godot --headless --path . res://tests/ui_flow_test.tscn

var _failed := false
var _out_dir := ""


func _ready() -> void:
	# Headless tests have no audio device; avoid leaving queued playback at immediate exit.
	Sfx.enabled = DisplayServer.get_name() != "headless"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			_out_dir = argument.trim_prefix("--out=")
			DirAccess.make_dir_recursive_absolute(_out_dir)
	# Keep this harness alive while SceneTree replaces the actual current scene.
	get_tree().current_scene = null
	Game.pending_scene = Game.SCENE_MAIN_MENU
	Game.show_start_prompt = true
	get_tree().call_deferred("change_scene_to_file", Game.SCENE_LOADING)
	var loading := await _scene(Game.SCENE_LOADING)
	if loading == null:
		return
	var load_deadline := Time.get_ticks_msec() + 15000
	while Time.get_ticks_msec() < load_deadline:
		if loading.get("_packed") != null:
			break
		await get_tree().process_frame
	_check(loading.get("_packed") is PackedScene, "startup loads the real menu")
	var enter: Button = loading.get("_continue")
	_check(enter.visible and enter.has_focus(), "startup offers a focused ready prompt")
	var stage: CoverStage = loading.get("_stage")
	var cover: TextureRect = stage.canvas.get_node("FetchHomeArt")
	# The supplied art fills the screen, so what matters is that it is never stretched.
	_check(is_equal_approx(cover.size.y / cover.size.x, CoverStage.ART_ASPECT), "home art keeps its aspect ratio")
	await _capture("00_loading")
	enter.pressed.emit()
	var menu := await _scene(Game.SCENE_MAIN_MENU)
	if menu == null:
		return
	_check(get_viewport().gui_get_focus_owner() is Button, "menu has keyboard/controller focus")
	await _capture("01_main_menu")
	menu.call("_show_controls")
	_check(is_instance_valid(menu.get("_modal")), "How to Play opens")
	await _capture("02_controls")
	menu.call("_close_modal")
	await get_tree().process_frame
	menu.call("_show_settings")
	await _capture("03_settings")
	var settings: Control = menu.get("_modal")
	var sound := _find_button(settings, "SOUND EFFECTS:")
	var original_sound: bool = Sfx.enabled
	_check(sound != null, "settings contains the real sound toggle")
	if sound:
		sound.pressed.emit()
		_check(Sfx.enabled != original_sound, "sound setting changes audio state")
		sound.pressed.emit()
	var music := _find_button(settings, "MUSIC:")
	var original_music: bool = Music.enabled
	_check(music != null, "settings contains the real music toggle")
	if music:
		music.pressed.emit()
		_check(Music.enabled != original_music, "music setting changes audio state")
		music.pressed.emit()
	# Music and effects are separately mixable, so each has its own bus.
	_check(AudioServer.get_bus_index("Music") != -1, "a Music bus exists")
	_check(AudioServer.get_bus_index("SFX") != -1, "an SFX bus exists")

	# A pad has to be able to drive the menus, not just highlight things in them. Godot ships
	# ui_accept and ui_cancel with keyboard events only, so without the runtime binding the
	# menus look frozen on a controller: the highlight moves and nothing else happens.
	for spec in [["ui_accept", "confirm"], ["ui_cancel", "back"]]:
		var action: String = spec[0]
		var joy_buttons := 0
		for event in InputMap.action_get_events(action):
			if event is InputEventJoypadButton:
				joy_buttons += 1
		_check(joy_buttons > 0, "menu %s is reachable from a gamepad" % spec[1])
	# Navigation should work from both the stick and the d-pad.
	var has_axis := false
	var has_dpad := false
	for event in InputMap.action_get_events("ui_down"):
		has_axis = has_axis or event is InputEventJoypadMotion
		has_dpad = has_dpad or event is InputEventJoypadButton
	_check(has_axis, "menu navigation responds to the stick")
	_check(has_dpad, "menu navigation responds to the d-pad")

	# The soundtrack is rendered rather than loaded, and an empty track fails silently: it
	# still "plays", just with nothing in it. So the sequencer output is checked directly.
	var track: PackedFloat32Array = Music._render(Music._menu_spec())
	_check(track.size() > 0, "the menu track renders")
	var peak := 0.0
	var audible := 0
	var sampled := 0
	for i in range(0, track.size(), 11):
		var level := absf(track[i])
		peak = maxf(peak, level)
		sampled += 1
		if level > 0.02:
			audible += 1
	_check(peak > 0.5, "the rendered track reaches a usable level")
	_check(float(audible) / maxf(1.0, float(sampled)) > 0.5, "the track carries sustained tone, not just percussion hits")
	for cue in ["throw", "catch", "bonk", "bark", "treat", "squeak", "whistle", "ui_move"]:
		var stream: AudioStreamWAV = Sfx._streams.get(cue)
		_check(stream != null and stream.data.size() > 0, "the %s cue is synthesised" % cue)
	menu.call("_close_modal")
	await get_tree().process_frame
	_check(get_viewport().gui_get_focus_owner() is Button, "modal close restores menu focus")

	Game.start_practice()
	var setup := await _scene(Game.SCENE_MATCH_SETUP)
	if setup == null:
		return
	_check(Game.slots.size() == 4, "practice fills four slots")
	_check(Game.slots.filter(func(slot: PlayerSlot) -> bool: return slot.is_bot).size() == 3, "practice has three bots")
	_check(Game.slots[0].device == DeviceInput.KEYBOARD_WASD, "practice keeps the requested human device")
	_check(Game.selected_mode.fully_implemented and Game.selected_toy.fully_implemented, "practice picks playable content")
	setup.call("_on_start")
	var match_scene := await _scene(Game.SCENE_MATCH)
	if match_scene == null:
		return
	_check(match_scene.get("dogs").size() == 4, "practice creates four match dogs")
	match_scene.call("set_paused", true)
	_check(get_tree().paused, "practice can pause")
	Game.goto(Game.SCENE_DOG_SELECT)
	var select := await _scene(Game.SCENE_DOG_SELECT)
	if select == null:
		return
	_check(not get_tree().paused, "navigation resumes a paused tree")
	for slot in Game.slots:
		if slot.is_bot:
			_check(slot.ready, "returning bots remain ready")
	Game.goto(Game.SCENE_MAIN_MENU)
	menu = await _scene(Game.SCENE_MAIN_MENU)
	_check(menu != null and Game.slots.is_empty(), "return to main menu clears the session")
	if not _failed:
		print("[ui-flow] PASSED: cover, threaded loading, menu, settings, practice, pause and lobby return")
	get_tree().quit(1 if _failed else 0)


func _scene(path: String) -> Node:
	var deadline := Time.get_ticks_msec() + 15000
	while Time.get_ticks_msec() < deadline:
		var current := get_tree().current_scene
		if is_instance_valid(current) and current.scene_file_path == path:
			await get_tree().process_frame
			return current
		await get_tree().process_frame
	_check(false, "timed out loading " + path)
	get_tree().quit(1)
	return null


func _find_button(parent: Node, prefix: String) -> Button:
	for child in parent.get_children():
		if child is Button and child.text.begins_with(prefix):
			return child
		var found := _find_button(child, prefix)
		if found:
			return found
	return null


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failed = true
		push_error("[ui-flow] FAILED: " + message)


func _capture(file_name: String) -> void:
	if _out_dir.is_empty():
		return
	for _frame in 12:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var screenshot := get_viewport().get_texture().get_image()
	_check(screenshot.save_png(_out_dir.path_join(file_name + ".png")) == OK, "save visual review " + file_name)
