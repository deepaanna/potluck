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

@onready var _camera: Camera2D = $Camera2D
@onready var _pot_visual := $PotVisual
@onready var _tile_spawn: Marker2D = $TileSpawnPoint
@onready var _combo_container: Node2D = $ComboPopupContainer
@onready var _vignette_rect: ColorRect = $VignetteRect
@onready var _sizzle_player: AudioStreamPlayer = $SizzlePlayer
@onready var _flick_trail: Line2D = $FlickTrail

# HUD
@onready var _bag_label: Label = %BagCountLabel
@onready var _score_label: Label = %ScoreLabel
@onready var _preview_label: Label = %IngredientPreview
@onready var _flick_prompt: Label = %FlickPrompt
@onready var _stop_button: Button = %StopButton
@onready var _heat_draw: Control = %HeatMeterDraw
@onready var _pot_dots: Control = %PotDots
@onready var _tutorial_label: Label = %TutorialLabel

var _engine: PotLuckEngine = PotLuckEngine.new()
var _current_tile: IngredientTile = null
var _tile_scene: PackedScene = preload("res://game/ingredient_tile.tscn")
var _combo_popup_scene: PackedScene = preload("res://scenes/combo_popup_label.tscn")
var _second_chance_scene: PackedScene = preload("res://scenes/second_chance_popup.tscn")
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

# Game mode
var _game_mode: String = "endless"  # "endless" or "daily"
var _daily_bag: Array[IngredientData] = []


func _ready() -> void:
	GameManager.start_game()
	AnalyticsManager.log_event("level_start", {"level": GameManager.level})
	AnalyticsManager.log_screen("game")

	# Detect game mode
	if GameManager.has_meta("game_mode"):
		_game_mode = GameManager.get_meta("game_mode") as String
		GameManager.remove_meta("game_mode")

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

	# Heat meter redraw at > 0.8 for glow pulse
	if _heat_ratio > 0.8:
		_heat_draw.queue_redraw()


# ── Round lifecycle ──────────────────────────────────────────────────────

func _start_round() -> void:
	_engine.reset()

	# Daily mode: use deterministic bag; normal mode: random bag
	if _game_mode == "daily":
		_daily_bag = DailyChallenge.get_daily_bag()
		_engine.bag = _daily_bag.duplicate()
	else:
		_engine.fill_bag()

	_running_score = 0
	_heat_ratio = 0.0
	_pot_colors.clear()
	_update_hud()
	_pot_visual.set_heat(0.0)
	_stop_button.visible = false
	_flick_prompt.text = ""
	_preview_label.text = "Daily Challenge" if _game_mode == "daily" else ""

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

	AudioManager.play_sfx_path(SFX_DRAW)

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


func _on_pot_landed(tile: IngredientTile) -> void:
	if tile != _current_tile:
		return
	_waiting_for_flick = false

	_engine.add_to_pot()
	_pot_visual.play_splash()
	AudioManager.play_sfx_path(SFX_SPLASH)
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

	# Tutorial hint step 3
	if _is_tutorial and _tutorial_step == 2:
		_show_tutorial_hint("Serve now for safe points,\nor keep adding for more!")
		_tutorial_step = 3


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

	# Recipe discovery via RecipeBook
	var is_new: bool = RecipeBook.discover_recipe(combo.combo_name)
	if is_new:
		AnalyticsManager.log_event("recipe_discovered", {"combo_name": combo.combo_name})
		_show_new_recipe_popup(combo)

	if combo.is_penalty:
		AudioManager.play_sfx_path(SFX_COMBO_PENALTY, 0.0, randf_range(0.9, 1.1))
		Juice.flash(_pot_visual, Color(1.0, 0.2, 0.1), 0.3)
		ScreenShake.shake(_camera, 8.0, 0.2)
	else:
		AudioManager.play_sfx_path(SFX_COMBO, 0.0, randf_range(0.9, 1.1))
		Juice.flash(_pot_visual, Color(1.0, 1.0, 0.5), 0.2)


func _on_heat_changed(new_heat: float, _stage: int) -> void:
	_heat_ratio = clampf(new_heat / GameManager.config.boilover_threshold, 0.0, 1.0)
	_pot_visual.set_heat(_heat_ratio)
	_heat_draw.queue_redraw()

	# Update vignette shader
	if _vignette_rect.material is ShaderMaterial:
		(_vignette_rect.material as ShaderMaterial).set_shader_parameter("heat_intensity", _heat_ratio)

	# Reset tension timer so shake re-triggers from current moment
	_tension_timer = 0.0


func _on_boilover() -> void:
	AnalyticsManager.log_event("boilover")
	_pot_visual.play_boilover(_camera)
	Utils.vibrate(200)
	AudioManager.play_sfx_path(SFX_BOILOVER)
	_stop_button.visible = false
	_flick_prompt.text = ""
	_preview_label.text = ""

	# Stop sizzle
	if _sizzle_player.playing:
		_sizzle_player.stop()

	if is_instance_valid(_current_tile):
		_current_tile.queue_free()
		_current_tile = null

	if not _engine.second_chance_used:
		await get_tree().create_timer(0.6).timeout
		AudioManager.play_sfx_path(SFX_SECOND_CHANCE)
		_show_second_chance()
	else:
		await get_tree().create_timer(0.8).timeout
		_end_game(0, true)


func _on_dish_served(final_score: int) -> void:
	AudioManager.play_sfx_path(SFX_SERVE)

	# Stop sizzle
	if _sizzle_player.playing:
		_sizzle_player.stop()

	# Score count-up tween
	_displayed_score = 0.0
	_score_label.text = "0"

	if _score_countup_tween and _score_countup_tween.is_valid():
		_score_countup_tween.kill()

	_score_countup_tween = create_tween()
	_score_countup_tween.tween_method(_update_score_display, 0.0, float(final_score), 1.0) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	_score_countup_tween.tween_callback(func() -> void:
		# Green flash + ding at completion
		Juice.flash(_score_label, Color(0.2, 1.0, 0.3), 0.3)
		AudioManager.play_sfx_path(SFX_DING)
	)

	await _score_countup_tween.finished

	# Restore bag_size if tutorial
	if _is_tutorial:
		GameManager.config.bag_size = _original_bag_size
		_is_tutorial = false
		SaveManager.set_value("pot_luck.tutorial_completed", true)

	_end_game(final_score, false)


func _on_bag_emptied() -> void:
	_preview_label.text = "Clean Pot! x%.1f Bonus!" % GameManager.config.clean_pot_bonus
	Juice.pulse(_score_label, 1.3, 0.3)


# ── Tile flicked handler ────────────────────────────────────────────────

func _on_tile_flicked(_tile: IngredientTile) -> void:
	AudioManager.play_sfx_path(SFX_FLICK, 0.0, randf_range(0.9, 1.1))


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
		"mode": _game_mode,
	})

	# Daily challenge: submit score
	if _game_mode == "daily" and not was_boilover:
		DailyChallenge.submit_score(final_score)
		AnalyticsManager.log_event("daily_challenge_completed", {
			"score": final_score,
			"seed": DailyChallenge.get_daily_seed(),
		})

	GameManager.set_meta("pot_luck_data", {
		"final_score": final_score,
		"was_boilover": was_boilover,
		"ingredients_count": ingredients_used,
		"combos": _engine.triggered_combos.size(),
		"combo_multiplier": _engine.get_combo_multiplier(),
		"streak_bonus": _engine.get_streak_bonus(),
		"bag_emptied": _engine.bag_was_emptied,
		"mode": _game_mode,
	})

	GameManager.add_score(final_score)
	GameManager.end_game()

	await get_tree().create_timer(0.5).timeout
	GameManager.goto_scene("res://scenes/game_over.tscn")


# ── Polish helpers ───────────────────────────────────────────────────────

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
	new_label.position = Vector2(340, 1100)
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
