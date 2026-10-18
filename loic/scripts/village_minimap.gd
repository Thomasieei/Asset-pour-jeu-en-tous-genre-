extends Control
class_name VillageMinimap
signal pressed()
var host: Node3D

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	var c := size/2
	var radius := size.x*0.48
	draw_circle(c,radius,Color(0.17,0.24,0.14,0.88))
	draw_arc(c,radius,0,TAU,80,Color(0.89,0.88,0.70,0.85),2,true)
	if not host or not host.avatar: return
	var origin: Vector3 = host.avatar.position
	for i in range(-35,35):
		var p := Vector2(float(i)-origin.x,VillageScenery.river_z(i)-origin.z)*2
		if p.length()<radius-6: draw_circle(c+p,5,Color(0.32,0.62,0.66))
	for point in host.scenery.obstacles:
		var p := Vector2(point.x-origin.x,point.z-origin.z)*2
		if p.length()<radius-8: draw_rect(Rect2(c+p-Vector2(4,4),Vector2(8,8)),Color(0.86,0.63,0.32))
	for person in [host.loic]+host.conductor.workers:
		var p := Vector2(person.position.x-origin.x,person.position.z-origin.z)*2
		if p.length()<radius-4: draw_circle(c+p,3,Color(0.94,0.87,0.48))
	var arrow := PackedVector2Array([Vector2(0,-9),Vector2(-6,7),Vector2(0,3),Vector2(6,7)])
	for i in range(arrow.size()): arrow[i] = c+arrow[i].rotated(-host.camera_yaw)
	draw_colored_polygon(arrow,Color.WHITE)
	draw_string(ThemeDB.fallback_font,Vector2(c.x-5,19),"N",HORIZONTAL_ALIGNMENT_LEFT,-1,18,Color.WHITE)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		pressed.emit()
		accept_event()
