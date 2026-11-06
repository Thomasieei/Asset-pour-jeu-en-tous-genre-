extends Node
## Visual play-test at phone resolution with REAL simulated touch events (same path as a finger).
## Run:  xvfb-run godot --rendering-driver opengl3 --resolution 2400x1080 --path . -- --playtest
## Screenshots are written to $PLAYTEST_DIR (default user://shots).

var main: Node
var out_dir := ""
var _shot_i := 0
var report: Array = []


func log_line(t: String) -> void:
	print("[PLAYTEST] ", t)
	report.append(t)


func run() -> void:
	out_dir = OS.get_environment("PLAYTEST_DIR")
	if out_dir == "":
		out_dir = ProjectSettings.globalize_path("user://shots")
	DirAccess.make_dir_recursive_absolute(out_dir)
	log_line("window %s  canvas %s" % [DisplayServer.window_get_size(), get_viewport().get_visible_rect().size])
	await _wait(4.0)
	await shot("start")
	var player: Player = main.player
	# ---------------------------------------------------------------- joystick
	var p0 := player.global_position
	var joy := _to_window(Vector2(170, get_viewport().get_visible_rect().size.y - 170))
	_touch(0, joy, true)
	await _wait(0.1)
	for i in 10:
		_drag(0, joy + Vector2(0, -12.0 * (i + 1)) * _scale())
		await get_tree().process_frame
	await _wait(1.2)
	await shot("joystick_hold_forward")
	_drag(0, joy + Vector2(110, -40) * _scale())
	await _wait(1.0)
	await shot("joystick_hold_right")
	_touch(0, joy + Vector2(110, -40) * _scale(), false)
	await _wait(0.4)
	var moved := player.global_position.distance_to(p0)
	log_line("JOYSTICK moved %.2f m -> %s" % [moved, "OK" if moved > 2.0 else "FAIL"])
	# ---------------------------------------------------------------- camera drag (right side)
	var yaw0: float = main.rig.yaw
	var cstart := _to_window(Vector2(get_viewport().get_visible_rect().size.x * 0.62, 330))
	_touch(1, cstart, true)
	for i in 12:
		_drag(1, cstart + Vector2(-15.0 * (i + 1), 0) * _scale())
		await get_tree().process_frame
	_touch(1, cstart + Vector2(-180, 0) * _scale(), false)
	await _wait(0.3)
	log_line("CAMERA yaw change %.2f rad -> %s" % [absf(main.rig.yaw - yaw0), "OK" if absf(main.rig.yaw - yaw0) > 0.2 else "FAIL"])
	await shot("camera_turned")
	# ---------------------------------------------------------------- talk to elder (interact button)
	player.global_position = Vector3(3.2, 0.2, 8.2)
	await _wait(0.6)
	await shot("near_elder")
	await _tap_button("interact")
	await _wait(0.5)
	await shot("elder_dialog")
	# ---------------------------------------------------------------- combat with real buttons
	var cc: Array = main.world.data["spawns"]["camp_center"]
	player.global_position = Vector3(float(cc[0]), 0.3, float(cc[1]) + 9.0)
	main.rig.yaw = 0.0
	await _wait(1.0)
	await shot("arrive_camp")
	var kills0: int = int(Game.stats["kills"])
	var shots_taken := 0
	for t in 40:
		var target: Actor = player._nearest_enemy(30.0)
		if target and player.flat_distance_to(target) > 2.4:
			player.global_position = target.global_position + (player.global_position - target.global_position).normalized() * 2.0
		await _tap_button("attack")
		await _wait(0.3)
		if t == 6 or t == 14:
			await shot("combat_%d" % t)
			shots_taken += 1
		if int(Game.stats["kills"]) - kills0 >= 1 and t > 8:
			break
	log_line("COMBAT kills %d" % (int(Game.stats["kills"]) - kills0))
	await _wait(0.6)
	await shot("after_kill_extract_button")
	var b: Dictionary = main.hud.touch.buttons["extract"]
	log_line("EXTRACT button visible=%s text=%s" % [b["visible"], b["text"]])
	if b["visible"]:
		await _tap_button("extract")
		await _wait(1.6)
		await shot("extract_result")
	# ---------------------------------------------------------------- menus via real taps
	await _tap_control_named("Ombres")
	await _wait(0.8)
	await shot("menu_ombres")
	await _close_panel()
	await _tap_control_named("Bonus")
	await _wait(0.5)
	await shot("menu_bonus")
	await _close_panel()
	await _tap_control_named("Réglages")
	await _wait(0.5)
	await shot("menu_reglages")
	await _close_panel()
	main.hud.open_forge()
	await _wait(0.5)
	await shot("menu_forge")
	await _close_panel()
	# ---------------------------------------------------------------- village tour
	player.global_position = Vector3(0, 0.2, 9.0)
	main.rig.yaw = 0.0
	await _wait(1.2)
	await shot("village_plaza")
	player.global_position = Vector3(0, 0.2, -40.0)
	await _wait(1.0)
	await shot("north_gate")
	var path := out_dir.path_join("report.txt")
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f:
		f.store_string("\n".join(report))
	log_line("DONE")
	get_tree().quit(0)


# ------------------------------------------------------------------ helpers
func _scale() -> float:
	var ws := Vector2(DisplayServer.window_get_size())
	var vs := get_viewport().get_visible_rect().size
	return ws.y / vs.y


func _to_window(canvas_pos: Vector2) -> Vector2:
	return get_tree().root.get_final_transform() * canvas_pos


func _touch(idx: int, pos: Vector2, pressed: bool) -> void:
	var e := InputEventScreenTouch.new()
	e.index = idx
	e.position = pos
	e.pressed = pressed
	Input.parse_input_event(e)


func _drag(idx: int, pos: Vector2) -> void:
	var e := InputEventScreenDrag.new()
	e.index = idx
	e.position = pos
	e.relative = Vector2(0, -12) * _scale()
	Input.parse_input_event(e)


func _tap(pos_window: Vector2) -> void:
	_touch(0, pos_window, true)
	await get_tree().process_frame
	await get_tree().process_frame
	_touch(0, pos_window, false)
	await get_tree().process_frame


func _tap_button(n: String) -> void:
	var b: Dictionary = main.hud.touch.buttons[n]
	await _tap(_to_window(b["center"]))


func _tap_control_named(text: String) -> void:
	for n in main.hud.find_children("*", "Button", true, false):
		var btn: Button = n
		if btn.text == text and btn.is_visible_in_tree():
			await _tap(_to_window(btn.get_global_rect().get_center()))
			return
	log_line("button not found: " + text)


func _close_panel() -> void:
	if main.hud.is_panel_open():
		for n in main.hud._open_panel.find_children("*", "Button", true, false):
			var btn: Button = n
			if btn.icon == UIKit.icon("cross") and btn.is_visible_in_tree():
				await _tap(_to_window(btn.get_global_rect().get_center()))
				await _wait(0.3)
				break
	if main.hud.is_panel_open():
		log_line("panel close button FAILED")
		main.hud._open_panel.queue_free()
		main.hud._panel_closed()
	await _wait(0.2)


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec).timeout


func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	if img == null:
		log_line("no image for " + name)
		return
	_shot_i += 1
	var path := out_dir.path_join("%02d_%s.png" % [_shot_i, name])
	img.save_png(path)
	log_line("shot " + path)
