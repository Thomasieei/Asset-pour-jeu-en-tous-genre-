class_name Npc
extends Node3D
## Villager: idle with periodic gestures, or walks a fixed loop on the plaza edge.
## Always stays on its path; turns toward the player when spoken to or approached.

var def: Dictionary = {}
var model: CharModel
var display_name: String = ""
var talk_text: String = ""
var fn: String = ""

var _walker: bool = false
var _angle: float = 0.0
var _radius: float = 12.2
var _pause_t: float = 0.0
var _gesture_t: float = 4.0
var _face_dir := Vector3.FORWARD
var _talking_t: float = 0.0


func setup(d: Dictionary) -> void:
	def = d
	display_name = str(d.get("name", ""))
	talk_text = str(d.get("talk", ""))
	fn = str(d.get("fn", ""))
	_walker = str(d.get("path", "")) == "ring"


func _ready() -> void:
	add_to_group("npcs")
	model = CharModel.new()
	add_child(model)
	model.setup(Data.CHAR_DIR + str(def["model"]))
	var p: Array = def.get("p", [0, 0, 0])
	position = Vector3(float(p[0]), 0.0, float(p[2]))
	if _walker:
		_radius = Vector2(position.x, position.z).length()
		_angle = atan2(position.x, position.z)
	elif def.has("face"):
		var f: Array = def["face"]
		_face_dir = Vector3(float(f[0]), 0, float(f[1])) - position
		model.rotation.y = atan2(_face_dir.x, _face_dir.z)
	var l := Label3D.new()
	l.text = display_name
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.font_size = 44
	l.outline_size = 12
	l.pixel_size = 0.01
	l.modulate = Color(0.85, 1.0, 0.85)
	l.outline_modulate = Color(0.05, 0.08, 0.05)
	l.position.y = 2.55
	l.visibility_range_end = 25.0
	add_child(l)
	_gesture_t = randf_range(3.0, 8.0)


func talk() -> String:
	_talking_t = 4.0
	model.play("Interact", 0.15, 1.0, true)
	return talk_text


func _process(delta: float) -> void:
	_talking_t = maxf(_talking_t - delta, 0.0)
	var player := get_tree().get_first_node_in_group("player") as Node3D
	var near := false
	if player:
		var to := player.global_position - global_position
		to.y = 0.0
		near = to.length() < 3.5
		if near or _talking_t > 0.0:
			model.rotation.y = lerp_angle(model.rotation.y, atan2(to.x, to.z), 1.0 - exp(-6.0 * delta))
	if _walker:
		_tick_walker(delta, near)
	else:
		_tick_idle(delta, near)


func _tick_walker(delta: float, near: bool) -> void:
	if near or _talking_t > 0.0:
		if model.current != "Interact" or not model.anim.is_playing():
			model.play("Idle", 0.25)
		return
	if _pause_t > 0.0:
		_pause_t -= delta
		model.play("Idle", 0.25)
		return
	var speed := 1.25
	_angle += speed / _radius * delta
	var np := Vector3(sin(_angle) * _radius, 0.0, cos(_angle) * _radius)
	var dir := np - position
	position = np
	model.rotation.y = lerp_angle(model.rotation.y, atan2(dir.x, dir.z), 1.0 - exp(-8.0 * delta))
	model.play("Walking_A", 0.2, speed / 1.6)
	if randf() < delta * 0.05:
		_pause_t = randf_range(2.0, 4.0)


func _tick_idle(delta: float, near: bool) -> void:
	if not near and _talking_t <= 0.0:
		model.rotation.y = lerp_angle(model.rotation.y, atan2(_face_dir.x, _face_dir.z), 1.0 - exp(-3.0 * delta))
	_gesture_t -= delta
	var busy := model.current != "Idle" and model.anim != null and model.anim.is_playing()
	if _gesture_t <= 0.0:
		_gesture_t = randf_range(6.0, 11.0)
		if fn == "forge" and model.has_anim("1H_Melee_Attack_Chop"):
			model.play("1H_Melee_Attack_Chop", 0.15, 0.8, true)
		else:
			model.play("Cheer" if randf() < 0.3 else "Interact", 0.15, 1.0, true)
	elif not busy:
		model.play("Idle", 0.25)
