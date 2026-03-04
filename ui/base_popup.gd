## Base class for all popup dialogs.
## Provides dim overlay, animated panel entrance, and dismiss functionality.
## Expects nodes: %DimOverlay (ColorRect) and %Panel (PanelContainer).
class_name BasePopup
extends Control

signal dismissed

@onready var _dim_overlay: ColorRect = %DimOverlay
@onready var _panel: PanelContainer = %Panel

var _popup_data: Dictionary = {}
var _current_tween: Tween


## Animate the popup in — dim overlay fades in, panel scales with overshoot
func animate_in() -> void:
	if _current_tween and _current_tween.is_valid():
		_current_tween.kill()

	_dim_overlay.modulate.a = 0.0
	_panel.scale = Vector2(0.8, 0.8)
	_panel.pivot_offset = _panel.size / 2.0

	_current_tween = create_tween().set_parallel(true)
	_current_tween.tween_property(_dim_overlay, "modulate:a", 1.0, 0.2)
	_current_tween.tween_property(_panel, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK)
	await _current_tween.finished


## Animate the popup out — reverse of animate_in
func animate_out() -> void:
	if _current_tween and _current_tween.is_valid():
		_current_tween.kill()

	_current_tween = create_tween().set_parallel(true)
	_current_tween.tween_property(_dim_overlay, "modulate:a", 0.0, 0.2)
	_current_tween.tween_property(_panel, "scale", Vector2(0.8, 0.8), 0.15)
	await _current_tween.finished


## Dismiss this popup through UIManager
func dismiss() -> void:
	UIManager.dismiss_popup(self)


## Virtual — called after popup is added to tree and animated in
func _on_popup_opened() -> void:
	pass
