extends Node
## Renders a thumbnail of every arena from the gameplay camera angle and saves it under
## images/arenas/. A colour swatch tells you nothing about a map; an actual picture of the
## obstacles does, which is what the menus want when you are choosing where to play.
##
##   godot --path . res://tools/build_arena_thumbnails.tscn
##
## Needs a display (it renders), so it cannot run headless.

const SIZE := Vector2i(640, 360)
const OUT_DIR := "res://images/arenas"


func _ready() -> void:
	# Whatever ran before this, the world renders at normal speed here.
	Engine.time_scale = 1.0
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	for data in Game.arenas:
		await _shoot(data)
	print("[thumbs] done -> %s" % ProjectSettings.globalize_path(OUT_DIR))
	get_tree().quit(0)


func _shoot(data: ArenaData) -> void:
	var viewport := SubViewport.new()
	viewport.size = SIZE
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.msaa_3d = Viewport.MSAA_4X
	add_child(viewport)

	var arena: Arena = data.scene.instantiate()
	viewport.add_child(arena)
	# The arena scene carries its own camera; frame the whole floor rather than the action.
	var camera := arena.get_node_or_null("Camera") as Camera3D
	if camera != null:
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		camera.size = arena.size.y * 1.34
		camera.position = Vector3(0, arena.size.y * 1.15, arena.size.y * 0.92)
		camera.rotation_degrees = Vector3(-52, 0, 0)
		camera.make_current()

	# A few toys and a crate so the picture reads as a place you play, not an empty box.
	var toy_index := 0
	for i in arena.toy_spawns.get_child_count():
		if Game.toys.is_empty():
			break
		var toy: Toy = load("res://scenes/actors/toy.tscn").instantiate()
		toy.setup(Game.toys[toy_index % Game.toys.size()])
		toy.position = arena.clear_pickup_position(arena.get_toy_spawn_position(i), 0.7)
		arena.add_child(toy)
		toy_index += 1

	# Frame-based rather than a SceneTreeTimer: create_timer is scaled by Engine.time_scale, so
	# a leftover hitstop would leave it waiting forever. Each arena takes roughly half a minute
	# now that the maps are bigger, so the whole run is a few minutes - it is not stuck.
	for _i in 12:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw

	var image := viewport.get_texture().get_image()
	var path := "%s/%s.png" % [OUT_DIR, data.id]
	var err := image.save_png(ProjectSettings.globalize_path(path))
	print("[thumbs] %-14s -> %s (%s)" % [data.id, path, error_string(err)])
	viewport.queue_free()
	await get_tree().process_frame
