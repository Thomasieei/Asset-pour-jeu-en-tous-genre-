extends SceneTree
var viewport: SubViewport
var world: Node3D
var camera: Camera3D
var box: AABB
var has_box := false
func _initialize() -> void:
	call_deferred("run")
func bounds(node: Node) -> void:
	if node is MeshInstance3D and node.mesh:
		var b: AABB = node.global_transform * node.mesh.get_aabb()
		box = box.merge(b) if has_box else b
		has_box = true
	for child in node.get_children(): bounds(child)
func run() -> void:
	viewport=SubViewport.new()
	viewport.size=Vector2i(512,512)
	viewport.transparent_bg=true
	viewport.own_world_3d=true
	viewport.msaa_3d=Viewport.MSAA_4X
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	world=Node3D.new()
	viewport.add_child(world)
	var environment_node := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode=Environment.BG_COLOR
	env.background_color=Color(0,0,0,0)
	env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color=Color("cad8ef")
	env.ambient_light_energy=.75
	environment_node.environment=env
	world.add_child(environment_node)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees=Vector3(-45,-35,0)
	sun.light_energy=1.5
	world.add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees=Vector3(20,125,0)
	fill.light_energy=.45
	world.add_child(fill)
	camera=Camera3D.new()
	camera.projection=Camera3D.PROJECTION_ORTHOGONAL
	camera.current=true
	world.add_child(camera)
	var manifest=JSON.parse_string(FileAccess.get_file_as_string("res://seed/visual-review.json" if "--review" in OS.get_cmdline_user_args() else "res://seed/inventory-icons.json"))
	for entry in manifest:
		var resource=load("res://"+entry.model)
		if not resource is PackedScene:
			print("FAIL ",entry.model)
			quit(1)
			return
		var model=resource.instantiate()
		world.add_child(model)
		has_box=false
		bounds(model)
		if not has_box:
			quit(2)
			return
		var center := box.get_center()
		var diameter := box.size.length()
		camera.size=maxf(.01,diameter*1.15)
		camera.position=center+Vector3(1.1,.75,1.6).normalized()*diameter*3
		camera.near=maxf(.001,diameter*.01)
		camera.far=maxf(100,diameter*10)
		camera.look_at(center)
		for _i in range(3): await process_frame
		await RenderingServer.frame_post_draw
		var image := viewport.get_texture().get_image()
		var error := image.save_png("res://"+entry.icon)
		if error!=OK:
			quit(3)
			return
		world.remove_child(model)
		model.queue_free()
	print("RENDERED_ICONS=",manifest.size())
	quit()
