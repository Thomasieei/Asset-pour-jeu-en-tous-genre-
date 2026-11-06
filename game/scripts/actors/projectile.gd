extends Node3D
## Homing magic bolt (used by ranged enemies and ranged shadows).

var _target: Actor
var _roll: Dictionary
var _source: Node3D
var _life: float = 3.0
var _speed: float = 13.0
var _color := Color(0.55, 1.0, 0.6)


func launch(t: Actor, roll: Dictionary, source: Node3D, color: Color = Color(0.55, 1.0, 0.6)) -> void:
	_target = t
	_roll = roll
	_source = source
	_color = color
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(0.9, 0.9)
	mi.mesh = q
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.albedo_texture = load("res://assets/vfx/light_01.png")
	m.albedo_color = _color
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	var trail := CPUParticles3D.new()
	trail.amount = 14
	trail.lifetime = 0.35
	var tq := QuadMesh.new()
	tq.size = Vector2(0.35, 0.35)
	tq.material = Fx.particle_material("magic_02", _color)
	trail.mesh = tq
	trail.gravity = Vector3.ZERO
	trail.initial_velocity_min = 0.2
	trail.initial_velocity_max = 0.6
	trail.local_coords = false
	add_child(trail)
	trail.emitting = true


func _physics_process(delta: float) -> void:
	_life -= delta
	if _life <= 0.0 or _target == null or not is_instance_valid(_target) or _target.dead:
		queue_free()
		return
	var goal := _target.global_position + Vector3(0, 1.1, 0)
	var to := goal - global_position
	if to.length() < 0.7:
		var src: Node3D = _source if is_instance_valid(_source) else null
		_target.take_damage(_roll["amount"], _roll["crit"], src)
		Fx.spark(goal)
		queue_free()
		return
	global_position += to.normalized() * minf(_speed * delta, to.length())
