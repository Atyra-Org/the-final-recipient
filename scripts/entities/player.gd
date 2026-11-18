extends CharacterBody2D

const SPEED = 100.0

func _physics_process(delta: float) -> void:

	var input_vector = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity = input_vector * SPEED
	move_and_slide()
<<<<<<< Updated upstream
=======

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


func _on_animation_tree_animation_finished(anim_name: StringName) -> void:
	if anim_name.begins_with("attack_"):
		hitbox.monitoring = false
		is_attacking = false

func _update_hitbox_position() -> void:
	var attack_direction = Vector2(facing_direction.x, -facing_direction.y).normalized()
	hitbox_shape.position = attack_direction * hitbox_offset
>>>>>>> Stashed changes
