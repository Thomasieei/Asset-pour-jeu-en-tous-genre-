class_name Player
extends Actor
## Player character: camera-relative movement, 3-hit combo, dodge with i-frames, extraction cast.

signal extraction_started
signal respawned

enum State { NORMAL, ATTACK, DODGE, CAST, DEAD }

const RUN_SPEED := 6.2
const WALK_SPEED := 2.6
const COMBO := ["1H_Melee_Attack_Slice_Diagonal", "1H_Melee_Attack_Chop", "1H_Melee_Attack_Stab"]
const ATTACK_SPEED := 1.45
const DODGE_SPEED := 12.0
const DODGE_TIME := 0.38
const DODGE_COOLDOWN := 0.85

var cam: CameraRig
var move_input := Vector2.ZERO          # x right, y forward (from joystick or keyboard)
var state: State = State.NORMAL
var respawn_point := Vector3.ZERO

var _combo_i := 0
var _attack_t := 0.0
var _attack_len := 0.5
var _hit_done := false
var _queued_attack := false
var _dodge_t := 0.0
var _dodge_cd := 0.0
var _dodge_dir := Vector3.FORWARD
var _cast_t := 0.0
var _cast_target: Node = null
var _dead_t := 0.0
var _since_hurt := 99.0
var _step_t := 0.0
var _in_combat_t := 0.0
var _hurt_t := 0.0


func _ready() -> void:
	add_to_group("friendly")
	add_to_group("player")
	display_name = "Vous"
	_make_body(0.42, 1.9, 2)
	_make_model(Data.CHAR_DIR + "knight.glb")
	refresh_stats(true)
	Game.level_up.connect(func(_l): refresh_stats(true))
	Game.forge_changed.connect(func(): refresh_stats(false))


func refresh_stats(full_heal: bool) -> void:
	var ratio := hp_ratio()
	max_hp = Game.player_max_hp()
	hp = max_hp.copy() if full_heal else max_hp.mulf(ratio).floor_big()
	hp_changed.emit()


func in_combat() -> bool:
	return _in_combat_t > 0.0


func _physics_process(delta: float) -> void:
	invulnerable_t = maxf(invulnerable_t - delta, 0.0)
	_dodge_cd = maxf(_dodge_cd - delta, 0.0)
	_since_hurt += delta
	_in_combat_t = maxf(_in_combat_t - delta, 0.0)
	_hurt_t = maxf(_hurt_t - delta, 0.0)
	apply_gravity(delta)
	match state:
		State.NORMAL:
			_tick_move(delta, 0.35 if _hurt_t > 0.0 else 1.0)
		State.ATTACK:
			_tick_attack(delta)
		State.DODGE:
			_tick_dodge(delta)
		State.CAST:
			_tick_cast(delta)
		State.DEAD:
			_tick_dead(delta)
	move_and_slide()
	# passive regeneration out of combat
	if not dead and _since_hurt > 5.0 and hp.lt(max_hp):
		hp = hp.add(max_hp.mulf(0.08 * delta)).floor_big()
		if hp.gt(max_hp):
			hp = max_hp.copy()
		hp_changed.emit()


func _wish_dir() -> Vector3:
	var v := move_input
	if v.length() > 1.0:
		v = v.normalized()
	if cam == null:
		return Vector3(v.x, 0, -v.y)
	return cam.right_flat() * v.x + cam.forward_flat() * v.y


func _tick_move(delta: float, speed_mult: float) -> void:
	var wish := _wish_dir()
	var amount := clampf(move_input.length(), 0.0, 1.0)
	var target_speed := 0.0
	if amount > 0.08:
		target_speed = (WALK_SPEED if amount < 0.55 else RUN_SPEED) * speed_mult
	var hv := Vector3(velocity.x, 0, velocity.z)
	var goal := wish.normalized() * target_speed if amount > 0.08 else Vector3.ZERO
	hv = hv.move_toward(goal, (40.0 if target_speed > 0.0 else 55.0) * delta)
	velocity.x = hv.x
	velocity.z = hv.z
	if amount > 0.08:
		face_dir(wish, delta, 14.0)
	if _hurt_t <= 0.0:
		_update_locomotion_anim(hv.length(), delta)


func _update_locomotion_anim(speed: float, delta: float) -> void:
	# animation always matches the real horizontal speed (no sliding)
	if speed > 3.6:
		model.play("Running_A", 0.15, clampf(speed / RUN_SPEED, 0.75, 1.25))
		_footsteps(delta, 0.3)
	elif speed > 0.4:
		model.play("Walking_A", 0.15, clampf(speed / WALK_SPEED, 0.7, 1.4))
		_footsteps(delta, 0.48)
	else:
		model.play("Idle", 0.2)


func _footsteps(delta: float, interval: float) -> void:
	_step_t -= delta
	if _step_t <= 0.0:
		_step_t = interval
		Sfx.play("step", -14.0, 0.12)


# ------------------------------------------------------------------ attack
func request_attack() -> void:
	if dead:
		return
	match state:
		State.NORMAL:
			_start_attack(0)
		State.ATTACK:
			_queued_attack = true


func _start_attack(i: int) -> void:
	state = State.ATTACK
	_combo_i = i
	_attack_t = 0.0
	_hit_done = false
	_queued_attack = false
	var a: String = COMBO[i]
	_attack_len = model.anim_length(a) / ATTACK_SPEED
	model.play(a, 0.08, ATTACK_SPEED, true)
	Sfx.play("swing", -6.0)
	var t := _nearest_enemy(5.5)
	if t:
		face_now(t.global_position - global_position)
	elif move_input.length() > 0.1:
		face_now(_wish_dir())


func _tick_attack(delta: float) -> void:
	_attack_t += delta
	# small forward drift during the swing, decelerating
	var drift := facing() * (2.2 if _attack_t < _attack_len * 0.4 else 0.0)
	velocity.x = move_toward(velocity.x, drift.x, 30.0 * delta)
	velocity.z = move_toward(velocity.z, drift.z, 30.0 * delta)
	if not _hit_done and _attack_t >= _attack_len * 0.38:
		_hit_done = true
		_deal_hits()
	# chain into next hit after the impact frame
	if _queued_attack and _attack_t >= _attack_len * 0.55:
		_start_attack((_combo_i + 1) % COMBO.size())
		return
	if _attack_t >= _attack_len * 0.92:
		state = State.NORMAL
		_combo_i = 0


func _deal_hits() -> void:
	var finisher := _combo_i == COMBO.size() - 1
	var reach := 3.4 if finisher else 2.8
	var arc_cos := -1.0 if finisher else 0.25
	var base: Big = Game.player_damage().mulf(1.6 if finisher else 1.0)
	var any := false
	for e in get_tree().get_nodes_in_group("enemies"):
		var en: Actor = e
		if en.dead:
			continue
		var to := en.global_position - global_position
		to.y = 0.0
		var dist := to.length() - en.radius
		if dist > reach:
			continue
		if to.length() > 0.3 and facing().dot(to.normalized()) < arc_cos:
			continue
		var r := Combat.random_roll(base, Game.crit_chance(), Data.BASE_CRIT_MULT)
		if en.take_damage(r["amount"], r["crit"], self):
			any = true
			Fx.spark(en.global_position + Vector3(0, 1.2 * en.model.scale.y, 0))
	if any:
		_in_combat_t = 6.0
		Sfx.play("hit_heavy" if finisher else "hit", -3.0)


func _nearest_enemy(max_d: float) -> Actor:
	var best: Actor = null
	var bd := max_d
	for e in get_tree().get_nodes_in_group("enemies"):
		var en: Actor = e
		if en.dead:
			continue
		var d := flat_distance_to(en)
		if d < bd:
			bd = d
			best = en
	return best


# ------------------------------------------------------------------ dodge
func request_dodge() -> void:
	if dead or _dodge_cd > 0.0 or state == State.DODGE or state == State.CAST:
		return
	state = State.DODGE
	_dodge_t = 0.0
	_dodge_cd = DODGE_COOLDOWN
	invulnerable_t = DODGE_TIME + 0.05
	_dodge_dir = _wish_dir().normalized() if move_input.length() > 0.1 else facing()
	face_now(_dodge_dir)
	model.play("Dodge_Forward", 0.05, model.anim_length("Dodge_Forward") / (DODGE_TIME + 0.12), true)
	Sfx.play("swing", -10.0, 0.2)


func _tick_dodge(delta: float) -> void:
	_dodge_t += delta
	var k := 1.0 - (_dodge_t / DODGE_TIME)
	velocity.x = _dodge_dir.x * DODGE_SPEED * maxf(k, 0.2)
	velocity.z = _dodge_dir.z * DODGE_SPEED * maxf(k, 0.2)
	if _dodge_t >= DODGE_TIME:
		state = State.NORMAL


# ------------------------------------------------------------------ extraction cast
func can_cast() -> bool:
	return not dead and (state == State.NORMAL)


func start_extract(corpse: Node) -> void:
	if not can_cast():
		return
	state = State.CAST
	_cast_t = 0.0
	_cast_target = corpse
	velocity.x = 0.0
	velocity.z = 0.0
	face_now((corpse as Node3D).global_position - global_position)
	model.play("Spellcast_Raise", 0.1, 1.0, true)
	extraction_started.emit()


func _tick_cast(delta: float) -> void:
	_cast_t += delta
	velocity.x = 0.0
	velocity.z = 0.0
	if _cast_t >= 0.85 and _cast_target != null:
		var c := _cast_target
		_cast_target = null
		if is_instance_valid(c) and c.has_method("resolve_extraction"):
			c.resolve_extraction()
	if _cast_t >= 1.25:
		state = State.NORMAL


# ------------------------------------------------------------------ damage / death
func take_damage(amount: Big, crit: bool, from: Node3D) -> bool:
	var ok := super.take_damage(amount, crit, from)
	if ok:
		_since_hurt = 0.0
		_in_combat_t = 6.0
		if not dead and state == State.NORMAL and amount.gt(max_hp.mulf(0.12)):
			model.play("Hit_A", 0.05, 1.4, true)
			_hurt_t = 0.32
	return ok


func _damage_color() -> Color:
	return Color(1.0, 0.35, 0.35)


func _die(killer: Node3D) -> void:
	super._die(killer)
	state = State.DEAD
	_dead_t = 0.0
	velocity = Vector3.ZERO
	model.play("Death_A", 0.1, 1.0, true)
	Game.notify("Vous êtes tombé… Renaissance à la chapelle.", Color(1, 0.5, 0.5))


func _tick_dead(delta: float) -> void:
	_dead_t += delta
	velocity.x = 0.0
	velocity.z = 0.0
	if _dead_t > 3.0:
		dead = false
		state = State.NORMAL
		global_position = respawn_point
		heal_full()
		invulnerable_t = 2.0
		model.play("Idle", 0.0, 1.0, true)
		Fx.ring_burst(global_position, Color(0.9, 0.85, 0.5))
		respawned.emit()
