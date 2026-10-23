extends "res://scripts/shell/campaign_progress.gd"
## Water-sort-only adapter for the existing menu API. It never reads cargo saves.
## A best record is ONE run: fewest moves, then shortest time on a tie.
const WATER_FILE := "water_sort_progress_v1.json"
const WATER_CAMPAIGN := "water_sort_v1"
const WaterRules = preload("res://scripts/experiments/water_sort_v1/rules.gd")
var reader: Callable
var writer: Callable
var campaign := WATER_CAMPAIGN
var attempt_prefix := "water_sort:"
var strict_content := false
var board_digests: Array[String] = []
var bound_levels: Array = []
var pack_digest := ""
var compatible_prefix_bindings: Array = []
var accepted_pack_counts: Dictionary = {}

func _init(test_reader: Callable = Callable(), test_writer: Callable = Callable(), configuration: Dictionary = {}) -> void:
	storage_file = str(configuration.get("storage_file",WATER_FILE))
	campaign = str(configuration.get("campaign",WATER_CAMPAIGN))
	attempt_prefix = str(configuration.get("attempt_prefix","water_sort:"))
	strict_content = bool(configuration.get("strict_content",false))
	compatible_prefix_bindings = configuration.get("compatible_prefixes",[]).duplicate(true)
	level_count = 5
	reader = test_reader
	writer = test_writer
	data = {"schema":2,"campaign":campaign,"completed":[],"records":{},"settlements":{},"serial":0,"pending_attempt":{},"locale":"zh","music":true,"sound":true}

func bind_level_pack(levels: Array) -> void:
	super.bind_level_pack(levels)
	bound_levels = levels.duplicate(true)
	board_digests.clear()
	var ordered: Array = []
	for level in levels:
		var board := WaterRules.create(level)
		var digest := JSON.stringify([str(level.id),board.capacity,board.bottles]).sha256_text()
		board_digests.append(digest)
		ordered.append(digest)
	pack_digest = JSON.stringify(ordered).sha256_text()
	accepted_pack_counts = {pack_digest:level_count}
	for binding in compatible_prefix_bindings:
		if not binding is Dictionary or binding.get("campaign","")!=campaign or not _whole(binding.get("level_count"),1): continue
		var count: int=int(binding.level_count)
		if count>=level_count or not binding.get("board_digests") is Array or not binding.get("level_ids") is Array: continue
		if binding.board_digests.size()!=count or binding.level_ids.size()!=count: continue
		if JSON.stringify(binding.board_digests).sha256_text()!=binding.get("pack_digest",""): continue
		var identical := true
		for index in range(count):
			if board_digests[index]!=binding.board_digests[index] or level_ids[index]!=binding.level_ids[index]: identical=false; break
		if identical: accepted_pack_counts[str(binding.pack_digest)]=count
	# Initialize only brand-new memory. Rebinding an accepted settings-only
	# legacy save must not eagerly mutate its metadata before a successful save.
	if strict_content and not data.has("pack_digest"): data.pack_digest = pack_digest

func _valid_attempt_id(value: Variant) -> bool:
	if not value is String or not value.begins_with(attempt_prefix): return false
	var suffix: String = value.trim_prefix(attempt_prefix)
	return suffix.is_valid_int() and int(suffix)>0 and suffix==str(int(suffix))

func _attempt_within_serial(value: String, serial: int) -> bool:
	return _valid_attempt_id(value) and int(value.trim_prefix(attempt_prefix))<=serial

func _inventory(bottles: Array) -> Dictionary:
	var result: Dictionary = {}
	for bottle in bottles:
		for color in bottle: result[color] = int(result.get(color,0))+1
	return result

func checkpoint_matches_level(index: int, snapshot: Dictionary) -> bool:
	if not WaterRules.validation_errors(snapshot).is_empty(): return false
	if not strict_content: return true
	if index<0 or index>=bound_levels.size(): return false
	var original := WaterRules.create(bound_levels[index])
	return snapshot.capacity==original.capacity and snapshot.bottles.size()==original.bottles.size() and _inventory(snapshot.bottles)==_inventory(original.bottles)

func load_progress() -> void:
	var saved: Dictionary = reader.call() if reader.is_valid() else Store.read(storage_file)
	if saved.get("ok",false) and _valid_water(saved.get("data",{})):
		data = saved.data.duplicate(true)
	elif saved.get("ok",false) or saved.get("reason","") != "missing":
		load_error = "invalid_water_sort_progress"
		persistent = false # Preserve an unreadable save, never replace it silently.

func save_progress() -> bool:
	if not persistent: return false
	# Append-only metadata upgrade is committed with the next real save, never
	# as a destructive reset or a separate write while merely loading a save.
	var candidate: Dictionary=data.duplicate(true)
	if strict_content:
		candidate.pack_digest=pack_digest
		candidate.pack_level_count=level_count
		if not _valid_water(candidate):
			load_error="invalid_water_sort_progress"
			return false
	var okay: bool = bool(writer.call(candidate.duplicate(true))) if writer.is_valid() else Store.write(storage_file,candidate)
	if okay: data=candidate
	load_error = "" if okay else "progress_save_failed"
	return okay

func _saved_pack_level_count(value: Dictionary) -> int:
	var count: int=int(accepted_pack_counts.get(value.get("pack_digest",""),0))
	if count<=0: return 0
	if value.has("pack_level_count") and (not _whole(value.pack_level_count,1) or int(value.pack_level_count)!=count): return 0
	return count

func _whole(value: Variant, minimum: int = 0) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) == floorf(float(value)) and value >= minimum

func _valid_water(value: Variant) -> bool:
	if not value is Dictionary or value.get("schema") != 2 or value.get("campaign") != campaign: return false
	if not value.get("completed") is Array or not value.get("records") is Dictionary or not value.get("settlements") is Dictionary or not value.get("pending_attempt") is Dictionary: return false
	var saved_level_count: int=_saved_pack_level_count(value) if strict_content else level_count
	if saved_level_count<=0: return false
	if not _whole(value.get("serial")) or value.get("locale") not in ["zh","en"] or not value.get("music") is bool or not value.get("sound") is bool: return false
	for number in value.completed:
		if not _whole(number,1) or number > saved_level_count: return false
		if number > 1 and not value.completed.has(number-1): return false
	for id in value.records:
		if not id is String or (not level_ids.is_empty() and not level_ids.has(id)): return false
		if strict_content and level_ids.find(id)>=saved_level_count: return false
		var record: Variant = value.records[id]
		if not record is Dictionary or not _whole(record.get("moves"),1) or not _valid_time(record.get("seconds")) or not record.get("attempt_id") is String: return false
		if strict_content and (not _attempt_within_serial(record.attempt_id,int(value.serial)) or record.get("board_digest","")!=board_digests[level_ids.find(id)]): return false
	for id in value.settlements:
		if not id is String or id.is_empty() or value.settlements[id] != true: return false
		if strict_content and not _attempt_within_serial(id,int(value.serial)): return false
	var pending: Dictionary = value.pending_attempt
	if not pending.is_empty():
		if not pending.get("id") is String or pending.id.is_empty() or not _whole(pending.get("index")) or pending.index >= saved_level_count: return false
		if strict_content and (not _attempt_within_serial(pending.id,int(value.serial)) or pending.get("board_digest","")!=board_digests[int(pending.index)]): return false
		if pending.has("snapshot"):
			if not pending.snapshot is Dictionary or not checkpoint_matches_level(int(pending.index),pending.snapshot): return false
			if not _whole(pending.get("moves")) or not _valid_time(pending.get("seconds")): return false
	return true

func _valid_time(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and value >= 0

func level_key(index: int) -> String:
	return str(level_ids[index]) if index >= 0 and index < level_ids.size() else "water_sort_%02d" % (index+1)

func reserve_attempt(index: int) -> String:
	if not unlocked(index): return ""
	var before: Dictionary = data.duplicate(true)
	data.serial = int(data.serial)+1
	var id := attempt_prefix+str(data.serial)
	data.pending_attempt = {"id":id,"index":index}
	if strict_content:
		data.pending_attempt.board_digest = board_digests[index]
		data.pack_digest = pack_digest
	if save_progress(): return id
	data = before
	return ""

func save_checkpoint(attempt_id: String, snapshot: Dictionary, moves: int, seconds: float) -> bool:
	if data.pending_attempt.get("id","") != attempt_id or not checkpoint_matches_level(int(data.pending_attempt.get("index",-1)),snapshot) or moves < 0 or not _valid_time(seconds): return false
	var before: Dictionary = data.duplicate(true)
	data.pending_attempt.snapshot = snapshot.duplicate(true)
	data.pending_attempt.moves = moves
	data.pending_attempt.seconds = seconds
	if save_progress(): return true
	data = before
	return false

func record_result(index: int, moves: int, seconds: float, attempt_id: String) -> bool:
	if data.settlements.has(attempt_id): return true
	if not unlocked(index) or moves <= 0 or not _valid_time(seconds) or data.pending_attempt.get("id","") != attempt_id or int(data.pending_attempt.get("index",-1)) != index: return false
	var before: Dictionary = data.duplicate(true)
	if not completed(index): data.completed.append(index+1)
	var key := level_key(index)
	var old: Dictionary = data.records.get(key,{})
	if old.is_empty() or moves < int(old.moves) or (moves == int(old.moves) and seconds < float(old.seconds)):
		data.records[key] = {"moves":moves,"seconds":seconds,"attempt_id":attempt_id}
		if strict_content: data.records[key].board_digest = board_digests[index]
	data.settlements[attempt_id] = true
	data.pending_attempt = {}
	if save_progress(): return true
	data = before
	return false

func best_record(index: int) -> Dictionary:
	return data.records.get(level_key(index),{}).duplicate(true)
