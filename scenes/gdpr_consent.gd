## GDPR/privacy consent popup shown on first launch.
## Saves consent status to SaveManager.
extends BasePopup

signal consent_given(accepted: bool)

@onready var accept_button: Button = %AcceptButton
@onready var decline_button: Button = %DeclineButton


func _ready() -> void:
	AnalyticsManager.log_screen("gdpr_consent")
	accept_button.pressed.connect(_on_accept)
	decline_button.pressed.connect(_on_decline)


func _on_accept() -> void:
	SaveManager.set_value("gdpr_consent", true)
	SaveManager.set_value("gdpr_answered", true)
	AnalyticsManager.log_event("gdpr_consent_given")
	consent_given.emit(true)
	dismiss()


func _on_decline() -> void:
	SaveManager.set_value("gdpr_consent", false)
	SaveManager.set_value("gdpr_answered", true)
	AnalyticsManager.log_event("gdpr_consent_declined")
	consent_given.emit(false)
	dismiss()
