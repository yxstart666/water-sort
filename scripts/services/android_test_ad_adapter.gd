extends RefCounted
## Test SDK callback capability only; this is not server-side verification.
signal result_ready(result: Dictionary)
signal status_changed(state: String, detail: String)
const SOURCE := "google_test_sdk"
const PLACEMENTS := ["bottle", "slot", "energy", "shuffle", "undo"]
var _native: Object
var _request: Dictionary = {}
var _retired: Dictionary = {}
var _awaiting_native_close: Dictionary = {}
var _earned := false
var _receipt := false
var _dismissed := false
var _closed := false
var _ready := false
var _backgrounded := false
var _deadline := 0
var _clock: Callable

func _init(injected_native: Object = null, clock: Callable = Callable()) -> void:
    _clock = clock
    if injected_native != null:
        _native = injected_native # Isolated test seam, never a provider setting.
    elif OS.get_name() == "Android" and Engine.has_singleton("ColorPauseTestAds"):
        _native = Engine.get_singleton("ColorPauseTestAds")
    if _native != null:
        if not _native.has_signal("ad_event"):
            _native=null
        else:
            for method in ["initialize","load","show","consume","invalidate","showPrivacyOptions","privacyOptionsRequired"]:
                if not _native.has_method(method):_native=null;break
        if _native!=null:_native.ad_event.connect(_on_event)

func _now() -> int:
    return int(_clock.call()) if _clock.is_valid() else Time.get_ticks_msec()

func available() -> bool:
    return _native != null and not _closed

func ready() -> bool:
    return available() and _ready and not _backgrounded and _request.is_empty() and _awaiting_native_close.is_empty()

func verifying_earned()->bool:
    return not _request.is_empty() and (_earned or _receipt)

func initialize() -> bool:
    if not available(): return false
    _native.initialize()
    return true

func load_ad() -> bool:
    if not available() or _backgrounded or not _request.is_empty() or not _awaiting_native_close.is_empty(): return false
    _native.load()
    return true

func privacy_options_required()->bool:
    return available() and bool(_native.privacyOptionsRequired())

func show_privacy_options()->bool:
    if not available() or _backgrounded or not _request.is_empty() or not _awaiting_native_close.is_empty():return false
    _ready=false
    _native.showPrivacyOptions()
    return true

func begin(request_id: String, placement: String, attempt_id: String, context_id: String, ttl_msec := 120000) -> Dictionary:
    if not available(): return {"ok": false, "reason": "reward_unavailable"}
    if not _request.is_empty(): return {"ok": false, "reason": "busy"}
    if _retired.has(request_id): return {"ok": false, "reason": "reused_request"}
    if placement not in PLACEMENTS or request_id.is_empty() or attempt_id.is_empty() or context_id.is_empty() or ttl_msec < 1 or ttl_msec > 3600000:
        return {"ok": false, "reason": "invalid_identity"}
    if not ready(): return {"ok": false, "reason": "not_ready"}
    _request = {"request_id": request_id, "placement": placement, "attempt_id": attempt_id, "context_id": context_id, "source": SOURCE}
    _ready = false
    _earned = false
    _receipt = false
    _dismissed = false
    _deadline = _now() + ttl_msec
    _native.show(request_id)
    return {"ok": true}

func invalidate(reason := "context_changed") -> void:
    if _request.is_empty(): return
    if available(): _native.invalidate(_request.request_id)
    _finish("cancelled", reason)

func poll() -> void:
    if not _request.is_empty() and not (_receipt and _dismissed) and _now() >= _deadline:
        if available(): _native.invalidate(_request.request_id)
        _finish("expired", "callback_timeout")

func set_backgrounded(value: bool) -> void:
    # A native ad pauses the Godot Activity too. Pause alone is not cancellation.
    _backgrounded = value
    if not value: _finish_if_ready()

func shutdown() -> void:
    invalidate("shutdown")
    if _native != null and _native.ad_event.is_connected(_on_event): _native.ad_event.disconnect(_on_event)
    _closed = true
    _ready = false

func _on_event(request_id: String, state: String, detail: String) -> void:
    if _closed: return
    if request_id.is_empty():
        if state == "loaded": _ready = true
        elif state in ["loading", "load_failed", "unavailable", "consent_error", "privacy_changed"]: _ready = false
        status_changed.emit(state, detail)
        return
    if _request.is_empty() or request_id != _request.request_id:
        # Cancelling the game's request cannot dismiss an OS ad. Its eventual
        # close may permit preloading again, but can never recreate a reward.
        if _awaiting_native_close.has(request_id) and state in ["dismissed","failed"]:
            _awaiting_native_close.erase(request_id)
            status_changed.emit("native_closed",detail)
        return
    match state:
        "earned":
            if not _earned:
                _earned = true
                _native.consume(request_id)
        "receipt":
            if not _earned or detail != "verified_test_sdk" or _receipt: return
            _receipt = true
            _finish_if_ready()
        "dismissed":
            _dismissed = true
            if _receipt: _finish_if_ready()
            elif not _earned: _finish("cancelled", "closed_without_reward")
        "failed", "receipt_rejected": _finish("failed", detail)
    status_changed.emit(state, detail)

func _finish_if_ready() -> void:
    if not _request.is_empty() and _receipt and _dismissed and not _backgrounded:
        _finish("completed", "verified_test_sdk")

func _finish(outcome: String, reason: String) -> void:
    var result := _request.duplicate(true)
    _retired[result.request_id] = true
    if outcome in ["cancelled","expired"] and not _dismissed:
        _awaiting_native_close[result.request_id]=true
    _request = {}
    _earned = false
    _receipt = false
    _dismissed = false
    result.outcome = outcome
    result.reason = reason
    result_ready.emit(result)
