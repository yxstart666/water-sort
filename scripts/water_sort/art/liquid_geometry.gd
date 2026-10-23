extends RefCounted
## Area-preserving 2D liquid approximation. All points are bottle-local.
## The physical volume model is exact for this cross-section, not a fluid simulation.
const INNER := [Vector2(-34, 0), Vector2(34, 0), Vector2(34, 43),
	Vector2(37, 51), Vector2(46, 59), Vector2(55, 68), Vector2(61, 81),
	Vector2(63, 96), Vector2(63, 348), Vector2(61, 359), Vector2(55, 366),
	Vector2(44, 370), Vector2(26, 373), Vector2(0, 374), Vector2(-26, 373), Vector2(-44, 370), Vector2(-55, 366), Vector2(-61, 359),
	Vector2(-63, 348), Vector2(-63, 96), Vector2(-61, 81), Vector2(-55, 68),
	Vector2(-46, 59), Vector2(-37, 51), Vector2(-34, 43)]
# A seated stopper ends at y=20; four units stop at y=24, leaving 4 local
# pixels of physical headroom instead of the old empty shoulder/neck.
const FILL_LINE := 24.0

static func cavity() -> PackedVector2Array:
	return PackedVector2Array(INNER)

static func area(poly: PackedVector2Array) -> float:
	if poly.size() < 3: return 0.0
	var value := 0.0
	for i in poly.size(): value += poly[i].cross(poly[(i + 1) % poly.size()])
	return absf(value) * 0.5

static func clip(poly: PackedVector2Array, normal: Vector2, level: float, below := true) -> PackedVector2Array:
	var result := PackedVector2Array()
	if poly.is_empty(): return result
	var previous := poly[-1]
	var previous_distance := previous.dot(normal) - level
	if not below: previous_distance = -previous_distance
	for current in poly:
		var distance := current.dot(normal) - level
		if not below: distance = -distance
		if (distance >= 0.0) != (previous_distance >= 0.0):
			var portion := previous_distance / (previous_distance - distance)
			result.append(previous.lerp(current, portion))
		if distance >= 0.0: result.append(current)
		previous = current
		previous_distance = distance
	return clean(result)

static func clean(poly: PackedVector2Array) -> PackedVector2Array:
	var result := PackedVector2Array()
	for point in poly:
		if result.is_empty() or result[-1].distance_squared_to(point)>0.000001:
			result.append(point)
	if result.size()>2 and result[0].distance_squared_to(result[-1])<0.000001:
		result.resize(result.size()-1)
	return result

static func full_area() -> float:
	return area(clip(cavity(), Vector2.DOWN, FILL_LINE))

static func gravity_normal(angle: float) -> Vector2:
	return Vector2(sin(angle), cos(angle))

static func threshold(units: float, capacity: float, angle: float) -> float:
	var poly := cavity()
	var normal := gravity_normal(angle)
	var low := INF
	var high := -INF
	for point in poly:
		low = minf(low, point.dot(normal))
		high = maxf(high, point.dot(normal))
	var desired := clampf(units / capacity, 0.0, 1.0) * full_area()
	if desired <= 0.000001: return high + 0.01
	for unused in 34:
		var middle := (low + high) * 0.5
		if area(clip(poly, normal, middle)) > desired: low = middle
		else: high = middle
	return (low + high) * 0.5

static func filled(units: float, capacity: float, angle: float) -> PackedVector2Array:
	return clip(cavity(), gravity_normal(angle), threshold(units, capacity, angle))

static func band(bottom_units: float, top_units: float, capacity: float, angle: float) -> PackedVector2Array:
	var poly := filled(top_units, capacity, angle)
	if bottom_units > 0.000001:
		poly = clip(poly, gravity_normal(angle), threshold(bottom_units, capacity, angle), false)
	return poly

static func surface(units: float, capacity: float, angle: float) -> PackedVector2Array:
	if units <= 0.00001: return PackedVector2Array()
	var n := gravity_normal(angle)
	var h := threshold(units, capacity, angle)
	var points := PackedVector2Array()
	var poly := cavity()
	for i in poly.size():
		var a := poly[i]
		var b := poly[(i + 1) % poly.size()]
		var da := a.dot(n) - h
		var db := b.dot(n) - h
		if (da >= 0.0) != (db >= 0.0): points.append(a.lerp(b, da / (da - db)))
	return points

## The spill angle places the horizontal free surface at the lower mouth edge.
## This increases while a contiguous top layer drains, so liquid exits the opening.
static func spill_angle(units: float, capacity: float) -> float:
	var desired := clampf(units / capacity, 0.0, 1.0) * full_area()
	var low := 0.0
	var high := deg_to_rad(174.0)
	for unused in 32:
		var middle := (low + high) * 0.5
		var normal := gravity_normal(middle)
		var held := area(clip(cavity(), normal, Vector2(34, 0).dot(normal)))
		if held > desired: low = middle
		else: high = middle
	return (low + high) * 0.5
