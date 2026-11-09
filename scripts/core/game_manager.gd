extends Node

enum GameState { PLAYING, PAUSED, DIALOGUE, GAME_OVER }
var current_state: GameState = GameState.PLAYING

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func set_game_state(new_state: GameState) -> void:
	current_state = new_state
	match current_state:
		GameState.PAUSED, GameState.DIALOGUE:
			get_tree().paused = true
		GameState.PLAYING:
			get_tree().paused = false
