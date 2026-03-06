## Onboarding tutorial popup — shows icon, title, body, and "Got it!" button.
extends BasePopup

@onready var _icon_label: Label = %IconLabel
@onready var _title_label: Label = %TitleLabel
@onready var _body_label: Label = %BodyLabel
@onready var _got_it_button: Button = %GotItButton


func _ready() -> void:
	_icon_label.text = _popup_data.get("icon", "") as String
	_title_label.text = _popup_data.get("title", "") as String
	_body_label.text = _popup_data.get("body", "") as String
	_got_it_button.pressed.connect(dismiss)
