extends Node3D
const LOIC = preload("res://loic/scripts/loic_agent.gd")
var realm: WorldStream
var avatar: PlayerAvatar
var player_ui: PlayerUI
var admin_panel: PanelContainer
var follow_player := true
var camera_offset := Vector3(0,3.2,6.3)
var scenery: VillageScenery
var camera_yaw := 0.0
var camera_finger := -1
var camera_distance := 5.2
var loic: LoicAgent
var conductor: WorldConductor
var brain: LoicBrain
var social: LoicSocial
var brain_clock := 0.0
var world_label: Label
var world_objective: LineEdit
var camera: Camera3D
var world_status_clock := 0.0
var journal_lines: Array[String] = []
var encounter_mesh: Node3D
var log_label: Label
var stats_label: Label
var input_line: LineEdit
var http: HTTPRequest
var pending := false
var ENDPOINT = "http://127.0.0.1:8765/v1/chat/completions"

func _ready() -> void:
	ENDPOINT = LoicAIConfig.endpoint()
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
	_seed_world()
	avatar = PlayerAvatar.new()
	avatar.world = conductor
	avatar.view_camera = camera
	add_child(avatar)
	realm = WorldStream.new()
	realm.host = self
	add_child(realm)
	# The legacy administrative movement menu has been replaced by the HUD.
	player_ui = PlayerUI.new()
	player_ui.host = self
	add_child(player_ui)
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
	scenery = VillageScenery.new()
	add_child(scenery)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40,-35,0)
	sun.light_color = Color(1.0,0.91,0.74)
	sun.directional_shadow_max_distance = 65.0
	sun.shadow_enabled = true
	sun.light_energy = 0.85
	add_child(sun)
	var env := WorldEnvironment.new()
	var sky := Sky.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color(0.24,0.48,0.72)
	sky_material.sky_horizon_color = Color(0.70,0.81,0.84)
	sky_material.ground_horizon_color = Color(0.70,0.81,0.84)
	sky_material.sky_curve = 0.2
	sky.sky_material = sky_material
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.73,0.81,0.92)
	environment.ambient_light_energy = 0.35
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = environment
	add_child(env)
	camera = Camera3D.new()
	camera.position = Vector3(2,3.2,11.3)
	add_child(camera)
	camera.look_at(Vector3(2,1.6,1))
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	camera.fov = 60
	camera.far = 180
	camera.size = 28
	camera.h_offset = 0.55
	camera.current = true

func _creer_interface() -> void:
	var canvas := CanvasLayer.new()
	add_child(canvas)
	var root := PanelContainer.new()
	root.position = Vector2(12,12)
	root.custom_minimum_size = Vector2(370,696)
	root.size = Vector2(370,696)
	canvas.add_child(root)
	admin_panel = root
	root.visible = false
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.055,0.09,0.10,0.94)
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	root.add_theme_stylebox_override("panel",style)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(370,670)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)
	var v := VBoxContainer.new()
	v.custom_minimum_size.x = 350
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation",6)
	scroll.add_child(v)
	var title := Label.new()
	title.text = "LOÏC · LE MONDE VIVANT"
	v.add_child(title)
	stats_label = Label.new()
	stats_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stats_label.custom_minimum_size.x = 350
	v.add_child(stats_label)
	var row := HFlowContainer.new()
	v.add_child(row)
	for choice in ["marcher","courir","sauter","accroupir","esquiver","attaquer","rentrer","dormir","equiper"]:
		var b := Button.new()
		b.text = choice
		row.add_child(b)
		b.pressed.connect(_action.bind(choice))
	var monster := Button.new()
	monster.text = "Explorer la lisière des monstres"
	v.add_child(monster)
	monster.pressed.connect(func(): realm.travel(1))
	var develop := Button.new()
	develop.text = "Monde : décider du prochain travail"
	v.add_child(develop)
	develop.pressed.connect(func(): conductor.think())
	world_label = Label.new()
	world_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	world_label.custom_minimum_size.x = 350
	v.add_child(world_label)
	world_objective = LineEdit.new()
	world_objective.placeholder_text = "Objectif du monde…"
	v.add_child(world_objective)
	world_objective.text_submitted.connect(func(text: String):
		conductor.objective = text.left(400)
		conductor.think()
		conductor.save_world())
	var tools_row := HFlowContainer.new()
	v.add_child(tools_row)
	for intent in ["planter_arbre","cultiver_champ","construire_maison","recolter","ramasser_bois","extraire_pierre"]:
		var tool := Button.new()
		tool.text = intent.replace("_"," ")
		tools_row.add_child(tool)
		tool.pressed.connect(func():
			if not conductor.propose(intent,"Demande du joueur"):
				_log("Ordre refusé : place, ressources, récolte mûre ou ouvrier indisponible."))
	var pause := CheckButton.new()
	pause.text = "Monde autonome actif"
	pause.button_pressed = true
	v.add_child(pause)
	pause.toggled.connect(func(active: bool): conductor.autonomous = active)
	var eyes := Button.new()
	eyes.text = "Observer le monde et les yeux de Loïc"
	v.add_child(eyes)
	eyes.pressed.connect(func():
		var facts := {"loic":WorldEyes.observe(loic),"monde":conductor.observe()}
		var file := FileAccess.open("user://derniere_observation.json",FileAccess.WRITE)
		if file: file.store_string(JSON.stringify(facts,"  "))
		_log("Loïc voit %d éléments. État complet : user://derniere_observation.json" % facts.loic.visibles.size()))
	for who in ["Elise","Garen"]:
		var talk := Button.new()
		talk.text = "Rencontrer " + who
		v.add_child(talk)
		talk.pressed.connect(_rencontre.bind(who))
	input_line = LineEdit.new()
	input_line.placeholder_text = "Parler à Loïc en français..."
	v.add_child(input_line)
	var speak := Button.new()
	speak.text = "Parler à Loïc"
	v.add_child(speak)
	speak.pressed.connect(_parler)
	log_label = Label.new()
	log_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	log_label.custom_minimum_size = Vector2(350,90)
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
	if not LoicAIConfig.enabled():
		_reponse_secours(phrase)
		input_line.clear()
		return
	pending = true
	var memo := loic.souvenirs.slice(maxi(0,loic.souvenirs.size()-8))
	var system_text := "Tu es Loïc, chevalier de 24 ans dans un monde fantasy que tu juges parfait. Tu es optimiste, curieux, prudent parfois, capable de désaccord. Reste en personnage. Réponds en français naturellement et brièvement, en une ou deux phrases. Ne prétends pas avoir agi dans le jeu. Tes souvenirs: "+JSON.stringify(memo)+"; état: "+JSON.stringify(loic.stats)+". /no_think"
	var body := {"model":"local","messages":[{"role":"system","content":system_text},{"role":"user","content":phrase+" /no_think"}],"temperature":0.75,"max_tokens":130,"chat_template_kwargs":{"enable_thinking":false}}
	var err: Error
	if LoicAIConfig.local_mode():
		err = get_tree().root.get_node("LocalModel").request(body,_reponse_modele)
	else:
		err = http.request(ENDPOINT,LoicAIConfig.headers(),HTTPClient.METHOD_POST,JSON.stringify(body))
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
		journal_lines.append(message)
		if journal_lines.size() > 3: journal_lines.pop_front()
		log_label.text = "\n".join(journal_lines)

func _refresh() -> void:
	if stats_label == null or loic == null:
		return
	stats_label.text = "Niveau %s | PV %d | Mana %d | Endurance %d | Faim %d | Fatigue %d\nAction : %s | Monstres vaincus : %d | Souvenirs : %d" % [loic.stats.niveau,loic.stats.vie,loic.stats.mana,loic.stats.endurance,loic.besoins.faim,loic.besoins.fatigue,loic.action,loic.ennemis_vaincus,loic.souvenirs.size()]

func _process(delta: float) -> void:
	if avatar and follow_player:
		var offset := Vector3(0,3.2,camera_distance).rotated(Vector3.UP,camera_yaw)
		camera.position = camera.position.lerp(avatar.position+offset,minf(1,delta*10))
		camera.look_at(avatar.position+Vector3(0,1.6,-4).rotated(Vector3.UP,camera_yaw))
	brain_clock += delta
	world_status_clock += delta
	if world_status_clock > 1 and world_label and conductor:
		world_status_clock = 0
		world_label.text = "MONDE · %s\nNourriture %d · Bois %d · Pierre %d\n%d éléments · %d travaux · Cycle %d" % [conductor.last_source,conductor.nourriture,conductor.bois,conductor.pierre,conductor.constructions.size(),conductor.work_queue.size(),conductor.world_age]
		_refresh()
	if not LoicAIConfig.local_mode() and brain_clock >= 12.0 and loic != null and brain != null:
		brain_clock = 0
		if avatar.position.distance_to(loic.position)<35:
			brain.ponder(loic, WorldEyes.observe(loic))
	if encounter_mesh != null:
		encounter_mesh.visible = loic.ennemi_proche

func _decision_ia(intent: String, motive: String, origin: String) -> void:
	if loic == null or loic.action == "dormir":
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
	encounter_mesh = WorldAssets.instantiate_model("res://packs/kaykit-character-pack-skeletons-1.0/addons/kaykit_character_pack_skeletons/Characters/gltf/Skeleton_Warrior.glb",1.9)
	if encounter_mesh:
		encounter_mesh.position = Vector3(6,0,3)
		encounter_mesh.visible = false
		add_child(encounter_mesh)
		encounter_mesh.add_to_group("world_observable")
		encounter_mesh.set_meta("kind","monstre")

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

func _seed_world() -> void:
	loic.add_to_group("world_observable")
	loic.set_meta("world_id","Loïc")
	if not conductor.constructions.is_empty():
		return
	for i in range(12):
		var angle := i * TAU / 12
		var item := {"id":conductor.next_id,"asset":"arbre" if i%2==0 else "arbre_b","action":"planter_arbre","position":[cos(angle)*42,0,sin(angle)*42],"growth":1.0}
		conductor.next_id += 1
		conductor.constructions.append(item)
		conductor._visualize(item)
	var field := {"id":conductor.next_id,"asset":"champ","action":"cultiver_champ","position":[-42,0,-20],"growth":0.3}
	conductor.next_id += 1
	conductor.constructions.append(field)
	conductor._visualize(field)
	conductor.save_world()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and camera_finger == -1: camera_finger = event.index
		elif not event.pressed and event.index == camera_finger: camera_finger = -1
	elif event is InputEventScreenDrag and event.index == camera_finger:
		camera_yaw -= event.relative.x*0.006
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			camera_distance = maxf(4.8,camera_distance-0.5)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			camera_distance = minf(9,camera_distance+0.5)
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		camera_yaw -= event.relative.x*0.006

func _exit_tree() -> void:
	if is_instance_valid(avatar): avatar.save_profile()
	if is_instance_valid(loic): loic.sauvegarder()
	if is_instance_valid(conductor): conductor.save_world()
