## Debug menu popup — only accessible in debug builds.
## Provides reset progress, recipe manipulation, and score overrides.
extends BasePopup

@onready var _status_label: Label = %StatusLabel
@onready var _reset_progress_button: Button = %ResetProgressButton
@onready var _reset_recipes_button: Button = %ResetRecipesButton
@onready var _unlock_recipes_button: Button = %UnlockRecipesButton
@onready var _set_score_button: Button = %SetScoreButton
@onready var _close_button: Button = %CloseButton

var _confirm_reset: bool = false

# Progression debug buttons (created in code)
var _set_level_5_button: Button
var _set_level_15_button: Button
var _set_level_25_button: Button
var _add_xp_button: Button
var _unlock_cuisines_button: Button
var _reset_progression_button: Button


func _ready() -> void:
	_reset_progress_button.pressed.connect(_on_reset_progress)
	_reset_recipes_button.pressed.connect(_on_reset_recipes)
	_unlock_recipes_button.pressed.connect(_on_unlock_recipes)
	_set_score_button.pressed.connect(_on_set_score)
	_close_button.pressed.connect(dismiss)

	_create_progression_buttons()
	_refresh_status()


func _refresh_status() -> void:
	var high_score: int = SaveManager.get_value("high_score", 0) as int
	var total_games: int = SaveManager.get_value("total_games", 0) as int
	var total_served: int = SaveManager.get_value("pot_luck.stats.total_dishes_served", 0) as int
	var total_boilovers: int = SaveManager.get_value("pot_luck.stats.total_boilovers", 0) as int
	var perfect_pots: int = SaveManager.get_value("pot_luck.stats.perfect_pots", 0) as int
	var recipes: int = RecipeBook.get_discovery_count()
	var total_recipes: int = RecipeBook.get_total_count()
	var chef_level: int = SaveManager.get_value("pot_luck.chef_level", 1) as int
	var chef_xp: int = SaveManager.get_value("pot_luck.chef_xp", 0) as int
	var xp_needed: int = ProgressionManager.xp_for_level(chef_level)
	var cuisines: Array = SaveManager.get_value("pot_luck.unlocked_cuisines", ["basic"]) as Array

	_status_label.text = "High Score: %s | Games: %d\nServed: %d | Boilovers: %d | Perfect: %d\nRecipes: %d/%d\nChef Level: %d | XP: %d/%d\nCuisines: %s" % [
		Utils.format_number(high_score), total_games,
		total_served, total_boilovers, perfect_pots,
		recipes, total_recipes,
		chef_level, chef_xp, xp_needed,
		", ".join(cuisines),
	]


func _on_reset_progress() -> void:
	if not _confirm_reset:
		_confirm_reset = true
		_reset_progress_button.text = "CONFIRM: Reset Everything?"
		_reset_progress_button.add_theme_color_override("font_color", Color(1.0, 0.2, 0.1))
		# Auto-cancel confirm after 3 seconds
		get_tree().create_timer(3.0).timeout.connect(func() -> void:
			_confirm_reset = false
			_reset_progress_button.text = "Reset All Progress"
			_reset_progress_button.remove_theme_color_override("font_color")
		)
		return

	_confirm_reset = false
	SaveManager.reset()
	_reset_progress_button.text = "Reset All Progress"
	_reset_progress_button.remove_theme_color_override("font_color")
	_show_feedback("All progress reset!")
	_refresh_status()


func _on_reset_recipes() -> void:
	SaveManager.set_value("pot_luck.recipes_discovered", [])
	_show_feedback("Recipes cleared!")
	_refresh_status()


func _on_unlock_recipes() -> void:
	var all_combos: Array[ComboData] = IngredientDatabase.get_all_combos()
	var names: Array = []
	for combo: ComboData in all_combos:
		names.append(combo.combo_name)
	SaveManager.set_value("pot_luck.recipes_discovered", names)
	_show_feedback("All %d recipes unlocked!" % names.size())
	_refresh_status()


func _on_set_score() -> void:
	SaveManager.set_value("high_score", 999)
	_show_feedback("High score set to 999")
	_refresh_status()


func _create_progression_buttons() -> void:
	# Find the VBox containing existing buttons
	var button_parent: Control = _reset_progress_button.get_parent()

	_set_level_5_button = _make_debug_button("Set Level 5")
	_set_level_5_button.pressed.connect(func() -> void: _set_chef_level(5))
	button_parent.add_child(_set_level_5_button)

	_set_level_15_button = _make_debug_button("Set Level 15")
	_set_level_15_button.pressed.connect(func() -> void: _set_chef_level(15))
	button_parent.add_child(_set_level_15_button)

	_set_level_25_button = _make_debug_button("Set Level 25")
	_set_level_25_button.pressed.connect(func() -> void: _set_chef_level(25))
	button_parent.add_child(_set_level_25_button)

	_add_xp_button = _make_debug_button("Add 1000 XP")
	_add_xp_button.pressed.connect(_on_add_xp)
	button_parent.add_child(_add_xp_button)

	_unlock_cuisines_button = _make_debug_button("Unlock All Cuisines")
	_unlock_cuisines_button.pressed.connect(_on_unlock_cuisines)
	button_parent.add_child(_unlock_cuisines_button)

	_reset_progression_button = _make_debug_button("Reset Progression")
	_reset_progression_button.pressed.connect(_on_reset_progression)
	button_parent.add_child(_reset_progression_button)


func _make_debug_button(text: String) -> Button:
	var btn: Button = Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(0, 60)
	btn.add_theme_font_size_override("font_size", 24)
	return btn


func _set_chef_level(target_level: int) -> void:
	SaveManager.set_value("pot_luck.chef_level", target_level)
	SaveManager.set_value("pot_luck.chef_xp", 0)
	GameManager.chef_level = target_level
	GameManager.chef_xp = 0

	# Sync cuisine unlocks
	var cuisines: Array[String] = ProgressionManager.get_unlocked_cuisines(target_level)
	SaveManager.set_value("pot_luck.unlocked_cuisines", cuisines)

	# Sync abilities
	var abilities: Array[String] = ProgressionManager.get_unlocked_abilities(target_level)
	SaveManager.set_value("pot_luck.abilities_unlocked", abilities)

	_show_feedback("Set to Chef Level %d" % target_level)
	_refresh_status()


func _on_add_xp() -> void:
	var chef_level: int = SaveManager.get_value("pot_luck.chef_level", 1) as int
	var chef_xp: int = SaveManager.get_value("pot_luck.chef_xp", 0) as int
	chef_xp += 1000

	# Process level-ups
	while chef_xp >= ProgressionManager.xp_for_level(chef_level):
		chef_xp -= ProgressionManager.xp_for_level(chef_level)
		chef_level += 1

	SaveManager.set_value("pot_luck.chef_level", chef_level)
	SaveManager.set_value("pot_luck.chef_xp", chef_xp)
	GameManager.chef_level = chef_level
	GameManager.chef_xp = chef_xp

	# Sync unlocks
	var cuisines: Array[String] = ProgressionManager.get_unlocked_cuisines(chef_level)
	SaveManager.set_value("pot_luck.unlocked_cuisines", cuisines)
	var abilities: Array[String] = ProgressionManager.get_unlocked_abilities(chef_level)
	SaveManager.set_value("pot_luck.abilities_unlocked", abilities)

	_show_feedback("+1000 XP → Level %d" % chef_level)
	_refresh_status()


func _on_unlock_cuisines() -> void:
	SaveManager.set_value("pot_luck.unlocked_cuisines", ["basic", "italian", "japanese"])
	_show_feedback("All cuisines unlocked!")
	_refresh_status()


func _on_reset_progression() -> void:
	SaveManager.set_value("pot_luck.chef_level", 1)
	SaveManager.set_value("pot_luck.chef_xp", 0)
	SaveManager.set_value("pot_luck.abilities_unlocked", [])
	SaveManager.set_value("pot_luck.unlocked_cuisines", ["basic"])
	GameManager.chef_level = 1
	GameManager.chef_xp = 0
	_show_feedback("Progression reset to Level 1")
	_refresh_status()


func _show_feedback(text: String) -> void:
	_status_label.text = text
	_status_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.4))
	get_tree().create_timer(1.5).timeout.connect(func() -> void:
		_status_label.remove_theme_color_override("font_color")
		_refresh_status()
	)
