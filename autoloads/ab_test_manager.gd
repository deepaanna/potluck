## A/B test configuration manager backed by Firebase Remote Config.
## Falls back to local defaults when Firebase is unavailable.
extends Node

signal config_fetched
signal config_activated

var _config: Dictionary = {}
var _defaults: Dictionary = {}
var _fetched_config: Dictionary = {}
var _is_fetched: bool = false
var _firebase_available: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_firebase_available = _detect_firebase()
	_load_cached_config()

	set_defaults({
		"boil_threshold": 1.0,
	})

	config_activated.connect(_apply_remote_values)
	fetch_and_activate()


## Set default values for A/B test parameters
func set_defaults(defaults: Dictionary) -> void:
	_defaults.merge(defaults, true)
	for key: String in defaults:
		if not _config.has(key):
			_config[key] = defaults[key]

	if _firebase_available:
		Firebase.RemoteConfig.set_defaults(defaults)


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
	if _firebase_available:
		Firebase.RemoteConfig.fetch()
		await Firebase.RemoteConfig.fetch_completed
		_fetched_config = {}
		for key: String in _defaults:
			_fetched_config[key] = Firebase.RemoteConfig.get_value(key)
	else:
		if OS.is_debug_build():
			print("[ABTestManager] Config fetched (stub — Firebase not available)")
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

	if _firebase_available:
		Firebase.RemoteConfig.activate()
	elif OS.is_debug_build():
		print("[ABTestManager] Config activated: %s" % str(_config))

	config_activated.emit()


## Fetch and activate in one call
func fetch_and_activate() -> void:
	fetch()
	if not _firebase_available:
		await get_tree().process_frame
	activate()


## Apply remote config values to game systems
func _apply_remote_values() -> void:
	var boil: float = get_float("boil_threshold", 1.0)
	GameManager.config.boilover_threshold = boil
	if OS.is_debug_build():
		print("[ABTestManager] boilover_threshold = %s" % boil)


func _detect_firebase() -> bool:
	# GodotFirebase addon exposes a global Firebase singleton
	if ClassDB.class_exists(&"Firebase"):
		return true
	if Engine.has_singleton("Firebase"):
		return true
	# Check if the global script autoload exists
	if get_node_or_null("/root/Firebase") != null:
		return true
	return false


func _load_cached_config() -> void:
	var cached: Variant = SaveManager.get_value("ab_config", {})
	if cached is Dictionary:
		_config = (cached as Dictionary).duplicate(true)


func _cache_config() -> void:
	SaveManager.set_value("ab_config", _config.duplicate(true))
