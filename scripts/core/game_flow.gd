extends Node

const PAUSE_MENU_SCENE: PackedScene = preload("res://scenes/ui/pause_menu.tscn")
const END_SCREEN_SCENE: PackedScene = preload("res://scenes/ui/end_screen.tscn")

var pause_menu: PauseMenu
var end_screen: EndScreen
var _ended: bool = false
var _bound_player: Node
var _tracked_scene: Node

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	pause_menu = PAUSE_MENU_SCENE.instantiate() as PauseMenu
	pause_menu.name = "PauseMenu"
	add_child(pause_menu)
	end_screen = END_SCREEN_SCENE.instantiate() as EndScreen
	end_screen.name = "EndScreen"
	add_child(end_screen)
	var bus: Node = get_tree().root.get_node_or_null(^"EventBus")
	if bus != null and bus.has_signal(&"enemy_died"):
		bus.connect(&"enemy_died", _on_enemy_died)
	get_tree().scene_changed.connect(_on_scene_changed)
	_track_scene()

func _process(_delta: float) -> void:
	if get_tree().current_scene != _tracked_scene:
		_on_scene_changed()
	if _ended:
		return
	var player: Node = get_tree().get_first_node_in_group(&"player")
	if player != _bound_player:
		_bind_player(player)
	if player == null:
		return
	var health: Variant = player.get("health")
	var dead: Variant = player.get("is_dead")
	if (health is int and int(health) <= 0) or (dead is bool and bool(dead)):
		_trigger_game_over()

func _on_enemy_died(enemy: Node2D, enemy_id: String, _death_position: Vector2) -> void:
	if _ended:
		return
	if (is_instance_valid(enemy) and enemy.is_in_group(&"boss")) or enemy_id == "the_fractured_seal":
		_ended = true
		_set_game_state(3)
		get_tree().paused = true
		var boss_name: String = "The Fractured Seal"
		if is_instance_valid(enemy) and enemy.has_method("_get_boss_name"):
			boss_name = str(enemy.call("_get_boss_name"))
		end_screen.show_victory(boss_name)

func _bind_player(player: Node) -> void:
	if is_instance_valid(_bound_player) and _bound_player.has_signal(&"health_changed"):
		var callback: Callable = _on_player_health_changed
		if _bound_player.is_connected(&"health_changed", callback):
			_bound_player.disconnect(&"health_changed", callback)
	_bound_player = player
	if is_instance_valid(player) and player.has_signal(&"health_changed"):
		player.connect(&"health_changed", _on_player_health_changed)
		var current_health: Variant = player.get("health")
		if current_health is int and int(current_health) <= 0:
			_trigger_game_over()

func _on_player_health_changed(current_health: int, _max_health: int) -> void:
	if current_health <= 0:
		_trigger_game_over()

func _trigger_game_over() -> void:
	if _ended:
		return
	_ended = true
	_set_game_state(3)
	get_tree().paused = true
	end_screen.show_game_over()

func reset_session() -> void:
	_ended = false
	_bind_player(null)
	get_tree().paused = false
	end_screen.hide_screen()
	pause_menu.resume_game()
	_track_scene()

func _on_scene_changed() -> void:
	reset_session()

func _track_scene() -> void:
	_tracked_scene = get_tree().current_scene

func _set_game_state(state: int) -> void:
	var manager: Node = get_tree().root.get_node_or_null(^"GameManager")
	if manager != null:
		manager.call("set_game_state", state)
