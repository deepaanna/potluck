## Floating combo name + multiplier text that animates up and fades out.
extends Node2D

@onready var _name_label: Label = $NameLabel
@onready var _multiplier_label: Label = $MultiplierLabel


func setup(combo: ComboData) -> void:
	if _name_label == null:
		await ready

	_name_label.text = combo.combo_name
	_multiplier_label.text = "x%.1f" % combo.multiplier

	if combo.is_penalty:
		_name_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.2))
		_multiplier_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.2))
	else:
		_name_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.2))
		_multiplier_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.1))


func animate() -> void:
	scale = Vector2.ZERO
	modulate.a = 1.0

	var tween: Tween = create_tween()
	# Pop in
	tween.tween_property(self, "scale", Vector2(1.2, 1.2), 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", Vector2.ONE, 0.1)
	# Float up and fade
	tween.tween_property(self, "position:y", position.y - 120.0, 1.0).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tween.parallel().tween_property(self, "modulate:a", 0.0, 0.8).set_delay(0.5)
	tween.tween_callback(queue_free)
