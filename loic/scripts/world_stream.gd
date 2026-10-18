extends Node3D
class_name WorldStream
const EXTENT := 1000.0
const CHUNK := 64.0
const RADIUS := 1
const MAX_CREATURES := 6
const SAVE := "user://realm_state.json"
const LANDMARKS := [
	{"name":"Village d'Aurore","position":[0,0],"kind":"village"},
	{"name":"Lisière des Murmures","position":[80,45],"kind":"forest"},
	{"name":"Tour des Veilleurs","position":[240,-160],"kind":"tower"},
	{"name":"Camp des Exilés","position":[-320,220],"kind":"camp"},
	{"name":"Clairière d'Émeraude","position":[700,300],"kind":"forest"},
	{"name":"Crête des Cendres","position":[-740,-600],"kind":"rocks"}
]
var host: Node3D
var avatar: PlayerAvatar
var chunks: Dictionary = {}
var pending_chunks: Array[Vector2i] = []
var desired: Dictionary = {}
var center := Vector2i(9999,9999)
var creatures: Dictionary = {}
var records: Array = []
var geometry: Dictionary = {}
var refresh_clock := 0.0
var save_clock := 0.0
var last_thought := -30000
var visited: Array = ["Village d'Aurore"]

func _ready() -> void:
	avatar = host.avatar
	var saved := StateStore.read_json(SAVE)
	records = saved.get("creatures",[])
	visited = saved.get("visited",visited)
	if records.is_empty(): _seed_creatures()
	update_focus(true)

func _seed_creatures() -> void:
	var names := ["Silex","Nacre","Vark","Brume","Orme","Morne","Braise","Kora","Écho","Ronce","Ambre","Noctis","Aube","Givre","Rune","Cendre","Opale","Fauve","Lichen","Vesper","Talis","Dune","Fulgur","Sylve","Thorn","Iris","Kael","Sora","Onyx","Astre","Perle","Ocre"]
	var personalities := ["curieux et solitaire","prudent, aime les conversations et déteste les combats","territorial, fier, avertit les étrangers","rêveur et méfiant"]
	var rng := RandomNumberGenerator.new()
	rng.seed = 41983
	for i in range(names.size()):
		var point := Vector2(rng.randf_range(-920,920),rng.randf_range(-920,920))
		if i<6: point = Vector2([86,-88,112,-110,65,-72][i],[45,30,-55,-70,-80,90][i])
		elif i<12:
			var landmark: Dictionary = LANDMARKS[(i-6)%5+1]
			point = Vector2(landmark.position[0],landmark.position[1])+Vector2(12+float(i-6)*3.5,9+float(i%3)*4)
		records.append({"id":i,"name":names[i],"model":["Skeleton_Rogue","Skeleton_Mage","Skeleton_Warrior","Skeleton_Minion"][i%4],"personality":personalities[i%4],"home":[point.x,point.y],"position":[point.x,point.y],"health":65.0,"hunger":float(i%4)*10,"trust":0.0,"aggression":0.75 if i%4==2 else 0.3,"memories":[]})
	save_state()

func _process(delta: float) -> void:
	refresh_clock += delta
	save_clock += delta
	if refresh_clock>0.8:
		refresh_clock = 0
		update_focus()
	if not pending_chunks.is_empty():
		var key: Vector2i = pending_chunks.pop_front()
		if desired.has(key) and not chunks.has(key): _create_chunk(key)
	if save_clock>15:
		save_clock = 0
		save_state()

func update_focus(force: bool = false) -> void:
	var next := Vector2i(floori(avatar.position.x/CHUNK),floori(avatar.position.z/CHUNK))
	if next != center or force:
		center = next
		desired.clear()
		pending_chunks.clear()
		for x in range(center.x-RADIUS,center.x+RADIUS+1):
			for z in range(center.y-RADIUS,center.y+RADIUS+1):
				var key := Vector2i(x,z)
				desired[key] = true
				if not chunks.has(key): pending_chunks.append(key)
		pending_chunks.sort_custom(func(a: Vector2i,b: Vector2i): return a.distance_squared_to(center)<b.distance_squared_to(center))
		for key in chunks.keys():
			if not desired.has(key):
				chunks[key].queue_free()
				chunks.erase(key)
	_refresh_creatures()
	for landmark in LANDMARKS:
		var point := Vector3(landmark.position[0],0,landmark.position[1])
		if point.distance_to(avatar.position)<20 and landmark.name not in visited: visited.append(landmark.name)

func _refresh_creatures() -> void:
	var candidates: Array = []
	for record in records:
		var p := Vector3(record.position[0],0,record.position[1])
		if float(record.health)>0 and p.distance_to(avatar.position)<92: candidates.append(record)
	candidates.sort_custom(func(a: Dictionary,b: Dictionary): return Vector2(a.position[0],a.position[1]).distance_squared_to(Vector2(avatar.position.x,avatar.position.z))<Vector2(b.position[0],b.position[1]).distance_squared_to(Vector2(avatar.position.x,avatar.position.z)))
	var ids: Array = []
	for record in candidates.slice(0,MAX_CREATURES): ids.append(int(record.id))
	for id in creatures.keys():
		if id not in ids:
			creatures[id].queue_free()
			creatures.erase(id)
	for record in candidates.slice(0,MAX_CREATURES):
		var id := int(record.id)
		if not creatures.has(id):
			var creature := WorldCreature.new()
			creature.state = record
			creature.realm = self
			add_child(creature)
			creatures[id] = creature

func _create_chunk(key: Vector2i) -> void:
	var node := Node3D.new()
	node.position = Vector3(key.x*CHUNK,0,key.y*CHUNK)
	add_child(node)
	chunks[key] = node
	var rng := RandomNumberGenerator.new()
	rng.seed = (key.x+100)*19349663+(key.y+100)*83492791
	var noise := FastNoiseLite.new()
	noise.seed = 72819
	noise.frequency = 0.003
	var dry := noise.get_noise_2d(node.position.x,node.position.z)>0.18
	var ground := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(CHUNK,0.5,CHUNK)
	ground.mesh = box
	ground.position = Vector3(CHUNK/2,-1.15 if abs(key.x)<3 and abs(key.y)<3 else -0.3,CHUNK/2)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.48,0.46,0.31) if dry else Color(0.28,0.47,0.32)
	ground.material_override = mat
	node.add_child(ground)
	for axis in range(2):
		if false: # Roads in the village follow the reference composition.
			var road := MeshInstance3D.new()
			var road_mesh := BoxMesh.new()
			road_mesh.size = Vector3(2.8,0.03,CHUNK) if axis == 0 else Vector3(CHUNK,0.03,2.8)
			road.mesh = road_mesh
			road.position = Vector3(0,0.015,CHUNK/2) if axis == 0 else Vector3(CHUNK/2,0.015,0)
			var road_material := StandardMaterial3D.new()
			road_material.albedo_color = Color(0.61,0.51,0.34)
			road.material_override = road_material
			node.add_child(road)
	var spots: Array[Transform3D] = []
	for i in range(8 if dry else 12):
		var x := rng.randf_range(3,CHUNK-3)
		var z := rng.randf_range(3,CHUNK-3)
		var world_point := Vector3(node.position.x+x,0,node.position.z+z)
		if world_point.length()<100 or absf(world_point.x)<3 or absf(world_point.z)<3: continue
		spots.append(Transform3D(Basis(Vector3.UP,rng.randf_range(0,TAU)).scaled(Vector3.ONE*rng.randf_range(0.8,1.2)),Vector3(x,0,z)))
	var path: String = WorldConductor.ASSETS.arbre if not dry else "res://packs/kaykit-forest-free/Assets/gltf/Rock_1_A_Color1.gltf"
	_batch_geometry(node,path,4.0 if not dry else 1.8,spots)
	for landmark in LANDMARKS:
		var point := Vector3(landmark.position[0],0,landmark.position[1])
		if Vector2i(floori(point.x/CHUNK),floori(point.z/CHUNK)) == key:
			var marker := Label3D.new()
			marker.text = "" if landmark.kind == "village" else landmark.name
			marker.position = point-node.position+Vector3.UP*7
			marker.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			marker.font_size = 40
			marker.pixel_size = 0.025
			node.add_child(marker)
			if landmark.kind in ["tower","camp"]:
				var building := "tower_A" if landmark.kind == "tower" else "barracks"
				var model := WorldAssets.instantiate_model("res://packs/kaykit-medieval-hexagon-pack-1.0/addons/kaykit_medieval_hexagon_pack/Assets/gltf/buildings/blue/building_"+building+"_blue.gltf",6)
				if model:
					model.position += point-node.position+Vector3(7,0,0)
					node.add_child(model)

func _batch_geometry(parent: Node3D, path: String, height: float, transforms: Array[Transform3D]) -> void:
	if transforms.is_empty(): return
	if not geometry.has(path):
		var prototype := WorldAssets.instantiate_model(path,height)
		var parts: Array = []
		if prototype:
			if path.begins_with(VillageScenery.NATURE): host.scenery._natural_palette(prototype,path)
			_mesh_parts(prototype,Transform3D.IDENTITY,parts)
			prototype.free()
		geometry[path] = parts
	for part in geometry[path]:
		var batch := MultiMeshInstance3D.new()
		var multi := MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_3D
		multi.mesh = part.mesh
		multi.instance_count = transforms.size()
		for i in range(transforms.size()): multi.set_instance_transform(i,transforms[i]*part.transform)
		batch.multimesh = multi
		parent.add_child(batch)

func _mesh_parts(node: Node3D, parent: Transform3D, output: Array) -> void:
	var transform := parent*node.transform
	if node is MeshInstance3D and node.mesh:
		var mesh: Mesh = node.mesh.duplicate()
		for i in range(mesh.get_surface_count()): mesh.surface_set_material(i,node.get_active_material(i))
		output.append({"mesh":mesh,"transform":transform})
	for child in node.get_children():
		if child is Node3D: _mesh_parts(child,transform,output)

func find_creature(name_: String) -> Node3D:
	for creature in creatures.values():
		if str(creature.state.name) == name_: return creature
	return null

func can_think() -> bool:
	if Time.get_ticks_msec()-last_thought<40000: return false
	last_thought = Time.get_ticks_msec()
	return true

func travel(index: int) -> void:
	var landmark: Dictionary = LANDMARKS[clampi(index,0,LANDMARKS.size()-1)]
	avatar.position = Vector3(landmark.position[0],0,landmark.position[1])
	avatar.has_destination = false
	avatar.joystick = Vector2.ZERO
	host.follow_player = true
	update_focus(true)
	avatar.save_profile()

func save_state() -> void:
	StateStore.write_json(SAVE,{"version":1,"creatures":records,"visited":visited})

func _exit_tree() -> void:
	save_state()

func region_name(point: Vector3) -> String:
	var nearest := "Étendues sauvages"
	var distance := 150.0
	for landmark in LANDMARKS:
		var d := point.distance_to(Vector3(landmark.position[0],0,landmark.position[1]))
		if d<distance:
			distance = d
			nearest = landmark.name
	return nearest
