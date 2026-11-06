class_name CharModel
extends Node3D
## Wraps an imported KayKit character: animation helper with cross-fades and looping,
## weapon attachment to hand bones, "shadow" look, and hit flash.

const LOOPING := ["Idle", "Idle_Combat", "Running_A", "Walking_A", "Spellcasting"]
const SHADOW_SHADER := preload("res://shaders/shadow_unit.gdshader")

static var _scenes := {}
static var _looped := {}
static var _shadow_mats := {}
static var _flash_mat: StandardMaterial3D

var anim: AnimationPlayer
var skeleton: Skeleton3D
var current: String = ""
var _meshes: Array = []
var _flash_t: float = 0.0
var _root: Node3D


static func load_scene(path: String) -> PackedScene:
	if not _scenes.has(path):
		_scenes[path] = load(path)
	return _scenes[path]


func setup(path: String, weapon_r: String = "", weapon_l: String = "", hidden: Array = []) -> void:
	var ps := load_scene(path)
	if ps == null:
		push_error("Missing character " + path)
		return
	_root = ps.instantiate()
	add_child(_root)
	var players := _root.find_children("*", "AnimationPlayer", true, false)
	if not players.is_empty():
		anim = players[0]
		anim.playback_default_blend_time = 0.18
		if not _looped.has(path):
			for n in LOOPING:
				if anim.has_animation(n):
					anim.get_animation(n).loop_mode = Animation.LOOP_LINEAR
			_looped[path] = true
	var skels := _root.find_children("*", "Skeleton3D", true, false)
	if not skels.is_empty():
		skeleton = skels[0]
	for n in _root.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = n
		if hidden.has(str(mi.name)):
			mi.visible = false
			continue
		_meshes.append(mi)
	if weapon_r != "":
		_attach(weapon_r, "handslot.r")
	if weapon_l != "":
		_attach(weapon_l, "handslot.l")
	play("Idle")


func _attach(file: String, bone: String) -> void:
	if skeleton == null or skeleton.find_bone(bone) < 0:
		return
	var ps := load_scene(Data.WEAPON_DIR + file)
	if ps == null:
		return
	var ba := BoneAttachment3D.new()
	ba.bone_name = bone
	skeleton.add_child(ba)
	var w: Node3D = ps.instantiate()
	ba.add_child(w)
	for n in w.find_children("*", "MeshInstance3D", true, false):
		_meshes.append(n)


func has_anim(n: String) -> bool:
	return anim != null and anim.has_animation(n)


func anim_length(n: String) -> float:
	if not has_anim(n):
		return 0.5
	return anim.get_animation(n).length


## Cross-fades into an animation. restart=true replays it even if already current.
func play(n: String, blend: float = -1.0, speed: float = 1.0, restart: bool = false) -> void:
	if anim == null or not anim.has_animation(n):
		return
	if current == n and not restart and anim.is_playing():
		anim.speed_scale = speed
		return
	anim.speed_scale = speed
	anim.play(n, blend)
	if restart:
		anim.seek(0.0, true)
	current = n


func set_speed(speed: float) -> void:
	if anim:
		anim.speed_scale = speed


## Freezes the current pose (used for corpses once the death animation finished).
func pause_anim() -> void:
	if anim:
		anim.pause()


func apply_shadow_look() -> void:
	for mi in _meshes:
		var m: MeshInstance3D = mi
		if m.mesh == null:
			continue
		for i in m.mesh.get_surface_count():
			var src: Material = m.get_active_material(i)
			var tex: Texture2D = null
			if src is BaseMaterial3D:
				tex = (src as BaseMaterial3D).albedo_texture
			var key: int = tex.get_instance_id() if tex else 0
			if not _shadow_mats.has(key):
				var sm := ShaderMaterial.new()
				sm.shader = SHADOW_SHADER
				if tex:
					sm.set_shader_parameter("tex", tex)
				_shadow_mats[key] = sm
			m.set_surface_override_material(i, _shadow_mats[key])


func flash(duration: float = 0.12) -> void:
	if _flash_mat == null:
		_flash_mat = StandardMaterial3D.new()
		_flash_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_flash_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_flash_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		_flash_mat.albedo_color = Color(1, 1, 1, 0.65)
	for mi in _meshes:
		(mi as MeshInstance3D).material_overlay = _flash_mat
	_flash_t = duration


func _process(delta: float) -> void:
	if _flash_t > 0.0:
		_flash_t -= delta
		if _flash_t <= 0.0:
			for mi in _meshes:
				if is_instance_valid(mi):
					(mi as MeshInstance3D).material_overlay = null
