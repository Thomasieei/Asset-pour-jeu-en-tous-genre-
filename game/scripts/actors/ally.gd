class_name Ally
extends Actor
## A summoned shadow. Follows its formation slot; engages enemies the Army assigns nearby.

enum State { SUMMON, FOLLOW, ENGAGE, ATTACK, DOWN }

const PROJECTILE := preload("res://scripts/actors/projectile.gd")

var uid: int = 0
var species_id: String = "ossu"
var sp: Dictionary = {}
var army: Node            # Army
var slot_offset := Vector3.ZERO
var state: State = State.SUMMON
var target: Actor = null

var _state_t: float = 0.0
var _atk_cd: float = 0.0
var _atk_len: float = 1.0
var _hit_done: bool = false
var _down_t: float = 0.0
var _atk_i: int = 0


func setup(inst: Dictionary, army_node: Node) -> void:
	uid = int(inst["uid"])
	species_id = str(inst["sp"])
	sp = Data.species(species_id)
	army = army_node
	display_name = str(sp["name"])


func _ready() -> void:
	add_to_group("friendly")
	add_to_group("allies")
	var s: float = minf(float(sp.get("scale", 1.0)), 1.35)
	_make_body(0.42 * s, 1.8 * s, 8)
	_make_model(Data.model_path(species_id), str(sp["weapon_r"]), str(sp["weapon_l"]), [], s)
	model.apply_shadow_look()
	refresh_stats(true)
	_summon_fx()


func refresh_stats(full: bool) -> void:
	var inst := Game.get_shadow(uid)
	if inst.is_empty():
		return
	var ratio := hp_ratio()
	max_hp = Game.shadow_max_hp(inst)
	hp = max_hp.copy() if full else max_hp.mulf(ratio).floor_big()


func damage() -> Big:
	var inst := Game.get_shadow(uid)
	if inst.is_empty():
		return Big.of(1.0)
	return Game.shadow_damage(inst)


func _summon_fx() -> void:
	state = State.SUMMON
	_state_t = 0.0
	invulnerable_t = 1.0
	if model.has_anim("Spawn_Ground_Skeletons"):
		model.play("Spawn_Ground_Skeletons", 0.0, 1.3, true)
	Fx.ring_burst(global_position)
	Sfx.play("summon", -10.0)


func teleport_to(p: Vector3) -> void:
	global_position = p
	velocity = Vector3.ZERO
	_summon_fx()


func _physics_process(delta: float) -> void:
	_state_t += delta
	_atk_cd = maxf(_atk_cd - delta, 0.0)
	invulnerable_t = maxf(invulnerable_t - delta, 0.0)
	apply_gravity(delta)
	var player: Actor = army.call("get_player")
	if player == null:
		return
	match state:
		State.SUMMON:
			velocity.x = 0.0
			velocity.z = 0.0
			if _state_t > 1.0:
				state = State.FOLLOW
		State.FOLLOW:
			_tick_follow(delta, player)
		State.ENGAGE:
			_tick_engage(delta, player)
		State.ATTACK:
			_tick_attack(delta)
		State.DOWN:
			_tick_down(delta, player)
	if state != State.DOWN:
		move_and_slide()


func _move_to(goal: Vector3, speed: float, delta: float, stop_dist: float) -> float:
	var to := goal - global_position
	to.y = 0.0
	var d := to.length()
	var v := Vector3.ZERO
	if d > stop_dist:
		v = to / d * speed * clampf((d - stop_dist) / 1.5, 0.35, 1.0)
	# separation from other allies
	var push: Vector3 = army.call("separation", self)
	v += push * 3.0
	velocity.x = move_toward(velocity.x, v.x, 30.0 * delta)
	velocity.z = move_toward(velocity.z, v.z, 30.0 * delta)
	var hv := Vector2(velocity.x, velocity.z).length()
	if hv > 0.3:
		face_dir(Vector3(velocity.x, 0, velocity.z), delta, 10.0)
	return d


func _locomotion() -> void:
	var hv := Vector2(velocity.x, velocity.z).length()
	if hv > 2.4:
		model.play("Running_A", 0.15, clampf(hv / 4.5, 0.7, 1.35))
	elif hv > 0.35:
		model.play("Walking_A", 0.15, clampf(hv / 1.6, 0.7, 1.5))
	else:
		model.play("Idle_Combat" if target else "Idle", 0.25)


func _tick_follow(delta: float, player: Actor) -> void:
	var off: Vector3 = army.call("slot_world", slot_offset)
	var slot := player.global_position + off
	var d := flat_distance_to(player)
	if d > 30.0:
		teleport_to(slot)
		return
	var speed := 7.5 if d > 6.0 else 5.5
	_move_to(slot, speed, delta, 0.6)
	_locomotion()
	if _state_t > 0.3:
		_state_t = 0.0
		var t: Actor = army.call("pick_target", self)
		if t:
			target = t
			state = State.ENGAGE


func _attack_range() -> float:
	return float(sp["range"]) if sp["role"] == "ranged" else float(sp["range"]) + 0.2


func _tick_engage(delta: float, player: Actor) -> void:
	if target == null or not is_instance_valid(target) or target.dead or flat_distance_to(player) > 18.0:
		target = null
		state = State.FOLLOW
		return
	var to := target.global_position - global_position
	to.y = 0.0
	var dist := to.length() - target.radius
	if dist <= _attack_range():
		velocity.x = move_toward(velocity.x, 0.0, 30.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 30.0 * delta)
		face_dir(to, delta, 12.0)
		if _atk_cd <= 0.0:
			_start_attack()
		else:
			model.play("Idle_Combat", 0.2)
	else:
		_move_to(target.global_position, float(sp["speed"]) + 1.2, delta, _attack_range() * 0.8)
		_locomotion()


func _start_attack() -> void:
	state = State.ATTACK
	_state_t = 0.0
	_hit_done = false
	_atk_i += 1
	var a := "Spellcast_Shoot" if sp["role"] == "ranged" else \
			("1H_Melee_Attack_Chop" if _atk_i % 2 == 0 else "1H_Melee_Attack_Slice_Diagonal")
	model.play(a, 0.08, 1.15, true)
	_atk_len = model.anim_length(a) / 1.15


func _tick_attack(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, 30.0 * delta)
	velocity.z = move_toward(velocity.z, 0.0, 30.0 * delta)
	if target and is_instance_valid(target) and not target.dead:
		face_dir(target.global_position - global_position, delta, 10.0)
	if not _hit_done and _state_t >= _atk_len * 0.45:
		_hit_done = true
		if target and is_instance_valid(target) and not target.dead:
			var r := Combat.random_roll(damage(), Game.crit_chance(), Data.BASE_CRIT_MULT)
			if sp["role"] == "ranged":
				var p: Node3D = PROJECTILE.new()
				get_parent().add_child(p)
				p.global_position = global_position + Vector3(0, 1.5, 0) + facing() * 0.6
				p.call("launch", target, r, self, Color(0.7, 0.45, 1.0))
			elif flat_distance_to(target) - target.radius <= _attack_range() + 0.8:
				if target.take_damage(r["amount"], r["crit"], self):
					Fx.spark(target.global_position + Vector3(0, 1.1, 0))
	if _state_t >= _atk_len:
		_atk_cd = float(sp["atk_cd"])
		state = State.ENGAGE


func take_damage(amount: Big, crit: bool, from: Node3D) -> bool:
	if state == State.DOWN or state == State.SUMMON:
		return false
	return super.take_damage(amount, crit, from)


func _damage_color() -> Color:
	return Color(0.75, 0.6, 1.0)


func _die(killer: Node3D) -> void:
	super._die(killer)
	state = State.DOWN
	_down_t = 0.0
	target = null
	model.play("Death_A", 0.1, 1.4, true)


func _tick_down(delta: float, player: Actor) -> void:
	_down_t += delta
	if _down_t > 1.2:
		model.position.y -= delta * 1.5
	if _down_t > 8.0:
		dead = false
		model.position.y = 0.0
		refresh_stats(true)
		var off: Vector3 = army.call("slot_world", slot_offset)
		teleport_to(player.global_position + off)
