extends RefCounted
class_name WorldEyes
# Geometric perception from the live scene, with occlusion. No invented pixel vision.
static func observe(observer: Node3D, radius: float = 18.0) -> Dictionary:
	var seen: Array = []
	var origin := observer.global_position + Vector3.UP * 1.5
	for entity in observer.get_tree().get_nodes_in_group("world_observable"):
		if entity == observer or not entity is Node3D:
			continue
		if not entity.is_visible_in_tree():
			continue
		var distance: float = observer.global_position.distance_to(entity.global_position)
		if distance > radius:
			continue
		var target: Vector3 = entity.global_position + Vector3.UP
		var ray := PhysicsRayQueryParameters3D.create(origin, target, 1)
		var hit := observer.get_world_3d().direct_space_state.intersect_ray(ray)
		if not hit.is_empty() and not entity.is_ancestor_of(hit.collider):
			continue
		seen.append({"id":str(entity.get_meta("world_id",entity.name)),"type":str(entity.get_meta("kind","habitant")),"distance":snappedf(distance,0.1),"position":[entity.global_position.x,entity.global_position.z]})
	return {"position":[observer.global_position.x,observer.global_position.z],"rayon":radius,"visibles":seen}
