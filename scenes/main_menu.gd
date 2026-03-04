## Main menu screen with Play and Settings buttons.
## Shows high score and GDPR consent popup on first launch.
extends Control

@onready var play_button: Button = %PlayButton
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
	settings_button.pressed.connect(_on_settings)

	AdManager.show_banner()
	_check_gdpr()


func _on_play() -> void:
	AnalyticsManager.log_event("button_clicked", {"button": "play"})
	GameManager.goto_scene("res://scenes/game_scene.tscn")


func _on_settings() -> void:
	AnalyticsManager.log_event("button_clicked", {"button": "settings"})
	UIManager.show_popup(SETTINGS_SCENE)


func _check_gdpr() -> void:
	var has_answered: bool = SaveManager.get_value("gdpr_answered", false) as bool
	if not has_answered:
		UIManager.show_popup(GDPR_SCENE)
