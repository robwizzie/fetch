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
				flow.add_child(_card(a.swatch, a.display_name, a.description))
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
