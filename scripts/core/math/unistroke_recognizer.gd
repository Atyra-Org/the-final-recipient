class_name UnistrokeRecognizer
extends RefCounted


const POINT_COUNT := 64
const SQUARE_SIZE := 250.0
const HALF_DIAGONAL := 0.5 * sqrt(SQUARE_SIZE * SQUARE_SIZE * 2.0)
const ANGLE_RANGE := PI / 4.0
const GOLDEN_RATIO := 0.5 * (sqrt(5.0) - 1.0)
const SEARCH_ITERATIONS := 20
const MIN_POINTS := 3

var _templates: Array[Dictionary] = []


func _init() -> void:
	add_template("line_horizontal", _line_template())
	add_template("circle", _circle_template())
	add_template("triangle", _triangle_template())
	add_template("v", [Vector2.ZERO, Vector2(60.0, 100.0), Vector2(120.0, 0.0)])
	add_template("caret", [Vector2(0.0, 100.0), Vector2(60.0, 0.0), Vector2(120.0, 100.0)])
	add_template("zigzag", [Vector2.ZERO, Vector2(40.0, 80.0), Vector2(80.0, 0.0), Vector2(120.0, 80.0), Vector2(160.0, 0.0)])
	add_template("star", _star_template(0))
	add_template("star", _star_template(1))
	add_template("star", _star_template(2))
	add_template("star", _star_template(3))
	add_template("star", _star_template(4))


func add_template(template_name: String, points: Array[Vector2]) -> void:
	var normalized := normalize(points)
	if normalized.is_empty():
		push_warning("UnistrokeRecognizer: skipped degenerate template '%s'" % template_name)
		return
	_templates.append({"name": template_name, "points": normalized, "star_variant": template_name == "star" and points[0] == points[-1]})


func recognize(points: Array[Vector2]) -> Dictionary:
	var candidate := normalize(points)
	if candidate.is_empty():
		return {"name": "", "score": 0.0}


	var reversed := normalize(_reversed(points))
	var closed_points: Array[Vector2] = points.duplicate()
	var gap: float = points[0].distance_to(points[-1])
	var open_star: bool = gap > 0.0 and gap <= path_length(points) * 0.12
	if open_star:
		closed_points.append(points[0])
	var closed_candidate: Array[Vector2] = normalize(closed_points) if open_star else candidate
	var reversed_closed_points: Array[Vector2] = _reversed(closed_points)
	var reversed_closed: Array[Vector2] = normalize(reversed_closed_points) if open_star else reversed

	var points_down: bool = centroid(resample(points)).y > (points[0].y + points[-1].y) * 0.5
	var best_name := ""
	var best_score := 0.0
	for template in _templates:
		if template["name"] == "star" and not template["star_variant"]:
			continue
		if (template["name"] == "v" and not points_down) or (template["name"] == "caret" and points_down):
			continue
		var score := _score_at_best_angle(candidate, template["points"])
		if not reversed.is_empty():
			score = maxf(score, _score_at_best_angle(reversed, template["points"]))
		if template["name"] == "star" and open_star:
			score = maxf(score, _score_at_best_angle(closed_candidate, template["points"]))
			score = maxf(score, _score_at_best_angle(reversed_closed, template["points"]))
		if score > best_score:
			best_score = score
			best_name = template["name"]
	return {"name": best_name, "score": best_score}


func normalize(points: Array[Vector2]) -> Array[Vector2]:
	if points.size() < MIN_POINTS or path_length(points) <= 0.0:
		return []
	var out := resample(points)
	out = rotate_by(out, -indicative_angle(out))
	out = scale_to_square(out)
	return translate_to_origin(out)


func resample(points: Array[Vector2]) -> Array[Vector2]:
	if points.size() < 2:
		return []
	var work: Array[Vector2] = points.duplicate()
	var interval := path_length(work) / float(POINT_COUNT - 1)
	if interval <= 0.0:
		return []

	var result: Array[Vector2] = [work[0]]
	var accumulated := 0.0
	var i := 1
	while i < work.size() and result.size() < POINT_COUNT:
		var d := work[i].distance_to(work[i - 1])
		if d <= 0.0:
			i += 1
			continue
		if accumulated + d >= interval:
			var t := (interval - accumulated) / d
			var q := work[i - 1].lerp(work[i], t)
			result.append(q)
			work.insert(i, q)
			accumulated = 0.0
		else:
			accumulated += d
		i += 1

	while result.size() < POINT_COUNT:
		result.append(work[work.size() - 1])
	return result


func rotate_by(points: Array[Vector2], theta: float) -> Array[Vector2]:
	var c := centroid(points)
	var cos_t := cos(theta)
	var sin_t := sin(theta)
	var out: Array[Vector2] = []
	for p in points:
		var dx := p.x - c.x
		var dy := p.y - c.y
		out.append(Vector2(dx * cos_t - dy * sin_t, dx * sin_t + dy * cos_t) + c)
	return out


func scale_to_square(points: Array[Vector2], size: float = SQUARE_SIZE) -> Array[Vector2]:
	var box := _bounding_box(points)
	var longest := maxf(box.size.x, box.size.y)
	if longest <= 0.0:
		return points
	var factor := size / longest
	var out: Array[Vector2] = []
	for p in points:
		out.append(p * factor)
	return out


func translate_to_origin(points: Array[Vector2]) -> Array[Vector2]:
	var c := centroid(points)
	var out: Array[Vector2] = []
	for p in points:
		out.append(p - c)
	return out


func centroid(points: Array[Vector2]) -> Vector2:
	var sum := Vector2.ZERO
	for p in points:
		sum += p
	return sum / float(points.size()) if points.size() > 0 else Vector2.ZERO


func indicative_angle(points: Array[Vector2]) -> float:
	if points.is_empty():
		return 0.0
	var c := centroid(points)
	return atan2(c.y - points[0].y, c.x - points[0].x)


func path_length(points: Array[Vector2]) -> float:
	var d := 0.0
	for i in range(1, points.size()):
		d += points[i].distance_to(points[i - 1])
	return d


func path_distance(a: Array[Vector2], b: Array[Vector2]) -> float:
	var n := mini(a.size(), b.size())
	if n == 0:
		return INF
	var d := 0.0
	for i in n:
		d += a[i].distance_to(b[i])
	return d / float(n)


func _reversed(points: Array[Vector2]) -> Array[Vector2]:
	var out: Array[Vector2] = []
	for i in range(points.size() - 1, -1, -1):
		out.append(points[i])
	return out


func _score_at_best_angle(candidate: Array[Vector2], template: Array[Vector2]) -> float:
	var a := -ANGLE_RANGE
	var b := ANGLE_RANGE
	var x1 := b - GOLDEN_RATIO * (b - a)
	var x2 := a + GOLDEN_RATIO * (b - a)
	var f1 := path_distance(rotate_by(candidate, x1), template)
	var f2 := path_distance(rotate_by(candidate, x2), template)

	for _i in SEARCH_ITERATIONS:
		if f1 < f2:
			b = x2
			x2 = x1
			f2 = f1
			x1 = b - GOLDEN_RATIO * (b - a)
			f1 = path_distance(rotate_by(candidate, x1), template)
		else:
			a = x1
			x1 = x2
			f1 = f2
			x2 = a + GOLDEN_RATIO * (b - a)
			f2 = path_distance(rotate_by(candidate, x2), template)

	return clampf(1.0 - minf(f1, f2) / HALF_DIAGONAL, 0.0, 1.0)


func _bounding_box(points: Array[Vector2]) -> Rect2:
	var box := Rect2(points[0], Vector2.ZERO)
	for p in points:
		box = box.expand(p)
	return box


func _line_template() -> Array[Vector2]:
	var out: Array[Vector2] = [Vector2.ZERO, Vector2(SQUARE_SIZE * 0.5, 0.0), Vector2(SQUARE_SIZE, 0.0)]
	return out


func _circle_template() -> Array[Vector2]:
	var out: Array[Vector2] = []
	var radius := 80.0
	for i in 32:
		var t := TAU * float(i) / 32.0
		out.append(Vector2(cos(t), sin(t)) * radius)
	out.append(out[0])
	return out


func _triangle_template() -> Array[Vector2]:
	var out: Array[Vector2] = [
		Vector2.ZERO, Vector2(120.0, 0.0), Vector2(60.0, -104.0), Vector2.ZERO
	]
	return out


func _star_template(start_corner: int) -> Array[Vector2]:
	var vertices: Array[Vector2] = [
		Vector2(60.0, 0.0),
		Vector2(95.0, 110.0),
		Vector2(0.0, 42.0),
		Vector2(120.0, 42.0),
		Vector2(25.0, 110.0),
	]
	var out: Array[Vector2] = []
	for i: int in 6:
		var index: int = (start_corner + i) % 5
		out.append(vertices[index])
	return out
