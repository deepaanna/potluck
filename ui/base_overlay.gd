## Base class for all overlay/HUD elements.
## Full-screen Control with mouse passthrough — clicks go to scene below.
class_name BaseOverlay
extends Control

var _overlay_name: String = ""


## Dismiss this overlay through UIManager
func dismiss() -> void:
	UIManager.dismiss_overlay(_overlay_name)


## Virtual — called when the overlay is added to the overlay layer
func _on_overlay_shown() -> void:
	pass


## Virtual — called when the overlay is about to be removed
func _on_overlay_hidden() -> void:
	pass
