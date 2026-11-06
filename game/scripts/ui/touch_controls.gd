class_name TouchControls
extends Control
## Multi-touch layer: floating joystick (left), action buttons (right), camera drag (free area).
## Reads raw touch events in _input so moving + attacking + turning work simultaneously.
## Mouse is supported for desktop testing (emulated mouse events from touch are ignored).

signal action(name: String)

const DEADZONE := 0.14
const JOY_RADIUS := 95.0
const MOUSE_ID := 99

var move_vector := Vector2.ZERO        # x right, y forward
var camera_drag := Vector2.ZERO        # accumulated pixels since last read
var blocked: bool = false
var blockers: Array = []               # Controls whose rects must not start camera drags

var buttons := {}                      # name -> Dictionary
var _joy_id := -1
var _joy_origin := Vector2.ZERO
var _joy_pos := Vector2.ZERO
var _cam_id := -1
var _cam_last := Vector2.ZERO
var _font: Font


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = ThemeDB.fallback_font
	_add_button("attack", "sword_1handed", Color(0.85, 0.25, 0.25), 80.0, "")
	_add_button("dodge", "arrowUp", Color(0.2, 0.55, 0.95), 50.0, "Esquive")
	_add_button("summon", "multiplayer", Color(0.55, 0.3, 0.95), 46.0, "Armée")
	_add_button("extract", "star", Color(0.6, 0.25, 1.0), 62.0, "ÉVEILLER")
	_add_button("interact", "information", Color(0.2, 0.7, 0.45), 50.0, "Parler")
	buttons["extract"]["visible"] = false
	buttons["interact"]["visible"] = false
	resized.connect(_layout)
	_layout()


func _add_button(n: String, icon_name: String, color: Color, r: float, text: String) -> void:
	buttons[n] = {"name": n, "icon": UIKit.icon(icon_name), "color": color, "r": r, "text": text,
		"center": Vector2.ZERO, "visible": true, "enabled": true, "touch": -1, "cooldown": 0.0, "pulse": 0.0}


func _layout() -> void:
	var w := size.x
	var h := size.y
	buttons["attack"]["center"] = Vector2(w - 150, h - 150)
	buttons["dodge"]["center"] = Vector2(w - 300, h - 80)
	buttons["summon"]["center"] = Vector2(w - 92, h - 312)
	buttons["extract"]["center"] = Vector2(w - 296, h - 228)
	buttons["interact"]["center"] = Vector2(w - 430, h - 96)
	queue_redraw()


func set_button(n: String, vis: bool, text: String = "", enabled: bool = true) -> void:
	var b: Dictionary = buttons[n]
	var changed: bool = b["visible"] != vis or (text != "" and b["text"] != text) or b["enabled"] != enabled
	b["visible"] = vis
	b["enabled"] = enabled
	if text != "":
		b["text"] = text
	if changed:
		queue_redraw()


func set_cooldown(n: String, ratio: float) -> void:
	var b: Dictionary = buttons[n]
	if absf(float(b["cooldown"]) - ratio) > 0.01:
		b["cooldown"] = ratio
		queue_redraw()


func release_all() -> void:
	_joy_id = -1
	_cam_id = -1
	move_vector = Vector2.ZERO
	for n in buttons.keys():
		buttons[n]["touch"] = -1
	queue_redraw()


func consume_camera_drag() -> Vector2:
	var d := camera_drag
	camera_drag = Vector2.ZERO
	return d


func _button_at(p: Vector2) -> String:
	for n in buttons.keys():
		var b: Dictionary = buttons[n]
		if not b["visible"]:
			continue
		if p.distance_to(b["center"]) <= float(b["r"]) * 1.15:
			return n
	return ""


func _on_blocker(p: Vector2) -> bool:
	var all: Array = blockers.duplicate()
	all.append_array(get_tree().get_nodes_in_group("ui_blocker"))
	for c in all:
		var ctl := c as Control
		if ctl and is_instance_valid(ctl) and ctl.is_visible_in_tree() and ctl.get_global_rect().has_point(p):
			return true
	return false


func _input(event: InputEvent) -> void:
	if blocked:
		return
	if event is InputEventScreenTouch:
		var t: InputEventScreenTouch = event
		if t.pressed:
			_press(t.index, t.position)
		else:
			_release(t.index, t.position)
	elif event is InputEventScreenDrag:
		var d: InputEventScreenDrag = event
		_drag(d.index, d.position, d.relative)
	elif event is InputEventMouseButton and event.device != InputEvent.DEVICE_ID_EMULATION:
		var mb: InputEventMouseButton = event
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_press(MOUSE_ID, mb.position)
			else:
				_release(MOUSE_ID, mb.position)
	elif event is InputEventMouseMotion and event.device != InputEvent.DEVICE_ID_EMULATION:
		var mm: InputEventMouseMotion = event
		if mm.button_mask & MOUSE_BUTTON_MASK_LEFT:
			_drag(MOUSE_ID, mm.position, mm.relative)


func _press(id: int, p: Vector2) -> void:
	var bn := _button_at(p)
	if bn != "":
		var b: Dictionary = buttons[bn]
		b["touch"] = id
		b["pulse"] = 1.0
		if b["enabled"]:
			action.emit(bn)
		else:
			action.emit(bn + "_disabled")
		get_viewport().set_input_as_handled()
		queue_redraw()
		return
	if _on_blocker(p):
		return
	if p.x < size.x * 0.42 and p.y > size.y * 0.3 and _joy_id == -1:
		_joy_id = id
		_joy_origin = p
		_joy_pos = p
		move_vector = Vector2.ZERO
		get_viewport().set_input_as_handled()
		queue_redraw()
		return
	if _cam_id == -1:
		_cam_id = id
		_cam_last = p


func _release(id: int, _p: Vector2) -> void:
	if id == _joy_id:
		_joy_id = -1
		move_vector = Vector2.ZERO
		queue_redraw()
	if id == _cam_id:
		_cam_id = -1
	for n in buttons.keys():
		if buttons[n]["touch"] == id:
			buttons[n]["touch"] = -1
			queue_redraw()


func _drag(id: int, p: Vector2, rel: Vector2) -> void:
	if id == _joy_id:
		_joy_pos = p
		var v := (p - _joy_origin) / JOY_RADIUS
		if v.length() > 1.0:
			# floating joystick: base follows the finger when pulled too far
			_joy_origin = p - v.normalized() * JOY_RADIUS
			v = v.normalized()
		var l := v.length()
		if l < DEADZONE:
			move_vector = Vector2.ZERO
		else:
			var k := (l - DEADZONE) / (1.0 - DEADZONE)
			move_vector = Vector2(v.x, -v.y).normalized() * k
		queue_redraw()
	elif id == _cam_id:
		camera_drag += rel
		_cam_last = p


func _process(delta: float) -> void:
	var redraw := false
	for n in buttons.keys():
		var b: Dictionary = buttons[n]
		if float(b["pulse"]) > 0.0:
			b["pulse"] = maxf(float(b["pulse"]) - delta * 5.0, 0.0)
			redraw = true
	if redraw:
		queue_redraw()


func _draw() -> void:
	# joystick
	var base := _joy_origin if _joy_id != -1 else Vector2(170, size.y - 170)
	var knob := _joy_pos if _joy_id != -1 else base
	if knob.distance_to(base) > JOY_RADIUS:
		knob = base + (knob - base).normalized() * JOY_RADIUS
	var alpha := 0.85 if _joy_id != -1 else 0.45
	draw_circle(base, JOY_RADIUS + 12, Color(0.05, 0.08, 0.2, 0.45 * alpha))
	draw_arc(base, JOY_RADIUS + 12, 0, TAU, 48, Color(0.3, 0.75, 1.0, alpha), 4.0, true)
	draw_circle(knob, 42, Color(0.25, 0.6, 1.0, 0.75 * alpha))
	draw_arc(knob, 42, 0, TAU, 32, Color(0.8, 0.95, 1.0, alpha), 3.0, true)
	# buttons
	for n in buttons.keys():
		var b: Dictionary = buttons[n]
		if not b["visible"]:
			continue
		var c: Vector2 = b["center"]
		var r: float = float(b["r"])
		var held: bool = int(b["touch"]) != -1
		var col: Color = b["color"]
		if not b["enabled"]:
			col = Color(0.3, 0.32, 0.38)
		var rr := r * (0.92 if held else 1.0) * (1.0 + 0.06 * float(b["pulse"]))
		draw_circle(c + Vector2(0, 4), rr, Color(0, 0, 0, 0.35))
		draw_circle(c, rr, col.darkened(0.35))
		draw_circle(c, rr * 0.86, col.lightened(0.1) if held else col)
		draw_arc(c, rr, 0, TAU, 40, col.lightened(0.55), 4.0, true)
		var cd: float = float(b["cooldown"])
		if cd > 0.0:
			draw_arc(c, rr * 0.5, -PI / 2, -PI / 2 + TAU * cd, 32, Color(0, 0, 0, 0.55), rr, false)
		var tex: Texture2D = b["icon"]
		if tex:
			var s := rr * (1.05 if n == "attack" else 0.95)
			var ic := c - Vector2(s, s) * 0.5 - (Vector2(0, 8) if str(b["text"]) != "" else Vector2.ZERO)
			draw_texture_rect(tex, Rect2(ic, Vector2(s, s)), false, Color(1, 1, 1, 0.95))
		var txt: String = b["text"]
		if txt != "":
			var fs := 18 if r < 60 else 20
			var tw := _font.get_string_size(txt, HORIZONTAL_ALIGNMENT_CENTER, -1, fs).x
			var tp := c + Vector2(-tw * 0.5, rr * 0.62)
			draw_string_outline(_font, tp, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 6, Color(0.02, 0.02, 0.08))
			draw_string(_font, tp, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)
