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
	_check("idle pause menu hidden", not bool(pause.get("visible")) and not bool(pause.get("is_visible_menu")))
	_check("idle pause backdrop hidden and ignores input", not bool(pause.get_node(^"Root/Shade").get("visible")) and int(pause.get_node(^"Root/Shade").get("mouse_filter")) == Control.MOUSE_FILTER_IGNORE)
	var end_screen: Node = flow.get_node(^"EndScreen")
	_check("idle end screen hidden", not bool(end_screen.get("visible")))
	_check("idle end backdrop hidden, transparent, and ignores input", not bool(end_screen.get_node(^"Root/Overlay").get("visible")) and float(end_screen.get_node(^"Root/Overlay").get("modulate").a) == 0.0 and int(end_screen.get_node(^"Root/Overlay").get("mouse_filter")) == Control.MOUSE_FILTER_IGNORE)
	pause.call("toggle_pause")
	_check("pause toggles state and visibility", _state() == 1 and bool(pause.get("is_visible_menu")) and bool(pause.get("visible")) and bool(pause.get_node(^"Root/Shade").get("visible")))
	pause.call("toggle_pause")
	_check("resume restores playing state and hides backdrop", _state() == 0 and not bool(pause.get("visible")) and not bool(pause.get_node(^"Root/Shade").get("visible")))
	var boss: Node2D = Node2D.new()
	boss.add_to_group(&"boss")
	root.add_child(boss)
	_bus().emit_signal(&"enemy_died", boss, "test_boss", Vector2.ZERO)
	_check("boss death shows victory", str(end_screen.get("mode")) == "VICTORY" and bool(end_screen.get("visible")) and bool(end_screen.get_node(^"Root/Overlay").get("visible")) and _state() == 3 and paused)
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
