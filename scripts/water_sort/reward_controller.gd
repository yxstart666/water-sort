extends RefCounted
## Shared business router. Owned adapter supplies one-use receipts; UI never grants rewards.
signal request_started(request: Dictionary)
signal finished(outcome: String, reason: String, placement: String)
signal save_failed(reason: String)
signal status_changed(state:String,detail:String)
var provider_kind:="development_mock"
var _stopped:=false
var _adapter_status_callback:Callable
var _native_injection:Object
func is_native()->bool:return provider_kind=="google_test"
func receipt_source()->String:return "google_test_sdk" if is_native() else "development_mock"
func is_enabled()->bool:
	if _stopped:return false
	if is_native():return adapter!=null and adapter.available()
	var flag:Variant=ProjectSettings.get_setting(SETTING,false)
	return provider_kind=="development_mock" and OS.is_debug_build() and flag is bool and flag
const SETTING := "development/mock_ads_enabled"
var host
var adapter
var _clock: Callable
var _session := Crypto.new().generate_random_bytes(32).hex_encode()
var _epoch := 0
var _request: Dictionary={}
var _operation: Dictionary={}
var _committing := false
var _prepared:Dictionary={}
var _preparing:Dictionary={}
var _search_thread:Thread
var _search_mutex:=Mutex.new()
var _search_cancelled:=false
var rearrangement_budget_msec:=750
var rearrangement_seed:=0 # Test injection only; zero uses a fresh runtime seed.
const NativeReceipt=preload("res://scripts/services/native_reward_receipt.gd")
const NativeSettlement=preload("res://scripts/water_sort/native_reward_settlement.gd")
const Rearrange=preload("res://scripts/water_sort/order_rearrangement.gd")
const Orders=preload("res://scripts/water_sort/order_rules.gd")

func _init(owner_app,test_clock:Callable=Callable(),kind:String="development_mock",native_injection:Object=null)->void:
	host=owner_app;_clock=test_clock;provider_kind=kind;_native_injection=native_injection
	if is_native():_ensure_adapter()


func active_request() -> Dictionary:
	return (_preparing if not _preparing.is_empty() else _request).duplicate(true)

func pending_operation() -> Dictionary:
	return _operation.duplicate(true)
func can_settle_pending()->bool:
	return not _operation.is_empty() and ((is_native() and NativeReceipt.valid(_operation)) or is_enabled())

func _context() -> Dictionary:
	if host.game.visible and not host.attempt_id.is_empty():
		return {"attempt_id":host.attempt_id,"scope":"game:%s:%d:%s" % [host.attempt_id,host.game.level_index,"energy" if is_instance_valid(host.energy_popup) else "board"]}
	return {"attempt_id":"energy:home:"+_session,"scope":"home:%s:%s" % [host.home.page,"energy" if host.home.energy_open else "page"]}

func _eligible(placement: String, completing := false) -> String:
	if not is_enabled() and not (completing and is_native() and not _operation.is_empty()): return "reward_unavailable"
	if placement=="energy":
		var energy: Dictionary=host.energy.snapshot()
		if not energy.get("ok",false): return "energy_unavailable"
		return "" if completing and is_native() else ("energy_full" if int(energy.energy)>=int(energy.cap) else "")
	if placement not in ["bottle","slot","shuffle","undo"]: return "invalid_placement"
	var game=host.game
	if not game.visible or not host.loaded_attempt or host.attempt_id.is_empty(): return "no_active_attempt"
	if not game.rules.has_method("has_bonus"): return "no_bonus"
	if host.progress.data.settlements.has(host.attempt_id): return "attempt_completed"
	if game.state not in (["playing","stuck","reward"] if completing else ["playing","stuck"]) or game._animation_busy(): return "game_busy"
	if placement in ["shuffle","undo"]:
		if not game.presentation.input_queue.is_empty():return "game_busy"
		if placement=="undo" and game.history.is_empty() and not completing:return "no_history"
		if game.rules.is_solved():return "attempt_completed"
		return ""
	if not game.rules.has_bonus(): return "no_bonus"
	if (placement=="bottle" and game.rules.bonus_unlocked) or (placement=="slot" and game.rules.slot_unlocked): return "already_claimed"
	return ""

func can_begin(placement: String) -> bool:
	return _request.is_empty() and _operation.is_empty() and _preparing.is_empty() and _search_thread==null and _eligible(placement).is_empty() and (not is_native() or adapter.ready())

func begin(placement: String, ttl_msec := 120000) -> Dictionary:
	if not _request.is_empty() or not _operation.is_empty() or not _preparing.is_empty() or _search_thread!=null: return {"ok":false,"reason":"busy"}
	var reason:=_eligible(placement)
	if not reason.is_empty(): return {"ok":false,"reason":reason}
	if is_native() and placement in ["bottle","slot"]:
		if not host._checkpoint():return {"ok":false,"reason":"checkpoint_save_failed"}
		NativeSettlement.prepare_bonus(self,placement)
	if placement in ["shuffle","undo"]:
		if not host._checkpoint():return {"ok":false,"reason":"checkpoint_save_failed"}
		var game=host.game;var context:=_context()
		_prepared={"placement":placement,"attempt_id":context.attempt_id,"scope":context.scope,"before":game.rules.snapshot(),"history":game.history.duplicate(true),"moves":game.moves,"seconds":game.elapsed,"sequence":int(host.progress.data.pending_attempt.get("board_action_sequence",0)),"ttl_msec":ttl_msec}
		if placement=="shuffle":
			_preparing=_prepared;_prepared={};_preparing.preparing=true
			_search_mutex.lock();_search_cancelled=false;_search_mutex.unlock()
			var search:=Rearrange.new();_search_thread=Thread.new()
			var seed_value:int=rearrangement_seed if rearrangement_seed!=0 else Time.get_ticks_usec()
			var error:=_search_thread.start(search.prepare.bind(game.rules.level.duplicate(true),_preparing.before.duplicate(true),seed_value,rearrangement_budget_msec,12000,_cancelled_search))
			if error!=OK:_search_thread=null;_preparing.clear();return {"ok":false,"reason":"worker_unavailable"}
			request_started.emit(_preparing.duplicate(true));return {"ok":true,"preparing":true}
		var undo=Orders.new(game.rules.level)
		if not undo.restore(game.history[-1].snapshot):_prepared.clear();return {"ok":false,"reason":"invalid_history"}
		if game.rules.bonus_unlocked:undo.unlock("bottle")
		if game.rules.slot_unlocked:undo.unlock("slot")
		_prepared.after=undo.snapshot();_prepared.after_moves=int(game.history[-1].moves)
	return _begin_ad(placement,ttl_msec)

func _begin_ad(placement:String,ttl_msec:int)->Dictionary:
	_ensure_adapter()
	var context:=_context()
	var context_id: String=_session+":"+str(_epoch)+":"+context.scope
	adapter.set_context(context.attempt_id,context_id)
	var result: Dictionary=adapter.begin_request(placement,context.attempt_id,context_id,ttl_msec)
	if result.get("ok",false):
		_request=result.request.duplicate(true); _request.scope=context.scope
		request_started.emit(result.request.duplicate(true))
	return result

func complete() -> Dictionary:
	if is_native():return {"ok":false,"reason":"native_callback_only"}
	if _request.is_empty(): return {"ok":false,"reason":"no_pending"}
	var r:=_request.duplicate(true)
	return adapter.complete_mock(r.request_id,r.placement,r.attempt_id,r.context_id)

func cancel() -> Dictionary:
	if is_native() and adapter!=null and adapter.verifying_earned():
		status_changed.emit("verifying","");return {"ok":false,"reason":"verification_pending"}
	if not _preparing.is_empty():
		_stop_search();_preparing.clear();finished.emit("cancelled","cancelled","shuffle");return {"ok":true,"outcome":"cancelled"}
	if not _operation.is_empty():
		if is_native():
			save_failed.emit("reward_save_pending");return {"ok":true,"outcome":"pending"}
		if holds_board_reward():
			save_failed.emit("reward_save_pending");return {"ok":true,"outcome":"pending"}
		# A consumed completion is not a new ad. Keep its unsaved operation for
		# retry while the same source context remains; navigation invalidates it.
		finished.emit("pending","save_pending",_operation.placement)
		return {"ok":true,"outcome":"pending"}
	if _request.is_empty(): return {"ok":false,"reason":"no_pending"}
	var r:=_request.duplicate(true)
	return adapter.cancel(r.request_id,r.placement,r.attempt_id,r.context_id)

func matches_identity(identity: Dictionary, retry := false) -> bool:
	var current: Dictionary=_operation if retry else _request
	if current.is_empty(): return false
	for key in ["request_id","placement","attempt_id","context_id"]:
		if identity.get(key)!=current.get(key): return false
	return true

func invalidate(reason := "context_changed") -> void:
	if is_native() and not _operation.is_empty():
		save_failed.emit("reward_save_pending");return
	var placement: String=_request.get("placement",_operation.get("placement",_preparing.get("placement","")))
	_stop_search();_preparing.clear();_prepared.clear()
	if adapter!=null: adapter.invalidate(reason)
	_request.clear(); _operation.clear(); _epoch+=1
	if not placement.is_empty(): finished.emit("cancelled",reason,placement)

func set_enabled(value: bool) -> void:
	if is_native():return
	if adapter!=null: adapter.set_mock_ads_enabled(value)
	else: ProjectSettings.set_setting(SETTING,value)
	if not value: invalidate("mock_disabled")

func poll() -> void:
	if _search_thread!=null and not _search_thread.is_alive():
		var candidate:Dictionary=_search_thread.wait_to_finish();_search_thread=null
		if not _preparing.is_empty():
			var ready:=_preparing;_preparing={}
			if not is_enabled() or not _action_matches(ready) or not _eligible("shuffle",true).is_empty():finished.emit("cancelled","stale_board","shuffle")
			elif not candidate.ok:finished.emit("failed",str(candidate.reason),"shuffle")
			else:
				_prepared=ready;_prepared.after=candidate.snapshot;_prepared.after_moves=ready.moves
				_prepared.proof_steps=candidate.solution.size();_prepared.search_usec=candidate.elapsed_usec
				var started:Dictionary=_begin_ad("shuffle",int(ready.ttl_msec))
				if not started.get("ok",false):
					_prepared.clear();finished.emit("failed",str(started.get("reason","native_not_ready")),"shuffle")
	if not is_enabled() and not (is_native() and not _operation.is_empty()):
		if not _request.is_empty() or not _operation.is_empty(): invalidate("mock_disabled")
		return
	if not _preparing.is_empty() and not _action_matches(_preparing):invalidate("stale_board");return
	var scope: String=_request.get("scope",_operation.get("scope",""))
	if not scope.is_empty() and scope!=str(_context().scope) and not (is_native() and not _operation.is_empty() and _operation.placement=="energy"):
		invalidate("context_changed"); return
	if adapter!=null:
		var result: Dictionary=adapter.poll()
		if not result.get("ok",false) and not _request.is_empty(): invalidate(str(result.reason))

func _result_ready(_untrusted_signal: Dictionary) -> void:
	if _request.is_empty(): return
	var r:=_request.duplicate(true)
	var consumed: Dictionary=adapter.consume_result(r.request_id,r.placement,r.attempt_id,r.context_id)
	if not consumed.get("ok",false):
		if consumed.get("reason") in ["no_result","identity_mismatch"]: return
		_request.clear()
		finished.emit("cancelled",str(consumed.get("reason","unverified")),r.placement); return
	_request.clear()
	var result: Dictionary=consumed.result
	if result.outcome!="completed":
		finished.emit(result.outcome,str(result.reason),r.placement)
		if is_native():_native_reload_when_idle.call_deferred()
		return
	if not is_enabled() or result.source!=receipt_source() or str(_context().scope)!=str(r.scope) or (is_native() and not NativeReceipt.valid(result)):
		finished.emit("cancelled","stale_or_disabled",r.placement); return
	var reason:=_eligible(r.placement,true)
	if r.placement in ["shuffle","undo"] and not _action_matches(_prepared):reason="stale_board"
	if not reason.is_empty():
		finished.emit("cancelled",reason,r.placement); return
	_operation=result.duplicate(true); _operation.scope=r.scope
	retry_pending()

func authorizes_energy(service, request_id: String) -> bool:
	return is_enabled() and _committing and service==host.energy and not _operation.is_empty() and _operation.placement=="energy" and _operation.request_id==request_id and _operation.source==receipt_source() and _operation.scope==str(_context().scope)

func authorizes_board_action(service,request_id:String)->bool:
	return is_enabled() and _committing and service==host.progress and not _operation.is_empty() and _operation.placement in ["shuffle","undo"] and _operation.request_id==request_id and _operation.source==receipt_source() and _action_matches(_prepared)

func holds_board_reward()->bool:
	return not _operation.is_empty() and (_operation.placement in ["shuffle","undo"] or (is_native() and _operation.placement in ["bottle","slot"]))

func resume_saved_reward()->bool:
	if is_native():return NativeSettlement.recover(self)
	var reward:Dictionary=host.progress.data.pending_attempt.get("board_action_reward",{})
	if reward.is_empty() or not is_enabled() or not _operation.is_empty():return false
	var context:=_context();var game=host.game
	if game.rules.snapshot()!=reward.expected:return false
	_prepared={"placement":reward.kind,"attempt_id":context.attempt_id,"scope":context.scope,"before":game.rules.snapshot(),"history":game.history.duplicate(true),"moves":game.moves,"seconds":reward.seconds,"sequence":int(reward.sequence),"after":reward.after.duplicate(true),"after_moves":int(reward.moves)}
	_operation={"request_id":reward.request_id,"placement":reward.kind,"attempt_id":context.attempt_id,"context_id":_session+":recovered","scope":context.scope,"source":"development_mock"}
	save_failed.emit("saved_reward_ready");return true

func _action_matches(action:Dictionary)->bool:
	if action.is_empty() or action.attempt_id!=host.attempt_id or action.scope!=str(_context().scope):return false
	return (NativeReceipt.same(host.game.rules.snapshot(),action.before) if is_native() else host.game.rules.snapshot()==action.before) and host.game.history==action.history and host.game.moves==action.moves and int(host.progress.data.pending_attempt.get("board_action_sequence",0))==int(action.sequence)

func _cancelled_search()->bool:
	_search_mutex.lock();var value:=_search_cancelled;_search_mutex.unlock();return value

func _stop_search()->void:
	_search_mutex.lock();_search_cancelled=true;_search_mutex.unlock()

func shutdown()->void:
	if _stopped:return
	if is_native() and not _operation.is_empty():retry_pending()
	else:invalidate("app_exit")
	_stopped=true
	if is_native() and adapter!=null:adapter.shutdown()
	if _search_thread!=null:_search_thread.wait_to_finish();_search_thread=null
	if adapter!=null:
		if adapter.result_ready.is_connected(_result_ready):adapter.result_ready.disconnect(_result_ready)
		if _adapter_status_callback.is_valid() and adapter.status_changed.is_connected(_adapter_status_callback):adapter.status_changed.disconnect(_adapter_status_callback)
	adapter=null;_adapter_status_callback=Callable()
	host=null;_native_injection=null;_clock=Callable()

func retry_pending() -> Dictionary:
	if _committing: return {"ok":false,"reason":"commit_busy"}
	if _operation.is_empty(): return {"ok":false,"reason":"no_operation"}
	var op:=_operation.duplicate(true)
	if (not is_enabled() and not is_native()) or (op.scope!=str(_context().scope) and not (is_native() and op.placement=="energy")):
		invalidate("stale_or_disabled"); return {"ok":false,"reason":"stale_or_disabled"}
	var reason:=_eligible(op.placement,true)
	if not reason.is_empty():
		if reason in ["game_busy","energy_unavailable"]:
			save_failed.emit(reason); return {"ok":false,"reason":reason}
		invalidate(reason); return {"ok":false,"reason":reason}
	_committing=true
	if is_native():
		var applied:Dictionary=NativeSettlement.settle(self,op);_committing=false
		if applied.get("ok",false):
			_operation.clear();_prepared.clear();finished.emit("completed","saved",op.placement)
			_native_reload_when_idle.call_deferred()
		else:save_failed.emit(str(applied.get("reason","reward_save_failed")))
		return applied
	var saved:=false
	if op.placement in ["shuffle","undo"]:
		if not _action_matches(_prepared):
			_committing=false;invalidate("stale_board");return {"ok":false,"reason":"stale_board"}
		if not host.progress.save_board_action_reward(host.attempt_id,op.request_id,op.placement,int(_prepared.sequence),_prepared.before,_prepared.after,int(_prepared.after_moves),float(_prepared.seconds),self):
			_committing=false;save_failed.emit("reward_receipt_save_failed");return {"ok":false,"reason":"reward_receipt_save_failed"}
		var result:Dictionary=host.progress.commit_board_action(host.attempt_id,op.request_id,op.placement,int(_prepared.sequence),_prepared.before,_prepared.after,int(_prepared.after_moves),float(_prepared.seconds),self)
		saved=result.ok;reason=str(result.get("reason",""))
		if saved and not result.get("already_applied",false):
			host.game.rules.restore(_prepared.after);host.game.moves=int(_prepared.after_moves)
			if op.placement=="shuffle":host.game.history.clear()
			elif not host.game.history.is_empty():host.game.history.pop_back()
			host.game.selected=-1;host.game.restore_presentation()
	elif op.placement=="energy":
		var result: Dictionary=host.energy.commit_development_refill(op.request_id,self)
		saved=bool(result.get("accepted",false)); reason=str(result.get("reason",""))
	else:
		var game=host.game
		var prior: Dictionary=game.rules.snapshot()
		var events: Array=game.rules.last_events.duplicate(true)
		if game.rules.unlock(op.placement):
			saved=host.progress.save_checkpoint(host.attempt_id,game.rules.snapshot(),game.moves,game.elapsed)
			if not saved:
				game.rules.restore(prior); game.rules.last_events=events
			reason="reward_save_failed"
	_committing=false
	if saved:
		_operation.clear();_prepared.clear(); finished.emit("completed","saved",op.placement)
		return {"ok":true}
	save_failed.emit(reason)
	return {"ok":false,"reason":reason}

func _ensure_adapter()->void:
	if adapter!=null:return
	if is_native():
		adapter=load("res://scripts/services/owned_native_reward_adapter.gd").new(_native_injection,_clock)
		_adapter_status_callback=func(state,detail):status_changed.emit(state,detail)
		adapter.status_changed.connect(_adapter_status_callback)
	else:adapter=load("res://scripts/services/development_ad_adapter.gd").new(_clock)
	adapter.result_ready.connect(_result_ready)
func initialize_provider()->void:
	if is_native() and adapter!=null:adapter.initialize()
func set_backgrounded(value:bool)->void:
	if is_native() and adapter!=null:adapter.set_backgrounded(value)
func privacy_options_required()->bool:return is_native() and adapter!=null and adapter.privacy_options_required()
func show_privacy_options()->bool:return is_native() and adapter!=null and adapter.show_privacy_options()

func authorizes_native_progress(service,request_id:String)->bool:
	return is_native() and _committing and service==host.progress and NativeReceipt.valid(_operation) and _operation.request_id==request_id and _operation.placement in ["bottle","slot","shuffle","undo"] and _action_matches(_prepared)
func authorizes_native_energy(service,request_id:String)->bool:
	return is_native() and _committing and service==host.energy and NativeReceipt.valid(_operation) and _operation.request_id==request_id and _operation.placement=="energy"
func native_status()->Dictionary:
	return {"available":is_enabled(),"ready":adapter!=null and adapter.ready(),"state":adapter.last_status if adapter!=null else "unavailable","detail":adapter.last_detail if adapter!=null else "native_plugin_unavailable","privacy_required":privacy_options_required()} if is_native() else {}
func retry_native_loading()->bool:return is_native() and adapter!=null and adapter.retry_loading()
func _native_reload_when_idle()->void:
	if not _stopped and is_native() and _request.is_empty() and _operation.is_empty() and adapter!=null:adapter.retry_loading()
