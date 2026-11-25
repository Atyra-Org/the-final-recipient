extends SceneTree

const EnemyScene: PackedScene = preload("res://scenes/characters/enemy_dummy.tscn")
const BusScript: Script = preload("res://scripts/core/event_bus.gd")

var _started: bool = false
var _checks: int = 0
var _failures: int = 0

func _process(_delta: float) -> bool:
	if not _started:
		_started = true
		_run.call_deferred()
	return false

func _check(label: String, condition: bool) -> void:
	_checks += 1
	if not condition:
		_failures += 1
	print("PASS " if condition else "FAIL ", label)

func _run() -> void:
	var data: EnemyData = load("res://resources/enemies/greedy_gremlin.tres") as EnemyData
	var sheet: Texture2D = load("res://assets/sprites/effects/greedy_gremlin_bind.png") as Texture2D
	_check("sheet dimensions", sheet.get_size() == Vector2(2445, 176))
	var directions: Array[String] = ["down", "up", "side"]
	for row: int in 3:
		var animation: StringName = StringName("bind_" + directions[row])
		_check(String(animation) + " exists", data.sprite_frames.has_animation(animation))
		if not data.sprite_frames.has_animation(animation):
			continue
		_check(String(animation) + " ten frames", data.sprite_frames.get_frame_count(animation) == 10)
		for column: int in data.sprite_frames.get_frame_count(animation):
			var frame: AtlasTexture = data.sprite_frames.get_frame_texture(animation, column) as AtlasTexture
			_check("valid atlas %s %d" % [animation, column], frame != null and frame.atlas == sheet)
			if frame != null:
				var expected: Rect2 = Rect2(column * 245, row * 58, 240 if column == 9 else 245, 60 if row == 2 else 58)
				_check("exact region %s %d" % [animation, column], frame.region == expected)
				_check("visible pixels %s %d" % [animation, column], not sheet.get_image().get_region(Rect2i(frame.region)).is_invisible())
	var bus: Node = root.get_node_or_null(^"EventBus")
	if bus == null:
		bus = BusScript.new()
		bus.name = "EventBus"
		root.add_child(bus)
	_check("bind signal declared", bus.has_signal(&"enemy_bind_requested"))
	var enemy: EnemyController = EnemyScene.instantiate() as EnemyController
	enemy.use_navigation = false
	enemy.require_line_of_sight = false
	root.add_child(enemy)
	enemy.require_line_of_sight = false
	var other: EnemyController = EnemyScene.instantiate() as EnemyController
	other.position = Vector2(1000, 1000)
	root.add_child(other)
	other.set_physics_process(false)
	var target: Node2D = Node2D.new()
	target.position = Vector2(400, 0)
	root.add_child(target)
	_check("apply_bind public API", enemy.has_method(&"apply_bind"))
	if enemy.has_method(&"apply_bind"):
		enemy.set_physics_process(false)
		for direction: String in directions:
			enemy.facing_direction = direction
			enemy.animated_sprite.flip_h = direction == "side"
			enemy.velocity = Vector2(70, 50)
			enemy.attack_hitbox.monitoring = true
			enemy.call(&"apply_bind", 1.5)
			await process_frame
			_check("bound stops immediately", enemy.velocity == Vector2.ZERO and not enemy.attack_hitbox.monitoring)
			_check("direction " + direction, enemy.animated_sprite.animation == StringName("bind_" + direction))
			_check("pixel art nearest", enemy.animated_sprite.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST)
			_check("side flip preserved", enemy.animated_sprite.flip_h == (direction == "side"))
			enemy.call(&"_start_attack")
			_check("cannot attack bound", enemy.current_state != EnemyController.State.ATTACK)
		var initial_frame: int = enemy.animated_sprite.frame
		await create_timer(0.15).timeout
		_check("bind animation advances", enemy.animated_sprite.frame != initial_frame)
		var hp: int = enemy.current_health
		enemy.take_damage(3, Vector2(200, 100))
		_check("damage preserves bind", enemy.current_health == hp - 3 and enemy.velocity == Vector2.ZERO and enemy.animated_sprite.animation == &"bind_side")
		enemy._on_detection_area_body_entered(target)
		_check("detection cannot break bind", enemy.animated_sprite.animation == &"bind_side")
		enemy.target = target
		enemy.set_physics_process(true)
		var before: Vector2 = enemy.position
		await create_timer(0.1).timeout
		_check("physics stays frozen", enemy.position == before and enemy.velocity == Vector2.ZERO)
		if bus.has_signal(&"enemy_bind_requested"):
			bus.emit_signal(&"enemy_bind_requested", enemy, 0.15)
			_check("signal targets one enemy", enemy.velocity == Vector2.ZERO and other.get("bind_timer") == 0.0)
		await create_timer(1.6).timeout
		_check("expiry resumes chase", enemy.current_state == EnemyController.State.CHASE and enemy.position.distance_to(target.position) < before.distance_to(target.position))
		_check("normal animation restored", not String(enemy.animated_sprite.animation).begins_with("bind_"))
		enemy.set_physics_process(false)
		if bus.has_signal(&"enemy_bind_requested"):
			enemy.velocity = Vector2(70, 0)
			bus.emit_signal(&"enemy_bind_requested", enemy, 0.1)
			_check("signal applies bind", enemy.velocity == Vector2.ZERO and String(enemy.animated_sprite.animation).begins_with("bind_"))
			enemy._physics_process(0.2)
			enemy._physics_process(0.1)
		_check("signal bind expires", enemy.current_state != EnemyController.State.ATTACK and not String(enemy.animated_sprite.animation).begins_with("bind_"))
		var variant: EnemyData = load("res://resources/enemies/greedy_gremlin_2.tres") as EnemyData
		other.data = variant
		other._apply_data()
		var original: Color = other.animated_sprite.modulate
		other.call(&"apply_bind", 0.1)
		_check("variant uses separate frames", other.animated_sprite.sprite_frames != data.sprite_frames and variant.is_invulnerable and variant.freeze_when_observed)
		_check("missing animation gold fallback", other.animated_sprite.modulate != original)
		other._physics_process(0.2)
		_check("fallback color restored", other.animated_sprite.modulate == original)
		_check("no target expires to idle", other.current_state == EnemyController.State.IDLE)
		var health: int = other.current_health
		other.take_damage(4)
		_check("variant invulnerability preserved", other.current_health == health)
		for duration: float in [0.0, -1.0, INF, NAN]:
			enemy.call(&"apply_bind", duration)
		_check("invalid durations ignored", enemy.get("bind_timer") == 0.0)
		enemy.call(&"apply_bind")
		_check("default duration", enemy.bind_timer == 2.5)
		enemy.call(&"apply_bind", 0.1)
		_check("rebind never shortens", enemy.bind_timer == 2.5)
		enemy.call(&"apply_bind", 0.1)
		enemy.take_damage(999)
		enemy.call(&"apply_bind", 2.0)
		_check("death never resurrected", enemy.current_state == EnemyController.State.DEAD)
	enemy.queue_free()
	other.queue_free()
	target.queue_free()
	await process_frame
	print("=== %d checks, %d failed ===" % [_checks, _failures])
	quit(0 if _failures == 0 else 1)
