## Main menu screen with Play, Daily Challenge, Recipe Book, and Settings buttons.
## Shows high score and GDPR consent popup on first launch.
extends Control

@onready var play_button: Button = %PlayButton
@onready var daily_button: Button = %DailyButton
@onready var daily_best_label: Label = %DailyBestLabel
@onready var recipe_button: Button = %RecipeButton
@onready var settings_button: Button = %SettingsButton
@onready var title_label: Label = %TitleLabel
@onready var high_score_label: Label = %HighScoreLabel

const SETTINGS_SCENE: PackedScene = preload("res://scenes/settings.tscn")
const GDPR_SCENE: PackedScene = preload("res://scenes/gdpr_consent.tscn")


func _ready() -> void:
	if GameManager.current_state != GameManager.GameState.MENU:
		GameManager.change_state(GameManager.GameState.MENU)
	AnalyticsManager.log_screen("main_menu")

	title_label.text = GameManager.config.game_name

	var high_score: int = SaveManager.get_value("high_score", 0) as int
	if high_score > 0:
		high_score_label.text = "Best: %s" % Utils.format_number(high_score)
	else:
		high_score_label.text = ""

	play_button.pressed.connect(_on_play)
	daily_button.pressed.connect(_on_daily)
	recipe_button.pressed.connect(_on_recipe_book)
	settings_button.pressed.connect(_on_settings)

	_update_daily_button()
	_update_recipe_button()

	AdManager.show_banner()
	_check_gdpr()


func _update_daily_button() -> void:
	if DailyChallenge.is_completed_today():
		var best: int = DailyChallenge.get_today_best()
		daily_button.text = "Daily Challenge"
		daily_best_label.text = "Today's Best: %s" % Utils.format_number(best)
		daily_best_label.visible = true
	else:
		daily_button.text = "Daily Challenge  NEW!"
		daily_best_label.text = ""
		daily_best_label.visible = false


func _update_recipe_button() -> void:
	var discovered: int = RecipeBook.get_discovery_count()
	var total: int = RecipeBook.get_total_count()
	recipe_button.text = "Recipe Book  (%d/%d)" % [discovered, total]


func _on_play() -> void:
	AnalyticsManager.log_event("button_clicked", {"button": "play"})
	GameManager.set_meta("game_mode", "endless")
	GameManager.goto_scene("res://scenes/game_scene.tscn")


func _on_daily() -> void:
	AnalyticsManager.log_event("button_clicked", {"button": "daily_challenge"})
	GameManager.goto_scene("res://scenes/daily_preview.tscn")


func _on_recipe_book() -> void:
	AnalyticsManager.log_event("button_clicked", {"button": "recipe_book"})
	GameManager.goto_scene("res://scenes/recipe_book_screen.tscn")


func _on_settings() -> void:
	AnalyticsManager.log_event("button_clicked", {"button": "settings"})
	UIManager.show_popup(SETTINGS_SCENE)


func _check_gdpr() -> void:
	var has_answered: bool = SaveManager.get_value("gdpr_answered", false) as bool
	if not has_answered:
		UIManager.show_popup(GDPR_SCENE)
