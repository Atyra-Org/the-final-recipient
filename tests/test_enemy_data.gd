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

	print("=== greedy_gremlin_2 variant loads ===")
	var res2: EnemyData = load("res://resources/enemies/greedy_gremlin_2.tres") as EnemyData
	_check("gg2 tres loads as EnemyData", res2 != null)
	_check("gg2 id unique", res2.id == &"greedy_gremlin_2", str(res2.id))
	_check("gg2 display_name", res2.display_name == "Greedy Gremlin II", res2.display_name)
	_check("gg2 is_invulnerable flag", res2.is_invulnerable, str(res2.is_invulnerable))
	_check("gg2 freeze_when_observed flag", res2.freeze_when_observed, str(res2.freeze_when_observed))
	_check("gg2 observer_fov_angle", res2.observer_fov_angle == 75.0, str(res2.observer_fov_angle))
	_check("gg2 move_speed in 260..300", res2.move_speed >= 260.0 and res2.move_speed <= 300.0, str(res2.move_speed))
	_check("gg2 acceleration high", res2.acceleration >= 2000.0, str(res2.acceleration))
	_check("gg2 detection_radius", res2.detection_radius == 220.0, str(res2.detection_radius))
	_check("gg2 sprite_frames loaded", res2.sprite_frames != null)
	_check("gg2 frames uses v02 sheet", res2.sprite_frames.get_animation_names().size() == 11, str(res2.sprite_frames.get_animation_names().size()))
	_check("gg2 has attack_up", res2.sprite_frames.has_animation("attack_up"))
	_check("base variant stays non-invulnerable", res.is_invulnerable == false, str(res.is_invulnerable))
	_check("base variant stays non-freezing", res.freeze_when_observed == false, str(res.freeze_when_observed))

	print("=== Invulnerable variant resists damage ===")
	var arena: Node = load("res://scenes/sandbox/node_2d.tscn").instantiate()
	root.add_child(arena)
	var g2: EnemyController = arena.get_node("EnemyDummy") as EnemyController
	var foe: Node2D = arena.get_node("Player")
	g2.data = res2
	g2.call("_apply_data")
	g2.current_health = g2.max_health
	await physics_frame
	await physics_frame
	var hp_before: int = g2.current_health
	var knockback: Vector2 = Vector2(500.0, 500.0)
	g2.take_damage(25, knockback)
	_check("invulnerable health unchanged", g2.current_health == hp_before, str(g2.current_health))
	_check("invulnerable state not HURT", g2.current_state != EnemyController.State.HURT, str(g2.current_state))
	_check("invulnerable knockback not applied", g2.velocity != knockback, str(g2.velocity))
	g2.take_damage(9999, knockback)
	_check("invulnerable cannot die", g2.current_health > 0 and g2.current_state != EnemyController.State.DEAD, str(g2.current_health))
	_check("controller mapped is_invulnerable", g2.is_invulnerable)
	_check("controller mapped freeze_when_observed", g2.freeze_when_observed)
	_check("controller mapped observer_fov_angle", g2.observer_fov_angle == 75.0, str(g2.observer_fov_angle))
	_check("controller mapped move_speed 280", g2.move_speed == 280.0, str(g2.move_speed))

	print("=== Freeze when observed by facing player ===")
	g2.global_position = Vector2(500.0, 500.0)
	foe.global_position = g2.global_position + Vector2(-100.0, 0.0)
	foe.set("facing_direction", Vector2(1.0, 0.0))
	g2.target = foe
	g2.current_state = EnemyController.State.CHASE
	for i in range(4):
		await physics_frame
	_check("observed while player faces enemy", g2.call("_is_observed_by", foe), "facing=(1,0) enemy at +x")
	_check("frozen velocity zero", g2.velocity == Vector2.ZERO, str(g2.velocity))
	_check("frozen hitbox disabled", not (g2.get_node("AttackHitbox") as Area2D).monitoring)
	var spr2: AnimatedSprite2D = g2.get_node("AnimatedSprite2D")
	var frame_before: int = spr2.frame
	var anim_before: StringName = spr2.animation
	for i in range(12):
		await physics_frame
	_check("frozen animation frame static", spr2.frame == frame_before, "%d -> %d" % [frame_before, spr2.frame])
	_check("frozen animation name static", spr2.animation == anim_before, str(spr2.animation))
	g2.call("_start_attack")
	_check("frozen cannot start attack", g2.current_state != EnemyController.State.ATTACK, str(g2.current_state))

	print("=== Vision cone respects player facing axis convention ===")
	foe.set("facing_direction", Vector2(0.0, 1.0))
	_check("player facing up (0,1) does not see enemy to the right", not g2.call("_is_observed_by", foe))
	foe.set("facing_direction", Vector2(-1.0, 0.0))
	g2.global_position = foe.global_position + Vector2(-100.0, 0.0)
	_check("player facing left sees enemy on left", g2.call("_is_observed_by", foe))
	g2.global_position = foe.global_position + Vector2(100.0, 0.0)
	_check("player facing left does not see enemy on right", not g2.call("_is_observed_by", foe))
	foe.set("facing_direction", Vector2(0.0, 1.0))
	g2.global_position = foe.global_position + Vector2(0.0, -100.0)
	_check("player facing up sees enemy above", g2.call("_is_observed_by", foe))
	g2.global_position = foe.global_position + Vector2(0.0, 100.0)
	_check("player facing up does not see enemy below", not g2.call("_is_observed_by", foe))

	print("=== Unfreeze when player turns away ===")
	foe.global_position = g2.global_position + Vector2(-100.0, 0.0)
	foe.set("facing_direction", Vector2(-1.0, 0.0))
	g2.target = foe
	g2.current_state = EnemyController.State.CHASE
	for i in range(4):
		await physics_frame
	_check("not observed when player faces away", not g2.call("_is_observed_by", foe))
	var dist_pre: float = g2.global_position.distance_to(foe.global_position)
	for i in range(8):
		await physics_frame
	var dist_post: float = g2.global_position.distance_to(foe.global_position)
	_check("unfrozen enemy chases fast", dist_post < dist_pre, "%.2f -> %.2f" % [dist_pre, dist_post])
	_check("unfrozen enemy moved >20px in 8 frames", dist_pre - dist_post > 20.0, "%.2f px" % (dist_pre - dist_post))
	_check("unfrozen animation playing", spr2.is_playing(), str(spr2.is_playing()))

	print("=== Regression: test_line_of_sight.tscn conditions ===")
	var scene_los: Node = load("res://scenes/sandbox/test_line_of_sight.tscn").instantiate()
	root.add_child(scene_los)
	await physics_frame
	await physics_frame
	var g2_los: EnemyController = scene_los.get_node("EnemyDummy") as EnemyController
	var foe_los: Node2D = scene_los.get_node("Player")
	_check("los scene uses base enemy data", g2_los.data.id == &"greedy_gremlin", str(g2_los.data.id))
	_check("los scene does not enable observation freeze", not g2_los.data.freeze_when_observed)
	g2_los.data = res2
	g2_los.call("_apply_data")
	g2_los.current_health = g2_los.max_health
	_check("los controller has freeze flag after apply", g2_los.freeze_when_observed)
	_check("los detection monitoring", (g2_los.get_node("DetectionArea") as Area2D).monitoring)
	_check("los enemy detection radius applied", is_equal_approx((g2_los.get_node("DetectionArea/DetectionRadius").shape as CircleShape2D).radius, 220.0))
	_check("los player initial facing before input", foe_los.get("facing_direction") == Vector2(0.0, 1.0), str(foe_los.get("facing_direction")))
	_check("default player facing does not observe enemy to the right", not g2_los.call("_is_observed_by", foe_los))
	var d0_los: float = g2_los.global_position.distance_to(foe_los.global_position)
	g2_los.current_state = EnemyController.State.CHASE
	g2_los.target = foe_los
	for i in range(10):
		await physics_frame
	var d1_los: float = g2_los.global_position.distance_to(foe_los.global_position)
	_check("enemy chases while outside observer FOV", d1_los < d0_los, "%.2f -> %.2f" % [d0_los, d1_los])
	foe_los.set("facing_direction", Vector2(1.0, 0.0))
	for i in range(4):
		await physics_frame
	_check("player facing right observes enemy", g2_los.call("_is_observed_by", foe_los))
	_check("los enemy frozen velocity", g2_los.velocity == Vector2.ZERO, str(g2_los.velocity))
	_check("los enemy frozen hitbox off", not (g2_los.get_node("AttackHitbox") as Area2D).monitoring)
	_check("los enemy did not start attack while observed", g2_los.current_state != EnemyController.State.ATTACK, str(g2_los.current_state))
	g2_los.call("_start_attack")
	_check("los enemy cannot start attack while observed", g2_los.current_state != EnemyController.State.ATTACK, str(g2_los.current_state))
	foe_los.set("facing_direction", Vector2(-1.0, 0.0))
	for i in range(8):
		await physics_frame
	_check("los enemy resumes chase when player turns away", g2_los.velocity.length() > 0.0, str(g2_los.velocity.length()))
	scene_los.queue_free()

	print("=== Wall blocks freeze (line of sight) ===")
	var wall: StaticBody2D = StaticBody2D.new()
	var wall_shape: CollisionShape2D = CollisionShape2D.new()
	var wall_rect: RectangleShape2D = RectangleShape2D.new()
	wall_rect.size = Vector2(16.0, 200.0)
	wall_shape.shape = wall_rect
	wall.collision_layer = 1
	wall.collision_mask = 0
	wall.add_child(wall_shape)
	root.add_child(wall)
	g2.global_position = Vector2(500.0, 500.0)
	foe.global_position = g2.global_position + Vector2(-100.0, 0.0)
	wall.global_position = g2.global_position + Vector2(-50.0, 0.0)
	foe.set("facing_direction", Vector2(1.0, 0.0))
	g2.target = foe
	g2.current_state = EnemyController.State.CHASE
	for i in range(4):
		await physics_frame
	_check("line of sight blocked by wall", not g2.call("_has_line_of_sight", foe))
	_check("wall prevents freeze", not g2.call("_is_observed_by", foe))
	_check("not frozen behind wall", g2.call("_update_observed_state") == false)
	wall.queue_free()
	arena.queue_free()

	print("=== %d checks, %d failed ===" % [_pass + _fail, _fail])
	quit(0 if _fail == 0 else 1)
