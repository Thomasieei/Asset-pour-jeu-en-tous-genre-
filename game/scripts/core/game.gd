extends Node
## Autoload "Game": the single source of truth for player progression, shadows and save data.
## UI and world only read from here and call its methods; they never keep their own copies.

signal gold_changed
signal xp_changed
signal level_up(new_level: int)
signal shadows_changed
signal army_changed
signal forge_changed
signal toast(text: String, color: Color)
signal extraction_result(success: bool, inst: Dictionary, species_id: String, chance: float)
signal boss_state(active: bool, actor: Node)
signal camera_shake(strength: float)

const SAVE_PATH := "user://save.json"
const SAVE_VERSION := 1

var level: int = 1
var xp: Big = Big.zero()
var gold: Big = Big.zero()
var forge_level: int = 0
var army_slots: int = Data.ARMY_BASE_SLOTS
var shadows: Array = []          # Array of Dictionary (owned instances)
var next_uid: int = 1
var settings := {"cam_sens": 1.0, "cam_dist": 9.0, "sfx": 0.8}
var stats := {"kills": 0, "extract_ok": 0, "extract_fail": 0, "boss_kills": 0, "quest": 0, "quest_base": 0}
var tutorial_done: bool = false

var _mods_cache: Array = []
var _mods_dirty: bool = true
var _save_timer: float = 0.0
var _dirty: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	load_game()


func _process(delta: float) -> void:
	_save_timer += delta
	if _dirty and _save_timer > 15.0:
		save_game()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST \
			or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		if _dirty:
			save_game()


func mark_dirty() -> void:
	_dirty = true
	_mods_dirty = true


# ---------------------------------------------------------------- bonuses
func mods() -> Array:
	if _mods_dirty:
		_mods_cache = Bonus.collect(self)
		_mods_dirty = false
	return _mods_cache


func factor(stat: String) -> float:
	return Bonus.factor(mods(), stat)


# ---------------------------------------------------------------- player
func xp_needed(lvl: int = -1) -> Big:
	var l := level if lvl < 0 else lvl
	return Big.power(Data.XP_GROWTH, float(l - 1)).mulf(Data.XP_BASE).floor_big()


func player_damage() -> Big:
	return Big.power(Data.PLAYER_GROWTH, float(level - 1)).mulf(Data.PLAYER_BASE_DMG * factor("player_damage"))


func player_max_hp() -> Big:
	return Big.power(Data.PLAYER_GROWTH, float(level - 1)).mulf(Data.PLAYER_BASE_HP).floor_big()


func crit_chance() -> float:
	return Data.BASE_CRIT_CHANCE + Bonus.flat(mods(), "crit_chance")


func add_xp(amount: Big) -> void:
	xp = xp.add(amount.mulf(factor("xp_gain")))
	var guard := 0
	while xp.gte(xp_needed()) and guard < 1000:
		xp = xp.sub(xp_needed())
		level += 1
		guard += 1
		mark_dirty()
		level_up.emit(level)
	mark_dirty()
	xp_changed.emit()


func add_gold(amount: Big, apply_bonus: bool = true) -> void:
	gold = gold.add(amount.mulf(factor("gold_gain")) if apply_bonus else amount)
	gold = gold.floor_big()
	mark_dirty()
	gold_changed.emit()


func spend_gold(amount: Big) -> bool:
	if gold.lt(amount):
		return false
	gold = gold.sub(amount)
	mark_dirty()
	gold_changed.emit()
	return true


# ---------------------------------------------------------------- forge
func forge_cost() -> Big:
	return Big.power(Data.FORGE_COST_GROWTH, float(forge_level)).mulf(Data.FORGE_COST_BASE).floor_big()


func upgrade_forge() -> bool:
	if not spend_gold(forge_cost()):
		return false
	forge_level += 1
	mark_dirty()
	forge_changed.emit()
	return true


# ---------------------------------------------------------------- shadows
func add_shadow(species_id: String) -> Dictionary:
	var inst := {"uid": next_uid, "sp": species_id, "lvl": 1, "xp": 0.0,
		"equipped": false, "locked": false, "order": next_uid, "new": true}
	next_uid += 1
	shadows.append(inst)
	# auto-equip into a free slot so the player immediately sees the new ally
	if equipped_count() < army_slots:
		inst["equipped"] = true
		army_changed.emit()
	mark_dirty()
	shadows_changed.emit()
	return inst


func get_shadow(uid: int) -> Dictionary:
	for s in shadows:
		if int(s["uid"]) == uid:
			return s
	return {}


func equipped_shadows() -> Array:
	var out: Array = []
	for s in shadows:
		if s["equipped"]:
			out.append(s)
	return out


func equipped_count() -> int:
	var n := 0
	for s in shadows:
		if s["equipped"]:
			n += 1
	return n


func distinct_species_count() -> int:
	var seen := {}
	for s in shadows:
		seen[s["sp"]] = true
	return seen.size()


func shadow_level_cap(inst: Dictionary) -> int:
	return int(Data.RANK_LEVEL_CAP.get(Data.species(inst["sp"])["rank"], 20))


func shadow_damage(inst: Dictionary) -> Big:
	var sp: Dictionary = Data.species(inst["sp"])
	var lvl_mult: float = 1.0 + Data.SHADOW_LEVEL_STEP * float(int(inst["lvl"]) - 1)
	return Big.of(float(sp["dmg"]) * lvl_mult * factor("shadow_damage"))


func shadow_max_hp(inst: Dictionary) -> Big:
	var sp: Dictionary = Data.species(inst["sp"])
	var lvl_mult: float = 1.0 + Data.SHADOW_LEVEL_STEP * float(int(inst["lvl"]) - 1)
	# allies are sturdier than their wild version so they last in fights
	return Big.of(float(sp["hp"]) * 1.5 * lvl_mult).floor_big()


## Power of one shadow = damage per second contribution.
func shadow_power(inst: Dictionary) -> Big:
	var sp: Dictionary = Data.species(inst["sp"])
	return shadow_damage(inst).divf(float(sp["atk_cd"])).mulf(10.0).floor_big()


## Total power = player DPS-equivalent + Σ equipped shadow power (×10 for readability).
func total_power() -> Big:
	var p: Big = player_damage().mulf((1.0 + crit_chance() * (Data.BASE_CRIT_MULT - 1.0)) * 10.0 / 0.55)
	for s in equipped_shadows():
		p = p.add(shadow_power(s))
	return p.floor_big()


func shadow_xp_needed(inst: Dictionary) -> float:
	return floor(Data.SHADOW_XP_BASE * pow(Data.SHADOW_XP_GROWTH, float(int(inst["lvl"]) - 1)))


func give_army_xp(amount: float) -> void:
	var changed := false
	for s in equipped_shadows():
		var cap := shadow_level_cap(s)
		if int(s["lvl"]) >= cap:
			continue
		s["xp"] = float(s["xp"]) + amount
		while int(s["lvl"]) < cap and float(s["xp"]) >= shadow_xp_needed(s):
			s["xp"] = float(s["xp"]) - shadow_xp_needed(s)
			s["lvl"] = int(s["lvl"]) + 1
			changed = true
		if int(s["lvl"]) >= cap:
			s["xp"] = 0.0
	mark_dirty()
	if changed:
		shadows_changed.emit()
		army_changed.emit()


## Returns "" on success, otherwise the reason (shown to the player).
func equip(uid: int) -> String:
	var s := get_shadow(uid)
	if s.is_empty():
		return "Ombre introuvable"
	if s["equipped"]:
		return ""
	if equipped_count() >= army_slots:
		return "Armée complète (%d/%d)" % [equipped_count(), army_slots]
	s["equipped"] = true
	mark_dirty()
	shadows_changed.emit()
	army_changed.emit()
	return ""


func unequip(uid: int) -> void:
	var s := get_shadow(uid)
	if s.is_empty() or not s["equipped"]:
		return
	s["equipped"] = false
	mark_dirty()
	shadows_changed.emit()
	army_changed.emit()


func toggle_lock(uid: int) -> void:
	var s := get_shadow(uid)
	if s.is_empty():
		return
	s["locked"] = not s["locked"]
	mark_dirty()
	shadows_changed.emit()


func sell_value(inst: Dictionary) -> Big:
	var r: int = int(Data.species(inst["sp"])["rarity"])
	return Big.of(Data.SHADOW_SELL_GOLD[clampi(r, 0, 4)] * (1.0 + 0.1 * float(int(inst["lvl"]) - 1))).floor_big()


## Returns "" on success, otherwise the reason.
func sell(uid: int) -> String:
	var s := get_shadow(uid)
	if s.is_empty():
		return "Ombre introuvable"
	if s["locked"]:
		return "Ombre verrouillée : déverrouillez-la d'abord"
	if s["equipped"]:
		return "Ombre équipée : déséquipez-la d'abord"
	var value := sell_value(s)
	shadows.erase(s)
	add_gold(value, false)
	mark_dirty()
	shadows_changed.emit()
	return ""


func unequip_all() -> void:
	for s in shadows:
		s["equipped"] = false
	mark_dirty()
	shadows_changed.emit()
	army_changed.emit()


## Equip the strongest shadows (by real power, not rarity).
func equip_best() -> void:
	var sorted := shadows.duplicate()
	sorted.sort_custom(func(a, b): return shadow_power(a).gt(shadow_power(b)))
	for s in shadows:
		s["equipped"] = false
	for i in range(mini(army_slots, sorted.size())):
		sorted[i]["equipped"] = true
	mark_dirty()
	shadows_changed.emit()
	army_changed.emit()


func clear_new_flags() -> void:
	var any := false
	for s in shadows:
		if s.get("new", false):
			s["new"] = false
			any = true
	if any:
		mark_dirty()
		shadows_changed.emit()


func has_new_shadows() -> bool:
	for s in shadows:
		if s.get("new", false):
			return true
	return false


func extract_chance(species_id: String) -> float:
	return Combat.extract_chance(float(Data.species(species_id)["extract"]), factor("extract_chance"))


# ---------------------------------------------------------------- save / load
func to_dict() -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"level": level, "xp": xp.to_variant(), "gold": gold.to_variant(),
		"forge_level": forge_level, "army_slots": army_slots,
		"shadows": shadows, "next_uid": next_uid,
		"settings": settings, "stats": stats, "tutorial_done": tutorial_done,
	}


func from_dict(d: Dictionary) -> void:
	level = maxi(1, int(d.get("level", 1)))
	xp = Big.from_variant(d.get("xp", 0))
	gold = Big.from_variant(d.get("gold", 0))
	forge_level = maxi(0, int(d.get("forge_level", 0)))
	army_slots = maxi(Data.ARMY_BASE_SLOTS, int(d.get("army_slots", Data.ARMY_BASE_SLOTS)))
	next_uid = maxi(1, int(d.get("next_uid", 1)))
	tutorial_done = bool(d.get("tutorial_done", false))
	shadows = []
	for raw in d.get("shadows", []):
		if not (raw is Dictionary) or not Data.SPECIES.has(str(raw.get("sp", ""))):
			continue
		var s := {
			"uid": int(raw.get("uid", next_uid)), "sp": str(raw["sp"]),
			"lvl": maxi(1, int(raw.get("lvl", 1))), "xp": float(raw.get("xp", 0.0)),
			"equipped": bool(raw.get("equipped", false)), "locked": bool(raw.get("locked", false)),
			"order": int(raw.get("order", raw.get("uid", 0))), "new": bool(raw.get("new", false)),
		}
		shadows.append(s)
		next_uid = maxi(next_uid, int(s["uid"]) + 1)
	# never more equipped than slots
	var eq := 0
	for s in shadows:
		if s["equipped"]:
			eq += 1
			if eq > army_slots:
				s["equipped"] = false
	var st: Variant = d.get("settings", {})
	if st is Dictionary:
		for k in settings.keys():
			if st.has(k):
				settings[k] = float(st[k])
	var stt: Variant = d.get("stats", {})
	if stt is Dictionary:
		for k in stats.keys():
			if stt.has(k):
				stats[k] = int(stt[k])
	_mods_dirty = true


func save_game() -> void:
	var f := FileAccess.open(SAVE_PATH + ".tmp", FileAccess.WRITE)
	if f == null:
		push_warning("Save failed: %s" % FileAccess.get_open_error())
		return
	f.store_string(JSON.stringify(to_dict()))
	f.close()
	var dir := DirAccess.open("user://")
	if dir:
		if dir.file_exists("save.json"):
			dir.remove("save.json")
		dir.rename("save.json.tmp", "save.json")
	_dirty = false
	_save_timer = 0.0


func load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var txt := FileAccess.get_file_as_string(SAVE_PATH)
	var parsed: Variant = JSON.parse_string(txt)
	if parsed is Dictionary:
		from_dict(parsed)
	else:
		push_warning("Save file unreadable, starting fresh")


func notify(text: String, color: Color = Color.WHITE) -> void:
	toast.emit(text, color)
