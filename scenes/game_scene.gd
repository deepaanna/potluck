## Game scene orchestration for Pot Luck.
## Wires PotLuckEngine signals to visuals, HUD, and template autoloads.
extends Node2D

@onready var _camera: Camera2D = $Camera2D
@onready var _pot_visual: Node2D = $PotVisual
@onready var _tile_spawn: Marker2D = $TileSpawnPoint
@onready var _pot_target: Marker2D = $PotTargetPoint
@onready var _combo_container: Node2D = $ComboPopupContainer

# HUD
@onready var _bag_count_label: Label = %BagCountLabel
@onready var _score_label: Label = %ScoreLabel
@onready var _ingredient_preview: Label = %IngredientPreview
@onready var _stop_button: Button = %StopButton
@onready var _heat_meter: Control = %HeatMeter
@onready var _draw_prompt: Label = %DrawPrompt

var _engine: PotLuckEngine = PotLuckEngine.new()
var _current_tile: Node2D = null
var _tile_scene: PackedScene = preload("res://scenes/ingredient_tile.tscn")
var _combo_popup_scene: PackedScene = preload("res://scenes/combo_popup_label.tscn")
var _second_chance_scene: PackedScene = preload("res://scenes/second_chance_popup.tscn")
var _running_score: int = 0


func _ready() -> void:
	GameManager.start_game()
	AnalyticsManager.log_event("level_start", {"level": GameManager.level})
	AnalyticsManager.log_screen("game")

	_engine.setup(GameManager.config)
	_connect_engine_signals()
	_setup_hud()
	_start_round()


func _connect_engine_signals() -> void:
	_engine.ingredient_drawn.connect(_on_ingredient_drawn)
	_engine.ingredient_added.connect(_on_ingredient_added)
	_engine.combo_triggered.connect(_on_combo_triggered)
	_engine.heat_changed.connect(_on_heat_changed)
	_engine.boilover.connect(_on_boilover)
	_engine.dish_served.connect(_on_dish_served)
	_engine.bag_emptied.connect(_on_bag_emptied)


func _setup_hud() -> void:
	_stop_button.pressed.connect(_on_stop_pressed)
	_stop_button.visible = false
	_ingredient_preview.text = ""
	_score_label.text = "0"
	_draw_prompt.visible = false


func _start_round() -> void:
	_engine.reset()
	_engine.fill_bag()
	_update_bag_count()
	_running_score = 0
	_score_label.text = "0"
	_heat_meter.update_heat(0.0, 0)
	_pot_visual.set_heat_stage(0)
	_stop_button.visible = false
	_draw_prompt.visible = true
	_draw_prompt.text = "Tap to Draw!"
	_ingredient_preview.text = ""

	# Auto-draw first ingredient
	await get_tree().create_timer(0.4).timeout
	_draw_next()


func _draw_next() -> void:
	if _engine.phase == PotLuckEngine.Phase.BOILOVER or _engine.phase == PotLuckEngine.Phase.SERVED:
		return

	var data: IngredientData = _engine.draw()
	if data == null:
		# Bag is empty, auto-serve
		_on_stop_pressed()


func _on_ingredient_drawn(data: IngredientData) -> void:
	AnalyticsManager.log_event("ingredient_drawn", {"ingredient_id": data.id})
	_update_bag_count()
	_draw_prompt.visible = false
	_ingredient_preview.text = "%s (+%d)" % [data.display_name, data.points]

	# Spawn tile at spawn point
	_current_tile = _tile_scene.instantiate() as Node2D
	_current_tile.setup(data)
	_current_tile.position = _tile_spawn.position
	add_child(_current_tile)
	_current_tile.appear()

	_current_tile.flicked.connect(_on_tile_flicked)
	_current_tile.arrived_at_pot.connect(_on_tile_arrived)


func _on_tile_flicked(_tile: Node2D) -> void:
	if _engine.phase != PotLuckEngine.Phase.DRAW:
		return
	_engine.begin_flick()
	_current_tile.fly_to_pot(_pot_target.position)


func _on_tile_arrived(_tile: Node2D) -> void:
	_engine.add_to_pot()
	_pot_visual.play_splash()
	Utils.vibrate(15)

	# Clean up tile
	if is_instance_valid(_tile):
		_tile.queue_free()
	_current_tile = null

	# Update running score display
	_running_score = _engine.calculate_score()
	_score_label.text = Utils.format_number(_running_score)


func _on_ingredient_added(_data: IngredientData) -> void:
	# Show stop button after first ingredient
	if _engine.pot.size() >= 1:
		_stop_button.visible = true

	# Auto-draw next if in DECIDE phase
	if _engine.phase == PotLuckEngine.Phase.DECIDE:
		_draw_prompt.visible = true
		_draw_prompt.text = "Tap to Draw!"
		# Brief pause before next draw
		await get_tree().create_timer(0.3).timeout
		if _engine.phase == PotLuckEngine.Phase.DECIDE:
			_draw_next()


func _on_combo_triggered(combo: ComboData) -> void:
	AnalyticsManager.log_event("combo_triggered", {
		"combo_name": combo.combo_name,
		"multiplier": combo.multiplier,
	})

	# Spawn combo popup above pot
	var popup: Node2D = _combo_popup_scene.instantiate() as Node2D
	popup.position = _pot_target.position + Vector2(0, -150)
	_combo_container.add_child(popup)
	popup.setup(combo)
	popup.animate()

	# Track best multiplier
	var best: float = SaveManager.get_value("pot_luck.stats.best_combo_multiplier", 1.0) as float
	if combo.multiplier > best:
		SaveManager.set_value("pot_luck.stats.best_combo_multiplier", combo.multiplier)

	# Track discovered recipes
	var discovered: Array = SaveManager.get_value("pot_luck.recipes_discovered", []) as Array
	if combo.combo_name not in discovered:
		discovered.append(combo.combo_name)
		SaveManager.set_value("pot_luck.recipes_discovered", discovered)

	if combo.is_penalty:
		Juice.flash(_pot_visual, Color(1.0, 0.2, 0.1), 0.3)
		ScreenShake.shake(_camera, 8.0, 0.2)
	else:
		Juice.flash(_pot_visual, Color(1.0, 1.0, 0.5), 0.2)


func _on_heat_changed(new_heat: float, stage: int) -> void:
	var ratio: float = new_heat / GameManager.config.boilover_threshold
	_heat_meter.update_heat(ratio, stage)
	_pot_visual.set_heat_stage(stage)


func _on_boilover() -> void:
	AnalyticsManager.log_event("boilover")
	_pot_visual.play_boilover()
	ScreenShake.shake(_camera, 20.0, 0.5)
	Utils.vibrate(50)
	_stop_button.visible = false
	_draw_prompt.visible = false
	_ingredient_preview.text = ""

	# Clean up current tile if any
	if is_instance_valid(_current_tile):
		_current_tile.queue_free()
		_current_tile = null

	# Show second chance popup if not already used
	if not _engine.second_chance_used:
		await get_tree().create_timer(0.6).timeout
		_show_second_chance()
	else:
		await get_tree().create_timer(0.8).timeout
		_end_game(0, true)


func _show_second_chance() -> void:
	var popup: BasePopup = UIManager.show_popup(_second_chance_scene)
	if popup != null:
		popup.second_chance_accepted.connect(_on_second_chance_accepted)
		popup.second_chance_declined.connect(_on_second_chance_declined)


func _on_second_chance_accepted() -> void:
	_engine.apply_second_chance()
	_stop_button.visible = true
	_draw_prompt.visible = true
	_draw_prompt.text = "Tap to Draw!"

	# Continue drawing
	await get_tree().create_timer(0.3).timeout
	if _engine.phase == PotLuckEngine.Phase.DECIDE:
		_draw_next()


func _on_second_chance_declined() -> void:
	_end_game(0, true)


func _on_stop_pressed() -> void:
	AnalyticsManager.log_event("stop_decision", {
		"ingredients_count": _engine.pot.size(),
		"heat": _engine.heat,
	})
	var final_score: int = _engine.serve()


func _on_dish_served(final_score: int) -> void:
	_end_game(final_score, false)


func _on_bag_emptied() -> void:
	# Visual feedback for clean pot bonus
	_draw_prompt.visible = true
	_draw_prompt.text = "Clean Pot! x%.1f Bonus!" % GameManager.config.clean_pot_bonus
	Juice.pulse(_score_label, 1.3, 0.3)


func _end_game(final_score: int, was_boilover: bool) -> void:
	_stop_button.visible = false
	_draw_prompt.visible = false

	# Update stats
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

	# Store game data for game over screen
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


func _update_bag_count() -> void:
	_bag_count_label.text = "Bag: %d" % _engine.bag.size()
