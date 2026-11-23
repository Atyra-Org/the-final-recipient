extends SceneTree

class MockPlayer:
	extends CharacterBody2D
	var health: int = 100
	var hits: int = 0
	var last_knockback: Vector2 = Vector2.ZERO
	func take_damage(amount: int, knockback: Vector2 = Vector2.ZERO) -> void:
		health -= amount
		hits += 1
		last_knockback = knockback

var passed: int = 0
var failed: int = 0
var _started: bool = false
var _bus: Node = null
var _events: Dictionary = {"spawned": 0, "hp": 0, "died": 0, "id": "", "last_hp": -1, "max_hp": -1}


func _process(_delta: float) -> bool:
	if _started:
		return false
	_started = true
	call_deferred("_run")
	return false


func _check(label: String, condition: bool) -> void:
	if condition:
		passed += 1
		print("PASS: " + label)
	else:
		failed += 1
		print("FAIL: " + label)


func _ensure_bus() -> Node:
	var bus: Node = root.get_node_or_null(^"EventBus")
	if bus == null:
		var bus_script: GDScript = load("res://scripts/core/event_bus.gd")
		bus = bus_script.new()
		bus.name = &"EventBus"
		root.add_child(bus)
	return bus


func _run() -> void:
	_bus = _ensure_bus()
	_bus.connect(&"enemy_spawned", func(_e: Node2D, enemy_id: String) -> void:
		_events["spawned"] += 1
		_events["id"] = enemy_id
	)
	_bus.connect(&"enemy_health_changed", func(_e: Node2D, enemy_id: String, hp: int, max_hp: int) -> void:
		_events["hp"] += 1
		_events["id"] = enemy_id
		_events["last_hp"] = hp
		_events["max_hp"] = max_hp
	)
	_bus.connect(&"enemy_died", func(_e: Node2D, enemy_id: String, _pos: Vector2) -> void:
		_events["died"] += 1
		_events["id"] = enemy_id
	)

	var boss_data: BossData = load("res://resources/bosses/the_fractured_seal.tres") as BossData
	_check("boss data loads as BossData", boss_data != null)
	if boss_data == null:
		_finish()
		return
	_check("boss data id", boss_data.id == &"the_fractured_seal")
	_check("boss data name", boss_data.boss_name == "The Fractured Seal")
	_check("boss data max health 300", boss_data.max_health == 300)
	_check("boss data arena radius", is_equal_approx(boss_data.arena_radius, 220.0))
	_check("boss data chain count 4", boss_data.chain_count == 4)
	_check("boss data rotation speed", is_equal_approx(boss_data.chain_rotation_speed, 0.65))
	_check("boss data chain damage 15", boss_data.chain_damage == 15)
	_check("boss data chain knockback", is_equal_approx(boss_data.chain_knockback, 180.0))
	_check("boss data chain cooldown", is_equal_approx(boss_data.chain_hit_cooldown, 0.6))
	_check("boss data chain width", is_equal_approx(boss_data.chain_width, 8.0))
	_check("boss data target group", boss_data.target_group == &"player")

	var boss_scene: PackedScene = load("res://scenes/characters/fractured_seal_boss.tscn")
	var boss: FracturedSealBoss = boss_scene.instantiate() as FracturedSealBoss
	boss.global_position = Vector2(500.0, 400.0)
	root.add_child(boss)
	_check("boss in group enemy", boss.is_in_group(&"enemy"))
	_check("boss in group boss", boss.is_in_group(&"boss"))
	_check("boss emits enemy_spawned", int(_events["spawned"]) == 1)
	_check("boss spawned id", String(_events["id"]) == "the_fractured_seal")
	_check("boss health from data", boss.current_health == 300 and boss.max_health == 300)

	var chains: Node2D = boss.get_node(^"Chains")
	_check("boss builds 4 chains", chains.get_child_count() == 4)
	_check("chain has line and hitbox", chains.get_child(0).get_child_count() == 2)
	_check("chain line is Line2D", chains.get_child(0).get_child(0) is Line2D)
	_check("arena inactive before player enters", boss.arena_active == false)
	_check("chains hidden before player enters", not chains.visible)

	var spawn_pos: Vector2 = boss.global_position
	boss.take_damage(30, Vector2(900.0, 0.0))
	_check("boss stays still after knockback", boss.global_position.is_equal_approx(spawn_pos))
	_check("boss health reduced to 270", boss.current_health == 270)
	_check("boss emits enemy_health_changed", int(_events["hp"]) == 1 and int(_events["last_hp"]) == 270)
	_check("boss reports max health", int(_events["max_hp"]) == 300)

	var player: MockPlayer = MockPlayer.new()
	player.add_to_group(&"player")
	player.collision_layer = 2
	player.collision_mask = 0
	var player_shape: CollisionShape2D = CollisionShape2D.new()
	var circle: CircleShape2D = CircleShape2D.new()
	circle.radius = 12.0
	player_shape.shape = circle
	player.add_child(player_shape)
	player.global_position = Vector2(900.0, 400.0)
	root.add_child(player)

	await physics_frame
	await physics_frame
	_check("arena stays inactive while player outside", boss.arena_active == false)
	_check("no boss health bar outside arena", boss.health_bar == null)

	player.global_position = boss.global_position + Vector2(150.0, 0.0)
	for _i: int in 5:
		await physics_frame
	_check("arena activates when player inside", boss.arena_active == true)
	_check("chains visible inside arena", chains.visible)
	_check("boss health bar instantiated", boss.health_bar != null)

	var bar: BossHealthBar = boss.health_bar
	if bar != null:
		_check("health bar visible in arena", bar.visible)
		_check("health bar sits at bottom", is_equal_approx(bar.bar.anchor_top, 1.0) and bar.bar.offset_top < 0.0)
		_check("health bar width is large", bar.bar.size.x >= 520.0)
		_check("health bar shows boss name", bar.name_label.text == "The Fractured Seal")

	var rotation_before: float = chains.get_child(0).rotation
	for _i: int in 20:
		await physics_frame
	var rotation_after: float = chains.get_child(0).rotation
	_check("chains rotate over physics frames", rotation_after > rotation_before)
	_check("chain rotation follows configured speed", is_equal_approx(rotation_after - rotation_before, 20.0 * (1.0 / 60.0) * 0.65))

	var reach_ok: bool = true
	for i: int in 4:
		if boss.get_chain_reach(i) > boss.arena_radius + 0.001:
			reach_ok = false
		var line: Line2D = chains.get_child(i).get_child(0) as Line2D
		if line.points.size() < 2 or line.points[1].length() > boss.arena_radius + 0.001:
			reach_ok = false
	_check("every chain reach is capped by arena radius", reach_ok)

	var hits_before: int = player.hits
	for _i: int in 45:
		var chain_root: Node2D = chains.get_child(0) as Node2D
		player.global_position = boss.global_position + Vector2.RIGHT.rotated(chain_root.global_rotation) * 120.0
		await physics_frame
	_check("chain damages player inside arena", player.hits >= 1)
	_check("chain damage amount matches data", player.health == 100 - boss.chain_damage * player.hits)
	_check("chain respects hit cooldown", player.hits <= 2)
	_check("chain knockback points away from boss", player.last_knockback.dot(Vector2.RIGHT.rotated(chains.get_child(0).global_rotation)) > 0.0)
	var hits_during: int = player.hits
	await physics_frame
	_check("no extra hit within cooldown window", player.hits == hits_during)

	for _i: int in 20:
		await process_frame
	if boss.health_bar != null:
		_check("health bar value tracks current hp", is_equal_approx(boss.health_bar.bar.value, 270.0) and is_equal_approx(boss.health_bar.bar.max_value, 300.0))

	player.global_position = Vector2(1200.0, 400.0)
	for _i: int in 5:
		await physics_frame
	_check("arena deactivates when player leaves", boss.arena_active == false)
	_check("chains hidden after leaving", not chains.visible)
	if boss.health_bar != null:
		_check("health bar hidden after leaving", not boss.health_bar.visible)

	var died_count: Array[int] = [0]
	boss.died.connect(func() -> void: died_count[0] += 1)
	boss.take_damage(400)
	await physics_frame
	_check("boss dies at zero health", boss.current_health == 0 and boss.is_dead)
	_check("boss emits local died signal", died_count[0] == 1)
	_check("boss emits enemy_died", int(_events["died"]) == 1)
	if boss.health_bar != null:
		_check("health bar hidden at death", not boss.health_bar.visible)
	var chain_hitbox: Area2D = chains.get_child(0).get_child(1) as Area2D
	_check("chain hitboxes disabled at death", not chain_hitbox.monitoring)

	_finish()


func _finish() -> void:
	print("Test Boss Fractured Seal: %d passed, %d failed" % [passed, failed])
	quit(0 if failed == 0 else 1)