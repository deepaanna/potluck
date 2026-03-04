## Ad management with frequency capping, cooldown, and session limits.
## Stub implementation that logs to console; replace with AdMob SDK for production.
extends Node

signal interstitial_closed
signal rewarded_ad_completed(reward_type: String, amount: int)
signal banner_loaded

var _interstitials_shown: int = 0
var _last_interstitial_time: float = 0.0
var _banner_visible: bool = false
var _interstitial_ready: bool = false
var _rewarded_ready: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_preload_ads()


## Show a banner ad at the bottom of the screen
func show_banner() -> void:
	if _is_ads_removed() or not _has_consent():
		return

	## INTEGRATION POINT: Show AdMob banner here
	## AdMob.show_banner()
	_banner_visible = true
	if OS.is_debug_build():
		print("[AdManager] Banner shown (stub)")
	banner_loaded.emit()


## Hide the banner ad
func hide_banner() -> void:
	## INTEGRATION POINT: Hide AdMob banner here
	## AdMob.hide_banner()
	_banner_visible = false
	if OS.is_debug_build():
		print("[AdManager] Banner hidden (stub)")


## Show an interstitial ad if frequency capping allows it
func show_interstitial() -> bool:
	if _is_ads_removed() or not _has_consent():
		if OS.is_debug_build():
			print("[AdManager] Interstitial blocked: ads removed or no consent")
		return false

	if not _can_show_interstitial():
		return false

	## INTEGRATION POINT: Show AdMob interstitial here
	## AdMob.show_interstitial()
	_interstitials_shown += 1
	_last_interstitial_time = Time.get_ticks_msec() / 1000.0
	_interstitial_ready = false

	AnalyticsManager.log_event("ad_shown", {"ad_type": "interstitial"})

	if OS.is_debug_build():
		print("[AdManager] Interstitial shown (stub) — %d/%d this session" % [
			_interstitials_shown, GameManager.config.ad_max_per_session
		])

	# Simulate ad close after a short delay
	get_tree().create_timer(0.1).timeout.connect(func() -> void:
		interstitial_closed.emit()
		_preload_interstitial()
	)
	return true


## Show a rewarded ad
func show_rewarded(reward_type: String = "coins", reward_amount: int = 1) -> bool:
	if not _rewarded_ready:
		if OS.is_debug_build():
			print("[AdManager] Rewarded ad not ready")
		return false

	## INTEGRATION POINT: Show AdMob rewarded ad here
	## AdMob.show_rewarded()
	_rewarded_ready = false

	AnalyticsManager.log_event("ad_shown", {"ad_type": "rewarded"})

	if OS.is_debug_build():
		print("[AdManager] Rewarded ad shown (stub) — reward: %s x%d" % [reward_type, reward_amount])

	# Simulate reward after a short delay
	get_tree().create_timer(0.1).timeout.connect(func() -> void:
		AnalyticsManager.log_event("ad_rewarded", {"reward_type": reward_type, "amount": reward_amount})
		rewarded_ad_completed.emit(reward_type, reward_amount)
		_preload_rewarded()
	)
	return true


## Check if an interstitial can be shown right now
func can_show_interstitial() -> bool:
	if _is_ads_removed() or not _has_consent():
		return false
	return _can_show_interstitial()


## Check if a rewarded ad is ready
func is_rewarded_ready() -> bool:
	return _rewarded_ready


func _is_ads_removed() -> bool:
	return SaveManager.get_value("ads_removed", false) as bool


func _has_consent() -> bool:
	return SaveManager.get_value("gdpr_consent", false) as bool


func _can_show_interstitial() -> bool:
	if not _interstitial_ready:
		if OS.is_debug_build():
			print("[AdManager] Interstitial not ready")
		return false

	var config: GameConfig = GameManager.config

	# Check level minimum
	if GameManager.level < config.ad_min_level:
		if OS.is_debug_build():
			print("[AdManager] Interstitial blocked: level %d < min %d" % [GameManager.level, config.ad_min_level])
		return false

	# Check session cap
	if _interstitials_shown >= config.ad_max_per_session:
		if OS.is_debug_build():
			print("[AdManager] Interstitial blocked: session cap reached (%d/%d)" % [
				_interstitials_shown, config.ad_max_per_session
			])
		return false

	# Check cooldown
	var elapsed: float = (Time.get_ticks_msec() / 1000.0) - _last_interstitial_time
	if _last_interstitial_time > 0.0 and elapsed < config.ad_cooldown_seconds:
		if OS.is_debug_build():
			print("[AdManager] Interstitial blocked: cooldown (%.1fs / %.1fs)" % [
				elapsed, config.ad_cooldown_seconds
			])
		return false

	return true


func _preload_ads() -> void:
	_preload_interstitial()
	_preload_rewarded()


func _preload_interstitial() -> void:
	## INTEGRATION POINT: Load AdMob interstitial here
	## AdMob.load_interstitial(GameManager.config.admob_interstitial_id)
	_interstitial_ready = true
	if OS.is_debug_build():
		print("[AdManager] Interstitial preloaded (stub)")


func _preload_rewarded() -> void:
	## INTEGRATION POINT: Load AdMob rewarded ad here
	## AdMob.load_rewarded(GameManager.config.admob_rewarded_id)
	_rewarded_ready = true
	if OS.is_debug_build():
		print("[AdManager] Rewarded ad preloaded (stub)")
