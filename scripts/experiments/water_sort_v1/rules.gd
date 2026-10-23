extends RefCounted
## Water-sort rules. No persistence, animation, ads or production imports.
## Each bottle is an Array[String] in bottom-to-top order.
const CAPACITY := 4
var capacity: int = CAPACITY
var bottles: Array = []

func _init(level: Dictionary = {}) -> void:
	if not level.is_empty():
		restore(create(level))

func can_pour(from: int, to: int) -> bool:
	return _pour_amount(snapshot(), from, to) > 0

## Atomic operation: returns the moved layer count, or 0 without mutation.
func pour(from: int, to: int) -> int:
	var result: Dictionary = apply_move(snapshot(), from, to)
	if not result.ok:
		return 0
	restore(result.state)
	return int(result.count)

func is_solved() -> bool:
	return is_won(snapshot())

func snapshot() -> Dictionary:
	return {"capacity": capacity, "bottles": bottles.duplicate(true)}

func restore(saved: Dictionary) -> bool:
	if not validation_errors(saved).is_empty():
		return false
	capacity = CAPACITY
	bottles = saved.bottles.duplicate(true)
	return true

## Returns an independent valid state, or {} for malformed/impossible inventory.
static func create(level: Dictionary) -> Dictionary:
	var result := {"capacity": level.get("capacity", CAPACITY), "bottles": level.get("bottles", []).duplicate(true) if level.get("bottles", []) is Array else []}
	if not validation_errors(result).is_empty():
		return {}
	result.capacity = CAPACITY
	return result

static func validation_errors(state: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	if state.get("capacity", -1) != CAPACITY:
		errors.append("capacity_must_be_4")
	var all_bottles = state.get("bottles", null)
	if not all_bottles is Array or all_bottles.is_empty():
		errors.append("bottles_must_be_nonempty_array")
		return errors
	var counts: Dictionary = {}
	for bottle in all_bottles:
		if not bottle is Array or bottle.size() > CAPACITY:
			errors.append("invalid_bottle")
			continue
		for color in bottle:
			if not color is String or color.is_empty():
				errors.append("invalid_color")
				continue
			counts[color] = int(counts.get(color, 0)) + 1
	if counts.is_empty():
		errors.append("empty_puzzle")
	for color in counts:
		if counts[color] != CAPACITY:
			errors.append("color_inventory_must_equal_4:" + str(color))
	return errors

static func _pour_amount(state: Dictionary, from: int, to: int) -> int:
	var items: Array = state.get("bottles", [])
	if from == to or from < 0 or to < 0 or from >= items.size() or to >= items.size():
		return 0
	var source: Array = items[from]
	var target: Array = items[to]
	if source.is_empty() or target.size() >= CAPACITY:
		return 0
	var color = source.back()
	if not target.is_empty() and target.back() != color:
		return 0
	var run := 0
	for index in range(source.size() - 1, -1, -1):
		if source[index] != color:
			break
		run += 1
	return mini(run, CAPACITY - target.size())

static func available_moves(state: Dictionary) -> Array[Dictionary]:
	var moves: Array[Dictionary] = []
	if not validation_errors(state).is_empty():
		return moves
	for from in range(state.bottles.size()):
		for to in range(state.bottles.size()):
			var count := _pour_amount(state, from, to)
			if count > 0:
				moves.append({"from": from, "to": to, "count": count})
	return moves

## Pure function: the supplied state is never changed, including illegal actions.
static func apply_move(state: Dictionary, from: int, to: int) -> Dictionary:
	var copy := state.duplicate(true)
	if not validation_errors(state).is_empty():
		return {"ok": false, "count": 0, "state": copy, "reason": "invalid_state"}
	var count := _pour_amount(state, from, to)
	if count == 0:
		return {"ok": false, "count": 0, "state": copy, "reason": "illegal_pour"}
	for unused in range(count):
		copy.bottles[to].append(copy.bottles[from].pop_back())
	return {"ok": true, "count": count, "state": copy, "reason": ""}

static func is_won(state: Dictionary) -> bool:
	if not validation_errors(state).is_empty():
		return false
	for bottle in state.bottles:
		if bottle.is_empty():
			continue
		if bottle.size() != CAPACITY:
			return false
		for color in bottle:
			if color != bottle[0]:
				return false
	return true
