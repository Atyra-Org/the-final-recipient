extends Area2D

var enemies_in_range: Array[Node2D] = []

func _ready() -> void:
	monitoring = false
	


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("enemy"):
		enemies_in_range.append(body)
		
func _on_body_exited(body: Node2D) -> void:
	enemies_in_range.erase(body)
