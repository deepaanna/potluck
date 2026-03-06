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
@onready var title_art: TextureRect = %TitleArt

const SETTINGS_SCENE: PackedScene = preload("res://scenes/settings.tscn")
const GDPR_SCENE: PackedScene = preload("res://scenes/gdpr_consent.tscn")
const DEBUG_MENU_SCENE: PackedScene = preload("res://scenes/debug_menu.tscn")


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

	# If TitleArt has a texture, show it instead of text
	if title_art.texture:
		title_art.visible = true
		title_label.visible = false

	if OS.is_debug_build():
		_add_debug_button()

	AdManager.show_banner()
	_check_gdpr()
	_play_entrance_animations()


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


func _play_entrance_animations() -> void:
	# Title slide down + fade in
	var title_node: Control = title_art if title_art.visible else title_label
	var original_y: float = title_node.position.y
	title_node.position.y = original_y - 30
	title_node.modulate.a = 0.0
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(title_node, "position:y", original_y, 0.35).set_trans(Tween.TRANS_BACK)
	tween.tween_property(title_node, "modulate:a", 1.0, 0.35)

	# High score fade in
	high_score_label.modulate.a = 0.0
	var hs_tween := create_tween()
	hs_tween.tween_interval(0.15)
	hs_tween.tween_property(high_score_label, "modulate:a", 1.0, 0.2)

	# Button stagger pop_in
	Juice.pop_in(play_button, 0.3, 0.1)
	Juice.pop_in(daily_button, 0.3, 0.18)
	Juice.pop_in(recipe_button, 0.3, 0.26)
	Juice.pop_in(settings_button, 0.3, 0.34)


func _add_debug_button() -> void:
	var debug_button: Button = Button.new()
	debug_button.text = "Debug"
	debug_button.custom_minimum_size = Vector2(200, 60)
	debug_button.add_theme_font_size_override("font_size", 24)
	debug_button.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3, 0.7))
	debug_button.flat = true
	# Place it in the bottom-left corner
	debug_button.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	debug_button.offset_left = 10
	debug_button.offset_top = -70
	debug_button.offset_right = 210
	debug_button.offset_bottom = -10
	add_child(debug_button)
	debug_button.pressed.connect(func() -> void:
		UIManager.show_popup(DEBUG_MENU_SCENE)
	)


func _check_gdpr() -> void:
	var has_answered: bool = SaveManager.get_value("gdpr_answered", false) as bool
	if not has_answered:
		UIManager.show_popup(GDPR_SCENE)
