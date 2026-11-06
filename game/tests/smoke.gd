extends Node
## Automated checks, run in CI with:  godot --headless -- --smoke
## 1) unit tests (big numbers, combat maths, bonuses, save round-trip)
## 2) gameplay scenario: fight in the camp, kill, extract, equip, army spawn, open every panel.

var main: Node
var failures: Array = []


func check(cond: bool, what: String) -> void:
	if cond:
		print("  ok   ", what)
	else:
		print("  FAIL ", what)
		failures.append(what)


func run() -> void:
	print("=== UNIT TESTS ===")
	_unit_big()
	_unit_combat()
	_unit_game()
	print("=== SCENARIO ===")
	await _scenario()
	if failures.is_empty():
		print("SMOKE OK")
		get_tree().quit(0)
	else:
		print("SMOKE FAILED: ", failures)
		get_tree().quit(1)


func _unit_big() -> void:
	check(Big.of(1500).fmt() == "1 500", "fmt 1 500 -> %s" % Big.of(1500).fmt())
	check(Big.of(2400000).fmt() == "2,4 M", "fmt 2,4 M -> %s" % Big.of(2400000).fmt())
	check(Big.of(8.7e9).fmt() == "8,7 Md", "fmt 8,7 Md -> %s" % Big.of(8.7e9).fmt())
	check(Big.me(1.25, 18).fmt() == "1,25e18", "fmt 1,25e18 -> %s" % Big.me(1.25, 18).fmt())
	var a := Big.me(5.0, 400)
	var b := Big.me(3.0, 400)
	check(a.add(b).e == 400 and absf(a.add(b).m - 8.0) < 1e-9, "add beyond float range")
	check(a.mul(b).e == 801, "mul exponent 5e400*3e400")
	check(a.gt(b) and b.lt(a) and a.cmp(a.copy()) == 0, "compare")
	check(a.sub(a).is_zero(), "sub to zero")
	check(Big.me(1.0, 3).sub(Big.of(1)).fmt() == "999", "1000-1 = 999")
	check(Big.from_variant(a.to_variant()).cmp(a) == 0, "serialize round trip")
	check(Big.power(1.25, 2000).e == int(floor(2000 * log(1.25) / log(10.0))), "power large")
	check(not is_inf(Big.power(10.0, 500).log10()), "no infinity")
	check(Big.of(1e300).mul(Big.of(1e300)).e == 600, "1e300^2 no overflow")


func _unit_combat() -> void:
	var r := Combat.roll(Big.of(100), 0.0, 2.0, 0.5, 0.5)
	check(not r["crit"] and r["amount"].cmp(Big.of(100)) == 0, "roll no crit = base at mid variance")
	var c := Combat.roll(Big.of(100), 1.0, 2.0, 0.0, 0.5)
	check(c["crit"] and c["amount"].cmp(Big.of(200)) == 0, "roll crit x2")
	check(Combat.roll(Big.of(0.1), 0.0, 2.0, 0.9, 0.0)["amount"].cmp(Big.of(1)) == 0, "min damage 1")
	check(is_equal_approx(Combat.extract_chance(0.5, 3.0), Data.EXTRACT_MAX), "extract chance capped")
	var mods := [{"stat": "x", "value": 0.5, "mode": "add"}, {"stat": "x", "value": 0.25, "mode": "add"}, {"stat": "x", "value": 2.0, "mode": "mul"}]
	check(is_equal_approx(Bonus.factor(mods, "x"), 3.5), "bonus factor (1+0.75)*2")


func _unit_game() -> void:
	var snapshot: Dictionary = Game.to_dict()
	Game.from_dict({})
	var s1 := Game.add_shadow("ossu")
	var s2 := Game.add_shadow("necro")
	check(s1["equipped"] and s2["equipped"], "auto-equip into free slots")
	Game.toggle_lock(int(s1["uid"]))
	check(Game.sell(int(s1["uid"])) != "", "locked shadow cannot be sold")
	Game.unequip(int(s2["uid"]))
	check(Game.sell(int(s2["uid"])) == "", "unequipped shadow can be sold")
	for i in 5:
		Game.add_shadow("garde")
	check(Game.equipped_count() == Game.army_slots, "never more equipped than slots")
	Game.equip_best()
	check(Game.equipped_count() == mini(Game.army_slots, Game.shadows.size()), "equip best fills slots")
	var d := Game.to_dict()
	var txt := JSON.stringify(d)
	Game.from_dict(JSON.parse_string(txt))
	check(Game.shadows.size() == 6 and Game.equipped_count() == Game.army_slots, "save round trip via JSON")
	Game.add_xp(Big.of(10000))
	check(Game.level > 1, "xp levels up")
	Game.from_dict(snapshot)


func _scenario() -> void:
	for i in 30:
		await get_tree().physics_frame
	var player: Player = main.player
	check(player != null, "player spawned")
	check(get_tree().get_nodes_in_group("enemies").size() == 13, "13 enemies spawned (12 + boss)")
	check(get_tree().get_nodes_in_group("npcs").size() == 3, "3 villagers")
	check(main.world.interactables.size() >= 5, "interactable buildings registered")
	# go fight: boost damage so the scenario is short
	Game.forge_level = 40
	Game.mark_dirty()
	var cc: Array = main.world.data["spawns"]["camp_center"]
	player.global_position = Vector3(float(cc[0]), 0.5, float(cc[1]) + 10.0)
	var kills0: int = int(Game.stats["kills"])
	for t in 900:
		await get_tree().physics_frame
		var target: Actor = player._nearest_enemy(40.0)
		if target and player.flat_distance_to(target) > 2.2:
			var dir := target.global_position - player.global_position
			player.move_input = Vector2(dir.x, -dir.z).normalized()
			player.cam = null
		else:
			player.move_input = Vector2.ZERO
			player.request_attack()
		if int(Game.stats["kills"]) - kills0 >= 2:
			break
	player.move_input = Vector2.ZERO
	check(int(Game.stats["kills"]) - kills0 >= 1, "player killed enemies (%d)" % (int(Game.stats["kills"]) - kills0))
	var corpses := get_tree().get_nodes_in_group("corpses")
	check(corpses.size() >= 1, "corpse available for extraction")
	if corpses.size() > 0:
		var ex0: int = int(Game.stats["extract_ok"]) + int(Game.stats["extract_fail"])
		var c: Enemy = corpses[0]
		player.global_position = c.global_position + Vector3(1.5, 0.5, 0)
		for i in 180:
			await get_tree().physics_frame
			if player.can_cast():
				break
		check(player.can_cast(), "player free to cast (state %d)" % player.state)
		player.start_extract(c)
		for i in 120:
			await get_tree().physics_frame
		check(int(Game.stats["extract_ok"]) + int(Game.stats["extract_fail"]) == ex0 + 1, "extraction resolved exactly once")
	Game.unequip_all()
	var inst := Game.add_shadow("lame")
	Game.equip(int(inst["uid"]))
	for i in 90:
		await get_tree().physics_frame
	check(get_tree().get_nodes_in_group("allies").size() >= 1, "equipped shadow is summoned in the world")
	main.hud.open_shadows()
	await get_tree().process_frame
	main.hud.open_bonus()
	await get_tree().process_frame
	main.hud.open_forge()
	await get_tree().process_frame
	main.hud.open_settings()
	await get_tree().process_frame
	check(main.hud.is_panel_open(), "panels open")
	main.hud._open_panel.queue_free()
	main.hud._panel_closed()
	for i in 10:
		await get_tree().process_frame
	check(not main.hud.touch.blocked, "controls unblocked after closing panel")
	Game.forge_level = 0
	Game.mark_dirty()
