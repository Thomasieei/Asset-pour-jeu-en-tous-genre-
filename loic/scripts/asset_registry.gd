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
	var model: Node3D = loaded[path].instantiate()
	if height > 0:
		var bounds := _bounds(model, Transform3D.IDENTITY)
		if bounds.size.y > 0.001:
			model.scale *= height / bounds.size.y
			model.position.y -= bounds.position.y * model.scale.y
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
