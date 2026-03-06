## Popup shown on new high score — offers Rate, Share, or Cancel.
extends BasePopup

@onready var _title_label: Label = %TitleLabel
@onready var _score_label: Label = %ScoreLabel
@onready var _rate_button: Button = %RateButton
@onready var _share_button: Button = %ShareButton
@onready var _cancel_button: Button = %CancelButton

var _score: int = 0


func _ready() -> void:
	_score = _popup_data.get("score", 0) as int
	_title_label.text = "New High Score!"
	_score_label.text = Utils.format_number(_score)
	_rate_button.pressed.connect(_on_rate)
	_share_button.pressed.connect(_on_share)
	_cancel_button.pressed.connect(dismiss)


func _on_rate() -> void:
	AnalyticsManager.log_event("high_score_rate_tapped", {"score": _score})
	var url: String = GameManager.config.app_store_url
	if url == "":
		url = "market://details?id=your.package"
	OS.shell_open(url)
	SaveManager.set_value("rate_us_completed", true)
	dismiss()


func _on_share() -> void:
	AnalyticsManager.log_event("high_score_share_tapped", {"score": _score})
	var image: Image = get_viewport().get_texture().get_image()
	var path: String = OS.get_user_data_dir() + "/high_score.png"
	image.save_png(path)

	var text: String = "I just scored %s in Pot Luck! Beat my PB!" % Utils.format_number(_score)
	var platform: String = OS.get_name()
	if platform == "Android":
		# INTEGRATION POINT: Use a share plugin for native Android share sheet
		OS.shell_open("https://twitter.com/intent/tweet?text=%s" % text.uri_encode())
	elif platform == "iOS":
		# INTEGRATION POINT: Use a share plugin for native iOS share sheet
		OS.shell_open("https://twitter.com/intent/tweet?text=%s" % text.uri_encode())
	else:
		DisplayServer.clipboard_set(text)
	dismiss()
