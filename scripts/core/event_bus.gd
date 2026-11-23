extends Node


signal gesture_recognized(gesture_name: String, score: float)
signal gesture_failed()
signal letter_trigger_activated(entry_id: String)


signal player_state_changed(new_state: String)
signal player_health_changed(new_health: int, max_health: int)
signal player_interacted(target_object: Node)
signal level_transition_requested(target_scene_path: String)


signal game_saved(slot: int)
signal game_loaded(slot: int)


signal item_added(item_id: String, quantity: int)
signal item_removed(item_id: String, quantity: int)
signal inventory_updated()

signal enemy_spawned(enemy: Node2D, enemy_id: String)
signal enemy_health_changed(enemy: Node2D, enemy_id: String, current_health: int, max_health: int)
signal enemy_died(enemy: Node2D, enemy_id: String, death_position: Vector2)
