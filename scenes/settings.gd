## Settings popup with SFX, Music, and Haptics toggles.
## Reads/writes settings directly to SaveManager.
extends BasePopup

@onready var sfx_toggle: CheckButton = %SFXToggle
@onready var music_toggle: CheckButton = %MusicToggle
@onready var haptics_toggle: CheckButton = %HapticsToggle
@onready var close_button: Button = %CloseButton
@onready var restore_button: Button = %RestoreButton


func _ready() -> void:
	AnalyticsManager.log_screen("settings")
	_load_settings()
	sfx_toggle.toggled.connect(_on_sfx_toggled)
	music_toggle.toggled.connect(_on_music_toggled)
	haptics_toggle.toggled.connect(_on_haptics_toggled)
	close_button.pressed.connect(_on_close)
	restore_button.pressed.connect(_on_restore_purchases)

	# Hide haptics toggle on non-mobile platforms
	if not Utils.is_mobile():
		haptics_toggle.get_parent().visible = false


func _load_settings() -> void:
	sfx_toggle.button_pressed = SaveManager.get_value("settings.sfx_enabled", true) as bool
	music_toggle.button_pressed = SaveManager.get_value("settings.music_enabled", true) as bool
	haptics_toggle.button_pressed = SaveManager.get_value("settings.haptics_enabled", true) as bool


func _on_sfx_toggled(enabled: bool) -> void:
	AudioManager.set_sfx_enabled(enabled)
	AnalyticsManager.log_event("button_clicked", {"button": "sfx_toggle", "value": enabled})


func _on_music_toggled(enabled: bool) -> void:
	AudioManager.set_music_enabled(enabled)
	AnalyticsManager.log_event("button_clicked", {"button": "music_toggle", "value": enabled})


func _on_haptics_toggled(enabled: bool) -> void:
	SaveManager.set_value("settings.haptics_enabled", enabled)
	AnalyticsManager.log_event("button_clicked", {"button": "haptics_toggle", "value": enabled})


func _on_close() -> void:
	AnalyticsManager.log_event("button_clicked", {"button": "settings_close"})
	dismiss()


func _on_restore_purchases() -> void:
	AnalyticsManager.log_event("button_clicked", {"button": "restore_purchases"})
	IAPManager.restore_purchases()
