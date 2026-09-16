class_name DogAssetValidator
extends RefCounted
## One asset contract shared by runtime, reference studio and the command-line audit.
## Technical readiness is separate from human review of the reference likeness.

const STATES := ["idle", "run", "throw", "catch", "dash", "ko", "win"]


static func load_model_scene(data: DogData) -> PackedScene:
	if data.model_scene != null:
		return data.model_scene
	if not data.model_scene_path.is_empty() and ResourceLoader.exists(data.model_scene_path):
		return load(data.model_scene_path) as PackedScene
	return null


static func inspect(data: DogData, instance: Node = null) -> Dictionary:
	var report := {"valid": false, "likeness_reviewed": data.likeness_reviewed,
		"errors": PackedStringArray(), "warnings": PackedStringArray(),
		"bones": 0, "meshes": 0, "skinned_meshes": 0, "animations": PackedStringArray()}
	var own_instance := instance == null
	if own_instance:
		var scene := load_model_scene(data)
		if scene == null:
			report.errors.append("No authored model. Deliver %s and import it in Godot." % (
				data.model_scene_path if not data.model_scene_path.is_empty() else "a skinned GLB; assign DogData.model_scene"))
			return report
		instance = scene.instantiate()
	if not instance is Node3D:
		report.errors.append("Model scene root must be Node3D.")
	if data.model_import_scale <= 0.0 or data.model_scale <= 0.0:
		report.errors.append("Model scale must be positive. Apply transforms in the source file.")
	var skeletons := find_skeletons(instance)
	for skeleton in skeletons:
		report.bones += skeleton.get_bone_count()
	if report.bones == 0:
		report.errors.append("No Skeleton3D bones. Export the armature and weighted mesh together.")
	for node in all_nodes(instance):
		if node is MeshInstance3D and node.mesh != null:
			report.meshes += 1
			if node.skin != null and node.get_node_or_null(node.skeleton) is Skeleton3D:
				report.skinned_meshes += 1
	if report.skinned_meshes == 0:
		report.errors.append("No skinned mesh bound to a Skeleton3D. Bind and export deform weights.")
	var socket := find_socket(instance, data)
	if socket == null and find_socket_skeleton(instance, data) == null:
		report.errors.append("No rig-bound mouth socket. Export bone '%s' or put a MouthSocket Marker3D under a valid BoneAttachment3D." % data.mouth_socket_bone)
	var player := find_animation_player(instance, data)
	if player == null:
		report.errors.append("No AnimationPlayer. Export the seven named action clips.")
	else:
		report.animations = player.get_animation_list()
		for state in STATES:
			var clip := StringName(data.model_animations.get(state, state))
			if clip == &"" or not player.has_animation(clip):
				report.errors.append("Missing '%s' animation '%s'. Export it or update DogData.model_animations." % [state, clip])
			elif player.get_animation(clip).get_track_count() == 0:
				report.errors.append("Animation '%s' has no tracks. Bake the rig's action before export." % clip)
	if not data.likeness_reviewed:
		report.warnings.append("Likeness not reviewed: compare front, side, back and gameplay views against the original sheet.")
	report.valid = report.errors.is_empty()
	if own_instance:
		instance.free()
	return report


static func all_nodes(root: Node) -> Array[Node]:
	var result: Array[Node] = [root]
	for child in root.get_children():
		result.append_array(all_nodes(child))
	return result


static func find_skeletons(root: Node) -> Array[Skeleton3D]:
	var result: Array[Skeleton3D] = []
	for node in all_nodes(root):
		if node is Skeleton3D:
			result.append(node)
	return result


static func find_socket_skeleton(root: Node, data: DogData) -> Skeleton3D:
	for skeleton in find_skeletons(root):
		if skeleton.find_bone(data.mouth_socket_bone) >= 0:
			return skeleton
	return null


static func find_socket(root: Node, data: DogData) -> Node3D:
	var candidates: Array[Node] = []
	if not data.mouth_socket_path.is_empty():
		var configured := root.get_node_or_null(data.mouth_socket_path)
		if configured != null:
			candidates.append(configured)
	else:
		for node in all_nodes(root):
			if node.name == &"MouthSocket":
				candidates.append(node)
	for socket in candidates:
		if not socket is Node3D:
			continue
		var ancestor: Node = socket
		while ancestor != null and ancestor != root.get_parent():
			if ancestor is BoneAttachment3D:
				var attachment := ancestor as BoneAttachment3D
				var skeleton := attachment.get_parent() as Skeleton3D
				if attachment.use_external_skeleton:
					skeleton = attachment.get_node_or_null(attachment.external_skeleton) as Skeleton3D
				if skeleton != null and skeleton.find_bone(ancestor.bone_name) >= 0:
					return socket
			ancestor = ancestor.get_parent()
	return null


static func find_animation_player(root: Node, data: DogData) -> AnimationPlayer:
	var best: AnimationPlayer
	var best_score := -1
	for node in all_nodes(root):
		if not node is AnimationPlayer:
			continue
		var score := 0
		for state in STATES:
			if node.has_animation(StringName(data.model_animations.get(state, state))):
				score += 1
		if score > best_score:
			best = node
			best_score = score
	return best
