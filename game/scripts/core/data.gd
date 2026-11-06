class_name Data
extends RefCounted
## Static game data (species, rarities, ranks). Instance data lives in Game (game.gd).

const RARITY_NAMES := ["Commun", "Rare", "Épique", "Légendaire", "Mythique"]
const RARITY_COLORS := [
	Color(0.62, 0.66, 0.72),
	Color(0.24, 0.55, 1.0),
	Color(0.68, 0.32, 1.0),
	Color(1.0, 0.71, 0.18),
	Color(1.0, 0.24, 0.35),
]
const RANKS := ["E", "D", "C", "B", "A", "S"]
const RANK_LEVEL_CAP := {"E": 20, "D": 30, "C": 40, "B": 50, "A": 60, "S": 80}

const CHAR_DIR := "res://assets/characters/"
const WEAPON_DIR := "res://assets/weapons/"

## role: melee / tank / ranged / boss
const SPECIES := {
	"ossu": {
		"name": "Rôdeur d'os", "model": "skeleton_minion.glb",
		"weapon_r": "Skeleton_Blade.gltf", "weapon_l": "",
		"rarity": 0, "rank": "E", "role": "melee",
		"hp": 60.0, "dmg": 6.0, "atk_cd": 1.5, "speed": 3.4, "range": 1.9,
		"xp": 12.0, "gold": 8.0, "extract": 0.55, "scale": 1.0,
	},
	"garde": {
		"name": "Gardien d'os", "model": "skeleton_warrior.glb",
		"weapon_r": "Skeleton_Axe.gltf", "weapon_l": "Skeleton_Shield_Small_A.gltf",
		"rarity": 1, "rank": "D", "role": "tank",
		"hp": 150.0, "dmg": 10.0, "atk_cd": 1.7, "speed": 3.0, "range": 2.0,
		"xp": 30.0, "gold": 20.0, "extract": 0.35, "scale": 1.05,
	},
	"lame": {
		"name": "Lame spectrale", "model": "skeleton_rogue.glb",
		"weapon_r": "Skeleton_Blade.gltf", "weapon_l": "Skeleton_Blade.gltf",
		"rarity": 2, "rank": "C", "role": "melee",
		"hp": 110.0, "dmg": 17.0, "atk_cd": 1.1, "speed": 4.0, "range": 1.9,
		"xp": 45.0, "gold": 32.0, "extract": 0.22, "scale": 1.0,
	},
	"necro": {
		"name": "Nécromage", "model": "skeleton_mage.glb",
		"weapon_r": "Skeleton_Staff.gltf", "weapon_l": "",
		"rarity": 3, "rank": "B", "role": "ranged",
		"hp": 90.0, "dmg": 21.0, "atk_cd": 2.2, "speed": 2.8, "range": 9.0,
		"xp": 70.0, "gold": 50.0, "extract": 0.12, "scale": 1.0,
	},
	"seigneur": {
		"name": "Seigneur des Tertres", "model": "skeleton_warrior.glb",
		"weapon_r": "Skeleton_Axe.gltf", "weapon_l": "Skeleton_Shield_Small_A.gltf",
		"rarity": 4, "rank": "A", "role": "boss",
		"hp": 2600.0, "dmg": 38.0, "atk_cd": 3.0, "speed": 3.1, "range": 3.4,
		"xp": 650.0, "gold": 520.0, "extract": 0.06, "scale": 1.9,
	},
}

## Player
const PLAYER_BASE_HP := 140.0
const PLAYER_BASE_DMG := 14.0
const PLAYER_GROWTH := 1.10
const XP_BASE := 50.0
const XP_GROWTH := 1.25
## Shadows
const SHADOW_LEVEL_STEP := 0.12
const SHADOW_XP_BASE := 30.0
const SHADOW_XP_GROWTH := 1.2
const SHADOW_SELL_GOLD := [5.0, 15.0, 40.0, 100.0, 400.0]
## Forge
const FORGE_COST_BASE := 40.0
const FORGE_COST_GROWTH := 1.55
const FORGE_DMG_PER_LEVEL := 0.15
## Army
const ARMY_BASE_SLOTS := 3
## Combat
const BASE_CRIT_CHANCE := 0.08
const BASE_CRIT_MULT := 1.8
const EXTRACT_MAX := 0.95


static func species(id: String) -> Dictionary:
	return SPECIES.get(id, SPECIES["ossu"])


static func rarity_color(r: int) -> Color:
	return RARITY_COLORS[clampi(r, 0, RARITY_COLORS.size() - 1)]


static func rarity_name(r: int) -> String:
	return RARITY_NAMES[clampi(r, 0, RARITY_NAMES.size() - 1)]


static func model_path(id: String) -> String:
	return CHAR_DIR + str(species(id)["model"])
