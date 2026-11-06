class_name Actor
extends CharacterBody3D
## Shared base for player, enemies and shadow allies.

signal died(actor: Actor)
signal hp_changed

const GRAVITY := 22.0

var model: CharModel
var max_hp: Big = Big.of(100.0)
var hp: Big = Big.of(100.0)
var dead: bool = false
var invulnerable_t: float = 0.0
var display_name: String = ""
var radius: float = 0.45


func _make_body(r: float = 0.45, h: float = 1.9, layer: int = 2) -> void:
	radius = r
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = r
	cap.height = h
	cs.shape = cap
	cs.position.y = h * 0.5
	add_child(cs)
	collision_layer = layer
	collision_mask = 1 | 16          # world + invisible map bounds
	floor_snap_length = 0.4
	safe_margin = 0.04


func _make_model(path: String, weapon_r: String = "", weapon_l: String = "", hidden: Array = [], s: float = 1.0) -> void:
	model = CharModel.new()
	add_child(model)
	model.setup(path, weapon_r, weapon_l, hidden)
	model.scale = Vector3.ONE * s


func hp_ratio() -> float:
	return clampf(hp.ratio(max_hp), 0.0, 1.0)


func is_alive() -> bool:
	return not dead


## Smoothly rotates the model toward a world direction.
func face_dir(dir: Vector3, delta: float, speed: float = 12.0) -> void:
	dir.y = 0.0
	if dir.length_squared() < 0.0001:
		return
	var target_yaw := atan2(dir.x, dir.z)
	model.rotation.y = lerp_angle(model.rotation.y, target_yaw, 1.0 - exp(-speed * delta))


func face_now(dir: Vector3) -> void:
	dir.y = 0.0
	if dir.length_squared() < 0.0001:
		return
	model.rotation.y = atan2(dir.x, dir.z)


func facing() -> Vector3:
	return Vector3(sin(model.rotation.y), 0.0, cos(model.rotation.y))


func apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	else:
		velocity.y = -0.5


## Returns true if the hit landed. Subclasses extend with reactions.
func take_damage(amount: Big, crit: bool, _from: Node3D) -> bool:
	if dead or invulnerable_t > 0.0:
		return false
	hp = hp.sub(amount)
	if hp.lt(Big.of(0.5)):
		hp = Big.zero()
	model.flash()
	hp_changed.emit()
	Fx.damage_number(global_position + Vector3(0, 2.3 * model.scale.y, 0), amount.fmt(), crit, _damage_color())
	if hp.is_zero():
		_die(_from)
	return true


func _damage_color() -> Color:
	return Color.WHITE


func _die(_killer: Node3D) -> void:
	dead = true
	died.emit(self)


func heal_full() -> void:
	hp = max_hp.copy()
	hp_changed.emit()


func flat_distance_to(n: Node3D) -> float:
	var a := global_position
	var b := n.global_position
	return Vector2(a.x - b.x, a.z - b.z).length()
