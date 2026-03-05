## Daily challenge system — deterministic seed from today's date ensures
## every player gets the same ingredient sequence each day.
class_name DailyChallenge
extends RefCounted


## Returns a deterministic seed from today's date.
static func get_daily_seed() -> int:
	var date: Dictionary = Time.get_date_dict_from_system()
	var year: int = date["year"] as int
	var month: int = date["month"] as int
	var day: int = date["day"] as int
	return year * 10000 + month * 100 + day


## Returns today's date string in YYYY-MM-DD format.
static func _get_today_string() -> String:
	var date: Dictionary = Time.get_date_dict_from_system()
	return "%04d-%02d-%02d" % [date["year"], date["month"], date["day"]]


## Builds a bag using the daily seed so every player gets the same sequence.
static func get_daily_bag() -> Array[IngredientData]:
	var seed_val: int = get_daily_seed()
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_val

	var all_ingredients: Array[IngredientData] = IngredientDatabase.get_all_ingredients()
	var pool: Array[IngredientData] = []

	for ingredient: IngredientData in all_ingredients:
		var copies: int = _rarity_copies(ingredient.rarity)
		for i: int in range(copies):
			pool.append(ingredient)

	# Deterministic shuffle using seeded RNG
	for i: int in range(pool.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var temp: IngredientData = pool[i]
		pool[i] = pool[j]
		pool[j] = temp

	var bag_size: int = GameManager.config.bag_size
	var count: int = mini(bag_size, pool.size())
	var bag: Array[IngredientData] = []
	for i: int in range(count):
		bag.append(pool[i])

	return bag


## Checks if the daily challenge has been completed today.
static func is_completed_today() -> bool:
	var last_date: String = SaveManager.get_value("pot_luck.daily_challenge.last_date", "") as String
	return last_date == _get_today_string()


## Saves the score if it's higher than today's best.
static func submit_score(score: int) -> void:
	var today: String = _get_today_string()
	var last_date: String = SaveManager.get_value("pot_luck.daily_challenge.last_date", "") as String

	if last_date != today:
		# New day — reset best score
		SaveManager.set_value("pot_luck.daily_challenge.last_date", today)
		SaveManager.set_value("pot_luck.daily_challenge.best_score", score)
	else:
		var current_best: int = SaveManager.get_value("pot_luck.daily_challenge.best_score", 0) as int
		if score > current_best:
			SaveManager.set_value("pot_luck.daily_challenge.best_score", score)


## Returns today's best score (0 if not played today).
static func get_today_best() -> int:
	var last_date: String = SaveManager.get_value("pot_luck.daily_challenge.last_date", "") as String
	if last_date != _get_today_string():
		return 0
	return SaveManager.get_value("pot_luck.daily_challenge.best_score", 0) as int


static func _rarity_copies(rarity: IngredientData.Rarity) -> int:
	match rarity:
		IngredientData.Rarity.COMMON:
			return 3
		IngredientData.Rarity.UNCOMMON:
			return 2
		IngredientData.Rarity.RARE:
			return 1
	return 1
