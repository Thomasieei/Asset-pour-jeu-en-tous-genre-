extends Node3D
class_name WorldConductor
signal world_event(description: String)
const SAVE := "user://world_conductor.json"
const ASSETS := {
 "arbre":"res://packs/nature-kit/Models/GLTF format/tree_pineTallA_detailed.glb",
 "arbre_b":"res://packs/nature-kit/Models/GLTF format/tree_oak.glb",
 "maison":"res://packs/kaykit-medieval-hexagon-pack-1.0/addons/kaykit_medieval_hexagon_pack/Assets/gltf/buildings/blue/building_home_A_blue.gltf",
 "atelier":"res://packs/kaykit-medieval-hexagon-pack-1.0/addons/kaykit_medieval_hexagon_pack/Assets/gltf/buildings/blue/building_blacksmith_blue.gltf",
 "marche":"res://packs/kaykit-medieval-hexagon-pack-1.0/addons/kaykit_medieval_hexagon_pack/Assets/gltf/buildings/blue/building_market_blue.gltf",
 "moulin":"res://packs/kaykit-medieval-hexagon-pack-1.0/addons/kaykit_medieval_hexagon_pack/Assets/gltf/buildings/blue/building_windmill_blue.gltf"
}
const INTENTS := ["planter_arbre","cultiver_champ","construire_maison","construire_atelier","construire_marche","construire_moulin","recolter","extraire_pierre","ramasser_bois"]
const MAX_ENTITIES := 120
var population := 3
var nourriture := 65
var bois := 100
var pierre := 85
var instructions: Array = []
var constructions: Array = []
var world_age := 0
var cycle := 0.0
var server := HTTPRequest.new()
var thinking := false
var use_qwen := true
var autonomous := true
var terrain: Node3D
var workers: Array = []
var work_queue: Array = []
var visual_nodes: Dictionary = {}
var last_source := "Règles locales"
var objective := "Créer un beau village viable, nourrir les habitants et préserver la forêt."
var endpoint := "http://127.0.0.1:8765/v1/chat/completions"
var next_id := 1
var last_observation: Dictionary = {}
var navigation: AStarGrid2D
var navigation_revision := -1
var path_cache: Dictionary = {}

func _ready() -> void:
	endpoint = LoicAIConfig.endpoint()
	terrain = Node3D.new()
	terrain.name = "Constructions_du_monde"
	add_child(terrain)
	add_child(server)
	server.timeout = 15.0
	server.request_completed.connect(_qwen_response)
	use_qwen = LoicAIConfig.enabled()
	load_world()
	for item in constructions:
		_visualize(item)
	for who in ["Élise","Garen"]:
		var worker := WorldWorker.new()
		worker.worker_name = who
		worker.world = self
		worker.position = Vector3(-8 - workers.size()*6,0,-16 - workers.size()*5)
		add_child(worker)
		workers.append(worker)
	_assign_jobs()

func _physics_process(delta: float) -> void:
	# Pause and speed include workers, plants, economy and planner.
	for worker in workers:
		worker.set_physics_process(autonomous)
	if not autonomous:
		return
	var dt := delta
	for item in constructions:
		if item.action in ["planter_arbre","cultiver_champ"] and float(item.growth) < 1:
			item.growth = minf(1,float(item.growth) + dt / 70.0)
			if visual_nodes.has(int(item.id)):
				visual_nodes[int(item.id)].scale = Vector3.ONE * maxf(0.15,float(item.growth))
	cycle += dt
	if cycle >= (30.0 if LoicAIConfig.local_mode() else 12.0):
		cycle = 0.0
		world_age += 1
		nourriture = maxi(0,nourriture - population)
		last_observation = observe()
		if work_queue.size() < 2:
			think()
		save_world()
	_assign_jobs()

func observe() -> Dictionary:
	var counts: Dictionary = {}
	var mature: Array = []
	for item in constructions:
		counts[item.asset] = int(counts.get(item.asset,0)) + 1
		if float(item.growth) >= 1 and item.action in ["planter_arbre","cultiver_champ"]:
			mature.append({"id":item.id,"type":item.asset,"position":item.position})
	var people: Array = []
	for worker in workers:
		people.append({"nom":worker.worker_name,"fatigue":worker.fatigue,"tache":worker.job,"perception":worker.eyes})
	return {"cycle":world_age,"habitants":population,"nourriture":nourriture,"bois":bois,"pierre":pierre,"elements":counts,"recoltables":mature,"travaux":work_queue.duplicate(true),"ouvriers":people,"objectif":objective,"limite_elements":MAX_ENTITIES,"nombre_elements":constructions.size(),"catalogue":WorldAssets.catalogue("kaykit",8)}

func think() -> void:
	if thinking or not autonomous or work_queue.size() >= 2:
		return
	var avatar = get_parent().get("avatar")
	var near_village: bool = avatar == null or avatar.position.length()<65
	if use_qwen and near_village:
		var prompt := "Tu gères un monde Godot. Observe les faits et choisis une seule action parmi " + str(INTENTS) + ". Priorité nourriture, ressources renouvelables, maisons puis embellissement. Ne récolte que des arbres/champs mûrs. Réponds uniquement JSON {\"action\":\"...\",\"raison\":\"...\"}. Tu commandes les outils du moteur; tu ne modifies pas du code. /no_think"
		var payload := {"model":"local","messages":[{"role":"system","content":prompt},{"role":"user","content":JSON.stringify(observe())+" /no_think"}],"temperature":0.3,"max_tokens":160,"response_format":{"type":"json_schema","json_schema":{"name":"world_intent","strict":true,"schema":{"type":"object","properties":{"action":{"type":"string","enum":INTENTS},"raison":{"type":"string"}},"required":["action","raison"],"additionalProperties":false}}},"chat_template_kwargs":{"enable_thinking":false}}
		thinking = true
		var error: Error
		if LoicAIConfig.local_mode():
			error = get_tree().root.get_node("LocalModel").request(payload,_qwen_response,1,"world_intent")
		else:
			error = server.request(endpoint,LoicAIConfig.headers(),HTTPClient.METHOD_POST,JSON.stringify(payload))
		if error == OK:
			return
		thinking = false
	choose_by_rules()

func _qwen_response(result: int, code: int, _headers: PackedStringArray, response: PackedByteArray) -> void:
	thinking = false
	if not autonomous:
		return
	if result == HTTPRequest.RESULT_SUCCESS and code == 200:
		var obj = JSON.parse_string(response.get_string_from_utf8())
		if obj is Dictionary:
			var choices = obj.get("choices",[])
			if choices is Array and not choices.is_empty() and choices[0] is Dictionary:
				var message = choices[0].get("message",{})
				if message is Dictionary:
					var idea = JSON.parse_string(str(message.get("content","")))
					if idea is Dictionary and propose(str(idea.get("action","")),str(idea.get("raison","Qwen"))):
						last_source = "Qwen local"
						return
	choose_by_rules()

func choose_by_rules() -> void:
	last_source = "Règles locales"
	if nourriture < 45:
		if _mature("cultiver_champ") != -1 and propose("recolter","Récolter les cultures mûres."):
			return
		if _count("cultiver_champ") < 4 and propose("cultiver_champ","Assurer les prochaines récoltes."):
			return
	if bois < 35:
		if propose("ramasser_bois","Prélever du bois sur un arbre mûr et le replanter."):
			return
		if propose("planter_arbre","Renouveler la forêt."):
			return
	if pierre < 25 and propose("extraire_pierre","Approvisionner les chantiers."):
		return
	var goals := {"planter_arbre":18,"cultiver_champ":3,"construire_maison":2,"construire_atelier":1,"construire_marche":1,"construire_moulin":1}
	for action in goals:
		if _count(action) < int(goals[action]) and propose(action,"Équilibrer nature, logement et services."):
			return
	if nourriture < 120 and propose("recolter","Constituer une réserve de nourriture."):
		return
	if bois < 150:
		propose("ramasser_bois","Entretenir la forêt et les réserves.")

func _count(action: String) -> int:
	var count := 0
	for item in constructions + work_queue:
		if item.action == action:
			count += 1
	return count

func _mature(action: String) -> int:
	for item in constructions:
		if item.action == action and float(item.growth) >= 1:
			var reserved := false
			for order in work_queue:
				if int(order.get("target",-1)) == int(item.id):
					reserved = true
			if not reserved:
				return int(item.id)
	return -1

func propose(action: String, reason: String) -> bool:
	if action not in INTENTS or work_queue.size() >= 2 or not autonomous:
		return false
	var resource_job := action in ["recolter","ramasser_bois","extraire_pierre"]
	if not resource_job and constructions.size() + work_queue.size() >= MAX_ENTITIES:
		return false
	var target := -1
	if action in ["recolter","ramasser_bois"]:
		target = _mature("cultiver_champ" if action == "recolter" else "planter_arbre")
		if target == -1:
			return false
	var wood_cost := 20 if action.begins_with("construire") else (2 if action == "cultiver_champ" else 0)
	var stone_cost := 12 if action.begins_with("construire") else 0
	if bois < wood_cost or pierre < stone_cost:
		return false
	var place := _find_place(action)
	if target >= 0:
		for item in constructions:
			if int(item.id) == target:
				place = Vector3(float(item.position[0]),0,float(item.position[2]))
	if place == Vector3.INF:
		return false
	bois -= wood_cost
	pierre -= stone_cost
	var order := {"id":next_id,"action":action,"raison":reason.left(180),"ouvrier":"","position":[place.x,0.0,place.z],"progress":0.0,"duration":18.0 if action.begins_with("construire") else 9.0,"target":target}
	next_id += 1
	work_queue.append(order)
	instructions.append({"cycle":world_age,"type":action,"raison":reason.left(180)})
	if instructions.size() > 150:
		instructions.pop_front()
	_assign_jobs()
	world_event.emit("Monde : "+action+" — "+reason.left(110))
	save_world()
	return true

func _assign_jobs() -> void:
	for order in work_queue:
		if not str(order.ouvrier).is_empty():
			continue
		for worker in workers:
			if worker.available():
				order.ouvrier = worker.worker_name
				worker.job = order
				break

func _find_place(action: String) -> Vector3:
	if action == "extraire_pierre":
		return Vector3(18,0,-12)
	for attempt in range(150):
		var index := next_id + attempt
		var ring := 10.0 + floorf(float(index)/12.0) * 5.0
		var angle := float(index) * 2.39996
		var place := Vector3(cos(angle)*ring,0,sin(angle)*ring)
		if absf(place.x) > 40 or absf(place.z) > 40 or absf(place.z) < 2.5 or absf(place.x) < 2.5:
			continue
		var free := place.distance_to(Vector3(-6,0,-3)) > 6
		for other in constructions + work_queue:
			var p: Array = other.position
			if place.distance_to(Vector3(float(p[0]),0,float(p[2]))) < 5.0:
				free = false
		var scenery = get_parent().get("scenery")
		if scenery:
			for landmark in scenery.obstacles:
				if Vector2(place.x-landmark.x,place.z-landmark.z).length()<landmark.y+4: free = false
		if free and not (place.x < 4 and place.z < 0) and absf(place.z-VillageScenery.river_z(place.x))>5:
			return place
	return Vector3.INF

func steer(origin: Vector3, destination: Vector3, distance: float, navigate: bool = true) -> Vector3:
	var scenery = get_parent().get("scenery")
	if navigate and scenery and absf(origin.x)<60 and absf(origin.z)<60 and absf(destination.x)<60 and absf(destination.z)<60:
		return _navigate(origin,destination,distance,scenery)
	var goal := destination
	# Route across the real bridge when work or a player destination is across
	# the creek. Returning the blocked step alone would strand workers forever.
	if navigate and absf(origin.x)<100 and absf(destination.x)<100 and absf(origin.z)<100 and absf(destination.z)<100:
		var start_bank := origin.z-VillageScenery.river_z(origin.x)
		var end_bank := destination.z-VillageScenery.river_z(destination.x)
		if absf(start_bank)<4.1 and absf(origin.x+2)<2:
			goal = Vector3(-2,0,-13.0 if end_bank<0 else -3.0)
		elif start_bank*end_bank<0 and absf(origin.x+2)>1.3:
			goal = Vector3(-2,0,-3.0 if start_bank>0 else -13.0)
		elif start_bank*end_bank<0:
			goal = Vector3(-2,0,-13.0 if end_bank<0 else -3.0)
	var direction := (goal-origin).normalized()
	for item in constructions:
		if not str(item.action).begins_with("construire"):
			continue
		var p := Vector3(float(item.position[0]),0,float(item.position[2]))
		if p.distance_to(destination) < 3:
			continue
		var offset := origin-p
		if offset.length() < 3.2 and direction.dot(offset) < 0:
			direction = (direction + offset.normalized()*2 + Vector3(-offset.z,0,offset.x).normalized()).normalized()
	var next := origin + direction * minf(distance, origin.distance_to(goal))
	return scenery.constrain_step(origin,next) if scenery else next

func _navigate(origin: Vector3, destination: Vector3, distance: float, scenery: VillageScenery) -> Vector3:
	if navigation == null or navigation_revision != constructions.size():
		navigation = AStarGrid2D.new()
		navigation.region = Rect2i(-32,-32,64,64)
		navigation.cell_size = Vector2(2,2)
		navigation.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
		navigation.update()
		for x in range(-32,32):
			for z in range(-32,32):
				var point := Vector3(x*2,0,z*2)
				var blocked := VillageScenery.ground_height(point.x,point.z)<-0.15 and absf(point.x+2)>1.3
				for item in scenery.obstacles:
					if Vector2(point.x-item.x,point.z-item.z).length()<item.y+0.8: blocked = true
				for item in constructions:
					if str(item.action).begins_with("construire") and Vector2(point.x-item.position[0],point.z-item.position[2]).length()<2.5: blocked = true
				navigation.set_point_solid(Vector2i(x,z),blocked)
		navigation_revision = constructions.size()
		path_cache.clear()
	var start := _open_cell(Vector2i(roundi(origin.x/2),roundi(origin.z/2)))
	var finish := _open_cell(Vector2i(roundi(destination.x/2),roundi(destination.z/2)))
	var key := Vector4i(start.x,start.y,finish.x,finish.y)
	if not path_cache.has(key):
		if path_cache.size()>512: path_cache.clear()
		path_cache[key] = navigation.get_point_path(start,finish)
	var path: PackedVector2Array = path_cache[key]
	if path.is_empty(): return origin
	var waypoint := destination
	if path.size()>1:
		var i := 1 if Vector2(origin.x,origin.z).distance_to(path[0])<1.8 else 0
		waypoint = Vector3(path[i].x,0,path[i].y)
	return scenery.constrain_step(origin,origin.move_toward(waypoint,distance))

func _open_cell(cell: Vector2i) -> Vector2i:
	if navigation.is_in_boundsv(cell) and not navigation.is_point_solid(cell): return cell
	var nearest := cell
	var best := INF
	for x in range(-4,5):
		for z in range(-4,5):
			var candidate := cell+Vector2i(x,z)
			if navigation.is_in_boundsv(candidate) and not navigation.is_point_solid(candidate):
				var d := float(x*x+z*z)
				if d<best:
					best = d
					nearest = candidate
	return nearest

func complete_project(order: Dictionary) -> void:
	if not work_queue.has(order):
		return
	work_queue.erase(order)
	var action := str(order.action)
	if action == "extraire_pierre":
		pierre += 24
	elif action in ["recolter","ramasser_bois"]:
		for item in constructions:
			if int(item.id) == int(order.target) and float(item.growth) >= 1:
				if action == "recolter":
					nourriture += 40
				else:
					bois += 28
				item.growth = 0.15
				break
	else:
		var item := {"id":int(order.id),"asset":_asset_for(action),"action":action,"position":order.position,"growth":0.15 if action in ["planter_arbre","cultiver_champ"] else 1.0}
		constructions.append(item)
		_visualize(item)
	world_event.emit(str(order.ouvrier)+" a terminé : "+action)
	save_world()

func _asset_for(action: String) -> String:
	return {"planter_arbre":"arbre","cultiver_champ":"champ","construire_maison":"maison","construire_atelier":"atelier","construire_marche":"marche","construire_moulin":"moulin"}.get(action,"champ")

func _visualize(item: Dictionary) -> void:
	var pivot := Node3D.new()
	pivot.position = Vector3(float(item.position[0]),0,float(item.position[2]))
	pivot.set_meta("world_id",str(item.id))
	pivot.set_meta("kind",item.asset)
	pivot.add_to_group("world_observable")
	terrain.add_child(pivot)
	visual_nodes[int(item.id)] = pivot
	if item.asset == "champ":
		for row in range(3):
			for col in range(4):
				var crop := WorldAssets.instantiate_model("res://packs/nature-kit/Models/GLTF format/crops_wheatStageB.glb",0.8)
				if crop:
					crop.position += Vector3(col*0.7-1.1,0,row*0.9-0.9)
					pivot.add_child(crop)
	else:
		var model := WorldAssets.instantiate_model(str(ASSETS.get(item.asset,"")),4.5 if item.asset in ["arbre","arbre_b"] else 3.8)
		if model:
			var scenery = get_parent().get("scenery")
			if scenery and str(ASSETS.get(item.asset,"")).begins_with(VillageScenery.NATURE): scenery._natural_palette(model,str(ASSETS[item.asset]))
			pivot.add_child(model)
	if str(item.action).begins_with("construire"):
		var body := StaticBody3D.new()
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(3,3,3)
		shape.shape = box
		shape.position.y = 1.5
		body.add_child(shape)
		pivot.add_child(body)
	pivot.scale = Vector3.ONE * maxf(0.15,float(item.growth))

func save_world() -> void:
	StateStore.write_json(SAVE,{"version":2,"population":population,"nourriture":nourriture,"bois":bois,"pierre":pierre,"age":world_age,"next_id":next_id,"objectif":objective,"instructions":instructions,"constructions":constructions,"travaux":work_queue})

func load_world() -> void:
	var data := StateStore.read_json(SAVE)
	if data.is_empty(): return
	population = int(data.get("population",3))
	nourriture = int(data.get("nourriture",65))
	bois = int(data.get("bois",100))
	pierre = int(data.get("pierre",85))
	world_age = int(data.get("age",0))
	objective = str(data.get("objectif",objective)).left(400)
	instructions = data.get("instructions",[])
	constructions = data.get("constructions",[])
	work_queue = data.get("travaux",[])
	next_id = int(data.get("next_id",1))
	for item in constructions + work_queue:
		if not item.has("id"):
			item.id = next_id
			next_id += 1
		next_id = maxi(next_id,int(item.id)+1)
	for order in work_queue:
		order.ouvrier = ""
		order.target = int(order.get("target",-1))
		# V0 progress was measured in 16s cycles.
		if int(data.get("version",0)) < 2:
			order.progress = 0.0
			order.duration = 18.0
