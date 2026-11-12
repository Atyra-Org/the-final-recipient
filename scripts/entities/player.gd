extends CharacterBody2D

const WALK_SPEED = 100.0
const RUN_SPEED = 250.0

var input_vector: = Vector2.ZERO
var is_running: bool = false

@onready var animation_tree: AnimationTree = $AnimationTree
var state_machine: AnimationNodeStateMachinePlayback

func _ready() -> void:
	state_machine = animation_tree.get("parameters/StateMachine/MoveState/playback")

func _physics_process(delta: float) -> void:

	input_vector = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	is_running = Input.is_action_pressed("run")

	if input_vector != Vector2.ZERO:
		var direction_vector: = Vector2(input_vector.x, -input_vector.y)
		animation_tree.set("parameters/StateMachine/MoveState/WalkState/blend_position", direction_vector)
		animation_tree.set("parameters/StateMachine/MoveState/RunState/blend_position", direction_vector)
		animation_tree.set("parameters/StateMachine/MoveState/IdleState/blend_position", direction_vector)

		if is_running:
			state_machine.travel("RunState")
		else:
			state_machine.travel("WalkState")
	else:
		state_machine.travel("IdleState")

	if is_running:
		velocity = input_vector * RUN_SPEED
	else:
		velocity = input_vector * WALK_SPEED

	move_and_slide()
