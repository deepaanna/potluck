## Visual juice effects for CanvasItem nodes.
## Provides squash & stretch, flash, pulse, and pop-in animations.
class_name Juice
extends RefCounted

## Squash and stretch effect — great for landings and impacts
static func squash_stretch(node: CanvasItem, squash_amount: float = 0.3, duration: float = 0.2) -> Tween:
	if not is_instance_valid(node):
		return null

	_kill_tweens(node, "scale")
	var original_scale: Vector2 = node.scale
	var tween: Tween = node.create_tween()

	# Squash
	tween.tween_property(node, "scale", Vector2(
		original_scale.x * (1.0 + squash_amount),
		original_scale.y * (1.0 - squash_amount)
	), duration * 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)

	# Stretch
	tween.tween_property(node, "scale", Vector2(
		original_scale.x * (1.0 - squash_amount * 0.5),
		original_scale.y * (1.0 + squash_amount * 0.5)
	), duration * 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)

	# Return to original
	tween.tween_property(node, "scale", original_scale, duration * 0.4).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_ELASTIC)

	_track_tween(node, "scale", tween)
	return tween


## Flash the node's modulate color
static func flash(node: CanvasItem, color: Color = Color.WHITE, duration: float = 0.15) -> Tween:
	if not is_instance_valid(node):
		return null

	_kill_tweens(node, "modulate")
	var original_modulate: Color = node.modulate
	var tween: Tween = node.create_tween()

	tween.tween_property(node, "modulate", color, duration * 0.3)
	tween.tween_property(node, "modulate", original_modulate, duration * 0.7)

	_track_tween(node, "modulate", tween)
	return tween


## Pulse the node's scale up and back
static func pulse(node: CanvasItem, scale_factor: float = 1.2, duration: float = 0.3) -> Tween:
	if not is_instance_valid(node):
		return null

	_kill_tweens(node, "scale")
	var original_scale: Vector2 = node.scale
	var tween: Tween = node.create_tween()

	tween.tween_property(node, "scale", original_scale * scale_factor, duration * 0.4).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(node, "scale", original_scale, duration * 0.6).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_ELASTIC)

	_track_tween(node, "scale", tween)
	return tween


## Pop-in animation from zero scale with overshoot
static func pop_in(node: CanvasItem, duration: float = 0.4, delay: float = 0.0) -> Tween:
	if not is_instance_valid(node):
		return null

	_kill_tweens(node, "scale")
	var target_scale: Vector2 = node.scale
	node.scale = Vector2.ZERO
	var tween: Tween = node.create_tween()

	if delay > 0.0:
		tween.tween_interval(delay)

	tween.tween_property(node, "scale", target_scale, duration).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

	_track_tween(node, "scale", tween)
	return tween


## Animate a Label's text counting from one number to another
static func count_up(label: Label, from: int, to: int, duration: float = 0.6, delay: float = 0.0) -> Tween:
	if not is_instance_valid(label):
		return null

	var tween: Tween = label.create_tween()
	if delay > 0.0:
		tween.tween_interval(delay)

	var value_dict: Dictionary = {"v": float(from)}
	label.text = Utils.format_number(from)
	tween.tween_method(func(val: float) -> void:
		value_dict["v"] = val
		label.text = Utils.format_number(int(val))
	, float(from), float(to), duration).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)

	return tween


## Scale from large to normal with overshoot — dramatic reveal
static func slam_in(node: CanvasItem, duration: float = 0.3, delay: float = 0.0) -> Tween:
	if not is_instance_valid(node):
		return null

	_kill_tweens(node, "scale")
	var target_scale: Vector2 = node.scale
	node.scale = target_scale * 2.5
	var tween: Tween = node.create_tween()

	if delay > 0.0:
		tween.tween_interval(delay)

	tween.tween_property(node, "scale", target_scale, duration).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

	_track_tween(node, "scale", tween)
	return tween


## Button press glow — scale bump + color flash for tactile feedback
static func button_press_glow(button: Button, glow_color: Color = Color(1, 1, 1, 0.3)) -> Tween:
	if not is_instance_valid(button):
		return null

	_kill_tweens(button, "scale")
	_kill_tweens(button, "modulate")
	var original_scale: Vector2 = button.scale
	var original_modulate: Color = button.modulate

	# Scale tween: bump up then back
	var scale_tween: Tween = button.create_tween()
	scale_tween.tween_property(button, "scale", original_scale * 1.08, 0.08).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	scale_tween.tween_property(button, "scale", original_scale, 0.15).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	_track_tween(button, "scale", scale_tween)

	# Color tween: flash then restore
	var color_tween: Tween = button.create_tween()
	color_tween.tween_property(button, "modulate", glow_color.lightened(0.3), 0.06).set_ease(Tween.EASE_OUT)
	color_tween.tween_property(button, "modulate", original_modulate, 0.15).set_ease(Tween.EASE_OUT)
	_track_tween(button, "modulate", color_tween)

	return scale_tween


## Kill any previous juice tween on this node+property via metadata tracking
static func _kill_tweens(node: CanvasItem, property: String) -> void:
	var meta_key: String = "_juice_tween_%s" % property
	if node.has_meta(meta_key):
		var old_tween: Tween = node.get_meta(meta_key) as Tween
		if is_instance_valid(old_tween) and old_tween.is_valid():
			old_tween.kill()


static func _track_tween(node: CanvasItem, property: String, tween: Tween) -> void:
	var meta_key: String = "_juice_tween_%s" % property
	node.set_meta(meta_key, tween)
