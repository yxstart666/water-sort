extends RefCounted
## Order transactions retain collected inventory for validation and undo, while
## delivered bottle indices leave the playable board. No animation or I/O here.
const Classic = preload("res://scripts/experiments/water_sort_v1/rules.gd")
const Visual = preload("res://scripts/water_sort/art/bottle_visual.gd")
var capacity := 4
var bottles: Array = []
var level: Dictionary = {}
var delivered: Array = []
var bonus_unlocked := false
var slot_unlocked := false
var last_events: Array = []
var unknown: Array = [] # Per-unit visibility, bottom to top; hidden units never transfer.
var definition_errors:Array=[]

func _init(source: Dictionary = {}) -> void:
	level = source.duplicate(true)
	definition_errors=unknown_definition_errors(source)
	bottles = source.get("bottles", []).duplicate(true)
	if has_bonus(): bottles.append([])
	unknown=initial_unknown(source,bottles)

static func initial_unknown(source: Dictionary, contents: Array) -> Array:
	var result: Array=[]
	for bottle in contents:
		var flags: Array=[]; flags.resize(bottle.size()); flags.fill(false); result.append(flags)
	if not unknown_definition_errors(source).is_empty():
		# Invalid development content must not silently expose hidden pigments.
		for flags in result: flags.fill(true)
		return result
	for entry in source.get("unknown_layers",[]):
		var index:=int(entry.bottle)
		for layer in entry.layers: result[index][int(layer)]=true
	return result

static func _layer_integer(value:Variant)->bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value)==floorf(float(value))

static func unknown_definition_errors(source:Dictionary)->Array:
	var errors:Array=[];var seen:Array=[]
	if not source.get("unknown_layers",[]) is Array:return ["unknown_layers must be an array"]
	for entry in source.get("unknown_layers",[]):
		if not entry is Dictionary or not _layer_integer(entry.get("bottle")) or not entry.get("layers") is Array:
			errors.append("invalid unknown entry");continue
		var index:int=entry.bottle
		if index<0 or index>=source.get("bottles",[]).size() or seen.has(index):
			errors.append("invalid or duplicate unknown bottle");continue
		seen.append(index);var layers:Array=entry.layers
		if layers.is_empty() or layers.size()>=source.bottles[index].size():errors.append("unknown bottle needs a visible top layer")
		for i in layers.size():
			if not _layer_integer(layers[i]) or int(layers[i])<0 or int(layers[i])>=source.bottles[index].size()-1 or layers.slice(0,i).has(layers[i]):
				errors.append("invalid unknown layer")
			elif not source.get("legacy_unknown_layout",false) and int(layers[i])!=i:
				errors.append("unknown layers must be a contiguous bottom prefix")
	return errors

func complete(index: int) -> bool:
	return not unknown[index].has(true) and Visual.complete_layers(bottles[index])

func pour_amount(from: int, to: int) -> int:
	var amount:=Classic._pour_amount(snapshot(),from,to)
	if amount<=0: return 0
	var visible:=0
	for i in range(bottles[from].size()-1,-1,-1):
		if unknown[from][i]: break
		visible+=1
	return mini(amount,visible)

func has_bonus() -> bool:
	return bool(level.get("bonus_bottle", false))

func bonus_index() -> int:
	return level.bottles.size() if has_bonus() else -1

func snapshot() -> Dictionary:
	var result: Dictionary={"capacity":capacity,"bottles":bottles.duplicate(true),"order_mode":1,"delivered":delivered.duplicate(),"bonus_unlocked":bonus_unlocked,"slot_unlocked":slot_unlocked}
	if not level.get("unknown_layers",[]).is_empty(): result.unknown=unknown.duplicate(true)
	return result

static func matches(source: Dictionary, saved: Dictionary) -> bool:
	if not unknown_definition_errors(source).is_empty():return false
	if saved.get("capacity")!=4 or saved.get("order_mode")!=1 or not saved.get("bottles") is Array: return false
	for bottle in saved.bottles:
		if not bottle is Array or bottle.size()>4: return false
		for color in bottle:
			if not color is String or color.is_empty(): return false
	if not saved.get("delivered") is Array or not saved.get("bonus_unlocked") is bool or not saved.get("slot_unlocked") is bool: return false
	var bonus: bool = bool(source.get("bonus_bottle",false))
	if saved.bottles.size() != source.bottles.size() + (1 if bonus else 0): return false
	if not bonus and (saved.bonus_unlocked or saved.slot_unlocked): return false
	if bonus and not saved.bonus_unlocked and not saved.bottles[-1].is_empty(): return false
	var inventory: Dictionary = {}
	for bottle in source.bottles:
		for color in bottle: inventory[color] = int(inventory.get(color,0))+1
	for bottle in saved.bottles:
		for color in bottle: inventory[color] = int(inventory.get(color,0))-1
	for count in inventory.values():
		if count != 0: return false
	var original:=initial_unknown(source,source.bottles)
	if bonus: original.append([])
	if saved.has("unknown") and not saved.unknown is Array: return false
	var visibility: Array=saved.get("unknown",[])
	if not source.get("unknown_layers",[]).is_empty():
		if visibility.size()!=saved.bottles.size(): return false
		for i in visibility.size():
			if not visibility[i] is Array or visibility[i].size()!=saved.bottles[i].size(): return false
			var visible_seen:=false
			for j in visibility[i].size():
				if not visibility[i][j] is bool: return false
				if visibility[i][j] and (j>=original[i].size() or not original[i][j] or j==visibility[i].size()-1): return false
				if visibility[i][j] and visible_seen and not source.get("legacy_unknown_layout",false):return false
				if not visibility[i][j]:visible_seen=true
	elif not visibility.is_empty(): return false
	var seen: Array = []
	var available: Array = source.get("orders",[]).slice(0,4 if saved.slot_unlocked else 3)
	var pending: Array = source.get("orders",[]).slice(available.size())
	for index in saved.delivered:
		if not (index is int or index is float) or not is_finite(float(index)) or float(index)!=floorf(float(index)): return false
		if index < 0 or index >= saved.bottles.size() or seen.has(int(index)): return false
		var bottle: Array = saved.bottles[int(index)]
		if not Visual.complete_layers(bottle): return false
		if not visibility.is_empty() and visibility[int(index)].has(true): return false
		var slot := available.find(bottle[0])
		if slot < 0: return false
		available[slot] = pending.pop_front() if not pending.is_empty() else ""
		seen.append(int(index))
	return true

func restore(saved: Dictionary) -> bool:
	if not matches(level,saved): return false
	bottles = saved.bottles.duplicate(true)
	# These are indices, including after a real JSON disk round trip.
	delivered = saved.delivered.map(func(index): return int(index))
	bonus_unlocked = saved.bonus_unlocked
	slot_unlocked = saved.slot_unlocked
	unknown=saved.unknown.duplicate(true) if saved.has("unknown") else initial_unknown(level,bottles)
	last_events.clear()
	return true

func slots() -> Array:
	var result: Array = level.orders.slice(0,4 if slot_unlocked else 3)
	while result.size() < (4 if slot_unlocked else 3): result.append("")
	var cursor := mini(result.size(),level.orders.size())
	for index in delivered:
		var slot := result.find(bottles[int(index)][0])
		if slot >= 0:
			result[slot] = level.orders[cursor] if cursor < level.orders.size() else ""
			cursor += 1
	return result

func can_pour(from: int, to: int) -> bool:
	if not definition_errors.is_empty():return false
	if from < 0 or to < 0 or from >= bottles.size() or to >= bottles.size(): return false
	if delivered.has(from) or delivered.has(to): return false
	if bottle_lock_remaining(from)>0 or bottle_lock_remaining(to)>0: return false
	if not bonus_unlocked and (from == bonus_index() or to == bonus_index()): return false
	if complete(from): return false
	return pour_amount(from,to) > 0

func pour(from: int, to: int) -> int:
	last_events.clear()
	if not can_pour(from,to): return 0
	# Orders may request two bottles of one color. Classic validation deliberately
	# accepts only four units per color, so keep this transaction in order rules.
	var count := pour_amount(from,to)
	for unused in count:
		bottles[to].append(bottles[from].pop_back())
		unknown[from].pop_back(); unknown[to].append(false)
	# Reveal just the newly exposed unit. Never recalculate this move's amount.
	if not unknown[from].is_empty(): unknown[from][-1]=false
	settle_orders()
	return count

func settle_orders() -> void:
	# Repeated matching also collects a previously completed waiting bottle when
	# its order is revealed. The bounded loop cannot duplicate a delivery.
	for unused in level.orders.size():
		var active := slots()
		var found := false
		for index in bottles.size():
			if delivered.has(index) or not complete(index): continue
			if bottle_lock_remaining(index)>0: continue
			var color: String = bottles[index][0]
			var slot := active.find(color)
			if slot < 0: continue
			delivered.append(index)
			last_events.append({"bottle":index,"color":color,"slot":slot,"slots_before":active,"slots_after":slots(),"completed":delivered.size()})
			found = true
			break
		if not found: break

func unlock(kind: String) -> bool:
	if not has_bonus(): return false
	last_events.clear()
	if kind == "bottle" and not bonus_unlocked: bonus_unlocked = true
	elif kind == "slot" and not slot_unlocked:
		# Expanding to four slots reconstructs the queue using the same delivery
		# history, then matches any waiting full bottles.
		slot_unlocked = true
		settle_orders()
	else: return false
	return true

static func unlock_condition(entry: Dictionary) -> Dictionary:
	# Legacy orders means ANY delivered order. No implicit color assignment.
	var value: Dictionary=entry.get("condition",{})
	return {"kind":str(value.get("kind","any")),"orders":int(value.get("orders",entry.get("orders",1))),"color":str(value.get("color",""))}

func condition_progress(entry: Dictionary, presented_orders: int=-1) -> Dictionary:
	var condition:=unlock_condition(entry)
	var count:=0
	var limit:=delivered.size() if presented_orders<0 else mini(delivered.size(),presented_orders)
	for i in limit:
		var layers: Array=bottles[int(delivered[i])]
		if condition.kind=="any" or (condition.kind=="color" and not layers.is_empty() and layers[0]==condition.color): count+=1
	return {"kind":condition.kind,"color":condition.color,"required":condition.orders,"completed":mini(count,condition.orders),"remaining":maxi(0,condition.orders-count)}

func mask_progress(index: int, presented_orders: int=-1) -> Dictionary:
	for mask in level.get("masks",[]):
		if int(mask.bottle)==index: return condition_progress(mask,presented_orders)
	return {"kind":"any","color":"","required":0,"completed":0,"remaining":0}

func mask_remaining(index: int, presented_orders: int=-1) -> int:
	return int(mask_progress(index,presented_orders).remaining)

func bottle_lock_remaining(index: int, presented_orders: int = -1) -> int:
	# A covered bottle is fully locked. Both UI and pure rules derive opening
	# from the same delivery history; no independently persisted unlock flag.
	var remaining:=mask_remaining(index,presented_orders)
	for lock in level.get("bottle_locks",[]):
		if int(lock.bottle)==index: remaining=maxi(remaining,int(condition_progress(lock,presented_orders).remaining))
	return remaining

func is_solved() -> bool:
	return not level.get("orders",[]).is_empty() and delivered.size() == level.orders.size()
