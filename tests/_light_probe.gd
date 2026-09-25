extends Node
## Temporary: arena-only captures for lighting iteration. Delete before committing.
var out_dir := "user://probe"
var diag := false

func _ready() -> void:
	Game.tutorial_shown = true
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.trim_prefix("--out=")
		if arg == "--diag":
			diag = true
	DirAccess.make_dir_recursive_absolute(out_dir)
	Game.debug_fill_players(4)
	Game.random_arena_each_round = false
	Game.powerups_enabled = true
	var only := [0, 4] if OS.get_cmdline_user_args().has("--one") else range(Game.arenas.size())
	for i: int in only:
		Game.selected_arena = Game.arenas[i]
		var m: Node = load("res://scenes/match/match.tscn").instantiate()
		add_child(m)
		await get_tree().process_frame
		m.round_time_left = 999.0
		await get_tree().create_timer(0.6).timeout
		if diag:
			for l in get_tree().root.find_children("*", "Light3D", true, false):
				print("LIGHT ", l.get_path(), " shadow=", l.shadow_enabled, " vis=", l.is_visible_in_tree(), " e=", l.light_energy, " mode=", l.get("directional_shadow_mode"), " maxd=", l.get("directional_shadow_max_distance"), " rot=", l.global_rotation_degrees, " mask=", l.light_cull_mask)
			var cam := get_viewport().get_camera_3d()
			print("CAM ", cam.get_path(), " proj=", cam.projection, " size=", cam.size, " near=", cam.near, " far=", cam.far, " pos=", cam.global_position)
			var cube := MeshInstance3D.new()
			cube.mesh = Mats.box(Vector3(2, 2, 2))
			cube.position = Vector3(0, 3, 0)
			m.add_child(cube)
			for l in m.find_children("*", "DirectionalLight3D", true, false):
				l.shadow_opacity = 1.0
			for w in m.find_children("*", "WorldEnvironment", true, false):
				w.environment.ambient_light_energy = 0.0
		await _capture("c%d_countdown_%s" % [i, Game.arenas[i].id])
		await get_tree().create_timer(3.8).timeout
		var d: Dog = m.dogs[0]
		d.input = DeviceInput.new(DeviceInput.VIRTUAL)
		m.toys[0].pick_up(d)
		d.input.virtual_move = Vector2(1, 0.4).normalized()
		await get_tree().create_timer(0.3).timeout
		d.input.virtual_buttons[&"throw"] = true
		await get_tree().create_timer(Dog.CHARGE_TIME * 0.75).timeout
		await _capture("w%d_windup_%s" % [i, Game.arenas[i].id])
		d.input.virtual_buttons[&"throw"] = false
		await get_tree().create_timer(0.25).timeout
		await _capture("m%d_%s" % [i, Game.arenas[i].id])
		if i == 0:
			d.slot.powerups.assign([PowerupKinds.SQUEAKY_BLAST, PowerupKinds.MUD_TRACK])
			d._action_lockout = 0.0
			var t2: Toy = m.toys[1]
			t2.pick_up(d)
			d.facing = Vector3(1, 0, 0.25).normalized()
			d.input.virtual_move = Vector2.ZERO
			d._throw(1.0)
			await get_tree().create_timer(0.3).timeout
			await _capture("p0_mud_trail")
			await get_tree().create_timer(0.3).timeout
			await _capture("p1_fuse")
		m.queue_free()
		await get_tree().process_frame
	get_tree().quit(0)

func _capture(name_: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out_dir.path_join(name_ + ".png"))
