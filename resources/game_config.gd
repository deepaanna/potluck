## Game configuration resource — holds all game-specific settings.
## Each new game customizes its own instance of this resource.
class_name GameConfig
extends Resource

## Display name shown in UI
@export var game_name: String = "My Game"

## Unique identifier for analytics and saves
@export var game_id: String = "my_game"

## Version string for save migration
@export var game_version: String = "1.0.0"

@export_group("AdMob")
## INTEGRATION POINT: Replace with real AdMob app ID
@export var admob_app_id: String = "ca-app-pub-3940256099942544~3347511713"
## INTEGRATION POINT: Replace with real banner ad unit ID
@export var admob_banner_id: String = "ca-app-pub-3940256099942544/6300978111"
## INTEGRATION POINT: Replace with real interstitial ad unit ID
@export var admob_interstitial_id: String = "ca-app-pub-3940256099942544/1033173712"
## INTEGRATION POINT: Replace with real rewarded ad unit ID
@export var admob_rewarded_id: String = "ca-app-pub-3940256099942544/5224354917"

@export_group("IAP")
## INTEGRATION POINT: Replace with real IAP product IDs
@export var iap_remove_ads_id: String = "remove_ads"
@export var iap_product_ids: PackedStringArray = ["remove_ads"]

@export_group("Firebase")
## INTEGRATION POINT: Replace with real Firebase project ID
@export var firebase_project_id: String = ""

@export_group("Rate Us")
## Email address for user feedback
@export var feedback_email: String = "feedback@example.com"
## INTEGRATION POINT: Replace with real app store URL
@export var app_store_url: String = ""
## Number of games played before showing Rate Us popup
@export var rate_us_games_threshold: int = 5

@export_group("Gameplay")
## Minimum level before interstitial ads appear
@export var ad_min_level: int = 3
## Minimum seconds between interstitial ads
@export var ad_cooldown_seconds: float = 30.0
## Maximum interstitial ads per session
@export var ad_max_per_session: int = 10

@export_group("Pot Luck")
## Number of ingredients drawn into the bag each round
@export var bag_size: int = 12
## Heat level that triggers a boilover (game over)
@export var boilover_threshold: float = 1.0
## Heat stage thresholds: [warm, hot, bubbling, danger]
@export var heat_stages: PackedFloat32Array = PackedFloat32Array([0.25, 0.50, 0.75, 0.90])
## Bonus multiplier per consecutive ingredient added (capped at streak_max_bonus)
@export var streak_bonus_per: float = 0.1
## Maximum streak bonus multiplier
@export var streak_max_bonus: float = 2.0
## Clean pot bonus multiplier when bag is emptied
@export var clean_pot_bonus: float = 1.5
## Heat reduction ratio when second chance is used (multiplied by current heat)
@export var second_chance_heat_reduction: float = 0.5
