class_name Bonus
extends RefCounted
## Central bonus engine.
## Every modifier: {id, stat, value, source, mode} with mode "add" (percentage points, summed)
## or "mul" (multiplier, multiplied). Final factor for a stat = (1 + Σadd) × Πmul.
## Crit chance is the only "flat" stat: final = base + Σadd (mul ignored).

const STAT_LABELS := {
	"player_damage": "Dégâts de l'arme",
	"shadow_damage": "Dégâts des ombres",
	"extract_chance": "Chance d'éveil",
	"xp_gain": "Expérience",
	"gold_gain": "Or",
	"crit_chance": "Chance critique",
}


static func collect(g: Node) -> Array:
	var mods: Array = []
	var forge: int = g.forge_level
	if forge > 0:
		mods.append({"id": "forge", "stat": "player_damage", "value": forge * Data.FORGE_DMG_PER_LEVEL,
			"source": "Forge (niv. %d)" % forge, "mode": "add"})
	var species_count: int = g.distinct_species_count()
	if species_count > 0:
		mods.append({"id": "codex_dmg", "stat": "shadow_damage", "value": 0.05 * species_count,
			"source": "Codex des ombres (%d espèces)" % species_count, "mode": "add"})
		mods.append({"id": "codex_ext", "stat": "extract_chance", "value": 0.02 * species_count,
			"source": "Codex des ombres (%d espèces)" % species_count, "mode": "add"})
	var lvl: int = g.level
	if lvl > 1:
		mods.append({"id": "lvl_crit", "stat": "crit_chance", "value": minf(0.002 * (lvl - 1), 0.15),
			"source": "Niveau du joueur (%d)" % lvl, "mode": "add"})
	if lvl >= 5:
		mods.append({"id": "lvl_gold", "stat": "gold_gain", "value": 0.10 * int(lvl / 5),
			"source": "Paliers de niveau (tous les 5)", "mode": "add"})
	return mods


static func factor(mods: Array, stat: String) -> float:
	var add := 0.0
	var mul := 1.0
	for md in mods:
		if md["stat"] != stat:
			continue
		if md["mode"] == "mul":
			mul *= float(md["value"])
		else:
			add += float(md["value"])
	return (1.0 + add) * mul


static func flat(mods: Array, stat: String) -> float:
	var add := 0.0
	for md in mods:
		if md["stat"] == stat and md["mode"] == "add":
			add += float(md["value"])
	return add


static func describe(md: Dictionary) -> String:
	var label: String = STAT_LABELS.get(md["stat"], md["stat"])
	if md["mode"] == "mul":
		return "%s ×%s" % [label, String.num(float(md["value"]), 2).replace(".", ",")]
	return "%s +%s %%" % [label, String.num(float(md["value"]) * 100.0, 1).replace(".", ",")]
