extends Node
## Autoload "Fx": pooled, lightweight visual effects (CPU particles + billboards, mobile friendly).

var world: Node3D
var _labels: Array[Label3D] = []
var _label_i := 0
var _sparks: Array[CPUParticles3D] = []
var _spark_i := 0
var _mats := {}


func attach(w: Node3D) -> void:
	world = w
	_labels.clear()
	_sparks.clear()
	for i in 28:
		var l := Label3D.new()
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		l.no_depth_test = true
		l.fixed_size = false
		l.pixel_size = 0.01
		l.font_size = 64
		l.outline_size = 16
		l.outline_modulate = Color(0.05, 0.02, 0.1)
		l.visible = false
		l.render_priority = 10
		l.outline_render_priority = 9
		world.add_child(l)
		_labels.append(l)
	for i in 8:
		var p := _make_burst("star_06", 10, 0.28, Color(1.0, 0.85, 0.5))
		world.add_child(p)
		_sparks.append(p)


func particle_material(tex_name: String, color: Color = Color.WHITE) -> StandardMaterial3D:
	var key := tex_name + color.to_html()
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	m.albedo_color = color
	m.albedo_texture = load("res://assets/vfx/%s.png" % tex_name)
	m.no_depth_test = false
	_mats[key] = m
	return m


func _make_burst(tex: String, amount: int, size: float, color: Color) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.emitting = false
	p.one_shot = true
	p.amount = amount
	p.lifetime = 0.45
	p.explosiveness = 1.0
	var q := QuadMesh.new()
	q.size = Vector2(size, size)
	q.material = particle_material(tex, color)
	p.mesh = q
	p.direction = Vector3.UP
	p.spread = 80.0
	p.initial_velocity_min = 2.5
	p.initial_velocity_max = 5.0
	p.gravity = Vector3(0, -6, 0)
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.3
	var curve := Curve.new()
	curve.add_point(Vector2(0, 1))
	curve.add_point(Vector2(1, 0))
	p.scale_amount_curve = curve
	p.local_coords = false
	return p


func damage_number(pos: Vector3, text: String, crit: bool = false, color: Color = Color(1, 1, 1)) -> void:
	if world == null or _labels.is_empty():
		return
	var l := _labels[_label_i]
	_label_i = (_label_i + 1) % _labels.size()
	l.text = text
	l.modulate = Color(1.0, 0.8, 0.15) if crit else color
	l.font_size = 88 if crit else 60
	l.global_position = pos + Vector3(randf_range(-0.4, 0.4), 0.0, randf_range(-0.4, 0.4))
	l.visible = true
	var tw := l.create_tween()
	tw.set_parallel(true)
	tw.tween_property(l, "global_position", l.global_position + Vector3(0, 1.4, 0), 0.75) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	l.modulate.a = 1.0
	tw.tween_property(l, "modulate:a", 0.0, 0.3).set_delay(0.45)
	tw.chain().tween_callback(func(): l.visible = false)


func spark(pos: Vector3) -> void:
	if _sparks.is_empty():
		return
	var p := _sparks[_spark_i]
	_spark_i = (_spark_i + 1) % _sparks.size()
	p.global_position = pos
	p.restart()


## Purple column + rising motes (extraction / summon).
func soul_pillar(pos: Vector3, success: bool = true, duration: float = 1.1) -> void:
	if world == null:
		return
	var root := Node3D.new()
	world.add_child(root)
	root.global_position = pos
	var col := Color(0.6, 0.35, 1.0) if success else Color(0.45, 0.45, 0.55)
	var beam := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.55
	cyl.bottom_radius = 0.9
	cyl.height = 6.0
	cyl.radial_segments = 12
	cyl.rings = 1
	cyl.cap_top = false
	cyl.cap_bottom = false
	var bm := StandardMaterial3D.new()
	bm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	bm.cull_mode = BaseMaterial3D.CULL_DISABLED
	bm.albedo_color = Color(col.r, col.g, col.b, 0.5)
	cyl.material = bm
	beam.mesh = cyl
	beam.position.y = 3.0
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(beam)
	var motes := CPUParticles3D.new()
	motes.amount = 26
	motes.lifetime = 0.9
	motes.one_shot = true
	motes.explosiveness = 0.3
	var q := QuadMesh.new()
	q.size = Vector2(0.45, 0.45)
	q.material = particle_material("magic_02", col)
	motes.mesh = q
	motes.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	motes.emission_sphere_radius = 0.9
	motes.direction = Vector3.UP
	motes.spread = 20.0
	motes.initial_velocity_min = 3.0
	motes.initial_velocity_max = 6.0
	motes.gravity = Vector3.ZERO
	motes.local_coords = false
	root.add_child(motes)
	motes.emitting = true
	beam.scale = Vector3(0.2, 1.0, 0.2)
	var tw := root.create_tween()
	tw.tween_property(beam, "scale", Vector3(1, 1, 1), 0.2)
	tw.tween_interval(maxf(duration - 0.55, 0.05))
	tw.tween_property(beam, "scale", Vector3(0.05, 1.3, 0.05), 0.35)
	tw.tween_interval(0.6)
	tw.tween_callback(root.queue_free)


## Small ring burst on the ground (summon / level-up).
func ring_burst(pos: Vector3, color: Color = Color(0.6, 0.35, 1.0)) -> void:
	if world == null:
		return
	var p := _make_burst("circle_05", 1, 0.5, color)
	p.direction = Vector3.ZERO
	p.spread = 0.0
	p.initial_velocity_min = 0.0
	p.initial_velocity_max = 0.0
	p.gravity = Vector3.ZERO
	p.lifetime = 0.5
	var c := Curve.new()
	c.add_point(Vector2(0, 0.2))
	c.add_point(Vector2(1, 1))
	p.scale_amount_curve = c
	p.scale_amount_min = 6.0
	p.scale_amount_max = 6.0
	world.add_child(p)
	p.global_position = pos + Vector3(0, 0.15, 0)
	p.emitting = true
	var t := get_tree().create_timer(1.0)
	t.timeout.connect(p.queue_free)
