extends CanvasLayer
class_name PlayerUI
var host: Node3D
var avatar: PlayerAvatar
var panel: PanelContainer
var text_input: LineEdit
var output: RichTextLabel
var target: OptionButton
var profile: ConfirmationDialog
var name_input: LineEdit
var appearance_input: OptionButton
var status_label: Label
var pending := false
var request_target := "Loïc"
var request_phrase := ""
var http: HTTPRequest
var clock := 0.0
var map_dialog: AcceptDialog

func _ready() -> void:
	avatar = host.avatar
	http = HTTPRequest.new()
	http.timeout = 45
	add_child(http)
	http.request_completed.connect(_response)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	var bar := HBoxContainer.new()
	bar.position = Vector2(18,14)
	root.add_child(bar)
	for label in ["Mon personnage","Discuter","Gestion","Me retrouver","Carte","Frapper","+","−"]:
		var button := Button.new()
		button.text = label
		button.custom_minimum_size.y = 46
		bar.add_child(button)
		match label:
			"Mon personnage": button.pressed.connect(_profile)
			"Discuter": button.pressed.connect(func(): panel.visible = not panel.visible)
			"Gestion": button.pressed.connect(func(): host.admin_panel.visible = not host.admin_panel.visible)
			"Me retrouver": button.pressed.connect(func(): host.follow_player = true)
			"Carte": button.pressed.connect(func(): map_dialog.popup_centered(Vector2i(500,420)))
			"Frapper": button.pressed.connect(func(): avatar.strike(host.realm))
			"+": button.pressed.connect(func(): host.camera.size = maxf(16,host.camera.size-4))
			"−": button.pressed.connect(func(): host.camera.size = minf(90,host.camera.size+4))
	status_label = Label.new()
	status_label.position = Vector2(20,66)
	status_label.add_theme_color_override("font_shadow_color",Color.BLACK)
	status_label.add_theme_constant_override("shadow_offset_x",1)
	status_label.add_theme_constant_override("shadow_offset_y",1)
	root.add_child(status_label)
	var pad := LoicTouchPad.new()
	pad.anchor_top = 1
	pad.anchor_bottom = 1
	pad.position = Vector2(24,-185)
	pad.size = Vector2(160,160)
	root.add_child(pad)
	pad.direction_changed.connect(func(value: Vector2): avatar.joystick = value)
	panel = PanelContainer.new()
	panel.anchor_left = 1
	panel.anchor_right = 1
	panel.anchor_top = 1
	panel.anchor_bottom = 1
	panel.position = Vector2(-510,-425)
	panel.size = Vector2(490,405)
	panel.add_theme_stylebox_override("panel",_style())
	root.add_child(panel)
	panel.visible = false
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation",9)
	panel.add_child(v)
	var top := HBoxContainer.new()
	v.add_child(top)
	target = OptionButton.new()
	target.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for person in ["Loïc","Élise","Garen","Monde"]: target.add_item(person)
	target.item_selected.connect(func(_index: int): _show_history())
	top.add_child(target)
	var join := Button.new()
	join.text = "Rejoindre"
	top.add_child(join)
	join.pressed.connect(_join)
	var close := Button.new()
	close.text = "×"
	top.add_child(close)
	close.pressed.connect(func(): panel.hide())
	output = RichTextLabel.new()
	output.custom_minimum_size = Vector2(450,245)
	output.size_flags_vertical = Control.SIZE_EXPAND_FILL
	output.bbcode_enabled = false
	output.scroll_following = true
	v.add_child(output)
	text_input = LineEdit.new()
	text_input.placeholder_text = "Écris ton message…"
	text_input.max_length = 350
	text_input.custom_minimum_size.y = 46
	text_input.text_submitted.connect(func(_text: String): send_message())
	v.add_child(text_input)
	var send := Button.new()
	send.text = "Envoyer"
	send.custom_minimum_size.y = 44
	v.add_child(send)
	send.pressed.connect(send_message)
	_show_history()
	map_dialog = AcceptDialog.new()
	map_dialog.title = "Monde 2 km × 2 km · voyages de démonstration"
	add_child(map_dialog)
	var places := VBoxContainer.new()
	map_dialog.add_child(places)
	for i in range(WorldStream.LANDMARKS.size()):
		var place := Button.new()
		place.text = WorldStream.LANDMARKS[i].name
		place.custom_minimum_size.y = 48
		places.add_child(place)
		place.pressed.connect(func(): host.realm.travel(i); map_dialog.hide())
	profile = ConfirmationDialog.new()
	profile.title = "Ton habitant"
	profile.min_size = Vector2i(440,260)
	profile.get_ok_button().text = "Entrer dans le monde"
	add_child(profile)
	var content := VBoxContainer.new()
	profile.add_child(content)
	var help := Label.new()
	help.text = "Choisis ton nom et ton apparence.\nTu pourras les modifier ensuite."
	content.add_child(help)
	name_input = LineEdit.new()
	name_input.max_length = 24
	name_input.placeholder_text = "Ton nom"
	name_input.custom_minimum_size.y = 48
	content.add_child(name_input)
	appearance_input = OptionButton.new()
	appearance_input.custom_minimum_size.y = 48
	for label in ["Chevalier","Mage","Éclaireur","Barbare"]: appearance_input.add_item(label)
	content.add_child(appearance_input)
	profile.confirmed.connect(_create_profile)
	if not avatar.created and OS.get_environment("LOIC_SKIP_PROFILE") != "1":
		call_deferred("_profile")

func _style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04,0.08,0.1,0.96)
	style.corner_radius_top_left = 14
	style.corner_radius_top_right = 14
	style.corner_radius_bottom_left = 14
	style.corner_radius_bottom_right = 14
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 14
	style.content_margin_bottom = 14
	return style

func _profile() -> void:
	name_input.text = avatar.display_name
	appearance_input.select(PlayerAvatar.MODELS.find(avatar.appearance))
	profile.get_cancel_button().visible = avatar.created
	profile.popup_centered()

func _create_profile() -> void:
	avatar.display_name = name_input.text.strip_edges().left(24)
	if avatar.display_name.is_empty(): avatar.display_name = "Voyageur"
	avatar.set_appearance(PlayerAvatar.MODELS[appearance_input.selected])
	avatar.created = true
	avatar.save_profile()
	output.text = "Bienvenue, "+avatar.display_name+". Déplace-toi avec le cercle tactile, puis parle aux habitants."

func _person(name_: String) -> Node3D:
	if name_ == "Loïc": return host.loic
	for worker in host.conductor.workers:
		if worker.worker_name == name_: return worker
	return host.realm.find_creature(name_)

func _join() -> void:
	var person := _person(target.get_item_text(target.selected))
	if person:
		avatar.destination = person.position + Vector3(1.8,0,1.8)
		avatar.has_destination = true
		host.follow_player = true

func _show_history() -> void:
	var person := target.get_item_text(target.selected)
	output.text = ""
	for message in avatar.conversations.get(person,[]):
		output.append_text((avatar.display_name if message.role == "user" else person)+" : "+str(message.content)+"\n\n")
	if output.text.is_empty(): output.text = "Approche-toi pour discuter avec "+person+". Le Monde peut t'entendre partout."

func send_message() -> void:
	if pending: return
	var phrase := text_input.text.strip_edges()
	if phrase.is_empty(): return
	request_target = target.get_item_text(target.selected)
	var person := _person(request_target)
	if person and avatar.position.distance_to(person.position) > 7:
		output.text = "Tu es trop loin. Utilise « Rejoindre » ou approche-toi avec le cercle tactile."
		return
	if person is WorldCreature: person.hear(phrase,avatar.display_name)
	request_phrase = phrase
	avatar.remember(request_target,"user",phrase)
	text_input.clear()
	text_input.release_focus()
	_show_history()
	if not LoicAIConfig.enabled():
		_fallback()
		return
	var description: String = {"Loïc":"chevalier de 24 ans, optimiste et curieux, qui croit vivre dans un monde parfait","Élise":"habitante soigneuse et patiente qui cultive et construit pour aider son village","Garen":"habitant sérieux, garde et bâtisseur, attaché à la prudence et au travail","Monde":"intelligence qui organise le village"}.get(request_target,"")
	if person is WorldCreature: description = "monstre nommé, " + str(person.state.personality)
	var facts: Dictionary = {"ressources":{"bois":host.conductor.bois,"pierre":host.conductor.pierre,"nourriture":host.conductor.nourriture},"region":host.realm.region_name(avatar.position),"souvenirs_pertinents":NpcMemory.recall(avatar.memories,request_target,phrase)}
	if person is WorldCreature: facts["etat_individuel"] = person.facts()
	var prompt := "Tu es "+request_target+", "+description+". Tu parles au nouvel habitant "+avatar.display_name+". Réponds en français en une ou deux phrases courtes. Tu n’as aucun lien familial avec le joueur. Ne répète pas sa question. Reste dans le monde du village. Ne prétends jamais avoir exécuté une action. Si tu ne sais pas, dis-le. Faits vérifiés : "+JSON.stringify(facts)+" /no_think"
	var messages: Array = [{"role":"system","content":prompt}]
	messages.append_array(avatar.conversations.get(request_target,[]).slice(-6))
	var body := {"model":"local","messages":messages,"temperature":0.5,"max_tokens":100,"chat_template_kwargs":{"enable_thinking":false}}
	pending = true
	var err: Error
	if LoicAIConfig.local_mode(): err = get_tree().root.get_node("LocalModel").request(body,_response,3,"dialogue_"+request_target)
	else: err = http.request(LoicAIConfig.endpoint(),LoicAIConfig.headers(),HTTPClient.METHOD_POST,JSON.stringify(body))
	if err != OK:
		pending = false
		_fallback()
	else:
		output.append_text("\n"+request_target+" réfléchit…")

func _response(result: int, code: int, _headers: PackedStringArray, bytes: PackedByteArray) -> void:
	pending = false
	if result == HTTPRequest.RESULT_SUCCESS and code == 200:
		var parser := JSON.new()
		if parser.parse(bytes.get_string_from_utf8()) == OK and parser.data is Dictionary:
			var choices = parser.data.get("choices",[])
			if choices is Array and not choices.is_empty() and choices[0] is Dictionary:
				var message = choices[0].get("message",{})
				if message is Dictionary:
					var answer := str(message.get("content","")).strip_edges()
					if DialogueGuard.accepts(answer,request_phrase):
						_finish(answer)
						return
	_fallback()

func _fallback() -> void:
	var phrase := request_phrase.to_lower()
	var answer := "Bienvenue au village, "+avatar.display_name+". Que voudrais-tu découvrir ?"
	if request_target == "Élise": answer = "Je m'occupe des cultures et des travaux. Les récoltes doivent mûrir avant de nourrir le village."
	elif request_target == "Garen": answer = "Je veille sur le village et je participe aux constructions. Mieux vaut préparer nos réserves avant de nous aventurer loin."
	elif request_target == "Monde":
		answer = "J'organise les travaux selon nos réserves. Nous avons %d nourritures, %d bois et %d pierres." % [host.conductor.nourriture,host.conductor.bois,host.conductor.pierre]
		var action := ""
		if "arbre" in phrase: action = "planter_arbre"
		elif "maison" in phrase: action = "construire_maison"
		elif "champ" in phrase: action = "cultiver_champ"
		elif "récolt" in phrase or "recolt" in phrase: action = "recolter"
		if not action.is_empty():
			answer = "Travail ajouté : "+action.replace("_"," ") if host.conductor.propose(action,"Demande de "+avatar.display_name) else "Je ne peux pas encore lancer ce travail : vérifions les ressources, la maturité et les travaux en cours."
	elif _person(request_target) is WorldCreature:
		var creature: WorldCreature = _person(request_target)
		answer = "Je suis "+request_target+". "+("Reste à distance de mon territoire." if float(creature.state.trust)<0 else "Tu peux me parler, tant que tu respectes mon territoire.")
	elif "nom" in phrase: answer = "Je m'appelle Loïc, j'ai 24 ans. Et je suis heureux de faire ta connaissance !"
	_finish("[Réponse simple] "+answer)

func _finish(answer: String) -> void:
	avatar.remember(request_target,"assistant",answer)
	if request_target == "Loïc":
		host.loic.entree_dialogue(answer)
		host.loic.relations.joueur = int(host.loic.relations.joueur)+1
		host.loic.sauvegarder()
	if target.get_item_text(target.selected) == request_target: _show_history()

func _process(delta: float) -> void:
	clock += delta
	if clock < 0.5 or not status_label: return
	clock = 0
	_refresh_targets()
	var ai: String = str(get_tree().root.get_node("LocalModel").get("status")) if LoicAIConfig.local_mode() else "Mode ordinateur"
	if not LoicAIConfig.enabled(): ai = "Réponses simples"
	status_label.text = avatar.display_name+" · %d PV · %d XP · " % [int(avatar.health),avatar.experience]+ai+"\n"+host.realm.region_name(avatar.position)+" · x%d z%d · %d FPS\n%d zones chargées · %d monstres actifs" % [int(avatar.position.x),int(avatar.position.z),int(Engine.get_frames_per_second()),host.realm.chunks.size(),host.realm.creatures.size()]

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and avatar:
		avatar.joystick = Vector2.ZERO
		avatar.save_profile()
		host.realm.save_state()
		host.conductor.save_world()
		host.loic.sauvegarder()

func _refresh_targets() -> void:
	var selected := target.get_item_text(target.selected)
	var names: Array[String] = ["Loïc","Élise","Garen","Monde"]
	for creature in host.realm.creatures.values():
		if float(creature.state.health)>0: names.append(str(creature.state.name))
	if names.size() == target.item_count:
		var same := true
		for i in range(names.size()):
			if names[i]!=target.get_item_text(i): same = false
		if same: return
	target.clear()
	for person in names: target.add_item(person)
	var index := names.find(selected)
	target.select(maxi(0,index))
