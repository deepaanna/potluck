## Static database of all ingredients and combos.
class_name IngredientDatabase
extends RefCounted

static var _ingredients: Dictionary = {}
static var _combos: Array[ComboData] = []
static var _initialized: bool = false


static func _ensure_init() -> void:
	if _initialized:
		return
	_initialized = true
	_init_ingredients()
	_init_combos()


static func get_ingredient(id: String) -> IngredientData:
	_ensure_init()
	return _ingredients.get(id) as IngredientData


static func get_all_ingredients() -> Array[IngredientData]:
	_ensure_init()
	var result: Array[IngredientData] = []
	for ingredient: IngredientData in _ingredients.values():
		result.append(ingredient)
	return result


static func get_ingredients_by_cuisine(cuisine: IngredientData.Cuisine) -> Array[IngredientData]:
	_ensure_init()
	var result: Array[IngredientData] = []
	for ingredient: IngredientData in _ingredients.values():
		if ingredient.cuisine == cuisine:
			result.append(ingredient)
	return result


static func get_all_combos() -> Array[ComboData]:
	_ensure_init()
	return _combos


static func find_new_combos(pot_ids: Array[String], new_id: String) -> Array[ComboData]:
	_ensure_init()
	var found: Array[ComboData] = []
	for combo: ComboData in _combos:
		var a: String = combo.ingredient_a
		var b: String = combo.ingredient_b
		if (new_id == a and b in pot_ids) or (new_id == b and a in pot_ids):
			found.append(combo)
	return found


static func _add(id: String, display_name: String, points: int, heat: float, rarity: IngredientData.Rarity, cuisine: IngredientData.Cuisine, color: Color) -> void:
	_ingredients[id] = IngredientData.create(id, display_name, points, heat, rarity, cuisine, color)


static func _init_ingredients() -> void:
	# Basic (8)
	_add("garlic", "Garlic", 3, 0.08, IngredientData.Rarity.COMMON, IngredientData.Cuisine.BASIC, Color(0.96, 0.93, 0.80))
	_add("butter", "Butter", 4, 0.06, IngredientData.Rarity.COMMON, IngredientData.Cuisine.BASIC, Color(1.0, 0.95, 0.55))
	_add("onion", "Onion", 3, 0.10, IngredientData.Rarity.COMMON, IngredientData.Cuisine.BASIC, Color(0.85, 0.75, 0.55))
	_add("pepper", "Pepper", 2, 0.15, IngredientData.Rarity.COMMON, IngredientData.Cuisine.BASIC, Color(0.2, 0.2, 0.2))
	_add("salt", "Salt", 1, 0.03, IngredientData.Rarity.COMMON, IngredientData.Cuisine.BASIC, Color(0.95, 0.95, 0.95))
	_add("olive_oil", "Olive Oil", 3, 0.05, IngredientData.Rarity.UNCOMMON, IngredientData.Cuisine.BASIC, Color(0.7, 0.75, 0.2))
	_add("tomato", "Tomato", 4, 0.08, IngredientData.Rarity.COMMON, IngredientData.Cuisine.BASIC, Color(0.9, 0.2, 0.15))
	_add("herbs", "Herbs", 5, 0.04, IngredientData.Rarity.UNCOMMON, IngredientData.Cuisine.BASIC, Color(0.3, 0.7, 0.25))

	# Italian (6)
	_add("basil", "Basil", 5, 0.05, IngredientData.Rarity.UNCOMMON, IngredientData.Cuisine.ITALIAN, Color(0.2, 0.65, 0.15))
	_add("mozzarella", "Mozzarella", 6, 0.07, IngredientData.Rarity.UNCOMMON, IngredientData.Cuisine.ITALIAN, Color(0.97, 0.97, 0.90))
	_add("prosciutto", "Prosciutto", 7, 0.12, IngredientData.Rarity.RARE, IngredientData.Cuisine.ITALIAN, Color(0.85, 0.45, 0.4))
	_add("truffle", "Truffle", 10, 0.20, IngredientData.Rarity.RARE, IngredientData.Cuisine.ITALIAN, Color(0.25, 0.15, 0.1))
	_add("parmesan", "Parmesan", 6, 0.06, IngredientData.Rarity.UNCOMMON, IngredientData.Cuisine.ITALIAN, Color(1.0, 0.9, 0.6))
	_add("balsamic", "Balsamic", 5, 0.10, IngredientData.Rarity.UNCOMMON, IngredientData.Cuisine.ITALIAN, Color(0.3, 0.1, 0.1))

	# Japanese (6)
	_add("miso", "Miso", 5, 0.07, IngredientData.Rarity.UNCOMMON, IngredientData.Cuisine.JAPANESE, Color(0.85, 0.7, 0.4))
	_add("wasabi", "Wasabi", 4, 0.25, IngredientData.Rarity.RARE, IngredientData.Cuisine.JAPANESE, Color(0.5, 0.8, 0.3))
	_add("nori", "Nori", 3, 0.03, IngredientData.Rarity.COMMON, IngredientData.Cuisine.JAPANESE, Color(0.15, 0.3, 0.15))
	_add("ginger", "Ginger", 4, 0.12, IngredientData.Rarity.UNCOMMON, IngredientData.Cuisine.JAPANESE, Color(0.95, 0.85, 0.5))
	_add("soy_sauce", "Soy Sauce", 5, 0.08, IngredientData.Rarity.UNCOMMON, IngredientData.Cuisine.JAPANESE, Color(0.3, 0.15, 0.05))
	_add("yuzu", "Yuzu", 6, 0.06, IngredientData.Rarity.UNCOMMON, IngredientData.Cuisine.JAPANESE, Color(1.0, 0.85, 0.2))


static func _init_combos() -> void:
	# Basic combos
	_combos.append(ComboData.create("Chef's Kiss", "garlic", "butter", 2.0))
	_combos.append(ComboData.create("Garden Fresh", "tomato", "herbs", 1.8))
	_combos.append(ComboData.create("Soffritto", "onion", "olive_oil", 1.5))
	_combos.append(ComboData.create("Classic Season", "salt", "pepper", 1.3))

	# Italian combos
	_combos.append(ComboData.create("Caprese", "basil", "mozzarella", 2.5))
	_combos.append(ComboData.create("Salumi Board", "prosciutto", "parmesan", 2.2))
	_combos.append(ComboData.create("Black Gold", "truffle", "butter", 3.0))
	_combos.append(ComboData.create("Margherita", "tomato", "basil", 2.0))
	_combos.append(ComboData.create("Tuscan Drizzle", "balsamic", "olive_oil", 1.8))

	# Japanese combos
	_combos.append(ComboData.create("Umami Bomb", "miso", "nori", 2.5))
	_combos.append(ComboData.create("Fire & Ice", "wasabi", "ginger", 2.2))
	_combos.append(ComboData.create("Teriyaki Base", "soy_sauce", "ginger", 2.0))
	_combos.append(ComboData.create("Zen Garden", "yuzu", "miso", 2.5))

	# Penalty combos
	_combos.append(ComboData.create("Too Hot!", "wasabi", "pepper", 0.5, 0.15))
	_combos.append(ComboData.create("Flavor Clash", "truffle", "wasabi", 0.3))
