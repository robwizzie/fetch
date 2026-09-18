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

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.follow_focus = true
	root.add_child(scroll)
	var flow := HFlowContainer.new()
	flow.alignment = FlowContainer.ALIGNMENT_CENTER
	flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	flow.add_theme_constant_override("h_separation", 20)
	flow.add_theme_constant_override("v_separation", 20)
	scroll.add_child(flow)

	match Game.gallery_kind:
		"dogs":
			var i := 0
			for d in Game.dogs:
				var color: Color = PlayerSlot.COLORS[i % PlayerSlot.COLORS.size()]
				var card := _card(d.card_color, d.display_name, d.description)
				var dog_shot := _stage(ModelPreview.new(Vector2i(360, 300)), Vector2(260, 210), color)
				(dog_shot.get_child(0) as ModelPreview).show_dog(d)
				card.get_node("VBox").add_child(dog_shot)
				card.get_node("VBox").move_child(dog_shot, 1)
				flow.add_child(card)
				i += 1
		"toys":
			for t in Game.toys:
				var card := _card(t.color, t.display_name + ("" if t.fully_implemented else " (prototype)"), t.description)
				# Even cards make an even grid; ragged heights were most of why this page
				# looked thrown together.
				card.custom_minimum_size = Vector2(320, 486)
				var box := card.get_node("VBox")
				var shot := _stage(ModelPreview.new(Vector2i(360, 300)), Vector2(272, 210), t.color)
				(shot.get_child(0) as ModelPreview).show_toy(t)
				box.add_child(shot)
				box.move_child(shot, 1)
				box.add_child(_chip_row(_toy_trait(t), t.color))
				box.add_child(_facts([
					["Throw", "%.0f m/s" % t.throw_speed],
					["Size", "%.2f m across" % (t.radius * 2.0)],
				], t.color))
				flow.add_child(card)
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
				var badge := _stage(ModelPreview.new(Vector2i(300, 260)), Vector2(260, 170), tint)
				(badge.get_child(0) as ModelPreview).show_powerup(kind)
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


## Frames a preview so every card has the same window, whatever is turning inside it.
func _stage(preview: ModelPreview, size: Vector2, tint: Color) -> PanelContainer:
	var holder := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.22)
	style.border_color = tint.lightened(0.25)
	style.set_border_width_all(3)
	style.set_corner_radius_all(14)
	holder.add_theme_stylebox_override("panel", style)
	holder.custom_minimum_size = size
	holder.add_child(preview)
	return holder


## What makes this toy different from the rest, in two words.
func _toy_trait(data: ToyData) -> String:
	match data.special:
		ToyData.Special.KNOCKBACK:
			return "SHOVES RIVALS"
		ToyData.Special.SQUEAK:
			return "SQUEAK DISARMS"
		ToyData.Special.RICOCHET:
			return "WILD RICOCHETS"
		ToyData.Special.HEAVY:
			return "PLOUGHS THROUGH"
	return "STRAIGHT AND TRUE"


## The trait as a filled chip, so it reads before the description does.
func _chip_row(text: String, tint: Color) -> CenterContainer:
	var holder := CenterContainer.new()
	var chip := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = tint.darkened(0.15)
	style.set_corner_radius_all(12)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 5
	style.content_margin_bottom = 5
	chip.add_theme_stylebox_override("panel", style)
	var label := UiKit.label(text, 18, UiKit.INK)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	chip.add_child(label)
	holder.add_child(chip)
	return holder


## A short spec table. "What does it do" is a number as often as it is a sentence.
func _facts(rows: Array, tint: Color) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	for row in rows:
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 8)
		var key := UiKit.label(str(row[0]), 18, tint.lightened(0.45))
		key.custom_minimum_size = Vector2(88, 0)
		line.add_child(key)
		line.add_child(UiKit.label(str(row[1]), 18, Color(1, 1, 1, 0.9)))
		box.add_child(line)
	return box


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
	var heading := UiKit.title(title, 30, color)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(heading)
	var d := UiKit.label(desc, 19, Color(1, 1, 1, 0.82))
	d.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	d.custom_minimum_size = Vector2(260, 56)
	v.add_child(d)
	return p
