extends SceneTree
func _initialize() -> void:
	call_deferred("capture")
func capture() -> void:
	var scene: Node3D = load("res://loic/scenes/monde_loic.tscn").instantiate()
	root.add_child(scene)
	var seconds := int(OS.get_environment("LOIC_CAPTURE_SIM_SECONDS"))
	if seconds > 0:
		scene.conductor.use_qwen = false
		for step in range(seconds*5):
			scene.conductor._physics_process(0.2)
			for resident in scene.conductor.workers:
				resident._physics_process(0.2)
		scene.camera.size = 52
	var destination := int(OS.get_environment("LOIC_PREVIEW_REGION"))
	if destination>0:
		scene.realm.travel(destination)
		scene.avatar.created = true
		scene.player_ui._refresh_targets()
	await create_timer(2).timeout
	await RenderingServer.frame_post_draw
	var path := OS.get_environment("LOIC_CAPTURE_PATH")
	if path.is_empty(): path = "user://loic-preview.png"
	var error := root.get_texture().get_image().save_png(path)
	print("Capture: ",path," result=",error)
	quit(error)
