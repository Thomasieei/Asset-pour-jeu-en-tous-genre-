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
var root_control: Control
var pad: LoicTouchPad
var attack_button: Button
var jump_button: Button
var crouch_button: Button
var chat_button: Button
var send_button: Button
var health_bar: ProgressBar
var heart: Button
var minimap: VillageMinimap
var request_elapsed := 0.0
var last_ai_reply := ""
var last_ai_result := -1
var request_serial := 0
var keyboard_height := 0
var map_dialog: AcceptDialog

func _ready() -> void:
	avatar = host.avatar
	http = HTTPRequest.new()
	http.timeout = 60
	add_child(http)
	http.request_completed.connect(_response)
	root_control = Control.new()
	root_control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root_control)
	root_control.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	health_bar = ProgressBar.new()
	health_bar.show_percentage = false
	health_bar.max_value = 100
	health_bar.value = avatar.health
	health_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg := _style()
	bg.bg_color = Color(0.10,0.15,0.13,0.8)
	var fill := _style()
	fill.bg_color = Color(0.80,0.17,0.18)
	health_bar.add_theme_stylebox_override("background",bg)
	health_bar.add_theme_stylebox_override("fill",fill)
	root_control.add_child(health_bar)
	heart = _round_button("heart",48,"Mon personnage",_profile)
	status_label = Label.new()
	status_label.add_theme_color_override("font_shadow_color",Color.BLACK)
	status_label.add_theme_constant_override("shadow_offset_x",1)
	status_label.add_theme_constant_override("shadow_offset_y",1)
	status_label.add_theme_font_size_override("font_size",17)
	status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root_control.add_child(status_label)
	pad = LoicTouchPad.new()
	pad.name = "Joystick"
	pad.size = Vector2(174,174)
	root_control.add_child(pad)
	pad.direction_changed.connect(func(value: Vector2): avatar.joystick = value)
	attack_button = _round_button("sword",104,"Attaquer",func(): avatar.strike(host.realm))
	jump_button = _round_button("jump",78,"Sauter",func(): avatar.jump())
	crouch_button = _round_button("crouch",78,"S’accroupir",func(): avatar.toggle_crouch())
	chat_button = _round_button("chat",78,"Parler",_toggle_chat)
	minimap = VillageMinimap.new()
	minimap.host = host
	minimap.size = Vector2(145,145)
	root_control.add_child(minimap)
	minimap.pressed.connect(func(): map_dialog.popup_centered(Vector2i(480,400)))
	panel = PanelContainer.new()
	panel.name = "Conversation"
	panel.add_theme_stylebox_override("panel",_style())
	root_control.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation",5)
	panel.add_child(v)
	var top := HBoxContainer.new()
	v.add_child(top)
	target = OptionButton.new()
	target.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for person in ["Loïc","Élise","Garen","Monde","Moussecorne"]: target.add_item(person)
	target.item_selected.connect(func(_index: int): _show_history())
	top.add_child(target)
	var join := Button.new()
	join.icon = load("res://loic/ui/walk.svg")
	join.expand_icon = true
	join.custom_minimum_size = Vector2(36,34)
	join.tooltip_text = "Rejoindre cet habitant"
	top.add_child(join)
	join.pressed.connect(_join)
	var close := Button.new()
	close.icon = load("res://loic/ui/close.svg")
	close.expand_icon = true
	close.custom_minimum_size = Vector2(36,34)
	top.add_child(close)
	close.pressed.connect(func(): panel.hide(); text_input.release_focus(); _hide_keyboard())
	output = RichTextLabel.new()
	output.name = "Messages"
	output.custom_minimum_size = Vector2(0,50)
	output.size_flags_vertical = Control.SIZE_EXPAND_FILL
	output.add_theme_font_size_override("normal_font_size",18)
	output.bbcode_enabled = false
	output.scroll_following = true
	v.add_child(output)
	var compose := HBoxContainer.new()
	v.add_child(compose)
	text_input = LineEdit.new()
	text_input.name = "Saisie"
	text_input.placeholder_text = "Écris ton message…"
	text_input.max_length = 350
	text_input.custom_minimum_size.y = 48
	text_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_input.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_DEFAULT
	text_input.add_theme_font_size_override("font_size",18)
	text_input.text_submitted.connect(func(_text: String): send_message())
	compose.add_child(text_input)
	send_button = Button.new()
	send_button.name = "Envoyer"
	send_button.icon = load("res://loic/ui/send.svg")
	send_button.expand_icon = true
	send_button.custom_minimum_size = Vector2(48,48)
	send_button.tooltip_text = "Envoyer"
	send_button.focus_mode = Control.FOCUS_NONE
	var blue := _style()
	blue.bg_color = Color(0.17,0.39,0.80)
	send_button.add_theme_stylebox_override("normal",blue)
	compose.add_child(send_button)
	send_button.pressed.connect(send_message)
	_show_history()
	get_viewport().size_changed.connect(_layout)
	_layout()
	map_dialog = AcceptDialog.new()
	map_dialog.title = "Carte du monde"
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
	# The game opens directly; the heart opens character customisation.

func _style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08,0.13,0.12,0.88)
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
	if name_ == "Moussecorne": return host.scenery.deer
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
	var history := ""
	for message in avatar.conversations.get(person,[]):
		history += (avatar.display_name if message.role == "user" else person)+" : "+str(message.content)+"\n\n"
	output.text = history if not history.is_empty() else "Bonjour ! Écris-moi ici pour discuter."

func send_message() -> void:
	if pending: return
	var phrase := text_input.text.strip_edges()
	if phrase.is_empty(): return
	request_target = target.get_item_text(target.selected)
	var person := _person(request_target)
	if person is WorldCreature: person.hear(phrase,avatar.display_name)
	request_phrase = phrase
	avatar.remember(request_target,"user",phrase)
	text_input.clear()
	text_input.release_focus()
	_show_history()
	if not LoicAIConfig.enabled():
		_fallback()
		return
	var description: String = {"Loïc":"chevalier de 24 ans, optimiste et curieux, qui croit vivre dans un monde parfait","Élise":"habitante soigneuse et patiente qui cultive et construit pour aider son village","Garen":"habitant sérieux, garde et bâtisseur, attaché à la prudence et au travail","Monde":"intelligence qui organise le village","Moussecorne":"cerf fantastique aux bois couverts de feuilles, prudent et protecteur de la forêt"}.get(request_target,"")
	if person is WorldCreature: description = "monstre nommé, " + str(person.state.personality)
	var facts: Dictionary = {"ressources":{"bois":host.conductor.bois,"pierre":host.conductor.pierre,"nourriture":host.conductor.nourriture},"region":host.realm.region_name(avatar.position),"souvenirs_pertinents":NpcMemory.recall(avatar.memories,request_target,phrase)}
	if person is WorldCreature: facts["etat_individuel"] = person.facts()
	var prompt := "Joue le rôle de "+request_target+", "+description+". Ton nom est "+request_target+". Tu parles à un joueur. Réponds à sa question en français, avec une ou deux phrases. Ne répète pas sa question et n'invente pas d'action accomplie. Faits du jeu : "+JSON.stringify(facts)+" /no_think"
	var introduction: String = {"Loïc":"Je m'appelle Loïc, je suis un chevalier de 24 ans. J'aime découvrir ce monde et ses habitants.","Élise":"Je m'appelle Élise. Je cultive les champs et je participe aux travaux du village.","Garen":"Je m'appelle Garen. Je veille sur le village et je participe aux constructions.","Monde":"J'organise les travaux et les ressources du village.","Moussecorne":"Je suis Moussecorne, le gardien de cette lisière."}.get(request_target,"Je m'appelle "+request_target+" et je vis dans ces terres.")
	var messages: Array = [{"role":"system","content":prompt},{"role":"user","content":"Présente-toi."},{"role":"assistant","content":introduction}]
	messages.append_array(avatar.conversations.get(request_target,[]).slice(-6))
	var body := {"model":"local","messages":messages,"temperature":0.5,"max_tokens":100,"chat_template_kwargs":{"enable_thinking":false}}
	pending = true
	request_elapsed = 0
	request_serial += 1
	send_button.disabled = true
	var err: Error
	if LoicAIConfig.local_mode(): err = get_tree().root.get_node("LocalModel").request(body,_response.bind(request_serial),3,"dialogue_"+request_target)
	else: err = http.request(LoicAIConfig.endpoint(),LoicAIConfig.headers(),HTTPClient.METHOD_POST,JSON.stringify(body))
	if err != OK:
		pending = false
		_fallback()
	else:
		output.append_text("\n"+request_target+" réfléchit…")

func _response(result: int, code: int, _headers: PackedStringArray, bytes: PackedByteArray, serial: int = -1) -> void:
	if serial != -1 and serial != request_serial: return
	if not pending: return
	pending = false
	send_button.disabled = false
	last_ai_result = result
	if result == HTTPRequest.RESULT_SUCCESS and code == 200:
		var parser := JSON.new()
		if parser.parse(bytes.get_string_from_utf8()) == OK and parser.data is Dictionary:
			var choices = parser.data.get("choices",[])
			if choices is Array and not choices.is_empty() and choices[0] is Dictionary:
				var message = choices[0].get("message",{})
				if message is Dictionary:
					var answer := str(message.get("content","")).strip_edges()
					last_ai_reply = answer
					if DialogueGuard.accepts(answer,request_phrase,request_target,avatar.display_name):
						_finish(answer)
						return
	_fallback()

func _fallback() -> void:
	pending = false
	send_button.disabled = false
	var phrase := request_phrase.to_lower()
	var answer := "Bienvenue au village, "+avatar.display_name+". Que voudrais-tu découvrir ?"
	if request_target == "Élise": answer = "Je m'occupe des cultures et des travaux. Les récoltes doivent mûrir avant de nourrir le village."
	elif request_target == "Moussecorne": answer = "Je veille sur cette lisière. Avance doucement et respecte les jeunes arbres."
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
	elif "nom" in phrase or "appell" in phrase: answer = "Je m'appelle Loïc, j'ai 24 ans. Et je suis heureux de faire ta connaissance !"
	_finish("[Réponse simple] "+answer)

func _finish(answer: String) -> void:
	avatar.remember(request_target,"assistant",answer)
	if request_target == "Loïc":
		host.loic.entree_dialogue(answer)
		host.loic.relations.joueur = int(host.loic.relations.joueur)+1
		host.loic.sauvegarder()
	if target.get_item_text(target.selected) == request_target: _show_history()

func _process(delta: float) -> void:
	var kh := DisplayServer.virtual_keyboard_get_height() if DisplayServer.has_feature(DisplayServer.FEATURE_VIRTUAL_KEYBOARD) else 0
	if kh != keyboard_height:
		keyboard_height = kh
		_layout()
	if pending:
		request_elapsed += delta
		if request_elapsed>75:
			request_serial += 1
			http.cancel_request()
			if LoicAIConfig.local_mode(): get_tree().root.get_node("LocalModel").cancel_requests("dialogue_"+request_target)
			_fallback()
	clock += delta
	if clock < 0.5 or not status_label: return
	clock = 0
	_refresh_targets()
	var ai: String = str(get_tree().root.get_node("LocalModel").get("status")) if LoicAIConfig.local_mode() else "Mode ordinateur"
	if not LoicAIConfig.enabled(): ai = "Réponses simples"
	health_bar.value = avatar.health
	status_label.text = "" if not pending else request_target+" réfléchit… %ds" % int(request_elapsed)
	crouch_button.modulate = Color(0.70,0.90,0.48) if avatar.crouched else Color.WHITE

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and avatar:
		avatar.joystick = Vector2.ZERO
		avatar.save_profile()
		host.realm.save_state()
		host.conductor.save_world()
		host.loic.sauvegarder()

func _refresh_targets() -> void:
	var selected := target.get_item_text(target.selected)
	var names: Array[String] = ["Loïc","Élise","Garen","Monde","Moussecorne"]
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

func _round_button(icon_name: String, diameter: float, hint: String, action: Callable) -> Button:
	var button := Button.new()
	button.name = icon_name.capitalize()
	button.icon = load("res://loic/ui/"+icon_name+".svg")
	button.expand_icon = true
	button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.add_theme_constant_override("icon_max_width",int(diameter*0.52))
	button.size = Vector2.ONE*diameter
	button.custom_minimum_size = button.size
	button.focus_mode = Control.FOCUS_NONE
	button.tooltip_text = hint
	for state in ["normal","hover","pressed","disabled"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.12,0.18,0.15,0.66 if state == "normal" else 0.92)
		style.border_color = Color(0.87,0.89,0.81,0.80)
		style.set_border_width_all(2)
		style.set_corner_radius_all(int(diameter/2))
		style.set_content_margin_all(diameter*0.24)
		button.add_theme_stylebox_override(state,style)
	root_control.add_child(button)
	button.pressed.connect(action)
	return button

func _toggle_chat() -> void:
	panel.visible = not panel.visible
	if panel.visible:
		_show_history()
	else:
		text_input.release_focus()
		_hide_keyboard()

func _layout() -> void:
	if not panel: return
	var screen := get_viewport().get_visible_rect().size
	root_control.size = screen
	var w := screen.x
	var h := screen.y
	var inset := 20.0
	if OS.has_feature("android"):
		var safe := DisplayServer.get_display_safe_area()
		var pixels := DisplayServer.window_get_size()
		if pixels.x>0: inset = maxf(inset,float(maxi(safe.position.x,pixels.x-safe.end.x))*w/float(pixels.x)+8)
	health_bar.position = Vector2(inset+40,29)
	health_bar.size = Vector2(170,22)
	heart.position = Vector2(inset,16)
	status_label.position = Vector2(inset+45,58)
	pad.position = Vector2(inset,h-198)
	attack_button.position = Vector2(w-inset-112,h-136)
	jump_button.position = Vector2(w-inset-171,h-223)
	crouch_button.position = Vector2(w-inset-217,h-105)
	chat_button.position = Vector2(w-inset-81,h-309)
	minimap.position = Vector2(w-inset-150,18)
	var panel_width := minf(480,w-490)
	var keyboard := float(keyboard_height)*h/maxf(1,float(DisplayServer.window_get_size().y))
	panel.size = Vector2(panel_width,178)
	panel.position = Vector2((w-panel_width)*0.5,h-194-keyboard)
	if keyboard>0:
		panel.position.y = maxf(8,panel.position.y)
		pad.hide()
	else: pad.show()

func _hide_keyboard() -> void:
	if DisplayServer.has_feature(DisplayServer.FEATURE_VIRTUAL_KEYBOARD): DisplayServer.virtual_keyboard_hide()
