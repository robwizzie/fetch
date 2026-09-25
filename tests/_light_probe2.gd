extends Node
var out_dir := "user://probe"
const VARIANTS := [
	# name, tonemap, sun, ambient, exposure, white, saturation
	["a_linear", 0, 0.9, 0.42, 1.0, 1.0, 1.05],
	["b_filmic", 2, 1.05, 0.45, 0.95, 4.0, 1.18],
	["c_aces", 3, 1.1, 0.45, 0.9, 6.0, 1.12],
	["d_filmic_low", 2, 0.95, 0.4, 1.0, 3.0, 1.2],
]

func _ready() -> void:
	Game.tutorial_shown = true
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.trim_prefix("--out=")
	Game.debug_fill_players(4)
	Game.random_arena_each_round = false
	for arena_index: int in [0, 1]:
		Game.selected_arena = Game.arenas[arena_index]
		var m: Node = load("res://scenes/match/match.tscn").instantiate()
		add_child(m)
		await get_tree().create_timer(0.8).timeout
		var arena: Node = m.find_children("*", "Arena", true, false)[0] if not m.find_children("*", "Arena", true, false).is_empty() else null
		var sun: DirectionalLight3D
		var env: Environment
		for l in m.find_children("*", "DirectionalLight3D", true, false):
			if l.name != "Fill":
				sun = l
		for w in m.find_children("*", "WorldEnvironment", true, false):
			env = w.environment
		var indoor: bool = arena_index == 1
		for v in VARIANTS:
			env.tonemap_mode = v[1]
			sun.light_energy = v[2] * (0.92 if indoor else 1.0)
			env.ambient_light_energy = v[3]
			env.tonemap_exposure = v[4]
			env.tonemap_white = v[5]
			env.adjustment_saturation = v[6]
			await _capture("%d_%s" % [arena_index, v[0]])
		m.queue_free()
		await get_tree().process_frame
	get_tree().quit(0)

func _capture(name_: String) -> void:
	for i in 3:
		await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out_dir.path_join(name_ + ".png"))
