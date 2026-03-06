## Game over screen with outcome-dependent VFX.
## Shows dramatic reveal (score, outcome), then auto-advances to rewards screen.
extends Control

@onready var _background: ColorRect = %Background
@onready var _background_art: TextureRect = %BackgroundArt
@onready var _score_banner: TextureRect = %ScoreBanner
@onready var _screen_flash: ColorRect = %ScreenFlash
@onready var _vfx_layer: Control = $VFXLayer
@onready var _score_label: Label = %ScoreLabel
@onready var _score_header: Label = %ScoreHeader
@onready var _high_score_label: Label = %HighScoreLabel
@onready var _new_high_score_label: Label = %NewHighScoreLabel
@onready var _outcome_label: Label = %OutcomeLabel
@onready var _continue_label: Label = %ContinueLabel
@onready var _continue_button: Button = %ContinueButton

var _pot_luck_data: Dictionary = {}
var _was_boilover: bool = false
var _bag_emptied: bool = false
var _score: int = 0
var _is_new_high_score: bool = false
var _smoke_tex: Texture2D = preload("res://assets/particles/kenney_particle-pack/PNG (Transparent)/smoke_07.png")
var _star_tex: Texture2D = preload("res://assets/particles/kenney_particle-pack/PNG (Transparent)/star_04.png")
var _auto_advance_timer: SceneTreeTimer = null
var _advanced: bool = false
var _xp_earned: int = 0
var _leveled_up: bool = false
var _new_level: int = 1


func _ready() -> void:
	AnalyticsManager.log_screen("game_over")

	if GameManager.has_meta("pot_luck_data"):
		_pot_luck_data = GameManager.get_meta("pot_luck_data") as Dictionary

	_was_boilover = _pot_luck_data.get("was_boilover", false) as bool
	_bag_emptied = _pot_luck_data.get("bag_emptied", false) as bool
	_score = GameManager.score
	var previous_high: int = _pot_luck_data.get("previous_high_score", 0) as int
	var high_score: int = SaveManager.get_value("high_score", 0) as int
	_is_new_high_score = _score > 0 and _score > previous_high
	_xp_earned = _pot_luck_data.get("xp_earned", 0) as int
	_leveled_up = _pot_luck_data.get("leveled_up", false) as bool
	_new_level = _pot_luck_data.get("new_level", 1) as int

	# Set up high score text
	var was_daily: bool = _pot_luck_data.get("mode", "endless") == "daily"
	if was_daily:
		var daily_best: int = DailyChallenge.get_today_best()
		if daily_best > 0:
			_high_score_label.text = "Daily Best: %s" % Utils.format_number(daily_best)
		else:
			_high_score_label.text = "Best: %s" % Utils.format_number(high_score)
	else:
		_high_score_label.text = "Best: %s" % Utils.format_number(high_score)

	# Hide elements initially for timed reveal
	_score_banner.modulate.a = 0.0
	_score_label.modulate.a = 0.0
	_high_score_label.modulate.a = 0.0
	_new_high_score_label.visible = false
	_continue_label.visible = false
	_outcome_label.modulate.a = 0.0

	_continue_button.pressed.connect(_advance_to_rewards)

	# Try to show an interstitial ad
	AdManager.show_interstitial()

	# Run the timed VFX sequence
	_play_vfx_sequence()


func _play_vfx_sequence() -> void:
	if _bag_emptied and not _was_boilover:
		_play_perfect_pot()
	elif _was_boilover:
		_play_boilover()
	else:
		_play_served()


# ── PERFECT POT VFX ──────────────────────────────────────────────────────

func _play_perfect_pot() -> void:
	# 0.0s: Warm gold background tint (strong shift)
	var bg_tween: Tween = create_tween()
	bg_tween.tween_property(_background, "color", Color(0.18, 0.14, 0.04), 0.8) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	# Gold confetti particles (continuous gentle rain)
	_spawn_confetti_particles()

	# 0.1s: Outcome label pops in with gold color
	_outcome_label.text = "PERFECT POT!"
	_outcome_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.0))
	_outcome_label.modulate.a = 1.0
	Juice.pop_in(_outcome_label, 0.35, 0.1)

	# Squash stretch after pop in — punchy
	get_tree().create_timer(0.45).timeout.connect(func() -> void:
		Juice.squash_stretch(_outcome_label, 0.35, 0.25)
	)

	# 0.5s: Score reveal with white flash + count-up + shake
	get_tree().create_timer(0.5).timeout.connect(func() -> void:
		_flash_screen(Color.WHITE, 0.35)
		_shake_ui(14.0, 0.3)
		_reveal_score_countup()
	)

	# 1.0s: High score fade in
	_fade_in_node(_high_score_label, 0.2, 1.0)

	# 1.2s: New high score badge
	if _is_new_high_score:
		get_tree().create_timer(1.2).timeout.connect(func() -> void:
			_show_new_high_score_badge()
		)

	# 1.5s: XP + level up
	get_tree().create_timer(1.5).timeout.connect(_show_xp_and_level_up)

	# 2.5s: Continue label
	get_tree().create_timer(2.5).timeout.connect(func() -> void:
		_show_continue()
	)

	# Auto-advance after 4.0s (extended for level-up display)
	_auto_advance_timer = get_tree().create_timer(4.0 if _leveled_up else 3.5)
	_auto_advance_timer.timeout.connect(_advance_to_rewards)


# ── SERVED VFX ────────────────────────────────────────────────────────────

func _play_served() -> void:
	# Subtle green particles (one-shot, upward drift)
	_spawn_served_particles()

	# 0.1s: Outcome label with green color
	_outcome_label.text = "Dish Served!"
	_outcome_label.add_theme_color_override("font_color", Color(0.3, 0.9, 0.3))
	_outcome_label.modulate.a = 1.0
	Juice.pop_in(_outcome_label, 0.35, 0.1)

	# 0.5s: Score count-up with green flash
	get_tree().create_timer(0.5).timeout.connect(func() -> void:
		_flash_screen(Color(0.3, 1.0, 0.4), 0.25)
		_reveal_score_countup()
	)

	# 1.0s: High score fade in
	_fade_in_node(_high_score_label, 0.2, 1.0)

	# 1.2s: New high score badge
	if _is_new_high_score:
		get_tree().create_timer(1.2).timeout.connect(func() -> void:
			_show_new_high_score_badge()
		)

	# 1.5s: XP + level up
	get_tree().create_timer(1.5).timeout.connect(_show_xp_and_level_up)

	# 2.5s: Continue label
	get_tree().create_timer(2.5).timeout.connect(func() -> void:
		_show_continue()
	)

	# Auto-advance after 4.0s (extended for level-up display)
	_auto_advance_timer = get_tree().create_timer(4.0 if _leveled_up else 3.5)
	_auto_advance_timer.timeout.connect(_advance_to_rewards)


# ── BOILOVER VFX ──────────────────────────────────────────────────────────

func _play_boilover() -> void:
	# Swap to boilover background art
	var boilover_tex: Texture2D = load("res://assets/sprites/Gemini_Generated_Image_cczvgwcczvgwcczv.png") as Texture2D
	if boilover_tex:
		_background_art.texture = boilover_tex
		_background_art.modulate.a = 0.25

	# 0.0s: Dark red background tint (strong shift)
	var bg_tween: Tween = create_tween()
	bg_tween.tween_property(_background, "color", Color(0.2, 0.04, 0.03), 0.8) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	# Red ember particles (continuous)
	_spawn_ember_particles()
	# Smoke particles
	_spawn_smoke_particles()

	# 0.1s: Outcome label with red flash
	_outcome_label.text = "BOILOVER!"
	_outcome_label.add_theme_color_override("font_color", Color(1.0, 0.2, 0.1))
	_outcome_label.modulate.a = 1.0
	Juice.pop_in(_outcome_label, 0.35, 0.1)

	# Red flash + heavy UI shake
	get_tree().create_timer(0.1).timeout.connect(func() -> void:
		_flash_screen(Color(1.0, 0.1, 0.03), 0.4)
		_shake_ui(25.0, 0.5)
	)

	# Squash stretch with heavy slam feel
	get_tree().create_timer(0.45).timeout.connect(func() -> void:
		Juice.squash_stretch(_outcome_label, 0.5, 0.3)
	)

	# 0.5s: Score slam to "0" immediately (no count-up)
	get_tree().create_timer(0.5).timeout.connect(func() -> void:
		_score_banner.modulate.a = 1.0
		_score_label.text = "0"
		_score_label.modulate.a = 1.0
		Juice.slam_in(_score_label, 0.3)
	)

	# 1.0s: High score fade in
	_fade_in_node(_high_score_label, 0.2, 1.0)

	# 1.3s: XP (even on boilover, consolation XP)
	get_tree().create_timer(1.3).timeout.connect(_show_xp_and_level_up)

	# 2.5s: Continue label
	get_tree().create_timer(2.5).timeout.connect(func() -> void:
		_show_continue()
	)

	# Auto-advance after 4.0s (extended for level-up display)
	_auto_advance_timer = get_tree().create_timer(4.0 if _leveled_up else 3.5)
	_auto_advance_timer.timeout.connect(_advance_to_rewards)


# ── VFX Helpers ───────────────────────────────────────────────────────────

func _flash_screen(color: Color, duration: float) -> void:
	_screen_flash.color = color
	_screen_flash.modulate.a = 1.0
	var tween: Tween = create_tween()
	tween.tween_property(_screen_flash, "modulate:a", 0.0, duration) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)


func _reveal_score_countup() -> void:
	_score_header.modulate.a = 0.0
	_score_label.modulate.a = 1.0

	# Fade in score banner
	var header_tween: Tween = create_tween()
	header_tween.tween_property(_score_banner, "modulate:a", 1.0, 0.2)

	# Count up score
	if _score > 0:
		Juice.count_up(_score_label, 0, _score, 0.6)
	else:
		_score_label.text = "0"


func _fade_in_node(node: CanvasItem, duration: float, delay: float) -> void:
	node.modulate.a = 0.0
	var tween: Tween = create_tween()
	tween.tween_interval(delay)
	tween.tween_property(node, "modulate:a", 1.0, duration)


func _show_new_high_score_badge() -> void:
	_new_high_score_label.visible = true
	_new_high_score_label.modulate.a = 1.0
	Juice.pop_in(_new_high_score_label, 0.3)
	_flash_screen(Color(1.0, 0.85, 0.0), 0.35)
	_shake_ui(8.0, 0.2)
	Juice.pulse(_new_high_score_label, 1.15, 1.0)


func _shake_ui(intensity: float, duration: float) -> void:
	var safe_area: MarginContainer = %SafeArea
	var original_pos: Vector2 = safe_area.position
	var tween: Tween = create_tween()
	var steps: int = ceili(duration / 0.05)
	for i: int in range(steps):
		var step_intensity: float = intensity * (1.0 - (float(i) / float(steps)))
		var offset: Vector2 = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized() * step_intensity
		tween.tween_property(safe_area, "position", original_pos + offset, 0.05)
	tween.tween_property(safe_area, "position", original_pos, 0.05)


func _show_xp_and_level_up() -> void:
	var xp_safe_area: MarginContainer = %SafeArea

	if _xp_earned > 0:
		# "+X XP" floating text
		var xp_label: Label = Label.new()
		xp_label.text = "+%d XP" % _xp_earned
		xp_label.add_theme_font_size_override("font_size", 32)
		xp_label.add_theme_color_override("font_color", Color(0.9, 0.75, 0.3))
		xp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		xp_label.set_anchors_preset(Control.PRESET_CENTER)
		xp_label.offset_top = 80
		xp_label.offset_bottom = 120
		xp_label.offset_left = -100
		xp_label.offset_right = 100
		xp_safe_area.add_child(xp_label)

		# Float up + fade
		xp_label.modulate.a = 0.0
		var xp_tween: Tween = create_tween()
		xp_tween.tween_property(xp_label, "modulate:a", 1.0, 0.2)
		xp_tween.tween_property(xp_label, "offset_top", xp_label.offset_top - 30.0, 1.0) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	if _leveled_up:
		# Show LEVEL UP! with slam_in
		await get_tree().create_timer(0.5).timeout
		var level_label: Label = Label.new()
		level_label.text = "LEVEL UP!"
		level_label.add_theme_font_size_override("font_size", 48)
		level_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.0))
		level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		level_label.set_anchors_preset(Control.PRESET_CENTER)
		level_label.offset_top = 130
		level_label.offset_bottom = 190
		level_label.offset_left = -150
		level_label.offset_right = 150
		xp_safe_area.add_child(level_label)
		Juice.slam_in(level_label, 0.35)

		# Chef Level X subtitle
		var sublabel: Label = Label.new()
		sublabel.text = "Chef Level %d" % _new_level
		sublabel.add_theme_font_size_override("font_size", 28)
		sublabel.add_theme_color_override("font_color", Color(0.9, 0.75, 0.3))
		sublabel.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		sublabel.set_anchors_preset(Control.PRESET_CENTER)
		sublabel.offset_top = 185
		sublabel.offset_bottom = 220
		sublabel.offset_left = -120
		sublabel.offset_right = 120
		xp_safe_area.add_child(sublabel)
		sublabel.modulate.a = 0.0
		var sub_tween: Tween = create_tween()
		sub_tween.tween_interval(0.2)
		sub_tween.tween_property(sublabel, "modulate:a", 1.0, 0.25)

		_flash_screen(Color(1.0, 0.85, 0.0), 0.3)
		_shake_ui(10.0, 0.2)


func _show_continue() -> void:
	if _advanced:
		return
	_continue_label.visible = true
	_continue_label.modulate.a = 0.0
	var tween: Tween = create_tween()
	tween.tween_property(_continue_label, "modulate:a", 0.7, 0.3)


# ── Particle spawners ────────────────────────────────────────────────────

func _spawn_confetti_particles() -> void:
	# Main confetti rain — wide spread across entire screen width
	var rain: CPUParticles2D = CPUParticles2D.new()
	rain.emitting = true
	rain.one_shot = false
	rain.amount = 50
	rain.lifetime = 2.5
	rain.explosiveness = 0.0
	rain.direction = Vector2(0, 1)
	rain.spread = 30.0
	rain.initial_velocity_min = 150.0
	rain.initial_velocity_max = 350.0
	rain.gravity = Vector2(0, 200)
	rain.scale_amount_min = 6.0
	rain.scale_amount_max = 14.0
	rain.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	rain.emission_rect_extents = Vector2(size.x * 0.45, 10)
	rain.color_ramp = _create_gold_gradient()
	rain.position = Vector2(size.x / 2.0, -40)
	_vfx_layer.add_child(rain)

	# Burst of confetti at center for immediate impact
	var burst: CPUParticles2D = CPUParticles2D.new()
	burst.emitting = true
	burst.one_shot = true
	burst.amount = 30
	burst.lifetime = 1.2
	burst.explosiveness = 1.0
	burst.direction = Vector2(0, -1)
	burst.spread = 180.0
	burst.initial_velocity_min = 200.0
	burst.initial_velocity_max = 500.0
	burst.gravity = Vector2(0, 300)
	burst.scale_amount_min = 8.0
	burst.scale_amount_max = 16.0
	burst.color_ramp = _create_gold_gradient()
	burst.position = Vector2(size.x / 2.0, size.y * 0.4)
	_vfx_layer.add_child(burst)

	# Sparkle layer — star particles
	var sparkles: CPUParticles2D = CPUParticles2D.new()
	sparkles.texture = _star_tex
	sparkles.emitting = true
	sparkles.one_shot = false
	sparkles.amount = 25
	sparkles.lifetime = 1.0
	sparkles.explosiveness = 0.0
	sparkles.direction = Vector2(0, 1)
	sparkles.spread = 60.0
	sparkles.initial_velocity_min = 50.0
	sparkles.initial_velocity_max = 180.0
	sparkles.gravity = Vector2(0, 100)
	sparkles.scale_amount_min = 0.04
	sparkles.scale_amount_max = 0.08
	sparkles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	sparkles.emission_rect_extents = Vector2(size.x * 0.4, 10)
	sparkles.color = Color(1.0, 1.0, 0.8, 0.9)
	sparkles.position = Vector2(size.x / 2.0, -20)
	_vfx_layer.add_child(sparkles)


func _spawn_served_particles() -> void:
	# Green upward burst from center
	var burst: CPUParticles2D = CPUParticles2D.new()
	burst.emitting = true
	burst.one_shot = true
	burst.amount = 25
	burst.lifetime = 1.5
	burst.explosiveness = 0.9
	burst.direction = Vector2(0, -1)
	burst.spread = 90.0
	burst.initial_velocity_min = 150.0
	burst.initial_velocity_max = 350.0
	burst.gravity = Vector2(0, 80)
	burst.scale_amount_min = 6.0
	burst.scale_amount_max = 12.0
	burst.color = Color(0.3, 1.0, 0.4, 0.85)
	burst.position = Vector2(size.x / 2.0, size.y * 0.5)
	_vfx_layer.add_child(burst)

	# Gentle rising particles (continuous, subtle)
	var rising: CPUParticles2D = CPUParticles2D.new()
	rising.emitting = true
	rising.one_shot = false
	rising.amount = 15
	rising.lifetime = 2.0
	rising.explosiveness = 0.0
	rising.direction = Vector2(0, -1)
	rising.spread = 40.0
	rising.initial_velocity_min = 40.0
	rising.initial_velocity_max = 100.0
	rising.gravity = Vector2(0, -20)
	rising.scale_amount_min = 4.0
	rising.scale_amount_max = 8.0
	rising.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	rising.emission_rect_extents = Vector2(size.x * 0.3, 20)
	rising.color = Color(0.2, 0.8, 0.3, 0.5)
	rising.position = Vector2(size.x / 2.0, size.y * 0.7)
	_vfx_layer.add_child(rising)


func _spawn_ember_particles() -> void:
	# Main ember field — wide spread, rising from bottom
	var embers: CPUParticles2D = CPUParticles2D.new()
	embers.emitting = true
	embers.one_shot = false
	embers.amount = 35
	embers.lifetime = 3.0
	embers.explosiveness = 0.0
	embers.direction = Vector2(0, -1)
	embers.spread = 60.0
	embers.initial_velocity_min = 40.0
	embers.initial_velocity_max = 150.0
	embers.gravity = Vector2(0, -20)
	embers.scale_amount_min = 5.0
	embers.scale_amount_max = 10.0
	embers.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	embers.emission_rect_extents = Vector2(size.x * 0.45, 40)
	embers.color_ramp = _create_ember_gradient()
	embers.position = Vector2(size.x / 2.0, size.y * 0.85)
	_vfx_layer.add_child(embers)

	# Hot bright sparks — small, fast, scattered
	var sparks: CPUParticles2D = CPUParticles2D.new()
	sparks.emitting = true
	sparks.one_shot = false
	sparks.amount = 20
	sparks.lifetime = 1.5
	sparks.explosiveness = 0.0
	sparks.direction = Vector2(0, -1)
	sparks.spread = 90.0
	sparks.initial_velocity_min = 80.0
	sparks.initial_velocity_max = 250.0
	sparks.gravity = Vector2(0, 30)
	sparks.scale_amount_min = 3.0
	sparks.scale_amount_max = 6.0
	sparks.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	sparks.emission_rect_extents = Vector2(size.x * 0.35, 20)
	sparks.color = Color(1.0, 0.7, 0.1, 0.9)
	sparks.position = Vector2(size.x / 2.0, size.y * 0.9)
	_vfx_layer.add_child(sparks)


func _spawn_smoke_particles() -> void:
	var smoke: CPUParticles2D = CPUParticles2D.new()
	smoke.texture = _smoke_tex
	smoke.emitting = true
	smoke.one_shot = false
	smoke.amount = 12
	smoke.lifetime = 3.5
	smoke.explosiveness = 0.0
	smoke.direction = Vector2(0, -1)
	smoke.spread = 40.0
	smoke.initial_velocity_min = 20.0
	smoke.initial_velocity_max = 60.0
	smoke.gravity = Vector2(0, -10)
	smoke.scale_amount_min = 0.15
	smoke.scale_amount_max = 0.3
	smoke.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	smoke.emission_rect_extents = Vector2(size.x * 0.3, 30)
	smoke.color = Color(0.15, 0.1, 0.08, 0.4)
	smoke.position = Vector2(size.x / 2.0, size.y * 0.65)
	_vfx_layer.add_child(smoke)


func _create_gold_gradient() -> Gradient:
	var gradient: Gradient = Gradient.new()
	gradient.colors = PackedColorArray([
		Color(1.0, 0.9, 0.3, 1.0),
		Color(1.0, 0.7, 0.15, 0.8),
		Color(0.9, 0.5, 0.1, 0.0),
	])
	gradient.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	return gradient


func _create_ember_gradient() -> Gradient:
	var gradient: Gradient = Gradient.new()
	gradient.colors = PackedColorArray([
		Color(1.0, 0.5, 0.1, 1.0),
		Color(1.0, 0.25, 0.05, 0.7),
		Color(0.6, 0.1, 0.02, 0.0),
	])
	gradient.offsets = PackedFloat32Array([0.0, 0.4, 1.0])
	return gradient


# ── Navigation ────────────────────────────────────────────────────────────

func _advance_to_rewards() -> void:
	if _advanced:
		return
	_advanced = true
	GameManager.goto_scene("res://scenes/rewards_screen.tscn")
