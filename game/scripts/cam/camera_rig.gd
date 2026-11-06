class_name CameraRig
extends Node3D
## Third-person camera: smooth follow, touch orbit, SpringArm wall collision, combat zoom-out.

var target: Node3D
var yaw: float = 0.0         # 0 = looking toward -Z (north)
var pitch: float = -0.42
var base_distance: float = 9.0
var combat_extra: float = 0.0
var sensitivity: float = 1.0

var _arm: SpringArm3D
var cam: Camera3D
var _focus := Vector3.ZERO
var _combat_target := 0.0


func _ready() -> void:
	_arm = SpringArm3D.new()
	_arm.collision_mask = 1          # world only (characters never push the camera)
	_arm.margin = 0.3
	var probe := SphereShape3D.new()
	probe.radius = 0.35
	_arm.shape = probe
	add_child(_arm)
	cam = Camera3D.new()
	cam.fov = 62.0
	cam.near = 0.15
	cam.far = 420.0
	_arm.add_child(cam)
	cam.current = true


func snap() -> void:
	if target:
		_focus = target.global_position + Vector3(0, 1.6, 0)
		global_position = _focus


func orbit(delta_px: Vector2) -> void:
	yaw -= delta_px.x * 0.0055 * sensitivity
	pitch = clampf(pitch - delta_px.y * 0.0045 * sensitivity, -1.15, 0.05)


func set_combat(active: bool, extra: float = 2.5) -> void:
	_combat_target = extra if active else 0.0


## Horizontal forward direction (for camera-relative movement).
func forward_flat() -> Vector3:
	return Vector3(-sin(yaw), 0, -cos(yaw))


func right_flat() -> Vector3:
	var f := forward_flat()
	return Vector3(-f.z, 0, f.x)


func _physics_process(delta: float) -> void:
	if target == null or not is_instance_valid(target):
		return
	var goal := target.global_position + Vector3(0, 1.6, 0)
	_focus = _focus.lerp(goal, 1.0 - exp(-12.0 * delta))
	global_position = _focus
	combat_extra = lerpf(combat_extra, _combat_target, 1.0 - exp(-2.0 * delta))
	rotation = Vector3(pitch, yaw, 0)
	_arm.spring_length = base_distance + combat_extra
