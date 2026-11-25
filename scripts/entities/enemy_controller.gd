class_name EnemyController
extends CharacterBody2D

signal health_changed(current_hp: int, max_hp: int)
signal died

enum State {
	IDLE,
	WANDER,
	CHASE,
	INVESTIGATE,
	ATTACK,
	HURT,
	DEAD,
	BOUND
}

@export var data: EnemyData = null

@export_category("Movement Settings")
@export var move_speed: float = 80.0
@export var acceleration: float = 700.0
@export var friction: float = 900.0
@export var use_navigation: bool = true

@export_category("Wander Settings")
@export var can_wander: bool = true
@export var wander_speed: float = 55.0
@export var wander_radius: float = 90.0
@export var idle_wait_min: float = 1.5
@export var idle_wait_max: float = 3.5

@export_category("Combat & Health")
@export var max_health: int = 50
@export var attack_damage: int = 10
@export var attack_range: float = 28.0
@export var attack_cooldown: float = 1.0
@export var hitbox_offset: float = 18.0
@export var attack_active_frames: Array[int] = [1, 2]

@export_category("AI Detection")
@export var target_group: StringName = &"player"
@export var require_line_of_sight: bool = true
@export var investigate_wait_time: float = 2.0

@export_category("Behavior Settings")
@export var is_invulnerable: bool = false
@export var freeze_when_observed: bool = false
@export var observer_fov_angle: float = 75.0

@onready var detection_area: Area2D = $DetectionArea
@onready var detection_radius: CollisionShape2D = $DetectionArea/DetectionRadius
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var body_collision: CollisionShape2D = $BodyCollision
@onready var health_bar: ProgressBar = $HealthBar
@onready var attack_hitbox: Area2D = $AttackHitbox
@onready var line_of_sight: RayCast2D = $LineOfSight
@onready var navigation_agent: NavigationAgent2D = $NavigationAgent2D

var current_state: State = State.IDLE
var current_health: int = max_health
var target: Node2D = null
var facing_direction: String = "down"
var attack_cooldown_timer: float = 0.0
var spawn_position: Vector2 = Vector2.ZERO
var wander_target_position: Vector2 = Vector2.ZERO
var state_timer: float = 0.0
var hit_targets: Array[Node2D] = []
var last_known_position: Vector2 = Vector2.ZERO
var reached_last_known: bool = false
var candidate_target: Node2D = null
var stuck_timer: float = 0.0
var bind_timer: float = 0.0
var _bind_original_modulate: Color = Color.WHITE

func _ready() -> void:
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	_apply_data()
	current_health = max_health
	if is_instance_valid(health_bar):
		health_bar.max_value = max_health
		health_bar.value = current_health
		health_bar.visible = false

	spawn_position = global_position
	state_timer = randf_range(idle_wait_min, idle_wait_max)
	add_to_group(&"enemy")

	if is_instance_valid(detection_area):
		if not detection_area.body_entered.is_connected(_on_detection_area_body_entered):
			detection_area.body_entered.connect(_on_detection_area_body_entered)
		if not detection_area.body_exited.is_connected(_on_detection_area_body_exited):
			detection_area.body_exited.connect(_on_detection_area_body_exited)

	if is_instance_valid(animated_sprite):
		if not animated_sprite.animation_finished.is_connected(_on_animated_sprite_animation_finished):
			animated_sprite.animation_finished.connect(_on_animated_sprite_animation_finished)
		if not animated_sprite.frame_changed.is_connected(_on_animated_sprite_frame_changed):
			animated_sprite.frame_changed.connect(_on_animated_sprite_frame_changed)

	if is_instance_valid(attack_hitbox):
		attack_hitbox.monitoring = false
		if not attack_hitbox.body_entered.is_connected(_on_attack_hitbox_body_entered):
			attack_hitbox.body_entered.connect(_on_attack_hitbox_body_entered)

	_update_animation()
	var event_bus: Node = _get_event_bus()
	if event_bus != null:
		event_bus.connect(&"enemy_bind_requested", _on_enemy_bind_requested)
		event_bus.emit_signal(&"enemy_spawned", self, _get_enemy_id())


func _apply_data() -> void:
	if data == null:
		return
	move_speed = data.move_speed
	acceleration = data.acceleration
	friction = data.friction
	can_wander = data.can_wander
	wander_speed = data.wander_speed
	wander_radius = data.wander_radius
	idle_wait_min = data.idle_wait_min
	idle_wait_max = data.idle_wait_max
	max_health = data.max_health
	attack_damage = data.attack_damage
	attack_range = data.attack_range
	attack_cooldown = data.attack_cooldown
	hitbox_offset = data.hitbox_offset
	attack_active_frames = data.attack_active_frames.duplicate()
	target_group = data.target_group
	require_line_of_sight = data.require_line_of_sight
	investigate_wait_time = data.investigate_wait_time
	is_invulnerable = data.is_invulnerable
	freeze_when_observed = data.freeze_when_observed
	observer_fov_angle = data.observer_fov_angle
	_apply_visual_data()
	_apply_detection_data()


func _apply_visual_data() -> void:
	if not is_instance_valid(animated_sprite):
		return
	if data.sprite_frames != null:
		animated_sprite.sprite_frames = data.sprite_frames
	animated_sprite.scale = data.sprite_scale


func _apply_detection_data() -> void:
	if not is_instance_valid(detection_radius):
		return
	var shape: Shape2D = detection_radius.shape
	if shape is CircleShape2D:
		var circle: CircleShape2D = shape.duplicate() as CircleShape2D
		circle.radius = data.detection_radius
		detection_radius.shape = circle

func _get_enemy_id() -> String:
	if data != null and not data.id.is_empty():
		return String(data.id)
	return name

func _get_event_bus() -> Node:
	var tree: SceneTree = get_tree()
	if tree == null or tree.root == null:
		return null
	return get_tree().root.get_node_or_null(^"EventBus")

func _on_enemy_bind_requested(enemy: Node2D, duration: float) -> void:
	if enemy == self:
		apply_bind(duration)

func apply_bind(duration: float = 2.5) -> void:
	if current_state == State.DEAD or not is_finite(duration) or duration <= 0.0:
		return
	if bind_timer <= 0.0:
		_bind_original_modulate = animated_sprite.modulate
	bind_timer = maxf(bind_timer, duration)
	current_state = State.BOUND
	velocity = Vector2.ZERO
	_disable_attack_hitbox()
	var animation: StringName = StringName("bind_" + facing_direction)
	if animated_sprite.sprite_frames != null and animated_sprite.sprite_frames.has_animation(animation):
		animated_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		animated_sprite.play(animation)
	else:
		animated_sprite.modulate = Color(1.0, 0.8, 0.2)
		animated_sprite.pause()
	
func _update_observed_state() -> bool:
	if not freeze_when_observed or not is_instance_valid(target):
		_resume_after_observation()
		return false
	if not _is_observed_by(target):
		_resume_after_observation()
		return false
	_freeze_from_observation()
	return true


func _is_observed_by(observer: Node2D) -> bool:
	if not _is_inside_detection_range(observer):
		return false
	if not _is_inside_observer_fov(observer):
		return false
	return _has_line_of_sight(observer)


func _is_inside_detection_range(observer: Node2D) -> bool:
	if not is_instance_valid(detection_area) or not detection_area.monitoring:
		return false
	for body: Node2D in detection_area.get_overlapping_bodies():
		if body == observer:
			return true
	return false


func _is_inside_observer_fov(observer: Node2D) -> bool:
	var observed_facing: Variant = observer.get("facing_direction")
	if typeof(observed_facing) != TYPE_VECTOR2:
		return true
	var facing: Vector2 = observed_facing
	if facing.is_zero_approx():
		return true
	var world_facing: Vector2 = Vector2(facing.x, -facing.y).normalized()
	var to_enemy: Vector2 = observer.global_position.direction_to(global_position)
	var half_angle_cos: float = cos(deg_to_rad(clampf(observer_fov_angle, 0.0, 180.0) * 0.5))
	return world_facing.dot(to_enemy) >= half_angle_cos


func _freeze_from_observation() -> void:
	velocity = Vector2.ZERO
	_disable_attack_hitbox()
	if current_state == State.ATTACK:
		_transition_to_state(State.CHASE)
	if not is_instance_valid(animated_sprite):
		return
	if not animated_sprite.is_playing():
		animated_sprite.play()
	animated_sprite.pause()


func _resume_after_observation() -> void:
	if not is_instance_valid(animated_sprite):
		return
	if not animated_sprite.is_playing() and animated_sprite.sprite_frames != null:
		animated_sprite.play()


func _physics_process(delta: float) -> void:
	if current_state == State.DEAD:
		return
	if bind_timer > 0.0:
		bind_timer = maxf(0.0, bind_timer - delta)
		velocity = Vector2.ZERO
		_disable_attack_hitbox()
		if bind_timer > 0.0:
			return
		animated_sprite.modulate = _bind_original_modulate
		if is_instance_valid(target):
			_transition_to_state(State.CHASE)
		else:
			_enter_idle_with_timer()
		_update_animation()

	if attack_cooldown_timer > 0.0:
		attack_cooldown_timer -= delta

	if _update_observed_state():
		move_and_slide()
		return


	if current_state in [State.IDLE, State.WANDER, State.INVESTIGATE]:
		if is_instance_valid(candidate_target) and _has_line_of_sight(candidate_target):
			_transition_to_state(State.CHASE, candidate_target)

	match current_state:
		State.IDLE:
			_process_idle_state(delta)
		State.WANDER:
			_process_wander_state(delta)
		State.CHASE:
			_process_chase_state(delta)
		State.INVESTIGATE:
			_process_investigate_state(delta)
		State.ATTACK:
			_process_attack_state(delta)
		State.HURT:
			_process_hurt_state(delta)

	move_and_slide()
	_update_animation()


func _process_idle_state(delta: float) -> void:
	velocity = velocity.move_toward(Vector2.ZERO, friction * delta)

	if not can_wander:
		return

	state_timer -= delta
	if state_timer <= 0.0:
		_pick_new_wander_target()


func _process_wander_state(delta: float) -> void:
	state_timer -= delta
	var distance_to_point: float = global_position.distance_to(wander_target_position)

	if distance_to_point <= 6.0 or state_timer <= 0.0:
		_enter_idle_with_timer()
		return

	if is_on_wall():
		stuck_timer += delta
		if stuck_timer >= 0.25:
			_enter_idle_with_timer()
			return
	else:
		stuck_timer = 0.0

	var direction: Vector2 = _get_move_direction(wander_target_position)
	_update_facing_direction(direction)
	velocity = velocity.move_toward(direction * wander_speed, acceleration * delta)


func _process_chase_state(delta: float) -> void:
	if not is_instance_valid(target):
		_enter_idle_with_timer()
		return

	if not _has_line_of_sight(target):
		_enter_investigate_state()
		return

	last_known_position = target.global_position
	var distance_to_target: float = global_position.distance_to(target.global_position)
	var direction: Vector2 = _get_move_direction(target.global_position)
	_update_facing_direction(direction)

	if distance_to_target <= attack_range:
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)
		if attack_cooldown_timer <= 0.0:
			_start_attack()
	else:
		var target_velocity: Vector2 = direction * move_speed
		velocity = velocity.move_toward(target_velocity, acceleration * delta)


func _process_attack_state(delta: float) -> void:
	velocity = velocity.move_toward(Vector2.ZERO, friction * delta)


func _process_hurt_state(delta: float) -> void:
	velocity = velocity.move_toward(Vector2.ZERO, friction * delta)


func _transition_to_state(new_state: State, new_target: Node2D = target) -> void:
	if current_state == State.DEAD:
		return
	if bind_timer > 0.0:
		target = new_target
		return
	if current_state == State.ATTACK and new_state != State.ATTACK:
		_disable_attack_hitbox()
	current_state = new_state
	target = new_target


func _enter_idle_with_timer() -> void:
	state_timer = randf_range(idle_wait_min, idle_wait_max)
	_transition_to_state(State.IDLE, null)
	last_known_position = Vector2.ZERO


func _pick_new_wander_target() -> void:
	var random_angle: float = randf_range(0.0, TAU)
	var random_distance: float = randf_range(wander_radius * 0.3, wander_radius)
	var offset: Vector2 = Vector2.from_angle(random_angle) * random_distance

	wander_target_position = spawn_position + offset
	state_timer = 4.0
	stuck_timer = 0.0
	_transition_to_state(State.WANDER, null)


func _start_attack() -> void:
	if current_state == State.DEAD or bind_timer > 0.0:
		return
	if _update_observed_state():
		return
	_transition_to_state(State.ATTACK)
	attack_cooldown_timer = attack_cooldown
	hit_targets.clear()
	_update_hitbox_transform()
	_play_one_shot_animation("attack_" + facing_direction)


func take_damage(amount: int, knockback_force: Vector2 = Vector2.ZERO) -> void:
	if current_state == State.DEAD or amount <= 0:
		return
	if is_invulnerable:
		_spawn_damage_number(0)
		return

	current_health = maxi(current_health - amount, 0)
	health_changed.emit(current_health, max_health)
	var event_bus: Node = _get_event_bus()
	if event_bus != null:
		event_bus.emit_signal(&"enemy_health_changed", self, _get_enemy_id(), current_health, max_health)
	velocity = knockback_force

	if is_instance_valid(health_bar):
		health_bar.visible = true
		health_bar.value = current_health

	_spawn_damage_number(amount)

	if current_health == 0:
		_die()
	elif bind_timer > 0.0:
		velocity = Vector2.ZERO
	else:
		_disable_attack_hitbox()
		_transition_to_state(State.HURT)
		_play_one_shot_animation("hurt")


func _die() -> void:
	bind_timer = 0.0
	animated_sprite.modulate = _bind_original_modulate
	candidate_target = null
	current_state = State.DEAD
	velocity = Vector2.ZERO
	died.emit()
	var event_bus: Node = _get_event_bus()
	if event_bus != null:
		event_bus.emit_signal(&"enemy_died", self, _get_enemy_id(), global_position)

	_disable_attack_hitbox()
	if is_instance_valid(body_collision):
		body_collision.set_deferred("disabled", true)
	if is_instance_valid(detection_area):
		detection_area.set_deferred("monitoring", false)
		detection_area.set_deferred("monitorable", false)
	if is_instance_valid(health_bar):
		health_bar.visible = false

	_play_one_shot_animation("death")


func _update_facing_direction(dir: Vector2) -> void:
	if not is_instance_valid(animated_sprite):
		return
	if dir.is_zero_approx():
		return

	if absf(dir.x) > absf(dir.y):
		facing_direction = "side"
		animated_sprite.flip_h = (dir.x < 0.0)
	else:
		animated_sprite.flip_h = false
		facing_direction = "up" if dir.y < 0.0 else "down"


func _update_animation() -> void:
	if current_state in [State.ATTACK, State.HURT, State.DEAD, State.BOUND]:
		return

	if not is_instance_valid(animated_sprite) or animated_sprite.sprite_frames == null:
		return

	var is_moving: bool = velocity.length() > 5.0
	var anim_prefix: String = "run_" if is_moving else "idle_"
	var anim_name: String = anim_prefix + facing_direction

	if animated_sprite.sprite_frames.has_animation(anim_name):
		if animated_sprite.animation != anim_name or not animated_sprite.is_playing():
			animated_sprite.play(anim_name)
	elif animated_sprite.sprite_frames.has_animation("idle_down"):
		animated_sprite.play("idle_down")


func _update_hitbox_transform() -> void:
	if not is_instance_valid(attack_hitbox):
		return

	match facing_direction:
		"down":
			attack_hitbox.position = Vector2(0.0, hitbox_offset)
		"up":
			attack_hitbox.position = Vector2(0.0, -hitbox_offset)
		"side":
			var dir_x: float = -1.0 if animated_sprite.flip_h else 1.0
			attack_hitbox.position = Vector2(hitbox_offset * dir_x, 0.0)


func _spawn_damage_number(amount: int) -> void:
	var dmg_label: Label = Label.new()
	dmg_label.text = str(amount)
	dmg_label.z_index = 10

	dmg_label.add_theme_font_size_override("font_size", 11)
	dmg_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
	dmg_label.add_theme_color_override("font_outline_color", Color.BLACK)
	dmg_label.add_theme_constant_override("outline_size", 4)

	var scene_root: Node = get_tree().current_scene
	if is_instance_valid(scene_root):
		scene_root.add_child(dmg_label)
	else:
		add_child(dmg_label)

	var random_x: float = randf_range(-16.0, 8.0)
	var random_y: float = randf_range(-32.0, -20.0)
	dmg_label.global_position = global_position + Vector2(random_x, random_y)

	var tween: Tween = dmg_label.create_tween()
	tween.set_parallel(true)
	tween.tween_property(dmg_label, "global_position:y", dmg_label.global_position.y - 20.0, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(dmg_label, "modulate:a", 0.0, 0.5).set_delay(0.15)

	tween.chain().tween_callback(dmg_label.queue_free)


func _play_one_shot_animation(anim_name: String) -> void:
	if not is_instance_valid(animated_sprite) or animated_sprite.sprite_frames == null:
		_on_animated_sprite_animation_finished()
		return

	if animated_sprite.sprite_frames.has_animation(anim_name):
		animated_sprite.stop()
		animated_sprite.play(anim_name)
	else:
		_on_animated_sprite_animation_finished()


func _on_animated_sprite_frame_changed() -> void:
	if not is_instance_valid(attack_hitbox):
		return
	if current_state == State.ATTACK:
		attack_hitbox.monitoring = (animated_sprite.frame in attack_active_frames)
	else:
		attack_hitbox.monitoring = false

func _on_animated_sprite_animation_finished() -> void:
	match current_state:
		State.ATTACK:
			if is_instance_valid(target):
				_transition_to_state(State.CHASE)
			else:
				_enter_idle_with_timer()
		State.HURT:
			if is_instance_valid(target):
				_transition_to_state(State.CHASE)
			elif last_known_position != Vector2.ZERO:
				_enter_investigate_state()
			else:
				_enter_idle_with_timer()
		State.DEAD:
			queue_free()


func _on_detection_area_body_entered(body: Node2D) -> void:
	if current_state != State.DEAD and body.is_in_group(target_group):
		candidate_target = body
		if _has_line_of_sight(body):
			_transition_to_state(State.CHASE, body)


func _on_detection_area_body_exited(body: Node2D) -> void:
	if body == candidate_target:
		candidate_target = null
	if current_state != State.DEAD and body == target:
		last_known_position = body.global_position
		if current_state == State.HURT:
			target = null
		else:
			_enter_investigate_state()

func _on_attack_hitbox_body_entered(body: Node2D) -> void:
	if current_state != State.ATTACK or body in hit_targets:
		return
	if body.is_in_group(target_group):
		hit_targets.append(body)
		if body.has_method("take_damage"):
			var knockback_dir: Vector2 = global_position.direction_to(body.global_position)
			body.take_damage(attack_damage, knockback_dir * 150.0)


func _disable_attack_hitbox() -> void:
	if is_instance_valid(attack_hitbox):
		attack_hitbox.set_deferred("monitoring", false)


func _enter_investigate_state() -> void:
	reached_last_known = false
	stuck_timer = 0.0
	state_timer = investigate_wait_time
	_transition_to_state(State.INVESTIGATE, null)


func _process_investigate_state(delta: float) -> void:
	if not reached_last_known:
		if is_on_wall():
			stuck_timer += delta
		else:
			stuck_timer = 0.0

		var distance_to_last_pos: float = global_position.distance_to(last_known_position)
		if distance_to_last_pos <= 8.0 or stuck_timer >= 0.25:
			reached_last_known = true
			velocity = velocity.move_toward(Vector2.ZERO, friction * delta)
		else:
			var direction: Vector2 = _get_move_direction(last_known_position)
			_update_facing_direction(direction)
			velocity = velocity.move_toward(direction * move_speed, acceleration * delta)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)
		state_timer -= delta
		if state_timer <= 0.0:
			last_known_position = Vector2.ZERO
			wander_target_position = spawn_position
			state_timer = 5.0
			stuck_timer = 0.0
			_transition_to_state(State.WANDER, null)


func _get_move_direction(destination: Vector2) -> Vector2:
	var direct_direction: Vector2 = global_position.direction_to(destination)
	if not use_navigation or not is_instance_valid(navigation_agent):
		return direct_direction

	var nav_map: RID = navigation_agent.get_navigation_map()
	if not nav_map.is_valid() or NavigationServer2D.map_get_iteration_id(nav_map) == 0:
		return direct_direction

	navigation_agent.target_position = destination
	if navigation_agent.is_navigation_finished():
		return direct_direction

	var next_path_pos: Vector2 = navigation_agent.get_next_path_position()
	var nav_direction: Vector2 = global_position.direction_to(next_path_pos)
	if nav_direction.is_zero_approx():
		return direct_direction
	return nav_direction


func _has_line_of_sight(target_node: Node2D) -> bool:
	if not require_line_of_sight or not is_instance_valid(line_of_sight):
		return true
	if not is_instance_valid(target_node):
		return false

	line_of_sight.target_position = line_of_sight.to_local(target_node.global_position)
	line_of_sight.force_raycast_update()

	if not line_of_sight.is_colliding():
		return true
	return line_of_sight.get_collider() == target_node
