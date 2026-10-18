extends SceneTree
var checks := 0
var failures: Array[String] = []
var local: Node
func check(ok: bool, text: String) -> void:
	checks += 1
	if not ok: failures.append(text)
	print(("PASS " if ok else "FAIL ")+text)
func _initialize() -> void:
	call_deferred("run")
func wait_idle(seconds: float = 90) -> void:
	var elapsed := 0.0
	while (local.thread != null or not local.queue.is_empty()) and elapsed < seconds:
		await create_timer(0.2).timeout
		elapsed += 0.2
func run() -> void:
	local = root.get_node("LocalModel")
	check(ClassDB.class_exists("LoicLocalAI"),"Native Qwen extension registered")
	var scheduler: Node = load("res://loic/scripts/local_model.gd").new()
	var noop := func(_a: int,_b: int,_c: PackedStringArray,_d: PackedByteArray): pass
	scheduler.request({"messages":[]},noop,0,"background")
	scheduler.request({"messages":[]},noop,3,"conversation")
	check(scheduler.queue[0].key=="conversation","Conversation priority outranks background AI")
	scheduler.request({"messages":[],"max_tokens":10},noop,3,"conversation")
	check(scheduler.queue.size()==2 and scheduler.queue[0].body.max_tokens==10,"Queued intentions deduplicated and refreshed")
	scheduler._notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	scheduler._process(0.1)
	check(scheduler.suspended and scheduler.thread == null,"Background pause prevents inference startup")
	scheduler._notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	scheduler.free()
	await wait_idle()
	check(local.loaded,"Embedded GGUF copied, verified and loaded")
	var scene: Node3D = load("res://loic/scenes/monde_loic.tscn").instantiate()
	root.add_child(scene)
	scene.set_process(false)
	scene.brain.enabled = false
	scene.conductor.set_physics_process(false)
	scene.loic.set_process(false)
	scene.avatar.set_physics_process(false)
	scene.avatar.created = true
	scene.avatar.position = Vector3(2,0,5)
	scene.conductor.think()
	await wait_idle()
	check(scene.conductor.last_source == "Qwen local","World receives valid native JSON intention")
	check(scene.conductor.work_queue.size()>0,"Native world intention produces a real job")
	var replies: Dictionary = {}
	for index in range(3):
		var name_: String = ["Loïc","Élise","Garen"][index]
		var who: Node3D = scene.player_ui._person(name_)
		scene.avatar.position = who.position + Vector3(1,0,1)
		scene.player_ui.target.select(index)
		scene.player_ui.text_input.text = "Bonjour, présente-toi en une phrase."
		var before_calls: int = local.completed
		scene.player_ui.send_message()
		await wait_idle()
		var history: Array = scene.avatar.conversations.get(name_,[])
		var reply := str(history[-1].content) if not history.is_empty() else ""
		replies[name_] = reply
		check(not reply.is_empty() and local.completed>before_calls,name_+" native request completes with a delivered response")
	scene.realm.travel(1)
	scene.realm.set_process(false)
	var creature: WorldCreature = scene.realm.find_creature("Silex")
	if creature:
		creature.set_physics_process(false)
		scene.avatar.position = creature.position+Vector3(1,0,1)
		scene.player_ui._refresh_targets()
		for i in range(scene.player_ui.target.item_count):
			if scene.player_ui.target.get_item_text(i)=="Silex": scene.player_ui.target.select(i)
		scene.player_ui.text_input.text = "Bonjour, comment t'appelles-tu ?"
		var before_monster_calls: int = local.completed
		scene.player_ui.send_message()
		await wait_idle()
		var history: Array = scene.avatar.conversations.get("Silex",[])
		var reply := str(history[-1].content) if not history.is_empty() else ""
		replies["Silex"] = reply
		check(not reply.is_empty() and local.completed>before_monster_calls,"Named monster native request completes with a delivered response")
	else: check(false,"Named monster instantiated for native test")
	var file := FileAccess.open(OS.get_environment("LOIC_TEST_REPORT"),FileAccess.WRITE)
	if file: file.store_string(JSON.stringify({"checks":checks,"failures":failures,"replies":replies,"native_platform":OS.get_name(),"model_sha256":local.MODEL_SHA},"  "))
	scene.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
