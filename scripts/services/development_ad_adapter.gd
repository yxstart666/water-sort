extends RefCounted
## Development simulation only. No SDK authentication, business rewards or IO.
## See API_CONTRACT.md for owner lifecycle and synchronous consumption rules.

signal result_ready(result: Dictionary)

const MOCK_SETTING := "development/mock_ads_enabled"
const SOURCE := "development_mock"
const DEFAULT_TTL_MSEC := 120000
const MAX_TTL_MSEC := 3600000
const MAX_CLOCK_MSEC := 9007199254740991
const PLACEMENTS := ["bottle", "slot", "energy", "shuffle", "undo"]

var _clock: Callable
var _last_now := 0
var _nonce := ""
var _serial := 0
var _attempt_id := ""
var _context_id := ""
var _pending: Dictionary = {}
var _receipt: Dictionary = {}


func _init(test_clock: Callable = Callable()) -> void:
	_clock = test_clock
	_new_nonce()


func _new_nonce() -> void:
	var bytes := Crypto.new().generate_random_bytes(32)
	_nonce = bytes.hex_encode() if bytes.size() == 32 else ""


func _failure(reason: String) -> Dictionary:
	return {"ok": false, "reason": reason}


func _gate_reason() -> String:
	# Hard gate: neither constructor nor injected clock can override the engine.
	if not OS.is_debug_build():
		return "release_build"
	var enabled: Variant = ProjectSettings.get_setting(MOCK_SETTING, false)
	if not enabled is bool or not enabled:
		return "mock_disabled"
	return ""


func _now() -> int:
	var value: Variant = _clock.call() if _clock.is_valid() else Time.get_ticks_msec()
	if not value is int or value < 0 or value > MAX_CLOCK_MSEC:
		return -1
	_last_now = maxi(_last_now, int(value))
	return _last_now


func invalidate(reason: String = "owner_invalidated") -> Dictionary:
	var request_id: String = _pending.get("request_id", _receipt.get("request_id", ""))
	_pending = {}
	_receipt = {}
	return {"ok": true, "invalidated_request_id": request_id, "reason": reason}


func reset() -> Dictionary:
	var result := invalidate("reset")
	_attempt_id = ""
	_context_id = ""
	_new_nonce()
	return result


func set_context(attempt_id: String, context_id: String) -> Dictionary:
	if attempt_id.is_empty() or context_id.is_empty():
		return _failure("invalid_context")
	var request_id := ""
	if attempt_id != _attempt_id or context_id != _context_id:
		request_id = invalidate("context_changed").invalidated_request_id
	_attempt_id = attempt_id
	_context_id = context_id
	return {"ok": true, "invalidated_request_id": request_id}


func set_mock_ads_enabled(enabled: bool) -> Dictionary:
	# In-memory only: never call save(), save_custom() or touch project.godot.
	ProjectSettings.set_setting(MOCK_SETTING, enabled)
	var request_id := ""
	if not enabled:
		request_id = invalidate("mock_disabled").invalidated_request_id
	return {"ok": true, "enabled": enabled, "invalidated_request_id": request_id}


func refresh_policy() -> Dictionary:
	var reason := _gate_reason()
	if not reason.is_empty():
		invalidate(reason)
		return _failure(reason)
	return {"ok": true}


func _finish(outcome: String, reason: String, now: int) -> Dictionary:
	# Store and clear before dispatch, so a reentrant handler can consume once.
	var result := _pending.duplicate(true)
	_pending = {}
	result["outcome"] = outcome
	result["reason"] = reason
	result["terminal_at_msec"] = now
	_receipt = result.duplicate(true)
	result_ready.emit(result.duplicate(true))
	return {"ok": true, "request_id": result.request_id, "outcome": outcome}


func _synchronize() -> String:
	var reason := _gate_reason()
	if not reason.is_empty():
		invalidate(reason)
		return reason
	var now := _now()
	if now < 0:
		invalidate("clock_invalid")
		return "clock_invalid"
	if not _pending.is_empty() and now >= int(_pending.expires_at_msec):
		_finish("expired", "ttl_elapsed", now)
		return "expired"
	if not _receipt.is_empty() and _receipt.outcome == "completed" and now >= int(_receipt.expires_at_msec):
		invalidate("expired")
		return "expired"
	return ""


func begin_mock(placement: String, attempt_id: String, context_id: String, ttl_msec: int = DEFAULT_TTL_MSEC) -> Dictionary:
	var reason := _synchronize()
	if not reason.is_empty():
		return _failure(reason)
	if placement not in PLACEMENTS:
		return _failure("invalid_placement")
	if attempt_id.is_empty() or context_id.is_empty():
		return _failure("invalid_context")
	if attempt_id != _attempt_id or context_id != _context_id:
		return _failure("context_mismatch")
	if ttl_msec < 1 or ttl_msec > MAX_TTL_MSEC:
		return _failure("invalid_ttl")
	if not _pending.is_empty() or not _receipt.is_empty():
		return _failure("busy")
	if _nonce.is_empty():
		return _failure("entropy_unavailable")
	_serial += 1
	_pending = {
		"schema_version": 1,
		"request_id": "dev_mock:%s:%s" % [_nonce, _serial],
		"placement": placement,
		"attempt_id": attempt_id,
		"context_id": context_id,
		"source": SOURCE,
		"created_at_msec": _last_now,
		"expires_at_msec": _last_now + ttl_msec,
	}
	return {"ok": true, "request": _pending.duplicate(true)}

func begin_request(placement:String,attempt_id:String,context_id:String,ttl_msec:int=DEFAULT_TTL_MSEC)->Dictionary:
	return begin_mock(placement,attempt_id,context_id,ttl_msec)


func _matches(value: Dictionary, request_id: String, placement: String, attempt_id: String, context_id: String) -> bool:
	return value.request_id == request_id and value.placement == placement and value.attempt_id == attempt_id and value.context_id == context_id


func _pending_reason(request_id: String, placement: String, attempt_id: String, context_id: String) -> String:
	var reason := _synchronize()
	if not reason.is_empty():
		return reason
	if _pending.is_empty():
		return "no_pending"
	if not _matches(_pending, request_id, placement, attempt_id, context_id):
		return "identity_mismatch"
	return ""


func complete_mock(request_id: String, placement: String, attempt_id: String, context_id: String) -> Dictionary:
	var reason := _pending_reason(request_id, placement, attempt_id, context_id)
	if not reason.is_empty():
		return _failure(reason)
	return _finish("completed", "dev_button_completed", _last_now)


func cancel(request_id: String, placement: String, attempt_id: String, context_id: String) -> Dictionary:
	var reason := _pending_reason(request_id, placement, attempt_id, context_id)
	if not reason.is_empty():
		return _failure(reason)
	return _finish("cancelled", "dev_button_cancelled", _last_now)


func expire(request_id: String, placement: String, attempt_id: String, context_id: String) -> Dictionary:
	# _pending_reason performs expiry at the exact TTL boundary and dispatches it.
	var was_matching := not _pending.is_empty() and _matches(_pending, request_id, placement, attempt_id, context_id)
	var reason := _pending_reason(request_id, placement, attempt_id, context_id)
	if reason == "expired" and was_matching:
		return {"ok": true, "request_id": request_id, "outcome": "expired"}
	return _failure(reason if not reason.is_empty() else "not_expired")


func poll() -> Dictionary:
	var reason := _synchronize()
	if not reason.is_empty():
		return _failure(reason)
	return {"ok": true, "pending": _pending.duplicate(true), "result_pending": not _receipt.is_empty()}


func consume_result(request_id: String, placement: String, attempt_id: String, context_id: String) -> Dictionary:
	var reason := _synchronize()
	if not reason.is_empty():
		return _failure(reason)
	if _receipt.is_empty():
		return _failure("no_result")
	if not _matches(_receipt, request_id, placement, attempt_id, context_id):
		return _failure("identity_mismatch")
	var result := _receipt.duplicate(true)
	_receipt = {}
	return {"ok": true, "result": result}


func begin_sdk(_placement: String, _attempt_id: String, _context_id: String) -> Dictionary:
	# No SDK installed. External strings cannot authenticate a rewarded view.
	return _failure("reward_unavailable")
