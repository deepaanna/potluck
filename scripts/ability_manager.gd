## Manages per-round ability charges for Peek, Cool Down, and Swap.
## Pure data — no Node dependencies.
class_name AbilityManager
extends RefCounted

enum AbilityType { PEEK, COOL_DOWN, SWAP }

var charges: Dictionary = {}       # AbilityType -> int
var max_charges: Dictionary = {}   # AbilityType -> int
var ad_refill_used: Dictionary = {} # AbilityType -> bool
var _unlocked: Dictionary = {}     # AbilityType -> bool
var _ad_refill_enabled: bool = false


## Initialize abilities based on chef level. Call at the start of each round.
func setup(chef_level: int) -> void:
	var max_ch: int = ProgressionManager.get_max_ability_charges(chef_level)
	var unlocked_abilities: Array[String] = ProgressionManager.get_unlocked_abilities(chef_level)
	_ad_refill_enabled = ProgressionManager.is_ad_refill_unlocked(chef_level)

	for ability_type: int in [AbilityType.PEEK, AbilityType.COOL_DOWN, AbilityType.SWAP]:
		var key: String = _type_to_key(ability_type)
		var is_unlocked: bool = key in unlocked_abilities
		_unlocked[ability_type] = is_unlocked

		if is_unlocked:
			max_charges[ability_type] = max_ch
			charges[ability_type] = max_ch
		else:
			max_charges[ability_type] = 0
			charges[ability_type] = 0

		ad_refill_used[ability_type] = false


## Use an ability. Returns true if successfully used.
func use_ability(ability_type: AbilityType) -> bool:
	if not is_unlocked(ability_type):
		return false
	var current: int = charges.get(ability_type, 0) as int
	if current <= 0:
		return false
	charges[ability_type] = current - 1
	return true


## Refill one charge via rewarded ad.
func refill_ability(ability_type: AbilityType) -> void:
	if not is_unlocked(ability_type):
		return
	var current: int = charges.get(ability_type, 0) as int
	var max_ch: int = max_charges.get(ability_type, 0) as int
	charges[ability_type] = mini(current + 1, max_ch)
	ad_refill_used[ability_type] = true


## Refill all ability charges to max (called at round start via setup).
func refill_all() -> void:
	for ability_type: int in [AbilityType.PEEK, AbilityType.COOL_DOWN, AbilityType.SWAP]:
		if _unlocked.get(ability_type, false) as bool:
			charges[ability_type] = max_charges.get(ability_type, 0)
		ad_refill_used[ability_type] = false


## Check if an ability can be used in the current engine phase.
func can_use(ability_type: AbilityType, engine_phase: PotLuckEngine.Phase) -> bool:
	if not is_unlocked(ability_type):
		return false
	var current: int = charges.get(ability_type, 0) as int
	if current <= 0:
		return false

	match ability_type:
		AbilityType.PEEK:
			return engine_phase == PotLuckEngine.Phase.DECIDE
		AbilityType.COOL_DOWN:
			return engine_phase == PotLuckEngine.Phase.DECIDE
		AbilityType.SWAP:
			return engine_phase == PotLuckEngine.Phase.DRAW
	return false


## Check if ad refill is available for this ability.
func has_ad_refill(ability_type: AbilityType) -> bool:
	if not _ad_refill_enabled:
		return false
	if not is_unlocked(ability_type):
		return false
	if ad_refill_used.get(ability_type, false) as bool:
		return false
	var current: int = charges.get(ability_type, 0) as int
	return current <= 0


## Check if an ability is unlocked.
func is_unlocked(ability_type: AbilityType) -> bool:
	return _unlocked.get(ability_type, false) as bool


## Get current charges for an ability.
func get_charges(ability_type: AbilityType) -> int:
	return charges.get(ability_type, 0) as int


## Get max charges for an ability.
func get_max_charges(ability_type: AbilityType) -> int:
	return max_charges.get(ability_type, 0) as int


## Get display name for an ability type.
static func get_ability_name(ability_type: AbilityType) -> String:
	match ability_type:
		AbilityType.PEEK:
			return "Peek"
		AbilityType.COOL_DOWN:
			return "Cool Down"
		AbilityType.SWAP:
			return "Swap"
	return ""


func _type_to_key(ability_type: int) -> String:
	match ability_type:
		AbilityType.PEEK:
			return "peek"
		AbilityType.COOL_DOWN:
			return "cool_down"
		AbilityType.SWAP:
			return "swap"
	return ""
