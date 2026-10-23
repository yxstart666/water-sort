extends RefCounted

# Local durable energy, not a server anti-cheat system. Wall-clock rollback is
# held behind the saved high-water mark. No commercial ad SDK is installed.
const Store = preload("res://scripts/services/local_store.gd")
const FILE_NAME := "energy.json"
const CAP := 30
const COST := 5
const RECOVERY_SECONDS := 120
var clock: Callable
var reader: Callable
var writer: Callable
var state: Dictionary = {}
var error := ""

func _init(test_clock: Callable = Callable(), test_reader: Callable = Callable(), test_writer: Callable = Callable()) -> void:
	clock = test_clock
	reader = test_reader
	writer = test_writer
	_load()

func _now() -> int:
	return maxi(0, int(clock.call()) if clock.is_valid() else int(Time.get_unix_time_from_system()))

func _load() -> void:
	var loaded: Dictionary = reader.call() if reader.is_valid() else Store.read(FILE_NAME)
	if not loaded.get("ok", false):
		if loaded.get("reason", "") != "missing":
			error = "energy_store_" + str(loaded.get("reason", "unreadable"))
			return
		var now := _now()
		_commit({"schema":2,"energy_version":1,"energy":CAP,"anchor":now,"high_water":now,"attempts":{},"serial":0})
		return
	var data: Variant = loaded.get("data", {})
	if not data is Dictionary or not _valid(data):
		error = "invalid_energy_store"
		return
	state = data.duplicate(true)

func _whole(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) >= 0 and float(value) <= 9000000000000000.0 and float(value) == floorf(float(value))

func _valid(data: Dictionary) -> bool:
	if data.get("schema") != 2 or data.get("energy_version") != 1:
		return false
	for key in ["energy", "anchor", "high_water", "serial"]:
		if not _whole(data.get(key)):
			return false
	if data.energy > CAP or data.anchor > data.high_water or not data.get("attempts") is Dictionary:
		return false
	var seen: Dictionary = {}
	for id in data.attempts:
		if not id is String or id.is_empty() or not data.attempts[id] is Dictionary:
			return false
		var attempt: Dictionary = data.attempts[id]
		if not attempt.get("completed") is bool:
			return false
		var entry_serial := _valid_receipt(attempt.get("entry_receipt"), "attempt_entered", id, int(data.serial))
		if entry_serial == 0 or seen.has(entry_serial):
			return false
		seen[entry_serial] = true
		if attempt.completed:
			var completion_serial := _valid_receipt(attempt.get("completion_receipt"), "attempt_completed", id, int(data.serial))
			if completion_serial <= entry_serial or seen.has(completion_serial):
				return false
			seen[completion_serial] = true
		elif attempt.has("completion_receipt"):
			return false
	# Version 1 never prunes attempts: serial counts exactly these receipts.
	# Do not compare historical after balances to current energy; recovery and
	# other attempts legitimately change the balance between these operations.
	return seen.size() == int(data.serial)

func _valid_receipt(value: Variant, kind: String, attempt_id: String, serial: int) -> int:
	if not value is Dictionary:
		return 0
	var receipt: Dictionary = value
	if receipt.get("kind") != kind or receipt.get("attempt_id") != attempt_id or not receipt.get("id") is String:
		return 0
	for field in ["before", "after"]:
		if not _whole(receipt.get(field)) or receipt[field] > CAP:
			return 0
	var delta: Variant = receipt.get("delta")
	if not (delta is int or delta is float) or not is_finite(float(delta)) or float(delta) != floorf(float(delta)):
		return 0
	if delta != receipt.after - receipt.before:
		return 0
	if kind == "attempt_entered":
		if receipt.before < COST or delta != -COST:
			return 0
	elif delta != mini(COST, CAP - int(receipt.before)):
		return 0
	var receipt_id: String = receipt.id
	if not receipt_id.begins_with("energy:"):
		return 0
	var number := receipt_id.trim_prefix("energy:")
	if not number.is_valid_int():
		return 0
	var sequence := int(number)
	if sequence < 1 or sequence > serial or number != str(sequence):
		return 0
	return sequence

func _write(data: Dictionary) -> bool:
	if writer.is_valid():
		return bool(writer.call(data.duplicate(true)))
	if DirAccess.make_dir_recursive_absolute(Store.base_dir()) != OK:
		return false
	var temporary := Store.path(FILE_NAME + ".tmp")
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(data))
	file.flush()
	var written := file.get_error() == OK
	file.close()
	if not written:
		return false
	# Rename only a fully written temporary file; never truncate the last save.
	return DirAccess.rename_absolute(temporary, Store.path(FILE_NAME)) == OK

func _commit(candidate: Dictionary) -> bool:
	if not _write(candidate):
		error = "energy_save_failed"
		return false
	state = candidate
	error = ""
	return true

func _recovered() -> Dictionary:
	var candidate := state.duplicate(true)
	var now := maxi(_now(), int(candidate.high_water))
	candidate.high_water = now
	if candidate.energy == CAP:
		candidate.anchor = now
	else:
		var ticks := int((now - int(candidate.anchor)) / RECOVERY_SECONDS)
		if ticks > 0:
			candidate.energy = mini(CAP, int(candidate.energy) + ticks)
			candidate.anchor = now if candidate.energy == CAP else int(candidate.anchor) + ticks * RECOVERY_SECONDS
	return candidate

func _reject(reason: String) -> Dictionary:
	return {"accepted":false,"reason":reason,"delta":0,"events":[],"receipt":{},"energy":state.get("energy",null)}

func snapshot() -> Dictionary:
	if state.is_empty():
		return {"ok":false,"energy":null,"cap":CAP,"next_recovery_seconds":null,"ad_available":false,"error":error}
	var candidate := _recovered()
	# Save high-water even without a tick, so restart cannot turn a rollback into
	# new elapsed time. UI polls at one second; identical polls do not write.
	if candidate != state:
		_commit(candidate)
	elif error == "energy_save_failed":
		_commit(candidate)
	var remaining: Variant = null
	if state.energy < CAP:
		remaining = maxi(0, RECOVERY_SECONDS - (maxi(_now(), int(state.high_water)) - int(state.anchor)))
	return {"ok":error.is_empty(),"energy":state.energy,"cap":CAP,"next_recovery_seconds":remaining,"ad_available":false,"error":error}

func _receipt(candidate: Dictionary, kind: String, attempt_id: String, before: int) -> Dictionary:
	candidate.serial = int(candidate.serial) + 1
	return {"id":"energy:%s" % candidate.serial,"kind":kind,"attempt_id":attempt_id,"before":before,"after":candidate.energy,"delta":int(candidate.energy)-before}

func _accepted(receipt: Dictionary, duplicate: bool) -> Dictionary:
	return {"accepted":true,"duplicate":duplicate,"energy":state.energy,"delta":0 if duplicate else receipt.delta,"receipt":receipt.duplicate(true),"events":[] if duplicate else [receipt.duplicate(true)]}

func enter_attempt(attempt_id: String) -> Dictionary:
	if state.is_empty():
		return _reject(error)
	if attempt_id.is_empty():
		return _reject("invalid_attempt_id")
	if state.attempts.has(attempt_id):
		return _accepted(state.attempts[attempt_id].entry_receipt, true)
	var candidate := _recovered()
	if candidate.energy < COST:
		return _reject("insufficient_energy")
	var before := int(candidate.energy)
	candidate.energy -= COST
	var receipt := _receipt(candidate, "attempt_entered", attempt_id, before)
	candidate.attempts[attempt_id] = {"completed":false,"entry_receipt":receipt}
	if not _commit(candidate):
		return _reject(error)
	return _accepted(receipt, false)

func complete_attempt(attempt_id: String) -> Dictionary:
	if state.is_empty():
		return _reject(error)
	if not state.attempts.has(attempt_id):
		return _reject("unknown_attempt")
	if state.attempts[attempt_id].completed:
		return _accepted(state.attempts[attempt_id].completion_receipt, true)
	var candidate := _recovered()
	var before := int(candidate.energy)
	candidate.energy = mini(CAP, before + COST)
	if candidate.energy == CAP:
		candidate.anchor = candidate.high_water
	var receipt := _receipt(candidate, "attempt_completed", attempt_id, before)
	candidate.attempts[attempt_id].completed = true
	candidate.attempts[attempt_id].completion_receipt = receipt
	if not _commit(candidate):
		return _reject(error)
	return _accepted(receipt, false)

func is_ad_available() -> bool:
	return false

func begin_ad() -> Dictionary:
	return _reject("reward_unavailable")

func complete_ad(_request_id: String = "", _outcome: String = "") -> Dictionary:
	# A claimed success string is not an authenticated SDK reward receipt.
	return _reject("reward_unavailable")
