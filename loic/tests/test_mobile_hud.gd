extends SceneTree
var scene: Node3D
var checks: Array = []
var errors: Array = []

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks.append({"check":label,"passed":ok})
	if not ok: errors.append(label)

func click(control: Control) -> void:
	var point := root.get_final_transform()*control.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = point
	Input.parse_input_event(motion)
	await process_frame
	for pressed in [true,false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = point
		event.pressed = pressed
		Input.parse_input_event(event)
		await process_frame

func run() -> void:
	scene = load("res://loic/scenes/monde_loic.tscn").instantiate()
	root.add_child(scene)
	scene.conductor.autonomous = false
	scene.brain.set_process(false)
	scene.set_process(false)
	scene.loic.set_process(false)
	scene.avatar.position = Vector3(2,0,5)
	scene.camera.position = scene.avatar.position+Vector3(0,3.2,scene.camera_distance)
	scene.camera.look_at(scene.avatar.position+Vector3(0,1.6,-4))
	await create_timer(1).timeout
	var ui: PlayerUI = scene.player_ui
	check(scene.camera.projection == Camera3D.PROJECTION_PERSPECTIVE,"Caméra en perspective derrière le joueur")
	var feet: Vector2 = scene.camera.unproject_position(scene.avatar.position)
	var head: Vector2 = scene.camera.unproject_position(scene.avatar.position+Vector3.UP*1.9)
	check(absf(feet.y-head.y)>root.get_visible_rect().size.y*0.22,"Personnage occupe au moins 22% de la hauteur")
	check(scene.admin_panel == null,"Ancien menu d’actions absent")
	for button in [ui.attack_button,ui.jump_button,ui.crouch_button,ui.chat_button,ui.send_button]:
		check(root.get_visible_rect().encloses(button.get_global_rect()),"Bouton accessible : "+button.name)
	await click(ui.crouch_button)
	check(scene.avatar.crouched,"Clic sur icône accroupir agit sur le joueur")
	await click(ui.crouch_button)
	check(not scene.avatar.crouched,"Second clic relève le joueur")
	await click(ui.jump_button)
	check(scene.avatar.jump_time>0,"Clic sur saut déclenche le saut du joueur")
	await click(ui.attack_button)
	check(scene.avatar.attack_cooldown>0,"Clic sur épée déclenche une attaque")
	await click(ui.chat_button)
	check(not ui.panel.visible,"Icône parole ferme le dialogue")
	await click(ui.chat_button)
	check(ui.panel.visible,"Icône parole ouvre le dialogue")
	await click(ui.text_input)
	check(ui.text_input.has_focus(),"Champ de message reçoit réellement le focus")
	scene.avatar.conversations.erase("Loïc")
	ui._show_history()
	var old_count: int = 0
	# Send through GUI events rather than invoking send_message directly.
	ui.text_input.text = "Bonjour Loïc, comment t’appelles-tu ?"
	scene.loic.position = Vector3(25,0,20)
	await click(ui.send_button)
	check(ui.text_input.text.is_empty(),"Bouton Envoyer accepte le message même à distance")
	if LoicAIConfig.local_mode() and LoicAIConfig.enabled():
		var end := Time.get_ticks_msec()+100000
		while ui.pending and Time.get_ticks_msec()<end: await create_timer(0.2).timeout
		check(not ui.pending,"La réponse IA termine la requête")
		check(not ui.output.text.contains("[Réponse simple]"),"Qwen natif répond au message saisi")
	else:
		check(not ui.pending,"Dialogue disponible en cas d’IA désactivée")
	check(scene.avatar.conversations.get("Loïc",[]).size()>=mini(12,old_count+2),"Message et réponse conservés dans l’historique")
	check(not ui.send_button.disabled,"Envoi suivant disponible après réponse")
	check(ui.output.get_parsed_text().contains("Bonjour Loïc, comment t’appelles-tu ?"),"Message envoyé reste effectivement visible à l’écran")
	check(ui.output.get_parsed_text().contains("Loïc :"),"Réponse de l’habitant reste effectivement visible")
	# Full touch/drag/release path on the virtual joystick.
	var point := root.get_final_transform()*(ui.pad.get_global_rect().get_center()+Vector2(50,0))
	var touch := InputEventScreenTouch.new()
	touch.index = 2
	touch.position = point
	touch.pressed = true
	Input.parse_input_event(touch)
	await process_frame
	check(scene.avatar.joystick.x>0.5,"Toucher le joystick produit une direction")
	touch = InputEventScreenTouch.new()
	touch.index = 2
	touch.position = point
	touch.pressed = false
	Input.parse_input_event(touch)
	await process_frame
	check(scene.avatar.joystick == Vector2.ZERO,"Relâcher le joystick arrête le déplacement")
	var before := ui.panel.visible
	var tap := InputEventScreenTouch.new()
	tap.index = 0
	tap.position = root.get_final_transform()*ui.chat_button.get_global_rect().get_center()
	tap.pressed = true
	Input.parse_input_event(tap)
	await process_frame
	tap = InputEventScreenTouch.new()
	tap.index = 0
	tap.position = root.get_final_transform()*ui.chat_button.get_global_rect().get_center()
	tap.pressed = false
	Input.parse_input_event(tap)
	await process_frame
	check(ui.panel.visible != before,"Toucher l’icône parole actionne le bouton")
	ui.panel.show()
	ui.keyboard_height = 260
	ui._layout()
	check(ui.panel.get_global_rect().end.y<=root.get_visible_rect().size.y-220,"Saisie remontée au-dessus du clavier")
	ui.keyboard_height = 0
	ui._layout()
	check(scene.scenery.constrain_step(Vector3(10,0,-3),Vector3(10,0,-8)) == Vector3(10,0,-3),"Berge empêche de marcher dans la rivière")
	check(scene.scenery.constrain_step(Vector3(-2,0,-3),Vector3(-2,0,-8)) == Vector3(-2,0,-8),"Pont permet de traverser la rivière")
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OS.get_environment("LOIC_CAPTURE_PATH"))
	var report := {"checks":checks,"errors":errors,"native_ai":LoicAIConfig.local_mode(),"dialogue":ui.output.text,"raw_ai_reply":ui.last_ai_reply,"ai_result":ui.last_ai_result,"completed":root.get_node("LocalModel").completed}
	var f := FileAccess.open("res://loic/tests/validation_mobile_hud.json",FileAccess.WRITE)
	f.store_string(JSON.stringify(report,"  "))
	print(JSON.stringify(report))
	quit(0 if errors.is_empty() else 1)
