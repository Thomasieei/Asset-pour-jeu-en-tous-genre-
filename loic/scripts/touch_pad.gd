extends Control
class_name LoicTouchPad
signal direction_changed(value: Vector2)
var finger := -1
var stick := Vector2.ZERO

func _draw() -> void:
	var center := size/2
	draw_circle(center,80,Color(0.15,0.19,0.14,0.58))
	draw_arc(center,80,0,TAU,64,Color(0.85,0.87,0.78,0.8),2,true)
	draw_circle(center+stick*42,35,Color(0.77,0.78,0.67,0.75))
	for angle in [0.0,PI/2,PI,PI*1.5]:
		var points := PackedVector2Array([Vector2(-7,-62),Vector2(7,-62),Vector2(0,-73)])
		for i in range(3): points[i] = center+points[i].rotated(angle)
		draw_colored_polygon(points,Color(0.85,0.87,0.78,0.6))

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
