extends SceneTree
var decision_received := false
var dialogue_received := false
var proposed := ""
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var scene: Node3D = load("res://loic/scenes/monde_loic.tscn").instantiate()
	root.add_child(scene)
	await physics_frame
	scene.set_process(false)
	scene.loic.set_process(false)
	scene.conductor.set_physics_process(false)
	scene.brain.decision.connect(func(action: String, _motive: String, _origin: String):
		decision_received = true
		proposed = action)
	scene.conductor.think()
	var elapsed := 0.0
	while scene.conductor.thinking and elapsed < 20:
		await create_timer(0.1).timeout
		elapsed += 0.1
	var world_source: String = scene.conductor.last_source
	var jobs: int = scene.conductor.work_queue.size()
	scene.brain.ponder(scene.loic,WorldEyes.observe(scene.loic))
	elapsed = 0
	while scene.brain.pending and elapsed < 15:
		await create_timer(0.1).timeout
		elapsed += 0.1
	scene.input_line.text = "Bonjour Loïc, quel est ton rêve ?"
	scene._parler()
	elapsed = 0
	while scene.pending and elapsed < 18:
		await create_timer(0.1).timeout
		elapsed += 0.1
	dialogue_received = not scene.loic.conversation.is_empty()
	var data := {"world_source":world_source,"world_jobs":jobs,"loic_valid_decision":decision_received,"loic_action":proposed,"dialogue":scene.loic.conversation,"godot":Engine.get_version_info().string}
	print(JSON.stringify(data))
	var path := OS.get_environment("LOIC_TEST_REPORT")
	if not path.is_empty():
		var file := FileAccess.open(path,FileAccess.WRITE)
		file.store_string(JSON.stringify(data,"  "))
	var ok := world_source == "Qwen local" and jobs>0 and decision_received and dialogue_received
	scene.queue_free()
	await process_frame
	quit(0 if ok else 1)
