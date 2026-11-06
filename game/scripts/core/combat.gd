class_name Combat
extends RefCounted
## Pure damage maths (testable, no scene access).


## Returns {"amount": Big, "crit": bool}. roll01 values are injected for tests.
static func roll(base: Big, crit_chance: float, crit_mult: float, roll_crit: float, roll_var: float) -> Dictionary:
	var variance: float = 0.92 + 0.16 * clampf(roll_var, 0.0, 1.0)
	var crit: bool = roll_crit < clampf(crit_chance, 0.0, 1.0)
	var amount: Big = base.mulf(variance * (crit_mult if crit else 1.0))
	if amount.lt(Big.of(1.0)):
		amount = Big.of(1.0)
	return {"amount": amount.floor_big(), "crit": crit}


static func random_roll(base: Big, crit_chance: float, crit_mult: float) -> Dictionary:
	return roll(base, crit_chance, crit_mult, randf(), randf())


## Extraction success chance (truthful value shown in UI).
static func extract_chance(base_chance: float, bonus_factor: float) -> float:
	return clampf(base_chance * bonus_factor, 0.0, Data.EXTRACT_MAX)
