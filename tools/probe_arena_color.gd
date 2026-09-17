extends Node
## Renders one arena and reports the colour of its ground, so a palette can be tuned against
## the cover art by measurement instead of by eye.
##
##   godot --path . res://tools/probe_arena_color.tscn -- --arena=backyard
##
## The numbers to aim at live in Palette, and were themselves sampled from the cover. Note the
## albedo in a scene always sits well BELOW the colour you want on screen: feeding the sampled
## lit colour straight in as albedo and then lighting it blows the map out.
##
## Needs a display (it renders), so it cannot run headless.

func _ready() -> void:
	var id := "backyard"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--arena="):
			id = arg.split("=")[1]
	var data: ArenaData = null
	for a in Game.arenas:
		if String(a.id) == id:
			data = a
	var vp := SubViewport.new()
	vp.size = Vector2i(640, 360)
	vp.own_world_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	var arena: Arena = data.scene.instantiate()
	vp.add_child(arena)
	var cam := arena.get_node_or_null("Camera") as Camera3D
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = arena.size.y * 1.25
	cam.position = Vector3(0, arena.size.y * 1.15, arena.size.y * 0.9)
	cam.rotation_degrees = Vector3(-52, 0, 0)
	cam.make_current()
	await get_tree().process_frame
	await get_tree().create_timer(0.3).timeout
	await RenderingServer.frame_post_draw
	var img := vp.get_texture().get_image()
	img.convert(Image.FORMAT_RGBA8)
	var r := 0.0
	var g := 0.0
	var b := 0.0
	var n := 0
	for y in range(int(img.get_height() * 0.42), int(img.get_height() * 0.62), 2):
		for x in range(int(img.get_width() * 0.10), int(img.get_width() * 0.30), 2):
			var c := img.get_pixel(x, y)
			r += c.r
			g += c.g
			b += c.b
			n += 1
	var got := Color(r / n, g / n, b / n)
	print("[one] %-12s lawn #%s hsv(%.2f %.2f %.2f)" % [id, got.to_html(false), got.h, got.s, got.v])
	get_tree().quit(0)
