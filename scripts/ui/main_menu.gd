class_name MainMenu
extends Control

@export_file("*.tscn") var first_level_scene: String = ""
@export var default_save_slot: int = 1
@export var intro_hold_duration: float = 3.0
@export var fade_out_menu_duration: float = 0.35
@export var fade_out_scene_duration: float = 0.35

@onready var new_game_button: Button = %NewGameButton
@onready var continue_button: Button = %ContinueButton
@onready var settings_button: Button = %SettingsButton
@onready var quit_button: Button = %QuitButton
@onready var settings_panel: Control = %SettingsPanel
@onready var close_settings_button: Button = %CloseSettingsButton
@onready var fade_overlay: ColorRect = %FadeOverlay

var _is_transitioning: bool = false

func _ready() -> void:
	if is_instance_valid(settings_panel):
		settings_panel.visible = false

	if is_instance_valid(quit_button) and OS.has_feature("web"):
		quit_button.visible = false

	_connect_buttons()
	_refresh_continue_state()
	_play_enter_fade()

	if is_instance_valid(new_game_button):
		new_game_button.grab_focus()

func _play_enter_fade() -> void:
	if not is_instance_valid(fade_overlay):
		return
	fade_overlay.visible = true
	fade_overlay.modulate.a = 1.0
	fade_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	var tween: Tween = create_tween()
	if intro_hold_duration > 0.0:
		tween.tween_interval(intro_hold_duration)
	tween.tween_property(fade_overlay, "modulate:a", 0.0, fade_out_menu_duration)
	await tween.finished
	if is_instance_valid(fade_overlay):
		fade_overlay.visible = false
		fade_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _connect_buttons() -> void:
	if is_instance_valid(new_game_button) and not new_game_button.pressed.is_connected(_on_new_game_pressed):
		new_game_button.pressed.connect(_on_new_game_pressed)
	if is_instance_valid(continue_button) and not continue_button.pressed.is_connected(_on_continue_pressed):
		continue_button.pressed.connect(_on_continue_pressed)
	if is_instance_valid(settings_button) and not settings_button.pressed.is_connected(_on_settings_pressed):
		settings_button.pressed.connect(_on_settings_pressed)
	if is_instance_valid(quit_button) and not quit_button.pressed.is_connected(_on_quit_pressed):
		quit_button.pressed.connect(_on_quit_pressed)
	if is_instance_valid(close_settings_button) and not close_settings_button.pressed.is_connected(_on_close_settings_pressed):
		close_settings_button.pressed.connect(_on_close_settings_pressed)

func _refresh_continue_state() -> void:
	if not is_instance_valid(continue_button):
		return
	continue_button.disabled = not _has_existing_save(default_save_slot)

func _has_existing_save(slot: int) -> bool:
	var save_system: Node = _get_autoload(&"SaveSystem")
	if save_system != null:
		if save_system.has_method("has_save"):
			return bool(save_system.call("has_save", slot))
		if save_system.has_method("save_exists"):
			return bool(save_system.call("save_exists", slot))
	return false

func _on_new_game_pressed() -> void:
	if _is_transitioning:
		return
	_start_scene_transition(first_level_scene, false)

func _on_continue_pressed() -> void:
	if _is_transitioning:
		return
	_start_scene_transition(first_level_scene, true)

func _on_settings_pressed() -> void:
	if is_instance_valid(settings_panel):
		settings_panel.visible = true
	if is_instance_valid(close_settings_button):
		close_settings_button.grab_focus()

func _on_close_settings_pressed() -> void:
	if is_instance_valid(settings_panel):
		settings_panel.visible = false
	if is_instance_valid(settings_button):
		settings_button.grab_focus()

func _on_quit_pressed() -> void:
	if _is_transitioning:
		return
	get_tree().quit()

func _start_scene_transition(target_scene: String, load_existing_save: bool) -> void:
	if target_scene.is_empty():
		push_warning("MainMenu: first_level_scene is not assigned.")
		return

	var tree: SceneTree = get_tree()
	if tree == null or tree.root == null:
		return

	_is_transitioning = true
	_set_buttons_disabled(true)

	var transition_layer: CanvasLayer = CanvasLayer.new()
	transition_layer.layer = 100
	var transition_rect: ColorRect = ColorRect.new()
	transition_rect.color = Color.BLACK
	transition_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	transition_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	transition_rect.modulate.a = 0.0
	transition_layer.add_child(transition_rect)
	tree.root.add_child(transition_layer)

	var fade_to_black: Tween = transition_layer.create_tween()
	fade_to_black.tween_property(transition_rect, "modulate:a", 1.0, fade_out_scene_duration)
	await fade_to_black.finished

	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	if load_existing_save:
		var save_system: Node = _get_autoload(&"SaveSystem")
		if save_system != null and save_system.has_method("load_game"):
			save_system.call("load_game", default_save_slot)
		var event_bus_load: Node = _get_autoload(&"EventBus")
		if event_bus_load != null:
			event_bus_load.emit_signal(&"game_loaded", default_save_slot)

	var handled_externally: bool = false
	var event_bus: Node = _get_autoload(&"EventBus")
	if event_bus != null and event_bus.has_signal(&"level_transition_requested"):
		var listeners: Array[Dictionary] = event_bus.get_signal_connection_list(&"level_transition_requested")
		event_bus.emit_signal(&"level_transition_requested", target_scene)
		handled_externally = not listeners.is_empty()

	if not handled_externally:
		tree.change_scene_to_file(target_scene)

	transition_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fade_from_black: Tween = transition_layer.create_tween()
	fade_from_black.tween_interval(0.05)
	fade_from_black.tween_property(transition_rect, "modulate:a", 0.0, fade_out_scene_duration)
	fade_from_black.finished.connect(transition_layer.queue_free)

	if handled_externally:
		queue_free()

func _set_buttons_disabled(disabled_state: bool) -> void:
	if is_instance_valid(new_game_button):
		new_game_button.disabled = disabled_state
	if is_instance_valid(continue_button):
		continue_button.disabled = disabled_state or not _has_existing_save(default_save_slot)
	if is_instance_valid(settings_button):
		settings_button.disabled = disabled_state
	if is_instance_valid(quit_button):
		quit_button.disabled = disabled_state

func _get_autoload(autoload_name: StringName) -> Node:
	var tree: SceneTree = get_tree()
	if tree == null or tree.root == null:
		return null
	return tree.root.get_node_or_null(NodePath(autoload_name))
