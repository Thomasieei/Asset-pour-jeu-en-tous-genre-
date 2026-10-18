extends Node3D
class_name WorldConductor
signal world_event(description: String)
const SAVE := "user://world_conductor.json"
const ASSETS := {
 "arbre":"res://packs/kaykit-forest-free/Assets/gltf/Tree_1_A_Color1.gltf",
 "arbre_b":"res://packs/kaykit-forest-free/Assets/gltf/Tree_2_A_Color1.gltf",
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

func _ready() -> void:
	endpoint = OS.get_environment("LOIC_AI_ENDPOINT") if not OS.get_environment("LOIC_AI_ENDPOINT").is_empty() else str(ProjectSettings.get_setting("loic/ai_endpoint",endpoint))
	terrain = Node3D.new()
	terrain.name = "Constructions_du_monde"
	add_child(terrain)
	add_child(server)
	server.timeout = 15.0
	server.request_completed.connect(_qwen_response)
	use_qwen = OS.get_environment("LOIC_DISABLE_AI") != "1"
	load_world()
	for item in constructions:
		_visualize(item)
	for who in ["Élise","Garen"]:
		var worker := WorldWorker.new()
		worker.worker_name = who
		worker.world = self
		worker.position = Vector3(-2 + workers.size()*4,0,3)
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
	if cycle >= 12.0:
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
	if use_qwen:
		var prompt := "Tu gères un monde Godot. Observe les faits et choisis une seule action parmi " + str(INTENTS) + ". Priorité nourriture, ressources renouvelables, maisons puis embellissement. Ne récolte que des arbres/champs mûrs. Réponds uniquement JSON {\"action\":\"...\",\"raison\":\"...\"}. Tu commandes les outils du moteur; tu ne modifies pas du code. /no_think"
		var payload := {"model":"local","messages":[{"role":"system","content":prompt},{"role":"user","content":JSON.stringify(observe())+" /no_think"}],"temperature":0.3,"max_tokens":160,"response_format":{"type":"json_schema","json_schema":{"name":"world_intent","strict":true,"schema":{"type":"object","properties":{"action":{"type":"string","enum":INTENTS},"raison":{"type":"string"}},"required":["action","raison"],"additionalProperties":false}}},"chat_template_kwargs":{"enable_thinking":false}}
		thinking = true
		if server.request(endpoint,["Content-Type: application/json"],HTTPClient.METHOD_POST,JSON.stringify(payload)) == OK:
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
		if free:
			return place
	return Vector3.INF

func steer(origin: Vector3, destination: Vector3, distance: float) -> Vector3:
	var direction := (destination-origin).normalized()
	for item in constructions:
		if not str(item.action).begins_with("construire"):
			continue
		var p := Vector3(float(item.position[0]),0,float(item.position[2]))
		if p.distance_to(destination) < 3:
			continue
		var offset := origin-p
		if offset.length() < 3.2 and direction.dot(offset) < 0:
			direction = (direction + offset.normalized()*2 + Vector3(-offset.z,0,offset.x).normalized()).normalized()
	return origin + direction * minf(distance, origin.distance_to(destination))

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
	var f := FileAccess.open(SAVE,FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"version":2,"population":population,"nourriture":nourriture,"bois":bois,"pierre":pierre,"age":world_age,"next_id":next_id,"objectif":objective,"instructions":instructions,"constructions":constructions,"travaux":work_queue}))

func load_world() -> void:
	if not FileAccess.file_exists(SAVE):
		return
	var f := FileAccess.open(SAVE,FileAccess.READ)
	if f == null:
		return
	var data = JSON.parse_string(f.get_as_text())
	if not data is Dictionary:
		return
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
