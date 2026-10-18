extends SceneTree
var failures: Array[String] = []
var checks := 0
func check(ok: bool, name_: String) -> void:
	checks += 1
	if not ok: failures.append(name_)
	print(("PASS " if ok else "FAIL ")+name_)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var scene: Node3D = load("res://loic/scenes/monde_loic.tscn").instantiate()
	root.add_child(scene)
	await physics_frame
	scene.avatar.set_physics_process(false)
	scene.loic.set_process(false)
	scene.conductor.set_physics_process(false)
	scene.brain.enabled = false
	var avatar: PlayerAvatar = scene.avatar
	var ui: PlayerUI = scene.player_ui
	check(avatar.model != null,"Player model instantiated")
	ui.name_input.text = "Thomas"
	ui.appearance_input.select(1)
	ui._create_profile()
	check(avatar.created and avatar.display_name == "Thomas" and avatar.appearance == "Mage","Player name and appearance created")
	var start := avatar.position
	avatar.move_input(Vector2(1,0),1)
	check(start.distance_to(avatar.position)>2,"Player moves using touch direction")
	for choice in PlayerAvatar.MODELS: check(avatar.set_appearance(choice),"Appearance loads: "+choice)
	avatar.position = Vector3(40,0,40)
	ui.target.select(0)
	ui.text_input.text = "Bonjour"
	ui.send_message()
	check(ui.text_input.text.is_empty() and ui.output.get_parsed_text().contains("Bonjour"),"Message at distance is accepted and visible")
	ui._join()
	check(avatar.has_destination,"Join button creates reachable destination")
	avatar.position = scene.loic.position+Vector3.ONE
	ui.text_input.text = "Salut Loïc"
	ui.send_message()
	check(not avatar.conversations.get("Loïc",[]).is_empty(),"Player speaks directly to Loic")
	check(scene.loic.conversation.begins_with("[Réponse simple]"),"Offline fallback is labelled honestly")
	for index in [1,2]:
		ui.target.select(index)
		var who: Node3D = ui._person(ui.target.get_item_text(index))
		avatar.position = who.position+Vector3(1,0,1)
		ui.text_input.text = "Bonjour"
		ui.send_message()
		check(avatar.conversations.has(who.worker_name),"Player talks to "+who.worker_name)
	ui.target.select(3)
	var jobs: int = scene.conductor.work_queue.size()
	ui.text_input.text = "Plante un arbre"
	ui.send_message()
	check(scene.conductor.work_queue.size() == jobs+1,"World dialogue can schedule a tree")
	avatar.save_profile()
	var copy := PlayerAvatar.new()
	copy.world = scene.conductor
	copy.view_camera = scene.camera
	root.add_child(copy)
	check(copy.display_name==avatar.display_name and copy.appearance==avatar.appearance,"Avatar profile survives reload")
	check(copy.conversations.size()==avatar.conversations.size(),"Conversation histories survive reload")
	var file := FileAccess.open(OS.get_environment("LOIC_TEST_REPORT"),FileAccess.WRITE)
	if file: file.store_string(JSON.stringify({"checks":checks,"failures":failures},"  "))
	copy.queue_free()
	scene.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
