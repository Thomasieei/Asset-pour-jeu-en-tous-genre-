extends RefCounted
class_name WorldAssets
# All repository models are discoverable; only requested scenes are loaded.
static var models: Array = []
static var loaded: Dictionary = {}

static func catalogue(query: String = "", limit: int = 30) -> Array:
	if models.is_empty():
		var file := FileAccess.open("res://catalog.json", FileAccess.READ)
		if file:
			var data = JSON.parse_string(file.get_as_text())
			if data is Dictionary:
				models = data.get("models", [])
	var results: Array = []
	for entry in models:
		if query.is_empty() or query.to_lower() in str(entry.get("path", "")).to_lower():
			results.append({"path":entry.path,"license":entry.get("license", ""),"pack":entry.get("pack", "")})
			if results.size() >= limit:
				break
	return results

static func instantiate_model(path: String, height: float = 0.0) -> Node3D:
	if not path.begins_with("res://packs/") or not ResourceLoader.exists(path):
		return null
	if not loaded.has(path):
		loaded[path] = load(path)
	if not loaded[path] is PackedScene:
		return null
	var model := Node3D.new()
	model.add_child(loaded[path].instantiate())
	if height > 0:
		var bounds := _bounds(model, Transform3D.IDENTITY)
		if bounds.size.y > 0.001:
			model.scale *= height / bounds.size.y
			model.position.y -= _bounds(model,Transform3D.IDENTITY).position.y
	return model

static func _bounds(node: Node3D, parent_transform: Transform3D) -> AABB:
	var transform := parent_transform * node.transform
	var result := AABB()
	if node is MeshInstance3D and node.mesh:
		result = transform * node.get_aabb()
	for child in node.get_children():
		if child is Node3D:
			var box := _bounds(child, transform)
			if box.size != Vector3.ZERO:
				result = box if result.size == Vector3.ZERO else result.merge(box)
	return result

static func settle_actor(model: Node3D, animator: AnimationPlayer, height: float) -> void:
	if animator and animator.has_animation("Idle"):
		animator.play("Idle")
		animator.advance(0)
	var tree := model.get_tree()
	for _frame in range(4):
		await tree.process_frame
		if not is_instance_valid(model) or not model.is_inside_tree(): return
	var bounds := _bounds(model,Transform3D.IDENTITY)
	if bounds.size.y>0.001: model.scale *= height/bounds.size.y
	model.position.y -= _bounds(model,Transform3D.IDENTITY).position.y
	var nodes: Array[Node] = [model]
	var lowest := INF
	while not nodes.is_empty():
		var node: Node = nodes.pop_back()
		if node is Skeleton3D:
			node.force_update_all_bone_transforms()
			for i in range(node.get_bone_count()):
				if str(node.get_bone_name(i)).to_lower() in ["toes.l","toes.r"]:
					var point: Vector3 = node.global_transform*node.get_bone_global_pose(i).origin
					point = model.get_parent().global_transform.affine_inverse()*point
					lowest = minf(lowest,point.y)
		for child in node.get_children(): nodes.append(child)
	if lowest<INF: model.position.y -= lowest-0.02
	model.set_meta("grounded_y",model.position.y)
	model.set_meta("pose_settled",true)
