## Game scene orchestration for Pot Luck.
## Flick-based flow: draw → drag/flick tile → pot catches it → decide → repeat.
extends Node2D

@onready var _camera: Camera2D = $Camera2D
@onready var _pot_visual := $PotVisual
@onready var _tile_spawn: Marker2D = $TileSpawnPoint
@onready var _combo_container: Node2D = $ComboPopupContainer

# HUD
@onready var _bag_label: Label = %BagCountLabel
@onready var _score_label: Label = %ScoreLabel
@onready var _preview_label: Label = %IngredientPreview
@onready var _flick_prompt: Label = %FlickPrompt
@onready var _stop_button: Button = %StopButton
@onready var _heat_draw: Control = %HeatMeterDraw
@onready var _pot_dots: Control = %PotDots

var _engine: PotLuckEngine = PotLuckEngine.new()
var _current_tile: IngredientTile = null
var _tile_scene: PackedScene = preload("res://game/ingredient_tile.tscn")
var _combo_popup_scene: PackedScene = preload("res://scenes/combo_popup_label.tscn")
var _second_chance_scene: PackedScene = preload("res://scenes/second_chance_popup.tscn")
var _running_score: int = 0
var _heat_ratio: float = 0.0
var _pot_colors: PackedColorArray = PackedColorArray()
var _waiting_for_flick: bool = false


func _ready() -> void:
	GameManager.start_game()
	AnalyticsManager.log_event("level_start", {"level": GameManager.level})
	AnalyticsManager.log_screen("game")

	_engine.setup(GameManager.config)
	_connect_engine()

	_stop_button.pressed.connect(_on_stop_pressed)
	_stop_button.visible = false
	_preview_label.text = ""
	_flick_prompt.text = ""
	_score_label.text = "0"

	# Wire pot visual landing signal
	_pot_visual.ingredient_landed.connect(_on_pot_landed)

	# Custom draw hooks
	_heat_draw.draw.connect(_draw_heat_meter)
	_pot_dots.draw.connect(_draw_pot_dots)

	_start_round()


func _connect_engine() -> void:
	_engine.ingredient_drawn.connect(_on_ingredient_drawn)
	_engine.ingredient_added.connect(_on_ingredient_added)
	_engine.combo_triggered.connect(_on_combo_triggered)
	_engine.heat_changed.connect(_on_heat_changed)
	_engine.boilover.connect(_on_boilover)
	_engine.dish_served.connect(_on_dish_served)
	_engine.bag_emptied.connect(_on_bag_emptied)


# ── Round lifecycle ──────────────────────────────────────────────────────

func _start_round() -> void:
	_engine.reset()
	_engine.fill_bag()
	_running_score = 0
	_heat_ratio = 0.0
	_pot_colors.clear()
	_update_hud()
	_pot_visual.set_heat(0.0)
	_stop_button.visible = false
	_flick_prompt.text = ""
	_preview_label.text = ""

	_heat_draw.queue_redraw()
	_pot_dots.queue_redraw()

	await get_tree().create_timer(0.4).timeout
	_draw_next()


func _draw_next() -> void:
	if _engine.phase == PotLuckEngine.Phase.BOILOVER or _engine.phase == PotLuckEngine.Phase.SERVED:
		return

	var data: IngredientData = _engine.draw()
	if data == null:
		_engine.serve()


# ── Engine signal handlers ───────────────────────────────────────────────

func _on_ingredient_drawn(data: IngredientData) -> void:
	AnalyticsManager.log_event("ingredient_drawn", {"ingredient_id": data.id})
	_update_hud()

	_preview_label.text = "%s  (+%d pts)" % [data.display_name, data.points]
	_flick_prompt.text = "Drag it down into the pot!"
	_stop_button.visible = false

	# Spawn tile
	_current_tile = _tile_scene.instantiate() as IngredientTile
	_current_tile.setup(data)
	add_child(_current_tile)
	_current_tile.reveal(_tile_spawn.position)
	_current_tile.missed.connect(_on_tile_missed)
	_waiting_for_flick = true


func _on_pot_landed(tile: IngredientTile) -> void:
	if tile != _current_tile:
		return
	_waiting_for_flick = false

	_engine.add_to_pot()
	_pot_visual.play_splash()
	AudioManager.play_sfx_path("res://assets/audio/sfx/splash.wav")
	Utils.vibrate(15)

	# Record color dot
	if tile.ingredient_data != null:
		_pot_colors.append(tile.ingredient_data.color)
		_pot_dots.queue_redraw()

	# Clean up tile after squash animation
	var cleanup_timer: SceneTreeTimer = get_tree().create_timer(0.25)
	cleanup_timer.timeout.connect(func() -> void:
		if is_instance_valid(tile):
			tile.queue_free()
	)
	_current_tile = null

	_running_score = _engine.calculate_score()
	_score_label.text = Utils.format_number(_running_score)


func _on_tile_missed(_tile: IngredientTile) -> void:
	_flick_prompt.text = "Drag it down toward the cauldron!"


func _on_ingredient_added(_data: IngredientData) -> void:
	_preview_label.text = ""
	_flick_prompt.text = ""

	if _engine.phase != PotLuckEngine.Phase.DECIDE:
		return

	# Show serve button with score
	_stop_button.text = "Serve Dish!  (%s pts)" % Utils.format_number(_running_score)
	_stop_button.visible = true
	Juice.pop_in(_stop_button, 0.2)

	if _engine.bag.is_empty():
		_flick_prompt.text = "Bag empty — Serve your dish!"
	else:
		_flick_prompt.text = "Tap anywhere to draw next (%d left)" % _engine.bag.size()

	_update_hud()


func _on_combo_triggered(combo: ComboData) -> void:
	AnalyticsManager.log_event("combo_triggered", {
		"combo_name": combo.combo_name,
		"multiplier": combo.multiplier,
	})

	var popup: ComboPopupLabel = _combo_popup_scene.instantiate() as ComboPopupLabel
	popup.position = Vector2(540, 1200)
	_combo_container.add_child(popup)
	popup.setup(combo)
	popup.animate()

	var best: float = SaveManager.get_value("pot_luck.stats.best_combo_multiplier", 1.0) as float
	if combo.multiplier > best:
		SaveManager.set_value("pot_luck.stats.best_combo_multiplier", combo.multiplier)

	var discovered: Array = SaveManager.get_value("pot_luck.recipes_discovered", []) as Array
	if combo.combo_name not in discovered:
		discovered.append(combo.combo_name)
		SaveManager.set_value("pot_luck.recipes_discovered", discovered)

	if combo.is_penalty:
		Juice.flash(_pot_visual, Color(1.0, 0.2, 0.1), 0.3)
		ScreenShake.shake(_camera, 8.0, 0.2)
	else:
		Juice.flash(_pot_visual, Color(1.0, 1.0, 0.5), 0.2)


func _on_heat_changed(new_heat: float, _stage: int) -> void:
	_heat_ratio = clampf(new_heat / GameManager.config.boilover_threshold, 0.0, 1.0)
	_pot_visual.set_heat(_heat_ratio)
	_heat_draw.queue_redraw()


func _on_boilover() -> void:
	AnalyticsManager.log_event("boilover")
	_pot_visual.play_boilover(_camera)
	Utils.vibrate(50)
	_stop_button.visible = false
	_flick_prompt.text = ""
	_preview_label.text = ""

	if is_instance_valid(_current_tile):
		_current_tile.queue_free()
		_current_tile = null

	if not _engine.second_chance_used:
		await get_tree().create_timer(0.6).timeout
		_show_second_chance()
	else:
		await get_tree().create_timer(0.8).timeout
		_end_game(0, true)


func _on_dish_served(final_score: int) -> void:
	_end_game(final_score, false)


func _on_bag_emptied() -> void:
	_preview_label.text = "Clean Pot! x%.1f Bonus!" % GameManager.config.clean_pot_bonus
	Juice.pulse(_score_label, 1.3, 0.3)


# ── Tap-to-draw in DECIDE phase ─────────────────────────────────────────

func _unhandled_input(event: InputEvent) -> void:
	# In DECIDE phase with bag remaining: tap anywhere to draw next
	if _engine.phase == PotLuckEngine.Phase.DECIDE and not _engine.bag.is_empty():
		var tapped: bool = false
		if event is InputEventScreenTouch:
			tapped = (event as InputEventScreenTouch).pressed
		elif event is InputEventMouseButton:
			var mb: InputEventMouseButton = event as InputEventMouseButton
			tapped = mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT
		if tapped:
			_draw_next()
			get_viewport().set_input_as_handled()


# ── UI actions ───────────────────────────────────────────────────────────

func _on_stop_pressed() -> void:
	AnalyticsManager.log_event("stop_decision", {
		"ingredients_count": _engine.pot.size(),
		"heat": _engine.heat,
	})
	_stop_button.visible = false
	_flick_prompt.text = ""
	_engine.serve()


func _show_second_chance() -> void:
	var popup: BasePopup = UIManager.show_popup(_second_chance_scene, {"score": _running_score})
	if popup != null:
		popup.connect("second_chance_accepted", _on_second_chance_accepted)
		popup.connect("second_chance_declined", _on_second_chance_declined)


func _on_second_chance_accepted() -> void:
	_engine.apply_second_chance()
	_heat_ratio = clampf(_engine.heat / GameManager.config.boilover_threshold, 0.0, 1.0)
	_pot_visual.set_heat(_heat_ratio)
	_heat_draw.queue_redraw()

	_stop_button.text = "Serve Dish!  (%s pts)" % Utils.format_number(_running_score)
	_stop_button.visible = true

	if not _engine.bag.is_empty():
		_flick_prompt.text = "Tap anywhere to draw next (%d left)" % _engine.bag.size()
	else:
		_flick_prompt.text = "Bag empty — Serve your dish!"


func _on_second_chance_declined() -> void:
	_end_game(0, true)


# ── End game ─────────────────────────────────────────────────────────────

func _end_game(final_score: int, was_boilover: bool) -> void:
	_stop_button.visible = false
	_flick_prompt.text = ""
	_preview_label.text = ""

	var ingredients_used: int = _engine.pot.size()
	SaveManager.set_value("pot_luck.stats.total_ingredients_used",
		(SaveManager.get_value("pot_luck.stats.total_ingredients_used", 0) as int) + ingredients_used)

	if was_boilover:
		SaveManager.set_value("pot_luck.stats.total_boilovers",
			(SaveManager.get_value("pot_luck.stats.total_boilovers", 0) as int) + 1)
	else:
		SaveManager.set_value("pot_luck.stats.total_dishes_served",
			(SaveManager.get_value("pot_luck.stats.total_dishes_served", 0) as int) + 1)
		if _engine.bag_was_emptied:
			SaveManager.set_value("pot_luck.stats.perfect_pots",
				(SaveManager.get_value("pot_luck.stats.perfect_pots", 0) as int) + 1)

	AnalyticsManager.log_event("dish_served", {
		"final_score": final_score,
		"ingredients_count": ingredients_used,
		"was_boilover": was_boilover,
		"combos_count": _engine.triggered_combos.size(),
		"bag_emptied": _engine.bag_was_emptied,
	})

	GameManager.set_meta("pot_luck_data", {
		"final_score": final_score,
		"was_boilover": was_boilover,
		"ingredients_count": ingredients_used,
		"combos": _engine.triggered_combos.size(),
		"combo_multiplier": _engine.get_combo_multiplier(),
		"streak_bonus": _engine.get_streak_bonus(),
		"bag_emptied": _engine.bag_was_emptied,
	})

	GameManager.add_score(final_score)
	GameManager.end_game()

	await get_tree().create_timer(0.5).timeout
	GameManager.goto_scene("res://scenes/game_over.tscn")


# ── HUD helpers ──────────────────────────────────────────────────────────

func _update_hud() -> void:
	_bag_label.text = "Bag: %d" % _engine.bag.size()


# ── Custom draw: heat meter (right side bar with gradient) ───────────────

func _draw_heat_meter() -> void:
	var rect: Rect2 = _heat_draw.get_rect()
	var w: float = rect.size.x
	var h: float = rect.size.y
	var bar_w: float = 40.0
	var bar_h: float = h - 80.0
	var x: float = (w - bar_w) / 2.0
	var y_top: float = 40.0

	# Background
	_heat_draw.draw_rect(Rect2(x, y_top, bar_w, bar_h), Color(0.12, 0.12, 0.18, 0.9))

	# Fill from bottom
	var fill_h: float = bar_h * _heat_ratio
	if fill_h > 0:
		var fill_y: float = y_top + bar_h - fill_h
		# Color gradient: green → yellow → red
		var col: Color
		if _heat_ratio < 0.4:
			col = Color(0.3, 0.8, 0.3).lerp(Color(0.9, 0.9, 0.2), _heat_ratio / 0.4)
		elif _heat_ratio < 0.7:
			col = Color(0.9, 0.9, 0.2).lerp(Color(0.95, 0.4, 0.1), (_heat_ratio - 0.4) / 0.3)
		else:
			col = Color(0.95, 0.4, 0.1).lerp(Color(1.0, 0.1, 0.05), (_heat_ratio - 0.7) / 0.3)
		_heat_draw.draw_rect(Rect2(x, fill_y, bar_w, fill_h), col)

	# Border
	_heat_draw.draw_rect(Rect2(x, y_top, bar_w, bar_h), Color(0.4, 0.4, 0.5, 0.6), false, 2.0)

	# Heat percentage text
	var pct_text: String = "%d%%" % int(_heat_ratio * 100)
	_heat_draw.draw_string(ThemeDB.fallback_font, Vector2(x, y_top - 8), pct_text,
		HORIZONTAL_ALIGNMENT_LEFT, bar_w, 24, Color(0.8, 0.8, 0.8))


# ── Custom draw: ingredient dots in pot ──────────────────────────────────

func _draw_pot_dots() -> void:
	var rect: Rect2 = _pot_dots.get_rect()
	var dot_size: float = 16.0
	var spacing: float = 22.0
	var count: int = _pot_colors.size()
	if count == 0:
		return

	var total_w: float = count * spacing
	var start_x: float = (rect.size.x - total_w) / 2.0
	var cy: float = rect.size.y / 2.0

	for i: int in range(count):
		var cx: float = start_x + i * spacing + spacing / 2.0
		_pot_dots.draw_circle(Vector2(cx, cy), dot_size / 2.0, _pot_colors[i])
