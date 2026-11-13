class_name EnemyController
extends CharacterBody2D

enum State {
	IDLE,
	CHASE
}

@export_category("Movement Settings")
@export var move_speed: float = 110.0
@export var acceleration: float = 700.0
@export var friction: float = 900.0
@export var stop_distance: float = 24.0

@export_category("AI Detection")
@export var target_group: StringName = &"player"

@onready var detection_area: Area2D = $DetectionArea
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

var current_state: State = State.IDLE
var target: Node2D = null
var facing_direction: String = "down"


func _ready() -> void:
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	add_to_group(&"enemy")

	if is_instance_valid(detection_area):
		if not detection_area.body_entered.is_connected(_on_detection_area_body_entered):
			detection_area.body_entered.connect(_on_detection_area_body_entered)
		if not detection_area.body_exited.is_connected(_on_detection_area_body_exited):
			detection_area.body_exited.connect(_on_detection_area_body_exited)
	else:
		push_warning("EnemyController: Node 'DetectionArea' tidak ditemukan pada " + name)

	_update_animation()


func _physics_process(delta: float) -> void:
	# Jika tidak sedang chase, cek apakah ada player di dalam area secara aktif
	if current_state == State.IDLE and is_instance_valid(detection_area):
		_scan_for_target()

	match current_state:
		State.IDLE:
			_process_idle_state(delta)
		State.CHASE:
			_process_chase_state(delta)

	move_and_slide()
	_update_animation()


## Scan secara aktif untuk menemukan target yang sudah ada di dalam area
func _scan_for_target() -> void:
	for body in detection_area.get_overlapping_bodies():
		if body.is_in_group(target_group):
			_transition_to_state(State.CHASE, body)
			return


func _process_idle_state(delta: float) -> void:
	velocity = velocity.move_toward(Vector2.ZERO, friction * delta)

func _process_chase_state(delta: float) -> void:
	if not is_instance_valid(target):
		_transition_to_state(State.IDLE, null)
		return

	var distance_to_target: float = global_position.distance_to(target.global_position)

	if distance_to_target > stop_distance:
		var direction: Vector2 = global_position.direction_to(target.global_position)
		var target_velocity: Vector2 = direction * move_speed
		velocity = velocity.move_toward(target_velocity, acceleration * delta)
		_update_facing_direction(direction)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)


func _transition_to_state(new_state: State, new_target: Node2D) -> void:
	current_state = new_state
	target = new_target

func _update_facing_direction(dir: Vector2) -> void:
	if not is_instance_valid(animated_sprite):
		return

	if absf(dir.x) > absf(dir.y):
		facing_direction = "side"
		animated_sprite.flip_h = (dir.x < 0.0)
	else:
		animated_sprite.flip_h = false
		if dir.y < 0.0:
			facing_direction = "up"
		else:
			facing_direction = "down"


func _update_animation() -> void:
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

func _on_detection_area_body_entered(body: Node2D) -> void:
	if body.is_in_group(target_group):
		_transition_to_state(State.CHASE, body)


func _on_detection_area_body_exited(body: Node2D) -> void:
	if body == target:
		_transition_to_state(State.IDLE, null)
