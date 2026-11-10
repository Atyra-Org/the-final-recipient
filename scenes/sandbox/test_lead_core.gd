extends Node2D
## Interactive sandbox bench: draw a stroke -> $1 recognizer -> EventBus.
## Left click + drag draws, release recognizes. F5 save, F9 load, C clear.

const Recognizer := preload("res://scripts/core/math/unistroke_recognizer.gd")
const SaveSystemScript := preload("res://scripts/core/save_system.gd")

const SANDBOX_SLOT := 1
const MIN_STROKE_POINTS := 3

@onready var _stroke: Line2D = $Stroke
@onready var _recognition_label: Label = $UI/RecognitionLabel
@onready var _status_label: Label = $UI/StatusLabel

var _recognizer = Recognizer.new()
var _points: Array[Vector2] = []
var _drawing := false
var _loop_count := 0


func _ready() -> void:
	_reset_bench()
	_status_label.text = "sandbox ready — LMB drag to draw | F5 save | F9 load | C clear"


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_begin_stroke(event.position)
		elif _drawing:
			_end_stroke()
		return

	if event is InputEventMouseMotion and _drawing:
		_extend_stroke(event.position)
		return

	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_F5:
				_save_dummy_state()
			KEY_F9:
				_load_dummy_state()
			KEY_C:
				_reset_bench()
				_status_label.text = "cleared"


# --- Drawing ----------------------------------------------------------------

func _begin_stroke(position: Vector2) -> void:
	_drawing = true
	_points.clear()
	_stroke.clear_points()
	_extend_stroke(position)
	_recognition_label.text = "drawing..."


func _extend_stroke(position: Vector2) -> void:
	# ponytail: accept every motion event; add distance-gating if brush strokes get dense.
	if not _points.is_empty() and _points[-1].distance_to(position) < 1.0:
		return
	_points.append(position)
	_stroke.add_point(position)


func _end_stroke() -> void:
	_drawing = false
	if _points.size() < MIN_STROKE_POINTS:
		_recognition_label.text = "stroke too short (min %d points)" % MIN_STROKE_POINTS
		EventBus.gesture_failed.emit()
		return

	var result: Dictionary = _recognizer.recognize(_points)
	var gesture_name: String = result["name"]
	var score: float = result["score"]

	if gesture_name.is_empty():
		_recognition_label.text = "no match (score 0.000)"
		EventBus.gesture_failed.emit()
		return

	_recognition_label.text = "match: %s   confidence: %.3f" % [gesture_name, score]
	EventBus.gesture_recognized.emit(gesture_name, score)
	print("[sandbox] %d points -> %s (%.3f)" % [_points.size(), gesture_name, score])


func _reset_bench() -> void:
	_drawing = false
	_points.clear()
	_stroke.clear_points()
	_recognition_label.text = "match: —   confidence: —"


# --- Save / load ------------------------------------------------------------

func _save_dummy_state() -> void:
	_loop_count += 1
	var payload := {
		"current_chapter": "sandbox_chapter",
		"player_position": Vector2(320.0, 180.0),
		"unlocked_clues": ["sandbox_clue_a", "sandbox_clue_b"],
		"timeline_loop_count": _loop_count,
	}
	if SaveSystemScript.save_game(SANDBOX_SLOT, payload):
		var message := "saved slot %d — loop_count=%d pos=(320, 180)" % [SANDBOX_SLOT, _loop_count]
		_status_label.text = message
		print("[sandbox] " + message)
	else:
		_status_label.text = "save FAILED (slot %d)" % SANDBOX_SLOT
		push_error("sandbox: save failed")


func _load_dummy_state() -> void:
	var data: Dictionary = SaveSystemScript.load_game(SANDBOX_SLOT)
	if data.is_empty():
		_status_label.text = "load FAILED — no save in slot %d" % SANDBOX_SLOT
		print("[sandbox] load slot %d: empty" % SANDBOX_SLOT)
		return

	var position: Vector2 = data.get("player_position", Vector2.ZERO)
	_loop_count = int(data.get("timeline_loop_count", 0))
	var message := "loaded slot %d — loop_count=%d pos=(%.1f, %.1f)" % [
		SANDBOX_SLOT, _loop_count, position.x, position.y
	]
	_status_label.text = message
	print("[sandbox] " + message)