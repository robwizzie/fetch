extends Control
## Asset review tool: original sheet, actual runtime renderer, rig/clip/socket readiness.

var _selection: OptionButton
var _reference: TextureRect
var _status: RichTextLabel
var _viewport: SubViewport
var _camera: Camera3D
var _turntable: Node3D
var _model: DogModel
var _grip: MeshInstance3D
var _spin: CheckBox
var _show_grip: CheckBox
var _animation: OptionButton
var _view: OptionButton
var _state := "idle"
var _data: DogData


func _ready() -> void:
	UiKit.backdrop(self)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 28)
	add_child(margin)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 14)
	margin.add_child(root)
	var heading := HBoxContainer.new()
	root.add_child(heading)
	var title := UiKit.title("3D DOG STUDIO", 44)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	heading.add_child(title)
	_selection = OptionButton.new()
	_selection.custom_minimum_size.x = 200
	for dog in Game.dogs:
		_selection.add_item(dog.display_name)
	_selection.item_selected.connect(_select_dog)
	heading.add_child(_selection)
	var back := UiKit.button("Back", 130)
	back.pressed.connect(func() -> void: Game.goto(Game.SCENE_MAIN_MENU))
	heading.add_child(back)
	var intro := UiKit.label("Compare the original character sheet with the actual 3D model. Technical checks and visual likeness are reviewed separately.", 21)
	root.add_child(intro)

	var comparison := HBoxContainer.new()
	comparison.size_flags_vertical = Control.SIZE_EXPAND_FILL
	comparison.add_theme_constant_override("separation", 18)
	root.add_child(comparison)
	var reference_column := _column(comparison)
	reference_column.add_child(UiKit.label("ORIGINAL CHARACTER SHEET", 23, UiKit.YELLOW))
	_reference = TextureRect.new()
	_reference.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_reference.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_reference.size_flags_vertical = Control.SIZE_EXPAND_FILL
	reference_column.add_child(_reference)
	var model_column := _column(comparison)
	model_column.add_child(UiKit.label("ACTUAL IN-GAME 3D MODEL", 23, UiKit.YELLOW))
	var container := SubViewportContainer.new()
	container.stretch = true
	container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	model_column.add_child(container)
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(800, 550)
	_viewport.own_world_3d = true
	_viewport.msaa_3d = Viewport.MSAA_4X
	container.add_child(_viewport)
	_build_studio()

	var controls := HBoxContainer.new()
	controls.alignment = BoxContainer.ALIGNMENT_CENTER
	controls.add_theme_constant_override("separation", 18)
	root.add_child(controls)
	var view_label := UiKit.label("View", 22)
	view_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	controls.add_child(view_label)
	_view = OptionButton.new()
	for view_name in ["Three-quarter", "Front", "Side", "Back", "Gameplay"]:
		_view.add_item(view_name)
	_view.item_selected.connect(func(_index: int) -> void: _set_view())
	controls.add_child(_view)
	var pose_label := UiKit.label("Pose", 22)
	pose_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	controls.add_child(pose_label)
	_animation = OptionButton.new()
	for state in DogAssetValidator.STATES:
		_animation.add_item(state.capitalize())
	_animation.item_selected.connect(_select_animation)
	controls.add_child(_animation)
	_spin = CheckBox.new()
	_spin.text = "Rotate"
	controls.add_child(_spin)
	_show_grip = CheckBox.new()
	_show_grip.text = "Mouth grip"
	_show_grip.button_pressed = true
	controls.add_child(_show_grip)
	var refresh := UiKit.button("Reload model", 180)
	refresh.pressed.connect(func() -> void: _select_dog(_selection.selected))
	controls.add_child(refresh)
	_status = RichTextLabel.new()
	_status.custom_minimum_size.y = 156
	_status.bbcode_enabled = true
	_status.add_theme_font_size_override("normal_font_size", 21)
	root.add_child(_status)
	_select_dog(0)
	_selection.grab_focus()


func _column(parent: Control) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", UiKit.panel_style(Color("648566")))
	parent.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	panel.add_child(column)
	return column


func _build_studio() -> void:
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("e6e0d4")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("dce8ff")
	environment.environment.ambient_light_energy = 0.5
	_viewport.add_child(environment)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-40, -35, 0)
	key.light_color = Color("fff0da")
	key.light_energy = 0.85
	key.shadow_enabled = true
	_viewport.add_child(key)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-25, 145, 0)
	fill.light_color = Color("c6ddff")
	fill.light_energy = 0.3
	_viewport.add_child(fill)
	var floor_mesh := MeshInstance3D.new()
	var floor_plane := PlaneMesh.new()
	floor_plane.size = Vector2(20, 20)
	floor_mesh.mesh = floor_plane
	var floor_material := StandardMaterial3D.new()
	floor_material.albedo_color = Color("e6e0d4")
	floor_material.roughness = 1.0
	floor_mesh.material_override = floor_material
	floor_mesh.position.y = -0.01
	_viewport.add_child(floor_mesh)
	_turntable = Node3D.new()
	_viewport.add_child(_turntable)
	_camera = Camera3D.new()
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_viewport.add_child(_camera)
	_grip = MeshInstance3D.new()
	var marker_mesh := SphereMesh.new()
	marker_mesh.radius = 0.055
	marker_mesh.height = 0.11
	_grip.mesh = marker_mesh
	var marker_material := StandardMaterial3D.new()
	marker_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	marker_material.albedo_color = Color("ff3385")
	_grip.material_override = marker_material
	_grip.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_viewport.add_child(_grip)


func _select_dog(index: int) -> void:
	if index < 0 or index >= Game.dogs.size():
		return
	_data = Game.dogs[index]
	_reference.texture = load(_data.reference_sheet) as Texture2D
	_state = DogAssetValidator.STATES[_animation.selected]
	if _model != null:
		_turntable.remove_child(_model)
		_model.queue_free()
	_model = DogModel.new()
	_turntable.add_child(_model)
	_model.setup(_data, _data.bandana_color)
	_apply_animation()
	_set_view()
	var report := _model.asset_report
	var ready: bool = report.valid
	_status.text = "[b]%s — %s[/b]\n" % [_data.display_name,
		("AUTHORED MODEL / " + ("LIKENESS REVIEWED" if _data.likeness_reviewed else "LIKENESS REVIEW NEEDED")) if ready else "TEMPORARY 3D PLACEHOLDER / AUTHORED ASSET MISSING OR INVALID"]
	if ready:
		_status.append_text("%d bones · %d skinned meshes · %d required clips found. Pink marker = rig-bound mouth grip.\n" % [report.bones, report.skinned_meshes, DogAssetValidator.STATES.size()])
	for issue in report.errors:
		_status.append_text("[color=#ffce83]• %s[/color]\n" % issue)
	for warning in report.warnings:
		_status.append_text("• %s\n" % warning)
	_status.append_text("%s\nAsset guide: assets/models/dogs/README.md" % _data.model_review_notes)


func _select_animation(index: int) -> void:
	_state = DogAssetValidator.STATES[index]
	# Recreate to clear terminal KO/win states and give every pose an identical starting point.
	_select_dog(_selection.selected)


func _apply_animation() -> void:
	match _state:
		"throw": _model.play_throw()
		"catch": _model.set_catching(true)
		"dash": _model.set_dashing(true)
		"ko": _model.play_knocked_out(Vector3.ZERO)
		"win": _model.play_victory()


func _set_view() -> void:
	if _model == null:
		return
	_turntable.rotation = Vector3.ZERO
	var h := _model.height()
	_camera.size = h * 1.60
	var look_target := Vector3(0, h * 0.48, 0)
	var position_offset := Vector3(1.9, 0.65, -3.0) * h
	match _view.selected:
		1: position_offset = Vector3(0, 0, -3) * h
		2: position_offset = Vector3(3, 0, 0) * h
		3: position_offset = Vector3(0, 0, 3) * h
		4: position_offset = Vector3(0, 3, -2.6) * h
	_camera.look_at_from_position(look_target + position_offset, look_target, Vector3.UP)


func _process(delta: float) -> void:
	if _model == null:
		return
	if _spin.button_pressed:
		_turntable.rotation.y += delta * 0.55
	_model.update_motion(Vector3.FORWARD, 0.8 if _state in ["run", "dash"] else 0.0, delta)
	_grip.visible = _show_grip.button_pressed
	_grip.global_transform = _model.get_mouth_transform().orthonormalized()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		Game.goto(Game.SCENE_MAIN_MENU)
