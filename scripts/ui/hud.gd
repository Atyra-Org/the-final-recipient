extends CanvasLayer

@onready var health_bar: HealthBar = $HealthBar
@onready var mana_bar: ManaBar = $ManaBar
@onready var player = get_parent().get_node("Player")

func _ready() -> void:
	mana_bar.init_mana(player.max_mana)
	player.mana_changed.connect(_on_player_mana_changed)
	player.health_changed.connect(_on_player_health_changed)
	_on_player_health_changed(player.health, player.max_health)


func _on_player_health_changed(current_health, max_health):
	health_bar.max_value = max_health
	health_bar.health = current_health

func _on_player_mana_changed(current_mana: int, max_mana: int) -> void:
	mana_bar.max_value = max_mana
	mana_bar.mana = current_mana
