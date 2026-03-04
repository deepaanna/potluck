## Popup shown on boilover offering a rewarded ad to continue.
extends BasePopup

signal second_chance_accepted
signal second_chance_declined

@onready var _title_label: Label = %TitleLabel
@onready var _message_label: Label = %MessageLabel
@onready var _watch_ad_button: Button = %WatchAdButton
@onready var _decline_button: Button = %DeclineButton


func _ready() -> void:
	_watch_ad_button.pressed.connect(_on_watch_ad)
	_decline_button.pressed.connect(_on_decline)

	_title_label.text = "BOILOVER!"
	_message_label.text = "Your pot boiled over!\nWatch an ad to cool it down and keep cooking?"

	if not AdManager.is_rewarded_ready():
		_watch_ad_button.text = "No Ad Available"
		_watch_ad_button.disabled = true


func _on_watch_ad() -> void:
	_watch_ad_button.disabled = true
	AdManager.rewarded_ad_completed.connect(_on_reward_received, CONNECT_ONE_SHOT)
	var shown: bool = AdManager.show_rewarded("second_chance", 1)
	if not shown:
		_watch_ad_button.text = "Ad Failed"
		_on_decline()


func _on_reward_received(_type: String, _amount: int) -> void:
	AnalyticsManager.log_event("second_chance_used")
	second_chance_accepted.emit()
	dismiss()


func _on_decline() -> void:
	AnalyticsManager.log_event("second_chance_declined")
	second_chance_declined.emit()
	dismiss()
