class_name FracturedSealBoss
extends StaticBody2D

signal died
signal arena_state_changed(active: bool)

const BOSS_BAR_SCENE: PackedScene = preload("res://scenes/ui/boss_health_bar.tscn")
const TELEGRAPH_COLOR: Color = Color(0.95, 0.25, 0.05, 0.95)
const TELEGRAPH_FILL: Color = Color(0.85, 0.08, 0.04, 0.28)

class Telegraph extends Node2D:
	var radius: float = 56.0
	var progress: float = 0.0
	var locked: bool = false
	var pulse: float = 0.0

	func _process(delta: float) -> void:
		pulse += delta
		queue_redraw()

	func _draw() -> void:
		var flash: float = 0.15 if locked and fmod(pulse * 10.0, 2.0) < 1.0 else 0.0
		draw_circle(Vector2.ZERO, radius, Color(TELEGRAPH_FILL.r + flash, TELEGRAPH_FILL.g, TELEGRAPH_FILL.b, TELEGRAPH_FILL.a))
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 48, TELEGRAPH_COLOR, 4.0, false)
		draw_arc(Vector2.ZERO, radius * 0.82, 0.0, TAU, 48, Color(1.0, 0.5, 0.08, 0.75), 2.0, false)
		draw_arc(Vector2.ZERO, radius * progress, 0.0, TAU, 32, Color(1.0, 0.75, 0.12, 0.95), 4.0, false)
		for i: int in 8:
			var angle: float = TAU * float(i) / 8.0
			draw_line(Vector2.from_angle(angle) * radius * 0.9, Vector2.from_angle(angle) * radius, Color(1.0, 0.4, 0.08, 0.75), 2.0)

class Explosion extends Node2D:
	var radius: float = 56.0
	var age: float = 0.0
	var duration: float = 0.35

	func _process(delta: float) -> void:
		age += delta
		queue_redraw()
		if age >= duration:
			queue_free()

	func _draw() -> void:
		var ratio: float = clampf(age / duration, 0.0, 1.0)
		var alpha: float = 1.0 - ratio
		draw_circle(Vector2.ZERO, radius * (0.45 + ratio * 0.55), Color(1.0, 0.16, 0.03, alpha * 0.42))
		draw_arc(Vector2.ZERO, radius * (0.65 + ratio * 0.35), 0.0, TAU, 40, Color(1.0, 0.62, 0.08, alpha), 6.0, false)
		for i: int in 8:
			var direction: Vector2 = Vector2.from_angle(TAU * float(i) / 8.0)
			draw_line(direction * radius * 0.3, direction * radius * (0.7 + ratio * 0.5), Color(1.0, 0.2, 0.04, alpha), 3.0)

@export var data: BossData = null

@export_category("Arena And AoE Telegraph")
@export var arena_radius: float = 220.0
@export var aoe_radius: float = 56.0
@export var aoe_charge_duration: float = 1.6
@export var aoe_lock_ratio: float = 0.8
@export var aoe_cooldown: float = 1.4
@export var aoe_damage: int = 20
@export var aoe_knockback: float = 200.0
@export var target_group: StringName = &"player"

@export_category("Phase Two")
@export var phase2_health_threshold: int = 30
@export var phase2_tint: Color = Color(1.0, 0.3, 0.45, 1.0)
@export var phase2_minion_scene: PackedScene = preload("res://scenes/characters/enemy_dummy.tscn")
@export var phase2_minion_data: Resource = preload("res://resources/enemies/greedy_gremlin.tres")
@export var phase2_minion_count: int = 2
@export var phase2_aoe_cooldown_multiplier: float = 0.75

@export_category("Stats")
@export var max_health: int = 300

@onready var arena_area: Area2D = $ArenaArea
@onready var arena_shape: CollisionShape2D = $ArenaArea/ArenaShape
@onready var core: Node2D = $Core
@onready var core_sprite: Sprite2D = $Core/CoreSprite
@onready var core_seal: Polygon2D = $Core/CoreSeal
@onready var telegraphs: Node2D = $Telegraphs

var current_health: int = 300
var is_dead: bool = false
var phase2_active: bool = false
var spawn_position: Vector2 = Vector2.ZERO
var arena_active: bool = false
var health_bar: BossHealthBar = null

var active_telegraph: Node2D = null
var telegraph_progress: float = 0.0
var aoe_cooldown_timer: float = 0.0
var locked_position: Vector2 = Vector2.ZERO
var phase2_minions: Array[Node2D] = []
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
	_set_arena_active(false)
	var event_bus: Node = _get_event_bus()
	if event_bus != null:
		event_bus.emit_signal(&"enemy_spawned", self, _get_boss_id())


func _apply_data() -> void:
	if data == null:
		return
	max_health = data.max_health
	arena_radius = data.arena_radius
	aoe_radius = data.aoe_radius
	aoe_charge_duration = data.aoe_charge_duration
	aoe_lock_ratio = data.aoe_lock_ratio
	aoe_cooldown = data.aoe_cooldown
	aoe_damage = data.aoe_damage
	aoe_knockback = data.aoe_knockback
	target_group = data.target_group
	phase2_health_threshold = data.phase2_health_threshold
	phase2_tint = data.phase2_tint
	phase2_minion_scene = data.phase2_minion_scene
	phase2_minion_data = data.phase2_minion_data
	phase2_minion_count = data.phase2_minion_count
	phase2_aoe_cooldown_multiplier = data.phase2_aoe_cooldown_multiplier
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


func _physics_process(delta: float) -> void:
	if is_dead:
		return
	var inside: bool = _is_target_inside_arena()
	if inside != arena_active:
		_set_arena_active(inside)
	if not arena_active:
		return
	if aoe_cooldown_timer > 0.0:
		aoe_cooldown_timer = maxf(aoe_cooldown_timer - delta, 0.0)
	if active_telegraph == null and aoe_cooldown_timer <= 0.0:
		_start_telegraph()
	if active_telegraph != null:
		_process_telegraph(delta)


func _process(delta: float) -> void:
	_bob_time += delta
	core.position.y = sin(_bob_time * 1.6) * 3.0


func _get_target() -> Node2D:
	for body: Node2D in arena_area.get_overlapping_bodies():
		if body.is_in_group(target_group):
			return body
	return null


func _is_target_inside_arena() -> bool:
	return _get_target() != null


func _set_arena_active(active: bool) -> void:
	arena_active = active
	if active:
		_ensure_health_bar()
	if is_instance_valid(health_bar):
		health_bar.visible = active
	if not active:
		_clear_telegraph()
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


func _start_telegraph() -> void:
	active_telegraph = Telegraph.new()
	active_telegraph.radius = aoe_radius
	active_telegraph.position = global_position
	telegraphs.add_child(active_telegraph)
	telegraph_progress = 0.0
	locked_position = global_position


func _process_telegraph(delta: float) -> void:
	if active_telegraph == null:
		return
	telegraph_progress += delta / aoe_charge_duration
	active_telegraph.set("progress", clampf(telegraph_progress, 0.0, 1.0))
	if telegraph_progress < aoe_lock_ratio:
		var target: Node2D = _get_target()
		if is_instance_valid(target):
			locked_position = _clamp_to_arena(target.global_position)
			active_telegraph.global_position = locked_position
	else:
		active_telegraph.set("locked", true)
	if telegraph_progress >= 1.0:
		_detonate(locked_position)


func _clamp_to_arena(world_position: Vector2) -> Vector2:
	var offset: Vector2 = world_position - global_position
	var maximum: float = maxf(arena_radius - aoe_radius, 0.0)
	if offset.length() > maximum:
		offset = offset.normalized() * maximum
	return global_position + offset


func _detonate(position: Vector2) -> void:
	_clear_telegraph()
	aoe_cooldown_timer = aoe_cooldown * (phase2_aoe_cooldown_multiplier if phase2_active else 1.0)
	var explosion: Explosion = Explosion.new()
	explosion.radius = aoe_radius
	explosion.global_position = position
	telegraphs.add_child(explosion)
	if data != null and data.explosion_texture != null:
		var sprite: Sprite2D = Sprite2D.new()
		sprite.texture = data.explosion_texture
		sprite.hframes = data.explosion_hframes
		sprite.vframes = data.explosion_vframes
		sprite.frame = data.explosion_row * data.explosion_hframes
		sprite.scale = Vector2.ONE * aoe_radius / 32.0
		sprite.modulate.a = 0.9
		explosion.add_child(sprite)
		var sprite_tween: Tween = sprite.create_tween()
		sprite_tween.tween_property(sprite, "modulate:a", 0.0, explosion.duration)
	var target: Node2D = _get_target()
	if is_instance_valid(target) and target.global_position.distance_to(position) <= aoe_radius and target.global_position.distance_to(global_position) <= arena_radius:
		var direction: Vector2 = position.direction_to(target.global_position)
		if direction.is_zero_approx():
			direction = Vector2.RIGHT
		if target.has_method(&"take_damage"):
			target.take_damage(aoe_damage, direction * aoe_knockback)


func _clear_telegraph() -> void:
	if is_instance_valid(active_telegraph):
		active_telegraph.queue_free()
	active_telegraph = null
	telegraph_progress = 0.0


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
	if not phase2_active and current_health <= phase2_health_threshold and current_health > 0:
		_activate_phase2()
	if current_health == 0:
		_die()


func _die() -> void:
	if is_dead:
		return
	is_dead = true
	_clear_telegraph()
	for minion: Node2D in phase2_minions:
		if is_instance_valid(minion):
			minion.queue_free()
	phase2_minions.clear()
	_set_arena_active(false)
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


func _activate_phase2() -> void:
	phase2_active = true
	var transition: Tween = create_tween()
	transition.tween_property(core_seal, "color", phase2_tint, 0.45)
	transition.parallel().tween_property(core, "scale", _base_core_scale * 1.2, 0.2)
	transition.tween_property(core, "scale", _base_core_scale, 0.25)
	_spawn_phase2_minions()


func _spawn_phase2_minions() -> void:
	var target: Node2D = _get_target()
	var detection_radius: float = maxf(arena_radius * 2.0, 440.0)
	for i: int in phase2_minion_count:
		if phase2_minion_scene == null:
			continue
		var minion: Node2D = phase2_minion_scene.instantiate() as Node2D
		var angle: float = TAU * float(i) / float(maxi(phase2_minion_count, 1)) + randf_range(-0.25, 0.25)
		var distance: float = randf_range(70.0, maxf(arena_radius - 20.0, 70.0))
		minion.position = spawn_position + Vector2.from_angle(angle) * distance
		minion.set("data", phase2_minion_data)
		minion.set("target_group", target_group)
		minion.set("can_wander", false)
		minion.set("wander_radius", arena_radius)
		minion.set("require_line_of_sight", false)
		minion.set("detection_radius", detection_radius)
		get_parent().add_child(minion)
		var detection_shape: CollisionShape2D = minion.get_node_or_null(^"DetectionArea/DetectionRadius") as CollisionShape2D
		if detection_shape != null and detection_shape.shape is CircleShape2D:
			var circle: CircleShape2D = detection_shape.shape.duplicate() as CircleShape2D
			circle.radius = detection_radius
			detection_shape.shape = circle
		if is_instance_valid(target):
			minion.set("candidate_target", target)
			minion.set("target", target)
		phase2_minions.append(minion)


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