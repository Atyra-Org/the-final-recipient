extends CanvasLayer

const MIN_RECOGNITION_SCORE: float = 0.75
const MIN_POINT_DISTANCE: float = 8.0

@onready var trail_line: Line2D = $TrailLine

var _recognizer: UnistrokeRecognizer = UnistrokeRecognizer.new()
var _points: Array[Vector2] = []
var _is_drawing: bool = false

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("draw"):
		_start_drawing()
	elif event.is_action_released("draw") and _is_drawing:
		_finish_drawing()
	elif event is InputEventMouseMotion and _is_drawing:
		_add_point(event.position)

func _start_drawing() -> void:
	_is_drawing = true
	_points.clear()
	trail_line.clear_points()
	_add_point(get_viewport().get_mouse_position())

func _add_point(pos: Vector2) -> void:
	if not _points.is_empty() and _points[-1].distance_to(pos) < MIN_POINT_DISTANCE:
		return
	_points.append(pos)
	trail_line.add_point(pos)

func _finish_drawing() -> void:
	_is_drawing = false
	trail_line.clear_points()

	if _points.size() < UnistrokeRecognizer.MIN_POINTS:
		return

	var result: Dictionary = _recognizer.recognize(_points)
	var gesture_name: String = result["name"]
	var score: float = result["score"]

	if gesture_name != "" and score >= MIN_RECOGNITION_SCORE:
		EventBus.gesture_recognized.emit(gesture_name, score)
	else:
		EventBus.gesture_failed.emit()
