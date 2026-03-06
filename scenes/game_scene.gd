## Game scene orchestration for Pot Luck.
## Flick-based flow: draw → drag/flick tile → pot catches it → decide → repeat.
## Includes visual juice, audio hooks, heat vignette, tutorial, and trail effects.
extends Node2D

# SFX path constants
const SFX_DRAW: String = "res://assets/audio/sfx/draw.wav"
const SFX_FLICK: String = "res://assets/audio/sfx/flick.wav"
const SFX_SPLASH: String = "res://assets/audio/sfx/splash.wav"
const SFX_COMBO: String = "res://assets/audio/sfx/combo.wav"
const SFX_COMBO_PENALTY: String = "res://assets/audio/sfx/combo_penalty.wav"
const SFX_BOILOVER: String = "res://assets/audio/sfx/boilover.wav"
const SFX_SERVE: String = "res://assets/audio/sfx/serve.wav"
const SFX_DING: String = "res://assets/audio/sfx/ding.wav"
const SFX_SECOND_CHANCE: String = "res://assets/audio/sfx/second_chance.wav"
const SFX_SIZZLE_LOOP: String = "res://assets/audio/sfx/sizzle_loop.wav"
const SFX_SIZZLE: String = "res://assets/audio/sfx/sizzle.wav"
const BGM_GAME: String = "res://assets/audio/music/game_bgm.wav"

@onready var _camera: Camera2D = $Camera2D
@onready var _pot_visual := $PotVisual
@onready var _tile_spawn: Marker2D = $TileSpawnPoint
@onready var _combo_container: Node2D = $ComboPopupContainer
@onready var _vignette_rect: ColorRect = $VignetteRect
@onready var _sizzle_player: AudioStreamPlayer = $SizzlePlayer
@onready var _flick_trail: Line2D = $FlickTrail

# HUD
@onready var _bag_icon: TextureRect = %BagIcon
@onready var _bag_label: Label = %BagCountLabel
@onready var _score_label: Label = %ScoreLabel
@onready var _preview_panel: PanelContainer = %PreviewPanel
@onready var _preview_label: Label = %IngredientPreview
@onready var _flick_prompt: Label = %FlickPrompt
@onready var _stop_button: Button = %StopButton
@onready var _heat_draw: Control = %HeatMeterDraw
@onready var _pot_dots: Control = %PotDots
@onready var _tutorial_label: Label = %TutorialLabel
@onready var _mode_badge: Label = %ModeBadge

var _engine: PotLuckEngine = PotLuckEngine.new()
var _current_tile: IngredientTile = null
var _tile_scene: PackedScene = preload("res://game/ingredient_tile.tscn")
var _combo_popup_scene: PackedScene = preload("res://scenes/combo_popup_label.tscn")
var _second_chance_scene: PackedScene = preload("res://scenes/second_chance_popup.tscn")
var _high_score_scene: PackedScene = preload("res://scenes/high_score_popup.tscn")
var _running_score: int = 0
var _heat_ratio: float = 0.0
var _pot_colors: PackedColorArray = PackedColorArray()
var _waiting_for_flick: bool = false

# Polish state
var _tension_timer: float = 0.0
var _score_countup_tween: Tween = null
var _displayed_score: float = 0.0
var _is_tutorial: bool = false
var _tutorial_step: int = 0
var _original_bag_size: int = 12
var _show_heat_debug: bool = false

# Enriched metadata tracking
var _new_recipes_this_round: Array[String] = []
var _previous_high_score: int = 0

# Game mode
var _game_mode: String = "endless"  # "endless" or "daily"
var _daily_bag: Array[IngredientData] = []

# Ability system
var _ability_manager: AbilityManager = AbilityManager.new()
var _ability_buttons: Dictionary = {}  # AbilityManager.AbilityType -> Button
var _ability_container: HBoxContainer = null
var _peek_overlay: PanelContainer = null
var _abilities_used_this_round: int = 0


func _ready() -> void:
	GameManager.start_game()
	AnalyticsManager.log_event("level_start", {"level": GameManager.level})
	AnalyticsManager.log_screen("game")

	# Detect game mode
	if GameManager.has_meta("game_mode"):
		_game_mode = GameManager.get_meta("game_mode") as String
		GameManager.remove_meta("game_mode")

	# Load bag icon if available
	var bag_tex: Texture2D = load("res://assets/sprites/bag.png") as Texture2D
	if bag_tex:
		_bag_icon.texture = bag_tex
		_bag_icon.visible = true

	# Show mode badge for daily challenge
	if _game_mode == "daily":
		_mode_badge.text = "DAILY"
		_mode_badge.visible = true
		var badge_sb := StyleBoxFlat.new()
		badge_sb.bg_color = Color(1.0, 0.85, 0.2, 0.15)
		badge_sb.set_corner_radius_all(6)
		badge_sb.content_margin_left = 6
		badge_sb.content_margin_right = 6
		_mode_badge.add_theme_stylebox_override("normal", badge_sb)
	else:
		_mode_badge.visible = false

	# Preview panel style
	var preview_sb := StyleBoxFlat.new()
	preview_sb.bg_color = Color(0.08, 0.08, 0.14, 0.7)
	preview_sb.set_corner_radius_all(10)
	preview_sb.content_margin_left = 12
	preview_sb.content_margin_right = 12
	preview_sb.content_margin_top = 6
	preview_sb.content_margin_bottom = 6
	_preview_panel.add_theme_stylebox_override("panel", preview_sb)

	_engine.setup(GameManager.config)
	_connect_engine()

	_stop_button.pressed.connect(_on_stop_pressed)
	_stop_button.visible = false  # Hidden until first ingredient added
	_stop_button.disabled = true
	_stop_button.modulate.a = 0.3
	_stop_button.text = "Keep Cooking..."
	_preview_label.text = ""
	_flick_prompt.text = ""
	_score_label.text = "0"

	# Wire pot visual landing signal
	_pot_visual.ingredient_landed.connect(_on_pot_landed)

	# Custom draw hooks
	_heat_draw.draw.connect(_draw_heat_meter)
	_pot_dots.draw.connect(_draw_pot_dots)

	# Init vignette to zero heat
	if _vignette_rect.material is ShaderMaterial:
		(_vignette_rect.material as ShaderMaterial).set_shader_parameter("heat_intensity", 0.0)

	# Load sizzle stream
	var sizzle_stream: AudioStream = load(SFX_SIZZLE_LOOP) as AudioStream
	if sizzle_stream != null:
		_sizzle_player.stream = sizzle_stream

	# Clear trail
	_flick_trail.clear_points()

	# Tutorial label
	_tutorial_label.text = ""
	_tutorial_label.modulate.a = 0.0

	# Tutorial check: first-time player
	var total_games: int = SaveManager.get_value("total_games", 0) as int
	var tutorial_completed: bool = SaveManager.get_value("pot_luck.tutorial_completed", false) as bool
	if total_games == 0 and not tutorial_completed:
		_is_tutorial = true
		_tutorial_step = 0
		_original_bag_size = GameManager.config.bag_size
		GameManager.config.bag_size = 3

	# Capture high score before this round modifies it
	_previous_high_score = SaveManager.get_value("high_score", 0) as int
	_new_recipes_this_round.clear()
	_abilities_used_this_round = 0

	# Set up ability manager
	_ability_manager.setup(GameManager.chef_level)
	_create_ability_ui()

	_start_round()


func _connect_engine() -> void:
	_engine.ingredient_drawn.connect(_on_ingredient_drawn)
	_engine.ingredient_added.connect(_on_ingredient_added)
	_engine.combo_triggered.connect(_on_combo_triggered)
	_engine.heat_changed.connect(_on_heat_changed)
	_engine.boilover.connect(_on_boilover)
	_engine.dish_served.connect(_on_dish_served)
	_engine.bag_emptied.connect(_on_bag_emptied)


# ── Process loop ────────────────────────────────────────────────────────

func _process(delta: float) -> void:
	# Tension shake at high heat
	if _heat_ratio > 0.85:
		_tension_timer += delta
		if _tension_timer >= 2.0:
			_tension_timer = 0.0
			ScreenShake.shake(_camera, 3.0, 0.1)

	# Sizzle loop: pitch and volume scale with heat
	if _sizzle_player.stream != null and _heat_ratio > 0.0:
		if not _sizzle_player.playing:
			_sizzle_player.play()
		_sizzle_player.pitch_scale = lerpf(0.8, 1.4, _heat_ratio)
		_sizzle_player.volume_db = lerpf(-40.0, -6.0, _heat_ratio)
	elif _sizzle_player.playing and _heat_ratio <= 0.0:
		_sizzle_player.stop()

	# Flick trail: record tile position during FLICKED state
	if _current_tile != null and is_instance_valid(_current_tile) and _current_tile.state == IngredientTile.State.FLICKED:
		_flick_trail.add_point(_current_tile.global_position)
		if _flick_trail.get_point_count() > 20:
			_flick_trail.remove_point(0)
	elif _flick_trail.get_point_count() > 0:
		# Fade out trail by removing points gradually
		_flick_trail.remove_point(0)

	# Heat meter redraw at > 0.6 for fill pulse and glow
	if _heat_ratio > 0.6:
		_heat_draw.queue_redraw()


# ── Round lifecycle ──────────────────────────────────────────────────────

func _start_round() -> void:
	_engine.reset()
	GameManager.reset_run()

	# Apply cuisine theme
	UIManager.swap_cuisine_theme(UIManager.get_active_cuisine_name())
	var ct: CuisineTheme = UIManager.get_cuisine_theme()
	if ct:
		_pot_visual.set_cuisine_tint(ct.pot_tint)

	# Daily mode: use deterministic bag; normal mode: balanced bag
	if _game_mode == "daily":
		_daily_bag = DailyChallenge.get_daily_bag()
		_engine.bag = _daily_bag.duplicate()
	else:
		var unlocked: Array = SaveManager.get_value("pot_luck.unlocked_cuisines", ["basic"]) as Array
		_engine.fill_bag_balanced(GameManager.chef_level, unlocked)

	_running_score = 0
	_heat_ratio = 0.0
	_pot_colors.clear()
	_update_hud()
	_pot_visual.set_heat(0.0)
	_stop_button.visible = false
	_stop_button.disabled = true
	_stop_button.modulate.a = 0.3
	_stop_button.text = "Keep Cooking..."
	_stop_button.theme_type_variation = &""
	_flick_prompt.text = ""
	_preview_label.text = "Daily Challenge" if _game_mode == "daily" else ""
	_preview_panel.visible = _game_mode == "daily"

	# Reset polish state
	_tension_timer = 0.0
	_flick_trail.clear_points()
	if _vignette_rect.material is ShaderMaterial:
		(_vignette_rect.material as ShaderMaterial).set_shader_parameter("heat_intensity", 0.0)
	if _sizzle_player.playing:
		_sizzle_player.stop()
	_tutorial_label.text = ""
	_tutorial_label.modulate.a = 0.0

	_heat_draw.queue_redraw()
	_pot_dots.queue_redraw()

	# Start game BGM with crossfade from menu music
	AudioManager.play_music_path(BGM_GAME, -6.0, true)

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
	_preview_panel.visible = true
	_flick_prompt.text = "Drag it down into the pot!"
	# Disable serve button during draw/flick phase
	_stop_button.disabled = true
	_stop_button.modulate.a = 0.3
	_stop_button.text = "Keep Cooking..."
	_stop_button.theme_type_variation = &""

	AudioManager.play_sfx_path(SFX_DRAW)
	_update_ability_buttons()

	# Reset trail for new tile
	_flick_trail.clear_points()

	# Spawn tile
	_current_tile = _tile_scene.instantiate() as IngredientTile
	_current_tile.setup(data)
	add_child(_current_tile)
	_current_tile.reveal(_tile_spawn.position)
	_current_tile.missed.connect(_on_tile_missed)
	_current_tile.flicked.connect(_on_tile_flicked)
	_waiting_for_flick = true

	# Tutorial hint step 1
	if _is_tutorial and _tutorial_step == 0:
		_show_tutorial_hint("Drag the ingredient down\ninto the pot!")
		_tutorial_step = 1

	# Onboarding popup: flick tutorial
	if TutorialManager.try_trigger("flick"):
		await TutorialManager.step_dismissed


func _on_pot_landed(tile: IngredientTile) -> void:
	if tile != _current_tile:
		return
	_waiting_for_flick = false

	_engine.add_to_pot()
	if tile.ingredient_data != null:
		GameManager.add_ingredient(tile.ingredient_data)
	_pot_visual.play_splash()
	AudioManager.play_sfx_path(SFX_SPLASH)
	AudioManager.play_sfx_path_heated(SFX_SIZZLE)
	Utils.vibrate(15)

	# Splash particles
	if tile.ingredient_data != null:
		_spawn_splash_particles(tile.ingredient_data.color)

	# Record color dot
	if tile.ingredient_data != null:
		_pot_colors.append(tile.ingredient_data.color)
		_pot_dots.queue_redraw()

	# Score pulse
	Juice.pulse(_score_label, 1.15, 0.2)

	# Floating "+X" score popup
	if tile.ingredient_data != null:
		_spawn_score_popup(tile.ingredient_data.points, tile.ingredient_data.color)

	# Clean up tile after shrink animation
	var cleanup_timer: SceneTreeTimer = get_tree().create_timer(0.25)
	cleanup_timer.timeout.connect(func() -> void:
		if is_instance_valid(tile):
			tile.queue_free()
	)
	_current_tile = null

	_running_score = _engine.calculate_score()
	_score_label.text = Utils.format_number(_running_score)

	# Tutorial hint step 2
	if _is_tutorial and _tutorial_step == 1:
		_show_tutorial_hint("Nice! Watch the heat meter\non the right.")
		_tutorial_step = 2


func _on_tile_missed(_tile: IngredientTile) -> void:
	_flick_prompt.text = "Drag it down toward the cauldron!"


func _on_ingredient_added(_data: IngredientData) -> void:
	_preview_label.text = ""
	_preview_panel.visible = false
	_flick_prompt.text = ""

	# Onboarding popup: heat warning after first ingredient lands (before DECIDE guard)
	if _engine.pot.size() == 1:
		if TutorialManager.try_trigger("heat"):
			await TutorialManager.step_dismissed

	if _engine.phase != PotLuckEngine.Phase.DECIDE:
		return

	# Enable serve button in DECIDE phase
	_stop_button.visible = true
	_stop_button.disabled = false
	_stop_button.modulate.a = 1.0
	_stop_button.text = "Serve Dish!  (%s pts)" % Utils.format_number(_running_score)
	_stop_button.theme_type_variation = &"PrimaryButton"
	Juice.pop_in(_stop_button, 0.2)

	if _engine.bag.is_empty():
		_flick_prompt.text = "Bag empty — Serve your dish!"
		# Re-show clean pot bonus if bag was emptied (signal fires before ingredient_added)
		if _engine.bag_was_emptied:
			_preview_label.text = "Clean Pot! x%.1f Bonus!" % GameManager.config.clean_pot_bonus
			_preview_panel.visible = true
	else:
		_flick_prompt.text = "Tap anywhere to draw next (%d left)" % _engine.bag.size()

	_update_hud()
	_update_ability_buttons()

	# Tutorial hint step 3
	if _is_tutorial and _tutorial_step == 2:
		_show_tutorial_hint("Serve now for safe points,\nor keep adding for more!")
		_tutorial_step = 3

	# Onboarding popup: serve lesson when DECIDE phase entered with 2+ ingredients
	if _engine.pot.size() >= 2:
		if TutorialManager.try_trigger("serve"):
			await TutorialManager.step_dismissed


func _on_combo_triggered(combo: ComboData) -> void:
	AnalyticsManager.log_event("combo_triggered", {
		"combo_name": combo.combo_name,
		"multiplier": combo.multiplier,
	})

	var popup: ComboPopupLabel = _combo_popup_scene.instantiate() as ComboPopupLabel
	popup.position = Vector2(540, 1050)
	_combo_container.add_child(popup)
	popup.setup(combo)
	popup.animate()

	var best: float = SaveManager.get_value("pot_luck.stats.best_combo_multiplier", 1.0) as float
	if combo.multiplier > best:
		SaveManager.set_value("pot_luck.stats.best_combo_multiplier", combo.multiplier)

	GameManager.combo_multiplier *= combo.multiplier

	# Recipe discovery via RecipeBook
	var is_new: bool = RecipeBook.discover_recipe(combo.combo_name)
	if is_new:
		_new_recipes_this_round.append(combo.combo_name)
		AnalyticsManager.log_event("recipe_discovered", {"combo_name": combo.combo_name})
		_show_new_recipe_popup(combo)

	if combo.is_penalty:
		AudioManager.play_sfx_path(SFX_COMBO_PENALTY, 0.0, randf_range(0.9, 1.1))
		Juice.flash(_pot_visual, Color(1.0, 0.2, 0.1), 0.3)
		ScreenShake.shake(_camera, 8.0, 0.2)
	else:
		AudioManager.play_sfx_path(SFX_COMBO, 0.0, randf_range(0.9, 1.1))
		AudioManager.play_sfx_path(SFX_DING, -3.0, randf_range(0.95, 1.05))
		Juice.flash(_pot_visual, Color(1.0, 1.0, 0.5), 0.2)


func _on_heat_changed(new_heat: float, _stage: int) -> void:
	var prev_heat: float = _heat_ratio
	_heat_ratio = clampf(new_heat / GameManager.config.boilover_threshold, 0.0, 1.0)
	_pot_visual.set_heat(_heat_ratio)
	_heat_draw.queue_redraw()

	# Flash heat meter on increase to draw attention
	if _heat_ratio > prev_heat:
		Juice.flash(_heat_draw, Color.WHITE, 0.15)

	# Update vignette shader
	if _vignette_rect.material is ShaderMaterial:
		(_vignette_rect.material as ShaderMaterial).set_shader_parameter("heat_intensity", _heat_ratio)

	# Reset tension timer so shake re-triggers from current moment
	_tension_timer = 0.0


func _on_boilover() -> void:
	AnalyticsManager.log_event("boilover")
	GameManager.boil_over()
	_pot_visual.play_boilover(_camera)
	Utils.vibrate(200)
	AudioManager.play_sfx_path(SFX_BOILOVER)
	_stop_button.visible = false  # Fully hide on boilover (round over)
	_flick_prompt.text = ""
	_preview_label.text = ""
	_preview_panel.visible = false

	# Max vignette on boilover
	if _vignette_rect.material is ShaderMaterial:
		(_vignette_rect.material as ShaderMaterial).set_shader_parameter("heat_intensity", 1.0)

	# Stop sizzle
	if _sizzle_player.playing:
		_sizzle_player.stop()

	if is_instance_valid(_current_tile):
		_current_tile.queue_free()
		_current_tile = null

	if not _engine.second_chance_used:
		# Onboarding popup: revive tutorial before second-chance popup
		if TutorialManager.try_trigger("revive"):
			await TutorialManager.step_dismissed
		await get_tree().create_timer(0.6).timeout
		AudioManager.play_sfx_path(SFX_SECOND_CHANCE)
		_show_second_chance()
	else:
		await get_tree().create_timer(0.8).timeout
		_end_game(0, true)


func _on_dish_served(final_score: int) -> void:
	GameManager.serve_dish(final_score)
	AudioManager.play_sfx_path(SFX_SERVE)

	# Stop sizzle
	if _sizzle_player.playing:
		_sizzle_player.stop()

	# Score count-up tween (start from 60% for snappy feel)
	var start_value: float = float(final_score) * 0.6
	_displayed_score = start_value
	_score_label.text = Utils.format_number(int(start_value))

	if _score_countup_tween and _score_countup_tween.is_valid():
		_score_countup_tween.kill()

	_score_countup_tween = create_tween()
	_score_countup_tween.tween_method(_update_score_display, start_value, float(final_score), 0.5) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	_score_countup_tween.tween_callback(func() -> void:
		# Green flash + ding at completion
		Juice.flash(_score_label, Color(0.2, 1.0, 0.3), 0.3)
		AudioManager.play_sfx_path(SFX_DING)
	)

	await _score_countup_tween.finished

	_end_game(final_score, false)


func _on_bag_emptied() -> void:
	_preview_label.text = "Clean Pot! x%.1f Bonus!" % GameManager.config.clean_pot_bonus
	_preview_panel.visible = true
	Juice.pulse(_score_label, 1.3, 0.3)


# ── Tile flicked handler ────────────────────────────────────────────────

func _on_tile_flicked(_tile: IngredientTile) -> void:
	AudioManager.play_sfx_path(SFX_FLICK, 0.0, randf_range(0.9, 1.1))
	AudioManager.play_sfx_path("res://assets/audio/sfx/whoosh.wav", -3.0, randf_range(0.9, 1.1))
	Utils.vibrate(50)


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
	_stop_button.disabled = true
	_stop_button.modulate.a = 0.3
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
	_stop_button.disabled = false
	_stop_button.modulate.a = 1.0

	if not _engine.bag.is_empty():
		_flick_prompt.text = "Tap anywhere to draw next (%d left)" % _engine.bag.size()
	else:
		_flick_prompt.text = "Bag empty — Serve your dish!"


func _on_second_chance_declined() -> void:
	_end_game(0, true)


# ── End game ─────────────────────────────────────────────────────────────

func _end_game(final_score: int, was_boilover: bool) -> void:
	TutorialManager.try_complete()

	# Restore bag_size if tutorial (covers both serve and boilover paths)
	if _is_tutorial:
		GameManager.config.bag_size = _original_bag_size
		_is_tutorial = false
		SaveManager.set_value("pot_luck.tutorial_completed", true)

	_stop_button.visible = false  # Fully hide when game ends
	_flick_prompt.text = ""
	_preview_label.text = ""
	_preview_panel.visible = false

	# Fade out game BGM
	AudioManager.stop_music(true)

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
		"mode": _game_mode,
	})

	# Daily challenge: submit score
	if _game_mode == "daily" and not was_boilover:
		DailyChallenge.submit_score(final_score)
		AnalyticsManager.log_event("daily_challenge_completed", {
			"score": final_score,
			"seed": DailyChallenge.get_daily_seed(),
		})

	# Build enriched combo data for rewards screen
	var triggered_combos_data: Array[Dictionary] = []
	for combo: ComboData in _engine.triggered_combos:
		triggered_combos_data.append({
			"combo_name": combo.combo_name,
			"multiplier": combo.multiplier,
			"is_penalty": combo.is_penalty,
			"ingredient_a": combo.ingredient_a,
			"ingredient_b": combo.ingredient_b,
		})

	# Build enriched ingredient data
	var ingredients_data: Array[Dictionary] = []
	for ingredient: IngredientData in _engine.pot:
		ingredients_data.append({
			"id": ingredient.id,
			"display_name": ingredient.display_name,
			"points": ingredient.points,
			"color": ingredient.color,
		})

	# Award XP
	var round_xp_data: Dictionary = {
		"was_boilover": was_boilover,
		"final_score": final_score,
		"combos_count": _engine.triggered_combos.size(),
		"bag_emptied": _engine.bag_was_emptied,
		"new_recipes_count": _new_recipes_this_round.size(),
	}
	var xp_result: Dictionary = GameManager.award_xp(round_xp_data)

	# Track abilities used
	SaveManager.set_value("pot_luck.stats.total_abilities_used",
		(SaveManager.get_value("pot_luck.stats.total_abilities_used", 0) as int) + _abilities_used_this_round)

	GameManager.set_meta("pot_luck_data", {
		"final_score": final_score,
		"was_boilover": was_boilover,
		"ingredients_count": ingredients_used,
		"combos": _engine.triggered_combos.size(),
		"combo_multiplier": _engine.get_combo_multiplier(),
		"streak_bonus": _engine.get_streak_bonus(),
		"bag_emptied": _engine.bag_was_emptied,
		"mode": _game_mode,
		"triggered_combos": triggered_combos_data,
		"ingredients": ingredients_data,
		"final_heat": clampf(_engine.heat / GameManager.config.boilover_threshold, 0.0, 1.0),
		"second_chance_used": _engine.second_chance_used,
		"new_recipes": _new_recipes_this_round.duplicate(),
		"previous_high_score": _previous_high_score,
		"pot_colors": _pot_colors,
		"xp_earned": xp_result.get("xp_earned", 0),
		"leveled_up": xp_result.get("leveled_up", false),
		"old_level": xp_result.get("old_level", 1),
		"new_level": xp_result.get("new_level", 1),
		"current_xp": xp_result.get("current_xp", 0),
		"xp_for_next": xp_result.get("xp_for_next", 25),
		"unlocks": xp_result.get("unlocks", []),
	})

	GameManager.add_score(final_score)
	GameManager.end_game()

	# Show high score popup if new personal best
	if final_score > 0 and final_score > _previous_high_score:
		var hs_popup: BasePopup = UIManager.show_popup(_high_score_scene, {"score": final_score})
		await hs_popup.dismissed

	await get_tree().create_timer(0.5).timeout
	GameManager.goto_scene("res://scenes/game_over.tscn")


# ── Polish helpers ───────────────────────────────────────────────────────

func _spawn_score_popup(points: int, color: Color) -> void:
	var popup_label: Label = Label.new()
	popup_label.text = "+%d" % points
	popup_label.add_theme_font_size_override("font_size", 36)
	popup_label.add_theme_color_override("font_color", color.lightened(0.3))
	popup_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	popup_label.position = _pot_visual.position + Vector2(-50, -80)
	popup_label.size = Vector2(100, 50)
	popup_label.z_index = 20
	add_child(popup_label)

	# Scale pop + float up + fade out
	popup_label.scale = Vector2(1.4, 1.4)
	popup_label.pivot_offset = Vector2(50, 25)
	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(popup_label, "scale", Vector2.ONE, 0.15) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(popup_label, "position:y", popup_label.position.y - 80.0, 0.6) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(popup_label, "modulate:a", 0.0, 0.3) \
		.set_delay(0.3)
	tween.chain().tween_callback(popup_label.queue_free)


func _spawn_splash_particles(color: Color) -> void:
	var particles: CPUParticles2D = CPUParticles2D.new()
	particles.position = _pot_visual.position
	particles.emitting = true
	particles.one_shot = true
	particles.amount = 12
	particles.lifetime = 0.6
	particles.explosiveness = 1.0
	particles.direction = Vector2(0, -1)
	particles.spread = 45.0
	particles.initial_velocity_min = 150.0
	particles.initial_velocity_max = 300.0
	particles.gravity = Vector2(0, 400)
	particles.scale_amount_min = 3.0
	particles.scale_amount_max = 6.0
	particles.color = color
	add_child(particles)

	# Self-cleanup after 1 second
	get_tree().create_timer(1.0).timeout.connect(func() -> void:
		if is_instance_valid(particles):
			particles.queue_free()
	)


func _update_score_display(value: float) -> void:
	_displayed_score = value
	_score_label.text = Utils.format_number(int(value))


func _show_new_recipe_popup(combo: ComboData) -> void:
	# Show "NEW RECIPE!" floating text above the combo popup
	var new_label: Label = Label.new()
	new_label.text = "NEW RECIPE!"
	new_label.add_theme_font_size_override("font_size", 44)
	new_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.5))
	new_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	new_label.position = Vector2(340, 950)
	new_label.size = Vector2(400, 60)
	add_child(new_label)

	new_label.scale = Vector2.ZERO
	new_label.modulate.a = 1.0
	var tween: Tween = create_tween()
	tween.tween_property(new_label, "scale", Vector2(1.2, 1.2), 0.2) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(new_label, "scale", Vector2.ONE, 0.1)
	tween.tween_interval(1.0)
	tween.tween_property(new_label, "modulate:a", 0.0, 0.5)
	tween.tween_callback(new_label.queue_free)


func _show_tutorial_hint(text: String) -> void:
	_tutorial_label.text = text
	_tutorial_label.modulate.a = 0.0
	var tween: Tween = create_tween()
	tween.tween_property(_tutorial_label, "modulate:a", 1.0, 0.3)


# ── HUD helpers ──────────────────────────────────────────────────────────

func _update_hud() -> void:
	if _game_mode == "daily":
		_bag_label.text = "Daily: %d" % _engine.bag.size()
	else:
		_bag_label.text = "Bag: %d" % _engine.bag.size()


# ── Custom draw: heat meter (right side bar with gradient) ───────────────

func _draw_heat_meter() -> void:
	var rect: Rect2 = _heat_draw.get_rect()
	var w: float = rect.size.x
	var h: float = rect.size.y
	var bar_w: float = 60.0
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

		# Pulsing fill alpha when heat > 0.6
		if _heat_ratio > 0.6:
			var pulse_a: float = 0.7 + 0.3 * sin(Time.get_ticks_msec() / 200.0)
			col.a = pulse_a
		_heat_draw.draw_rect(Rect2(x, fill_y, bar_w, fill_h), col)

	# Threshold tick marks at 25%, 50%, 75%, 90%
	var thresholds: PackedFloat64Array = [0.25, 0.50, 0.75, 0.90]
	for threshold: float in thresholds:
		var tick_y: float = y_top + bar_h * (1.0 - threshold)
		var tick_col: Color = Color(0.6, 0.6, 0.7, 0.5)
		if threshold >= 0.90:
			tick_col = Color(1.0, 0.2, 0.1, 0.8)
		_heat_draw.draw_line(Vector2(x, tick_y), Vector2(x + bar_w, tick_y), tick_col, 2.0)

	# "DANGER" text at 90% mark
	var danger_y: float = y_top + bar_h * (1.0 - 0.90) - 2
	_heat_draw.draw_string(ThemeDB.fallback_font, Vector2(x - 2, danger_y),
		"DANGER", HORIZONTAL_ALIGNMENT_LEFT, bar_w + 4, 16, Color(1.0, 0.15, 0.05, 0.9))

	# Pulsing glow border at high heat
	if _heat_ratio > 0.8:
		var pulse_alpha: float = 0.4 + 0.4 * sin(Time.get_ticks_msec() / 300.0)
		var glow_col: Color = Color(1.0, 0.1, 0.05, pulse_alpha)
		_heat_draw.draw_rect(Rect2(x - 2, y_top - 2, bar_w + 4, bar_h + 4), glow_col, false, 3.0)

	# Border
	_heat_draw.draw_rect(Rect2(x, y_top, bar_w, bar_h), Color(0.4, 0.4, 0.5, 0.6), false, 2.0)

	# Heat percentage text
	var pct_text: String = "%d%%" % int(_heat_ratio * 100)
	if _show_heat_debug:
		pct_text = "%.3f" % _heat_ratio
	_heat_draw.draw_string(ThemeDB.fallback_font, Vector2(x, y_top - 8), pct_text,
		HORIZONTAL_ALIGNMENT_LEFT, bar_w, 24, Color(0.8, 0.8, 0.8))

	# "HEAT" label at the bottom of the meter
	_heat_draw.draw_string(ThemeDB.fallback_font, Vector2(x, y_top + bar_h + 22),
		"HEAT", HORIZONTAL_ALIGNMENT_LEFT, bar_w, 16, Color(0.45, 0.45, 0.55))


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


# ── Ability UI ──────────────────────────────────────────────────────────

func _create_ability_ui() -> void:
	# Remove previous if re-creating (free the canvas layer parent too)
	if _ability_container != null and is_instance_valid(_ability_container):
		var old_canvas: Node = _ability_container.get_parent()
		if old_canvas != null and old_canvas is CanvasLayer and is_instance_valid(old_canvas):
			old_canvas.queue_free()
		else:
			_ability_container.queue_free()
		_ability_container = null
	_ability_buttons.clear()

	# Check if any abilities are unlocked
	var has_any: bool = _ability_manager.is_unlocked(AbilityManager.AbilityType.PEEK) \
		or _ability_manager.is_unlocked(AbilityManager.AbilityType.COOL_DOWN) \
		or _ability_manager.is_unlocked(AbilityManager.AbilityType.SWAP)
	if not has_any:
		return

	# Create container positioned below the pot, above the serve button
	_ability_container = HBoxContainer.new()
	_ability_container.alignment = BoxContainer.ALIGNMENT_CENTER
	_ability_container.add_theme_constant_override("separation", 16)
	_ability_container.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_ability_container.offset_top = -220
	_ability_container.offset_bottom = -120
	_ability_container.offset_left = -180
	_ability_container.offset_right = 180

	# Create buttons for each unlocked ability
	var types: Array = [
		AbilityManager.AbilityType.PEEK,
		AbilityManager.AbilityType.COOL_DOWN,
		AbilityManager.AbilityType.SWAP,
	]
	for ability_type: int in types:
		if not _ability_manager.is_unlocked(ability_type as AbilityManager.AbilityType):
			continue
		var btn: Button = _create_ability_button(ability_type as AbilityManager.AbilityType)
		_ability_container.add_child(btn)
		_ability_buttons[ability_type] = btn

	# Add as CanvasLayer child so it stays on screen
	var canvas: CanvasLayer = CanvasLayer.new()
	canvas.layer = 10
	add_child(canvas)
	canvas.add_child(_ability_container)

	_update_ability_buttons()


func _create_ability_button(ability_type: AbilityManager.AbilityType) -> Button:
	var btn: Button = Button.new()
	btn.custom_minimum_size = Vector2(100, 70)
	btn.add_theme_font_size_override("font_size", 18)

	# Style
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = Color(0.12, 0.12, 0.2, 0.85)
	sb.set_corner_radius_all(16)
	sb.border_color = Color(0.3, 0.3, 0.5, 0.6)
	sb.set_border_width_all(2)
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	btn.add_theme_stylebox_override("normal", sb)

	var pressed_sb: StyleBoxFlat = sb.duplicate() as StyleBoxFlat
	pressed_sb.bg_color = Color(0.2, 0.2, 0.35, 0.9)
	btn.add_theme_stylebox_override("pressed", pressed_sb)

	var disabled_sb: StyleBoxFlat = sb.duplicate() as StyleBoxFlat
	disabled_sb.bg_color = Color(0.08, 0.08, 0.12, 0.6)
	disabled_sb.border_color = Color(0.2, 0.2, 0.3, 0.3)
	btn.add_theme_stylebox_override("disabled", disabled_sb)

	btn.pressed.connect(_on_ability_pressed.bind(ability_type))
	return btn


func _update_ability_buttons() -> void:
	for ability_type: int in _ability_buttons:
		var btn: Button = _ability_buttons[ability_type] as Button
		var ab_type: AbilityManager.AbilityType = ability_type as AbilityManager.AbilityType
		var ab_charges: int = _ability_manager.get_charges(ab_type)
		var ab_max: int = _ability_manager.get_max_charges(ab_type)
		var ab_name: String = AbilityManager.get_ability_name(ab_type)
		var ab_can_use: bool = _ability_manager.can_use(ab_type, _engine.phase)
		var has_refill: bool = _ability_manager.has_ad_refill(ab_type)

		# Update text
		if has_refill:
			btn.text = "%s\n%d/%d +" % [ab_name, ab_charges, ab_max]
		else:
			btn.text = "%s\n%d/%d" % [ab_name, ab_charges, ab_max]

		# Update enabled state
		btn.disabled = not ab_can_use and not has_refill

		# Visual dimming
		if ab_can_use:
			btn.modulate.a = 1.0
		elif has_refill:
			btn.modulate.a = 0.85
		else:
			btn.modulate.a = 0.4


func _on_ability_pressed(ability_type: AbilityManager.AbilityType) -> void:
	# Check if this is an ad refill tap (charges depleted but refill available)
	if _ability_manager.get_charges(ability_type) <= 0 and _ability_manager.has_ad_refill(ability_type):
		_request_ad_refill(ability_type)
		return

	if not _ability_manager.can_use(ability_type, _engine.phase):
		return

	match ability_type:
		AbilityManager.AbilityType.PEEK:
			_use_peek()
		AbilityManager.AbilityType.COOL_DOWN:
			_use_cool_down()
		AbilityManager.AbilityType.SWAP:
			_use_swap()


func _use_peek() -> void:
	if not _ability_manager.use_ability(AbilityManager.AbilityType.PEEK):
		return
	_abilities_used_this_round += 1

	var next: IngredientData = _engine.peek()
	if next == null:
		return

	# Show peek overlay
	_show_peek_overlay(next)
	_update_ability_buttons()
	AnalyticsManager.log_event("ability_used", {"ability": "peek"})


func _use_cool_down() -> void:
	if not _ability_manager.use_ability(AbilityManager.AbilityType.COOL_DOWN):
		return
	_abilities_used_this_round += 1

	_engine.cool_down(GameManager.config.cool_down_amount)
	_heat_ratio = clampf(_engine.heat / GameManager.config.boilover_threshold, 0.0, 1.0)
	_pot_visual.set_heat(_heat_ratio)
	_heat_draw.queue_redraw()

	# Blue flash VFX
	Juice.flash(_pot_visual, Color(0.3, 0.6, 1.0), 0.3)

	# Ice particle burst
	var ice_particles: CPUParticles2D = CPUParticles2D.new()
	ice_particles.position = _pot_visual.position
	ice_particles.emitting = true
	ice_particles.one_shot = true
	ice_particles.amount = 16
	ice_particles.lifetime = 0.8
	ice_particles.explosiveness = 1.0
	ice_particles.direction = Vector2(0, -1)
	ice_particles.spread = 60.0
	ice_particles.initial_velocity_min = 100.0
	ice_particles.initial_velocity_max = 250.0
	ice_particles.gravity = Vector2(0, 300)
	ice_particles.scale_amount_min = 4.0
	ice_particles.scale_amount_max = 8.0
	ice_particles.color = Color(0.5, 0.8, 1.0, 0.9)
	add_child(ice_particles)
	get_tree().create_timer(1.5).timeout.connect(func() -> void:
		if is_instance_valid(ice_particles):
			ice_particles.queue_free()
	)

	Utils.vibrate(20)
	_update_ability_buttons()
	AnalyticsManager.log_event("ability_used", {"ability": "cool_down"})


func _use_swap() -> void:
	if not _ability_manager.use_ability(AbilityManager.AbilityType.SWAP):
		return
	_abilities_used_this_round += 1

	# Clean up current tile
	if is_instance_valid(_current_tile):
		# Spin-off animation
		var old_tile: IngredientTile = _current_tile
		var spin_tween: Tween = create_tween().set_parallel(true)
		spin_tween.tween_property(old_tile, "rotation", TAU, 0.3)
		spin_tween.tween_property(old_tile, "scale", Vector2.ZERO, 0.3)
		spin_tween.tween_property(old_tile, "modulate:a", 0.0, 0.3)
		spin_tween.chain().tween_callback(old_tile.queue_free)
		_current_tile = null

	# Draw replacement via engine
	var replacement: IngredientData = _engine.swap_current()
	if replacement == null:
		_update_ability_buttons()
		return

	# Spawn new tile with pop-in
	_update_hud()
	_preview_label.text = "%s  (+%d pts)" % [replacement.display_name, replacement.points]

	await get_tree().create_timer(0.35).timeout

	_current_tile = _tile_scene.instantiate() as IngredientTile
	_current_tile.setup(replacement)
	add_child(_current_tile)
	_current_tile.reveal(_tile_spawn.position)
	_current_tile.missed.connect(_on_tile_missed)
	_current_tile.flicked.connect(_on_tile_flicked)
	_waiting_for_flick = true

	Juice.pop_in(_current_tile, 0.25)
	_update_ability_buttons()
	AnalyticsManager.log_event("ability_used", {"ability": "swap"})


func _show_peek_overlay(ingredient: IngredientData) -> void:
	# Remove existing overlay and its canvas layer
	if _peek_overlay != null and is_instance_valid(_peek_overlay):
		var old_canvas: Node = _peek_overlay.get_parent()
		if old_canvas != null and is_instance_valid(old_canvas):
			old_canvas.queue_free()
		else:
			_peek_overlay.queue_free()
		_peek_overlay = null

	_peek_overlay = PanelContainer.new()
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.08, 0.14, 0.85)
	sb.set_corner_radius_all(12)
	sb.border_color = Color(0.4, 0.6, 1.0, 0.6)
	sb.set_border_width_all(2)
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	sb.content_margin_top = 12
	sb.content_margin_bottom = 12
	_peek_overlay.add_theme_stylebox_override("panel", sb)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	_peek_overlay.add_child(vbox)

	var title: Label = Label.new()
	title.text = "NEXT UP"
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(0.5, 0.7, 1.0))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var name_label: Label = Label.new()
	name_label.text = ingredient.display_name
	name_label.add_theme_font_size_override("font_size", 28)
	name_label.add_theme_color_override("font_color", ingredient.color.lightened(0.2))
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(name_label)

	var info_label: Label = Label.new()
	info_label.text = "+%d pts  |  %.2f heat" % [ingredient.points, ingredient.heat]
	info_label.add_theme_font_size_override("font_size", 20)
	info_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
	info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(info_label)

	# Position above bag area
	_peek_overlay.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_peek_overlay.offset_top = 180
	_peek_overlay.offset_bottom = 300
	_peek_overlay.offset_left = -140
	_peek_overlay.offset_right = 140

	# Add to canvas layer
	var canvas: CanvasLayer = CanvasLayer.new()
	canvas.layer = 11
	add_child(canvas)
	canvas.add_child(_peek_overlay)

	Juice.pop_in(_peek_overlay, 0.25)

	# Auto-dismiss after 3 seconds
	get_tree().create_timer(3.0).timeout.connect(func() -> void:
		if is_instance_valid(_peek_overlay):
			var fade_tween: Tween = create_tween()
			fade_tween.tween_property(_peek_overlay, "modulate:a", 0.0, 0.3)
			fade_tween.tween_callback(func() -> void:
				if is_instance_valid(_peek_overlay):
					_peek_overlay.get_parent().queue_free()  # Remove canvas layer too
					_peek_overlay = null
			)
	)


func _request_ad_refill(ability_type: AbilityManager.AbilityType) -> void:
	var ability_name: String = AbilityManager.get_ability_name(ability_type)
	# Show rewarded ad
	if not AdManager.show_rewarded():
		return

	# Connect to rewarded ad signal (one-shot)
	# Signal signature: rewarded_ad_completed(reward_type: String, amount: int)
	var callback: Callable = func(_reward_type: String, _amount: int) -> void:
		_ability_manager.refill_ability(ability_type)
		_update_ability_buttons()
		AnalyticsManager.log_event("ad_refill_used", {"ability": ability_name})

	if AdManager.has_signal("rewarded_ad_completed"):
		if not AdManager.is_connected("rewarded_ad_completed", callback):
			AdManager.rewarded_ad_completed.connect(callback, CONNECT_ONE_SHOT)
