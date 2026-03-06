## Persistent save system using JSON file storage.
## Supports dot-path access, auto-save, and schema migration.
extends Node

signal save_completed
signal load_completed
signal data_changed(key: String, value: Variant)

const SAVE_PATH: String = "user://save.json"
const AUTO_SAVE_INTERVAL: float = 30.0
const SAVE_VERSION: int = 3

var _data: Dictionary = {}
var _dirty: bool = false
var _mutex: Mutex = Mutex.new()
var _auto_save_timer: Timer

var _default_data: Dictionary = {
	"save_version": SAVE_VERSION,
	"high_score": 0,
	"total_games": 0,
	"total_score": 0,
	"gdpr_consent": false,
	"gdpr_answered": false,
	"ads_removed": false,
	"rate_us_completed": false,
	"rate_us_declined": false,
	"settings": {
		"sfx_enabled": true,
		"music_enabled": true,
		"haptics_enabled": true,
	},
	"stats": {
		"first_play_time": 0,
		"last_play_time": 0,
		"total_play_time": 0.0,
	},
	"iap": {
		"purchases": [],
	},
	"pot_luck": {
		"unlocked_cuisines": ["basic"],
		"recipes_discovered": [],
		"daily_challenge": {"last_date": "", "best_score": 0},
		"tutorial_completed": false,
		"onboarding_step": 0,
		"onboarding_completed": false,
		"chef_level": 1,
		"chef_xp": 0,
		"abilities_unlocked": [],
		"spice_coins": 0,
		"chefs_pass_active": false,
		"chefs_pass_expiry": 0,
		"equipped_pot_skin": "default",
		"owned_pot_skins": ["default"],
		"stats": {
			"total_dishes_served": 0,
			"total_boilovers": 0,
			"total_ingredients_used": 0,
			"best_combo_multiplier": 1.0,
			"perfect_pots": 0,
			"total_xp_earned": 0,
			"total_abilities_used": 0,
			"highest_level_reached": 1,
		},
	},
}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_data()
	_setup_auto_save()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save()
	elif what == NOTIFICATION_APPLICATION_PAUSED:
		save()


## Get a value using dot-path notation (e.g., "settings.sfx_enabled")
func get_value(path: String, default: Variant = null) -> Variant:
	_mutex.lock()
	var result: Variant = _get_nested(_data, path, default)
	_mutex.unlock()
	return result


## Set a value using dot-path notation (e.g., "settings.sfx_enabled")
func set_value(path: String, value: Variant) -> void:
	_mutex.lock()
	_set_nested(_data, path, value)
	_dirty = true
	_mutex.unlock()
	data_changed.emit(path, value)


## Check if a key exists at the given dot-path
func has_value(path: String) -> bool:
	_mutex.lock()
	var result: bool = _has_nested(_data, path)
	_mutex.unlock()
	return result


## Save data to disk immediately
func save() -> void:
	_mutex.lock()
	if not _dirty:
		_mutex.unlock()
		return
	var data_copy: Dictionary = _data.duplicate(true)
	_dirty = false
	_mutex.unlock()

	var json_string: String = JSON.stringify(data_copy, "\t")
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("SaveManager: Failed to open save file for writing: %s" % error_string(FileAccess.get_open_error()))
		return
	file.store_string(json_string)
	file.close()
	save_completed.emit()


## Reset all data to defaults
func reset() -> void:
	_mutex.lock()
	_data = _default_data.duplicate(true)
	_dirty = true
	_mutex.unlock()
	save()


## Get entire data dictionary (read-only copy)
func get_all_data() -> Dictionary:
	_mutex.lock()
	var copy: Dictionary = _data.duplicate(true)
	_mutex.unlock()
	return copy


func _load_data() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		_data = _default_data.duplicate(true)
		_dirty = true
		save()
		load_completed.emit()
		return

	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		push_error("SaveManager: Failed to open save file for reading: %s" % error_string(FileAccess.get_open_error()))
		_data = _default_data.duplicate(true)
		load_completed.emit()
		return

	var json_string: String = file.get_as_text()
	file.close()

	var json: JSON = JSON.new()
	var parse_result: Error = json.parse(json_string)
	if parse_result != OK:
		push_error("SaveManager: Failed to parse save file: %s" % json.get_error_message())
		_data = _default_data.duplicate(true)
		_dirty = true
		save()
		load_completed.emit()
		return

	_data = json.data as Dictionary
	_migrate_data()
	_merge_defaults()
	load_completed.emit()


func _migrate_data() -> void:
	var version: int = _data.get("save_version", 0) as int
	if version < 2:
		_data["pot_luck"] = _default_data["pot_luck"].duplicate(true)
	if version < 3:
		# Ensure pot_luck top-level keys exist for v3 additions
		if _data.has("pot_luck") and _data["pot_luck"] is Dictionary:
			var pl: Dictionary = _data["pot_luck"] as Dictionary
			if not pl.has("chef_level"):
				pl["chef_level"] = 1
			if not pl.has("chef_xp"):
				pl["chef_xp"] = 0
			if not pl.has("abilities_unlocked"):
				pl["abilities_unlocked"] = []
			if not pl.has("tutorial_completed"):
				pl["tutorial_completed"] = false
	if version < SAVE_VERSION:
		_data["save_version"] = SAVE_VERSION
		_dirty = true


func _merge_defaults() -> void:
	_merge_dict(_data, _default_data)


func _merge_dict(target: Dictionary, defaults: Dictionary) -> void:
	for key: String in defaults:
		if not target.has(key):
			target[key] = defaults[key]
			_dirty = true
		elif defaults[key] is Dictionary and target[key] is Dictionary:
			_merge_dict(target[key] as Dictionary, defaults[key] as Dictionary)


func _setup_auto_save() -> void:
	_auto_save_timer = Timer.new()
	_auto_save_timer.wait_time = AUTO_SAVE_INTERVAL
	_auto_save_timer.autostart = true
	_auto_save_timer.timeout.connect(_on_auto_save)
	add_child(_auto_save_timer)


func _on_auto_save() -> void:
	if _dirty:
		save()


func _get_nested(dict: Dictionary, path: String, default: Variant) -> Variant:
	var keys: PackedStringArray = path.split(".")
	var current: Variant = dict
	for key: String in keys:
		if current is Dictionary and (current as Dictionary).has(key):
			current = (current as Dictionary)[key]
		else:
			return default
	return current


func _set_nested(dict: Dictionary, path: String, value: Variant) -> void:
	var keys: PackedStringArray = path.split(".")
	var current: Dictionary = dict
	for i: int in range(keys.size() - 1):
		var key: String = keys[i]
		if not current.has(key) or not current[key] is Dictionary:
			current[key] = {}
		current = current[key] as Dictionary
	current[keys[keys.size() - 1]] = value


func _has_nested(dict: Dictionary, path: String) -> bool:
	var keys: PackedStringArray = path.split(".")
	var current: Variant = dict
	for key: String in keys:
		if current is Dictionary and (current as Dictionary).has(key):
			current = (current as Dictionary)[key]
		else:
			return false
	return true
