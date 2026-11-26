extends CanvasLayer

const MIN_RECOGNITION_SCORE: float = 0.75
const MIN_POINT_DISTANCE: float = 8.0

@onready var clip_area: Control = $ClipArea
@onready var trail_line: Line2D = $ClipArea/TrailLine
@onready var _magic_book: MagicBook = $"../MagicBook"

var _recognizer: UnistrokeRecognizer = UnistrokeRecognizer.new()
var _points: Array[Vector2] = []
var _is_drawing: bool = false

var _last_line_point: Vector2 = Vector2.ZERO
var _has_last_line_point: bool = false

func _ready() -> void:
	clip_area.clip_contents = true
	clip_area.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _unhandled_input(event: InputEvent) -> void:
	if not _magic_book.is_open:
		return

	if event.is_action_pressed("draw"):
		_start_drawing()
		get_viewport().set_input_as_handled()
	elif event.is_action_released("draw") and _is_drawing:
		_finish_drawing()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and _is_drawing:
		_add_point(event.position)
		get_viewport().set_input_as_handled()

func _process(_delta: float) -> void:
	if _magic_book.is_open:
		_sync_clip_area()
	elif _is_drawing:
		_is_drawing = false
		_points.clear()
		trail_line.clear_points()

func _sync_clip_area() -> void:
	var book_rect: Rect2 = _magic_book.book_texture.get_global_rect()

	var horizontal_inset: float = 50
	var vertical_inset: float = 10

	clip_area.global_position = book_rect.position + Vector2(horizontal_inset, vertical_inset)
	clip_area.size = book_rect.size - Vector2(horizontal_inset * 2, vertical_inset * 2)

func _get_local_point(pos: Vector2) -> Vector2:
	return clip_area.get_global_transform_with_canvas().affine_inverse() * pos

func _is_inside_book(pos: Vector2) -> bool:
	var local_pos: Vector2 = _get_local_point(pos)
	var book_area: Rect2 = Rect2(Vector2.ZERO, clip_area.size)

	return book_area.has_point(local_pos)

func _start_drawing() -> void:
	var mouse_pos: Vector2 = get_viewport().get_mouse_position()

	if not _is_inside_book(mouse_pos):
		return

	_is_drawing = true
	_points.clear()
	trail_line.clear_points()

	_has_last_line_point = false

	_add_point(mouse_pos)

func _add_point(pos: Vector2) -> void:
	var local_pos: Vector2 = _get_local_point(pos)

	if _has_last_line_point:
		if _last_line_point.distance_to(local_pos) < MIN_POINT_DISTANCE:
			return

	trail_line.add_point(local_pos)

	_last_line_point = local_pos
	_has_last_line_point = true

	if _is_inside_book(pos):
		if _points.is_empty() or _points[-1].distance_to(local_pos) >= MIN_POINT_DISTANCE:
			_points.append(local_pos)

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
		_magic_book.close_book()
	else:
		EventBus.gesture_failed.emit()
