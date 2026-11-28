extends SceneTree

class TestPlayer extends Node:
	var mana: int = 0
	var max_mana: int = 300
	var is_attack_buff_active: bool = false
	signal mana_changed(current_mana: int, maximum_mana: int)

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
	var hud: Node = root.get_node_or_null(^"SpellHud")
	if hud == null:
		var scene: PackedScene = load("res://scenes/ui/spell_hud.tscn")
		hud = scene.instantiate()
		hud.name = "SpellHudTest"
		root.add_child(hud)
	await process_frame
	_check("hidden without player", not bool(hud.get("visible")))
	var player: TestPlayer = TestPlayer.new()
	player.mana = 50
	player.add_to_group(&"player")
	root.add_child(player)
	await process_frame
	_check("shown with player", bool(hud.get("visible")))
	_check("low mana dims costly spell", not bool(hud.call("is_spell_ready", "line_horizontal")) and bool(hud.call("is_spell_ready", "circle")))
	player.mana = 100
	player.mana_changed.emit(player.mana, player.max_mana)
	player.is_attack_buff_active = true
	await process_frame
	_check("sufficient mana enables spells", bool(hud.call("is_spell_ready", "line_horizontal")) and bool(hud.call("is_spell_ready", "star")))
	_check("attack buff status visible", bool(hud.call("is_buff_active")))
	var bus: Node = root.get_node_or_null(^"EventBus")
	if bus != null:
		bus.emit_signal(&"gesture_recognized", "star", 0.94)
	_check("recognized gesture shows toast and highlights card", str(hud.call("get_feedback_text")).contains("CAST: STAR BIND (94%)") and bool(hud.call("is_spell_highlighted", "star")))
	if bus != null:
		bus.emit_signal(&"gesture_failed")
	_check("failed gesture shows warning", hud.call("get_feedback_text") == "RUNE FAILED")
	await create_timer(1.1).timeout
	_check("failed gesture toast expires", hud.call("get_feedback_text") == "")
	player.remove_from_group(&"player")
	player.queue_free()
	await process_frame
	await process_frame
	_check("hidden after player leaves", not bool(hud.get("visible")))
	if root.has_node(^"SpellHudTest"):
		hud.queue_free()
	print("RESULT passed=%d failed=%d" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)

func _check(label: String, condition: bool) -> void:
	if condition:
		_passed += 1
		print("PASS ", label)
	else:
		_failed += 1
		printerr("FAIL ", label)
