extends CanvasLayer
class_name EndScreen

const MAIN_MENU_PATH: String = "res://scenes/ui/main_menu.tscn"

@onready var overlay: ColorRect = $Root/Overlay
@onready var title_label: Label = $Root/Center/Content/Title
@onready var subtitle_label: Label = $Root/Center/Content/Subtitle
@onready var primary_button: Button = $Root/Center/Content/Buttons/Primary
@onready var secondary_button: Button = $Root/Center/Content/Buttons/Secondary

var mode: String = ""

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	primary_button.pressed.connect(_on_primary_pressed)
	secondary_button.pressed.connect(_on_secondary_pressed)

func show_victory(boss_name: String = "The Fractured Seal") -> void:
	mode = "VICTORY"
	title_label.text = "SEAL RESTORED"
	title_label.add_theme_color_override(&"font_color", Color("e9c977"))
	subtitle_label.text = boss_name + " has been vanquished."
	primary_button.text = "Main Menu"
	secondary_button.text = "Play Again"
	_show()

func show_game_over() -> void:
	mode = "GAME_OVER"
	title_label.text = "YOU DIED"
	title_label.add_theme_color_override(&"font_color", Color("a8323e"))
	subtitle_label.text = "The corruption consumed you."
	primary_button.text = "Retry"
	secondary_button.text = "Main Menu"
	_show()

func hide_screen() -> void:
	mode = ""
	visible = false
	overlay.modulate.a = 0.0

func _show() -> void:
	visible = true
	overlay.modulate.a = 0.0
	var tween: Tween = create_tween()
	tween.tween_property(overlay, "modulate:a", 0.82, 0.35)

func _on_primary_pressed() -> void:
	if mode == "VICTORY":
		_change_scene(MAIN_MENU_PATH)
	else:
		_reload_scene()

func _on_secondary_pressed() -> void:
	if mode == "VICTORY":
		_reload_scene()
	else:
		_change_scene(MAIN_MENU_PATH)

func _reload_scene() -> void:
	_set_playing()
	get_tree().reload_current_scene()

func _change_scene(path: String) -> void:
	_set_playing()
	get_tree().change_scene_to_file(path)

func _set_playing() -> void:
	var manager: Node = get_tree().root.get_node_or_null(^"GameManager")
	if manager != null:
		manager.call("set_game_state", 0)
