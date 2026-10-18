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
const INTENTS := ["planter_arbre","cultiver_champ","construire_maison","construire_atelier","construire_marche","construire_moulin"]
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
var terrain: Node3D
var workers := ["Élise","Garen","Loïc"]
var work_queue: Array = []

func _ready() -> void:
	terrain = Node3D.new()
	terrain.name = "Constructions_du_monde"
	add_child(terrain)
	add_child(server)
	server.timeout = 8.0
	server.request_completed.connect(_qwen_response)
	load_world()
	for item in constructions:
		_visualize(item)

func _process(delta: float) -> void:
	cycle += delta
	if cycle >= 16.0:
		cycle = 0.0
		world_age += 1
		nourriture = maxi(0,nourriture - maxi(1,population / 3))
		# Chaque ordre a une durée de construction et un artisan désigné.
		for i in range(work_queue.size()-1,-1,-1):
			work_queue[i].progress += 1
			if work_queue[i].progress >= work_queue[i].duration:
				var done: Dictionary = work_queue[i]
				work_queue.remove_at(i)
				complete_project(done)
		if work_queue.size() < 2:
			think()
		save_world()

func think() -> void:
	if thinking:
		return
	if use_qwen:
		var facts := {"habitants":population,"nourriture":nourriture,"bois":bois,"pierre":pierre,"constructions":constructions.size(),"travaux":work_queue,"dernieres_decisions":instructions.slice(maxi(0,instructions.size()-8))}
		var prompt := "Tu es la Conscience du Monde d'un univers fantastique vivant. Tu ne joues PAS les habitants. Propose une seule action de développement utile et une raison, au format JSON: {\\\"action\\\":\\\"cultiver_champ\\\",\\\"raison\\\":\\\"...\\\"}. Actions possibles: " + str(INTENTS) + ". L'humain garde le contrôle du monde et de ses ressources. /no_think"
		var payload := {"model":"local","messages":[{"role":"system","content":prompt},{"role":"user","content":JSON.stringify(facts)+" /no_think"}],"temperature":0.3,"max_tokens":100,"chat_template_kwargs":{"enable_thinking":false}}
		thinking = true
		if server.request("http://127.0.0.1:8765/v1/chat/completions",["Content-Type: application/json"],HTTPClient.METHOD_POST,JSON.stringify(payload)) == OK:
			return
		thinking = false
	choose_by_rules()

func _qwen_response(result: int, code: int, _headers: PackedStringArray, response: PackedByteArray) -> void:
	thinking = false
	if result == HTTPRequest.RESULT_SUCCESS and code == 200:
		var obj = JSON.parse_string(response.get_string_from_utf8())
		if obj is Dictionary:
			var choices = obj.get("choices",[])
			if choices is Array and not choices.is_empty():
				var raw = str(choices[0].get("message",{}).get("content",""))
				var idea = JSON.parse_string(raw)
				if idea is Dictionary and str(idea.get("action","")) in INTENTS:
					if propose(str(idea.action),str(idea.get("raison","Qwen"))):
						return
	choose_by_rules()

func choose_by_rules() -> void:
	if nourriture < 35:
		propose("cultiver_champ","La nourriture manque.")
	elif population > constructions.size() + 3:
		propose("construire_maison","De nouveaux habitants ont besoin d'un foyer.")
	elif world_age % 3 == 0:
		propose("planter_arbre","La nature doit se régénérer.")
	elif world_age % 4 == 0:
		propose("cultiver_champ","Préparer les prochaines récoltes.")
	else:
		propose("construire_maison","Faire grandir le village.")

func propose(action: String, reason: String) -> bool:
	if action not in INTENTS or work_queue.size() >= 2:
		return false
	var wood_cost := 0
	var stone_cost := 0
	if action.begins_with("construire"):
		wood_cost = 20
		stone_cost = 12
	elif action == "planter_arbre":
		wood_cost = 1
	else:
		wood_cost = 4
	if bois < wood_cost or pierre < stone_cost:
		world_event.emit("Construction refusée : ressources insuffisantes.")
		return false
	bois -= wood_cost
	pierre -= stone_cost
	var place := _find_place(action)
	var worker := workers[world_age % workers.size()]
	var order := {"action":action,"raison":reason.left(180),"ouvrier":worker,"position":[place.x,0.0,place.z],"progress":0,"duration":2 if action.begins_with("construire") else 1}
	work_queue.append(order)
	instructions.append({"cycle":world_age,"type":action,"raison":reason.left(180),"ouvrier":worker})
	world_event.emit("Conscience du Monde à "+worker+" : "+action+" — "+reason.left(110))
	save_world()
	return true

func _find_place(action: String) -> Vector3:
	var index := constructions.size() + work_queue.size()
	var ring := 13.0 + floorf(float(index)/9.0) * 7.0
	var angle := float(index) * 2.39996
	if action == "cultiver_champ":
		ring += 5.0
	return Vector3(cos(angle)*ring,0,sin(angle)*ring)

func complete_project(order: Dictionary) -> void:
	var action := str(order.get("action",""))
	var pos = order.get("position",[0,0,0])
	var item := {"asset":_asset_for(action),"action":action,"position":pos,"growth":0.25 if action == "planter_arbre" else 1.0}
	constructions.append(item)
	if action == "cultiver_champ":
		nourriture += 30
	if action == "planter_arbre":
		bois += 3
	_visualize(item)
	world_event.emit(str(order.get("ouvrier","Un habitant"))+" a terminé : "+action)
	save_world()

func _asset_for(action: String) -> String:
	match action:
		"planter_arbre": return "arbre" if constructions.size() % 2 == 0 else "arbre_b"
		"construire_maison": return "maison"
		"construire_atelier": return "atelier"
		"construire_marche": return "marche"
		"construire_moulin": return "moulin"
	return "champ"

func _visualize(item: Dictionary) -> void:
	var p = item.get("position",[0,0,0])
	if not(p is Array) or p.size()<3:
		return
	var pivot := Node3D.new()
	pivot.position = Vector3(float(p[0]),float(p[1]),float(p[2]))
	terrain.add_child(pivot)
	var asset := str(item.get("asset",""))
	if ASSETS.has(asset) and ResourceLoader.exists(ASSETS[asset]):
		var res = load(ASSETS[asset])
		if res is PackedScene:
			var model: Node3D = res.instantiate()
			pivot.add_child(model)
			if str(item.get("action","")) == "planter_arbre":
				model.scale = Vector3.ONE * float(item.get("growth",1.0))
			return
	# Les champs utilisent des rangées cultivées, pas de bâtiment fictif.
	for row in range(5 if asset == "champ" else 1):
		var patch := MeshInstance3D.new()
		var cube := BoxMesh.new()
		cube.size = Vector3(5.0 if asset=="champ" else 1.5,0.12,0.55 if asset=="champ" else 1.5)
		patch.mesh = cube
		patch.position = Vector3(0,0.12,float(row)-2.0 if asset=="champ" else 0)
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.34,0.26,0.12) if asset=="champ" else Color(0.25,0.47,0.24)
		patch.material_override = mat
		pivot.add_child(patch)

func save_world() -> void:
	var f := FileAccess.open(SAVE,FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"population":population,"nourriture":nourriture,"bois":bois,"pierre":pierre,"age":world_age,"instructions":instructions.slice(maxi(0,instructions.size()-150)),"constructions":constructions,"travaux":work_queue}))

func load_world() -> void:
	if not FileAccess.file_exists(SAVE):
		return
	var f := FileAccess.open(SAVE,FileAccess.READ)
	if f == null:
		return
	var data = JSON.parse_string(f.get_as_text())
	if data is Dictionary:
		population = int(data.get("population",3))
		nourriture = int(data.get("nourriture",65))
		bois = int(data.get("bois",100))
		pierre = int(data.get("pierre",85))
		world_age = int(data.get("age",0))
		instructions = data.get("instructions",[])
		constructions = data.get("constructions",[])
		work_queue = data.get("travaux",[])
