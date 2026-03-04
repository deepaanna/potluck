## Rate Us popup with 3-stage flow:
## 1. "Are you having fun?" → YES / NO
## 2. YES → "Rate us!" → opens app store
## 3. NO → "Send feedback" → opens email
extends BasePopup

enum Stage { ASK_ENJOYING, RATE, FEEDBACK }

@onready var title_label: Label = %TitleLabel
@onready var message_label: Label = %MessageLabel
@onready var primary_button: Button = %PrimaryButton
@onready var secondary_button: Button = %SecondaryButton

var _current_stage: Stage = Stage.ASK_ENJOYING
var _config: GameConfig


func _ready() -> void:
	_config = GameManager.config
	AnalyticsManager.log_event("rate_us_shown")
	_show_stage(Stage.ASK_ENJOYING)


func _show_stage(stage: Stage) -> void:
	_current_stage = stage
	if primary_button.pressed.is_connected(_on_primary):
		primary_button.pressed.disconnect(_on_primary)
	if secondary_button.pressed.is_connected(_on_secondary):
		secondary_button.pressed.disconnect(_on_secondary)
	primary_button.pressed.connect(_on_primary)
	secondary_button.pressed.connect(_on_secondary)

	match stage:
		Stage.ASK_ENJOYING:
			title_label.text = "Are you having fun?"
			message_label.text = "We'd love to hear what you think!"
			primary_button.text = "Yes!"
			secondary_button.text = "Not really"
			primary_button.visible = true
			secondary_button.visible = true
		Stage.RATE:
			title_label.text = "Awesome!"
			message_label.text = "Would you mind leaving us a rating? It really helps!"
			primary_button.text = "Rate Us"
			secondary_button.text = "Maybe Later"
			primary_button.visible = true
			secondary_button.visible = true
		Stage.FEEDBACK:
			title_label.text = "We're sorry!"
			message_label.text = "Would you like to tell us how we can improve?"
			primary_button.text = "Send Feedback"
			secondary_button.text = "No Thanks"
			primary_button.visible = true
			secondary_button.visible = true


func _on_primary() -> void:
	match _current_stage:
		Stage.ASK_ENJOYING:
			AnalyticsManager.log_event("rate_us_enjoying_yes")
			_show_stage(Stage.RATE)
		Stage.RATE:
			AnalyticsManager.log_event("rate_us_rated")
			SaveManager.set_value("rate_us_completed", true)
			if _config.app_store_url != "":
				OS.shell_open(_config.app_store_url)
			else:
				push_warning("RateUs: app_store_url not configured in GameConfig")
			dismiss()
		Stage.FEEDBACK:
			AnalyticsManager.log_event("rate_us_feedback")
			SaveManager.set_value("rate_us_completed", true)
			var subject: String = "%s Feedback" % _config.game_name
			var mailto: String = "mailto:%s?subject=%s" % [_config.feedback_email, subject.uri_encode()]
			OS.shell_open(mailto)
			dismiss()


func _on_secondary() -> void:
	match _current_stage:
		Stage.ASK_ENJOYING:
			AnalyticsManager.log_event("rate_us_enjoying_no")
			_show_stage(Stage.FEEDBACK)
		Stage.RATE:
			AnalyticsManager.log_event("rate_us_later")
			dismiss()
		Stage.FEEDBACK:
			AnalyticsManager.log_event("rate_us_declined")
			SaveManager.set_value("rate_us_declined", true)
			dismiss()
