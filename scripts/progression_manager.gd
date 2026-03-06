## XP, leveling, and unlock calculations for the chef progression system.
## Pure data — no Node dependencies.
class_name ProgressionManager
extends RefCounted

## Unlock table: each entry is { level, type, key, description }
## type: "ability", "cuisine", "bag_size", "max_charges"
const UNLOCK_TABLE: Array[Dictionary] = [
	{"level": 2, "type": "ability", "key": "peek", "description": "Peek: See the next ingredient before drawing"},
	{"level": 3, "type": "feature", "key": "ad_refill", "description": "Ad refill: Watch an ad to restore 1 ability charge"},
	{"level": 5, "type": "cuisine", "key": "italian", "description": "Italian Cuisine: +6 ingredients, +5 combos"},
	{"level": 7, "type": "ability", "key": "cool_down", "description": "Cool Down: Remove heat from the pot"},
	{"level": 8, "type": "bag_size", "key": "13", "description": "Bag size increased to 13"},
	{"level": 10, "type": "ability", "key": "swap", "description": "Swap: Discard drawn ingredient, draw replacement"},
	{"level": 12, "type": "max_charges", "key": "2", "description": "All abilities get +1 max charge"},
	{"level": 15, "type": "cuisine", "key": "japanese", "description": "Japanese Cuisine: +6 ingredients, +6 combos"},
	{"level": 18, "type": "bag_size", "key": "14", "description": "Bag size increased to 14"},
	{"level": 20, "type": "max_charges", "key": "3", "description": "All abilities get +1 max charge"},
	{"level": 30, "type": "bag_size", "key": "15", "description": "Bag size increased to 15"},
	{"level": 35, "type": "max_charges", "key": "4", "description": "All abilities get +1 max charge"},
]


## Calculate XP earned from a round.
## round_data keys: was_boilover, final_score, combos_count, bag_emptied, new_recipes_count
static func calculate_xp(round_data: Dictionary) -> int:
	var was_boilover: bool = round_data.get("was_boilover", false) as bool
	if was_boilover:
		return 5  # Consolation XP

	var xp: int = 10  # Base XP

	# Score bonus: 1 XP per 10 points
	var final_score: int = round_data.get("final_score", 0) as int
	xp += final_score / 10

	# Combo bonus: 5 XP per combo
	var combos_count: int = round_data.get("combos_count", 0) as int
	xp += combos_count * 5

	# Clean pot bonus
	var bag_emptied: bool = round_data.get("bag_emptied", false) as bool
	if bag_emptied:
		xp += 15

	# Recipe discovery bonus: 25 per new recipe
	var new_recipes_count: int = round_data.get("new_recipes_count", 0) as int
	xp += new_recipes_count * 25

	return xp


## XP required to go from (level) to (level+1).
static func xp_for_level(level: int) -> int:
	return 25 * level


## Total cumulative XP required to reach a given level from level 1.
static func total_xp_for_level(level: int) -> int:
	if level <= 1:
		return 0
	# Sum of 25*1 + 25*2 + ... + 25*(level-1) = 25 * (level-1)*level/2
	return 25 * (level - 1) * level / 2


## Check what unlocks happened between old_level and new_level.
## Returns array of unlock dictionaries from the UNLOCK_TABLE.
static func check_unlocks(old_level: int, new_level: int) -> Array[Dictionary]:
	var unlocks: Array[Dictionary] = []
	for entry: Dictionary in UNLOCK_TABLE:
		var lvl: int = entry["level"] as int
		if lvl > old_level and lvl <= new_level:
			unlocks.append(entry)
	return unlocks


## Get the effective bag size for a given chef level.
static func get_effective_bag_size(level: int, base_bag_size: int) -> int:
	var bag_size: int = base_bag_size
	if level >= 30:
		bag_size = 15
	elif level >= 18:
		bag_size = 14
	elif level >= 8:
		bag_size = 13
	return bag_size


## Get the heat budget ratio for balanced bag generation.
static func get_heat_budget_ratio(level: int, ratio_min: float, ratio_max: float, level_cap: int) -> float:
	var t: float = clampf(float(level - 1) / float(level_cap - 1), 0.0, 1.0)
	return lerpf(ratio_min, ratio_max, t)


## Get max ability charges for a given level.
static func get_max_ability_charges(level: int) -> int:
	if level >= 35:
		return 4
	elif level >= 20:
		return 3
	elif level >= 12:
		return 2
	return 1


## Get list of unlocked ability keys for a given level.
static func get_unlocked_abilities(level: int) -> Array[String]:
	var abilities: Array[String] = []
	if level >= 2:
		abilities.append("peek")
	if level >= 7:
		abilities.append("cool_down")
	if level >= 10:
		abilities.append("swap")
	return abilities


## Get list of unlocked cuisine keys for a given level.
static func get_unlocked_cuisines(level: int) -> Array[String]:
	var cuisines: Array[String] = ["basic"]
	if level >= 5:
		cuisines.append("italian")
	if level >= 15:
		cuisines.append("japanese")
	return cuisines


## Check if ad refill feature is unlocked.
static func is_ad_refill_unlocked(level: int) -> bool:
	return level >= 3
