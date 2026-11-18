extends Node
## Global signal hub (autoload `EventBus`).
## Publishers and subscribers never reference each other — only these signals.

# --- Gesture / letter input ---
signal gesture_recognized(gesture_name: String, score: float)
signal gesture_failed()
signal letter_trigger_activated(entry_id: String)

# --- Player / gameplay ---
signal player_state_changed(new_state: String)
signal player_health_changed(new_health: int, max_health: int)
signal player_interacted(target_object: Node)
signal level_transition_requested(target_scene_path: String)

# --- Persistence ---
signal game_saved(slot: int)
signal game_loaded(slot: int)

# --- Inventory ---
signal item_added(item_id: String, quantity: int)
signal item_removed(item_id: String, quantity: int)
signal inventory_updated()
