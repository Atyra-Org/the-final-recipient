class_name BossHealthBar
extends CanvasLayer

@onready var bar: ProgressBar = $Root/Bar
@onready var name_label: Label = $Root/NameLabel

var fill_tween: Tween = null


func setup(display_name: String, max_health: int) -> void:
	name_label.text = display_name
	bar.max_value = max_health
	bar.value = max_health


func set_health(current: int, max_health: int) -> void:
	bar.max_value = max_health
	if fill_tween != null and fill_tween.is_valid():
		fill_tween.kill()
	fill_tween = create_tween()
	fill_tween.tween_property(bar, "value", float(current), 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)