extends Node3D
class_name LoicAgent

signal journal(message: String)
signal changed()
const SAVE_PATH = "user://loic_unique_save.json"
const ACTIONS = ["observer","marcher","courir","sauter","accroupir","esquiver","attaquer","aider","demander_aide","rentrer","dormir","parler","equiper","se_reposer"]
var age := 24
var nom := "Loïc"
var worldview := "Ce monde est un univers parfait. Je souhaite y trouver ma place."
var stats := {"vie":100.0,"vie_max":100.0,"mana":60.0,"mana_max":60.0,"endurance":100.0,"niveau":1,"experience":0,"force":9}
var traits := {"curiosite":0.82,"empathie":0.77,"courage":0.65,"prudence":0.54,"optimisme":0.94}
var besoins := {"fatigue":0.0,"faim":5.0,"solitude":0.0}
var relations := {"joueur":0}
var inventaire := [{"id":"epee_fer","qte":1},{"id":"pain","qte":2},{"id":"potion_mana","qte":1}]
var equipement := {"arme":"epee_fer","armure":"armure_chevalier"}
var souvenirs: Array = []
var historique: Array = []
var action := "observer"
var temps_action := 0.0
var tick := 0.0
var maison := Vector3(-6,0,-3)
var position_depart := Vector3.ZERO
var cible := Vector3(3,0,3)
var ennemis_vaincus := 0
var ennemi_proche := false
var vie_ennemi := 35.0
var conversation := ""
var visual: Node3D
var player_anim: AnimationPlayer
var status_label: Label
var anim_hint := ""
const MODEL = "res://packs/kaykit-character-pack-adventures-1.0/addons/kaykit_character_pack_adventures/Characters/gltf/Knight.glb"

func _ready() -> void:
	charger()
	if ResourceLoader.exists(MODEL):
		var scene = load(MODEL)
		if scene is PackedScene:
			visual = scene.instantiate()
			add_child(visual)
			player_anim = _find_anim(visual)
	if visual == null:
		visual = Node3D.new()
		add_child(visual)
		var mesh := MeshInstance3D.new()
		var capsule := CapsuleMesh.new()
		capsule.radius = 0.35
		capsule.height = 1.8
		mesh.mesh = capsule
		visual.add_child(mesh)
	position = position_depart
	set_process(true)

func _find_anim(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node
	for child in node.get_children():
		var found := _find_anim(child)
		if found != null:
			return found
	return null

func _jouer_animation(hints: Array) -> void:
	if player_anim == null:
		return
	for lib in player_anim.get_animation_library_list():
		var library := player_anim.get_animation_library(lib)
		for name in library.get_animation_list():
			for hint in hints:
				if String(name).to_lower().contains(str(hint)) and not str(hint).is_empty():
					var full_name := str(name) if lib == "" else str(lib) + "/" + str(name)
					if player_anim.current_animation != full_name:
						player_anim.play(full_name)
					return

func _process(delta: float) -> void:
	tick += delta
	temps_action += delta
	_animer_secours(delta)
	besoins.fatigue = clampf(besoins.fatigue + delta * 0.09,0,100)
	besoins.faim = clampf(besoins.faim + delta * 0.035,0,100)
	stats.mana = minf(stats.mana_max, stats.mana + delta * 0.12)
	if action in ["marcher","courir","rentrer"]:
		var vitesse := 5.0 if action == "courir" else 2.2
		var direction := cible - position
		direction.y = 0
		if direction.length() > 0.22:
			position += direction.normalized() * minf(vitesse * delta,direction.length())
			visual.rotation.y = atan2(direction.x,direction.z)
		else:
			if action == "rentrer":
				choisir("dormir")
			else:
				choisir("observer")
	if action == "dormir":
		besoins.fatigue = maxf(0, besoins.fatigue - delta * 4)
		stats.vie = minf(stats.vie_max,stats.vie + delta)
		if besoins.fatigue < 5 and temps_action > 2:
			choisir("observer")
	if action == "courir":
		stats.endurance = maxf(0,stats.endurance-delta * 6)
	else:
		stats.endurance = minf(100,stats.endurance+delta * 2)
	if action in ["esquiver","attaquer","sauter","accroupir","parler","aider","demander_aide","equiper","se_reposer"] and temps_action > 1.2:
		choisir("observer")
	if tick >= 4:
		tick = 0
		reflechir()
		sauvegarder()
		changed.emit()

func souvenir(texte: String, importance: int = 1) -> void:
	souvenirs.append({"texte":texte.left(250),"importance":importance,"date":Time.get_datetime_string_from_system()})
	if souvenirs.size() > 150:
		souvenirs.pop_front()
	journal.emit(texte)
	changed.emit()

func choisir(prochaine: String) -> bool:
	if prochaine not in ACTIONS:
		return false
	if prochaine == "dormir" and position.distance_to(maison) > 1.8:
		souvenir("Je ne peux dormir que chez moi.")
		return false
	if prochaine == "attaquer" and not ennemi_proche:
		return false
	if prochaine == "courir" and stats.endurance < 10:
		return false
	action = prochaine
	temps_action = 0
	historique.append({"action":action,"date":Time.get_datetime_string_from_system()})
	if historique.size() > 200:
		historique.pop_front()
	match prochaine:
		"dormir":
			_jouer_animation(["lie","sleep","lay"])
		"marcher","rentrer":
			_jouer_animation(["walk"])
		"courir":
			_jouer_animation(["run"])
		"attaquer":
			_jouer_animation(["attack","slash"])
			attaquer_monstre()
		"esquiver":
			_jouer_animation(["dodge","roll"])
		"sauter":
			_jouer_animation(["jump"])
		"accroupir":
			_jouer_animation(["crouch"])
		"parler":
			_jouer_animation(["talk"])
		"observer":
			_jouer_animation(["idle"])
		"equiper":
			equipement.arme = "epee_fer"
	changed.emit()
	return true

func reflechir() -> void:
	if action == "dormir":
		return
	if besoins.fatigue > 66:
		cible = maison
		choisir("rentrer")
		return
	if besoins.faim > 65 and _possede("pain"):
		_consomme("pain")
		besoins.faim = maxf(0,besoins.faim-45)
		souvenir("J'ai mangé du pain pour reprendre des forces.")
	if ennemi_proche:
		if stats.vie < 32 or (traits.prudence > traits.courage and stats.vie < 65):
			choisir("demander_aide")
			souvenir("Un monstre m'inquiète. Je demande de l'aide.",3)
		elif stats.endurance >= 15:
			choisir("attaquer")
		else:
			choisir("esquiver")
		return
	if action in ["observer","parler","se_reposer"]:
		if randf() < traits.curiosite * 0.7:
			cible = Vector3(randf_range(-8,8),0,randf_range(-8,8))
			choisir("marcher")
		else:
			choisir("parler")
			conversation = "Chaque rencontre mérite que je m'y intéresse."

func attaquer_monstre() -> void:
	if not ennemi_proche:
		return
	stats.endurance = maxf(0,stats.endurance-12)
	vie_ennemi -= stats.force
	if vie_ennemi <= 0:
		ennemi_proche = false
		ennemis_vaincus += 1
		stats.experience += 35
		inventaire.append({"id":"essence_monstre","qte":1})
		souvenir("J'ai vaincu un monstre. J'en tire une leçon et une essence.",4)
		if stats.experience >= stats.niveau * 100:
			stats.experience -= stats.niveau * 100
			stats.niveau += 1
			stats.force += 2
			stats.vie_max += 10
			stats.mana_max += 5
			stats.vie = stats.vie_max
			souvenir("Je viens de progresser au niveau "+str(stats.niveau)+".",5)

func _possede(id: String) -> bool:
	for item in inventaire:
		if item.get("id") == id and int(item.get("qte",0)) > 0:
			return true
	return false

func _consomme(id: String) -> void:
	for item in inventaire:
		if item.get("id") == id and int(item.get("qte",0)) > 0:
			item.qte -= 1
			return

func evenement_monstre() -> void:
	ennemi_proche = true
	vie_ennemi = 35
	souvenir("Un monstre est apparu non loin de moi.",2)

func entree_dialogue(reponse: String) -> void:
	conversation = reponse.left(600)
	souvenir("J'ai parlé : "+conversation,2)
	choisir("parler")

func sauvegarder() -> void:
	var state := {"nom":nom,"age":age,"worldview":worldview,"stats":stats,"traits":traits,"besoins":besoins,"relations":relations,"inventaire":inventaire,"equipement":equipement,"souvenirs":souvenirs,"historique":historique,"position":[position.x,position.y,position.z],"ennemis_vaincus":ennemis_vaincus}
	var f := FileAccess.open(SAVE_PATH,FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(state))

func charger() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var f := FileAccess.open(SAVE_PATH,FileAccess.READ)
	if not f:
		return
	var data = JSON.parse_string(f.get_as_text())
	if not data is Dictionary:
		return
	for key in ["stats","traits","besoins","relations","inventaire","equipement","souvenirs","historique","worldview","ennemis_vaincus"]:
		if data.has(key):
			set(key,data[key])
	if data.get("position",[]) is Array and data.position.size() == 3:
		position_depart = Vector3(float(data.position[0]),float(data.position[1]),float(data.position[2]))

func _animer_secours(delta: float) -> void:
	if visual == null:
		return
	var inclinaison := 0.0
	var hauteur := 0.0
	match action:
		"dormir":
			inclinaison = 1.4
			hauteur = 0.35
		"accroupir":
			hauteur = -0.35
		"sauter":
			hauteur = absf(sin(temps_action * 4.0)) * 0.75
		"marcher","rentrer":
			hauteur = absf(sin(temps_action * 8.0)) * 0.06
		"courir":
			hauteur = absf(sin(temps_action * 13.0)) * 0.12
			inclinaison = -0.16
		"esquiver":
			inclinaison = sin(temps_action * 5.0) * 0.55
		"attaquer":
			inclinaison = sin(temps_action * 5.0) * 0.22
	visual.rotation.z = lerp_angle(visual.rotation.z,inclinaison,minf(1.0,delta * 9.0))
	visual.position.y = lerpf(visual.position.y,hauteur,minf(1.0,delta * 12.0))
