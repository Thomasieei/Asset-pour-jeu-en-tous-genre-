extends RefCounted
class_name WorldEyes
# Bounded geometric perception, nearest objects first, with occlusion.
static func observe(observer: Node3D, radius: float = 18.0) -> Dictionary:
	var candidates: Array = []
	for entity in observer.get_tree().get_nodes_in_group("world_observable"):
		if entity == observer or not entity is Node3D or not entity.is_visible_in_tree(): continue
		var distance: float = observer.global_position.distance_to(entity.global_position)
		if distance <= radius: candidates.append({"entity":entity,"distance":distance})
	candidates.sort_custom(func(a: Dictionary,b: Dictionary): return a.distance<b.distance)
	var seen: Array = []
	for candidate in candidates:
		var entity: Node3D = candidate.entity
		if not has_line_of_sight(observer,entity): continue
		seen.append({"id":str(entity.get_meta("world_id",entity.name)),"type":str(entity.get_meta("kind","habitant")),"distance":snappedf(candidate.distance,0.1),"position":[entity.global_position.x,entity.global_position.z]})
		if seen.size()>=24: break
	return {"position":[observer.global_position.x,observer.global_position.z],"rayon":radius,"visibles":seen}

static func has_line_of_sight(observer: Node3D, target: Node3D) -> bool:
	var ray := PhysicsRayQueryParameters3D.create(observer.global_position+Vector3.UP*1.5,target.global_position+Vector3.UP*1.2,1)
	var hit := observer.get_world_3d().direct_space_state.intersect_ray(ray)
	return hit.is_empty() or target.is_ancestor_of(hit.collider)
