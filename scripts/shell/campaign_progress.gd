extends RefCounted
# Separate additive record. Never rewrites the existing replay/session files.
const Store = preload("res://scripts/services/local_store.gd")
const FILE = "campaign_progress_lane100_v1.json"
var storage_file := FILE
var level_count := 100
var level_ids: Array = []
var data := {"schema": 2, "campaign": "lane_campaign100", "completed": [], "locale": "zh", "music": true, "sound": true}
var persistent := true
var load_error := ""

func load_progress() -> void:
	var saved: Dictionary = Store.read(storage_file)
	if saved.ok and saved.data.get("campaign") == "lane_campaign100" and _valid(saved.data):
		data.merge(saved.data.duplicate(true), true)
		var validated: Array = []
		for level in data.completed:
			if (level is float or level is int) and level == int(level) and int(level) >= 1 and int(level) <= level_count and not validated.has(int(level)):
				validated.append(int(level))
		data.completed = validated
		if data.has("completed_level_ids") and not level_ids.is_empty():
			data.completed = []
			for id in data.completed_level_ids:
				data.completed.append(level_ids.find(id)+1)
		if data.has("pending_attempt") and data.pending_attempt.has("level_id") and not level_ids.is_empty():
			data.pending_attempt.index = level_ids.find(data.pending_attempt.level_id)
	elif saved.ok or saved.reason != "missing":
		load_error = str(saved.get("reason", "incompatible_campaign"))
		persistent = false # Preserve damaged/incompatible data for recovery.

func save_progress() -> bool:
	if not persistent: return false
	var candidate: Dictionary = data.duplicate(true)
	if not level_ids.is_empty():
		candidate.completed_level_ids = []
		for number in candidate.completed:
			candidate.completed_level_ids.append(level_ids[int(number)-1])
		candidate.progress_version = 2
	if not Store.write(storage_file,candidate): return false
	data = candidate
	return true

func bind_level_pack(levels: Array) -> void:
	level_count = levels.size()
	level_ids.clear()
	for level in levels: level_ids.append(str(level.id))

func completed(index: int) -> bool:
	return data.completed.has(index + 1)

func unlocked(index: int) -> bool:
	return index >= 0 and index < level_count and (index == 0 or completed(index - 1))

func current_index() -> int:
	for index in range(level_count):
		if not completed(index):
			return index
	return level_count - 1

func record_verified_win(index: int, status: String) -> bool:
	if status != "won" or not unlocked(index):
		return false
	if not completed(index):
		data.completed.append(index + 1)
		if not save_progress():
			data.completed.erase(index + 1)
			load_error = "progress_save_failed"
			return false
	return true

func set_preference(key: String, value: Variant) -> void:
	if key == "locale" and value in ["zh", "en"] or key in ["music", "sound"] and value is bool:
		var previous: Variant = data.get(key)
		data[key] = value
		if not save_progress():
			data[key] = previous
			load_error = "preference_save_failed"

func set_tutorial_seen(seen: Dictionary) -> bool:
	if not _valid_tutorial(seen): return false
	var previous: Dictionary = data.get("tutorial_seen",{}).duplicate(true)
	data.tutorial_seen = seen.duplicate(true)
	if save_progress(): return true
	data.tutorial_seen = previous
	return false

func _valid_tutorial(seen: Variant) -> bool:
	if not seen is Dictionary: return false
	for key in seen:
		if key not in ["match_ready","read_current_and_next","unmatched_waits","release_waiting"] or not seen[key] is bool or not seen[key]: return false
	return true

func _valid(value: Dictionary) -> bool:
	if value.has("tutorial_seen") and not _valid_tutorial(value.tutorial_seen): return false
	if value.has("progress_version") and value.progress_version != 1 and value.progress_version != 2: return false
	if not value.get("completed") is Array: return false
	if value.has("locale") and value.locale not in ["zh","en"]: return false
	for key in ["music","sound"]:
		if value.has(key) and not value[key] is bool: return false
	for level in value.completed:
		if not (level is int or level is float) or not is_finite(float(level)) or float(level) != floorf(float(level)) or level < 1 or level > level_count: return false
	if value.has("completed_level_ids"):
		if not value.completed_level_ids is Array: return false
		for id in value.completed_level_ids:
			if not id is String or (not level_ids.is_empty() and not level_ids.has(id)): return false
	if value.has("pending_attempt"):
		var pending: Variant = value.pending_attempt
		if not pending is Dictionary or not pending.get("id") is String or pending.id.is_empty(): return false
		if pending.has("level_id") and (not pending.level_id is String or (not level_ids.is_empty() and not level_ids.has(pending.level_id))): return false
		var index: Variant = pending.get("index")
		if not (index is int or index is float) or not is_finite(float(index)) or float(index) != floorf(float(index)) or index < 0 or index >= level_count: return false
	return true
