## General utility functions for mobile game development.
## Provides number formatting, time formatting, vibration, and platform detection.
class_name Utils
extends RefCounted

## Format a large number with K/M/B suffixes (e.g., 1500 → "1.5K")
static func format_number(value: int) -> String:
	if value >= 1_000_000_000:
		return "%.1fB" % (value / 1_000_000_000.0)
	elif value >= 1_000_000:
		return "%.1fM" % (value / 1_000_000.0)
	elif value >= 1_000:
		return "%.1fK" % (value / 1_000.0)
	return str(value)


## Format seconds into MM:SS or HH:MM:SS
static func format_time(seconds: float) -> String:
	var total_seconds: int = int(seconds)
	@warning_ignore("integer_division")
	var hours: int = total_seconds / 3600
	@warning_ignore("integer_division")
	var minutes: int = (total_seconds % 3600) / 60
	var secs: int = total_seconds % 60

	if hours > 0:
		return "%d:%02d:%02d" % [hours, minutes, secs]
	return "%d:%02d" % [minutes, secs]


## Trigger device vibration if haptics are enabled
static func vibrate(duration_ms: int = 50) -> void:
	if not is_mobile():
		return
	var haptics_enabled: bool = SaveManager.get_value("settings.haptics_enabled", true) as bool
	if not haptics_enabled:
		return
	Input.vibrate_handheld(duration_ms)


## Check if running on a mobile platform
static func is_mobile() -> bool:
	return OS.get_name() in ["Android", "iOS"]


## Get the safe area rect accounting for notches and system UI
static func safe_area() -> Rect2i:
	return DisplayServer.get_display_safe_area()


## Get safe area margins in viewport coordinates as a Dictionary.
## Returns {"left": int, "top": int, "right": int, "bottom": int}.
## Uses ProjectSettings viewport width for scale (safe for static context).
static func get_safe_margins() -> Dictionary:
	var safe_area_rect: Rect2i = DisplayServer.get_display_safe_area()
	var window_size: Vector2i = DisplayServer.window_get_size()

	if window_size.x <= 0 or window_size.y <= 0:
		return {"left": 0, "top": 0, "right": 0, "bottom": 0}

	var viewport_width: int = ProjectSettings.get_setting("display/window/size/viewport_width") as int
	var scale: float = float(viewport_width) / float(window_size.x)

	# Safe area is in screen coordinates — offset by window position
	var window_pos: Vector2i = DisplayServer.window_get_position()
	var window_end: Vector2i = window_pos + window_size

	return {
		"left": maxi(0, int(float(safe_area_rect.position.x - window_pos.x) * scale)),
		"top": maxi(0, int(float(safe_area_rect.position.y - window_pos.y) * scale)),
		"right": maxi(0, int(float(window_end.x - safe_area_rect.end.x) * scale)),
		"bottom": maxi(0, int(float(window_end.y - safe_area_rect.end.y) * scale)),
	}


## Remap a value from one range to another
static func remap_value(value: float, from_min: float, from_max: float, to_min: float, to_max: float) -> float:
	return to_min + (value - from_min) * (to_max - to_min) / (from_max - from_min)


## Clamp and remap a value (safe version that clamps input to source range)
static func remap_clamped(value: float, from_min: float, from_max: float, to_min: float, to_max: float) -> float:
	var clamped: float = clampf(value, from_min, from_max)
	return remap_value(clamped, from_min, from_max, to_min, to_max)
