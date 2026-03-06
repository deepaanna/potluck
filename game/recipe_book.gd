## Manages discovered recipes (combos triggered at least once).
## Persists to SaveManager "pot_luck.recipes_discovered" array.
class_name RecipeBook
extends RefCounted


## Discovers a recipe by combo name. Returns true if this is a NEW discovery.
static func discover_recipe(combo_name: String) -> bool:
	var discovered: Array = SaveManager.get_value("pot_luck.recipes_discovered", []) as Array
	if combo_name in discovered:
		return false
	discovered.append(combo_name)
	SaveManager.set_value("pot_luck.recipes_discovered", discovered)
	return true


## Returns all possible combos with "discovered" and "locked" flags.
## Each entry: { "combo_name", "ingredient_a", "ingredient_b", "multiplier",
##               "is_penalty", "discovered", "locked", "unlock_level", "cuisine" }
static func get_all_recipes() -> Array[Dictionary]:
	var all_combos: Array[ComboData] = IngredientDatabase.get_all_combos()
	var discovered: Array = SaveManager.get_value("pot_luck.recipes_discovered", []) as Array
	var unlocked_cuisines: Array = SaveManager.get_value("pot_luck.unlocked_cuisines", ["basic"]) as Array
	var result: Array[Dictionary] = []

	for combo: ComboData in all_combos:
		var is_discovered: bool = combo.combo_name in discovered

		# Determine cuisine for this combo (highest cuisine of either ingredient)
		var a_data: IngredientData = IngredientDatabase.get_ingredient(combo.ingredient_a)
		var b_data: IngredientData = IngredientDatabase.get_ingredient(combo.ingredient_b)
		var cuisine_key: String = "basic"
		var unlock_level: int = 1
		if a_data != null and b_data != null:
			var a_cuisine: String = IngredientDatabase._cuisine_to_key(a_data.cuisine)
			var b_cuisine: String = IngredientDatabase._cuisine_to_key(b_data.cuisine)
			# Use the "higher" cuisine (italian/japanese over basic)
			if a_cuisine != "basic":
				cuisine_key = a_cuisine
			elif b_cuisine != "basic":
				cuisine_key = b_cuisine

		# Determine if locked (cuisine not yet unlocked)
		var is_locked: bool = cuisine_key not in unlocked_cuisines
		if cuisine_key == "italian":
			unlock_level = 5
		elif cuisine_key == "japanese":
			unlock_level = 15

		result.append({
			"combo_name": combo.combo_name,
			"ingredient_a": combo.ingredient_a,
			"ingredient_b": combo.ingredient_b,
			"multiplier": combo.multiplier,
			"is_penalty": combo.is_penalty,
			"discovered": is_discovered,
			"locked": is_locked,
			"unlock_level": unlock_level,
			"cuisine": cuisine_key,
		})

	return result


## Returns the number of discovered recipes.
static func get_discovery_count() -> int:
	var discovered: Array = SaveManager.get_value("pot_luck.recipes_discovered", []) as Array
	return discovered.size()


## Returns the total number of possible recipes (all combos).
static func get_total_count() -> int:
	return IngredientDatabase.get_all_combos().size()


## Returns the number of eligible (unlocked cuisine) recipes.
static func get_eligible_count() -> int:
	var unlocked_cuisines: Array = SaveManager.get_value("pot_luck.unlocked_cuisines", ["basic"]) as Array
	return IngredientDatabase.get_eligible_combos(unlocked_cuisines).size()
