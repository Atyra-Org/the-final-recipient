extends SceneTree

class MockPlayer:
	extends CharacterBody2D
	var health: int = 100
	var damage_count: int = 0
	func take_damage(amount: int, _knockback: Vector2 = Vector2.ZERO) -> void:
		health -= amount
		damage_count += 1

var passed: int = 0
var failed: int = 0
var _started: bool = false
var _events: Dictionary = {"spawned": 0, "hp": 0, "died": 0}

func _process(_delta: float) -> bool:
	if not _started:
		_started = true
		call_deferred("_run")
	return false

func _check(label: String, condition: bool) -> void:
	if condition:
		passed += 1
	else:
		failed += 1
		push_error("FAIL: " + label)

func _run() -> void:
	var bus: Node = root.get_node_or_null(^"EventBus")
	if bus == null:
		bus = (load("res://scripts/core/event_bus.gd") as GDScript).new()
		bus.name = &"EventBus"
		root.add_child(bus)
	bus.connect(&"enemy_spawned", func(_e: Node2D, _id: String) -> void: _events["spawned"] += 1)
	bus.connect(&"enemy_health_changed", func(_e: Node2D, _id: String, _hp: int, _max: int) -> void: _events["hp"] += 1)
	bus.connect(&"enemy_died", func(_e: Node2D, _id: String, _pos: Vector2) -> void: _events["died"] += 1)
	var data: BossData = load("res://resources/bosses/the_fractured_seal.tres") as BossData
	_check("BossData loads", data != null)
	if data == null:
		_finish()
		return
	_check("AoE config", is_equal_approx(data.aoe_radius, 56.0) and is_equal_approx(data.aoe_charge_duration, 1.6) and is_equal_approx(data.aoe_lock_ratio, 0.8) and data.aoe_damage == 20)
	_check("Phase 2 config", data.phase2_health_threshold == 30 and data.phase2_minion_count == 2 and is_equal_approx(data.phase2_aoe_cooldown_multiplier, 0.75))
	_check("obsolete chain properties removed", not ("chain_count" in data))
	var boss: FracturedSealBoss = (load("res://scenes/characters/fractured_seal_boss.tscn") as PackedScene).instantiate() as FracturedSealBoss
	boss.position = Vector2(500.0, 400.0)
	root.add_child(boss)
	_check("enemy and boss groups, event", boss.is_in_group(&"enemy") and boss.is_in_group(&"boss") and int(_events["spawned"]) == 1)
	_check("static position on hit", boss.position == Vector2(500.0, 400.0))
	var player: MockPlayer = MockPlayer.new()
	player.add_to_group(&"player")
	player.collision_layer = 2
	player.collision_mask = 0
	var collision: CollisionShape2D = CollisionShape2D.new()
	var circle: CircleShape2D = CircleShape2D.new()
	circle.radius = 12.0
	collision.shape = circle
	player.add_child(collision)
	player.position = boss.position + Vector2(120.0, 0.0)
	root.add_child(player)
	for _i: int in 5:
		await physics_frame
	_check("arena activates", boss.arena_active and boss.health_bar != null and boss.health_bar.visible)
	_check("telegraph present", boss.active_telegraph != null)
	var telegraph: Node2D = boss.active_telegraph
	boss._process_telegraph(0.1)
	_check("telegraph tracks target", telegraph.global_position.distance_to(player.global_position) < 1.0)
	player.position = boss.position + Vector2(210.0, 0.0)
	boss._process_telegraph(0.1)
	_check("telegraph clamped within arena", boss.locked_position.distance_to(boss.position) <= boss.arena_radius - boss.aoe_radius + 0.001)
	boss.telegraph_progress = 0.79
	boss._process_telegraph(0.01)
	var locked: Vector2 = boss.locked_position
	player.position = boss.position + Vector2(100.0, 100.0)
	boss._process_telegraph(0.01)
	_check("telegraph locks at threshold", boss.locked_position.is_equal_approx(locked) and boss.active_telegraph.locked)
	player.position = locked
	var before: int = player.health
	boss.telegraph_progress = 0.99
	boss._process_telegraph(0.02)
	_check("detonation damages target in radius", player.health == before - boss.aoe_damage)
	boss.aoe_cooldown_timer = 0.0
	boss._start_telegraph()
	boss.locked_position = player.position
	boss.telegraph_progress = 0.99
	player.position = locked + Vector2(100.0, 0.0)
	before = player.health
	boss._process_telegraph(0.02)
	_check("detonation misses escaped target", player.health == before)
	boss.take_damage(270)
	_check("phase 2 threshold triggers", boss.phase2_active and boss.current_health == 30)
	_check("phase 2 spawns two minions", boss.phase2_minions.size() == 2)
	var minion_ok: bool = boss.phase2_minions.size() == 2
	for minion: Node2D in boss.phase2_minions:
		var controller: EnemyController = minion as EnemyController
		minion_ok = minion_ok and minion.position.distance_to(boss.position) <= boss.arena_radius
		minion_ok = minion_ok and is_equal_approx((controller.detection_radius.shape as CircleShape2D).radius, maxf(boss.arena_radius * 2.0, 440.0))
		minion_ok = minion_ok and controller.target == player
	_check("minion radius and target", minion_ok)
	_check("Boss HealthBar retains HP", boss.health_bar != null and boss.health_bar.bar.max_value == 300.0)
	_check("health changed event", int(_events["hp"]) == 1)
	boss.take_damage(30)
	_check("boss death event", int(_events["died"]) == 1 and boss.is_dead)
	_check("minions queued on boss death", boss.phase2_minions.is_empty())
	await _test_overrides()
	await _test_explosions()
	_finish()

func _test_overrides() -> void:
	var scene: PackedScene = load("res://scenes/characters/fractured_seal_boss.tscn") as PackedScene
	var boss: FracturedSealBoss = scene.instantiate() as FracturedSealBoss
	boss.max_health = 10
	boss.arena_radius = 180.0
	boss.aoe_damage = 7
	boss.phase2_minion_count = 0
	root.add_child(boss)
	boss.set_physics_process(false)
	boss._set_arena_active(true)
	_check("instance health override survives ready", boss.max_health == 10 and boss.current_health == 10)
	_check("health bar uses overridden max", boss.health_bar.bar.max_value == 10.0 and boss.health_bar.bar.value == 10.0)
	_check("arena and attack overrides survive ready", is_equal_approx((boss.arena_shape.shape as CircleShape2D).radius, 180.0) and boss.aoe_damage == 7 and boss.phase2_minion_count == 0)
	boss.take_damage(10)
	_check("override boss dies in one hit", boss.is_dead and boss.current_health == 0 and not boss.health_bar.visible)
	var inherited: FracturedSealBoss = scene.instantiate() as FracturedSealBoss
	inherited.data = inherited.data.duplicate() as BossData
	inherited.data.max_health = 123
	inherited.data.arena_radius = 190.0
	root.add_child(inherited)
	inherited.set_physics_process(false)
	inherited._set_arena_active(true)
	_check("resource applies to untouched defaults", inherited.max_health == 123 and inherited.current_health == 123 and is_equal_approx(inherited.arena_radius, 190.0))
	inherited.max_health = 20
	inherited.arena_radius = 150.0
	_check("runtime health setter syncs current and bar", inherited.current_health == 20 and inherited.health_bar.bar.max_value == 20.0)
	_check("runtime arena setter syncs detection", is_equal_approx((inherited.arena_shape.shape as CircleShape2D).radius, 150.0))
	inherited.take_damage(5)
	inherited.max_health = 40
	_check("runtime max change preserves damage", inherited.current_health == 35 and inherited.health_bar.bar.max_value == 40.0)
	inherited.queue_free()

func _test_explosions() -> void:
	await create_timer(0.45).timeout
	var scene: PackedScene = load("res://scenes/characters/fractured_seal_boss.tscn") as PackedScene
	for textured: bool in [true, false]:
		var parent: Node2D = Node2D.new()
		parent.position = Vector2(70.0, 45.0)
		parent.scale = Vector2(1.5, 1.5)
		root.add_child(parent)
		var boss: FracturedSealBoss = scene.instantiate() as FracturedSealBoss
		boss.data = boss.data.duplicate() as BossData
		if not textured:
			boss.data.explosion_texture = null
		boss.position = Vector2(388.0, 211.0)
		parent.add_child(boss)
		boss.set_physics_process(false)
		var point: Vector2 = boss.global_position + Vector2(80.0, 20.0)
		boss._detonate(point)
		var effects: Array[Node] = []
		for child: Node in root.find_children("*", "Node2D", true, false):
			if child is FracturedSealBoss.Explosion:
				effects.append(child)
		_check("explosion appears in tree", effects.size() == 1)
		if effects.is_empty():
			parent.queue_free()
			continue
		var effect: Node2D = effects[0] as Node2D
		_check("explosion world position", effect.global_position.is_equal_approx(point))
		_check("explosion visible above floor", effect.is_visible_in_tree() and effect.modulate.a == 1.0 and effect.z_index >= 20)
		var sprite: Sprite2D = effect.get_child(0) as Sprite2D if textured else null
		var initial_frame: int = sprite.frame if sprite != null else -1
		if textured:
			_check("spritesheet frame geometry", sprite != null and sprite.hframes == 6 and sprite.vframes == 24 and sprite.texture.get_size() / Vector2(6.0, 24.0) == Vector2(32.0, 32.0) and initial_frame == 132)
		await create_timer(0.12).timeout
		_check("explosion survives animation start", is_instance_valid(effect))
		if textured and is_instance_valid(sprite):
			_check("explosion sprite animates", sprite.frame > initial_frame and sprite.frame <= 137)
		boss.queue_free()
		await process_frame
		_check("explosion survives boss deletion", is_instance_valid(effect))
		await create_timer(0.45).timeout
		_check("explosion cleans itself up", not is_instance_valid(effect))
		parent.queue_free()

func _finish() -> void:
	print("Test Boss Fractured Seal: %d passed, %d failed" % [passed, failed])
	quit(0 if failed == 0 else 1)
