class_name Enemy
extends Actor
## Wild skeleton (and boss). States: SPAWN → IDLE ⇄ CHASE ⇄ ATTACK → RETURN; DEAD → corpse
## (extractable) → sink → respawn at a camp spawn point. Never leaves its camp leash.

enum State { SPAWN, IDLE, CHASE, ATTACK, RETURN, DEAD, GONE }

const HPBAR_SHADER := preload("res://shaders/hpbar.gdshader")
const TELEGRAPH_SHADER := preload("res://shaders/telegraph.gdshader")
const PROJECTILE := preload("res://scripts/actors/projectile.gd")

var species_id: String = "ossu"
var sp: Dictionary = {}
var is_boss: bool = false
var camp_center := Vector3.ZERO
var leash: float = 27.0
var spawn_points: Array = []
var home := Vector3.ZERO
var state: State = State.SPAWN
var target: Actor = null
var extractable: bool = false

var _dmg: Big = Big.of(5.0)
var _speed: float = 3.2
var _range: float = 1.9
var _aggro: float = 10.0
var _state_t: float = 0.0
var _think_t: float = 0.0
var _atk_cd: float = 0.0
var _atk_len: float = 1.0
var _atk_hit_done: bool = false
var _atk_count: int = 0
var _slam: bool = false
var _slam_phase: int = 0
var _wander_to := Vector3.ZERO
var _corpse_t: float = 0.0
var _gone_t: float = 0.0
var _hpbar: MeshInstance3D
var _hpbar_mat: ShaderMaterial
var _lag: float = 1.0
var _marker: MeshInstance3D
var _telegraph: MeshInstance3D
var _tele_mat: ShaderMaterial
var _boss_announced: bool = false
var _hurt_t: float = 0.0


func setup(id: String, at: Vector3, center: Vector3, leash_r: float, points: Array) -> void:
	species_id = id
	sp = Data.species(id)
	is_boss = sp["role"] == "boss"
	home = at
	camp_center = center
	leash = leash_r
	spawn_points = points
	display_name = str(sp["name"])


func _ready() -> void:
	add_to_group("enemies")
	var s: float = float(sp.get("scale", 1.0))
	_make_body(0.45 * s, 1.9 * s, 4)
	_make_model(Data.model_path(species_id), str(sp["weapon_r"]), str(sp["weapon_l"]), [], s)
	max_hp = Big.of(float(sp["hp"]))
	hp = max_hp.copy()
	_dmg = Big.of(float(sp["dmg"]))
	_speed = float(sp["speed"])
	_range = float(sp["range"])
	_aggro = 15.0 if is_boss else (12.0 if sp["role"] == "ranged" else 10.0)
	_build_overhead(s)
	global_position = home
	_enter_spawn()


func _build_overhead(s: float) -> void:
	_hpbar = MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(1.3 if not is_boss else 2.6, 0.15 if not is_boss else 0.24)
	_hpbar.mesh = q
	_hpbar_mat = ShaderMaterial.new()
	_hpbar_mat.shader = HPBAR_SHADER
	_hpbar_mat.set_shader_parameter("fill_color", Color(0.95, 0.25, 0.25) if not is_boss else Color(0.85, 0.15, 0.6))
	_hpbar.material_override = _hpbar_mat
	_hpbar.position.y = 2.45 * s
	_hpbar.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_hpbar.visible = false
	add_child(_hpbar)
	var r: int = int(sp["rarity"])
	if r >= 1:
		var l := Label3D.new()
		l.text = "%s  [%s]" % [display_name, sp["rank"]]
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		l.font_size = 48 if not is_boss else 72
		l.outline_size = 14
		l.pixel_size = 0.01
		l.modulate = Data.rarity_color(r)
		l.outline_modulate = Color(0.05, 0.03, 0.1)
		l.position.y = 2.75 * s
		l.visibility_range_end = 30.0
		add_child(l)
	_marker = MeshInstance3D.new()
	var mq := QuadMesh.new()
	mq.size = Vector2(2.6, 2.6) * maxf(s, 1.0)
	mq.orientation = PlaneMesh.FACE_Y
	_marker.mesh = mq
	var mm := StandardMaterial3D.new()
	mm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mm.albedo_color = Color(0.65, 0.4, 1.0, 0.9)
	mm.albedo_texture = load("res://assets/vfx/magic_05.png")
	mm.cull_mode = BaseMaterial3D.CULL_DISABLED
	_marker.material_override = mm
	_marker.position.y = 0.08
	_marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_marker.visible = false
	add_child(_marker)


# ------------------------------------------------------------------ main loop
func _physics_process(delta: float) -> void:
	_state_t += delta
	_atk_cd = maxf(_atk_cd - delta, 0.0)
	invulnerable_t = maxf(invulnerable_t - delta, 0.0)
	_hurt_t = maxf(_hurt_t - delta, 0.0)
	if state == State.GONE:
		_tick_gone(delta)
		return
	apply_gravity(delta)
	match state:
		State.SPAWN:
			velocity.x = 0.0
			velocity.z = 0.0
			if _state_t > 1.4:
				invulnerable_t = 0.0
				_set_state(State.IDLE)
		State.IDLE:
			_tick_idle(delta)
		State.CHASE:
			_tick_chase(delta)
		State.ATTACK:
			_tick_attack(delta)
		State.RETURN:
			_tick_return(delta)
		State.DEAD:
			_tick_dead(delta)
	move_and_slide()
	_update_bar(delta)


func _set_state(s: State) -> void:
	state = s
	_state_t = 0.0


func _update_bar(delta: float) -> void:
	var r := hp_ratio()
	_lag = move_toward(_lag, r, delta * 0.6) if _lag > r else r
	_hpbar.visible = not dead and state != State.SPAWN and r < 0.999
	if _hpbar.visible:
		_hpbar_mat.set_shader_parameter("fill", r)
		_hpbar_mat.set_shader_parameter("lag", _lag)
	if is_boss:
		var p := _player()
		var near := p != null and not dead and flat_distance_to(p) < 26.0
		if near != _boss_announced:
			_boss_announced = near
			Game.boss_state.emit(near, self)


func _target_ok() -> bool:
	return target != null and is_instance_valid(target) and not target.dead


func _player() -> Actor:
	return get_tree().get_first_node_in_group("player") as Actor


func _dist_to_camp(p: Vector3) -> float:
	return Vector2(p.x - camp_center.x, p.z - camp_center.z).length()


## Nearest friendly (player or shadow) inside aggro range and inside the camp area.
func _find_target() -> Actor:
	var best: Actor = null
	var bd := _aggro
	for f in get_tree().get_nodes_in_group("friendly"):
		var a: Actor = f
		if a.dead:
			continue
		if _dist_to_camp(a.global_position) > leash + 2.0:
			continue
		var d := flat_distance_to(a)
		if d < bd:
			bd = d
			best = a
	return best


func _steer(goal_dir: Vector3, speed: float, delta: float) -> void:
	# separation from other enemies so groups do not stack
	var push := Vector3.ZERO
	for e in get_tree().get_nodes_in_group("enemies"):
		if e == self:
			continue
		var o: Actor = e
		if o.dead:
			continue
		var d := global_position - o.global_position
		d.y = 0.0
		var l := d.length()
		var min_d := radius + o.radius + 0.4
		if l < min_d and l > 0.001:
			push += d / l * (min_d - l)
	var v := goal_dir.normalized() * speed + push * 3.0
	velocity.x = move_toward(velocity.x, v.x, 25.0 * delta)
	velocity.z = move_toward(velocity.z, v.z, 25.0 * delta)
	face_dir(goal_dir, delta, 10.0)


func _anim_for_speed() -> void:
	var hv := Vector2(velocity.x, velocity.z).length()
	if hv > 2.2:
		model.play("Running_A", 0.15, clampf(hv / 4.2, 0.7, 1.3))
	elif hv > 0.35:
		model.play("Walking_A", 0.15, clampf(hv / 1.6, 0.7, 1.4))
	else:
		model.play("Idle_Combat" if _target_ok() else "Idle", 0.2)


# ------------------------------------------------------------------ states
func _tick_idle(delta: float) -> void:
	_think_t -= delta
	if _think_t <= 0.0:
		_think_t = 0.35 + randf() * 0.2
		target = _find_target()
		if target:
			_set_state(State.CHASE)
			return
		if randf() < 0.25 and not is_boss:
			var a := randf() * TAU
			_wander_to = home + Vector3(cos(a), 0, sin(a)) * randf_range(1.5, 5.0)
			if _dist_to_camp(_wander_to) > leash - 4.0:
				_wander_to = home
	var to := _wander_to - global_position
	to.y = 0.0
	if _wander_to != Vector3.ZERO and to.length() > 0.6 and not is_boss:
		_steer(to, 1.4, delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, 20.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 20.0 * delta)
	_anim_for_speed()


func _tick_chase(delta: float) -> void:
	if _dist_to_camp(global_position) > leash:
		target = null
		_set_state(State.RETURN)
		return
	_think_t -= delta
	if _think_t <= 0.0:
		_think_t = 0.4
		var t := _find_target()
		if t == null:
			target = null
			_set_state(State.RETURN)
			return
		target = t
	if not _target_ok():
		target = null
		_set_state(State.RETURN)
		return
	var to := target.global_position - global_position
	to.y = 0.0
	var dist := to.length() - target.radius
	if dist <= _range:
		velocity.x = move_toward(velocity.x, 0.0, 30.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 30.0 * delta)
		face_dir(to, delta, 12.0)
		if _atk_cd <= 0.0:
			_start_attack()
			return
		model.play("Idle_Combat", 0.2)
	else:
		_steer(to, _speed, delta)
		_anim_for_speed()


func _tick_return(delta: float) -> void:
	var to := home - global_position
	to.y = 0.0
	if to.length() < 1.0:
		velocity.x = 0.0
		velocity.z = 0.0
		heal_full()
		_set_state(State.IDLE)
		return
	# heal while walking back, and ignore taunts until home
	hp = hp.add(max_hp.mulf(0.25 * delta))
	if hp.gt(max_hp):
		hp = max_hp.copy()
	_steer(to, _speed * 1.1, delta)
	_anim_for_speed()
	if _state_t > 12.0:
		global_position = home      # safety net: never stay stuck forever
		heal_full()
		_set_state(State.IDLE)


# ------------------------------------------------------------------ attacks
func _start_attack() -> void:
	_set_state(State.ATTACK)
	_atk_hit_done = false
	_atk_count += 1
	_slam = is_boss and _atk_count % 3 == 0
	_slam_phase = 0
	var anim_name := "Spellcast_Shoot" if sp["role"] == "ranged" else \
			("1H_Melee_Attack_Chop" if _atk_count % 2 == 0 else "1H_Melee_Attack_Slice_Diagonal")
	if _slam:
		anim_name = "Spellcast_Shoot"
		_show_telegraph(true)
		model.play(anim_name, 0.1, 0.55, true)
		_atk_len = 1.5
	else:
		var spd := 1.0 if not is_boss else 0.8
		model.play(anim_name, 0.1, spd, true)
		_atk_len = model.anim_length(anim_name) / spd


func _tick_attack(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, 30.0 * delta)
	velocity.z = move_toward(velocity.z, 0.0, 30.0 * delta)
	if _target_ok() and not _slam:
		face_dir(target.global_position - global_position, delta, 8.0)
	if _slam:
		_tick_slam(delta)
		return
	if not _atk_hit_done and _state_t >= _atk_len * 0.45:
		_atk_hit_done = true
		if _target_ok():
			if sp["role"] == "ranged":
				_shoot(target)
			else:
				var dist := flat_distance_to(target) - target.radius
				if dist <= _range + 0.8:
					var r := Combat.random_roll(_dmg, 0.05, 1.5)
					if target.take_damage(r["amount"], r["crit"], self):
						Sfx.play("hit", -8.0)
	if _state_t >= _atk_len:
		_atk_cd = float(sp["atk_cd"])
		_set_state(State.CHASE)


func _tick_slam(_delta: float) -> void:
	var tele_time := 1.3
	if _slam_phase == 0:
		_tele_mat.set_shader_parameter("progress", clampf(_state_t / tele_time, 0.0, 1.0))
		if _state_t >= tele_time:
			_slam_phase = 1
			model.play("1H_Melee_Attack_Chop", 0.05, 1.6, true)
	elif _slam_phase == 1 and _state_t >= tele_time + 0.25:
		_slam_phase = 2
		_show_telegraph(false)
		var radius_aoe := 5.5
		for f in get_tree().get_nodes_in_group("friendly"):
			var a: Actor = f
			if a.dead:
				continue
			if flat_distance_to(a) <= radius_aoe + a.radius:
				var r := Combat.random_roll(_dmg.mulf(2.2), 0.0, 1.0)
				a.take_damage(r["amount"], false, self)
		Fx.ring_burst(global_position, Color(1.0, 0.4, 0.2))
		Fx.spark(global_position + Vector3(0, 0.4, 0))
		Sfx.play("hit_heavy", 0.0, 0.05)
		Game.camera_shake.emit(0.6)
	elif _slam_phase == 2 and _state_t >= tele_time + 0.9:
		_atk_cd = float(sp["atk_cd"])
		_set_state(State.CHASE)


func _show_telegraph(on: bool) -> void:
	if _telegraph == null:
		_telegraph = MeshInstance3D.new()
		var q := QuadMesh.new()
		q.size = Vector2(11.0, 11.0)
		q.orientation = PlaneMesh.FACE_Y
		_telegraph.mesh = q
		_tele_mat = ShaderMaterial.new()
		_tele_mat.shader = TELEGRAPH_SHADER
		_telegraph.material_override = _tele_mat
		_telegraph.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_telegraph.top_level = true
		add_child(_telegraph)
	_telegraph.visible = on
	if on:
		_telegraph.global_position = global_position + Vector3(0, 0.12, 0)
		_tele_mat.set_shader_parameter("progress", 0.0)


func _shoot(t: Actor) -> void:
	var p: Node3D = PROJECTILE.new()
	get_parent().add_child(p)
	p.global_position = global_position + Vector3(0, 1.5, 0) + facing() * 0.6
	p.call("launch", t, Combat.random_roll(_dmg, 0.05, 1.5), self)


# ------------------------------------------------------------------ damage / death
func take_damage(amount: Big, crit: bool, from: Node3D) -> bool:
	if state == State.SPAWN or state == State.GONE:
		return false
	var ok := super.take_damage(amount, crit, from)
	if ok and not dead:
		# retaliate against the attacker if it is inside the camp
		if from is Actor and (state == State.IDLE or state == State.RETURN) \
				and _dist_to_camp((from as Actor).global_position) <= leash + 2.0:
			target = from as Actor
			_set_state(State.CHASE)
		if not is_boss and state != State.ATTACK and _hurt_t <= 0.0:
			model.play("Hit_A", 0.05, 1.5, true)
			_hurt_t = 0.45
	return ok


func _die(killer: Node3D) -> void:
	super._die(killer)
	_set_state(State.DEAD)
	if _telegraph:
		_telegraph.visible = false
	velocity = Vector3.ZERO
	model.play("Death_A", 0.1, 1.0, true)
	Sfx.play("hit_heavy", -4.0, 0.15)
	# rewards: real values from data, scaled by bonuses inside Game
	Game.add_xp(Big.of(float(sp["xp"])))
	Game.add_gold(Big.of(float(sp["gold"])))
	Game.give_army_xp(float(sp["xp"]) * 0.6)
	Game.stats["kills"] = int(Game.stats["kills"]) + 1
	if is_boss:
		Game.stats["boss_kills"] = int(Game.stats["boss_kills"]) + 1
		Game.notify("%s vaincu !" % display_name, Color(1.0, 0.8, 0.3))
	Fx.damage_number(global_position + Vector3(0, 1.4, 0), "+%s or" % Big.of(float(sp["gold"]) * Game.factor("gold_gain")).floor_big().fmt(), false, Color(1.0, 0.85, 0.3))
	extractable = true
	_corpse_t = 25.0 if is_boss else 14.0
	_marker.visible = true
	add_to_group("corpses")


func _tick_dead(delta: float) -> void:
	velocity.x = 0.0
	velocity.z = 0.0
	if extractable:
		_corpse_t -= delta
		var pulse := 0.85 + 0.15 * sin(_state_t * 5.0)
		_marker.scale = Vector3(pulse, 1.0, pulse)
		_marker.rotation.y += delta * 0.8
		if _corpse_t <= 0.0:
			_end_corpse()
	else:
		# sinking into the ground
		model.position.y -= delta * 1.2
		if model.position.y < -2.2:
			_go_away()


func _end_corpse() -> void:
	extractable = false
	_marker.visible = false
	remove_from_group("corpses")
	_set_state(State.DEAD)


## Called by the player's cast. Rolls the real, displayed probability.
func resolve_extraction() -> void:
	if not extractable:
		return
	var chance := Game.extract_chance(species_id)
	var ok := randf() < chance
	_end_corpse()
	Fx.soul_pillar(global_position, ok)
	var inst := {}
	if ok:
		inst = Game.add_shadow(species_id)
		Game.stats["extract_ok"] = int(Game.stats["extract_ok"]) + 1
		Sfx.play("extract", -2.0, 0.0)
		if int(sp["rarity"]) >= 2:
			Sfx.play("rare", -4.0, 0.0)
	else:
		Game.stats["extract_fail"] = int(Game.stats["extract_fail"]) + 1
		Sfx.play("extract_fail", -6.0, 0.0)
	Game.extraction_result.emit(ok, inst, species_id, chance)


func _go_away() -> void:
	_set_state(State.GONE)
	visible = false
	_gone_t = 75.0 if is_boss else randf_range(6.0, 10.0)


func _tick_gone(delta: float) -> void:
	_gone_t -= delta
	if _gone_t <= 0.0:
		if not spawn_points.is_empty() and not is_boss:
			var p: Array = spawn_points[randi() % spawn_points.size()]
			home = Vector3(float(p[0]), 0.0, float(p[1]))
		global_position = home
		velocity = Vector3.ZERO
		_enter_spawn()


func _enter_spawn() -> void:
	dead = false
	target = null
	_atk_count = 0
	extractable = false
	model.position = Vector3.ZERO
	visible = true
	heal_full()
	_lag = 1.0
	invulnerable_t = 1.5
	_set_state(State.SPAWN)
	model.rotation.y = randf() * TAU
	if model.has_anim("Spawn_Ground_Skeletons"):
		model.play("Spawn_Ground_Skeletons", 0.0, 1.0, true)
	else:
		model.play("Idle", 0.0)
