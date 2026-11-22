extends CharacterBody2D

const WALK_SPEED = 65.0
const RUN_SPEED = 170.0
const DASH_DURATION = 0.2
const DASH_SPEED = 360.0
const DASH_COOLDOWN = 1.5
const KNOCKBACK_FORCE = 250.0
const KNOCKBACK_TIMER = 1000.0

var input_vector := Vector2.ZERO
var facing_direction := Vector2.DOWN
var is_running: bool = false
var is_attacking: bool = false
var is_dashing: bool = false
var dash_timer: float = 0.0
var dash_direction:= Vector2.ZERO
var attack_damage: int = 10
var hit_targets: Array[Node2D] = []
@export var hitbox_offset: float = 20.0
@export var max_health: int = 100
var health: int = 0
var dash_cooldown_timer: float = 0.0
var is_dead: bool = false
var is_hurt: bool = false

@onready var animation_tree: AnimationTree = $AnimationTree
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var hitbox: Area2D = $Hitbox
@onready var hitbox_shape: CollisionShape2D = $Hitbox/CollisionShape2D
var state_machine: AnimationNodeStateMachinePlayback
var move_state_machine: AnimationNodeStateMachinePlayback
signal health_changed(current_health, max_health)

func _ready() -> void:
	add_to_group(&"player")
	hitbox.monitoring = false
	health = max_health
	health_changed.emit(health, max_health)

	state_machine = animation_tree.get("parameters/StateMachine/playback")
	move_state_machine = animation_tree.get("parameters/StateMachine/MoveState/playback")

func _physics_process(delta: float) -> void:
	if is_dead:
		return
		
	if is_hurt:
		velocity = velocity.move_toward(Vector2.ZERO, KNOCKBACK_TIMER * delta)
		move_and_slide()
		return
	
	var current_state = state_machine.get_current_node()
	is_attacking = (current_state == "AttackState")
	
	if dash_cooldown_timer > 0.0:
		dash_cooldown_timer -= delta

	if is_attacking:
		velocity = velocity.move_toward(Vector2.ZERO, 800.0 * delta)
		move_and_slide()
		return

	input_vector = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	is_running = Input.is_action_pressed("run")
	
	if Input.is_action_just_pressed("dash"):
		_start_dash()
		
	if is_dashing:
		dash_timer -= delta
		velocity = dash_direction * DASH_SPEED
		
		move_and_slide()
		
		if dash_timer <= 0.0:
			is_dashing = false
			velocity = Vector2.ZERO
			
		return

	if input_vector != Vector2.ZERO:
		facing_direction = Vector2(input_vector.x, -input_vector.y).normalized()
		
		animation_tree.set("parameters/StateMachine/MoveState/WalkState/blend_position", facing_direction)
		animation_tree.set("parameters/StateMachine/MoveState/RunState/blend_position", facing_direction)
		animation_tree.set("parameters/StateMachine/MoveState/IdleState/blend_position", facing_direction)

		if is_running:
			move_state_machine.travel("RunState")
		else:
			move_state_machine.travel("WalkState")
	else:
		move_state_machine.travel("IdleState")

	if is_running:
		velocity = input_vector * RUN_SPEED
	else:
		velocity = input_vector * WALK_SPEED

	move_and_slide()

func _unhandled_input(event: InputEvent) -> void:
	if is_dead:
		return
	
	if event.is_action_pressed("attack") and not is_attacking and not is_hurt and not is_dashing:
		_start_attack()

func _start_attack() -> void:
	hit_targets.clear()
	
	_update_hitbox_position()
	animation_tree.set("parameters/StateMachine/AttackState/blend_position", facing_direction)
	
	is_attacking = true
	hitbox.monitoring = true
	
	state_machine.travel("AttackState")
	
func _play_dash_animation() -> void:
	var animation_name: String
	
	if abs(dash_direction.x) > abs(dash_direction.y):
		if dash_direction.x > 0:
			animation_name = "dash_right"
		else:
			animation_name = "dash_left"
	else:
		if dash_direction.y > 0:
			animation_name = "dash_down"
		else:
			animation_name = "dash_up"
			
	animation_player.play(animation_name)
	
func _start_dash() -> void:
	if is_dashing or is_attacking:
		return
		
	if dash_cooldown_timer > 0.0:
		return
		
	if input_vector == Vector2.ZERO:
		return
		
	is_dashing = true
	dash_timer = DASH_DURATION
	
	dash_cooldown_timer = DASH_COOLDOWN

	if input_vector != Vector2.ZERO:
		dash_direction = input_vector.normalized()
	else:
		dash_direction = Vector2(facing_direction.x, -facing_direction.y).normalized()
	
	_play_dash_animation()


func _on_hitbox_area_entered(area: Area2D) -> void:
	var enemy = area.get_parent()
	
	if not enemy.is_in_group("enemy"):
		return
		
	if enemy in hit_targets:
		return
		
	if enemy.has_method("take_damage"):
		hit_targets.append(enemy)
		enemy.take_damage(attack_damage)
		
		print("Player memberikan damage", attack_damage)


func _on_animation_tree_animation_finished(anim_name: StringName) -> void:
	if anim_name.begins_with("attack_"):
		hitbox.monitoring = false
		is_attacking = false
		
		print("Animasi selesai", anim_name)

func _update_hitbox_position() -> void:
	var attack_direction = Vector2(facing_direction.x, -facing_direction.y).normalized()
	hitbox_shape.position = attack_direction * hitbox_offset
	
func _play_death_animation() -> void:
	var animation_name: String
	
	if abs(facing_direction.x) > abs(facing_direction.y):
		if facing_direction.x > 0:
			animation_name = "death_right"
		else:
			animation_name = "death_left"
	else:
		if facing_direction.y > 0:
			animation_name = "death_up"
		else:
			animation_name = "death_down"
	animation_player.play(animation_name)
	
func take_damage(amount: int, knockback: Vector2) -> void:
	if is_dead or is_hurt or is_dashing:
		return

	health -= amount
	health = clamp(health, 0, max_health)

	health_changed.emit(health, max_health)

	if health <= 0:
		die()
		return

	is_hurt = true
	is_attacking = false

	hitbox.monitoring = false

	_apply_knockback(knockback)
	_play_hurt_animation()
	
func die() -> void:
	if is_dead:
		return
		
	is_dead = true
	
	hitbox.monitoring = false
	velocity = Vector2.ZERO
	
	animation_tree.active = false
	
	_play_death_animation()
	
	print("kamu sudah mati!")
	
func _play_hurt_animation() -> void:
	var animation_name: String
	
	if abs(facing_direction.x) > abs(facing_direction.y):
		if facing_direction.x > 0:
			animation_name = "hurt_right"
		else:
			animation_name = "hurt_left"
	else:
		if facing_direction.y > 0:
			animation_name = "hurt_up"
		else:
			animation_name = "hurt_down"
			
	animation_tree.active = false
			
	animation_player.play(animation_name)
		
func _apply_knockback(knockback: Vector2) -> void:
	velocity = knockback.normalized() * KNOCKBACK_FORCE

func _on_animation_player_animation_finished(anim_name: StringName) -> void:
	if anim_name.begins_with("hurt_"):
		is_hurt = false
		velocity = Vector2.ZERO
		
		animation_tree.active = true
		
		state_machine.travel("MoveState")
		move_state_machine.travel("IdleState")
