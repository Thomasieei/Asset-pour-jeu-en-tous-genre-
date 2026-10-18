extends Control
class_name LoicTouchPad
signal direction_changed(value: Vector2)
var finger := -1
var stick := Vector2.ZERO

func _draw() -> void:
	var center := size/2
	draw_circle(center,72,Color(0.06,0.1,0.14,0.65))
	draw_arc(center,72,0,TAU,48,Color(0.7,0.85,0.9,0.7),2,true)
	draw_circle(center+stick*50,25,Color(0.6,0.82,0.86,0.95))

func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and finger == -1:
			finger = event.index
			_update_stick(event.position)
		elif not event.pressed and event.index == finger:
			_reset()
		accept_event()
	elif event is InputEventScreenDrag and event.index == finger:
		_update_stick(event.position)
		accept_event()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and finger == -1:
			finger = -2
			_update_stick(event.position)
		elif finger == -2: _reset()
		accept_event()
	elif event is InputEventMouseMotion and finger == -2:
		_update_stick(event.position)
		accept_event()

func _update_stick(point: Vector2) -> void:
	stick = ((point-size/2)/50).limit_length()
	direction_changed.emit(stick)
	queue_redraw()

func _reset() -> void:
	finger = -1
	stick = Vector2.ZERO
	direction_changed.emit(stick)
	queue_redraw()
