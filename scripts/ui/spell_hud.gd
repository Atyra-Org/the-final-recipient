extends CanvasLayer

const SPELLS: Array[Dictionary] = [
	{"id": "line_horizontal", "name": "ARCANE BOLT", "effect": "DASH BURST", "mana": 100},
	{"id": "circle", "name": "ARCANE BURST", "effect": "HEAL", "mana": 50},
	{"id": "triangle", "name": "ARCANE WARD", "effect": "ATK BUFF", "mana": 50},
	{"id": "star", "name": "STAR BIND", "effect": "STAR BIND", "mana": 65}
]

var _player: Node
var _event_bus: Node
var _feedback_text: String = ""
var _highlighted_spell: String = ""
var _feedback_timer: float = 0.0
var _cards: Dictionary = {}
var _font: Font = preload("res://assets/fonts/monogram/ttf/monogram.ttf")
var _canvas: Control
var _hud_modulate: Color = Color.WHITE
var _guide_expanded: bool = true
var _panel_position: Vector2 = Vector2.ZERO

func toggle_guide() -> void:
	_guide_expanded = not _guide_expanded
	if _canvas != null:
		_canvas.queue_redraw()

func is_guide_expanded() -> bool:
	return _guide_expanded

func _input(event: InputEvent) -> void:
	if not event is InputEventKey:
		return
	var key_event: InputEventKey = event as InputEventKey
	if key_event.keycode != KEY_J or not key_event.pressed or key_event.echo:
		return
	if get_tree().paused:
		return
	var manager: Node = get_tree().root.get_node_or_null(^"GameManager")
	if manager != null and int(manager.get("current_state")) in [1, 3]:
		return
	toggle_guide()

func _on_scene_changed() -> void:
	_player = null
	var scene_root: Node = get_tree().current_scene
	visible = scene_root != null and scene_root.name != &"MainMenu"
	if _canvas != null:
		_canvas.visible = visible
		_canvas.queue_redraw()

func _ready() -> void:
	layer = 30
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_hud_modulate.a = 1.0
	_canvas = get_node_or_null(^"DrawingControl") as Control
	if _canvas != null:
		_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_canvas.modulate = _hud_modulate
		_canvas.draw.connect(_draw_hud)
	_set_event_bus(get_tree().root.get_node_or_null(^"EventBus"))
	get_tree().node_added.connect(_on_tree_node_added)
	get_tree().scene_changed.connect(_on_scene_changed)
	_on_scene_changed()
	set_process(true)

func _find_player(node: Node) -> Node:
	if node.is_in_group(&"player") or node.name.to_lower() == "player":
		return node
	for property: Dictionary in node.get_property_list():
		if property.get("name") == "mana":
			if node.get("is_attack_buff_active") != null:
				return node
	for child: Node in node.get_children():
		var found: Node = _find_player(child)
		if found != null:
			return found
	return null

func _exit_tree() -> void:
	if is_inside_tree() and get_tree().node_added.is_connected(_on_tree_node_added):
		get_tree().node_added.disconnect(_on_tree_node_added)
	if is_inside_tree() and get_tree().scene_changed.is_connected(_on_scene_changed):
		get_tree().scene_changed.disconnect(_on_scene_changed)
	_set_event_bus(null)

func _on_tree_node_added(node: Node) -> void:
	if node.name == &"EventBus":
		_set_event_bus(node)
	elif _find_player(node) != null:
		_player = _find_player(node)
		visible = true
		if _canvas != null:
			_canvas.queue_redraw()

func _set_event_bus(bus: Node) -> void:
	if _event_bus == bus:
		return
	if _event_bus != null:
		if _event_bus.has_signal(&"gesture_recognized") and _event_bus.is_connected(&"gesture_recognized", _on_gesture_recognized):
			_event_bus.disconnect(&"gesture_recognized", _on_gesture_recognized)
		if _event_bus.has_signal(&"gesture_failed") and _event_bus.is_connected(&"gesture_failed", _on_gesture_failed):
			_event_bus.disconnect(&"gesture_failed", _on_gesture_failed)
	_event_bus = bus
	if _event_bus != null:
		if _event_bus.has_signal(&"gesture_recognized") and not _event_bus.is_connected(&"gesture_recognized", _on_gesture_recognized):
			_event_bus.connect(&"gesture_recognized", _on_gesture_recognized)
		if _event_bus.has_signal(&"gesture_failed") and not _event_bus.is_connected(&"gesture_failed", _on_gesture_failed):
			_event_bus.connect(&"gesture_failed", _on_gesture_failed)

func _process(delta: float) -> void:
	var players: Array[Node] = get_tree().get_nodes_in_group(&"player")
	var next_player: Node = players[0] if not players.is_empty() else null
	var scene_root: Node = get_tree().current_scene
	if next_player == null and scene_root != null and scene_root.name != &"MainMenu":
		next_player = _find_player(scene_root)
	if next_player != _player:
		if _player != null and _player.has_signal(&"mana_changed") and _player.is_connected(&"mana_changed", _on_mana_changed):
			_player.disconnect(&"mana_changed", _on_mana_changed)
		_player = next_player
		if _player != null and _player.has_signal(&"mana_changed") and not _player.is_connected(&"mana_changed", _on_mana_changed):
			_player.connect(&"mana_changed", _on_mana_changed)
		if _player == null:
			_feedback_text = ""
			_feedback_timer = 0.0
			visible = false
	elif _player == null and _feedback_timer <= 0.0:
		visible = false
	if _player != null:
		visible = true
	if _feedback_timer > 0.0:
		_feedback_timer = maxf(0.0, _feedback_timer - delta)
		if _feedback_timer == 0.0:
			_feedback_text = ""
			visible = _player != null
	if _canvas != null:
		_canvas.visible = visible
		var viewport_size: Vector2 = _canvas.get_viewport_rect().size
		_panel_position = Vector2(maxf(16.0, viewport_size.x - minf(360.0, viewport_size.x - 32.0) - 16.0), 16.0)
		_canvas.queue_redraw()

func is_spell_ready(spell_id: String) -> bool:
	var spell: Dictionary = _spell_for(spell_id)
	return not spell.is_empty() and _player != null and int(_player.get("mana")) >= int(spell["mana"])

func is_buff_active() -> bool:
	return _player != null and bool(_player.get("is_attack_buff_active"))

func get_feedback_text() -> String:
	return _feedback_text

func is_spell_highlighted(spell_id: String) -> bool:
	return _highlighted_spell == spell_id

func _spell_for(spell_id: String) -> Dictionary:
	for spell: Dictionary in SPELLS:
		if String(spell["id"]) == spell_id:
			return spell
	return {}

func _on_gesture_recognized(spell_id: String, score: float) -> void:
	var spell: Dictionary = _spell_for(spell_id)
	if spell.is_empty():
		_feedback_text = "RUNE FAILED"
		_feedback_timer = 1.0
		visible = true
		if _canvas != null:
			_canvas.visible = true
			_canvas.queue_redraw()
		return
	_highlighted_spell = spell_id
	_feedback_text = "CAST: %s (%d%%)" % [String(spell["name"]), roundi(score * 100.0)]
	_feedback_timer = 1.0
	visible = true
	_hud_modulate.a = 1.0
	if _canvas != null:
		_canvas.visible = true
		_canvas.modulate = _hud_modulate
		_canvas.queue_redraw()

func _on_gesture_failed() -> void:
	_highlighted_spell = ""
	_feedback_text = "RUNE FAILED"
	_feedback_timer = 1.0
	visible = true
	_hud_modulate.a = 1.0
	if _canvas != null:
		_canvas.visible = true
		_canvas.modulate = _hud_modulate
		_canvas.queue_redraw()

func _on_mana_changed(_current_mana: int, _maximum_mana: int) -> void:
	if _canvas != null:
		_canvas.queue_redraw()

func _draw_hud() -> void:
	if not visible or _canvas == null:
		return
	var canvas: Control = _canvas
	var viewport_size: Vector2 = canvas.get_viewport_rect().size
	var panel_width: float = minf(360.0, viewport_size.x - 32.0)
	var panel_height: float = minf(208.0, viewport_size.y - 32.0)
	var origin: Vector2 = _panel_position
	if _guide_expanded:
		var panel_rect: Rect2 = Rect2(origin, Vector2(panel_width, panel_height))
		canvas.draw_rect(panel_rect, Color(0.08, 0.06, 0.12, 0.90), true)
		canvas.draw_rect(panel_rect, Color(0.66, 0.53, 0.28, 1.0), false, 2.0)
		canvas.draw_string(_font, origin + Vector2(12.0, 20.0), "SPELL GUIDE  [J]", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.96, 0.9, 0.72))
		canvas.draw_line(origin + Vector2(10.0, 28.0), origin + Vector2(panel_width - 10.0, 28.0), Color(0.55, 0.43, 0.33, 0.9), 1.0)
		for index: int in SPELLS.size():
			var spell: Dictionary = SPELLS[index]
			var row_origin: Vector2 = origin + Vector2(12.0, 52.0 + float(index) * 34.0)
			var mana_color: Color = Color(0.35, 0.95, 1.0) if is_spell_ready(String(spell["id"])) else Color(0.42, 0.45, 0.5)
			var highlighted: bool = is_spell_highlighted(String(spell["id"]))
			if highlighted:
				canvas.draw_rect(Rect2(row_origin - Vector2(5.0, 17.0), Vector2(panel_width - 24.0, 32.0)), Color(0.3, 0.19, 0.42, 0.82), true)
			_draw_gesture(canvas, String(spell["id"]), row_origin + Vector2(10.0, -4.0), Color(0.95, 0.78, 0.4) if highlighted else Color(0.83, 0.76, 0.92))
			canvas.draw_string(_font, row_origin + Vector2(28.0, -3.0), String(spell["name"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1.0, 0.96, 0.9))
			canvas.draw_string(_font, row_origin + Vector2(28.0, 12.0), String(spell["effect"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.7, 0.66, 0.74))
			canvas.draw_string(_font, row_origin + Vector2(panel_width - 100.0, 1.0), "%d MP" % int(spell["mana"]), HORIZONTAL_ALIGNMENT_RIGHT, 76, 16, mana_color)
		canvas.draw_line(origin + Vector2(10.0, panel_height - 26.0), origin + Vector2(panel_width - 10.0, panel_height - 26.0), Color(0.55, 0.43, 0.33, 0.9), 1.0)
		var buff_text: String = "BUFF: ACTIVE" if is_buff_active() else ("BUFF: READY" if _player != null else "BUFF: OFF")
		canvas.draw_string(_font, origin + Vector2(12.0, panel_height - 7.0), buff_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1.0, 0.78, 0.35) if is_buff_active() else Color(0.71, 0.68, 0.74))
	else:
		var badge_size: Vector2 = Vector2(96.0, 26.0)
		var badge_origin: Vector2 = origin
		var badge_rect: Rect2 = Rect2(badge_origin, badge_size)
		canvas.draw_rect(badge_rect, Color(0.08, 0.06, 0.12, 0.90), true)
		canvas.draw_rect(badge_rect, Color(0.66, 0.53, 0.28, 1.0), false, 2.0)
		canvas.draw_string(_font, badge_origin + Vector2(9.0, 19.0), "[J] SPELLS", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.96, 0.9, 0.72))
	if not _feedback_text.is_empty():
		var feedback_color: Color = Color(1.0, 0.48, 0.42) if _feedback_text == "RUNE FAILED" else Color(0.76, 1.0, 0.67)
		var feedback_size: Vector2 = Vector2(240.0, 26.0)
		var feedback_origin: Vector2 = Vector2(maxf(16.0, viewport_size.x - feedback_size.x - 16.0), origin.y + (panel_height if _guide_expanded else 34.0))
		canvas.draw_rect(Rect2(feedback_origin, feedback_size), Color(0.08, 0.06, 0.12, 0.94), true)
		canvas.draw_rect(Rect2(feedback_origin, feedback_size), Color(0.66, 0.53, 0.28, 1.0), false, 1.0)
		canvas.draw_string(_font, feedback_origin + Vector2(10.0, 19.0), _feedback_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, feedback_color)

func _draw_gesture(canvas: Control, spell_id: String, center: Vector2, color: Color) -> void:
	match spell_id:
		"line_horizontal":
			canvas.draw_line(center + Vector2(-6.0, 0.0), center + Vector2(6.0, 0.0), color, 2.0)
		"circle":
			canvas.draw_arc(center, 5.0, 0.0, TAU, 24, color, 1.5)
		"triangle":
			var triangle_points: PackedVector2Array = PackedVector2Array([center + Vector2(0.0, -6.0), center + Vector2(6.0, 5.0), center + Vector2(-6.0, 5.0), center + Vector2(0.0, -6.0)])
			canvas.draw_polyline(triangle_points, color, 1.5)
		"star":
			var star_points: PackedVector2Array = PackedVector2Array()
			for point_index: int in 11:
				var angle: float = -PI / 2.0 + float(point_index) * PI / 5.0
				var radius: float = 6.0 if point_index % 2 == 0 else 2.5
				star_points.append(center + Vector2(cos(angle), sin(angle)) * radius)
			canvas.draw_polyline(star_points, color, 1.5)
