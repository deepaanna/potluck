## Camera screen shake utility.
## Call ScreenShake.shake() with any Camera2D to create juicy impact effects.
class_name ScreenShake
extends RefCounted

## Shake a Camera2D with the given intensity and duration
static func shake(camera: Camera2D, intensity: float = 10.0, duration: float = 0.3) -> void:
	if not is_instance_valid(camera):
		push_warning("ScreenShake: Invalid camera reference")
		return

	var original_offset: Vector2 = camera.offset
	var tween: Tween = camera.create_tween()
	var steps: int = ceili(duration / 0.05)

	for i: int in range(steps):
		var shake_offset: Vector2 = Vector2(
			randf_range(-intensity, intensity),
			randf_range(-intensity, intensity)
		)
		var step_intensity: float = intensity * (1.0 - (float(i) / float(steps)))
		shake_offset = shake_offset.normalized() * step_intensity
		tween.tween_property(camera, "offset", original_offset + shake_offset, 0.05)

	tween.tween_property(camera, "offset", original_offset, 0.05)
