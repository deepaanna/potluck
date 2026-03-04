## In-app purchase management with purchase flow stubs.
## Applies purchases to SaveManager. Replace with real IAP SDK for production.
extends Node

signal purchase_started(product_id: String)
signal purchase_completed(product_id: String)
signal purchase_failed(product_id: String, error: String)
signal purchases_restored

var _is_purchasing: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_init_store()


## Initiate a purchase by product ID
func purchase(product_id: String) -> void:
	if _is_purchasing:
		push_warning("IAPManager: Purchase already in progress")
		return

	_is_purchasing = true
	purchase_started.emit(product_id)
	AnalyticsManager.log_event("iap_initiated", {"product_id": product_id})

	if OS.is_debug_build():
		print("[IAPManager] Purchase started (stub): %s" % product_id)

	## INTEGRATION POINT: Initiate real IAP purchase here
	## GooglePlayBilling.purchase(product_id)
	## or AppStore.purchase(product_id)

	# Simulate successful purchase after a short delay
	get_tree().create_timer(0.5).timeout.connect(func() -> void:
		_on_purchase_success(product_id)
	)


## Purchase the remove-ads product specifically
func purchase_remove_ads() -> void:
	var product_id: String = GameManager.config.iap_remove_ads_id
	purchase(product_id)


## Restore previous purchases
func restore_purchases() -> void:
	if OS.is_debug_build():
		print("[IAPManager] Restoring purchases (stub)")

	## INTEGRATION POINT: Restore purchases here
	## GooglePlayBilling.query_purchases()
	## or AppStore.restore_purchases()

	# Simulate restore completion
	get_tree().create_timer(0.3).timeout.connect(func() -> void:
		var purchases: Array = SaveManager.get_value("iap.purchases", []) as Array
		for product_id: Variant in purchases:
			_apply_purchase(product_id as String)
		purchases_restored.emit()

		if OS.is_debug_build():
			print("[IAPManager] Purchases restored (stub): %s" % str(purchases))
	)


## Check if a specific product has been purchased
func is_purchased(product_id: String) -> bool:
	var purchases: Array = SaveManager.get_value("iap.purchases", []) as Array
	return product_id in purchases


## Check if ads have been removed via IAP
func is_ads_removed() -> bool:
	return SaveManager.get_value("ads_removed", false) as bool


func _init_store() -> void:
	## INTEGRATION POINT: Initialize IAP store here
	## GooglePlayBilling.start_connection()
	## or AppStore.init()
	if OS.is_debug_build():
		print("[IAPManager] Store initialized (stub)")


func _on_purchase_success(product_id: String) -> void:
	_is_purchasing = false
	_record_purchase(product_id)
	_apply_purchase(product_id)

	AnalyticsManager.log_event("iap_completed", {"product_id": product_id})
	purchase_completed.emit(product_id)

	if OS.is_debug_build():
		print("[IAPManager] Purchase completed (stub): %s" % product_id)


func _on_purchase_failed(product_id: String, error: String) -> void:
	_is_purchasing = false

	AnalyticsManager.log_event("iap_failed", {"product_id": product_id, "error": error})
	purchase_failed.emit(product_id, error)

	if OS.is_debug_build():
		print("[IAPManager] Purchase failed (stub): %s — %s" % [product_id, error])


func _record_purchase(product_id: String) -> void:
	var purchases: Array = SaveManager.get_value("iap.purchases", []) as Array
	if product_id not in purchases:
		purchases.append(product_id)
		SaveManager.set_value("iap.purchases", purchases)


func _apply_purchase(product_id: String) -> void:
	var config: GameConfig = GameManager.config
	if product_id == config.iap_remove_ads_id:
		SaveManager.set_value("ads_removed", true)
		AdManager.hide_banner()
		if OS.is_debug_build():
			print("[IAPManager] Applied purchase: ads removed")
