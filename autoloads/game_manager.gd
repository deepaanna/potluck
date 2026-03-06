## Central game state machine and scene management.
## Controls game flow: MENU → PLAYING → PAUSED/GAME_OVER → MENU.
extends Node

signal state_changed(old_state: GameState, new_state: GameState)
signal score_changed(new_score: int)
signal scene_changed(scene_name: String)
signal heat_updated(new_heat: float)

enum GameState { MENU, PLAYING, PAUSED, GAME_OVER }

const VALID_TRANSITIONS: Dictionary = {
	GameState.MENU: [GameState.PLAYING],
	GameState.PLAYING: [GameState.PAUSED, GameState.GAME_OVER],
	GameState.PAUSED: [GameState.PLAYING, GameState.MENU],
	GameState.GAME_OVER: [GameState.MENU, GameState.PLAYING],
}

var current_state: GameState = GameState.MENU
var score: int = 0
var level: int = 1
var config: GameConfig

# Push-your-luck run state
var current_heat: float = 0.0
var ingredients_pulled: int = 0
var combo_multiplier: float = 1.0
var recent_ingredients: Array[String] = []

var _scene_tree: SceneTree


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_scene_tree = get_tree()
	_load_config()


## Transition to a new game state if the transition is valid
func change_state(new_state: GameState) -> bool:
	if not _is_valid_transition(new_state):
		push_warning("GameManager: Invalid state transition from %s to %s" % [
			GameState.keys()[current_state], GameState.keys()[new_state]
		])
		return false

	var old_state: GameState = current_state
	current_state = new_state

	match new_state:
		GameState.PLAYING:
			_scene_tree.paused = false
		GameState.PAUSED:
			_scene_tree.paused = true
		GameState.GAME_OVER:
			_scene_tree.paused = false
		GameState.MENU:
			_scene_tree.paused = false

	state_changed.emit(old_state, new_state)
	return true


## Start a new game — resets score, sets state to PLAYING
func start_game() -> void:
	score = 0
	level = 1
	score_changed.emit(score)
	reset_run()
	change_state(GameState.PLAYING)


## Reset push-your-luck run state for a new round
func reset_run() -> void:
	current_heat = 0.0
	ingredients_pulled = 0
	combo_multiplier = 1.0
	recent_ingredients.clear()


## Track an ingredient being added to the pot
func add_ingredient(data: IngredientData) -> void:
	current_heat += data.heat
	ingredients_pulled += 1
	recent_ingredients.append(data.id)
	heat_updated.emit(current_heat)


## Log and handle boilover event
func boil_over() -> void:
	AnalyticsManager.log_event("boilover_gm", {
		"heat": current_heat,
		"ingredients": ingredients_pulled,
	})


## Log and finalize a served dish
func serve_dish(final_score: int) -> void:
	AnalyticsManager.log_event("dish_served_gm", {
		"score": final_score,
		"ingredients": ingredients_pulled,
		"combo_multiplier": combo_multiplier,
	})


## Add points to the current score
func add_score(points: int) -> void:
	score += points
	score_changed.emit(score)


## End the game — checks for high score, transitions to GAME_OVER
func end_game() -> void:
	var high_score: int = SaveManager.get_value("high_score", 0) as int
	var is_high_score: bool = score > high_score
	if is_high_score:
		SaveManager.set_value("high_score", score)

	var total_games: int = SaveManager.get_value("total_games", 0) as int
	SaveManager.set_value("total_games", total_games + 1)

	var total_score: int = SaveManager.get_value("total_score", 0) as int
	SaveManager.set_value("total_score", total_score + score)

	change_state(GameState.GAME_OVER)


## Change the current scene with a fade transition (fire-and-forget)
func goto_scene(scene_path: String, transition: UIManager.Transition = UIManager.Transition.FADE) -> void:
	UIManager.change_screen(scene_path, transition)
	var scene_name: String = scene_path.get_file().get_basename()
	scene_changed.emit(scene_name)


## Pause the game
func pause() -> void:
	if current_state == GameState.PLAYING:
		change_state(GameState.PAUSED)


## Resume the game
func resume() -> void:
	if current_state == GameState.PAUSED:
		change_state(GameState.PLAYING)


func _is_valid_transition(new_state: GameState) -> bool:
	if new_state == current_state:
		return false
	var valid: Array = VALID_TRANSITIONS.get(current_state, []) as Array
	return new_state in valid


func _load_config() -> void:
	config = load("res://resources/game_config.tres") as GameConfig
	if config == null:
		push_warning("GameManager: game_config.tres not found, using defaults")
		config = GameConfig.new()
