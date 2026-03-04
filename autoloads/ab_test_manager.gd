## A/B test configuration manager with key-value defaults.
## Stub implementation — replace with Firebase Remote Config for production.
extends Node

signal config_fetched
signal config_activated

var _config: Dictionary = {}
var _defaults: Dictionary = {}
var _fetched_config: Dictionary = {}
var _is_fetched: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_cached_config()


## Set default values for A/B test parameters
func set_defaults(defaults: Dictionary) -> void:
	_defaults = defaults.duplicate(true)
	for key: String in _defaults:
		if not _config.has(key):
			_config[key] = _defaults[key]


## Get a string config value
func get_string(key: String, default: String = "") -> String:
	return str(_config.get(key, _defaults.get(key, default)))


## Get an int config value
func get_int(key: String, default: int = 0) -> int:
	return int(_config.get(key, _defaults.get(key, default)))


## Get a float config value
func get_float(key: String, default: float = 0.0) -> float:
	return float(_config.get(key, _defaults.get(key, default)))


## Get a bool config value
func get_bool(key: String, default: bool = false) -> bool:
	var value: Variant = _config.get(key, _defaults.get(key, default))
	if value is bool:
		return value
	return str(value).to_lower() == "true"


## Fetch remote config from server
func fetch() -> void:
	## INTEGRATION POINT: Fetch from Firebase Remote Config here
	## Firebase.RemoteConfig.fetch()
	if OS.is_debug_build():
		print("[ABTestManager] Config fetched (stub)")

	# Simulate fetch completion
	_fetched_config = _defaults.duplicate(true)
	_is_fetched = true
	config_fetched.emit()


## Activate fetched config values
func activate() -> void:
	if not _is_fetched:
		push_warning("ABTestManager: No fetched config to activate")
		return

	_config.merge(_fetched_config, true)
	_cache_config()

	## INTEGRATION POINT: Activate Firebase Remote Config here
	## Firebase.RemoteConfig.activate()
	if OS.is_debug_build():
		print("[ABTestManager] Config activated (stub): %s" % str(_config))

	config_activated.emit()


## Fetch and activate in one call
func fetch_and_activate() -> void:
	## INTEGRATION POINT: Use Firebase fetch_and_activate here
	fetch()
	# Wait a frame to simulate async
	await get_tree().process_frame
	activate()


func _load_cached_config() -> void:
	var cached: Variant = SaveManager.get_value("ab_config", {})
	if cached is Dictionary:
		_config = (cached as Dictionary).duplicate(true)


func _cache_config() -> void:
	SaveManager.set_value("ab_config", _config.duplicate(true))
