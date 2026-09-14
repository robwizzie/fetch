extends Node
## Captures a PNG of every screen (and a live match) for visual review. Needs a display or Xvfb:
##   xvfb-run -s "-screen 0 1920x1080x24" godot --path . --rendering-driver opengl3 res://tests/screenshots.tscn -- --out=/tmp/shots
## Output directory defaults to user://shots.

var out_dir := "user://shots"


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(out_dir)
	Game.debug_fill_players(3)
	Game.slots[1].dog = Game.dogs[4]
	Game.slots[2].dog = Game.dogs[2]
	Game.last_match_winner = Game.slots[1]
	Game.slots[1].score = 5
	Game.slots[0].score = 3
	Game.slots[2].score = 1

	await _shoot("res://scenes/ui/main_menu.tscn", "01_main_menu", 2.5)
	Game.debug_fill_players(3)
	Game.slots[1].dog = Game.dogs[4]
	Game.slots[1].ready = true
	Game.slots[2].dog = Game.dogs[2]
	await _shoot("res://scenes/ui/dog_select.tscn", "02_dog_select")
	await _shoot("res://scenes/ui/match_setup.tscn", "03_match_setup")
	Game.gallery_kind = "dogs"
	await _shoot("res://scenes/ui/gallery.tscn", "04_gallery_dogs")
	await _shoot("res://scenes/ui/results.tscn", "05_results")

	Game.reset_scores()
	Game.slots[0].score = 2
	for i in Game.arenas.size():
		Game.selected_arena = Game.arenas[i]
		var m: Node = load("res://scenes/match/match.tscn").instantiate()
		add_child(m)
		await get_tree().create_timer(4.2).timeout
		# Throw once so a ball is mid-flight, then wait a beat and capture.
		var d: Dog = m.dogs[0]
		d.input = DeviceInput.new(DeviceInput.VIRTUAL)
		d.input.virtual_move = Vector2(1, 0.4).normalized()
		await get_tree().create_timer(0.3).timeout
		d.input.virtual_buttons[&"throw"] = true
		await get_tree().create_timer(0.25).timeout
		await _capture("1%d_match_%s" % [i, Game.arenas[i].id])
		m.queue_free()
		await get_tree().process_frame
	print("[shots] done -> " + ProjectSettings.globalize_path(out_dir))
	get_tree().quit(0)


func _shoot(path: String, name_: String, settle: float = 0.4) -> void:
	var inst: Node = load(path).instantiate()
	add_child(inst)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().create_timer(settle).timeout
	await _capture(name_)
	inst.queue_free()
	await get_tree().process_frame


func _capture(name_: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var file := out_dir.path_join(name_ + ".png")
	var err := img.save_png(file)
	print("[shots] %s -> %s (%s)" % [name_, file, error_string(err)])
