class_name Portraits
extends Node
## Renders a real 3D portrait of every species once (normal and shadow look) into textures.
## Uses an isolated SubViewport world, then frees it: zero runtime cost afterwards.

signal ready_all

static var textures := {}      # "species|shadow" -> Texture2D
static var done: bool = false


static func get_tex(species_id: String, shadow: bool) -> Texture2D:
	return textures.get("%s|%s" % [species_id, shadow], null)


func generate() -> void:
	if done:
		ready_all.emit()
		return
	var vp := SubViewport.new()
	vp.size = Vector2i(256, 256)
	vp.transparent_bg = true
	vp.own_world_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.75, 0.78, 0.9)
	env.ambient_light_energy = 0.7
	var we := WorldEnvironment.new()
	we.environment = env
	vp.add_child(we)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-35, 30, 0)
	light.light_energy = 1.3
	vp.add_child(light)
	var cam := Camera3D.new()
	cam.fov = 34.0
	cam.position = Vector3(0, 1.55, 3.05)
	vp.add_child(cam)
	cam.look_at(Vector3(0, 1.3, 0), Vector3.UP)
	cam.current = true
	for id in Data.SPECIES.keys():
		for shadow in [false, true]:
			var sp: Dictionary = Data.species(id)
			var m := CharModel.new()
			vp.add_child(m)
			m.setup(Data.model_path(id), str(sp["weapon_r"]), str(sp["weapon_l"]))
			m.rotation.y = deg_to_rad(18.0)
			if shadow:
				m.apply_shadow_look()
			m.play("Idle", 0.0)
			for i in 3:
				await get_tree().process_frame
			await RenderingServer.frame_post_draw
			var img := vp.get_texture().get_image()
			if img:
				textures["%s|%s" % [id, shadow]] = ImageTexture.create_from_image(img)
			m.queue_free()
			await get_tree().process_frame
	vp.queue_free()
	done = true
	ready_all.emit()
