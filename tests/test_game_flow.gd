extends SceneTree

const GAME_FLOW_SCRIPT: Script = preload("res://scripts/core/game_flow.gd")

var _started: bool = false
var _passed: int = 0
var _failed: int = 0

func _process(_delta: float) -> bool:
	if _started:
		return false
	_started = true
	call_deferred("_run")
	return false

func _run() -> void:
	var flow: Node = root.get_node_or_null(^"GameFlow")
	if flow == null:
		flow = GAME_FLOW_SCRIPT.new()
		flow.name = "GameFlowTest"
		root.add_child(flow)
	var pause: Node = flow.get_node(^"PauseMenu")
	pause.call("toggle_pause")
	_check("pause toggles state and visibility", _state() == 1 and bool(pause.get("is_visible_menu")))
	pause.call("toggle_pause")
	_check("resume restores playing state", _state() == 0 and not bool(pause.get("is_visible_menu")))
	var boss: Node2D = Node2D.new()
	boss.add_to_group(&"boss")
	root.add_child(boss)
	_bus().emit_signal(&"enemy_died", boss, "test_boss", Vector2.ZERO)
	var end_screen: Node = flow.get_node(^"EndScreen")
	_check("boss death shows victory", str(end_screen.get("mode")) == "VICTORY" and _state() == 3 and paused)
	flow.call("reset_session")
	_check("session reset hides end screen", _state() == 0 and str(end_screen.get("mode")) == "" and not paused)
	var player: Node = Node.new()
	player.add_user_signal("health_changed", [{"name": "current_health", "type": TYPE_INT}, {"name": "max_health", "type": TYPE_INT}])
	player.set_meta("health", 100)
	root.add_child(player)
	player.add_to_group(&"player")
	flow.call("_bind_player", player)
	player.set_meta("health", 0)
	player.emit_signal(&"health_changed", 0, 100)
	_check("zero health shows game over", str(end_screen.get("mode")) == "GAME_OVER" and _state() == 3)
	flow.call("reset_session")
	_check("scene reset clears one-shot state", _state() == 0 and str(end_screen.get("mode")) == "")
	player.queue_free()
	boss.queue_free()
	if root.has_node(^"GameFlowTest"):
		flow.queue_free()
	print("RESULT passed=%d failed=%d" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)

func _check(label: String, condition: bool) -> void:
	if condition:
		_passed += 1
		print("PASS ", label)
	else:
		_failed += 1
		printerr("FAIL ", label)

func _bus() -> Node:
	return root.get_node(^"EventBus")

func _state() -> int:
	var manager: Node = root.get_node(^"GameManager")
	return int(manager.get("current_state"))

func _initialize() -> void:
	pass
