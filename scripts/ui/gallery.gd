extends Control
## Read-only showcase of dogs / toys / arenas / modes, driven entirely by the data folders.


## What each page is called on its sign, and the line under it.
const HEADINGS := {
	"dogs": ["MEET THE PACK", "Every dog plays the same game - they just play it differently."],
	"toys": ["TOYS", "What turns up on the grass, and what each one does when you throw it."],
	"arenas": ["ARENAS", "Where the pack plays."],
	"powerups": ["POWER-UPS", "Grab one off the grass and it is yours until you are bonked."],
	"hats": ["HATS", "Earn them by playing. Wear them from Choose Your Dog."],
	"modes": ["MODES", "Ways to play."],
}


func _ready() -> void:
	UiKit.cover_backdrop(self)
	# One column with air around it: heading at the top, the way out at the bottom, and the
	# cards centred in everything between.
	var page := MarginContainer.new()
	page.set_anchors_preset(Control.PRESET_FULL_RECT)
	page.add_theme_constant_override("margin_left", 56)
	page.add_theme_constant_override("margin_right", 56)
	page.add_theme_constant_override("margin_top", 30)
	page.add_theme_constant_override("margin_bottom", 30)
	add_child(page)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 14)
	page.add_child(root)
	var heading: Array = HEADINGS.get(Game.gallery_kind, [Game.gallery_kind.to_upper(), ""])
	root.add_child(UiKit.sign(heading[0], 58))
	if heading[1] != "":
		var line := UiKit.label(heading[1], 22, Color(1, 1, 1, 0.78))
		line.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.5))
		line.add_theme_constant_override("outline_size", 4)
		root.add_child(line)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.follow_focus = true
	root.add_child(scroll)
	# The middle box fills the room the heading and the buttons leave and centres the cards in
	# it. Without it the ScrollContainer stretches and the cards stay pinned to its top edge.
	var middle := VBoxContainer.new()
	middle.alignment = BoxContainer.ALIGNMENT_CENTER
	middle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	middle.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(middle)
	var flow := HFlowContainer.new()
	flow.alignment = FlowContainer.ALIGNMENT_CENTER
	flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	flow.add_theme_constant_override("h_separation", 22)
	flow.add_theme_constant_override("v_separation", 22)
	middle.add_child(flow)

	match Game.gallery_kind:
		"dogs":
			for d in Game.dogs:
				var card := _card(d.card_color, d.display_name, d.description)
				# This page exists to show the dogs off, and the row has a screen to itself: give
				# them the room rather than five small cards adrift in the middle of it.
				card.custom_minimum_size = Vector2(330, 0)
				var box := _box(card)
				var dog_shot := _stage(ModelPreview.new(Vector2i(400, 360)), Vector2(298, 280), d.card_color)
				(dog_shot.get_child(1) as ModelPreview).show_dog(d)
				box.add_child(dog_shot)
				box.move_child(dog_shot, 0)
				var stats := VBoxContainer.new()
				stats.add_theme_constant_override("separation", 6)
				stats.add_child(UiKit.stat_row("Speed", d.speed_rating, d.card_color.lightened(0.15)))
				stats.add_child(UiKit.stat_row("Throw", d.throw_rating, d.card_color.lightened(0.15)))
				stats.add_child(UiKit.stat_row("Catch", d.catch_rating, d.card_color.lightened(0.15)))
				stats.add_child(UiKit.stat_row("Dash", d.dash_rating, d.card_color.lightened(0.15)))
				var stats_center := CenterContainer.new()
				stats_center.add_child(stats)
				box.add_child(stats_center)
				flow.add_child(card)
		"toys":
			for t in Game.toys:
				var card := _card(t.color, t.display_name + ("" if t.fully_implemented else " (prototype)"), t.description)
				# Even cards make an even grid; ragged heights were most of why this page
				# looked thrown together. Two rows of these have to fit the screen without a
				# scrollbar, because nothing on this page takes focus for a pad to scroll it with.
				card.custom_minimum_size = Vector2(320, 0)
				var box := _box(card)
				var shot := _stage(ModelPreview.new(Vector2i(360, 260)), Vector2(286, 140), t.color)
				(shot.get_child(1) as ModelPreview).show_toy(t)
				box.add_child(shot)
				box.move_child(shot, 0)
				box.add_child(_chip_row(_toy_trait(t), t.color))
				box.add_child(_facts([
					["Throw", "%.0f m/s" % t.throw_speed],
					["Size", "%.2f m across" % (t.radius * 2.0)],
				], t.color))
				flow.add_child(card)
		"arenas":
			for a in Game.arenas:
				var card := _card(a.swatch, a.display_name, a.description)
				card.custom_minimum_size = Vector2(340, 0)
				if a.thumbnail != null:
					var frame := PanelContainer.new()
					var frame_style := StyleBoxFlat.new()
					frame_style.bg_color = Color.WHITE
					frame_style.set_corner_radius_all(14)
					frame.add_theme_stylebox_override("panel", frame_style)
					# Clipped to the frame's rounded corners, so the picture sits in the card
					# instead of poking square corners out of it.
					frame.clip_children = CanvasItem.CLIP_CHILDREN_ONLY
					var shot := TextureRect.new()
					shot.texture = a.thumbnail
					shot.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
					shot.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
					shot.custom_minimum_size = Vector2(300, 168)
					frame.add_child(shot)
					var box := _box(card)
					box.add_child(frame)
					box.move_child(frame, 0)
				flow.add_child(card)
		"powerups":
			for kind in PowerupKinds.ALL:
				var tint := PowerupKinds.color(kind)
				var card := _card(tint, PowerupKinds.display_name(kind), PowerupKinds.blurb(kind))
				var box := _box(card)
				var badge := _stage(ModelPreview.new(Vector2i(300, 240)), Vector2(264, 160), tint)
				(badge.get_child(1) as ModelPreview).show_powerup(kind)
				box.add_child(badge)
				box.move_child(badge, 0)
				flow.add_child(card)
		"hats":
			# Every hat, earned or not: the locked ones say how to get them and how close you are.
			for hat in Game.hats:
				var owned := Progress.is_unlocked(hat)
				var tint := hat.color if owned else Color(0.4, 0.42, 0.41)
				var progress := "" if owned or hat.stat == &"" else "\n%d / %d" % [mini(Progress.stat(hat.stat), hat.threshold), hat.threshold]
				var card := _card(tint, hat.display_name if owned else "???", ("Earned: " if owned else "") + hat.unlock_text + progress)
				var shot := _stage(ModelPreview.new(Vector2i(300, 240)), Vector2(264, 160), tint)
				var preview := shot.get_child(1) as ModelPreview
				preview.show_hat(hat)
				if not owned:
					# A silhouette: you can see there is something to earn, not what it looks like.
					preview.modulate = Color(0.05, 0.05, 0.08)
				_box(card).add_child(shot)
				_box(card).move_child(shot, 0)
				flow.add_child(card)
		"modes":
			for m in Game.modes:
				flow.add_child(_card(m.swatch, m.display_name + ("" if m.fully_implemented else " (coming soon)"), m.description))

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 18)
	root.add_child(buttons)
	var back := UiKit.wood_button("Back", 300)
	back.pressed.connect(func() -> void: Game.goto(Game.SCENE_MAIN_MENU))
	buttons.add_child(back)
	if Game.gallery_kind == "dogs":
		var studio := UiKit.wood_button("3D Dog Studio", 300, true)
		studio.pressed.connect(func() -> void: Game.goto("res://scenes/ui/model_review.tscn"))
		buttons.add_child(studio)
	back.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		Game.goto(Game.SCENE_MAIN_MENU)


## Stands a preview in a soft pool of light in the card's colour, so every card has the same
## window whatever is turning inside it. The preview is child 1 (the light is child 0).
func _stage(preview: ModelPreview, size: Vector2, tint: Color) -> Control:
	var holder := Control.new()
	holder.custom_minimum_size = size
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var light := UiKit.spotlight(tint)
	light.set_anchors_preset(Control.PRESET_FULL_RECT)
	holder.add_child(light)
	preview.set_anchors_preset(Control.PRESET_FULL_RECT)
	holder.add_child(preview)
	return holder


## What makes this toy different from the rest, in two words.
func _toy_trait(data: ToyData) -> String:
	match data.special:
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
	# A wrapping label asks for no width at all, and a CenterContainer takes it at its word:
	# the chip came out one letter wide with the trait running down the card.
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
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
		key.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		key.autowrap_mode = TextServer.AUTOWRAP_OFF
		key.custom_minimum_size = Vector2(88, 0)
		line.add_child(key)
		# Same trap as the chip: these are short values, so they never wrap - they just have to
		# be allowed to ask for the width they need.
		var value := UiKit.label(str(row[1]), 18, Color(1, 1, 1, 0.9))
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		value.autowrap_mode = TextServer.AUTOWRAP_OFF
		line.add_child(value)
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


## A showcase card: the name on a banner in [param color], then a body column (see [method _box])
## that the page fills with a picture and facts, and the description at the foot.
func _card(color: Color, title: String, desc: String) -> PanelContainer:
	var p := PanelContainer.new()
	p.custom_minimum_size = Vector2(300, 0)
	p.add_theme_stylebox_override("panel", UiKit.card_style(color))
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 0)
	p.add_child(column)
	column.add_child(UiKit.card_banner(title.to_upper(), color, 30))
	var margin := MarginContainer.new()
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 16)
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(margin)
	var v := VBoxContainer.new()
	v.name = "VBox"
	v.add_theme_constant_override("separation", 10)
	margin.add_child(v)
	var d := UiKit.label(desc, 19, Color(1, 1, 1, 0.86))
	d.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	d.custom_minimum_size = Vector2(260, 52)
	v.add_child(d)
	p.set_meta("box", v)
	return p


func _box(card: PanelContainer) -> VBoxContainer:
	return card.get_meta("box") as VBoxContainer
