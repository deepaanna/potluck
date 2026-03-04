## Cauldron visual with sprite, heat coloring, bubble particles, and boilover.
## Has a generous Area2D that detects flicked ingredient tiles.
extends Node2D

signal ingredient_landed(tile: IngredientTile)

@onready var _sprite: Sprite2D = $Sprite2D
@onready var _catch_area: Area2D = $CatchArea
@onready var _bubbles: CPUParticles2D = $Bubbles
@onready var _boilover_burst: CPUParticles2D = $BoiloverBurst

var _heat: float = 0.0
var _base_scale: Vector2 = Vector2.ONE
var _pulse_tween: Tween = null


func _ready() -> void:
	_base_scale = scale
	_catch_area.area_entered.connect(_on_area_entered)
	_bubbles.emitting = false
	_boilover_burst.emitting = false
	set_heat(0.0)


func set_heat(value: float) -> void:
	_heat = clampf(value, 0.0, 1.2)

	# Color shift: blue-ish → orange → red → intense red
	var tint: Color
	if _heat < 0.3:
		tint = Color(0.85, 0.9, 1.0).lerp(Color(1.0, 1.0, 1.0), _heat / 0.3)
	elif _heat < 0.6:
		var t: float = (_heat - 0.3) / 0.3
		tint = Color(1.0, 1.0, 1.0).lerp(Color(1.0, 0.8, 0.5), t)
	elif _heat < 0.8:
		var t: float = (_heat - 0.6) / 0.2
		tint = Color(1.0, 0.8, 0.5).lerp(Color(1.0, 0.5, 0.3), t)
	else:
		var t: float = clampf((_heat - 0.8) / 0.2, 0.0, 1.0)
		tint = Color(1.0, 0.5, 0.3).lerp(Color(1.0, 0.25, 0.15), t)

	_sprite.modulate = tint

	# Bubble particles — increase with heat
	if _heat > 0.15:
		_bubbles.emitting = true
		_bubbles.amount = clampi(int(_heat * 40), 3, 40)
		_bubbles.initial_velocity_min = 20.0 + _heat * 60.0
		_bubbles.initial_velocity_max = 40.0 + _heat * 100.0
	else:
		_bubbles.emitting = false

	# Pulse at high heat
	if _heat >= 0.8:
		_start_danger_pulse()
	else:
		_stop_danger_pulse()


func play_splash() -> void:
	Juice.squash_stretch(self, 0.12, 0.2)


func play_boilover(camera: Camera2D) -> void:
	# Screen shake
	ScreenShake.shake(camera, 20.0, 0.5)

	# Flash red
	Juice.flash(self, Color(1.0, 0.2, 0.1), 0.4)

	# Scale up then settle
	var tween: Tween = create_tween()
	tween.tween_property(self, "scale", _base_scale * 1.25, 0.15).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(self, "scale", _base_scale, 0.4).set_trans(Tween.TRANS_ELASTIC)

	# Burst particles upward
	_boilover_burst.restart()
	_boilover_burst.emitting = true


func _start_danger_pulse() -> void:
	if _pulse_tween and _pulse_tween.is_valid():
		return
	_pulse_tween = create_tween().set_loops()
	_pulse_tween.tween_property(self, "scale", _base_scale * 1.04, 0.3).set_trans(Tween.TRANS_SINE)
	_pulse_tween.tween_property(self, "scale", _base_scale * 0.97, 0.3).set_trans(Tween.TRANS_SINE)


func _stop_danger_pulse() -> void:
	if _pulse_tween and _pulse_tween.is_valid():
		_pulse_tween.kill()
		_pulse_tween = null
		scale = _base_scale


func _on_area_entered(area: Area2D) -> void:
	var tile: Node = area.get_parent()
	if tile is IngredientTile:
		(tile as IngredientTile).on_pot_entered()
		ingredient_landed.emit(tile as IngredientTile)
