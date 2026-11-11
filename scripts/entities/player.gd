extends CharacterBody2D

const SPEED = 100.0

var input_vector: = Vector2.ZERO
func _physics_process(delta: float) -> void:

	input_vector = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity = input_vector * SPEED
	move_and_slide()
