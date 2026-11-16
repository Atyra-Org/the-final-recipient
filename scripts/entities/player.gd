extends CharacterBody2D

const WALK_SPEED = 100.0
const RUN_SPEED = 200.0
const DASH_DURATION = 0.2
const DASH_SPEED = 400.0

var input_vector := Vector2.ZERO
var facing_direction := Vector2.DOWN # Menyimpan arah hadap terakhir player (default menghadap bawah)
var is_running: bool = false
var is_attacking: bool = false
var is_dashing: bool = false
var dash_timer: float = 0.0
var dash_direction:= Vector2.ZERO
var attack_damage: int = 10
var hit_targets: Array[Node2D] = []
@export var hitbox_offset: float = 20.0

@onready var animation_tree: AnimationTree = $AnimationTree
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var hitbox: Area2D = $Hitbox
@onready var hitbox_shape: CollisionShape2D = $Hitbox/CollisionShape2D
var state_machine: AnimationNodeStateMachinePlayback
var move_state_machine: AnimationNodeStateMachinePlayback

func _ready() -> void:
	add_to_group(&"player")
	
	hitbox.monitoring = false
	
	state_machine = animation_tree.get("parameters/StateMachine/playback")
	move_state_machine = animation_tree.get("parameters/StateMachine/MoveState/playback")

func _physics_process(delta: float) -> void:
	var current_state = state_machine.get_current_node()
	is_attacking = (current_state == "AttackState")

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
		# Simpan arah gerak terakhir ke variabel facing_direction
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
	if event.is_action_pressed("attack") and not is_attacking:
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
		
	if input_vector == Vector2.ZERO:
		return
		
	is_dashing = true
	dash_timer = DASH_DURATION
	
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
