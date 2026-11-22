extends CanvasLayer

@onready var health_bar: HealthBar = $HealthBar
@onready var player = get_parent().get_node("Player")

func _ready() -> void:
	player.health_changed.connect(_on_player_health_changed)
	_on_player_health_changed(player.health, player.max_health)


func _on_player_health_changed(current_health, max_health):
	health_bar.max_value = max_health
	health_bar.health = current_health
