extends CharacterBody2D

const WALK_SPEED = 100.0
const RUN_SPEED = 200.0

var input_vector := Vector2.ZERO
var facing_direction := Vector2.DOWN # Menyimpan arah hadap terakhir player (default menghadap bawah)
var is_running: bool = false
var is_attacking: bool = false

@onready var animation_tree: AnimationTree = $AnimationTree
var state_machine: AnimationNodeStateMachinePlayback
var move_state_machine: AnimationNodeStateMachinePlayback

func _ready() -> void:
	add_to_group(&"player")
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
	# Gunakan facing_direction (arah hadap player) untuk animasi serangan
	animation_tree.set("parameters/StateMachine/AttackState/blend_position", facing_direction)
	state_machine.travel("AttackState")
