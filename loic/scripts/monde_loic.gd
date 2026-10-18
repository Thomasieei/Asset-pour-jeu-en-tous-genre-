extends Node3D
const LOIC = preload("res://loic/scripts/loic_agent.gd")
var loic: LoicAgent
var conductor: WorldConductor
var brain: LoicBrain
var social: LoicSocial
var brain_clock := 0.0
var encounter_mesh: MeshInstance3D
var log_label: Label
var stats_label: Label
var input_line: LineEdit
var http: HTTPRequest
var pending := false
const ENDPOINT = "http://127.0.0.1:8765/v1/chat/completions"

func _ready() -> void:
	_creer_environnement()
	loic = LOIC.new()
	add_child(loic)
	loic.journal.connect(_log)
	loic.changed.connect(_refresh)
	brain = preload("res://loic/scripts/loic_brain.gd").new()
	add_child(brain)
	brain.decision.connect(_decision_ia)
	social = preload("res://loic/scripts/loic_social.gd").new()
	add_child(social)
	charger_social()
	_creer_monstre()
	conductor = preload("res://loic/scripts/world_conductor.gd").new()
	add_child(conductor)
	conductor.world_event.connect(_log)
	http = HTTPRequest.new()
	http.timeout = 12
	add_child(http)
	http.request_completed.connect(_reponse_modele)
	_creer_interface()
	_log("Loïc, 24 ans, découvre son univers idéal. Ses choix lui appartiennent.")
	_refresh()

func _sol(pos: Vector3,scale_: Vector3,color: Color) -> void:
	var cube := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = scale_
	cube.mesh = mesh
	cube.position = pos
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	cube.material_override = mat
	add_child(cube)

func _creer_environnement() -> void:
	_sol(Vector3(0,-0.25,0),Vector3(100,0.5,100),Color(0.26,0.48,0.31))
	# Maison avec porte ouverte et lit visible.
	_sol(Vector3(-7.5,0.85,-3),Vector3(0.25,1.7,3.3),Color(0.65,0.45,0.27))
	_sol(Vector3(-4.5,0.85,-3),Vector3(0.25,1.7,3.3),Color(0.65,0.45,0.27))
	_sol(Vector3(-6,0.85,-4.6),Vector3(3.2,1.7,0.25),Color(0.65,0.45,0.27))
	_sol(Vector3(-7,0.85,-1.4),Vector3(1.05,1.7,0.25),Color(0.65,0.45,0.27))
	_sol(Vector3(-5,0.85,-1.4),Vector3(1.05,1.7,0.25),Color(0.65,0.45,0.27))
	_sol(Vector3(-6,1.4,-1.4),Vector3(0.95,0.55,0.25),Color(0.65,0.45,0.27))
	_sol(Vector3(-6,0.18,-3.1),Vector3(1.5,0.35,2.1),Color(0.42,0.28,0.17))
	_sol(Vector3(-6,0.41,-3.7),Vector3(1.35,0.13,0.7),Color(0.84,0.79,0.64))
	_sol(Vector3(6,0.5,3),Vector3(1,1,1),Color(0.5,0.18,0.17))
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50,-25,0)
	add_child(sun)
	var env := WorldEnvironment.new()
	var sky := Sky.new()
	sky.sky_material = ProceduralSkyMaterial.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	env.environment = environment
	add_child(env)
	var camera := Camera3D.new()
	camera.position = Vector3(13,14,17)
	add_child(camera)
	camera.look_at(Vector3(0,0,0))
	camera.current = true

func _creer_interface() -> void:
	var canvas := CanvasLayer.new()
	add_child(canvas)
	var root := PanelContainer.new()
	root.position = Vector2(12,12)
	root.custom_minimum_size = Vector2(475,0)
	canvas.add_child(root)
	var v := VBoxContainer.new()
	root.add_child(v)
	var title := Label.new()
	title.text = "LOÏC — PREMIER HABITANT AUTONOME"
	v.add_child(title)
	stats_label = Label.new()
	v.add_child(stats_label)
	var row := HBoxContainer.new()
	v.add_child(row)
	for choice in ["marcher","courir","sauter","accroupir","esquiver","attaquer","rentrer","dormir","equiper"]:
		var b := Button.new()
		b.text = choice
		row.add_child(b)
		b.pressed.connect(_action.bind(choice))
	var monster := Button.new()
	monster.text = "Faire apparaître un monstre"
	v.add_child(monster)
	monster.pressed.connect(_apparition_monstre)
	var develop := Button.new()
	develop.text = "Conscience du Monde : décider du prochain aménagement"
	v.add_child(develop)
	develop.pressed.connect(func(): conductor.think())
	for who in ["Elise","Garen"]:
		var talk := Button.new()
		talk.text = "Rencontrer " + who
		v.add_child(talk)
		talk.pressed.connect(_rencontre.bind(who))
	input_line = LineEdit.new()
	input_line.placeholder_text = "Parler à Loïc en français..."
	v.add_child(input_line)
	var speak := Button.new()
	speak.text = "Parler (Qwen local si serveur disponible)"
	v.add_child(speak)
	speak.pressed.connect(_parler)
	log_label = Label.new()
	log_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	log_label.custom_minimum_size = Vector2(470,110)
	v.add_child(log_label)

func _action(choice: String) -> void:
	if choice == "rentrer":
		loic.cible = loic.maison
	if choice == "marcher" or choice == "courir":
		loic.cible = Vector3(randf_range(-7,7),0,randf_range(-7,7))
	if not loic.choisir(choice):
		_log("Cette action n'est pas possible maintenant.")
	_refresh()

func _parler() -> void:
	var phrase := input_line.text.strip_edges().left(250)
	if phrase.is_empty():
		return
	loic.relations.joueur = int(loic.relations.joueur) + 1
	if pending:
		return
	pending = true
	var memo := loic.souvenirs.slice(maxi(0,loic.souvenirs.size()-8))
	var system_text := "Tu es Loïc, chevalier de 24 ans dans un monde fantasy que tu juges parfait. Tu es optimiste, curieux, prudent parfois, capable de désaccord. Reste en personnage. Réponds en français naturellement et brièvement, en une ou deux phrases. Ne prétends pas avoir agi dans le jeu. Tes souvenirs: "+JSON.stringify(memo)+"; état: "+JSON.stringify(loic.stats)+". /no_think"
	var body := {"model":"local","messages":[{"role":"system","content":system_text},{"role":"user","content":phrase+" /no_think"}],"temperature":0.75,"max_tokens":130,"chat_template_kwargs":{"enable_thinking":false}}
	var err := http.request(ENDPOINT,["Content-Type: application/json"],HTTPClient.METHOD_POST,JSON.stringify(body))
	if err != OK:
		pending = false
		_reponse_secours(phrase)
	input_line.clear()

func _reponse_secours(phrase: String) -> void:
	var answer := "Je me demande ce que ce monde nous réserve. "
	if "aide" in phrase.to_lower():
		answer = "Je peux aider, mais je dois aussi veiller sur ma propre vie."
	elif "monstre" in phrase.to_lower():
		answer = "Je préfère observer sa force avant de risquer notre peau."
	elif "bonjour" in phrase.to_lower():
		answer = "Bonjour ! Je m'appelle Loïc. Cet univers me fascine."
	loic.entree_dialogue(answer)
	_log("Mode règles (serveur Qwen indisponible) : "+answer)

func _reponse_modele(result: int,code: int,_headers: PackedStringArray,bytes: PackedByteArray) -> void:
	pending = false
	if result == HTTPRequest.RESULT_SUCCESS and code == 200:
		var data = JSON.parse_string(bytes.get_string_from_utf8())
		if data is Dictionary and data.get("choices",[]) is Array and not data.choices.is_empty():
			var content := str(data.choices[0].get("message",{}).get("content","")).strip_edges()
			if not content.is_empty():
				loic.entree_dialogue(content)
				_log("Qwen : "+content)
				return
	_reponse_secours("")

func _log(message: String) -> void:
	if log_label:
		log_label.text = message

func _refresh() -> void:
	if stats_label == null or loic == null:
		return
	stats_label.text = "Niveau %s | PV %d | Mana %d | Endurance %d | Faim %d | Fatigue %d\nAction : %s | Monstres vaincus : %d | Souvenirs : %d" % [loic.stats.niveau,loic.stats.vie,loic.stats.mana,loic.stats.endurance,loic.besoins.faim,loic.besoins.fatigue,loic.action,loic.ennemis_vaincus,loic.souvenirs.size()]

func _process(delta: float) -> void:
	brain_clock += delta
	if brain_clock >= 12.0 and loic != null and brain != null:
		brain_clock = 0
		brain.ponder(loic, {"chez_soi":loic.position.distance_to(loic.maison)<1.8,"personnes":["Elise","Garen"],"monstre_visible":loic.ennemi_proche})
	if encounter_mesh != null:
		encounter_mesh.visible = loic.ennemi_proche

func _decision_ia(intent: String, motive: String, origin: String) -> void:
	if loic == null:
		return
	# N'autoriser les ordres du modèle qu'après vérification par les règles internes.
	if intent == "rentrer":
		loic.cible = loic.maison
	elif intent in ["marcher","courir"]:
		loic.cible = Vector3(randf_range(-8,8),0,randf_range(-8,8))
	elif intent == "aider":
		_rencontre("Elise")
	elif intent == "demander_aide":
		_rencontre("Garen")
	if loic.choisir(intent):
		loic.souvenir("J'ai choisi "+intent+" : "+motive,2)
		_log(origin+" — "+motive)
		loic.sauvegarder()

func _creer_monstre() -> void:
	encounter_mesh = MeshInstance3D.new()
	var creature := SphereMesh.new()
	creature.radius = 0.65
	creature.height = 1.2
	encounter_mesh.mesh = creature
	encounter_mesh.position = Vector3(6,1.25,3)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.65,0.12,0.16)
	encounter_mesh.material_override = mat
	encounter_mesh.visible = false
	add_child(encounter_mesh)

func _apparition_monstre() -> void:
	loic.evenement_monstre()
	_log("Un monstre menace les environs. Loïc doit choisir.")
	_refresh()

func _rencontre(who: String) -> void:
	var intent := "saluer"
	if loic.ennemi_proche:
		intent = "demander_aide"
	elif loic.traits.empathie > 0.7 and loic.stats.endurance > 20:
		intent = "aider"
	var result := social.converse(loic,who,intent)
	loic.choisir("parler")
	_sauver_social()
	_log(result)

func _sauver_social() -> void:
	var f := FileAccess.open("user://loic_social.json",FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(social.acquaintances))

func charger_social() -> void:
	if not FileAccess.file_exists("user://loic_social.json"):
		return
	var f := FileAccess.open("user://loic_social.json",FileAccess.READ)
	if f:
		var data = JSON.parse_string(f.get_as_text())
		if data is Dictionary:
			social.acquaintances = data
