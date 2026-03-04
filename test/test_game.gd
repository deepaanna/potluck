## Test game: Tap 10 times to trigger game over.
## Validates: state machine, analytics events, save system, ad frequency capping.
extends Control

const TARGET_TAPS: int = 10

@onready var tap_button: Button = %TapButton
@onready var score_label: Label = %ScoreLabel
@onready var state_label: Label = %StateLabel
@onready var info_label: Label = %InfoLabel

var _tap_count: int = 0


func _ready() -> void:
	GameManager.start_game()
	GameManager.state_changed.connect(_on_state_changed)
	GameManager.score_changed.connect(_on_score_changed)
	AnalyticsManager.log_event("level_start", {"level": GameManager.level})

	tap_button.pressed.connect(_on_tap)
	_update_ui()

	info_label.text = "Tap %d times to test game over flow.\nCheck console for analytics events." % TARGET_TAPS

	print("=== TEST GAME STARTED ===")
	print("Verify the following in console output:")
	print("  1. [Analytics] session_start event")
	print("  2. [Analytics] level_start event")
	print("  3. Score increments on each tap")
	print("  4. [Analytics] level_complete at game over")
	print("  5. [AdManager] interstitial frequency capping")
	print("  6. Save file created at user://save.json")
	print("========================")


func _on_tap() -> void:
	_tap_count += 1
	GameManager.add_score(1)
	Utils.vibrate(30)

	if _tap_count >= TARGET_TAPS:
		_end_game()


func _end_game() -> void:
	AnalyticsManager.log_event("level_complete", {
		"level": GameManager.level,
		"score": GameManager.score,
	})
	GameManager.end_game()

	# Try showing an interstitial (will be blocked by level < 3 cap)
	var ad_shown: bool = AdManager.show_interstitial()
	print("[Test] Interstitial shown: %s" % str(ad_shown))

	# Switch to game over screen after a short delay
	get_tree().create_timer(0.5).timeout.connect(func() -> void:
		GameManager.goto_scene("res://scenes/game_over.tscn")
	)


func _on_state_changed(old_state: GameManager.GameState, new_state: GameManager.GameState) -> void:
	print("[Test] State: %s -> %s" % [
		GameManager.GameState.keys()[old_state],
		GameManager.GameState.keys()[new_state],
	])
	_update_ui()


func _on_score_changed(new_score: int) -> void:
	_update_ui()


func _update_ui() -> void:
	score_label.text = "Score: %d / %d" % [_tap_count, TARGET_TAPS]
	state_label.text = "State: %s" % GameManager.GameState.keys()[GameManager.current_state]
