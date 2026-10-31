extends RefCounted
## Owned one-use delivery port. UI dictionaries are never used as reward proof.
signal result_ready(result:Dictionary)
signal status_changed(state:String,detail:String)
const Native=preload("res://scripts/services/android_test_ad_adapter.gd")
const SOURCE:="google_test_sdk"
var inner
var _attempt:=""
var _context:=""
var _nonce:=Crypto.new().generate_random_bytes(32).hex_encode()
var _serial:=0
var _receipt:Dictionary={}
var _pending:Dictionary={}
var _initialized:=false
var _preload_pending:=false
var _shutdown:=false
var last_status:="initializing"
var last_detail:=""
func _init(native_object:Object=null,clock:Callable=Callable())->void:
	inner=Native.new(native_object,clock)
	inner.result_ready.connect(_receive)
	inner.status_changed.connect(_status)
	if not inner.available():last_status="unavailable";last_detail="native_plugin_unavailable"
func available()->bool:return not _shutdown and inner!=null and inner.available()
func ready()->bool:return available() and inner.ready() and _receipt.is_empty()
func verifying_earned()->bool:return inner.verifying_earned()
func initialize()->bool:return inner.initialize()
func retry_loading()->bool:
	if not available():return false
	if not _initialized:return inner.initialize()
	_preload_pending=true;return _try_preload()
func privacy_options_required()->bool:return available() and inner.privacy_options_required()
func show_privacy_options()->bool:return inner.show_privacy_options()
func set_context(attempt:String,context:String)->Dictionary:
	if attempt!=_attempt or context!=_context:invalidate("context_changed")
	_attempt=attempt;_context=context;return {"ok":true}
func begin_request(placement:String,attempt:String,context:String,ttl_msec:int)->Dictionary:
	if _nonce.length()!=64:return {"ok":false,"reason":"entropy_unavailable"}
	if not _pending.is_empty() or not _receipt.is_empty():return {"ok":false,"reason":"busy"}
	if attempt!=_attempt or context!=_context:return {"ok":false,"reason":"context_mismatch"}
	if not ready():return {"ok":false,"reason":"native_not_ready" if available() else "native_plugin_unavailable"}
	_serial+=1
	var id:="google_test:%s:%d" % [_nonce,_serial]
	_pending={"request_id":id,"placement":placement,"attempt_id":attempt,"context_id":context,"source":SOURCE}
	_show_native.call_deferred(id,ttl_msec)
	return {"ok":true,"request":_pending.duplicate(true)}
func _show_native(id:String,ttl_msec:int)->void:
	if _shutdown or _pending.get("request_id","")!=id:return
	var started:Dictionary=inner.begin(id,_pending.placement,_pending.attempt_id,_pending.context_id,ttl_msec)
	if not started.ok:
		var failed:=_pending.duplicate(true);failed.outcome="failed";failed.reason=started.get("reason","native_unavailable");_receive(failed)
func _receive(result:Dictionary)->void:
	if _shutdown or _pending.is_empty():return
	for key in ["request_id","placement","attempt_id","context_id","source"]:
		if result.get(key)!=_pending.get(key):return
	_pending.clear();_receipt=result.duplicate(true);result_ready.emit(result.duplicate(true))
func consume_result(id:String,placement:String,attempt:String,context:String)->Dictionary:
	if _receipt.is_empty():return {"ok":false,"reason":"no_result"}
	if _receipt.request_id!=id or _receipt.placement!=placement or _receipt.attempt_id!=attempt or _receipt.context_id!=context:return {"ok":false,"reason":"identity_mismatch"}
	var result:=_receipt.duplicate(true);_receipt.clear();return {"ok":true,"result":result}
func cancel(id:String,placement:String,attempt:String,context:String)->Dictionary:
	if _pending.is_empty() or _pending.request_id!=id or _pending.placement!=placement or _pending.attempt_id!=attempt or _pending.context_id!=context:return {"ok":false,"reason":"identity_mismatch"}
	inner.invalidate("user_cancelled");return {"ok":true}
func invalidate(reason:String="context_changed")->Dictionary:
	inner.invalidate(reason);_pending.clear();_receipt.clear();return {"ok":true}
func poll()->Dictionary:
	inner.poll();return {"ok":true}
func set_backgrounded(value:bool)->void:
	inner.set_backgrounded(value)
	if not value:_try_preload()
func shutdown()->void:
	if _shutdown:return
	_shutdown=true
	inner.shutdown()
	if inner.result_ready.is_connected(_receive):inner.result_ready.disconnect(_receive)
	if inner.status_changed.is_connected(_status):inner.status_changed.disconnect(_status)
	inner=null;_pending.clear();_receipt.clear()
func _status(state:String,detail:String)->void:
	last_status=state;last_detail=detail
	if state=="initialized":_initialized=true;_preload_pending=true;_try_preload()
	elif state in ["privacy_changed","privacy_error","native_closed"] and _initialized:_preload_pending=true;_try_preload()
	status_changed.emit(state,detail)
func _try_preload()->bool:
	if not _preload_pending or not available() or not _pending.is_empty() or not _receipt.is_empty():return false
	# Clear before the call: SDK/test signals may arrive synchronously. If UMP
	# initialization completed while its Activity paused Godot, resume retries
	# this one deferred load, without a per-frame network retry loop.
	_preload_pending=false
	if inner.load_ad():return true
	_preload_pending=true;return false
