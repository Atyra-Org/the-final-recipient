extends Node

# Global Gameplay Signals (Decoupled Architecture)
signal player_health_changed(new_health: int, max_health: int)
signal player_interacted(target_object: Node)
signal level_transition_requested(target_scene_path: String)
