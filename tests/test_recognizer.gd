extends SceneTree
## Headless test runner: godot --headless --path . --script tests/test_recognizer.gd
## Exit code 0 = all pass, 1 = failure.

const Recognizer := preload("res://scripts/core/math/unistroke_recognizer.gd")
const EventBusScript := preload("res://scripts/core/event_bus.gd")

var _failures := 0
var _checks := 0


func _initialize() -> void:
	print("=== the-final-recipient :: Task 1 & 2 test run ===")
	_case_a_event_bus()
	_case_b_horizontal_line()
	_case_c_invalid_stroke()
	print("=== %d checks, %d failed ===" % [_checks, _failures])
	quit(1 if _failures > 0 else 0)


func _check(label: String, condition: bool, detail: String = "") -> void:
	_checks += 1
	if condition:
		print("  PASS  %s%s" % [label, (" :: " + detail) if detail else ""])
	else:
		_failures += 1
		print("  FAIL  %s%s" % [label, (" :: " + detail) if detail else ""])


# --- Case A ------------------------------------------------------------------

func _case_a_event_bus() -> void:
	print("[Case A] EventBus signal emission/reception")
	var bus: Node = root.get_node_or_null("EventBus")
	if bus == null:
		# Autoload absent (bare --script run): test a fresh instance instead.
		bus = EventBusScript.new()
		root.add_child(bus)

	var seen := {}
	bus.gesture_recognized.connect(func(n: String, s: float): seen["gesture"] = [n, s])
	bus.gesture_failed.connect(func(): seen["failed"] = true)
	bus.letter_trigger_activated.connect(func(id: String): seen["letter"] = id)
	bus.player_state_changed.connect(func(s: String): seen["state"] = s)

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


# --- Case B ------------------------------------------------------------------

func _case_b_horizontal_line() -> void:
	print("[Case B] rough horizontal line -> line_horizontal, score >= 0.75")
	var recognizer = Recognizer.new()
	var stroke: Array[Vector2] = []
	for i in 25:
		var x := float(i) * 12.0
		# Hand-drawn jitter: +-3 px vertical noise.
		var y := sin(float(i) * 1.7) * 3.0
		stroke.append(Vector2(x, y))

	var result: Dictionary = recognizer.recognize(stroke)
	print("  -> result = %s" % [result])
	_check("recognized == line_horizontal", result["name"] == "line_horizontal", str(result["name"]))
	_check("score >= 0.75", result["score"] >= 0.75, "score=%.4f" % result["score"])

	# Also confirm the pipeline contract: exactly 64 points on a 250-square, centred.
	var normalized: Array[Vector2] = recognizer.normalize(stroke)
	_check("resample yields 64 points", normalized.size() == Recognizer.POINT_COUNT, "n=%d" % normalized.size())
	var box := Rect2(normalized[0], Vector2.ZERO)
	for p in normalized:
		box = box.expand(p)
	_check("scaled to 250 bounding box", is_equal_approx(maxf(box.size.x, box.size.y), 250.0),
		"longest=%.4f" % maxf(box.size.x, box.size.y))
	_check("centroid at origin", recognizer.centroid(normalized).length() < 0.001,
		"|centroid|=%.6f" % recognizer.centroid(normalized).length())


# --- Case C ------------------------------------------------------------------

func _case_c_invalid_stroke() -> void:
	print("[Case C] invalid / noisy strokes -> graceful failure")
	var recognizer = Recognizer.new()

	var empty: Array[Vector2] = []
	var empty_result: Dictionary = recognizer.recognize(empty)
	_check("empty stroke -> no name, score 0",
		empty_result["name"] == "" and empty_result["score"] == 0.0, str(empty_result))

	var two_point: Array[Vector2] = [Vector2.ZERO, Vector2(10.0, 0.0)]
	var two_result: Dictionary = recognizer.recognize(two_point)
	_check("2-point stroke rejected (below MIN_POINTS)",
		two_result["name"] == "" and two_result["score"] == 0.0, str(two_result))

	# Degenerate: all points identical -> zero path length.
	var duplicate: Array[Vector2] = []
	for i in 10:
		duplicate.append(Vector2(50.0, 50.0))
	var dup_result: Dictionary = recognizer.recognize(duplicate)
	_check("zero-length stroke rejected (no NaN)",
		dup_result["name"] == "" and not is_nan(dup_result["score"]), str(dup_result))

	# Degenerate template registration must not corrupt the template set.
	recognizer.add_template("bogus", [Vector2.ZERO, Vector2.ZERO])
	var after: Dictionary = recognizer.recognize([Vector2(0, 0), Vector2(5, 0), Vector2(9, 1), Vector2(14, 0)])
	_check("degenerate template rejected, recognizer still functional",
		after["name"] != "bogus" and after["score"] >= 0.0, str(after))