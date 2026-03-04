## MarginContainer that auto-applies display safe area insets.
## Accounts for notches, punch-holes, status bars, and home indicators.
## Converts screen-pixel insets to viewport coordinates using the uniform scale factor.
class_name SafeAreaMargin
extends MarginContainer


func _ready() -> void:
	_apply_margins()
	get_tree().root.size_changed.connect(_apply_margins)


func _apply_margins() -> void:
	var safe_area: Rect2i = DisplayServer.get_display_safe_area()
	var window_size: Vector2i = DisplayServer.window_get_size()

	if window_size.x <= 0 or window_size.y <= 0:
		return

	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var scale: float = viewport_size.x / float(window_size.x)

	# Safe area is in screen coordinates — offset by window position
	var window_pos: Vector2i = DisplayServer.window_get_position()
	var window_end: Vector2i = window_pos + window_size

	var left: int = maxi(0, int(float(safe_area.position.x - window_pos.x) * scale))
	var top: int = maxi(0, int(float(safe_area.position.y - window_pos.y) * scale))
	var right: int = maxi(0, int(float(window_end.x - safe_area.end.x) * scale))
	var bottom: int = maxi(0, int(float(window_end.y - safe_area.end.y) * scale))

	add_theme_constant_override("margin_left", left)
	add_theme_constant_override("margin_top", top)
	add_theme_constant_override("margin_right", right)
	add_theme_constant_override("margin_bottom", bottom)
