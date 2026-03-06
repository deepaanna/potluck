## Onboarding popup sequence for first-time players.
## Shows 4 sequential tutorial popups at key game moments.
extends Node

signal step_dismissed

const STEPS: Array[Dictionary] = [
	{"id": "flick", "icon": "👆", "title": "Flick to Cook!", "body": "Drag ingredients down into the pot to add them to your dish."},
	{"id": "heat", "icon": "🔥", "title": "Watch the Heat!", "body": "Each ingredient adds heat. Too much and your pot boils over!"},
	{"id": "serve", "icon": "🍽️", "title": "Serve Your Dish!", "body": "Tap Serve to bank your points safely — or keep cooking for more!"},
	{"id": "revive", "icon": "💖", "title": "Second Chance!", "body": "Boiled over? Watch a short ad to save your dish and keep cooking."},
]

var _current_step: int = -1  # -1 = not started / completed
var _popup_scene: PackedScene = preload("res://scenes/tutorial_popup.tscn")
var _showing: bool = false


func _ready() -> void:
	var completed: bool = SaveManager.get_value("pot_luck.onboarding_completed", false) as bool
	if completed:
		_current_step = -1
	else:
		_current_step = SaveManager.get_value("pot_luck.onboarding_step", 0) as int


func is_active() -> bool:
	return _current_step >= 0 and _current_step < STEPS.size()


func try_trigger(step_id: String) -> bool:
	if not is_active() or _showing:
		return false
	if STEPS[_current_step].id != step_id:
		return false
	_show_current_step()
	return true


func try_complete() -> void:
	if is_active():
		SaveManager.set_value("pot_luck.onboarding_completed", true)
		_current_step = -1


func _show_current_step() -> void:
	_showing = true
	var step: Dictionary = STEPS[_current_step]
	var popup: BasePopup = UIManager.show_popup(_popup_scene, step)
	popup.dismissed.connect(_on_step_dismissed.bind(step), CONNECT_ONE_SHOT)


func _on_step_dismissed(step: Dictionary) -> void:
	_showing = false
	AnalyticsManager.log_event("tutorial_step_completed", {
		"step": _current_step, "step_name": step.id
	})
	_current_step += 1
	SaveManager.set_value("pot_luck.onboarding_step", _current_step)
	if _current_step >= STEPS.size():
		SaveManager.set_value("pot_luck.onboarding_completed", true)
		_current_step = -1
	step_dismissed.emit()
