extends SceneTree


const Recognizer := preload("res://scripts/core/math/unistroke_recognizer.gd")
const EventBusScript := preload("res://scripts/core/event_bus.gd")

var _failures := 0
var _checks := 0


func _initialize() -> void:
	print("=== the-final-recipient :: Task 1 & 2 test run ===")
	_case_a_event_bus()
	_case_b_horizontal_line()
	_case_c_invalid_stroke()
	_case_d_direction_invariance()
	_check_variants("v", [Vector2.ZERO, Vector2(60.0, 100.0), Vector2(120.0, 0.0)])
	_check_variants("caret", [Vector2(0.0, 100.0), Vector2(60.0, 0.0), Vector2(120.0, 100.0)])
	_check_variants("star", [Vector2(60.0, 0.0), Vector2(95.0, 110.0), Vector2(0.0, 42.0), Vector2(120.0, 42.0), Vector2(25.0, 110.0), Vector2(60.0, 0.0)])
	_check_variants("zigzag", [Vector2.ZERO, Vector2(40.0, 80.0), Vector2(80.0, 0.0), Vector2(120.0, 80.0), Vector2(160.0, 0.0)])
	_check_variants("line_horizontal", [Vector2.ZERO, Vector2(60.0, 0.0), Vector2(120.0, 0.0)])
	_check_variants("circle", _closed_circle(32, 80.0))
	_check_variants("triangle", [Vector2.ZERO, Vector2(120.0, 0.0), Vector2(60.0, -104.0), Vector2.ZERO])
	_case_manual_star_strokes()
	print("=== %d checks, %d failed ===" % [_checks, _failures])
	quit(1 if _failures > 0 else 0)


func _check(label: String, condition: bool, detail: String = "") -> void:
	_checks += 1
	if condition:
		print("  PASS  %s%s" % [label, (" :: " + detail) if detail else ""])
	else:
		_failures += 1
		print("  FAIL  %s%s" % [label, (" :: " + detail) if detail else ""])


func _case_a_event_bus() -> void:
	print("[Case A] EventBus signal emission/reception")
	var bus: Node = root.get_node_or_null("EventBus")
	if bus == null:

		bus = EventBusScript.new()
		root.add_child(bus)

	var seen: Dictionary = {}
	bus.gesture_recognized.connect(func(n: String, s: float) -> void: seen["gesture"] = [n, s])
	bus.gesture_failed.connect(func() -> void: seen["failed"] = true)
	bus.letter_trigger_activated.connect(func(id: String) -> void: seen["letter"] = id)
	bus.player_state_changed.connect(func(s: String) -> void: seen["state"] = s)

	bus.gesture_recognized.emit("circle", 0.91)
	bus.gesture_failed.emit()
	bus.letter_trigger_activated.emit("entry_07")
	bus.player_state_changed.emit("DIALOGUE")

	_check("gesture_recognized payload", seen.get("gesture") == ["circle", 0.91], str(seen.get("gesture")))
	_check("gesture_failed received", seen.get("failed") == true)
	_check("letter_trigger_activated payload", seen.get("letter") == "entry_07", str(seen.get("letter")))
	_check("player_state_changed payload", seen.get("state") == "DIALOGUE", str(seen.get("state")))
	_check("all four core signals declared",
		bus.has_signal("gesture_recognized") and bus.has_signal("gesture_failed")
		and bus.has_signal("letter_trigger_activated") and bus.has_signal("player_state_changed"))


func _case_b_horizontal_line() -> void:
	print("[Case B] rough horizontal line -> line_horizontal, score >= 0.75")
	var recognizer: Recognizer = Recognizer.new()
	var stroke: Array[Vector2] = []
	for i: int in 25:
		var x: float = float(i) * 12.0

		var y: float = sin(float(i) * 1.7) * 3.0
		stroke.append(Vector2(x, y))

	var result: Dictionary = recognizer.recognize(stroke)
	print("  -> result = %s" % [result])
	_check("recognized == line_horizontal", result["name"] == "line_horizontal", str(result["name"]))
	_check("score >= 0.75", result["score"] >= 0.75, "score=%.4f" % result["score"])


	var normalized: Array[Vector2] = recognizer.normalize(stroke)
	_check("resample yields 64 points", normalized.size() == Recognizer.POINT_COUNT, "n=%d" % normalized.size())
	var box: Rect2 = Rect2(normalized[0], Vector2.ZERO)
	for p: Vector2 in normalized:
		box = box.expand(p)
	_check("scaled to 250 bounding box", is_equal_approx(maxf(box.size.x, box.size.y), 250.0),
		"longest=%.4f" % maxf(box.size.x, box.size.y))
	_check("centroid at origin", recognizer.centroid(normalized).length() < 0.001,
		"|centroid|=%.6f" % recognizer.centroid(normalized).length())


func _case_c_invalid_stroke() -> void:
	print("[Case C] invalid / noisy strokes -> graceful failure")
	var recognizer: Recognizer = Recognizer.new()

	var empty: Array[Vector2] = []
	var empty_result: Dictionary = recognizer.recognize(empty)
	_check("empty stroke -> no name, score 0",
		empty_result["name"] == "" and empty_result["score"] == 0.0, str(empty_result))

	var two_point: Array[Vector2] = [Vector2.ZERO, Vector2(10.0, 0.0)]
	var two_result: Dictionary = recognizer.recognize(two_point)
	_check("2-point stroke rejected (below MIN_POINTS)",
		two_result["name"] == "" and two_result["score"] == 0.0, str(two_result))


	var duplicate: Array[Vector2] = []
	for i: int in 10:
		duplicate.append(Vector2(50.0, 50.0))
	var dup_result: Dictionary = recognizer.recognize(duplicate)
	_check("zero-length stroke rejected (no NaN)",
		dup_result["name"] == "" and not is_nan(dup_result["score"]), str(dup_result))


	recognizer.add_template("bogus", [Vector2.ZERO, Vector2.ZERO])
	var after: Dictionary = recognizer.recognize([Vector2(0, 0), Vector2(5, 0), Vector2(9, 1), Vector2(14, 0)])
	_check("degenerate template rejected, recognizer still functional",
		after["name"] != "bogus" and after["score"] >= 0.0, str(after))


func _case_d_direction_invariance() -> void:
	print("[Case D] stroke direction must not change the match")
	var recognizer: Recognizer = Recognizer.new()

	var circle := _closed_circle(60, 90.0)
	var circle_ccw: Array[Vector2] = []
	for p: Vector2 in circle:
		circle_ccw.append(Vector2(320.0, 180.0) * 2.0 - p)
	var tri := _closed_triangle(90.0)
	var tri_ccw: Array[Vector2] = []
	for p: Vector2 in tri:
		tri_ccw.append(Vector2(320.0, 180.0) * 2.0 - p)

	var cw_result: Dictionary = recognizer.recognize(circle)
	var ccw_result: Dictionary = recognizer.recognize(circle_ccw)
	print("  -> circle CW  = %s" % [cw_result])
	print("  -> circle CCW = %s" % [ccw_result])
	_check("circle CW -> circle", cw_result["name"] == "circle" and cw_result["score"] >= 0.75, str(cw_result))
	_check("circle CCW -> circle", ccw_result["name"] == "circle" and ccw_result["score"] >= 0.75, str(ccw_result))

	var tri_cw_result: Dictionary = recognizer.recognize(tri)
	var tri_ccw_result: Dictionary = recognizer.recognize(tri_ccw)
	print("  -> triangle CW  = %s" % [tri_cw_result])
	print("  -> triangle CCW = %s" % [tri_ccw_result])
	_check("triangle CW -> triangle", tri_cw_result["name"] == "triangle" and tri_cw_result["score"] >= 0.75,
		str(tri_cw_result))
	_check("triangle CCW -> triangle",
		tri_ccw_result["name"] == "triangle" and tri_ccw_result["score"] >= 0.75, str(tri_ccw_result))


	_check("circle not mistaken for triangle", cw_result["name"] != "triangle" and ccw_result["name"] != "triangle")
	_check("triangle not mistaken for circle", tri_cw_result["name"] != "circle" and tri_ccw_result["name"] != "circle")


func _closed_circle(steps: int, radius: float) -> Array[Vector2]:
	var out: Array[Vector2] = []
	for i: int in steps + 1:
		var t: float = TAU * float(i) / float(steps)
		out.append(Vector2(320.0 + cos(t) * radius, 180.0 + sin(t) * radius))
	return out


func _closed_triangle(radius: float) -> Array[Vector2]:
	var corners: Array[Vector2] = [
		Vector2(320.0, 180.0 - radius),
		Vector2(320.0 + radius * 0.95, 180.0 + radius * 0.7),
		Vector2(320.0 - radius * 0.95, 180.0 + radius * 0.7),
		Vector2(320.0, 180.0 - radius),
	]
	var out: Array[Vector2] = []
	for i: int in 3:
		for k: int in 20:
			out.append(corners[i].lerp(corners[i + 1], float(k) / 20.0))
	out.append(corners[3])
	return out


func _check_variants(gesture_name: String, vertices: Array[Vector2]) -> void:
	var recognizer: Recognizer = Recognizer.new()
	for variant: int in 5:
		var stroke: Array[Vector2] = []
		for segment: int in vertices.size() - 1:
			for sample: int in 16:
				var point: Vector2 = vertices[segment].lerp(vertices[segment + 1], float(sample) / 16.0)
				if variant >= 2:
					point = point.rotated(-0.35 if variant == 2 else 0.4) * 1.7 + Vector2(420.0, -170.0)
				if variant == 4:
					point += Vector2(sin(float(stroke.size()) * 1.7), cos(float(stroke.size()) * 2.1)) * 1.5
				stroke.append(point)
		var endpoint: Vector2 = vertices[-1]
		if variant >= 2:
			endpoint = endpoint.rotated(-0.35 if variant == 2 else 0.4) * 1.7 + Vector2(420.0, -170.0)
		stroke.append(endpoint)
		if variant == 1 or variant == 3 or variant == 4:
			stroke.reverse()
		var result: Dictionary = recognizer.recognize(stroke)
		_check("%s variant %d name" % [gesture_name, variant], result["name"] == gesture_name, str(result))
		_check("%s variant %d score >= 0.90" % [gesture_name, variant], result["score"] >= 0.90, str(result["score"]))


func _case_manual_star_strokes() -> void:
	var top: Array[Vector2] = [Vector2(320.0, 20.0), Vector2(361.0, 123.0), Vector2(264.0, 62.0), Vector2(376.0, 55.0), Vector2(284.0, 127.0), Vector2(320.0, 20.0)]
	var bottom_left: Array[Vector2] = [Vector2(284.0, 127.0), Vector2(320.0, 20.0), Vector2(361.0, 123.0), Vector2(264.0, 62.0), Vector2(376.0, 55.0), Vector2(284.0, 127.0)]
	var open_star: Array[Vector2] = top.duplicate()
	open_star[-1] = top[0].lerp(top[1], 0.07)
	var candidates: Array = [
		_sample_edges(bottom_left, 14),
		_sample_edges(top, 14),
		_sample_edges(_reverse_points(top), 14),
		_sample_edges(open_star, 14),
	]
	var recognizer: Recognizer = Recognizer.new()
	for i: int in candidates.size():
		var stroke: Array[Vector2] = _add_mouse_noise(candidates[i], i)
		var result: Dictionary = recognizer.recognize(stroke)
		_check("manual star %d -> star" % i, result["name"] == "star", str(result))
		_check("manual star %d high score" % i, result["score"] >= 0.90, str(result))
	var triangle: Array[Vector2] = _sample_edges([Vector2(320.0, 20.0), Vector2(376.0, 127.0), Vector2(264.0, 127.0), Vector2(320.0, 20.0)], 24)
	var triangle_result: Dictionary = recognizer.recognize(triangle)
	_check("three-sided triangle remains triangle", triangle_result["name"] == "triangle", str(triangle_result))
	var open_triangle: Array[Vector2] = triangle.duplicate()
	open_triangle[-1] = triangle[0].lerp(triangle[1], 0.08)
	var open_triangle_result: Dictionary = recognizer.recognize(open_triangle)
	_check("open three-sided triangle is not star", open_triangle_result["name"] != "star", str(open_triangle_result))


func _sample_edges(vertices: Array[Vector2], samples: int) -> Array[Vector2]:
	var points: Array[Vector2] = []
	for edge: int in vertices.size() - 1:
		for sample: int in samples:
			points.append(vertices[edge].lerp(vertices[edge + 1], float(sample) / float(samples)))
	points.append(vertices[-1])
	return points


func _reverse_points(points: Array[Vector2]) -> Array[Vector2]:
	var reversed_points: Array[Vector2] = points.duplicate()
	reversed_points.reverse()
	return reversed_points


func _add_mouse_noise(points: Array[Vector2], variant: int) -> Array[Vector2]:
	var noisy: Array[Vector2] = []
	for i: int in points.size():
		var point: Vector2 = points[i] + Vector2(sin(float(i) * 1.7), cos(float(i) * 1.1)) * float(variant + 1) * 0.55
		noisy.append(point.rotated(0.17) * 1.2 + Vector2(350.0, -120.0))
	return noisy
