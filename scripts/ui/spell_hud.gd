extends CanvasLayer

class DrawingControl extends Control:
	var hud: CanvasLayer

	func _draw() -> void:
		if hud != null:
			hud.call("_draw_hud", self)

const SPELLS: Array[Dictionary] = [
	{"id": "line_horizontal", "name": "ARCANE BOLT", "mana": 100},
	{"id": "circle", "name": "ARCANE BURST", "mana": 50},
	{"id": "triangle", "name": "ARCANE WARD", "mana": 50},
	{"id": "star", "name": "STAR BIND", "mana": 65}
]

var _player: Node
var _event_bus: Node
var _feedback_text: String = ""
var _highlighted_spell: String = ""
var _feedback_timer: float = 0.0
var _cards: Dictionary = {}
var _font: Font = preload("res://assets/fonts/monogram/ttf/monogram.ttf")
var _canvas: DrawingControl
var _hud_modulate: Color = Color.WHITE

func _ready() -> void:
	layer = 30
	visible = false
	_hud_modulate.a = 1.0
	_canvas = get_node_or_null(^"DrawingControl") as DrawingControl
	if _canvas != null:
		_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_canvas.modulate = _hud_modulate
		_canvas.hud = self
	_set_event_bus(get_tree().root.get_node_or_null(^"EventBus"))
	get_tree().node_added.connect(_on_tree_node_added)
	set_process(true)

func _exit_tree() -> void:
	if is_inside_tree() and get_tree().node_added.is_connected(_on_tree_node_added):
		get_tree().node_added.disconnect(_on_tree_node_added)
	_set_event_bus(null)

func _on_tree_node_added(node: Node) -> void:
	if node.name == &"EventBus":
		_set_event_bus(node)
	elif node.is_in_group(&"player") or node.name == &"Player":
		_player = node
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
	if next_player == null:
		var scene_root: Node = get_tree().current_scene
		if scene_root != null and scene_root.name != &"MainMenu":
			next_player = scene_root.find_child("Player", true, false)
		if next_player == null and scene_root != null and scene_root.name != &"MainMenu":
			next_player = get_tree().root.get_node_or_null(^"Player")
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

func _draw_hud(canvas: Control) -> void:
	if not visible:
		return
	var viewport_size: Vector2 = canvas.get_viewport_rect().size
	var panel_width: float = 192.0
	var panel_height: float = 112.0
	var origin: Vector2 = Vector2(viewport_size.x - panel_width - 8.0, viewport_size.y - panel_height - 8.0)
	canvas.draw_rect(Rect2(origin, Vector2(panel_width, panel_height)), Color(0.035, 0.025, 0.06, 0.88), true)
	canvas.draw_rect(Rect2(origin, Vector2(panel_width, panel_height)), Color(0.55, 0.35, 0.75), false, 1.0)
	canvas.draw_string(_font, origin + Vector2(7.0, 15.0), "SPELL GUIDE", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.94, 0.84, 1.0))
	for index: int in SPELLS.size():
		var spell: Dictionary = SPELLS[index]
		var card_origin: Vector2 = origin + Vector2(7.0, 20.0 + float(index) * 19.0)
		var ready: bool = is_spell_ready(String(spell["id"]))
		var highlighted: bool = is_spell_highlighted(String(spell["id"]))
		var color: Color = Color(0.98, 0.78, 1.0) if highlighted else (Color(0.82, 0.91, 0.7) if ready else Color(0.45, 0.43, 0.5))
		if highlighted:
			canvas.draw_rect(Rect2(card_origin - Vector2(3.0, 12.0), Vector2(panel_width - 8.0, 17.0)), Color(0.42, 0.22, 0.55, 0.7), true)
		_draw_gesture(canvas, String(spell["id"]), card_origin + Vector2(8.0, -6.0), color)
		canvas.draw_string(_font, card_origin + Vector2(21.0, 0.0), String(spell["name"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, color)
		canvas.draw_string(_font, card_origin + Vector2(146.0, 0.0), "%d MP" % int(spell["mana"]), HORIZONTAL_ALIGNMENT_RIGHT, 38, 9, color)
	var buff_text: String = "ATTACK BUFF: ACTIVE" if is_buff_active() else "ATTACK BUFF: --"
	canvas.draw_string(_font, origin + Vector2(7.0, 99.0), buff_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.9, 0.75, 0.4))
	if not _feedback_text.is_empty():
		var feedback_color: Color = Color(1.0, 0.45, 0.38) if _feedback_text == "RUNE FAILED" else Color(0.75, 1.0, 0.65)
		canvas.draw_string(_font, origin + Vector2(7.0, 110.0), _feedback_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, feedback_color)

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
