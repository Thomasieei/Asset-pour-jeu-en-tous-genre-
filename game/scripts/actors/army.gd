class_name Army
extends Node3D
## Centralised army brain: keeps the summoned allies in sync with Game's equipped shadows,
## computes formation slots, shares one enemy scan between all allies and spreads targets.

const ALLY_SCRIPT := preload("res://scripts/actors/ally.gd")

var player: Player
var summoned: bool = true
var allies := {}                 # uid -> Ally
var _enemies_near: Array = []
var _scan_t: float = 0.0
var _assign := {}                # enemy instance id -> number of allies on it


func _ready() -> void:
	Game.army_changed.connect(sync)
	Game.shadows_changed.connect(_refresh_stats)


func get_player() -> Actor:
	return player


func sync() -> void:
	if player == null:
		return
	var wanted := {}
	if summoned:
		for s in Game.equipped_shadows():
			wanted[int(s["uid"])] = s
	for uid in allies.keys():
		if not wanted.has(uid):
			var a: Ally = allies[uid]
			Fx.ring_burst(a.global_position, Color(0.4, 0.3, 0.7))
			a.queue_free()
			allies.erase(uid)
	var keys := wanted.keys()
	keys.sort()
	# formation: an arc behind the player
	var n := keys.size()
	for i in n:
		var uid: int = keys[i]
		var ang := PI + (float(i) - float(n - 1) * 0.5) * 0.62
		var dist := 2.6 + 0.9 * float(i % 2)
		var off := Vector3(sin(ang), 0, cos(ang)) * dist
		if allies.has(uid):
			(allies[uid] as Ally).slot_offset = off
			continue
		var a: Ally = ALLY_SCRIPT.new()
		a.setup(wanted[uid], self)
		a.slot_offset = off
		a.position = player.global_position + slot_world(off)
		get_parent().add_child(a)
		allies[uid] = a


func _refresh_stats() -> void:
	for uid in allies.keys():
		var a: Ally = allies[uid]
		a.refresh_stats(false)


func toggle_summon() -> bool:
	summoned = not summoned
	sync()
	Sfx.play("summon" if summoned else "close", -6.0)
	return summoned


## Offset expressed relative to the player's facing.
func slot_world(offset: Vector3) -> Vector3:
	if player == null:
		return offset
	return offset.rotated(Vector3.UP, player.model.rotation.y)


func separation(who: Actor) -> Vector3:
	var push := Vector3.ZERO
	for uid in allies.keys():
		var o: Ally = allies[uid]
		if o == who or o.dead:
			continue
		push += _push(who, o, 0.5)
	if player and who != player:
		push += _push(who, player, 0.6)
	return push


func _push(a: Actor, b: Actor, extra: float) -> Vector3:
	var d := a.global_position - b.global_position
	d.y = 0.0
	var l := d.length()
	var min_d := a.radius + b.radius + extra
	if l < min_d and l > 0.001:
		return d / l * (min_d - l)
	return Vector3.ZERO


func _physics_process(delta: float) -> void:
	_scan_t -= delta
	if _scan_t > 0.0 or player == null:
		return
	_scan_t = 0.3
	_enemies_near.clear()
	_assign.clear()
	for e in get_tree().get_nodes_in_group("enemies"):
		var en: Actor = e
		if en.dead or not en.visible:
			continue
		if en.flat_distance_to(player) < 14.0:
			_enemies_near.append(en)
	for uid in allies.keys():
		var a: Ally = allies[uid]
		if a._target_ok():
			var k := a.target.get_instance_id()
			_assign[k] = int(_assign.get(k, 0)) + 1


## Spread allies over nearby enemies: score = distance + 4 m per ally already on that enemy.
func pick_target(who: Ally) -> Actor:
	var best: Actor = null
	var bs := INF
	for e in _enemies_near:
		var en: Actor = e
		if not is_instance_valid(en) or en.dead:
			continue
		var score := who.flat_distance_to(en) + 4.0 * float(_assign.get(en.get_instance_id(), 0))
		if score < bs:
			bs = score
			best = en
	if best:
		var k := best.get_instance_id()
		_assign[k] = int(_assign.get(k, 0)) + 1
	return best
