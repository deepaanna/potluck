## Game over screen showing pot luck stats, score, and navigation buttons.
extends Control

@onready var score_label: Label = %ScoreLabel
@onready var high_score_label: Label = %HighScoreLabel
@onready var new_high_score_label: Label = %NewHighScoreLabel
@onready var play_again_button: Button = %PlayAgainButton
@onready var menu_button: Button = %MenuButton
@onready var outcome_label: Label = %OutcomeLabel
@onready var stats_label: Label = %StatsLabel


func _ready() -> void:
	AnalyticsManager.log_screen("game_over")

	var score: int = GameManager.score
	var high_score: int = SaveManager.get_value("high_score", 0) as int
	var is_new_high_score: bool = score >= high_score and score > 0

	score_label.text = "Score: %s" % Utils.format_number(score)
	high_score_label.text = "Best: %s" % Utils.format_number(high_score)
	new_high_score_label.visible = is_new_high_score

	play_again_button.pressed.connect(_on_play_again)
	menu_button.pressed.connect(_on_menu)

	# Show pot luck specific data
	_show_pot_luck_stats()

	# Try to show an interstitial ad
	AdManager.show_interstitial()

	# Check if Rate Us popup should be shown
	_try_show_rate_us()


func _show_pot_luck_stats() -> void:
	var data: Dictionary = {}
	if GameManager.has_meta("pot_luck_data"):
		data = GameManager.get_meta("pot_luck_data") as Dictionary

	var was_boilover: bool = data.get("was_boilover", false) as bool
	var ingredients_count: int = data.get("ingredients_count", 0) as int
	var combos: int = data.get("combos", 0) as int
	var combo_multiplier: float = data.get("combo_multiplier", 1.0) as float
	var streak_bonus: float = data.get("streak_bonus", 0.0) as float
	var bag_emptied: bool = data.get("bag_emptied", false) as bool

	if was_boilover:
		outcome_label.text = "BOILOVER!"
		outcome_label.add_theme_color_override("font_color", Color(1.0, 0.2, 0.1))
	elif bag_emptied:
		outcome_label.text = "PERFECT POT!"
		outcome_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.0))
	else:
		outcome_label.text = "Dish Served!"
		outcome_label.add_theme_color_override("font_color", Color(0.3, 0.9, 0.3))

	var stats_text: String = ""
	stats_text += "Ingredients: %d\n" % ingredients_count
	stats_text += "Combos: %d\n" % combos
	if combo_multiplier != 1.0:
		stats_text += "Combo Multiplier: x%.1f\n" % combo_multiplier
	if streak_bonus > 0.0:
		stats_text += "Streak Bonus: +%.0f%%\n" % (streak_bonus * 100.0)
	if bag_emptied:
		stats_text += "Clean Pot Bonus: x1.5\n"
	stats_label.text = stats_text


func _on_play_again() -> void:
	AnalyticsManager.log_event("button_clicked", {"button": "play_again"})
	GameManager.change_state(GameManager.GameState.MENU)
	GameManager.goto_scene("res://scenes/game_scene.tscn")


func _on_menu() -> void:
	AnalyticsManager.log_event("button_clicked", {"button": "menu"})
	GameManager.change_state(GameManager.GameState.MENU)
	GameManager.goto_scene("res://scenes/main_menu.tscn")


func _try_show_rate_us() -> void:
	var completed: bool = SaveManager.get_value("rate_us_completed", false) as bool
	var declined: bool = SaveManager.get_value("rate_us_declined", false) as bool
	if completed or declined:
		return

	var total_games: int = SaveManager.get_value("total_games", 0) as int
	var threshold: int = GameManager.config.rate_us_games_threshold
	if total_games >= threshold:
		var rate_us_scene: PackedScene = load("res://scenes/rate_us.tscn") as PackedScene
		UIManager.show_popup(rate_us_scene)
