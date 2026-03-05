## Daily challenge preview screen — shows today's ingredients before playing.
extends Control

@onready var _date_label: Label = %DateLabel
@onready var _best_label: Label = %BestLabel
@onready var _ingredient_grid: GridContainer = %IngredientGrid
@onready var _start_button: Button = %StartButton
@onready var _back_button: Button = %BackButton

var _daily_bag: Array[IngredientData] = []


func _ready() -> void:
	AnalyticsManager.log_screen("daily_preview")

	_start_button.pressed.connect(_on_start)
	_back_button.pressed.connect(_on_back)

	# Date display
	var date: Dictionary = Time.get_date_dict_from_system()
	_date_label.text = "%04d-%02d-%02d" % [date["year"], date["month"], date["day"]]

	# Best score
	if DailyChallenge.is_completed_today():
		var best: int = DailyChallenge.get_today_best()
		_best_label.text = "Your Best: %s" % Utils.format_number(best)
		_start_button.text = "Try Again"
	else:
		_best_label.text = "Not yet attempted"
		_start_button.text = "Start Challenge"

	# Build ingredient preview
	_daily_bag = DailyChallenge.get_daily_bag()
	_build_ingredient_list()


func _build_ingredient_list() -> void:
	for ingredient: IngredientData in _daily_bag:
		var card: PanelContainer = _create_ingredient_card(ingredient)
		_ingredient_grid.add_child(card)


func _create_ingredient_card(data: IngredientData) -> PanelContainer:
	var panel: PanelContainer = PanelContainer.new()
	panel.custom_minimum_size = Vector2(160, 80)

	var hbox: HBoxContainer = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)
	panel.add_child(hbox)

	# Color swatch
	var swatch: ColorRect = ColorRect.new()
	swatch.custom_minimum_size = Vector2(40, 40)
	swatch.color = data.color
	hbox.add_child(swatch)

	# Name + points
	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(vbox)

	var name_label: Label = Label.new()
	name_label.text = data.display_name
	name_label.add_theme_font_size_override("font_size", 26)
	vbox.add_child(name_label)

	var points_label: Label = Label.new()
	points_label.text = "+%d pts  | heat %.0f%%" % [data.points, data.heat * 100.0]
	points_label.add_theme_font_size_override("font_size", 20)
	points_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.65))
	vbox.add_child(points_label)

	return panel


func _on_start() -> void:
	AnalyticsManager.log_event("button_clicked", {"button": "daily_start"})
	GameManager.set_meta("game_mode", "daily")
	GameManager.goto_scene("res://scenes/game_scene.tscn")


func _on_back() -> void:
	AnalyticsManager.log_event("button_clicked", {"button": "daily_back"})
	GameManager.goto_scene("res://scenes/main_menu.tscn")
