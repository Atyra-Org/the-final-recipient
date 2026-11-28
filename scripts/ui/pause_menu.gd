extends CanvasLayer
class_name PauseMenu

const MAIN_MENU_PATH: String = "res://scenes/ui/main_menu.tscn"

@onready var panel: PanelContainer = $Root/Center/Panel
@onready var shade: ColorRect = $Root/Shade
@onready var resume_button: Button = $Root/Center/Panel/Content/Resume
@onready var restart_button: Button = $Root/Center/Panel/Content/Restart
@onready var main_menu_button: Button = $Root/Center/Panel/Content/MainMenu
@onready var quit_button: Button = $Root/Center/Panel/Content/Quit

var is_visible_menu: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	shade.hide()
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.hide()
	is_visible_menu = false
	resume_button.pressed.connect(resume_game)
	restart_button.pressed.connect(restart_game)
	main_menu_button.pressed.connect(open_main_menu)
	quit_button.pressed.connect(quit_game)
	if OS.has_feature("web"):
		quit_button.hide()

func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel") or _is_main_menu() or _is_game_over():
		return
	toggle_pause()
	get_viewport().set_input_as_handled()

func toggle_pause() -> void:
	if _is_game_over() or _is_main_menu():
		return
	if is_visible_menu:
		resume_game()
	else:
		_set_game_state(1)
		is_visible_menu = true
		visible = true
		shade.show()
		shade.mouse_filter = Control.MOUSE_FILTER_STOP
		panel.show()

func resume_game() -> void:
	_set_game_state(0)
	is_visible_menu = false
	visible = false
	shade.hide()
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.hide()

func restart_game() -> void:
	resume_game()
	get_tree().reload_current_scene()

func open_main_menu() -> void:
	resume_game()
	get_tree().change_scene_to_file(MAIN_MENU_PATH)

func quit_game() -> void:
	get_tree().quit()

func _is_main_menu() -> bool:
	var scene: Node = get_tree().current_scene
	return scene != null and scene.scene_file_path == MAIN_MENU_PATH

func _is_game_over() -> bool:
	var manager: Node = get_tree().root.get_node_or_null(^"GameManager")
	return manager != null and int(manager.get("current_state")) == 3

func _set_game_state(state: int) -> void:
	var manager: Node = get_tree().root.get_node_or_null(^"GameManager")
	if manager != null:
		manager.call("set_game_state", state)
