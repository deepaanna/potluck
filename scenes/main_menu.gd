## Main menu screen with Play and Settings buttons.
## Shows GDPR consent popup on first launch.
extends Control

@onready var play_button: Button = %PlayButton
@onready var settings_button: Button = %SettingsButton
@onready var title_label: Label = %TitleLabel

const SETTINGS_SCENE: PackedScene = preload("res://scenes/settings.tscn")
const GDPR_SCENE: PackedScene = preload("res://scenes/gdpr_consent.tscn")


func _ready() -> void:
	if GameManager.current_state != GameManager.GameState.MENU:
		GameManager.change_state(GameManager.GameState.MENU)
	AnalyticsManager.log_screen("main_menu")

	title_label.text = GameManager.config.game_name

	play_button.pressed.connect(_on_play)
	settings_button.pressed.connect(_on_settings)

	_check_gdpr()


func _on_play() -> void:
	AnalyticsManager.log_event("button_clicked", {"button": "play"})
	GameManager.goto_scene("res://scenes/game_scene.tscn")


func _on_settings() -> void:
	AnalyticsManager.log_event("button_clicked", {"button": "settings"})
	UIManager.show_popup(SETTINGS_SCENE)


func _check_gdpr() -> void:
	# gdpr_consent defaults to false in SaveManager; once the user
	# answers, gdpr_consent.answered is set to true
	var has_answered: bool = SaveManager.get_value("gdpr_answered", false) as bool
	if not has_answered:
		UIManager.show_popup(GDPR_SCENE)
