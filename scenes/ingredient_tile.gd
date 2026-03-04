## Ingredient tile visual with flick/tap input handling.
## Spawns at bottom, player flicks/taps upward to send to pot.
extends Node2D

signal flicked(tile: Node2D)
signal arrived_at_pot(tile: Node2D)

@onready var _background: ColorRect = $Background
@onready var _name_label: Label = $Background/NameLabel
@onready var _points_label: Label = $Background/PointsLabel
@onready var _rarity_label: Label = $Background/RarityLabel

var ingredient_data: IngredientData
var _dragging: bool = false
var _drag_start: Vector2 = Vector2.ZERO
var _drag_start_pos: Vector2 = Vector2.ZERO
var _drag_velocity: Vector2 = Vector2.ZERO
var _last_pos: Vector2 = Vector2.ZERO
var _flying: bool = false

const FLICK_THRESHOLD: float = -10.0  # Negative Y = upward
const TILE_SIZE: Vector2 = Vector2(280, 160)
const HIT_PADDING: float = 80.0  # Extra tap area around tile


func setup(data: IngredientData) -> void:
	ingredient_data = data


func _ready() -> void:
	if ingredient_data == null:
		return

	_background.color = ingredient_data.color
	_background.custom_minimum_size = TILE_SIZE
	_background.size = TILE_SIZE
	_background.position = -TILE_SIZE / 2.0

	# Text color: dark for light backgrounds, white for dark
	var luminance: float = ingredient_data.color.r * 0.299 + ingredient_data.color.g * 0.587 + ingredient_data.color.b * 0.114
	var text_color: Color = Color.BLACK if luminance > 0.5 else Color.WHITE

	_name_label.text = ingredient_data.display_name
	_name_label.add_theme_color_override("font_color", text_color)

	_points_label.text = "+%d" % ingredient_data.points
	_points_label.add_theme_color_override("font_color", text_color)

	var rarity_text: String = ""
	match ingredient_data.rarity:
		IngredientData.Rarity.UNCOMMON:
			rarity_text = "U"
		IngredientData.Rarity.RARE:
			rarity_text = "R"
	_rarity_label.text = rarity_text
	_rarity_label.add_theme_color_override("font_color", text_color)


func appear() -> void:
	scale = Vector2.ZERO
	Juice.pop_in(self, 0.3)


func fly_to_pot(target: Vector2) -> void:
	if _flying:
		return
	_flying = true
	_dragging = false

	var tween: Tween = create_tween()
	tween.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(self, "position", target, 0.25)
	tween.parallel().tween_property(self, "scale", Vector2(0.5, 0.5), 0.25)
	tween.tween_callback(_on_arrived)


func _on_arrived() -> void:
	arrived_at_pot.emit(self)


func _input(event: InputEvent) -> void:
	if _flying:
		return

	# Handle touch/click start and release
	if event is InputEventScreenTouch:
		var touch: InputEventScreenTouch = event as InputEventScreenTouch
		var world_pos: Vector2 = _screen_to_world(touch.position)
		if touch.pressed:
			if _hit_test(world_pos):
				_start_drag(touch.position)
				get_viewport().set_input_as_handled()
		elif _dragging:
			_end_drag(touch.position)
			get_viewport().set_input_as_handled()

	elif event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return
		var world_pos: Vector2 = get_global_mouse_position()
		if mb.pressed:
			if _hit_test(world_pos):
				_start_drag(mb.position)
				get_viewport().set_input_as_handled()
		elif _dragging:
			_end_drag(mb.position)
			get_viewport().set_input_as_handled()

	# Handle drag motion
	elif event is InputEventScreenDrag and _dragging:
		var drag: InputEventScreenDrag = event as InputEventScreenDrag
		_update_drag(drag.position)

	elif event is InputEventMouseMotion and _dragging:
		if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			_dragging = false
			return
		var motion: InputEventMouseMotion = event as InputEventMouseMotion
		_update_drag(motion.position)


func _hit_test(world_pos: Vector2) -> bool:
	var local: Vector2 = world_pos - global_position
	var padded_half: Vector2 = (TILE_SIZE / 2.0) + Vector2(HIT_PADDING, HIT_PADDING)
	return absf(local.x) < padded_half.x and absf(local.y) < padded_half.y


func _start_drag(screen_pos: Vector2) -> void:
	_dragging = true
	_drag_start = screen_pos
	_drag_start_pos = position
	_last_pos = screen_pos
	_drag_velocity = Vector2.ZERO


func _end_drag(screen_pos: Vector2) -> void:
	_dragging = false
	# Flick if any upward velocity, or tap (small movement)
	if _drag_velocity.y < FLICK_THRESHOLD or screen_pos.distance_to(_drag_start) < 30.0:
		flicked.emit(self)
	else:
		# Return to original position
		var tween: Tween = create_tween()
		tween.tween_property(self, "position", _drag_start_pos, 0.15)


func _update_drag(screen_pos: Vector2) -> void:
	_drag_velocity = screen_pos - _last_pos
	_last_pos = screen_pos

	var drag_offset: Vector2 = screen_pos - _drag_start
	position = _drag_start_pos + Vector2(0.0, clampf(drag_offset.y, -100.0, 30.0))


func _screen_to_world(screen_pos: Vector2) -> Vector2:
	var canvas_xform: Transform2D = get_canvas_transform()
	return canvas_xform.affine_inverse() * screen_pos
