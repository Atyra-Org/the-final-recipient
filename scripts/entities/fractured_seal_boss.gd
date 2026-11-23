class_name FracturedSealBoss
extends StaticBody2D

signal died
signal arena_state_changed(active: bool)

const BOSS_BAR_SCENE: PackedScene = preload("res://scenes/ui/boss_health_bar.tscn")
const WORLD_MASK: int = 1

@export var data: BossData = null

@export_category("Arena")
@export var arena_radius: float = 220.0
@export var chain_count: int = 4
@export var chain_rotation_speed: float = 0.65
@export var chain_damage: int = 15
@export var chain_knockback: float = 180.0
@export var chain_hit_cooldown: float = 0.6
@export var chain_width: float = 8.0
@export var target_group: StringName = &"player"

@export_category("Stats")
@export var max_health: int = 300

@onready var hurtbox: Area2D = $Hurtbox
@onready var arena_area: Area2D = $ArenaArea
@onready var arena_shape: CollisionShape2D = $ArenaArea/ArenaShape
@onready var core: Node2D = $Core
@onready var core_sprite: Sprite2D = $Core/CoreSprite
@onready var core_seal: Polygon2D = $Core/CoreSeal
@onready var chains: Node2D = $Chains

var current_health: int = 300
var is_dead: bool = false
var spawn_position: Vector2 = Vector2.ZERO
var arena_active: bool = false
var health_bar: BossHealthBar = null

var _chain_roots: Array[Node2D] = []
var _chain_lines: Array[Line2D] = []
var _chain_areas: Array[Area2D] = []
var _chain_rects: Array[RectangleShape2D] = []
var _chain_reaches: Array[float] = []
var _hit_cooldowns: Dictionary = {}
var _bob_time: float = 0.0
var _base_core_scale: Vector2 = Vector2.ONE
var _squash_tween: Tween = null


func _ready() -> void:
	add_to_group(&"enemy")
	add_to_group(&"boss")
	_apply_data()
	spawn_position = global_position
	current_health = max_health
	_base_core_scale = core.scale
	_apply_arena_radius()
	_build_chains()
	_set_arena_active(false)
	var event_bus: Node = _get_event_bus()
	if event_bus != null:
		event_bus.emit_signal(&"enemy_spawned", self, _get_boss_id())


func _apply_data() -> void:
	if data == null:
		return
	max_health = data.max_health
	arena_radius = data.arena_radius
	chain_count = maxi(data.chain_count, 1)
	chain_rotation_speed = data.chain_rotation_speed
	chain_damage = data.chain_damage
	chain_knockback = data.chain_knockback
	chain_hit_cooldown = data.chain_hit_cooldown
	chain_width = data.chain_width
	target_group = data.target_group
	_apply_visual_data()


func _apply_visual_data() -> void:
	if data == null:
		return
	core.scale = data.core_scale
	if data.core_texture != null:
		core_sprite.texture = data.core_texture
		core_sprite.visible = true
		core_seal.visible = false


func _apply_arena_radius() -> void:
	var shape: Shape2D = arena_shape.shape
	if shape is CircleShape2D:
		var circle: CircleShape2D = shape.duplicate() as CircleShape2D
		circle.radius = arena_radius
		arena_shape.shape = circle


func _build_chains() -> void:
	for i: int in chain_count:
		var chain_root: Node2D = Node2D.new()
		chain_root.name = "Chain%d" % i
		chain_root.rotation = (TAU / float(chain_count)) * float(i)

		var line: Line2D = Line2D.new()
		line.name = "Line"
		line.width = chain_width
		line.default_color = Color(0.36, 0.09, 0.42, 0.9)
		line.joint_mode = Line2D.LINE_JOINT_ROUND
		line.begin_cap_mode = Line2D.LINE_CAP_ROUND
		line.end_cap_mode = Line2D.LINE_CAP_ROUND
		if data != null and data.chain_texture != null:
			line.texture = data.chain_texture
			line.texture_mode = Line2D.LINE_TEXTURE_TILE

		var hitbox: Area2D = Area2D.new()
		hitbox.name = "Hitbox"
		hitbox.collision_layer = 16
		hitbox.collision_mask = 2
		hitbox.monitorable = false

		var shape_node: CollisionShape2D = CollisionShape2D.new()
		shape_node.name = "CollisionShape2D"
		var rect: RectangleShape2D = RectangleShape2D.new()
		rect.size = Vector2(arena_radius, chain_width)
		shape_node.shape = rect

		hitbox.add_child(shape_node)
		chain_root.add_child(line)
		chain_root.add_child(hitbox)
		chains.add_child(chain_root)

		_chain_roots.append(chain_root)
		_chain_lines.append(line)
		_chain_areas.append(hitbox)
		_chain_rects.append(rect)
		_chain_reaches.append(arena_radius)


func _physics_process(delta: float) -> void:
	if is_dead:
		return
	_tick_cooldowns(delta)
	var inside: bool = _is_target_inside_arena()
	if inside != arena_active:
		_set_arena_active(inside)
	if not arena_active:
		return
	for i: int in _chain_roots.size():
		var chain_root: Node2D = _chain_roots[i]
		chain_root.rotation = wrapf(chain_root.rotation + chain_rotation_speed * delta, 0.0, TAU)
		_refresh_chain_reach(i)
		_apply_chain_damage(i)


func _process(delta: float) -> void:
	_bob_time += delta
	core.position.y = sin(_bob_time * 1.6) * 3.0


func _is_target_inside_arena() -> bool:
	for body: Node2D in arena_area.get_overlapping_bodies():
		if body.is_in_group(target_group):
			return true
	return false


func _set_arena_active(active: bool) -> void:
	arena_active = active
	chains.visible = active
	for area: Area2D in _chain_areas:
		area.monitoring = active
	if active and is_instance_valid(health_bar):
		health_bar.visible = true
	elif is_instance_valid(health_bar):
		health_bar.visible = false
	if active:
		_ensure_health_bar()
	arena_state_changed.emit(active)


func _ensure_health_bar() -> void:
	if is_instance_valid(health_bar):
		return
	var scene_root: Node = get_tree().current_scene
	if not is_instance_valid(scene_root):
		scene_root = get_tree().root
	health_bar = BOSS_BAR_SCENE.instantiate() as BossHealthBar
	scene_root.add_child(health_bar)
	health_bar.setup(_get_boss_name(), max_health)
	health_bar.set_health(current_health, max_health)


func _refresh_chain_reach(i: int) -> void:
	var chain_root: Node2D = _chain_roots[i]
	var direction: Vector2 = Vector2.RIGHT.rotated(chain_root.global_rotation)
	var reach: float = arena_radius
	var query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(global_position, global_position + direction * arena_radius, WORLD_MASK)
	var hit: Dictionary = get_world_2d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		reach = global_position.distance_to(hit["position"]) - chain_width * 0.5
	reach = clampf(reach, chain_width, arena_radius)
	_chain_reaches[i] = reach
	var line: Line2D = _chain_lines[i]
	var points: PackedVector2Array = PackedVector2Array([Vector2.ZERO, Vector2(reach, 0.0)])
	line.points = points
	var rect: RectangleShape2D = _chain_rects[i]
	rect.size = Vector2(reach, chain_width)
	var shape_node: CollisionShape2D = _chain_areas[i].get_child(0) as CollisionShape2D
	shape_node.position = Vector2(reach * 0.5, 0.0)


func _apply_chain_damage(i: int) -> void:
	var knockback_direction: Vector2 = Vector2.RIGHT.rotated(_chain_roots[i].global_rotation)
	for body: Node2D in _chain_areas[i].get_overlapping_bodies():
		if not body.is_in_group(target_group):
			continue
		var key: int = body.get_instance_id()
		if _hit_cooldowns.has(key) and float(_hit_cooldowns[key]) > 0.0:
			continue
		_hit_cooldowns[key] = chain_hit_cooldown
		var away: Vector2 = global_position.direction_to(body.global_position)
		if away.is_zero_approx():
			away = knockback_direction
		if body.has_method(&"take_damage"):
			body.take_damage(chain_damage, away * chain_knockback)


func _tick_cooldowns(delta: float) -> void:
	for key: int in _hit_cooldowns.keys():
		var remaining: float = float(_hit_cooldowns[key]) - delta
		if remaining <= 0.0:
			_hit_cooldowns.erase(key)
		else:
			_hit_cooldowns[key] = remaining


func take_damage(amount: int, _knockback_force: Vector2 = Vector2.ZERO) -> void:
	if is_dead or amount <= 0:
		return
	current_health = maxi(current_health - amount, 0)
	_spawn_damage_number(amount)
	_play_hit_squash()
	if is_instance_valid(health_bar):
		health_bar.set_health(current_health, max_health)
	var event_bus: Node = _get_event_bus()
	if event_bus != null:
		event_bus.emit_signal(&"enemy_health_changed", self, _get_boss_id(), current_health, max_health)
	if current_health == 0:
		_die()


func _die() -> void:
	if is_dead:
		return
	is_dead = true
	_set_arena_active(false)
	_disable_chains()
	died.emit()
	var event_bus: Node = _get_event_bus()
	if event_bus != null:
		event_bus.emit_signal(&"enemy_died", self, _get_boss_id(), global_position)
	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(core, "scale", Vector2.ZERO, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.tween_property(core, "rotation", 2.4, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(core, "modulate:a", 0.0, 0.35)
	tween.chain().tween_callback(queue_free)


func _disable_chains() -> void:
	chains.visible = false
	for area: Area2D in _chain_areas:
		area.set_deferred(&"monitoring", false)
		area.set_deferred(&"monitorable", false)
	_hit_cooldowns.clear()


func _play_hit_squash() -> void:
	if _squash_tween != null and _squash_tween.is_valid():
		_squash_tween.kill()
	core.scale = Vector2(_base_core_scale.x * 1.14, _base_core_scale.y * 0.86)
	_squash_tween = create_tween()
	_squash_tween.tween_property(core, "scale", _base_core_scale, 0.22).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


func _spawn_damage_number(amount: int) -> void:
	var dmg_label: Label = Label.new()
	dmg_label.text = str(amount)
	dmg_label.z_index = 10
	dmg_label.add_theme_font_size_override(&"font_size", 13)
	dmg_label.add_theme_color_override(&"font_color", Color(1.0, 0.34, 0.34))
	dmg_label.add_theme_color_override(&"font_outline_color", Color.BLACK)
	dmg_label.add_theme_constant_override(&"outline_size", 4)
	var scene_root: Node = get_tree().current_scene
	if is_instance_valid(scene_root):
		scene_root.add_child(dmg_label)
	else:
		get_parent().add_child(dmg_label)
	dmg_label.global_position = global_position + Vector2(randf_range(-16.0, 8.0), randf_range(-42.0, -26.0))
	var tween: Tween = dmg_label.create_tween()
	tween.set_parallel(true)
	tween.tween_property(dmg_label, "global_position:y", dmg_label.global_position.y - 24.0, 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(dmg_label, "modulate:a", 0.0, 0.55).set_delay(0.12)
	tween.chain().tween_callback(dmg_label.queue_free)


func get_chain_reach(i: int) -> float:
	if i < 0 or i >= _chain_reaches.size():
		return 0.0
	return _chain_reaches[i]


func _get_boss_id() -> String:
	if data != null and not data.id.is_empty():
		return String(data.id)
	return "the_fractured_seal"


func _get_boss_name() -> String:
	if data != null and not data.boss_name.is_empty():
		return data.boss_name
	return "The Fractured Seal"


func _get_event_bus() -> Node:
	var tree: SceneTree = get_tree()
	if tree == null or tree.root == null:
		return null
	return tree.root.get_node_or_null(^"EventBus")