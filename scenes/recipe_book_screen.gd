## Full-screen recipe book showing all possible combos.
## Discovered recipes show full details; undiscovered show "???".
extends Control

@onready var _back_button: Button = %BackButton
@onready var _progress_label: Label = %ProgressLabel
@onready var _progress_bar: Control = %ProgressBarDraw
@onready var _recipe_list: VBoxContainer = %RecipeList
@onready var _master_badge: Label = %MasterBadge

var _discovered_count: int = 0
var _total_count: int = 0


func _ready() -> void:
	AnalyticsManager.log_screen("recipe_book")

	_back_button.pressed.connect(_on_back)

	var recipes: Array[Dictionary] = RecipeBook.get_all_recipes()
	_discovered_count = RecipeBook.get_discovery_count()
	_total_count = RecipeBook.get_total_count()

	_progress_label.text = "%d / %d Recipes Discovered" % [_discovered_count, _total_count]

	# Progress bar draw
	_progress_bar.draw.connect(_draw_progress_bar)
	_progress_bar.queue_redraw()

	# Master Chef badge
	if _discovered_count >= _total_count and _total_count > 0:
		_master_badge.visible = true
		Juice.pulse(_master_badge, 1.06, 1.2)
	else:
		_master_badge.visible = false

	_build_recipe_list(recipes)
	_play_entrance_animations()


func _build_recipe_list(recipes: Array[Dictionary]) -> void:
	for recipe: Dictionary in recipes:
		var is_discovered: bool = recipe["discovered"] as bool
		var card: PanelContainer = _create_recipe_card(recipe, is_discovered)
		_recipe_list.add_child(card)


func _create_recipe_card(recipe: Dictionary, is_discovered: bool) -> PanelContainer:
	var panel: PanelContainer = PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 100)

	if is_discovered:
		# Accent border — left side colored strip
		var is_penalty: bool = recipe["is_penalty"] as bool
		var card_sb := StyleBoxFlat.new()
		card_sb.bg_color = Color(0.11, 0.11, 0.16)
		card_sb.set_corner_radius_all(12)
		card_sb.border_width_left = 4
		card_sb.border_color = Color(1, 0.85, 0.2) if not is_penalty else Color(1, 0.3, 0.2)
		card_sb.content_margin_left = 16
		card_sb.content_margin_right = 16
		card_sb.content_margin_top = 16
		card_sb.content_margin_bottom = 16
		panel.add_theme_stylebox_override("panel", card_sb)
	else:
		# Locked dimming
		var locked_sb := StyleBoxFlat.new()
		locked_sb.bg_color = Color(0.08, 0.08, 0.11)
		locked_sb.set_corner_radius_all(12)
		locked_sb.content_margin_left = 16
		locked_sb.content_margin_right = 16
		locked_sb.content_margin_top = 16
		locked_sb.content_margin_bottom = 16
		panel.add_theme_stylebox_override("panel", locked_sb)
		panel.modulate.a = 0.6

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
		# Ingredient color dots
		var ingredient_a_id: String = recipe["ingredient_a"] as String
		var ingredient_b_id: String = recipe["ingredient_b"] as String
		var a_data: IngredientData = IngredientDatabase.get_ingredient(ingredient_a_id)
		var b_data: IngredientData = IngredientDatabase.get_ingredient(ingredient_b_id)

		var dots_vbox := VBoxContainer.new()
		dots_vbox.add_theme_constant_override("separation", 4)
		dots_vbox.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		hbox.add_child(dots_vbox)

		for ing_data: IngredientData in [a_data, b_data]:
			if ing_data != null:
				var dot := ColorRect.new()
				dot.custom_minimum_size = Vector2(14, 14)
				dot.color = ing_data.color
				dots_vbox.add_child(dot)

		# Combo name
		var is_penalty: bool = recipe["is_penalty"] as bool
		var name_label: Label = Label.new()
		name_label.text = recipe["combo_name"] as String
		name_label.add_theme_font_size_override("font_size", 36)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		if is_penalty:
			name_label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.3))
		else:
			name_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3))
		hbox.add_child(name_label)

		# Ingredients text
		var a_name: String = a_data.display_name if a_data != null else ingredient_a_id
		var b_name: String = b_data.display_name if b_data != null else ingredient_b_id

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


func _draw_progress_bar() -> void:
	var rect: Rect2 = _progress_bar.get_rect()
	var bar_w: float = rect.size.x
	var bar_h: float = 8.0
	var y: float = (rect.size.y - bar_h) / 2.0

	# Background
	_progress_bar.draw_rect(Rect2(0, y, bar_w, bar_h), Color(0.15, 0.15, 0.22))

	# Fill
	if _total_count > 0:
		var fill_w: float = (float(_discovered_count) / float(_total_count)) * bar_w
		_progress_bar.draw_rect(Rect2(0, y, fill_w, bar_h), Color(1, 0.85, 0.2))


func _play_entrance_animations() -> void:
	# Title + progress fade in
	var title: Label = $SafeArea/VBox/TopBar/TitleLabel
	title.modulate.a = 0.0
	_progress_label.modulate.a = 0.0
	var t := create_tween().set_parallel(true)
	t.tween_property(title, "modulate:a", 1.0, 0.2)
	t.tween_property(_progress_label, "modulate:a", 1.0, 0.2)

	# Cards stagger pop_in
	var cards := _recipe_list.get_children()
	for i in cards.size():
		Juice.pop_in(cards[i], 0.3, 0.04 * i)


func _on_back() -> void:
	AnalyticsManager.log_event("button_clicked", {"button": "recipe_book_back"})
	GameManager.change_state(GameManager.GameState.MENU)
	GameManager.goto_scene("res://scenes/main_menu.tscn")
