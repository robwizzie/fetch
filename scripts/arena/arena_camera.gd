class_name ArenaCamera
extends Camera3D
## Shared arena camera. A fixed tilted heading and a narrow perspective lens show the arena as a
## diorama - wall faces, prop sides and dogs all read as solid - and the whole park stays in
## shot nearly all the time, the way a couch party game wants it: you should never lose your dog
## off the edge or have to learn where the camera is going. It leans in only a little when the
## pack bunches up, and punches in on a knockout.

@export_range(35.0, 75.0) var pitch_degrees := 58.0
## Vertical field of view. Narrow, so the far wall is not dwarfed by the near one.
@export_range(15.0, 60.0) var lens_degrees := 30.0
@export var look_target := Vector3(0, 0.0, 0.0)
@export var follow_speed := 3.0
@export var zoom_in_speed := 1.8
## How far towards the pack the framing centre may drift (0 = locked on the arena centre).
@export_range(0.0, 1.0) var follow_share := 0.35
## How close the camera may come when everyone is bunched up, as a share of the full overview.
@export_range(0.5, 1.0) var closest_share := 0.76
## Screen kept clear at the top for the player cards, and a sliver at the bottom, as shares of
## the screen height. The arena is framed into what is left.
@export_range(0.0, 0.4) var hud_top := 0.17
@export_range(0.0, 0.4) var hud_bottom := 0.035
@export_range(0.0, 0.2) var side_margin := 0.02
## Legacy scene properties; the perspective framing works out distance itself.
@export var height := 17.0
@export var framing_height := 13.5
@export var edge_padding := Vector2(2.1, 2.0)

## How far the camera sits from its target, along the fixed view direction. This is the zoom.
var distance := 30.0
var _arena_size := Vector2(26, 14.6)
var _home := Vector3.ZERO
var _target := Vector3.ZERO
var _last_tick := 0
var _focus_position := Vector3.ZERO
var _focus_left := 0.0
var _focus_duration := 0.0
var _final_focus := false
var _snap_next := true
## Pinned to the whole arena, with no fitting and no easing. The practice round wants a stable,
## complete view: every pen has to be visible at once, and a camera breathing in and out while
## people are still finding the buttons reads as a fault rather than as framing.
var locked_wide := false


func _ready() -> void:
	# Camera and impact timing continue during a slow-motion KO, but not during pause.
	process_mode = Node.PROCESS_MODE_ALWAYS
	projection = Camera3D.PROJECTION_PERSPECTIVE
	keep_aspect = Camera3D.KEEP_HEIGHT
	fov = lens_degrees
	# The default 4 km far plane stretched the directional shadow's depth range until no prop
	# or dog cast a shadow at all. A tall portrait window can push the lens out past 100 m.
	near = 1.0
	far = 220.0
	if get_parent() is Arena:
		_arena_size = get_parent().size
	_home = look_target
	_target = _home
	_last_tick = Time.get_ticks_usec()
	get_viewport().size_changed.connect(_on_viewport_changed)
	Events.dog_eliminated.connect(_on_dog_eliminated)
	Events.round_started.connect(_on_round_started)
	distance = _maximum_distance(_aspect())
	_place()


func _exit_tree() -> void:
	Juice.reset_time_effects()


func _process(_delta: float) -> void:
	var now := Time.get_ticks_usec()
	var real_delta := clampf(float(now - _last_tick) / 1000000.0, 0.0, 0.05)
	_last_tick = now
	if get_tree().paused:
		_focus_left = 0.0
		return
	_update_framing(real_delta)


func _update_framing(real_delta: float) -> void:
	_focus_left = maxf(0.0, _focus_left - real_delta)
	var aspect := _aspect()
	if locked_wide:
		_target = _home
		distance = _maximum_distance(aspect)
		_place()
		return
	var points := _gather_points()
	var frame := _fit_points(points, aspect)
	var goal: Vector3 = frame.target
	var goal_distance: float = frame.distance
	if _snap_next:
		_target = goal
		distance = goal_distance
		_snap_next = false
	else:
		var speed := 8.0 if _focus_left > 0.0 else follow_speed
		_target = _target.lerp(goal, 1.0 - exp(-speed * real_delta))
		# Pulling back is quick; moving closer is gradual so the floor never pumps.
		var zoom_speed := 10.0 if goal_distance > distance else zoom_in_speed
		if _focus_left > 0.0:
			zoom_speed = 7.0
		distance = lerpf(distance, goal_distance, 1.0 - exp(-zoom_speed * real_delta))
		# An accelerating dog or ricochet must never outrun camera interpolation.
		var maximum := _maximum_distance(aspect)
		var required := _required_distance(points, _target, aspect)
		if required > maximum:
			_target = goal
			required = _required_distance(points, _target, aspect)
		distance = clampf(maxf(distance, required), 1.0, maximum)
	_place()


## Back along the fixed view direction: up and towards the players' side of the room (+Z).
func _view_direction() -> Vector3:
	var pitch := deg_to_rad(clampf(pitch_degrees, 35.0, 75.0))
	return Vector3(0.0, sin(pitch), cos(pitch))


func _place() -> void:
	fov = lens_degrees
	look_at_from_position(_target + _view_direction() * distance, _target, Vector3.UP)


func _aspect() -> float:
	var viewport_size := get_viewport().get_visible_rect().size
	return maxf(viewport_size.x, 1.0) / maxf(viewport_size.y, 1.0)


func _gather_points() -> Array[Vector3]:
	var points: Array[Vector3] = []
	for node in get_tree().get_nodes_in_group("dogs"):
		if not node is Dog or not node.alive or node.is_queued_for_deletion():
			continue
		var dog := node as Dog
		var p := dog.global_position
		# Include the head/name and feet as well as a small movement look-ahead.
		points.append(p + Vector3(0, 2.4, 0))
		points.append(p)
		points.append(p + dog.velocity.limit_length(9.0) * 0.12 + Vector3(0, 0.8, 0))
	for node in get_tree().get_nodes_in_group("toys"):
		if not node is Toy or node.is_queued_for_deletion():
			continue
		var toy := node as Toy
		if toy.state == Toy.State.FLYING:
			points.append(toy.global_position)
	if _focus_left > 0.0:
		points.append(_focus_position)
		points.append(_focus_position + Vector3(0, 2.4, 0))
	return points


## A flat stand-in for the screen, used only to find the middle of the action.
func _plane(point: Vector3) -> Vector2:
	var pitch := deg_to_rad(clampf(pitch_degrees, 35.0, 75.0))
	return Vector2(point.x, point.y * cos(pitch) - point.z * sin(pitch))


## The closest the camera can sit to [param target] with every point inside the usable part of
## the screen. Solved per point rather than searched: with the heading fixed, a point's screen
## position is linear in its offset and inversely proportional to its depth, so each edge gives
## a distance directly.
func _required_distance(points: Array[Vector3], target: Vector3, aspect: float) -> float:
	var back := _view_direction()
	var forward := -back
	var up := Vector3(0.0, back.z, -back.y)
	var tan_v := tan(deg_to_rad(lens_degrees) * 0.5)
	var tan_h := tan_v * maxf(aspect, 0.01)
	# Usable screen, in normalised device units (-1..1), after the HUD bands and side margin.
	var right_limit := (1.0 - side_margin * 2.0) * tan_h
	var top_limit := (1.0 - hud_top * 2.0) * tan_v
	var bottom_limit := (1.0 - hud_bottom * 2.0) * tan_v
	var required := 1.0
	for point in points:
		var offset := point - target
		var depth := offset.dot(forward)
		var across := absf(offset.x)
		var lift := offset.dot(up)
		required = maxf(required, across / right_limit - depth)
		required = maxf(required, (lift / top_limit if lift > 0.0 else -lift / bottom_limit) - depth)
	return required


func _arena_corners() -> Array[Vector3]:
	var corners: Array[Vector3] = []
	for x in [-1.0, 1.0]:
		for z in [-1.0, 1.0]:
			for y in [0.0, 2.4]:
				corners.append(Vector3(x * (_arena_size.x * 0.5 + 0.8), y, z * (_arena_size.y * 0.5 + 0.8)))
	return corners


func _maximum_distance(aspect: float) -> float:
	return _required_distance(_arena_corners(), _home, aspect)


## Pure framing calculation, exercised at portrait and ultra-wide aspects by tests.
func _fit_points(points: Array[Vector3], aspect: float) -> Dictionary:
	var maximum := _maximum_distance(aspect)
	if points.is_empty():
		return {"target": _home, "distance": maximum}
	var low := _plane(points[0])
	var high := low
	for point in points:
		var projected := _plane(point)
		low = low.min(projected)
		high = high.max(projected)
	var center := (low + high) * 0.5
	var pitch := deg_to_rad(clampf(pitch_degrees, 35.0, 75.0))
	var target := Vector3(center.x, _home.y, (_home.y * cos(pitch) - center.y) / sin(pitch))
	target = _home.lerp(target, follow_share)
	if _focus_left > 0.0:
		var strength := smoothstep(0.0, _focus_duration, _focus_left)
		var impact := Vector3(_focus_position.x, _home.y, _focus_position.z)
		target = target.lerp(impact, strength * (0.5 if _final_focus else 0.15))
	target.x = clampf(target.x, -_arena_size.x * 0.12, _arena_size.x * 0.12)
	target.z = clampf(target.z, -_arena_size.y * 0.12, _arena_size.y * 0.12)
	# A pack spanning the whole park needs its full overview again.
	for attempt in 8:
		if _required_distance(points, target, aspect) <= maximum:
			break
		target = target.lerp(_home, 0.5)
	if _required_distance(points, target, aspect) > maximum:
		target = _home
	var minimum := maximum * closest_share
	if _focus_left > 0.0 and _final_focus:
		minimum *= 0.86
	return {"target": target, "distance": clampf(maxf(minimum, _required_distance(points, target, aspect)), 1.0, maximum)}


func _on_dog_eliminated(dog: Node, _toy: Node) -> void:
	if not dog is Node3D or not is_current():
		return
	var survivors := 0
	for candidate in get_tree().get_nodes_in_group("dogs"):
		if candidate is Dog and candidate.alive and not candidate.is_queued_for_deletion():
			survivors += 1
	_focus_position = dog.global_position
	_final_focus = survivors <= 1
	_focus_duration = 0.78 if _final_focus else 0.32
	_focus_left = _focus_duration
	Juice.elimination_slowmo(_final_focus)


func _on_round_started(_round: int) -> void:
	_focus_left = 0.0
	_final_focus = false
	_snap_next = true
	Juice.reset_time_effects()


func _on_viewport_changed() -> void:
	# Resize immediately instead of interpolating through cropped frames.
	_snap_next = true
