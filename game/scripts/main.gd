extends Node3D
## Entry point: builds the world, spawns actors, binds the HUD, then hides the loading screen.

const ENEMY_LAYOUT := ["ossu", "ossu", "ossu", "ossu", "garde", "ossu", "garde", "lame", "necro", "garde", "lame", "necro"]

var world: WorldBuilder
var player: Player
var rig: CameraRig
var army: Army
var hud: Hud
var _shake: float = 0.0
var _loading: CanvasLayer


func _ready() -> void:
	_show_loading()
	await get_tree().process_frame
	await get_tree().process_frame
	_build()
	if "--smoke" in OS.get_cmdline_user_args():
		_hide_loading()
		var smoke: Node = load("res://tests/smoke.gd").new()
		smoke.set("main", self)
		add_child(smoke)
		smoke.call("run")
		return
	var portraits := Portraits.new()
	add_child(portraits)
	await portraits.generate()
	_hide_loading()
	if "--playtest" in OS.get_cmdline_user_args():
		var pt: Node = load("res://tests/playtest.gd").new()
		pt.set("main", self)
		add_child(pt)
		pt.call("run")


func _show_loading() -> void:
	_loading = CanvasLayer.new()
	_loading.layer = 50
	add_child(_loading)
	var bg := ColorRect.new()
	bg.color = Color(0.03, 0.03, 0.09)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_loading.add_child(bg)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_loading.add_child(center)
	var vb := VBoxContainer.new()
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(vb)
	var title := UIKit.label("LÉGION D'OMBRE", 64, Color(0.75, 0.6, 1.0), 12)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(title)
	var sub := UIKit.label("Éveil des ombres en cours…", 26, Color(0.8, 0.85, 1.0), 6)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(sub)


func _hide_loading() -> void:
	if _loading == null:
		return
	var tw := create_tween()
	for c in _loading.get_children():
		if c is CanvasItem:
			tw.parallel().tween_property(c, "modulate:a", 0.0, 0.5)
	tw.tween_callback(_loading.queue_free)


func _build() -> void:
	world = WorldBuilder.new()
	world.name = "World"
	add_child(world)
	world.build()
	Fx.attach(world)

	player = Player.new()
	player.name = "Player"
	player.position = world.spawn("player")
	player.respawn_point = world.spawn("respawn")
	world.add_child(player)
	player.model.rotation.y = world.spawn_facing("player")

	rig = CameraRig.new()
	rig.name = "CameraRig"
	world.add_child(rig)
	rig.target = player
	rig.yaw = player.model.rotation.y + PI
	rig.snap()
	player.cam = rig

	army = Army.new()
	army.name = "Army"
	world.add_child(army)
	army.player = player
	army.sync()

	_spawn_enemies()
	_spawn_npcs()

	hud = Hud.new()
	add_child(hud)
	hud.bind(player, army, world, rig)
	hud._apply_settings()
	Game.camera_shake.connect(func(s: float): _shake = maxf(_shake, s))
	player.respawned.connect(func(): army.sync())


func _spawn_enemies() -> void:
	var sp: Dictionary = world.data.get("spawns", {})
	var pts: Array = sp.get("enemies", []).duplicate()
	# closest to the entrance (largest z) get the weakest species
	pts.sort_custom(func(a, b): return float(a[1]) > float(b[1]))
	var cc: Array = sp.get("camp_center", [0, -86])
	var center := Vector3(float(cc[0]), 0, float(cc[1]))
	var leash: float = float(sp.get("camp_leash", 27.0))
	for i in pts.size():
		var p: Array = pts[i]
		var e := Enemy.new()
		e.setup(ENEMY_LAYOUT[i % ENEMY_LAYOUT.size()], Vector3(float(p[0]), 0, float(p[1])), center, leash, [p])
		world.add_child(e)
	var b: Array = sp.get("boss", [0, -107])
	var boss := Enemy.new()
	boss.setup("seigneur", Vector3(float(b[0]), 0, float(b[1])), center, leash, [b])
	world.add_child(boss)


func _spawn_npcs() -> void:
	for d in world.data.get("npcs", []):
		var n := Npc.new()
		n.setup(d)
		world.add_child(n)


func _process(delta: float) -> void:
	if rig == null or rig.cam == null:
		return
	if _shake > 0.0:
		_shake = maxf(_shake - delta * 1.8, 0.0)
		rig.cam.h_offset = randf_range(-1.0, 1.0) * _shake * 0.35
		rig.cam.v_offset = randf_range(-1.0, 1.0) * _shake * 0.35
	elif rig.cam.h_offset != 0.0 or rig.cam.v_offset != 0.0:
		rig.cam.h_offset = 0.0
		rig.cam.v_offset = 0.0
