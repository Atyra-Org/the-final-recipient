class_name EnemyController
extends CharacterBody2D

signal health_changed(current_hp: int, max_hp: int)
signal died

enum State {
	IDLE,
	CHASE,
	ATTACK,
	HURT,
	DEAD
}

@export_category("Movement Settings")
@export var move_speed: float = 80.0
@export var acceleration: float = 700.0
@export var friction: float = 900.0

@export_category("Combat & Health")
@export var max_health: int = 50
@export var attack_damage: int = 10
@export var attack_range: float = 28.0
@export var attack_cooldown: float = 1.0

@export_category("AI Detection")
@export var target_group: StringName = &"player"

@onready var detection_area: Area2D = $DetectionArea
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var body_collision: CollisionShape2D = $BodyCollision

var current_state: State = State.IDLE
var current_health: int = max_health
var target: Node2D = null
var facing_direction: String = "down"
var attack_cooldown_timer: float = 0.0

func _ready() -> void:
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	current_health = max_health
	add_to_group(&"enemy")
	
	if is_instance_valid(detection_area):
		if not detection_area.body_entered.is_connected(_on_detection_area_body_entered):
			detection_area.body_entered.connect(_on_detection_area_body_entered)
		if not detection_area.body_exited.is_connected(_on_detection_area_body_exited):
			detection_area.body_exited.connect(_on_detection_area_body_exited)
	
	if is_instance_valid(animated_sprite):
		if not animated_sprite.animation_finished.is_connected(_on_animated_sprite_animation_finished):
			animated_sprite.animation_finished.connect(_on_animated_sprite_animation_finished)

	_update_animation()


func _physics_process(delta: float) -> void:
	if current_state == State.DEAD:
		return

	if attack_cooldown_timer > 0.0:
		attack_cooldown_timer -= delta

	match current_state:
		State.IDLE:
			_process_idle_state(delta)
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

func _process_chase_state(delta: float) -> void:
	if not is_instance_valid(target):
		_transition_to_state(State.IDLE, null)
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
	current_state = new_state
	target = new_target

func _start_attack() -> void:
	_transition_to_state(State.ATTACK)
	attack_cooldown_timer = attack_cooldown
	
	if is_instance_valid(target) and global_position.distance_to(target.global_position) <= attack_range + 8.0:
		if target.has_method("take_damage"):
			target.take_damage(attack_damage)

func take_damage(amount: int, knockback_force: Vector2 = Vector2.ZERO) -> void:
	if current_state == State.DEAD or amount <= 0:
		return
		
	current_health = maxi(current_health - amount, 0)
	health_changed.emit(current_health, max_health)
	velocity = knockback_force
	
	if current_health == 0:
		_die()
	else:
		_transition_to_state(State.HURT)
		_play_one_shot_animation("hurt")


func _die() -> void:
	current_state = State.DEAD
	velocity = Vector2.ZERO
	died.emit()
	
	if is_instance_valid(body_collision):
		body_collision.set_deferred("disabled", true)
	if is_instance_valid(detection_area):
		detection_area.set_deferred("monitoring", false)
		detection_area.set_deferred("monitorable", false)
		
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
		if current_state == State.ATTACK:
			var attack_anim: String = "attack_" + facing_direction
			_play_one_shot_animation(attack_anim)
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


func _play_one_shot_animation(anim_name: String) -> void:
	if not is_instance_valid(animated_sprite) or animated_sprite.sprite_frames == null:
		_on_animated_sprite_animation_finished()
		return
		
	if animated_sprite.sprite_frames.has_animation(anim_name):
		if animated_sprite.animation != anim_name:
			animated_sprite.play(anim_name)
	else:
		_on_animated_sprite_animation_finished()

func _on_animated_sprite_animation_finished() -> void:
	match current_state:
		State.ATTACK, State.HURT:
			if is_instance_valid(target):
				_transition_to_state(State.CHASE)
			else:
				_transition_to_state(State.IDLE, null)
		State.DEAD:
			queue_free()

func _on_detection_area_body_entered(body: Node2D) -> void:
	if current_state != State.DEAD and body.is_in_group(target_group):
		_transition_to_state(State.CHASE, body)

func _on_detection_area_body_exited(body: Node2D) -> void:
	if current_state != State.DEAD and body == target:
		_transition_to_state(State.IDLE, null)
		
# test
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("attack"):
		take_damage(10)
		print("Health tersisa: ", current_health)
