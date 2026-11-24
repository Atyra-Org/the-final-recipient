class_name ManaBar
extends ProgressBar

var mana: int = 0 : set = _set_mana


func _set_mana(new_mana: int) -> void:
	mana = clampi(new_mana, 0, int(max_value))
	value = mana


func init_mana(starting_mana: int) -> void:
	max_value = starting_mana
	mana = starting_mana
	value = starting_mana
