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


func _ready() -> void:
	_reset_progress_button.pressed.connect(_on_reset_progress)
	_reset_recipes_button.pressed.connect(_on_reset_recipes)
	_unlock_recipes_button.pressed.connect(_on_unlock_recipes)
	_set_score_button.pressed.connect(_on_set_score)
	_close_button.pressed.connect(dismiss)

	_refresh_status()


func _refresh_status() -> void:
	var high_score: int = SaveManager.get_value("high_score", 0) as int
	var total_games: int = SaveManager.get_value("total_games", 0) as int
	var total_served: int = SaveManager.get_value("pot_luck.stats.total_dishes_served", 0) as int
	var total_boilovers: int = SaveManager.get_value("pot_luck.stats.total_boilovers", 0) as int
	var perfect_pots: int = SaveManager.get_value("pot_luck.stats.perfect_pots", 0) as int
	var recipes: int = RecipeBook.get_discovery_count()
	var total_recipes: int = RecipeBook.get_total_count()

	_status_label.text = "High Score: %s | Games: %d\nServed: %d | Boilovers: %d | Perfect: %d\nRecipes: %d/%d" % [
		Utils.format_number(high_score), total_games,
		total_served, total_boilovers, perfect_pots,
		recipes, total_recipes,
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


func _show_feedback(text: String) -> void:
	_status_label.text = text
	_status_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.4))
	get_tree().create_timer(1.5).timeout.connect(func() -> void:
		_status_label.remove_theme_color_override("font_color")
		_refresh_status()
	)
