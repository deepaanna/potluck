## Ingredient tile visual with flick/tap input handling.
## Spawns at bottom, flicks upward to the pot.
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

const FLICK_THRESHOLD: float = -20.0  # Negative Y = upward (very low threshold)
const TILE_SIZE: Vector2 = Vector2(280, 160)


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

	if event is InputEventScreenTouch or event is InputEventMouseButton:
		var pressed: bool = false
		var event_pos: Vector2 = Vector2.ZERO

		if event is InputEventScreenTouch:
			pressed = (event as InputEventScreenTouch).pressed
			event_pos = (event as InputEventScreenTouch).position
		elif event is InputEventMouseButton:
			var mb: InputEventMouseButton = event as InputEventMouseButton
			if mb.button_index == MOUSE_BUTTON_LEFT:
				pressed = mb.pressed
				event_pos = mb.position

		# Convert to local space for hit test
		var local: Vector2 = to_local(get_global_mouse_position()) if event is InputEventMouseButton else to_local(_get_global_from_screen(event_pos))
		var hit_rect: Rect2 = Rect2(-TILE_SIZE / 2.0, TILE_SIZE)

		if pressed and hit_rect.has_point(local):
			_dragging = true
			_drag_start = event_pos
			_drag_start_pos = position
			_last_pos = event_pos
			_drag_velocity = Vector2.ZERO
		elif not pressed and _dragging:
			_dragging = false
			# Check for flick (any upward velocity) or tap
			if _drag_velocity.y < FLICK_THRESHOLD or event_pos.distance_to(_drag_start) < 20.0:
				flicked.emit(self)

	if event is InputEventScreenDrag or event is InputEventMouseMotion:
		if not _dragging:
			return
		var event_pos: Vector2 = Vector2.ZERO
		if event is InputEventScreenDrag:
			event_pos = (event as InputEventScreenDrag).position
		elif event is InputEventMouseMotion:
			if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
				_dragging = false
				return
			event_pos = (event as InputEventMouseMotion).position

		_drag_velocity = event_pos - _last_pos
		_last_pos = event_pos

		# Allow slight vertical drag movement for feedback
		var drag_offset: Vector2 = event_pos - _drag_start
		position = _drag_start_pos + Vector2(0.0, clampf(drag_offset.y, -80.0, 20.0))


func _get_global_from_screen(screen_pos: Vector2) -> Vector2:
	var canvas_transform: Transform2D = get_canvas_transform()
	return canvas_transform.affine_inverse() * screen_pos
