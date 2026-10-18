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
		scene.player_ui.send_message()
		await wait_idle()
		var history: Array = scene.avatar.conversations.get(name_,[])
		var reply := str(history[-1].content) if not history.is_empty() else ""
		replies[name_] = reply
		check(not reply.is_empty() and not reply.begins_with("[Réponse simple]"),name_+" replies using embedded Qwen")
	var file := FileAccess.open(OS.get_environment("LOIC_TEST_REPORT"),FileAccess.WRITE)
	if file: file.store_string(JSON.stringify({"checks":checks,"failures":failures,"replies":replies,"native_platform":OS.get_name(),"model_sha256":local.MODEL_SHA},"  "))
	scene.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
