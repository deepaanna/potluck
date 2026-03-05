## Flick-able ingredient tile. Drag to aim, release to fling toward the pot.
## Uses manual velocity + gravity, detected by PotVisual's Area2D on collision.
class_name IngredientTile
extends Node2D

signal entered_pot(tile: Node2D)
signal missed(tile: Node2D)
signal flicked(tile: Node2D)

enum State { IN_BAG, DRAWN, FLICKED, IN_POT }

@onready var _area: Area2D = $Area2D
@onready var _rect: ColorRect = $ColorRect
@onready var _label: Label = $ColorRect/Label

var ingredient_data: IngredientData
var state: State = State.IN_BAG

var _velocity: Vector2 = Vector2.ZERO
var _dragging: bool = false
var _drag_positions: PackedVector2Array = PackedVector2Array()
var _drag_times: PackedFloat64Array = PackedFloat64Array()
var _spawn_pos: Vector2 = Vector2.ZERO
var _flick_timer: float = 0.0
var _bob_tween: Tween = null

const GRAVITY: float = 1200.0
const MAX_FLICK_TIME: float = 2.5
const TILE_SIZE: float = 120.0
const DRAG_SAMPLE_COUNT: int = 6
const MIN_FLICK_SPEED: float = 200.0


func setup(data: IngredientData) -> void:
	ingredient_data = data


func _ready() -> void:
	visible = false
	set_physics_process(false)

	if ingredient_data == null:
		return

	_rect.color = ingredient_data.color
	_rect.size = Vector2(TILE_SIZE, TILE_SIZE)
	_rect.position = Vector2(-TILE_SIZE / 2.0, -TILE_SIZE / 2.0)

	# Make label fill the rect
	_label.position = Vector2.ZERO
	_label.size = Vector2(TILE_SIZE, TILE_SIZE)
	_label.add_theme_font_size_override("font_size", 36)

	# 3-letter abbreviation
	var abbrev: String = ingredient_data.display_name.substr(0, 3).to_upper()
	_label.text = abbrev

	# Text color: dark for light backgrounds, white for dark
	var lum: float = ingredient_data.color.r * 0.299 + ingredient_data.color.g * 0.587 + ingredient_data.color.b * 0.114
	_label.add_theme_color_override("font_color", Color.BLACK if lum > 0.5 else Color.WHITE)


func reveal(spawn_position: Vector2) -> void:
	state = State.DRAWN
	_spawn_pos = spawn_position
	position = spawn_position
	visible = true
	# NOTE: Do NOT set scale = Vector2.ZERO here.
	# pop_in reads current scale as target, then animates from zero to that.
	Juice.pop_in(self, 0.25)
	_start_idle_bob()
	queue_redraw()


func _draw() -> void:
	if state != State.DRAWN or _dragging:
		return
	# Draw downward arrow below tile — visual hint toward the pot
	var arrow_y: float = TILE_SIZE / 2.0 + 20.0
	var arrow_w: float = 14.0
	var arrow_h: float = 22.0
	var col: Color = Color(1.0, 0.9, 0.3, 0.7)
	# Stem
	draw_line(Vector2(0, TILE_SIZE / 2.0 + 6.0), Vector2(0, arrow_y), col, 3.0)
	# Triangle
	draw_colored_polygon(PackedVector2Array([
		Vector2(-arrow_w, arrow_y),
		Vector2(arrow_w, arrow_y),
		Vector2(0, arrow_y + arrow_h),
	]), col)


func _start_idle_bob() -> void:
	_stop_idle_bob()
	_bob_tween = create_tween().set_loops()
	_bob_tween.tween_property(self, "position:y", _spawn_pos.y - 8.0, 0.5) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_bob_tween.tween_property(self, "position:y", _spawn_pos.y + 8.0, 0.5) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _stop_idle_bob() -> void:
	if _bob_tween and _bob_tween.is_valid():
		_bob_tween.kill()
		_bob_tween = null


func _input(event: InputEvent) -> void:
	if state != State.DRAWN:
		return

	# Touch start
	if event is InputEventScreenTouch:
		var touch: InputEventScreenTouch = event as InputEventScreenTouch
		var world: Vector2 = _screen_to_world(touch.position)
		if touch.pressed:
			if _hit_test(world):
				_begin_drag(touch.position)
				get_viewport().set_input_as_handled()
		elif _dragging:
			_release_drag()
			get_viewport().set_input_as_handled()
		return

	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return
		if mb.pressed:
			if _hit_test(get_global_mouse_position()):
				_begin_drag(mb.position)
				get_viewport().set_input_as_handled()
		elif _dragging:
			_release_drag()
			get_viewport().set_input_as_handled()
		return

	# Drag motion
	if _dragging:
		if event is InputEventScreenDrag:
			_update_drag((event as InputEventScreenDrag).position)
		elif event is InputEventMouseMotion:
			if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
				_update_drag((event as InputEventMouseMotion).position)
			else:
				_release_drag()


func _physics_process(delta: float) -> void:
	if state != State.FLICKED:
		return

	_velocity.y += GRAVITY * delta
	position += _velocity * delta
	_flick_timer += delta

	# Rotate in flight direction slightly for juice
	rotation = _velocity.angle() * 0.15

	# Timeout or off-screen — return to spawn
	var vp_rect: Rect2 = Rect2(Vector2(-100, -100), Vector2(1280, 2120))
	if _flick_timer > MAX_FLICK_TIME or not vp_rect.has_point(position):
		_return_to_spawn()


func on_pot_entered() -> void:
	if state != State.FLICKED:
		return
	state = State.IN_POT
	set_physics_process(false)
	_stop_idle_bob()
	var tween: Tween = create_tween()
	tween.tween_property(self, "scale", Vector2.ZERO, 0.15) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	entered_pot.emit(self)


func _hit_test(world_pos: Vector2) -> bool:
	var local: Vector2 = world_pos - global_position
	var half: float = TILE_SIZE * 1.5  # Generous hit area
	return absf(local.x) < half and absf(local.y) < half


func _begin_drag(screen_pos: Vector2) -> void:
	_stop_idle_bob()
	_dragging = true
	rotation = 0.0
	_drag_positions.clear()
	_drag_times.clear()
	_record_drag(screen_pos)
	queue_redraw()


func _update_drag(screen_pos: Vector2) -> void:
	var prev_pos: Vector2 = _drag_positions[_drag_positions.size() - 1] if _drag_positions.size() > 0 else screen_pos
	_record_drag(screen_pos)
	position = _screen_to_world(screen_pos)
	var delta_x: float = screen_pos.x - prev_pos.x
	rotation = clampf(delta_x * 0.005, -0.3, 0.3)


func _record_drag(screen_pos: Vector2) -> void:
	_drag_positions.append(screen_pos)
	_drag_times.append(Time.get_ticks_msec() / 1000.0)
	while _drag_positions.size() > DRAG_SAMPLE_COUNT:
		_drag_positions.remove_at(0)
		_drag_times.remove_at(0)


func _release_drag() -> void:
	_dragging = false
	var vel: Vector2 = _compute_flick_velocity()

	# If velocity is too low, treat as a gentle nudge toward pot
	if vel.length() < MIN_FLICK_SPEED:
		vel = Vector2(0.0, 600.0)

	_velocity = vel
	state = State.FLICKED
	_flick_timer = 0.0
	set_physics_process(true)
	queue_redraw()
	flicked.emit(self)


func _compute_flick_velocity() -> Vector2:
	if _drag_positions.size() < 2:
		return Vector2.ZERO

	var oldest_pos: Vector2 = _drag_positions[0]
	var newest_pos: Vector2 = _drag_positions[_drag_positions.size() - 1]
	var oldest_time: float = _drag_times[0]
	var newest_time: float = _drag_times[_drag_times.size() - 1]
	var dt: float = newest_time - oldest_time

	if dt < 0.001:
		return Vector2.ZERO

	var screen_delta: Vector2 = newest_pos - oldest_pos
	var vel: Vector2 = screen_delta / dt

	if vel.length() > 3000.0:
		vel = vel.normalized() * 3000.0

	return vel


func _return_to_spawn() -> void:
	state = State.DRAWN
	set_physics_process(false)
	rotation = 0.0
	_velocity = Vector2.ZERO

	var tween: Tween = create_tween()
	tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.tween_property(self, "position", _spawn_pos, 0.3)
	tween.tween_callback(_start_idle_bob)

	queue_redraw()
	missed.emit(self)


func _screen_to_world(screen_pos: Vector2) -> Vector2:
	return get_canvas_transform().affine_inverse() * screen_pos
