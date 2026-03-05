## Full-screen recipe book showing all possible combos.
## Discovered recipes show full details; undiscovered show "???".
extends Control

@onready var _back_button: Button = %BackButton
@onready var _progress_label: Label = %ProgressLabel
@onready var _recipe_list: VBoxContainer = %RecipeList
@onready var _master_badge: Label = %MasterBadge


func _ready() -> void:
	AnalyticsManager.log_screen("recipe_book")

	_back_button.pressed.connect(_on_back)

	var recipes: Array[Dictionary] = RecipeBook.get_all_recipes()
	var discovered_count: int = RecipeBook.get_discovery_count()
	var total_count: int = RecipeBook.get_total_count()

	_progress_label.text = "%d / %d Recipes Discovered" % [discovered_count, total_count]

	# Master Chef badge
	if discovered_count >= total_count and total_count > 0:
		_master_badge.visible = true
	else:
		_master_badge.visible = false

	_build_recipe_list(recipes)


func _build_recipe_list(recipes: Array[Dictionary]) -> void:
	for recipe: Dictionary in recipes:
		var is_discovered: bool = recipe["discovered"] as bool
		var card: PanelContainer = _create_recipe_card(recipe, is_discovered)
		_recipe_list.add_child(card)


func _create_recipe_card(recipe: Dictionary, is_discovered: bool) -> PanelContainer:
	var panel: PanelContainer = PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 100)

	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	panel.add_child(margin)

	var hbox: HBoxContainer = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 16)
	margin.add_child(hbox)

	if is_discovered:
		# Combo name
		var name_label: Label = Label.new()
		name_label.text = recipe["combo_name"] as String
		name_label.add_theme_font_size_override("font_size", 36)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		var is_penalty: bool = recipe["is_penalty"] as bool
		if is_penalty:
			name_label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.3))
		else:
			name_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3))
		hbox.add_child(name_label)

		# Ingredients
		var ingredient_a: String = recipe["ingredient_a"] as String
		var ingredient_b: String = recipe["ingredient_b"] as String
		var a_data: IngredientData = IngredientDatabase.get_ingredient(ingredient_a)
		var b_data: IngredientData = IngredientDatabase.get_ingredient(ingredient_b)
		var a_name: String = a_data.display_name if a_data != null else ingredient_a
		var b_name: String = b_data.display_name if b_data != null else ingredient_b

		var ingredients_label: Label = Label.new()
		ingredients_label.text = "%s + %s" % [a_name, b_name]
		ingredients_label.add_theme_font_size_override("font_size", 28)
		ingredients_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.75))
		hbox.add_child(ingredients_label)

		# Multiplier
		var mult_label: Label = Label.new()
		var multiplier: float = recipe["multiplier"] as float
		mult_label.text = "x%.1f" % multiplier
		mult_label.add_theme_font_size_override("font_size", 34)
		if is_penalty:
			mult_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.2))
		else:
			mult_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.4))
		hbox.add_child(mult_label)
	else:
		# Locked appearance
		var lock_label: Label = Label.new()
		lock_label.text = "???"
		lock_label.add_theme_font_size_override("font_size", 36)
		lock_label.add_theme_color_override("font_color", Color(0.4, 0.4, 0.45))
		lock_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hbox.add_child(lock_label)

		var hint_label: Label = Label.new()
		hint_label.text = "Undiscovered"
		hint_label.add_theme_font_size_override("font_size", 28)
		hint_label.add_theme_color_override("font_color", Color(0.35, 0.35, 0.4))
		hbox.add_child(hint_label)

	return panel


func _on_back() -> void:
	AnalyticsManager.log_event("button_clicked", {"button": "recipe_book_back"})
	GameManager.change_state(GameManager.GameState.MENU)
	GameManager.goto_scene("res://scenes/main_menu.tscn")
