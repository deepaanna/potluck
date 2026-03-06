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


## Heat-balanced bag generation. Ensures total heat slightly exceeds boilover
## threshold so every round is tight but solvable.
func fill_bag_balanced(chef_level: int, unlocked_cuisines: Array) -> void:
	bag.clear()
	var eligible: Array[IngredientData] = IngredientDatabase.get_eligible_ingredients(unlocked_cuisines)
	if eligible.is_empty():
		fill_bag()
		return

	var bag_size: int = ProgressionManager.get_effective_bag_size(chef_level, _config.bag_size)
	var heat_ratio: float = ProgressionManager.get_heat_budget_ratio(
		chef_level, _config.heat_budget_ratio_min, _config.heat_budget_ratio_max, _config.heat_budget_level_cap)
	var target_budget: float = _config.boilover_threshold * heat_ratio

	# Build rarity-weighted pool
	var pool: Array[IngredientData] = []
	for ingredient: IngredientData in eligible:
		var copies: int = _rarity_copies(ingredient.rarity)
		for i: int in range(copies):
			pool.append(ingredient)
	pool.shuffle()

	# Greedy fill: track remaining budget
	var remaining_budget: float = target_budget
	var selected: Array[IngredientData] = []

	for candidate: IngredientData in pool:
		if selected.size() >= bag_size:
			break
		if candidate.heat <= remaining_budget:
			selected.append(candidate)
			remaining_budget -= candidate.heat

	# If we didn't fill the bag, add lowest-heat ingredients to fill
	if selected.size() < bag_size:
		var sorted_pool: Array[IngredientData] = eligible.duplicate()
		sorted_pool.sort_custom(func(a: IngredientData, b: IngredientData) -> bool:
			return a.heat < b.heat)
		for filler: IngredientData in sorted_pool:
			if selected.size() >= bag_size:
				break
			selected.append(filler)

	# Tension shaping: ensure at least 1 spicy (heat >= 0.10) and 2 safe (heat <= 0.05)
	var spicy_count: int = 0
	var safe_count: int = 0
	for ing: IngredientData in selected:
		if ing.heat >= 0.10:
			spicy_count += 1
		if ing.heat <= 0.05:
			safe_count += 1

	# Find candidates from eligible pool for swaps
	var spicy_candidates: Array[IngredientData] = []
	var safe_candidates: Array[IngredientData] = []
	for ing: IngredientData in eligible:
		if ing.heat >= 0.10:
			spicy_candidates.append(ing)
		if ing.heat <= 0.05:
			safe_candidates.append(ing)

	# Swap in spicy if needed
	if spicy_count == 0 and not spicy_candidates.is_empty():
		spicy_candidates.shuffle()
		# Replace a mid-heat ingredient with spicy
		for i: int in range(selected.size()):
			if selected[i].heat >= 0.05 and selected[i].heat < 0.10:
				selected[i] = spicy_candidates[0]
				break

	# Swap in safe if needed
	if safe_count < 2 and not safe_candidates.is_empty():
		safe_candidates.shuffle()
		var swaps_needed: int = 2 - safe_count
		var swap_idx: int = 0
		for i: int in range(selected.size()):
			if swaps_needed <= 0:
				break
			if selected[i].heat > 0.05 and selected[i].heat < 0.10:
				selected[i] = safe_candidates[swap_idx % safe_candidates.size()]
				swap_idx += 1
				swaps_needed -= 1

	# Validate total heat is in acceptable range
	var total_heat: float = 0.0
	for ing: IngredientData in selected:
		total_heat += ing.heat
	var min_heat: float = _config.boilover_threshold * 0.95
	var max_heat: float = _config.boilover_threshold * 1.40
	if total_heat < min_heat or total_heat > max_heat:
		# Fallback: use standard bag generation
		push_warning("PotLuckEngine: Balanced bag heat %.3f outside range [%.3f, %.3f], falling back to random bag" % [total_heat, min_heat, max_heat])
		fill_bag()
		return

	# Final shuffle for unpredictable draw order
	selected.shuffle()
	bag = selected


## Peek at the next ingredient without popping it from the bag.
func peek() -> IngredientData:
	if bag.is_empty():
		return null
	return bag.back()


## Discard the current drawn ingredient and draw a replacement from the bag.
func swap_current() -> IngredientData:
	if current_ingredient == null:
		return null
	if phase != Phase.DRAW:
		return null
	# Discard current ingredient entirely (not returned to bag)
	current_ingredient = null
	# Draw replacement
	if bag.is_empty():
		return null
	current_ingredient = bag.pop_back()
	ingredient_drawn.emit(current_ingredient)
	return current_ingredient


## Reduce heat by the configured cool down amount.
func cool_down(amount: float) -> void:
	heat = maxf(0.0, heat - amount)
	heat_changed.emit(heat, get_heat_stage())


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
	heat = _config.second_chance_heat_reduction * _config.boilover_threshold
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
