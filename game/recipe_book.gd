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


## Returns all possible combos with a "discovered" flag.
## Each entry: { "combo_name", "ingredient_a", "ingredient_b", "multiplier",
##               "is_penalty", "discovered" }
static func get_all_recipes() -> Array[Dictionary]:
	var all_combos: Array[ComboData] = IngredientDatabase.get_all_combos()
	var discovered: Array = SaveManager.get_value("pot_luck.recipes_discovered", []) as Array
	var result: Array[Dictionary] = []

	for combo: ComboData in all_combos:
		var is_discovered: bool = combo.combo_name in discovered
		result.append({
			"combo_name": combo.combo_name,
			"ingredient_a": combo.ingredient_a,
			"ingredient_b": combo.ingredient_b,
			"multiplier": combo.multiplier,
			"is_penalty": combo.is_penalty,
			"discovered": is_discovered,
		})

	return result


## Returns the number of discovered recipes.
static func get_discovery_count() -> int:
	var discovered: Array = SaveManager.get_value("pot_luck.recipes_discovered", []) as Array
	return discovered.size()


## Returns the total number of possible recipes.
static func get_total_count() -> int:
	return IngredientDatabase.get_all_combos().size()
