## Rewards screen — animated card reveals showcasing round results.
## Follows game over, provides play-again and menu navigation.
extends Control

@onready var _header_label: Label = %HeaderLabel
@onready var _card_list: VBoxContainer = %CardList
@onready var _button_bar: HBoxContainer = %ButtonBar
@onready var _play_again_button: Button = %PlayAgainButton
@onready var _menu_button: Button = %MenuButton
@onready var _vfx_layer: Control = %VFXLayer

var _pot_luck_data: Dictionary = {}
var _was_boilover: bool = false
var _was_daily: bool = false
var _score: int = 0
var _is_new_high_score: bool = false

# Card styling
const CARD_MARGIN: int = 20
const HEADER_FONT_SIZE: int = 28
const VALUE_FONT_SIZE: int = 34
const BODY_FONT_SIZE: int = 24
const CARD_STAGGER_DELAY: float = 0.12
const ACCENT_GOLD: Color = Color(1.0, 0.85, 0.0)
const ACCENT_GREEN: Color = Color(0.3, 0.9, 0.3)
const ACCENT_RED: Color = Color(1.0, 0.2, 0.1)
const MUTED_COLOR: Color = Color(0.5, 0.5, 0.6)


func _ready() -> void:
	AnalyticsManager.log_screen("rewards_screen")

	if GameManager.has_meta("pot_luck_data"):
		_pot_luck_data = GameManager.get_meta("pot_luck_data") as Dictionary

	_was_boilover = _pot_luck_data.get("was_boilover", false) as bool
	_was_daily = _pot_luck_data.get("mode", "endless") == "daily"
	_score = GameManager.score
	var high_score: int = SaveManager.get_value("high_score", 0) as int
	_is_new_high_score = _score >= high_score and _score > 0

	# Header
	if _was_boilover:
		_header_label.text = "Better Luck Next Time"
	elif _was_daily:
		_header_label.text = "Daily Results"
	else:
		_header_label.text = "Round Results"

	# Daily mode button text
	if _was_daily:
		_play_again_button.text = "Try Daily Again"

	# Wire buttons
	_play_again_button.pressed.connect(_on_play_again)
	_menu_button.pressed.connect(_on_menu)

	# Hide buttons initially for animation
	_button_bar.modulate.a = 0.0

	# Hide header initially
	_header_label.modulate.a = 0.0

	# Build and animate cards
	_build_cards()

	# Rate-us check (moved from game_over to here)
	_try_show_rate_us()


func _build_cards() -> void:
	var cards: Array[PanelContainer] = []

	# 1. Score Card (always)
	cards.append(_build_score_card())

	if not _was_boilover:
		# 2. Ingredients Card
		var ingredients_count: int = _pot_luck_data.get("ingredients_count", 0) as int
		if ingredients_count > 0:
			cards.append(_build_ingredients_card())

		# 3. Combos Card
		var triggered_combos: Array = _pot_luck_data.get("triggered_combos", []) as Array
		if triggered_combos.size() > 0:
			cards.append(_build_combos_card(triggered_combos))

		# 4. Recipes Card
		var new_recipes: Array = _pot_luck_data.get("new_recipes", []) as Array
		if new_recipes.size() > 0:
			cards.append(_build_recipes_card(new_recipes))

		# 5. Streak Card
		var streak_bonus: float = _pot_luck_data.get("streak_bonus", 0.0) as float
		if streak_bonus > 0.0:
			cards.append(_build_streak_card(streak_bonus))
	else:
		# Boilover: still show ingredients
		var ingredients_count: int = _pot_luck_data.get("ingredients_count", 0) as int
		if ingredients_count > 0:
			cards.append(_build_ingredients_card())

	# 6. Milestones Card (always check)
	var milestones: Array[Dictionary] = _check_milestones()
	if milestones.size() > 0:
		cards.append(_build_milestones_card(milestones))

	# Add cards to list
	for card: PanelContainer in cards:
		_card_list.add_child(card)

	# Animate entrance
	_animate_entrance(cards)


# ── Card Builders ─────────────────────────────────────────────────────────

func _build_score_card() -> PanelContainer:
	var card: PanelContainer = _create_card_container()
	var vbox: VBoxContainer = _get_card_content(card)

	# Header row
	var header_hbox: HBoxContainer = _create_header_row("Score", "")
	vbox.add_child(header_hbox)

	# Score value (large)
	var score_value: Label = Label.new()
	score_value.add_theme_font_size_override("font_size", 56)
	score_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	score_value.text = Utils.format_number(_score)

	if _was_boilover:
		score_value.add_theme_color_override("font_color", ACCENT_RED)
	elif _is_new_high_score:
		score_value.add_theme_color_override("font_color", ACCENT_GOLD)
	vbox.add_child(score_value)

	# New high score badge
	if _is_new_high_score and not _was_boilover:
		var badge: Label = Label.new()
		badge.text = "NEW BEST!"
		badge.add_theme_font_size_override("font_size", 30)
		badge.add_theme_color_override("font_color", ACCENT_GOLD)
		badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(badge)

		# Gold accent border on the card
		_set_card_accent(card, ACCENT_GOLD)

	# Show improvement over previous high score
	var previous_high: int = _pot_luck_data.get("previous_high_score", 0) as int
	if not _was_boilover and not _is_new_high_score and _score > 0 and previous_high > 0:
		var diff: int = _score - previous_high
		if diff > 0:
			var improvement: Label = Label.new()
			improvement.text = "+%s points over previous best" % Utils.format_number(diff)
			improvement.add_theme_font_size_override("font_size", 22)
			improvement.add_theme_color_override("font_color", ACCENT_GREEN)
			improvement.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			vbox.add_child(improvement)

	# Daily best comparison
	if _was_daily:
		var daily_best: int = DailyChallenge.get_today_best()
		if daily_best > 0:
			var daily_label: Label = Label.new()
			daily_label.text = "Daily Best: %s" % Utils.format_number(daily_best)
			daily_label.add_theme_font_size_override("font_size", 24)
			daily_label.add_theme_color_override("font_color", MUTED_COLOR)
			daily_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			vbox.add_child(daily_label)

	if _was_boilover:
		_set_card_accent(card, ACCENT_RED)

	return card


func _build_ingredients_card() -> PanelContainer:
	var card: PanelContainer = _create_card_container()
	var vbox: VBoxContainer = _get_card_content(card)

	var ingredients_count: int = _pot_luck_data.get("ingredients_count", 0) as int
	var header_hbox: HBoxContainer = _create_header_row("Ingredients Used", str(ingredients_count))
	vbox.add_child(header_hbox)

	# Colored dots row
	var pot_colors: PackedColorArray = _pot_luck_data.get("pot_colors", PackedColorArray()) as PackedColorArray
	if pot_colors.size() > 0:
		var dots_container: HBoxContainer = HBoxContainer.new()
		dots_container.alignment = BoxContainer.ALIGNMENT_CENTER
		dots_container.add_theme_constant_override("separation", 6)
		for color: Color in pot_colors:
			var dot: ColorRect = ColorRect.new()
			dot.custom_minimum_size = Vector2(16, 16)
			dot.color = color
			dots_container.add_child(dot)
		vbox.add_child(dots_container)

	# Clean pot badge
	var bag_emptied: bool = _pot_luck_data.get("bag_emptied", false) as bool
	if bag_emptied and not _was_boilover:
		var badge: Label = Label.new()
		badge.text = "CLEAN POT x1.5"
		badge.add_theme_font_size_override("font_size", 26)
		badge.add_theme_color_override("font_color", ACCENT_GOLD)
		badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(badge)

	if _was_boilover:
		_set_card_accent(card, ACCENT_RED)

	return card


func _build_combos_card(triggered_combos: Array) -> PanelContainer:
	var card: PanelContainer = _create_card_container()
	var vbox: VBoxContainer = _get_card_content(card)

	var header_hbox: HBoxContainer = _create_header_row("Combos Triggered", str(triggered_combos.size()))
	vbox.add_child(header_hbox)

	# Find best combo multiplier
	var best_multiplier: float = 0.0
	for combo_dict: Dictionary in triggered_combos:
		var mult: float = combo_dict.get("multiplier", 1.0) as float
		if not (combo_dict.get("is_penalty", false) as bool) and mult > best_multiplier:
			best_multiplier = mult

	# List each combo
	for combo_dict: Dictionary in triggered_combos:
		var combo_hbox: HBoxContainer = HBoxContainer.new()
		combo_hbox.add_theme_constant_override("separation", 8)

		var name_label: Label = Label.new()
		name_label.text = combo_dict.get("combo_name", "") as String
		name_label.add_theme_font_size_override("font_size", BODY_FONT_SIZE)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		combo_hbox.add_child(name_label)

		var mult_label: Label = Label.new()
		var multiplier: float = combo_dict.get("multiplier", 1.0) as float
		var is_penalty: bool = combo_dict.get("is_penalty", false) as bool
		mult_label.text = "x%.1f" % multiplier
		mult_label.add_theme_font_size_override("font_size", BODY_FONT_SIZE)
		mult_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

		if is_penalty:
			name_label.add_theme_color_override("font_color", ACCENT_RED)
			mult_label.add_theme_color_override("font_color", ACCENT_RED)
		else:
			name_label.add_theme_color_override("font_color", ACCENT_GOLD)
			mult_label.add_theme_color_override("font_color", ACCENT_GOLD)

		# Highlight best combo
		if not is_penalty and multiplier == best_multiplier and best_multiplier > 1.0:
			name_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.5))

		combo_hbox.add_child(mult_label)
		vbox.add_child(combo_hbox)

	return card


func _build_recipes_card(new_recipes: Array) -> PanelContainer:
	var card: PanelContainer = _create_card_container()
	var vbox: VBoxContainer = _get_card_content(card)

	var header_hbox: HBoxContainer = _create_header_row("NEW RECIPES DISCOVERED!", "")
	# Make header gold
	var header_label: Label = header_hbox.get_child(0) as Label
	header_label.add_theme_color_override("font_color", ACCENT_GOLD)
	vbox.add_child(header_hbox)

	# Each new recipe
	for recipe_name: String in new_recipes:
		var recipe_label: Label = Label.new()
		recipe_label.text = "* %s" % recipe_name
		recipe_label.add_theme_font_size_override("font_size", BODY_FONT_SIZE)
		recipe_label.add_theme_color_override("font_color", ACCENT_GOLD)
		vbox.add_child(recipe_label)

	# Progress
	var discovered: int = RecipeBook.get_discovery_count()
	var total: int = RecipeBook.get_total_count()
	var progress_label: Label = Label.new()
	progress_label.text = "%d / %d Recipes Found" % [discovered, total]
	progress_label.add_theme_font_size_override("font_size", 22)
	progress_label.add_theme_color_override("font_color", MUTED_COLOR)
	progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(progress_label)

	# Mark this card for extra pop emphasis
	card.set_meta("_recipe_card", true)

	return card


func _build_streak_card(streak_bonus: float) -> PanelContainer:
	var card: PanelContainer = _create_card_container()
	var vbox: VBoxContainer = _get_card_content(card)

	var header_hbox: HBoxContainer = _create_header_row("Streak Bonus", "+%.0f%%" % (streak_bonus * 100.0))
	vbox.add_child(header_hbox)

	# Mini heat meter (static bar showing final_heat)
	var final_heat: float = _pot_luck_data.get("final_heat", 0.0) as float
	var heat_bar_bg: ColorRect = ColorRect.new()
	heat_bar_bg.custom_minimum_size = Vector2(0, 20)
	heat_bar_bg.color = Color(0.12, 0.12, 0.18)
	vbox.add_child(heat_bar_bg)

	var heat_bar_fill: ColorRect = ColorRect.new()
	heat_bar_fill.custom_minimum_size = Vector2(0, 20)
	# Color based on heat level
	if final_heat < 0.4:
		heat_bar_fill.color = Color(0.3, 0.8, 0.3)
	elif final_heat < 0.7:
		heat_bar_fill.color = Color(0.9, 0.9, 0.2)
	else:
		heat_bar_fill.color = Color(1.0, 0.3, 0.05)
	heat_bar_fill.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	# We'll set the fill width in _animate_entrance after layout
	heat_bar_fill.set_meta("_heat_ratio", final_heat)
	heat_bar_bg.add_child(heat_bar_fill)

	var heat_label: Label = Label.new()
	heat_label.text = "Heat Survived: %d%%" % int(final_heat * 100)
	heat_label.add_theme_font_size_override("font_size", 20)
	heat_label.add_theme_color_override("font_color", MUTED_COLOR)
	heat_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(heat_label)

	return card


func _build_milestones_card(milestones: Array[Dictionary]) -> PanelContainer:
	var card: PanelContainer = _create_card_container()
	var vbox: VBoxContainer = _get_card_content(card)

	var header_hbox: HBoxContainer = _create_header_row("Milestones", "")
	vbox.add_child(header_hbox)

	for milestone: Dictionary in milestones:
		var milestone_hbox: VBoxContainer = VBoxContainer.new()
		milestone_hbox.add_theme_constant_override("separation", 2)

		var name_label: Label = Label.new()
		name_label.text = milestone.get("name", "") as String
		name_label.add_theme_font_size_override("font_size", BODY_FONT_SIZE)
		name_label.add_theme_color_override("font_color", ACCENT_GOLD)
		milestone_hbox.add_child(name_label)

		var desc_label: Label = Label.new()
		desc_label.text = milestone.get("description", "") as String
		desc_label.add_theme_font_size_override("font_size", 20)
		desc_label.add_theme_color_override("font_color", MUTED_COLOR)
		milestone_hbox.add_child(desc_label)

		vbox.add_child(milestone_hbox)

	if _was_boilover:
		_set_card_accent(card, ACCENT_RED)

	return card


# ── Milestone checks ─────────────────────────────────────────────────────

func _check_milestones() -> Array[Dictionary]:
	var milestones: Array[Dictionary] = []

	var total_served: int = SaveManager.get_value("pot_luck.stats.total_dishes_served", 0) as int
	var total_boilovers: int = SaveManager.get_value("pot_luck.stats.total_boilovers", 0) as int
	var total_games: int = total_served + total_boilovers
	var perfect_pots: int = SaveManager.get_value("pot_luck.stats.perfect_pots", 0) as int

	# First serve
	if total_served == 1 and not _was_boilover:
		milestones.append({"name": "First Dish!", "description": "You served your first dish"})

	# First perfect pot
	if perfect_pots == 1 and _pot_luck_data.get("bag_emptied", false) as bool:
		milestones.append({"name": "Perfectionist", "description": "Your first perfect pot"})

	# Games played milestones
	for threshold: int in [10, 25, 50, 100]:
		if total_games == threshold:
			milestones.append({"name": "%d Games!" % threshold, "description": "You've played %d games" % threshold})

	# All recipes discovered
	var discovered: int = RecipeBook.get_discovery_count()
	var total_recipes: int = RecipeBook.get_total_count()
	if discovered >= total_recipes and total_recipes > 0:
		milestones.append({"name": "Master Chef!", "description": "All recipes discovered"})

	return milestones


# ── Card UI Helpers ───────────────────────────────────────────────────────

func _create_card_container() -> PanelContainer:
	var card: PanelContainer = PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	# Use a StyleBoxFlat matching the theme's card style
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = Color(0.11, 0.11, 0.16)
	sb.border_color = Color(0.2, 0.2, 0.28, 0.5)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(12)
	sb.content_margin_left = CARD_MARGIN
	sb.content_margin_right = CARD_MARGIN
	sb.content_margin_top = CARD_MARGIN
	sb.content_margin_bottom = CARD_MARGIN
	card.add_theme_stylebox_override("panel", sb)

	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 0)
	margin.add_theme_constant_override("margin_right", 0)
	margin.add_theme_constant_override("margin_top", 0)
	margin.add_theme_constant_override("margin_bottom", 0)
	card.add_child(margin)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	margin.add_child(vbox)

	return card


func _get_card_content(card: PanelContainer) -> VBoxContainer:
	return card.get_child(0).get_child(0) as VBoxContainer


func _create_header_row(header_text: String, value_text: String) -> HBoxContainer:
	var hbox: HBoxContainer = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)

	var header: Label = Label.new()
	header.text = header_text
	header.add_theme_font_size_override("font_size", HEADER_FONT_SIZE)
	header.add_theme_color_override("font_color", MUTED_COLOR)
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(header)

	if value_text != "":
		var value: Label = Label.new()
		value.text = value_text
		value.add_theme_font_size_override("font_size", VALUE_FONT_SIZE)
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		hbox.add_child(value)

	return hbox


func _set_card_accent(card: PanelContainer, color: Color) -> void:
	var sb: StyleBoxFlat = card.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
	sb.border_color = Color(color.r, color.g, color.b, 0.4)
	sb.set_border_width_all(2)
	card.add_theme_stylebox_override("panel", sb)


# ── Entrance Animations ──────────────────────────────────────────────────

func _animate_entrance(cards: Array[PanelContainer]) -> void:
	# 0.0s: Background + header fade in
	_header_label.modulate.a = 0.0
	var header_tween: Tween = create_tween()
	header_tween.tween_property(_header_label, "modulate:a", 1.0, 0.3)

	# Staggered card pop-ins
	for i: int in range(cards.size()):
		var card: PanelContainer = cards[i]
		var delay: float = 0.2 + CARD_STAGGER_DELAY * i

		# Recipe cards get extra scale overshoot
		if card.has_meta("_recipe_card"):
			card.pivot_offset = card.size / 2.0
			card.scale = Vector2.ZERO
			var t: Tween = create_tween()
			t.tween_interval(delay)
			t.tween_property(card, "scale", Vector2(1.3, 1.3), 0.2) \
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			t.tween_property(card, "scale", Vector2.ONE, 0.15) \
				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		else:
			Juice.pop_in(card, 0.3, delay)

	# New high score card: sparkle particles
	if _is_new_high_score and not _was_boilover and cards.size() > 0:
		var score_card: PanelContainer = cards[0]
		get_tree().create_timer(0.3).timeout.connect(func() -> void:
			_spawn_sparkle_particles(score_card)
		)

	# Buttons pop in after last card
	var button_delay: float = 0.2 + CARD_STAGGER_DELAY * cards.size() + 0.3
	var btn_tween: Tween = create_tween()
	btn_tween.tween_interval(button_delay)
	btn_tween.tween_property(_button_bar, "modulate:a", 1.0, 0.3)

	Juice.pop_in(_play_again_button, 0.3, button_delay)
	Juice.pop_in(_menu_button, 0.3, button_delay + 0.1)


func _spawn_sparkle_particles(target: Control) -> void:
	# Big burst of gold sparkles
	var burst: CPUParticles2D = CPUParticles2D.new()
	burst.emitting = true
	burst.one_shot = true
	burst.amount = 30
	burst.lifetime = 1.2
	burst.explosiveness = 1.0
	burst.direction = Vector2(0, -1)
	burst.spread = 180.0
	burst.initial_velocity_min = 120.0
	burst.initial_velocity_max = 350.0
	burst.gravity = Vector2(0, 80)
	burst.scale_amount_min = 5.0
	burst.scale_amount_max = 12.0
	burst.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	burst.emission_rect_extents = Vector2(target.size.x * 0.3, 10)
	burst.color = ACCENT_GOLD
	burst.position = Vector2(target.size.x / 2.0, target.size.y / 2.0)
	target.add_child(burst)

	# Lingering glitter
	var glitter: CPUParticles2D = CPUParticles2D.new()
	glitter.emitting = true
	glitter.one_shot = false
	glitter.amount = 15
	glitter.lifetime = 1.5
	glitter.explosiveness = 0.0
	glitter.direction = Vector2(0, -1)
	glitter.spread = 120.0
	glitter.initial_velocity_min = 30.0
	glitter.initial_velocity_max = 80.0
	glitter.gravity = Vector2(0, 20)
	glitter.scale_amount_min = 3.0
	glitter.scale_amount_max = 7.0
	glitter.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	glitter.emission_rect_extents = Vector2(target.size.x * 0.4, target.size.y * 0.3)
	glitter.color = Color(1.0, 0.95, 0.6, 0.7)
	glitter.position = Vector2(target.size.x / 2.0, target.size.y / 2.0)
	target.add_child(glitter)

	get_tree().create_timer(3.0).timeout.connect(func() -> void:
		if is_instance_valid(glitter):
			glitter.emitting = false
		get_tree().create_timer(2.0).timeout.connect(func() -> void:
			if is_instance_valid(burst):
				burst.queue_free()
			if is_instance_valid(glitter):
				glitter.queue_free()
		)
	)


# ── Navigation ────────────────────────────────────────────────────────────

func _on_play_again() -> void:
	AnalyticsManager.log_event("button_clicked", {"button": "play_again"})
	if _was_daily:
		GameManager.set_meta("game_mode", "daily")
	else:
		GameManager.set_meta("game_mode", "endless")
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
