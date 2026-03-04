## Analytics event tracking with structured events and session management.
## Logs all events to console in debug; replace with Firebase SDK for production.
extends Node

signal event_logged(event_name: String, params: Dictionary)

const SESSION_TIMEOUT: float = 300.0  # 5 minutes

var _session_id: String = ""
var _session_start_time: int = 0
var _event_count: int = 0
var _session_timer: Timer

## INTEGRATION POINT: Replace these lists with your actual event/param names
var _valid_events: PackedStringArray = [
	"session_start", "session_end",
	"level_start", "level_complete", "level_fail",
	"ad_requested", "ad_shown", "ad_clicked", "ad_rewarded",
	"iap_initiated", "iap_completed", "iap_failed",
	"button_clicked", "screen_viewed",
	"gdpr_consent_given", "gdpr_consent_declined",
	"ingredient_drawn", "stop_decision", "boilover",
	"combo_triggered", "second_chance_used", "second_chance_declined",
	"dish_served", "cuisine_selected",
]

var _required_params: Dictionary = {
	"level_start": ["level"],
	"level_complete": ["level", "score"],
	"level_fail": ["level", "score"],
	"ad_shown": ["ad_type"],
	"iap_completed": ["product_id"],
	"ingredient_drawn": ["ingredient_id"],
	"combo_triggered": ["combo_name", "multiplier"],
	"dish_served": ["final_score", "ingredients_count"],
}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_start_session()
	_setup_session_timer()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED:
		log_event("session_end", {"duration": Time.get_unix_time_from_system() - _session_start_time})
	elif what == NOTIFICATION_APPLICATION_RESUMED:
		_start_session()
	elif what == NOTIFICATION_WM_CLOSE_REQUEST:
		log_event("session_end", {"duration": Time.get_unix_time_from_system() - _session_start_time})


## Log an analytics event with optional parameters.
## Respects GDPR consent — only logs if consent was given.
func log_event(event_name: String, params: Dictionary = {}) -> void:
	if not _has_consent():
		return
	if not _validate_event(event_name, params):
		return

	var enriched_params: Dictionary = params.duplicate()
	_event_count += 1
	enriched_params["session_id"] = _session_id
	enriched_params["event_index"] = _event_count
	enriched_params["timestamp"] = Time.get_unix_time_from_system()

	## INTEGRATION POINT: Send to Firebase Analytics here
	## Firebase.Analytics.log_event(event_name, params)
	if OS.is_debug_build():
		print("[Analytics] %s: %s" % [event_name, str(enriched_params)])

	event_logged.emit(event_name, enriched_params)


## Log a screen view event
func log_screen(screen_name: String) -> void:
	log_event("screen_viewed", {"screen": screen_name})


## Set a user property for analytics segmentation
func set_user_property(property: String, value: Variant) -> void:
	if not _has_consent():
		return
	## INTEGRATION POINT: Set Firebase user property here
	## Firebase.Analytics.set_user_property(property, str(value))
	if OS.is_debug_build():
		print("[Analytics] User property: %s = %s" % [property, str(value)])


func _start_session() -> void:
	_session_id = _generate_session_id()
	_session_start_time = Time.get_unix_time_from_system() as int
	_event_count = 0

	SaveManager.set_value("stats.last_play_time", _session_start_time)
	var first_play: int = SaveManager.get_value("stats.first_play_time", 0) as int
	if first_play == 0:
		SaveManager.set_value("stats.first_play_time", _session_start_time)

	log_event("session_start", {
		"first_play": first_play == 0,
	})


func _setup_session_timer() -> void:
	_session_timer = Timer.new()
	_session_timer.wait_time = 60.0
	_session_timer.autostart = true
	_session_timer.timeout.connect(_on_session_tick)
	add_child(_session_timer)


func _on_session_tick() -> void:
	var total_play_time: float = SaveManager.get_value("stats.total_play_time", 0.0) as float
	SaveManager.set_value("stats.total_play_time", total_play_time + 60.0)


func _validate_event(event_name: String, params: Dictionary) -> bool:
	if event_name not in _valid_events:
		push_warning("AnalyticsManager: Unknown event '%s'" % event_name)
		return true  # Still log it, just warn

	if event_name in _required_params:
		var required: Array = _required_params[event_name] as Array
		for param_name: String in required:
			if param_name not in params:
				push_warning("AnalyticsManager: Event '%s' missing required param '%s'" % [event_name, param_name])
				return true  # Still log it, just warn
	return true


func _has_consent() -> bool:
	return SaveManager.get_value("gdpr_consent", false) as bool


func _generate_session_id() -> String:
	var time_part: String = str(Time.get_unix_time_from_system()).sha256_text().substr(0, 8)
	var rand_part: String = str(randi()).sha256_text().substr(0, 8)
	return "%s-%s" % [time_part, rand_part]
