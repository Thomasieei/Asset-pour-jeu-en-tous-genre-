extends Node3D
class_name CombatEffect
var age := 0.0
var reach := 1.0
var mesh_node: MeshInstance3D
var material: StandardMaterial3D
static func spawn(parent: Node, point: Vector3, size_: float) -> void:
	var effect := CombatEffect.new()
	effect.position = point
	effect.reach = size_
	parent.add_child(effect)
func _ready() -> void:
	add_to_group("combat_effect")
	mesh_node = MeshInstance3D.new()
	var ring := TorusMesh.new()
	ring.inner_radius = 0.92
	ring.outer_radius = 1.0
	ring.rings = 32
	ring.ring_segments = 6
	mesh_node.mesh = ring
	material = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(0.4,0.8,1,0.9)
	mesh_node.material_override = material
	add_child(mesh_node)
func _process(delta: float) -> void:
	age += delta
	mesh_node.scale = Vector3.ONE*lerpf(0.2,reach,minf(1,age/0.45))
	material.albedo_color.a = 1-age/0.55
	if age>0.55: queue_free()
