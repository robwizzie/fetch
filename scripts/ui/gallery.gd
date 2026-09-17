extends Control
## Read-only showcase of dogs / toys / arenas / modes, driven entirely by the data folders.


func _ready() -> void:
	UiKit.backdrop(self)
	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.alignment = BoxContainer.ALIGNMENT_CENTER
	root.add_theme_constant_override("separation", 20)
	add_child(root)
	root.add_child(UiKit.title(Game.gallery_kind.to_upper(), 72, UiKit.ACCENT))

	var flow := HFlowContainer.new()
	flow.alignment = FlowContainer.ALIGNMENT_CENTER
	flow.add_theme_constant_override("h_separation", 20)
	flow.add_theme_constant_override("v_separation", 20)
	root.add_child(flow)

	match Game.gallery_kind:
		"dogs":
			var i := 0
			for d in Game.dogs:
				var color: Color = PlayerSlot.COLORS[i % PlayerSlot.COLORS.size()]
				var card := _card(d.card_color, d.display_name, d.description)
				card.get_node("VBox").add_child(UiKit.dog_portrait(d, color, Vector2(260, 210), 1.0, 0.0, true))
				card.get_node("VBox").move_child(card.get_node("VBox").get_child(-1), 1)
				flow.add_child(card)
				i += 1
		"toys":
			for t in Game.toys:
				flow.add_child(_card(t.color, t.display_name + ("" if t.fully_implemented else " (prototype)"), t.description))
		"arenas":
			for a in Game.arenas:
				var card := _card(a.swatch, a.display_name, a.description)
				if a.thumbnail != null:
					var shot := TextureRect.new()
					shot.texture = a.thumbnail
					shot.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
					shot.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
					shot.custom_minimum_size = Vector2(260, 146)
					var box := card.get_node("VBox")
					box.add_child(shot)
					box.move_child(shot, 1)
				flow.add_child(card)
		"powerups":
			for kind in PowerupKinds.ALL:
				var tint := PowerupKinds.color(kind)
				var card := _card(tint, PowerupKinds.display_name(kind), PowerupKinds.blurb(kind))
				var box := card.get_node("VBox")
				var badge := _powerup_badge(kind)
				box.add_child(badge)
				box.move_child(badge, 1)
				flow.add_child(card)
		"modes":
			for m in Game.modes:
				flow.add_child(_card(m.swatch, m.display_name + ("" if m.fully_implemented else " (coming soon)"), m.description))

	if Game.gallery_kind == "dogs":
		var studio := UiKit.button("3D DOG STUDIO")
		studio.pressed.connect(func() -> void: Game.goto("res://scenes/ui/model_review.tscn"))
		var studio_center := CenterContainer.new()
		studio_center.add_child(studio)
		root.add_child(studio_center)

	var back := UiKit.button("Back")
	back.pressed.connect(func() -> void: Game.goto(Game.SCENE_MAIN_MENU))
	var center := CenterContainer.new()
	center.add_child(back)
	root.add_child(center)
	back.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		Game.goto(Game.SCENE_MAIN_MENU)


## The same coloured chip the HUD belt shows, drawn large so people can learn the glyphs.
func _powerup_badge(kind: StringName) -> Control:
	var holder := CenterContainer.new()
	var badge := Panel.new()
	badge.custom_minimum_size = Vector2(96, 96)
	var style := StyleBoxFlat.new()
	style.bg_color = PowerupKinds.color(kind)
	style.border_color = PowerupKinds.color(kind).lightened(0.4)
	style.set_border_width_all(4)
	style.set_corner_radius_all(22)
	badge.add_theme_stylebox_override("panel", style)
	var glyph := UiKit.title(PowerupKinds.glyph(kind), 52, UiKit.INK)
	glyph.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	glyph.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge.add_child(glyph)
	holder.add_child(badge)
	return holder


func _card(color: Color, title: String, desc: String) -> PanelContainer:
	var p := PanelContainer.new()
	p.custom_minimum_size = Vector2(300, 0)
	p.add_theme_stylebox_override("panel", UiKit.panel_style(color))
	var v := VBoxContainer.new()
	v.name = "VBox"
	v.add_theme_constant_override("separation", 8)
	p.add_child(v)
	v.add_child(UiKit.title(title, 32, color))
	var d := UiKit.label(desc, 20, Color(1, 1, 1, 0.8))
	d.custom_minimum_size = Vector2(260, 0)
	v.add_child(d)
	return p
