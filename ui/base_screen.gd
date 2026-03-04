## Base class for all full-screen game screens.
## Auto-logs screen view analytics on enter.
class_name BaseScreen
extends Control


## Virtual — called when this screen enters the scene tree
func _on_screen_enter() -> void:
	pass


## Virtual — called when this screen is about to exit (during transitions)
func _on_screen_exit() -> void:
	pass


func _ready() -> void:
	var screen_name: String = scene_file_path.get_file().get_basename()
	AnalyticsManager.log_screen(screen_name)
	_on_screen_enter()
