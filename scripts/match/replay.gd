class_name Replay
extends Node3D
## The final-bonk replay. While a round is played this keeps the last few seconds and, when a
## knockout decides the round, plays them back slowly from close up.
##
## It is the round as it happened, not an approximation: every frame keeps where each dog and
## toy was (each toy's whole transform, so a toy in a mouth sits in that mouth), and every
## visible thing a dog's model was told to do - throw, catch, dash, wind up, bark, whack, wear a
## crown, go down - is recorded off DogModel.acted and played on the stand-in at the same
## moment. Hats and crowns are whatever they were at the start of the replay.
##
## Everything else on the field is mirrored as it was: every visible mesh, label, sprite and
## trail under the actors - shield bubbles, power-up halos, rings, name tags, charge meters,
## crates, mud, decoys - frame by frame, and every floating word and burst (Juice.spawned)
## made again at its moment.
##
## Stand-ins rather than the real dogs, so nothing in the match itself is rewound or disturbed.

signal finished

const KEEP_SECONDS := 3.0
## How much of the recording the replay shows, and how slowly.
const SHOW_SECONDS := 2.0
const SPEED := 0.4
## Played on past the knockout, so the knockdown lands on screen.
const AFTER_KNOCKOUT := 1.0
## Model calls that set how a dog looks until told otherwise, rather than play a moment. The
## latest of each before the replay starts is put on the stand-in before playback.
## Calls the round's result makes, which the replay leaves out.
const AFTER_RESULT: Array[StringName] = [&"set_crown", &"play_victory"]
const STATE_CALLS: Array[StringName] = [&"set_hat", &"set_crown", &"set_dashing", &"set_catching",
	&"set_dizzy", &"set_size_multiplier", &"set_charge"]

var _frames: Array[Dictionary] = []
## Every model call in the recording: {t, slot, method, args}, oldest first.
var _events: Array[Dictionary] = []
## Per slot, the latest state call of each kind that has aged out of the recording.
var _state_before: Dictionary = {}
var _knockouts: Array[Dictionary] = []
var _listening: Dictionary = {}
var _now := 0.0
## Juice's words and bursts: {t, kind, args}.
var _effects: Array[Dictionary] = []
var _next_effect := 0
## Instance id -> a bare copy of a mirrored node, taken when it was first seen.
var _templates: Dictionary = {}
## Instance id -> its copy in the replay, made the first time it is shown.
var _mirrors: Dictionary = {}
var _since_prune := 0
## Dog models that belong to no dog (decoys, ghosts): instance id -> the material laid over
## all of it, or null.
var _skins: Dictionary = {}

var _playing := false
var _clock := 0.0
var _start := 0.0
var _end := 0.0
var _next_event := 0
var _puppets: Dictionary = {}
var _toys: Dictionary = {}
var _camera: Camera3D
var _arena_camera: Camera3D
var _victim_spot := Vector3.ZERO
var _shot_spot := Vector3.ZERO
var _shot_width := 0.0
## Flat direction from the action to the replay camera.
var _side_on := Vector3.BACK
var _decided_at := INF
## This frame's slice of replay time, so the stand-ins turn and lean at the replay's pace.
var _step := 1.0 / 60.0


func _ready() -> void:
	Events.dog_eliminated.connect(_on_eliminated)
	Juice.spawned.connect(func(kind: StringName, args: Array) -> void:
		if not _playing and not _frames.is_empty():
			_effects.append({"t": _now, "kind": kind, "args": args}))


## Called every physics frame of play. [param root] is the node the actors live under.
func record(time: float, dogs: Array[Dog], toys: Array[Toy], root: Node = null) -> void:
	if _playing:
		return
	_now = time
	var dog_states: Array[Dictionary] = []
	for dog in dogs:
		if not is_instance_valid(dog):
			continue
		_listen(dog)
		var heading := -dog.model.global_transform.basis.z
		dog_states.append({"slot": dog.slot, "pos": dog.global_position, "facing": Vector3(heading.x, 0, heading.z).normalized(),
			"speed": dog.velocity.length() / maxf(dog.data.move_speed, 0.1), "alive": dog.alive,
			"shown": dog.model.is_visible_in_tree() and not dog.is_burrowed(), "meter": _meter_state(dog)})
	# Keyed by the toy itself: toys come and go mid-recording, so the n-th toy of one frame is
	# not the n-th of the next.
	var toy_states: Dictionary = {}
	for toy in toys:
		if is_instance_valid(toy) and is_instance_valid(toy.model):
			toy_states[toy.get_instance_id()] = {"data": toy.data, "xform": toy.model.global_transform,
				"shown": toy.model.is_visible_in_tree()}
	var visuals: Dictionary = {}
	var models: Dictionary = {}
	if root != null:
		_walk(root, visuals, models)
	_frames.append({"t": time, "dogs": dog_states, "toys": toy_states, "visuals": visuals, "models": models})
	while not _frames.is_empty() and time - float(_frames[0].t) > KEEP_SECONDS:
		_frames.pop_front()
	while not _events.is_empty() and time - float(_events[0].t) > KEEP_SECONDS:
		var old: Dictionary = _events.pop_front()
		if STATE_CALLS.has(old.method):
			if not _state_before.has(old.slot):
				_state_before[old.slot] = {}
			_state_before[old.slot][old.method] = old.args
	while not _knockouts.is_empty() and time - float(_knockouts[0].t) > KEEP_SECONDS:
		_knockouts.pop_front()
	while not _effects.is_empty() and time - float(_effects[0].t) > KEEP_SECONDS:
		_effects.pop_front()
	_since_prune += 1
	if _since_prune >= 180:
		_since_prune = 0
		_prune_templates()


## Everything visible under the actors, by instance id: where it is, whether it shows, and
## the little that changes on it (a label's words, a trail's emitting). Dog and toy models
## have their own stand-ins and charge meters are redrawn, so those are left to their owners;
## a dog model that belongs to no dog (a decoy) is kept as a model of its own.
func _walk(node: Node, visuals: Dictionary, models: Dictionary) -> void:
	for child in node.get_children():
		if child.has_meta(&"juice") or child is ToyModel or child is ChargeMeter:
			continue
		if child is DogModel:
			if not child.get_parent() is Dog:
				var model := child as DogModel
				var id := model.get_instance_id()
				if not _skins.has(id):
					# A ghost paints every surface with one see-through material; a decoy
					# paints nothing.
					var meshes := model.find_children("*", "MeshInstance3D", true, false)
					_skins[id] = (meshes[0] as MeshInstance3D).material_override if not meshes.is_empty() else null
				models[id] = {"data": model.data, "color": model.player_color,
					"xform": model.global_transform, "shown": model.is_visible_in_tree()}
			continue
		if child is GeometryInstance3D:
			var visual := child as GeometryInstance3D
			var id := visual.get_instance_id()
			if not _templates.has(id):
				_templates[id] = _bare_copy(visual)
			var state := {"xform": visual.global_transform, "shown": visual.is_visible_in_tree()}
			if visual is Label3D:
				state["text"] = (visual as Label3D).text
				state["tint"] = (visual as Label3D).modulate
			elif visual is SpriteBase3D:
				state["tint"] = (visual as SpriteBase3D).modulate
			elif visual is CPUParticles3D:
				state["emit"] = (visual as CPUParticles3D).emitting
			visuals[id] = state
		_walk(child, visuals, models)


## The node alone - no children (each is mirrored in its own right) and no script.
func _bare_copy(node: Node3D) -> Node3D:
	var copy := node.duplicate(0) as Node3D
	for child in copy.get_children():
		copy.remove_child(child)
		child.free()
	return copy


func _meter_state(dog: Dog) -> Dictionary:
	var meter := dog.get("_charge_meter") as ChargeMeter
	if meter == null or not meter.is_visible_in_tree():
		return {}
	return {"charge": maxf(meter._drawn, 0.0), "xform": meter.global_transform}


## Copies of nodes no longer in the recording are let go.
func _prune_templates() -> void:
	var live: Dictionary = {}
	for frame in _frames:
		for id in frame.visuals:
			live[id] = true
	for id in _templates.keys():
		if not live.has(id):
			(_templates[id] as Node).free()
			_templates.erase(id)


func _listen(dog: Dog) -> void:
	var id := dog.model.get_instance_id()
	if _listening.has(id):
		return
	_listening[id] = true
	var slot := dog.slot
	dog.model.acted.connect(func(method: StringName, args: Array) -> void:
		if not _playing:
			_events.append({"t": _now, "slot": slot, "method": method, "args": args}))


func clear() -> void:
	_effects.clear()
	for id in _templates:
		(_templates[id] as Node).free()
	_templates.clear()
	_skins.clear()
	_frames.clear()
	_events.clear()
	_state_before.clear()
	_knockouts.clear()
	_listening.clear()


func _on_eliminated(dog: Node, by: Node) -> void:
	if _playing or not dog is Dog or _frames.is_empty():
		return
	var victim := dog as Dog
	var toy := by as Toy
	var thrower: PlayerSlot = null
	if toy != null and is_instance_valid(toy.thrower) and toy.thrower is Dog:
		thrower = (toy.thrower as Dog).slot
	_knockouts.append({"t": _now, "slot": victim.slot, "pos": victim.global_position, "by": thrower})


## True when the last knockout is recent enough to be what decided the round.
func has_moment() -> bool:
	return not _knockouts.is_empty() and _frames.size() > 20


func is_playing() -> bool:
	return _playing


func play(arena_camera: Camera3D) -> void:
	var moment: Dictionary = _knockouts.back()
	_end = float(moment.t) + AFTER_KNOCKOUT
	_start = maxf(float(_frames[0].t), float(moment.t) - SHOW_SECONDS)
	_clock = _start
	_victim_spot = moment.pos
	_decided_at = float(moment.t)
	_arena_camera = arena_camera
	_playing = true
	# The whole replay runs in slow motion, so the stand-ins' own animation - the knockdown
	# above all - slows down with it instead of snapping past at full speed.
	Juice.reset_time_effects()
	Engine.time_scale = SPEED
	# Whoever threw it shares the shot with whoever it hit, so you see where it came from.
	_shot_spot = _victim_spot
	_shot_width = 0.0
	_side_on = Vector3.BACK
	var thrower: PlayerSlot = moment.by
	if thrower != null and thrower != moment.slot:
		for state in _frame_at(float(moment.t)).dogs:
			if state.slot == thrower:
				var from: Vector3 = state.pos
				_shot_spot = (from + _victim_spot) * 0.5
				_shot_width = from.distance_to(_victim_spot)
				var line := Vector3(_victim_spot.x - from.x, 0.0, _victim_spot.z - from.z)
				if line.length() > 0.5:
					_side_on = line.normalized().cross(Vector3.UP)
					if _side_on.z < 0.0:
						_side_on = -_side_on
					# Mostly side-on, a little toward the usual camera so the arena still reads.
					_side_on = _side_on.lerp(Vector3.BACK, 0.3).normalized()
	for state in _frames[0].dogs:
		_puppets[state.slot] = _make_puppet(state.slot)
	# How each dog looked going in: the state calls from before the replay, oldest first.
	for slot in _puppets:
		var model := _model_of(slot)
		var before: Dictionary = _state_before.get(slot, {})
		for method in before:
			model.callv(method, before[method])
	_next_effect = 0
	while _next_effect < _effects.size() and float(_effects[_next_effect].t) < _start:
		_next_effect += 1
	_next_event = 0
	while _next_event < _events.size() and float(_events[_next_event].t) < _start:
		var early: Dictionary = _events[_next_event]
		if STATE_CALLS.has(early.method) and _puppets.has(early.slot):
			_model_of(early.slot).callv(early.method, early.args)
		_next_event += 1
	for frame in _frames:
		if float(frame.t) < _start - 0.05:
			continue
		for id in frame.toys:
			if not _toys.has(id):
				var toy_model := ToyModel.new()
				toy_model.setup(frame.toys[id].data)
				toy_model.visible = false
				add_child(toy_model)
				_toys[id] = toy_model
	_camera = Camera3D.new()
	_camera.fov = 40.0
	add_child(_camera)
	_camera.make_current()
	_place_camera(0.0)
	_apply(_clock)


## A stand-in built the way Dog builds its own model, with a charge meter of its own (the real
## one's mesh is redrawn as it fills, so it cannot be mirrored). The ring, name tag and the
## rest of what hangs off the dog are mirrored.
func _make_puppet(slot: PlayerSlot) -> Node3D:
	var holder := Node3D.new()
	add_child(holder)
	var model := DogModel.new()
	holder.add_child(model)
	model.setup(slot.dog, slot.color)
	model.set_hat(Game.hat(slot.hat))
	var meter := ChargeMeter.new()
	meter.name = "Meter"
	holder.add_child(meter)
	meter.setup(slot.color, slot.dog.body_radius)
	return holder


func _model_of(slot: PlayerSlot) -> DogModel:
	return (_puppets[slot] as Node3D).get_child(0) as DogModel


## The recorded frame nearest [param time].
func _frame_at(time: float) -> Dictionary:
	for frame in _frames:
		if float(frame.t) >= time:
			return frame
	return _frames.back()


func skip() -> void:
	if _playing:
		_stop()


func _process(delta: float) -> void:
	if not _playing:
		return
	# Hold the slow motion: nothing else may speed the replay back up while it runs.
	Engine.time_scale = SPEED
	# delta is already slowed by the time scale.
	_step = minf(delta, 0.05 * SPEED)
	_clock += _step
	_apply(_clock)
	_place_camera((_clock - _start) / maxf(_end - _start, 0.01))
	if _clock >= _end:
		_stop()


## Starts wide enough to hold the thrower and the dog it hit, then pushes in on the knockout.
## The camera stands side-on to the throw (on the side nearer the game camera), so the two
## dogs sit left and right of the frame rather than one hiding behind the other.
func _place_camera(t: float) -> void:
	var push := smoothstep(0.45, 1.0, t)
	var focus := _shot_spot.lerp(_victim_spot, push)
	var wide := clampf(_shot_width * 0.85 + 5.5, 6.5, 13.0)
	var distance := lerpf(wide, 5.2, push)
	var side := _side_on.rotated(Vector3.UP, lerpf(-0.18, 0.18, t))
	var offset := side * distance + Vector3(0, distance * 0.5, 0)
	_camera.look_at_from_position(focus + offset, focus + Vector3(0, 0.5, 0), Vector3.UP)


func _apply(time: float) -> void:
	var b := 1
	while b < _frames.size() - 1 and float(_frames[b].t) < time:
		b += 1
	var a := b - 1
	var span := maxf(float(_frames[b].t) - float(_frames[a].t), 0.0001)
	var w := clampf((time - float(_frames[a].t)) / span, 0.0, 1.0)
	var fa: Dictionary = _frames[a]
	var fb: Dictionary = _frames[b]
	# Model calls due by now, in the order they happened.
	while _next_event < _events.size() and float(_events[_next_event].t) <= time:
		var event: Dictionary = _events[_next_event]
		_next_event += 1
		if not _puppets.has(event.slot):
			continue
		# The round is decided on the knockout's tick, and the crowns and victory poses that
		# follow land on that same tick: they belong to the result, not to the moment.
		if float(event.t) >= _decided_at and AFTER_RESULT.has(event.method):
			continue
		_model_of(event.slot).callv(event.method, event.args)
	# The words and bursts, made again where and when they were.
	while _next_effect < _effects.size() and float(_effects[_next_effect].t) <= time:
		var effect: Dictionary = _effects[_next_effect]
		_next_effect += 1
		var args: Array = effect.args.duplicate()
		args[0] = to_local(args[0])
		if effect.kind == &"float_text":
			Juice.float_text(self, args[0], args[1], args[2], args[3])
		else:
			Juice.burst(self, args[0], args[1], args[2], args[3])
	for i in mini(fa.dogs.size(), fb.dogs.size()):
		var sa: Dictionary = fa.dogs[i]
		var sb: Dictionary = fb.dogs[i]
		if not _puppets.has(sa.slot):
			continue
		var holder: Node3D = _puppets[sa.slot]
		var model := holder.get_child(0) as DogModel
		# Out before the replay starts: not part of this moment.
		var down_already := not bool(fa.dogs[i].alive) and not _knocked_in_window(sa.slot)
		holder.visible = bool(sa.shown) and not down_already
		holder.global_position = (sa.pos as Vector3).lerp(sb.pos, w)
		if bool(sa.alive):
			var facing: Vector3 = (sa.facing as Vector3).lerp(sb.facing, w)
			model.update_motion(facing if facing.length() > 0.01 else Vector3.FORWARD, lerpf(sa.speed, sb.speed, w), _step)
		var meter := holder.get_node("Meter") as ChargeMeter
		var gauge: Dictionary = sa.meter
		if gauge.is_empty():
			meter.hide_meter()
		else:
			meter.set_charge(float(gauge.charge), Vector3.FORWARD)
			meter.global_transform = gauge.xform
	_mirror(fa, fb, w)
	for id in _toys:
		var stand_in: ToyModel = _toys[id]
		if not fa.toys.has(id):
			stand_in.visible = false
			continue
		var from: Transform3D = fa.toys[id].xform
		var to: Transform3D = fb.toys[id].xform if fb.toys.has(id) else from
		stand_in.visible = bool(fa.toys[id].shown)
		stand_in.global_transform = from.interpolate_with(to, w)


## Everything else on the field, placed and shown as it was.
func _mirror(fa: Dictionary, fb: Dictionary, w: float) -> void:
	for id in _mirrors:
		(_mirrors[id] as Node3D).visible = false
	for id in fa.visuals:
		var state: Dictionary = fa.visuals[id]
		if not bool(state.shown) or not _templates.has(id):
			continue
		if not _mirrors.has(id):
			var copy := (_templates[id] as Node3D).duplicate(0) as Node3D
			add_child(copy)
			_mirrors[id] = copy
		var node: Node3D = _mirrors[id]
		var to: Transform3D = fb.visuals[id].xform if fb.visuals.has(id) else state.xform
		node.visible = true
		node.global_transform = (state.xform as Transform3D).interpolate_with(to, w)
		if node is Label3D:
			(node as Label3D).text = state.text
			(node as Label3D).modulate = state.tint
		elif node is SpriteBase3D:
			(node as SpriteBase3D).modulate = state.tint
		elif node is CPUParticles3D:
			(node as CPUParticles3D).emitting = state.emit
	for id in fa.models:
		var look: Dictionary = fa.models[id]
		if not _mirrors.has(id):
			var model := DogModel.new()
			add_child(model)
			model.setup(look.data, look.color)
			var skin: Material = _skins.get(id)
			if skin != null:
				for mesh in model.find_children("*", "MeshInstance3D", true, false):
					(mesh as MeshInstance3D).material_override = skin
					(mesh as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			_mirrors[id] = model
		var stand_in: Node3D = _mirrors[id]
		stand_in.visible = bool(look.shown)
		stand_in.global_transform = look.xform


func _knocked_in_window(slot: PlayerSlot) -> bool:
	for knock in _knockouts:
		if knock.slot == slot and float(knock.t) >= _start:
			return true
	return false


func _stop() -> void:
	_playing = false
	Engine.time_scale = 1.0
	for child in get_children():
		child.queue_free()
	_puppets.clear()
	_toys.clear()
	_mirrors.clear()
	if is_instance_valid(_arena_camera):
		_arena_camera.make_current()
	finished.emit()
