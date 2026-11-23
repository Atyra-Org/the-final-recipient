extends SceneTree

var passed: int = 0
var failed: int = 0
var _ran: bool = false

func _process(_delta: float) -> bool:
	if _ran:
		return true
	_ran = true
	_test_enemy_event_bus_signals()
	print("Test Enemy EventBus: %d passed, %d failed" % [passed, failed])
	quit(0 if failed == 0 else 1)
	return true

func _check(label: String, condition: bool) -> void:
	if condition:
		passed += 1
	else:
		failed += 1
		push_error("FAILED: " + label)

func _test_enemy_event_bus_signals() -> void:
	var created_bus: bool = false
	var event_bus: Node = root.get_node_or_null(^"EventBus")
	if event_bus == null:
		var bus_script: GDScript = load("res://scripts/core/event_bus.gd")
		event_bus = bus_script.new()
		event_bus.name = &"EventBus"
		root.add_child(event_bus)
		created_bus = true

	_check("event_bus defines enemy_spawned", event_bus.has_signal(&"enemy_spawned"))
	_check("event_bus defines enemy_health_changed", event_bus.has_signal(&"enemy_health_changed"))
	_check("event_bus defines enemy_died", event_bus.has_signal(&"enemy_died"))

	var events: Dictionary = {
		"spawned_count": 0,
		"spawned_id": "",
		"hp_changed_count": 0,
		"last_hp": -1,
		"last_max_hp": -1,
		"died_count": 0,
		"died_id": "",
		"death_pos": Vector2.ZERO
	}

	var on_spawned: Callable = func(enemy: Node2D, enemy_id: String) -> void:
		if is_instance_valid(enemy):
			events["spawned_count"] += 1
			events["spawned_id"] = enemy_id

	var on_hp_changed: Callable = func(enemy: Node2D, _enemy_id: String, current_hp: int, max_hp: int) -> void:
		if is_instance_valid(enemy):
			events["hp_changed_count"] += 1
			events["last_hp"] = current_hp
			events["last_max_hp"] = max_hp

	var on_died: Callable = func(enemy: Node2D, enemy_id: String, death_pos: Vector2) -> void:
		if is_instance_valid(enemy):
			events["died_count"] += 1
			events["died_id"] = enemy_id
			events["death_pos"] = death_pos

	event_bus.connect(&"enemy_spawned", on_spawned)
	event_bus.connect(&"enemy_health_changed", on_hp_changed)
	event_bus.connect(&"enemy_died", on_died)

	var enemy_scene: PackedScene = load("res://scenes/characters/enemy_dummy.tscn")
	var gremlin: EnemyController = enemy_scene.instantiate() as EnemyController
	gremlin.data = load("res://resources/enemies/greedy_gremlin.tres")
	gremlin.global_position = Vector2(120.0, 240.0)
	root.add_child(gremlin)

	_check("event_bus emits enemy_spawned", events["spawned_count"] == 1)
	_check("event_bus spawned id matches resource", events["spawned_id"] == "greedy_gremlin")

	gremlin.take_damage(15)
	_check("event_bus emits enemy_health_changed", events["hp_changed_count"] == 1)
	_check("event_bus reports remaining hp", events["last_hp"] == 35 and events["last_max_hp"] == 50)

	gremlin.take_damage(999)
	_check("event_bus emits enemy_died", events["died_count"] == 1)
	_check("event_bus died id matches resource", events["died_id"] == "greedy_gremlin")
	_check("event_bus death position matches global_position", events["death_pos"].is_equal_approx(Vector2(120.0, 240.0)))

	event_bus.disconnect(&"enemy_spawned", on_spawned)
	event_bus.disconnect(&"enemy_health_changed", on_hp_changed)
	event_bus.disconnect(&"enemy_died", on_died)
	gremlin.free()
	if created_bus:
		event_bus.free()
