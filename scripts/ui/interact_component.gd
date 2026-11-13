extends Node2D

@onready var interact_label: Label = $InteractRange/InteractLabel
var current_interaction := []
var can_interact := true

func _ready() -> void:
	interact_label.hide()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("interact") and can_interact:
		if current_interaction.is_empty():
			return

		current_interaction.sort_custom(_sort_by_nearest)
		var nearest = current_interaction[0]

		if not nearest.is_interactable:
			return

		can_interact = false
		interact_label.hide()

		await nearest.interact.call()

		can_interact = true

func _process(delta: float) -> void:
	if current_interaction.is_empty() or not can_interact:
		interact_label.hide()
		return

	current_interaction.sort_custom(_sort_by_nearest)
	var nearest = current_interaction[0]

	if nearest.is_interactable:
		interact_label.text = nearest.interact_name
		interact_label.show()
	else:
		interact_label.hide()

func _sort_by_nearest(area1, area2):
	var area1_dist = global_position.distance_to(area1.global_position)
	var area2_dist = global_position.distance_to(area2.global_position)
	return area1_dist < area2_dist

func _on_interact_range_area_entered(area: Area2D) -> void:
	if not current_interaction.has(area):
		current_interaction.push_back(area)


func _on_interact_range_area_exited(area: Area2D) -> void:
	current_interaction.erase(area)
