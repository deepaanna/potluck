## Core game logic for Pot Luck. No Node dependencies — fully testable.
## Manages bag, pot, heat, combos, scoring, and phase state machine.
class_name PotLuckEngine
extends RefCounted

signal ingredient_drawn(data: IngredientData)
signal ingredient_added(data: IngredientData)
signal combo_triggered(combo: ComboData)
signal heat_changed(new_heat: float, stage: int)
signal boilover
signal dish_served(final_score: int)
signal bag_emptied

enum Phase { WAITING, DRAW, FLICK, DECIDE, SERVED, BOILOVER }

var phase: Phase = Phase.WAITING
var heat: float = 0.0
var bag: Array[IngredientData] = []
var pot: Array[IngredientData] = []
var pot_ids: Array[String] = []
var triggered_combos: Array[ComboData] = []
var consecutive_ingredients: int = 0
var current_ingredient: IngredientData = null
var second_chance_used: bool = false
var bag_was_emptied: bool = false

var _config: GameConfig


func setup(config: GameConfig) -> void:
	_config = config


func reset() -> void:
	phase = Phase.WAITING
	heat = 0.0
	bag.clear()
	pot.clear()
	pot_ids.clear()
	triggered_combos.clear()
	consecutive_ingredients = 0
	current_ingredient = null
	second_chance_used = false
	bag_was_emptied = false


func fill_bag() -> void:
	bag.clear()
	var all_ingredients: Array[IngredientData] = IngredientDatabase.get_all_ingredients()
	var pool: Array[IngredientData] = []

	for ingredient: IngredientData in all_ingredients:
		var copies: int = _rarity_copies(ingredient.rarity)
		for i: int in range(copies):
			pool.append(ingredient)

	pool.shuffle()

	var count: int = mini(_config.bag_size, pool.size())
	for i: int in range(count):
		bag.append(pool[i])

	bag.shuffle()


func draw() -> IngredientData:
	if bag.is_empty():
		return null
	if phase != Phase.WAITING and phase != Phase.DECIDE:
		return null

	current_ingredient = bag.pop_back()
	phase = Phase.DRAW
	ingredient_drawn.emit(current_ingredient)
	return current_ingredient


func begin_flick() -> void:
	if phase == Phase.DRAW:
		phase = Phase.FLICK


func add_to_pot() -> void:
	if current_ingredient == null:
		return

	var data: IngredientData = current_ingredient
	pot.append(data)
	pot_ids.append(data.id)
	consecutive_ingredients += 1

	# Apply heat
	heat += data.heat
	var stage: int = get_heat_stage()
	heat_changed.emit(heat, stage)

	# Check combos
	var new_combos: Array[ComboData] = IngredientDatabase.find_new_combos(pot_ids, data.id)
	for combo: ComboData in new_combos:
		if combo not in triggered_combos:
			triggered_combos.append(combo)
			if combo.bonus_heat > 0.0:
				heat += combo.bonus_heat
				heat_changed.emit(heat, get_heat_stage())
			combo_triggered.emit(combo)

	current_ingredient = null

	# Check boilover
	if heat >= _config.boilover_threshold:
		phase = Phase.BOILOVER
		ingredient_added.emit(data)
		boilover.emit()
		return

	# Check bag empty
	if bag.is_empty():
		bag_was_emptied = true
		bag_emptied.emit()

	phase = Phase.DECIDE
	ingredient_added.emit(data)


func serve() -> int:
	if phase != Phase.DECIDE:
		return 0

	phase = Phase.SERVED
	var final_score: int = calculate_score()
	dish_served.emit(final_score)
	return final_score


func apply_second_chance() -> void:
	if phase != Phase.BOILOVER:
		return
	second_chance_used = true
	heat *= _config.second_chance_heat_reduction
	heat_changed.emit(heat, get_heat_stage())

	if bag.is_empty():
		bag_was_emptied = true
		bag_emptied.emit()

	phase = Phase.DECIDE


func get_heat_stage() -> int:
	var stages: PackedFloat32Array = _config.heat_stages
	var stage: int = 0
	for i: int in range(stages.size()):
		if heat >= stages[i] * _config.boilover_threshold:
			stage = i + 1
	return stage


func calculate_score() -> int:
	# Raw total from ingredients
	var raw_total: float = 0.0
	for ingredient: IngredientData in pot:
		raw_total += ingredient.points

	# Combo multiplier (product of all triggered combo multipliers)
	var combo_multiplier: float = 1.0
	for combo: ComboData in triggered_combos:
		combo_multiplier *= combo.multiplier

	# Streak bonus
	var streak_bonus: float = minf(consecutive_ingredients * _config.streak_bonus_per, _config.streak_max_bonus)

	# Clean pot bonus
	var clean_bonus: float = 1.0
	if bag_was_emptied:
		clean_bonus = _config.clean_pot_bonus

	var final: float = raw_total * combo_multiplier * (1.0 + streak_bonus) * clean_bonus
	return maxi(0, roundi(final))


func get_combo_multiplier() -> float:
	var multiplier: float = 1.0
	for combo: ComboData in triggered_combos:
		multiplier *= combo.multiplier
	return multiplier


func get_streak_bonus() -> float:
	return minf(consecutive_ingredients * _config.streak_bonus_per, _config.streak_max_bonus)


func _rarity_copies(rarity: IngredientData.Rarity) -> int:
	match rarity:
		IngredientData.Rarity.COMMON:
			return 3
		IngredientData.Rarity.UNCOMMON:
			return 2
		IngredientData.Rarity.RARE:
			return 1
	return 1
