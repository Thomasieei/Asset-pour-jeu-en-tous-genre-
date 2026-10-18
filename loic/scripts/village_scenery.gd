extends Node3D
class_name VillageScenery
# Composition of the approved concept: village left, creek and bridge ahead,
# forest right, distant castle. All repeated vegetation uses MultiMesh.
const MEDIEVAL := "res://packs/kaykit-medieval-hexagon-pack-1.0/addons/kaykit_medieval_hexagon_pack/Assets/gltf/"
const FOREST := "res://packs/kaykit-forest-free/Assets/gltf/"
const NATURE := "res://packs/nature-kit/Models/GLTF format/"
const BUILDINGS := ["home_A","home_B","tavern","watermill","tower_A","market","well"]
const FOLIAGE := ["tree_pineTallA_detailed","tree_oak","plant_bushDetailed","rock_largeA","grass_large"]
var obstacles: Array[Vector3] = []
var water: MeshInstance3D
var deer: Node3D
var deer_clock := 0.0
var cache: Dictionary = {}

static func river_z(x: float) -> float:
	return -8.0 + sin(x*0.085)*3.0

static func raw_height(x: float, z: float) -> float:
	var y := 12.0*(1-smoothstep(17,48,Vector2((x-5)/1.1,z+110).length()))
	y += smoothstep(95,180,Vector2(x,z).length())*sin(x*0.013)*cos(z*0.012)*3
	if absf(x)<128:
		var width := 2.9*clampf((128-absf(x))/16,0,1)
		if width>0.01: y -= 0.85*(1-smoothstep(width-0.8,width+1.4,absf(z-river_z(x))))
	return y

static func ground_height(x: float, z: float) -> float:
	var gx := floorf(x/2)*2
	var gz := floorf(z/2)*2
	var u := (x-gx)/2
	var v := (z-gz)/2
	var a := raw_height(gx,gz)
	var b := raw_height(gx+2,gz)
	var c := raw_height(gx,gz+2)
	if u+v<=1: return a+(b-a)*u+(c-a)*v
	var d := raw_height(gx+2,gz+2)
	return d+(c-d)*(1-u)+(b-d)*(1-v)

static func walk_height(x: float,z: float) -> float:
	if absf(x+2)<1.65 and z>=-12.3 and z<=-3.1: return 0.025
	return ground_height(x,z)

static func make_ground(origin: Vector2, span: float) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for ix in range(int(span/2)):
		for iz in range(int(span/2)):
			var x := origin.x+ix*2
			var z := origin.y+iz*2
			for p in [Vector2(x,z),Vector2(x+2,z),Vector2(x,z+2),Vector2(x+2,z),Vector2(x+2,z+2),Vector2(x,z+2)]:
				surface.add_vertex(Vector3(p.x-origin.x,raw_height(p.x,p.y),p.y-origin.y))
	surface.generate_normals()
	return surface.commit()

func _ready() -> void:
	name = "Village_de_la_maquette"
	_terrain()
	_paths()
	_buildings()
	_bridge()
	_vegetation()
	_horizon()
	_moussecorne()

func _material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.95
	return mat

func _terrain() -> void:
	var stream := SurfaceTool.new()
	stream.begin(Mesh.PRIMITIVE_TRIANGLES)
	for x in range(-128,128,2):
		for p in [Vector2(x,-2.9),Vector2(x,2.9),Vector2(x+2,-2.9),Vector2(x+2,-2.9),Vector2(x,2.9),Vector2(x+2,2.9)]:
			stream.add_vertex(Vector3(p.x,-0.28,river_z(p.x)+p.y))
	stream.generate_normals()
	water = MeshInstance3D.new()
	water.mesh = stream.commit()
	var water_mat := ShaderMaterial.new()
	water_mat.shader = load("res://loic/shaders/river.gdshader")
	water.material_override = water_mat
	add_child(water)

func _strip(points: Array[Vector3], width: float) -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(points.size()-1):
		var a := points[i]
		var b := points[i+1]
		var side := (b-a).cross(Vector3.UP).normalized()*width*0.5
		for p in [a-side,b-side,a+side,a+side,b-side,b+side]:
			surface.add_vertex(Vector3(p.x,ground_height(p.x,p.z)+0.018,p.z))
	surface.generate_normals()
	var road := MeshInstance3D.new()
	road.mesh = surface.commit()
	road.material_override = _material(Color(0.44,0.30,0.16))
	add_child(road)

func _paths() -> void:
	_strip([Vector3(2,0,18),Vector3(2,0,5),Vector3(-2,0,-3.6)],3.3)
	_strip([Vector3(-2,0,-12.2),Vector3(-4,0,-18),Vector3(-17,0,-27),Vector3(-35,0,-38)],3.8)
	_strip([Vector3(1,0,4),Vector3(11,0,0),Vector3(26,0,-1),Vector3(42,0,8)],2.1)

func _place(path: String, height: float, point: Vector3, yaw: float = 0) -> Node3D:
	var model := WorldAssets.instantiate_model(path,height)
	if not model: return null
	if path.begins_with(NATURE): _natural_palette(model,path)
	if path.begins_with(MEDIEVAL): _warm_roofs(model)
	if "packs/castle-kit/" in path: _stone_palette(model)
	model.position.y -= WorldAssets._bounds(model,Transform3D.IDENTITY).position.y
	point.y = ground_height(point.x,point.z)
	model.position += point
	model.rotation.y = yaw
	add_child(model)
	return model

func _stone_palette(node: Node3D) -> void:
	if node is MeshInstance3D: node.material_override = _material(Color(0.40,0.39,0.34))
	for child in node.get_children():
		if child is Node3D: _stone_palette(child)

func _warm_roofs(node: Node3D) -> void:
	if node is MeshInstance3D and node.mesh:
		for i in range(node.mesh.get_surface_count()):
			var source: Material = node.get_active_material(i)
			if source is StandardMaterial3D and source.albedo_texture:
				var material := ShaderMaterial.new()
				material.shader = load("res://loic/shaders/village_roofs.gdshader")
				material.set_shader_parameter("albedo",source.albedo_texture)
				node.set_surface_override_material(i,material)
	for child in node.get_children():
		if child is Node3D: _warm_roofs(child)

func _natural_palette(node: Node3D, path: String) -> void:
	if node is MeshInstance3D and node.mesh:
		for i in range(node.mesh.get_surface_count()):
			var source: Material = node.get_active_material(i)
			if source is StandardMaterial3D:
				var mat: StandardMaterial3D = source.duplicate()
				mat.metallic = 0
				mat.roughness = 0.95
				mat.vertex_color_use_as_albedo = true
				var label := str(source.resource_name).to_lower()
				if "leaf" in label: mat.albedo_color = Color(0.22,0.32,0.08)
				elif "grass" in label: mat.albedo_color = Color(0.27,0.34,0.08)
				elif "wood" in label or "trunk" in label: mat.albedo_color = Color(0.32,0.20,0.10)
				elif "rock" in path: mat.albedo_color = Color(0.33,0.35,0.32)
				elif "dirt" in label: mat.albedo_color = Color(0.34,0.23,0.13)
				node.set_surface_override_material(i,mat)
	for child in node.get_children():
		if child is Node3D: _natural_palette(child,path)
	if node.get_parent() == null and "rock" in path:
		var bounds := WorldAssets._bounds(node,Transform3D.IDENTITY)
		var width := maxf(bounds.size.x,bounds.size.z)
		if width>3: node.scale *= 3.0/width

func _house(kind: String, height: float, point: Vector3, yaw: float = 0) -> void:
	var model := _place(MEDIEVAL+"buildings/yellow/building_"+kind+"_yellow.gltf",height,point,yaw)
	if model: _foundation(model)
	obstacles.append(Vector3(point.x,height*0.28,point.z))

func _buildings() -> void:
	_house("watermill",7.5,Vector3(-15,0,-13),0.35)
	_house("tower_A",9,Vector3(-29,0,-22))
	_house("home_A",6.5,Vector3(-12,0,-23),0.45)
	_house("home_B",7.5,Vector3(-21,0,-30),0.1)
	_house("tavern",8.0,Vector3(-6,0,-34),0.25)
	_house("home_A",6.0,Vector3(-32,0,-32),-0.2)
	_house("home_B",5.8,Vector3(-24,0,-42),0.4)
	_house("home_A",5.5,Vector3(-39,0,-46),0.1)
	_house("market",4,Vector3(-9,0,-17))
	_house("well",1.8,Vector3(-3,0,-23))
	# Architecture has space around the approach, rather than random scatter.
	for i in range(7):
		_place(MEDIEVAL+"buildings/neutral/fence_wood_straight.gltf",0.75,Vector3(-19+i*2.0,0,-3.5))

func _bridge() -> void:
	# Individual stone arch blocks follow the reference silhouette. The walkable
	# deck stays at ground height so characters do not float above the bridge.
	for side in [-1,1]:
		for i in range(13):
			var t := float(i)/12
			var z := -12.3+t*9.2
			var arch := sin(t*PI)*0.65
			var stone := MeshInstance3D.new()
			var box := BoxMesh.new()
			box.size = Vector3(0.48,0.9,0.8)
			stone.mesh = box
			stone.position = Vector3(-2+side*1.85,0.25+arch,z)
			stone.material_override = _material(Color(0.51+float(i%3)*0.025,0.51+float(i%3)*0.025,0.45))
			add_child(stone)
	var deck := MeshInstance3D.new()
	var slab := BoxMesh.new()
	slab.size = Vector3(3.6,0.45,9.2)
	deck.mesh = slab
	deck.position = Vector3(-2,-0.2,-7.7)
	deck.material_override = _material(Color(0.50,0.48,0.39))
	add_child(deck)

func _parts(node: Node3D, parent: Transform3D, out: Array) -> void:
	var transform := parent*node.transform
	if node is MeshInstance3D and node.mesh:
		var mesh: Mesh = node.mesh.duplicate()
		for i in range(mesh.get_surface_count()): mesh.surface_set_material(i,node.get_active_material(i))
		out.append({"mesh":mesh,"transform":transform})
	for child in node.get_children():
		if child is Node3D: _parts(child,transform,out)

func _batch(path: String, height: float, placements: Array[Transform3D]) -> void:
	if placements.is_empty(): return
	if not cache.has(path):
		var proto := WorldAssets.instantiate_model(path,height)
		var parts: Array = []
		if proto:
			if path.begins_with(NATURE): _natural_palette(proto,path)
			_parts(proto,Transform3D.IDENTITY,parts)
			proto.free()
		cache[path] = parts
	for part in cache[path]:
		var batch := MultiMeshInstance3D.new()
		var multi := MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_3D
		multi.mesh = part.mesh
		multi.use_colors = true
		multi.instance_count = placements.size()
		for i in range(placements.size()):
			multi.set_instance_transform(i,placements[i]*part.transform)
			var tint := 0.8+float(i%11)*0.025
			multi.set_instance_color(i,Color(tint,tint,tint))
		batch.multimesh = multi
		batch.visibility_range_end = 155
		add_child(batch)

func _vegetation() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 87021
	for kind in range(5):
		var placements: Array[Transform3D] = []
		for i in range([90,65,95,85,2200][kind]):
			var x := rng.randf_range(-65,80)
			var z := rng.randf_range(-90,35)
			if ground_height(x,z)<-0.01: continue
			if absf(x-2)<3.8 and z>-4: continue
			if absf(x+2)<4 and z>-17 and z<-3: continue
			if x<-4 and x>-40 and z<-12 and z>-45: continue
			if Vector2(x-5,z).length()<6: continue
			if kind<2 and Vector2(x-20,z+30).length()<9: continue
			if kind<2 and x<15 and z>-38: continue
			if kind<2 and x>10 and x<25 and z>-8: continue
			var scale_ := rng.randf_range(0.75,1.5)
			placements.append(Transform3D(Basis(Vector3.UP,rng.randf_range(0,TAU)).scaled(Vector3.ONE*scale_),Vector3(x,ground_height(x,z),z)))
		_batch(NATURE+FOLIAGE[kind]+".glb",[9.0,8.0,0.8,1.4,0.35][kind],placements)
	for flower in ["flower_yellowA","flower_purpleA"]:
		var placements: Array[Transform3D] = []
		for i in range(130):
			var x := rng.randf_range(-8,22)
			var z := rng.randf_range(-3,14)
			if absf(x-2)<2.2: continue
			placements.append(Transform3D(Basis(Vector3.UP,rng.randf_range(0,TAU)),Vector3(x,ground_height(x,z),z)))
		_batch(NATURE+flower+".glb",0.32,placements)
	# Foreground trees frame the screen without hiding the character.
	_place(NATURE+FOLIAGE[0]+".glb",13,Vector3(-12,0,5))
	_place(NATURE+FOLIAGE[1]+".glb",14,Vector3(18,0,3))
	_place(NATURE+FOLIAGE[3]+".glb",2.2,Vector3(10,0,-1))

func _horizon() -> void:
	for x in [-5.0,15.0]:
		for z in [-100.0,-120.0]:
			var model := _place("res://packs/castle-kit/Models/GLB format/tower-square.glb",10,Vector3(x,0,z))
			if model: _foundation(model)
	for x in [0.0,5.0,10.0]:
		var model := _place("res://packs/castle-kit/Models/GLB format/wall.glb",4.5,Vector3(x,0,-100))
		if model: _foundation(model)

func _foundation(model: Node3D) -> void:
	var bounds := WorldAssets._bounds(model,Transform3D.IDENTITY)
	var top := bounds.position.y
	var bottom := top
	for x in [bounds.position.x,bounds.end.x]:
		for z in [bounds.position.z,bounds.end.z]:
			top = maxf(top,ground_height(x,z))
			bottom = minf(bottom,ground_height(x,z))
	model.position.y += top-bounds.position.y
	if top-bottom>0.04:
		var foundation := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(bounds.size.x,top-bottom+0.1,bounds.size.z)
		foundation.mesh = box
		foundation.position = Vector3(bounds.get_center().x,top-box.size.y/2,bounds.get_center().z)
		foundation.material_override = _material(Color(0.33,0.34,0.29))
		add_child(foundation)

func _shape(parent: Node3D, mesh: Mesh, color: Color, point: Vector3, scale_: Vector3) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	part.mesh = mesh
	part.material_override = _material(color)
	part.position = point
	part.scale = scale_
	parent.add_child(part)
	return part

func _branch(parent: Node3D, a: Vector3, b: Vector3, radius: float, color: Color) -> void:
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = radius*0.65
	cylinder.bottom_radius = radius
	cylinder.height = a.distance_to(b)
	cylinder.radial_segments = 6
	var branch := _shape(parent,cylinder,color,(a+b)/2,Vector3.ONE)
	var axis := (b-a).normalized()
	branch.quaternion = Quaternion(Vector3.UP,axis)

func _moussecorne() -> void:
	deer = Node3D.new()
	deer.name = "Moussecorne"
	deer.position = Vector3(8.5,0,-0.5)
	deer.rotation.y = 2.3
	deer.set_meta("world_id","Moussecorne")
	deer.set_meta("kind","creature_de_la_foret")
	deer.add_to_group("world_observable")
	add_child(deer)
	var sphere := SphereMesh.new()
	sphere.radial_segments = 10
	sphere.rings = 5
	var fur := Color(0.67,0.52,0.30)
	_shape(deer,sphere,fur,Vector3(0,1.05,0),Vector3(0.58,0.62,1.05))
	_shape(deer,sphere,fur,Vector3(0,1.52,-0.56),Vector3(0.34,0.80,0.36))
	_shape(deer,sphere,fur,Vector3(0,1.97,-0.79),Vector3(0.38,0.39,0.59))
	_shape(deer,sphere,Color(0.12,0.16,0.12),Vector3(0,1.96,-1.08),Vector3(0.16,0.13,0.12))
	for side in [-1,1]:
		_shape(deer,sphere,Color(0.03,0.045,0.025),Vector3(side*0.16,2.05,-0.87),Vector3.ONE*0.065)
		_shape(deer,sphere,fur,Vector3(side*0.27,2.14,-0.69),Vector3(0.35,0.12,0.14))
		for z in [-0.45,0.45]:
			_branch(deer,Vector3(side*0.22,0.14,z),Vector3(side*0.22,1,z),0.065,fur)
		var base := Vector3(side*0.16,2.1,-0.7)
		var tip := Vector3(side*0.6,2.8,-0.5)
		_branch(deer,base,tip,0.055,Color(0.75,0.65,0.38))
		for i in range(3):
			var a := base.lerp(tip,0.3+i*0.22)
			var b := a+Vector3(side*0.12,0.22,-0.22)
			_branch(deer,a,b,0.028,Color(0.75,0.65,0.38))
			_shape(deer,sphere,Color(0.39,0.58,0.17),b,Vector3(0.14,0.09,0.22))
	var label := Label3D.new()
	label.text = "Moussecorne"
	label.position.y = 3.05
	label.font_size = 30
	label.pixel_size = 0.008
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	deer.add_child(label)

func constrain_step(origin: Vector3, next: Vector3) -> Vector3:
	if absf(next.x)<128 and absf(next.z)<128:
		if ground_height(next.x,next.z)<-0.15 and absf(next.x+2)>1.5: return origin
	for obstacle in obstacles:
		var offset := Vector2(next.x-obstacle.x,next.z-obstacle.z)
		if offset.length()<obstacle.y+0.3:
			var old := Vector2(origin.x-obstacle.x,origin.z-obstacle.z)
			if offset.length()<old.length(): return origin
	return next

func _process(delta: float) -> void:
	deer_clock += delta
	if deer: deer.rotation.y = 2.3+sin(deer_clock*0.35)*0.12
