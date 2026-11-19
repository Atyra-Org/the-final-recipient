extends SceneTree

var _pass: int = 0
var _fail: int = 0

func _initialize() -> void:
	call_deferred("_run")

func _check(label: String, cond: bool, detail: String = "") -> void:
	if cond:
		_pass += 1
		print("  PASS  ", label, (" :: " + detail) if detail != "" else "")
	else:
		_fail += 1
		print("  FAIL  ", label, (" :: " + detail) if detail != "" else "")

func _run() -> void:
	print("=== EnemyData resource load ===")
	var res: EnemyData = load("res://resources/enemies/greedy_gremlin.tres") as EnemyData
	_check("tres loads as EnemyData", res != null)
	_check("id set", res.id == &"greedy_gremlin", str(res.id))
	_check("display_name set", res.display_name == "Greedy Gremlin", res.display_name)
	_check("max_health", res.max_health == 50, str(res.max_health))
	_check("move_speed", res.move_speed == 80.0, str(res.move_speed))
	_check("attack_damage", res.attack_damage == 10, str(res.attack_damage))
	_check("attack_range", res.attack_range == 28.0, str(res.attack_range))
	_check("detection_radius", res.detection_radius == 140.34, str(res.detection_radius))
	_check("target_group", res.target_group == &"player", str(res.target_group))
	_check("attack_active_frames", res.attack_active_frames == [1, 2], str(res.attack_active_frames))
	_check("sprite_frames assigned", res.sprite_frames != null)
	_check("sprite_frames has run_down", res.sprite_frames.has_animation("run_down") if res.sprite_frames else false)
	_check("sprite_frames anim count == 11", res.sprite_frames.get_animation_names().size() == 11, str(res.sprite_frames.get_animation_names().size()))

	print("=== Scene applies EnemyData to controller ===")
	var scene: Node = load("res://scenes/sandbox/node_2d.tscn").instantiate()
	root.add_child(scene)
	var enemy: Node2D = scene.get_node("EnemyDummy")
	var player: Node2D = scene.get_node("Player")
	await physics_frame
	await physics_frame

	_check("scene has data assigned", enemy.get("data") != null)
	_check("controller max_health from data", enemy.get("max_health") == 50, str(enemy.get("max_health")))
	_check("controller current_health initialised", enemy.get("current_health") == 50, str(enemy.get("current_health")))
	_check("controller move_speed from data", enemy.get("move_speed") == 80.0, str(enemy.get("move_speed")))
	_check("controller attack_range from data", enemy.get("attack_range") == 28.0, str(enemy.get("attack_range")))
	var spr: AnimatedSprite2D = enemy.get_node("AnimatedSprite2D")
	_check("sprite_frames applied from data", spr.sprite_frames == res.sprite_frames)
	var det: CollisionShape2D = enemy.get_node("DetectionArea/DetectionRadius")
	_check("detection radius applied", is_equal_approx((det.shape as CircleShape2D).radius, 140.34), str((det.shape as CircleShape2D).radius))
	var hp: ProgressBar = enemy.get_node("HealthBar")
	_check("health bar max from data", hp.max_value == 50.0, str(hp.max_value))

	print("=== Shared resource not mutated per instance ===")
	var scene2: Node = load("res://scenes/sandbox/node_2d.tscn").instantiate()
	root.add_child(scene2)
	await physics_frame
	var enemy2: Node2D = scene2.get_node("EnemyDummy")
	enemy2.set("max_health", 999)
	_check("instance field does not leak into resource", res.max_health == 50, str(res.max_health))
	_check("second instance unaffected", enemy2.get("current_health") == 50, str(enemy2.get("current_health")))
	scene2.queue_free()

	print("=== Fallback when data is null ===")
	var bare: EnemyController = load("res://scenes/characters/enemy_dummy.tscn").instantiate() as EnemyController
	bare.data = null
	root.add_child(bare)
	await physics_frame
	await physics_frame
	_check("null data -> default max_health", bare.max_health == 50, str(bare.max_health))
	_check("null data -> default move_speed", bare.move_speed == 80.0, str(bare.move_speed))
	_check("null data -> sprite_frames kept", bare.get_node("AnimatedSprite2D").sprite_frames != null)
	_check("null data -> no crash on state machine", bare.current_state != null)
	bare.queue_free()

	print("=== State machine still functional ===")
	enemy.set("current_state", 2)
	enemy.set("target", player)
	var d0: float = enemy.global_position.distance_to(player.global_position)
	for i in range(30):
		await physics_frame
	var d1: float = enemy.global_position.distance_to(player.global_position)
	_check("chase closes distance", d1 < d0, "%.2f -> %.2f" % [d0, d1])
	player.global_position = enemy.global_position + Vector2(0.0, -60.0)
	for i in range(10):
		await physics_frame
	_check("facing follows player above", enemy.get("facing_direction") == "up", str(enemy.get("facing_direction")))
	enemy.call("_update_hitbox_transform")
	_check("hitbox offset above", (enemy.get_node("AttackHitbox") as Area2D).position == Vector2(0.0, -18.0), str((enemy.get_node("AttackHitbox") as Area2D).position))

	print("=== %d checks, %d failed ===" % [_pass + _fail, _fail])
	quit(0 if _fail == 0 else 1)
