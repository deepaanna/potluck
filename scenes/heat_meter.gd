## Vertical heat bar with color stages.
extends Control

@onready var _background: ColorRect = $Background
@onready var _fill: ColorRect = $Fill
@onready var _label: Label = $StageLabel

const STAGE_COLORS: Array[Color] = [
	Color(0.3, 0.7, 0.3),    # Cool - green
	Color(0.7, 0.7, 0.2),    # Warm - yellow
	Color(0.9, 0.5, 0.1),    # Hot - orange
	Color(0.9, 0.2, 0.1),    # Bubbling - red-orange
	Color(1.0, 0.05, 0.05),  # Danger - bright red
]

const STAGE_NAMES: PackedStringArray = [
	"COOL", "WARM", "HOT", "BUBBLING", "DANGER"
]

var _bar_height: float = 400.0


func _ready() -> void:
	_bar_height = _background.size.y
	_fill.size.y = 0.0
	_fill.position.y = _bar_height
	update_heat(0.0, 0)


func update_heat(heat_ratio: float, stage: int) -> void:
	var clamped: float = clampf(heat_ratio, 0.0, 1.0)
	var fill_height: float = _bar_height * clamped

	var tween: Tween = create_tween()
	tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(_fill, "size:y", fill_height, 0.3)
	tween.parallel().tween_property(_fill, "position:y", _bar_height - fill_height, 0.3)

	var color_idx: int = clampi(stage, 0, STAGE_COLORS.size() - 1)
	tween.parallel().tween_property(_fill, "color", STAGE_COLORS[color_idx], 0.3)

	_label.text = STAGE_NAMES[clampi(stage, 0, STAGE_NAMES.size() - 1)]

	if stage >= 4:
		Juice.pulse(self, 1.1, 0.2)
