## Popup shown on boilover offering a rewarded ad to continue.
## Has a 3-second countdown and urgent visual treatment.
extends BasePopup

signal second_chance_accepted
signal second_chance_declined

@onready var _title_label: Label = %TitleLabel
@onready var _score_lost_label: Label = %ScoreLostLabel
@onready var _countdown_label: Label = %CountdownLabel
@onready var _save_button: Button = %SaveButton
@onready var _give_up_button: Button = %GiveUpButton

var _countdown: float = 3.0
var _resolved: bool = false
var _pulse_tween: Tween = null


func _ready() -> void:
	_save_button.pressed.connect(_on_save_pressed)
	_give_up_button.pressed.connect(_on_give_up)

	_title_label.text = "YOUR POT BOILED OVER!"

	var lost_score: int = _popup_data.get("score", 0) as int
	if lost_score > 0:
		_score_lost_label.text = "You lost %s points!" % Utils.format_number(lost_score)
	else:
		_score_lost_label.text = "Your dish is ruined!"

	_countdown_label.text = "Watch an ad to save your dish! 3..."

	if not AdManager.is_rewarded_ready():
		_save_button.text = "No Ad Available"
		_save_button.disabled = true
	else:
		_start_button_pulse()

	set_process(true)


func _process(delta: float) -> void:
	if _resolved:
		return

	_countdown -= delta
	var secs: int = ceili(_countdown)

	if secs > 0:
		_countdown_label.text = "Watch an ad to save your dish! %d..." % secs
	else:
		_resolved = true
		set_process(false)
		_decline_and_dismiss()


func _on_save_pressed() -> void:
	if _resolved:
		return
	_resolved = true
	set_process(false)
	_save_button.disabled = true
	_save_button.text = "Loading Ad..."
	_stop_button_pulse()

	AdManager.rewarded_ad_completed.connect(_on_reward_received, CONNECT_ONE_SHOT)
	var shown: bool = AdManager.show_rewarded("second_chance", 1)
	if not shown:
		_save_button.text = "Ad Failed"
		if AdManager.rewarded_ad_completed.is_connected(_on_reward_received):
			AdManager.rewarded_ad_completed.disconnect(_on_reward_received)
		get_tree().create_timer(0.5).timeout.connect(_decline_and_dismiss)


func _on_reward_received(_type: String, _amount: int) -> void:
	AnalyticsManager.log_event("second_chance_used")
	_stop_button_pulse()
	second_chance_accepted.emit()
	dismiss()


func _on_give_up() -> void:
	if _resolved:
		return
	_resolved = true
	set_process(false)
	_decline_and_dismiss()


func _decline_and_dismiss() -> void:
	_stop_button_pulse()
	AnalyticsManager.log_event("second_chance_declined")
	second_chance_declined.emit()
	dismiss()


func _start_button_pulse() -> void:
	if _pulse_tween and _pulse_tween.is_valid():
		return
	_pulse_tween = _save_button.create_tween().set_loops()
	_pulse_tween.tween_property(_save_button, "modulate", Color(1.3, 1.0, 0.8), 0.3)
	_pulse_tween.tween_property(_save_button, "modulate", Color.WHITE, 0.3)


func _stop_button_pulse() -> void:
	if _pulse_tween and _pulse_tween.is_valid():
		_pulse_tween.kill()
		_pulse_tween = null
	if is_instance_valid(_save_button):
		_save_button.modulate = Color.WHITE
