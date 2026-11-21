class_name HealthBar
extends ProgressBar

@onready var timer: Timer = $Timer
@onready var damage_bar: ProgressBar = $DamageBar

var health: int = 0 : set = _set_health


func _set_health(new_health: int) -> void:
	var prev_health = health

	health = clampi(new_health, 0, int(max_value))
	value = health

	if health < prev_health:
		timer.start()
	else:
		damage_bar.value = health


func init_health(starting_health: int) -> void:
	max_value = starting_health
	damage_bar.max_value = starting_health

	health = starting_health
	damage_bar.value = starting_health

	timer.stop()
