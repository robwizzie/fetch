extends Node
## The content pages: Meet the Pack, Toys and Power-ups.
##
## These exist to answer "what is this and what does it do" before a match starts, so what is
## checked here is that every entry actually shows a live model and says what it does — a page
## that silently renders nothing still loads fine, which is exactly the failure worth catching.

var failed := false


func _ready() -> void:
	Sfx.enabled = false
	Music.enabled = false
	for kind in ["dogs", "toys", "powerups", "arenas"]:
		await _page(kind)
	await _previews_accept_every_kind()
	if not failed:
		print("[gallery] PASSED: live previews on every card, specs on toys, blurbs on power-ups")
	get_tree().quit(1 if failed else 0)


func _page(kind: String) -> void:
	Game.gallery_kind = kind
	var page: Node = load("res://scenes/ui/gallery.tscn").instantiate()
	add_child(page)
	await get_tree().process_frame
	var previews := _find(page, "ModelPreview")
	var expected := 0
	match kind:
		"dogs":
			expected = Game.dogs.size()
		"toys":
			expected = Game.toys.size()
		"powerups":
			expected = PowerupKinds.ALL.size()
	if kind == "arenas":
		# Arenas show a rendered thumbnail rather than a live model.
		var shots := 0
		for a in Game.arenas:
			if a.thumbnail != null:
				shots += 1
		_check(shots == Game.arenas.size(), "every arena has a thumbnail to show (%d of %d)" % [shots, Game.arenas.size()])
	else:
		_check(previews.size() == expected, "%s page shows %d live previews, found %d" % [kind, expected, previews.size()])
	page.queue_free()
	await get_tree().process_frame


## Every toy and power-up has to survive being put on the turntable. A model that throws while
## building would leave a blank card on the page rather than an error anybody notices.
func _previews_accept_every_kind() -> void:
	var preview := ModelPreview.new(Vector2i(160, 160))
	add_child(preview)
	await get_tree().process_frame
	for dog in Game.dogs:
		preview.show_dog(dog)
		await get_tree().process_frame
		_check(_subject_count(preview) > 0, "%s has something to show" % dog.display_name)
		# Where the dog actually lands in its card. It has to fill the card, stand on the
		# bottom of it and keep its ears and tail inside the edges - a dog framed by the
		# height in its data file rather than by its own measurements fails one of the three.
		var fit := preview.frame_fit()
		_check(fit.size.y > 0.62, "%s fills the card it is given (%.2f of the height)" % [dog.display_name, fit.size.y])
		_check(fit.end.y > 0.93 and fit.end.y <= 1.001, "%s stands on the bottom of the frame (%.3f)" % [dog.display_name, fit.end.y])
		_check(fit.position.x > -0.001 and fit.end.x < 1.001, "%s is not cropped at the sides (%.2f..%.2f)" % [dog.display_name, fit.position.x, fit.end.x])
		_check(fit.position.y > -0.001, "%s keeps its ears inside the frame (%.3f)" % [dog.display_name, fit.position.y])
	for toy in Game.toys:
		preview.show_toy(toy)
		await get_tree().process_frame
		_check(_subject_count(preview) > 0, "%s has something to show" % toy.display_name)
		_check(toy.throw_speed > 0.0, "%s has a throw speed to quote" % toy.display_name)
	for kind in PowerupKinds.ALL:
		preview.show_powerup(kind)
		await get_tree().process_frame
		_check(_subject_count(preview) > 0, "%s has something to show" % kind)
		_check(not PowerupKinds.blurb(kind).is_empty(), "%s says what it does" % kind)
	# Switching subjects replaces the last one instead of piling them up.
	preview.show_dog(Game.dogs[0])
	await get_tree().process_frame
	var first := _subject_count(preview)
	preview.show_dog(Game.dogs[1])
	await get_tree().process_frame
	_check(_subject_count(preview) == first, "swapping the subject clears the previous one")
	preview.queue_free()
	await get_tree().process_frame


func _subject_count(preview: ModelPreview) -> int:
	var pivot: Node3D = preview.get("_pivot")
	var live := 0
	for child in pivot.get_children():
		if not child.is_queued_for_deletion():
			live += 1
	return live


func _find(node: Node, type_name: String) -> Array[Node]:
	var out: Array[Node] = []
	for child in node.find_children("*", "", true, false):
		var script: Script = child.get_script()
		if script != null and String(script.get_global_name()) == type_name:
			out.append(child)
	return out


func _check(ok: bool, message: String) -> void:
	if not ok:
		failed = true
		push_error("[gallery] " + message)
