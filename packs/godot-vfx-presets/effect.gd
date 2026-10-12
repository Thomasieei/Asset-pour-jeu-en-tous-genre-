extends Node3D
@export_enum("Impact", "Fire", "Heal", "Portal", "Loot", "Magic") var effect_type := "Impact"
@export var autoplay := true
var emitters: Array[CPUParticles3D] = []
var ring: MeshInstance3D
var elapsed := 0.0
func _ready() -> void:
	var colors := {"Impact":Color("ffe1a3"),"Fire":Color("ff6b35"),"Heal":Color("61f6ad"),"Portal":Color("ab82ff"),"Loot":Color("ffe498"),"Magic":Color("74caff")}
	var tint: Color=colors[effect_type]
	var p := CPUParticles3D.new()
	p.amount=40
	p.lifetime=.65 if effect_type=="Impact" else 1.6
	p.one_shot=effect_type in ["Impact","Fire","Heal","Magic"]
	p.explosiveness=.9 if p.one_shot else 0
	p.emission_shape=CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius=.12 if effect_type=="Impact" else .45
	p.direction=Vector3.UP
	p.spread=180 if effect_type in ["Impact","Magic"] else 25
	p.initial_velocity_min=.3
	p.initial_velocity_max=2.2 if effect_type=="Impact" else 1.1
	p.gravity=Vector3(0,-.7,0) if effect_type=="Impact" else Vector3(0,.15,0)
	p.scale_amount_min=.08
	p.scale_amount_max=.24 if effect_type=="Fire" else .13
	var ramp := Gradient.new()
	ramp.set_color(0,tint)
	ramp.set_color(1,Color(tint.r,tint.g,tint.b,0))
	p.color_ramp=ramp
	var curve := Curve.new()
	curve.add_point(Vector2(0,.4))
	curve.add_point(Vector2(.25,1))
	curve.add_point(Vector2(1,0))
	p.scale_amount_curve=curve
	var quad := QuadMesh.new()
	quad.size=Vector2.ONE
	p.mesh=quad
	var mat := StandardMaterial3D.new()
	mat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode=BaseMaterial3D.BILLBOARD_ENABLED
	mat.vertex_color_use_as_albedo=true
	mat.albedo_texture=load("res://packs/kenney-particle-pack/PNG (Transparent)/spark_01.png")
	p.material_override=mat
	p.emitting=false
	add_child(p)
	emitters.append(p)
	if effect_type in ["Portal","Loot","Heal"]:
		ring=MeshInstance3D.new()
		var torus := TorusMesh.new()
		torus.inner_radius=.65
		torus.outer_radius=.7
		torus.rings=48
		torus.ring_segments=12
		ring.mesh=torus
		var material := StandardMaterial3D.new()
		material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
		material.albedo_color=tint
		material.emission_enabled=true
		material.emission=tint
		ring.material_override=material
		if effect_type=="Portal":
			ring.rotation_degrees.x=90
			ring.position.y=1
			p.position.y=1
		elif effect_type=="Loot": ring.scale=Vector3.ONE*.35
		add_child(ring)
	if autoplay: play()
func play() -> void:
	for emitter in emitters:
		emitter.restart()
		emitter.emitting=true
func _process(delta: float) -> void:
	elapsed+=delta
	if is_instance_valid(ring):
		ring.rotation.y+=delta*.3
		var s := .35 if effect_type=="Loot" else 1.0
		ring.scale=Vector3.ONE*s*(1+sin(elapsed*2)*.035)
