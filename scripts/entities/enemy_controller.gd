class_name EnemyController
extends CharacterBody2D

signal health_changed(current_hp: int, max_hp: int)
signal died

enum State {
	IDLE,
	WANDER,
	CHASE,
	ATTACK,
	HURT,
	DEAD
}

@export_category("Movement Settings")
@export var move_speed: float = 80.0
@export var acceleration: float = 700.0
@export var friction: float = 900.0

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

@onready var detection_area: Area2D = $DetectionArea
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var body_collision: CollisionShape2D = $BodyCollision
@onready var health_bar: ProgressBar = $HealthBar
@onready var attack_hitbox: Area2D = $AttackHitbox

var current_state: State = State.IDLE
var current_health: int = max_health
var target: Node2D = null
var facing_direction: String = "down"
var attack_cooldown_timer: float = 0.0
var spawn_position: Vector2 = Vector2.ZERO
var wander_target_position: Vector2 = Vector2.ZERO
var state_timer: float = 0.0
var hit_targets: Array[Node2D] = []

func _ready() -> void:
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
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


func _physics_process(delta: float) -> void:
	if current_state == State.DEAD:
		return

	if attack_cooldown_timer > 0.0:
		attack_cooldown_timer -= delta

	match current_state:
		State.IDLE:
			_process_idle_state(delta)
		State.WANDER:
			_process_wander_state(delta)
		State.CHASE:
			_process_chase_state(delta)
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
	
	if distance_to_point <= 6.0 or state_timer <= 0.0 or is_on_wall():
		_enter_idle_with_timer()
		return
		
	var direction: Vector2 = global_position.direction_to(wander_target_position)
	_update_facing_direction(direction)
	velocity = velocity.move_toward(direction * wander_speed, acceleration * delta)


func _process_chase_state(delta: float) -> void:
	if not is_instance_valid(target):
		_enter_idle_with_timer()
		return
	
	var distance_to_target: float = global_position.distance_to(target.global_position)
	var direction: Vector2 = global_position.direction_to(target.global_position)
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
	if current_state == State.ATTACK and new_state != State.ATTACK:
		_disable_attack_hitbox()
	current_state = new_state
	target = new_target


func _enter_idle_with_timer() -> void:
	state_timer = randf_range(idle_wait_min, idle_wait_max)
	_transition_to_state(State.IDLE, null)


func _pick_new_wander_target() -> void:
	var random_angle: float = randf_range(0.0, TAU)
	var random_distance: float = randf_range(wander_radius * 0.3, wander_radius)
	var offset: Vector2 = Vector2.from_angle(random_angle) * random_distance
	
	wander_target_position = spawn_position + offset
	state_timer = 4.0
	_transition_to_state(State.WANDER, null)


func _start_attack() -> void:
	_transition_to_state(State.ATTACK)
	attack_cooldown_timer = attack_cooldown
	hit_targets.clear()
	_update_hitbox_transform()
	_play_one_shot_animation("attack_" + facing_direction)


func take_damage(amount: int, knockback_force: Vector2 = Vector2.ZERO) -> void:
	if current_state == State.DEAD or amount <= 0:
		return
		
	current_health = maxi(current_health - amount, 0)
	health_changed.emit(current_health, max_health)
	velocity = knockback_force
	
	if is_instance_valid(health_bar):
		health_bar.visible = true
		health_bar.value = current_health
	
	_spawn_damage_number(amount)
	
	if current_health == 0:
		_die()
	else:
		_disable_attack_hitbox()
		_transition_to_state(State.HURT)
		_play_one_shot_animation("hurt")


func _die() -> void:
	current_state = State.DEAD
	velocity = Vector2.ZERO
	died.emit()
	
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
		
	if absf(dir.x) > absf(dir.y):
		facing_direction = "side"
		animated_sprite.flip_h = (dir.x < 0.0)
	else:
		animated_sprite.flip_h = false
		facing_direction = "up" if dir.y < 0.0 else "down"


func _update_animation() -> void:
	if current_state in [State.ATTACK, State.HURT, State.DEAD]:
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
		State.ATTACK, State.HURT:
			if is_instance_valid(target):
				_transition_to_state(State.CHASE)
			else:
				_enter_idle_with_timer()
		State.DEAD:
			queue_free()


func _on_detection_area_body_entered(body: Node2D) -> void:
	if current_state != State.DEAD and body.is_in_group(target_group):
		_transition_to_state(State.CHASE, body)


func _on_detection_area_body_exited(body: Node2D) -> void:
	if current_state != State.DEAD and body == target:
		spawn_position = global_position
		_enter_idle_with_timer()

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

# testing 
func _unhandled_input(event: InputEvent) -> void:
	if OS.is_debug_build() and event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F2:
			take_damage(10)
			print("HP tersisa: ", current_health)
