extends "res://tests/water_sort_orders/native_reward_host_smoke.gd"
var failures_rows:Array=[]
func start(placement:String,ttl:int=120000)->String:
	if placement=="undo":app.game.select_bottle(0);app.game.select_bottle(2);drain()
	app.debug_ads.rearrangement_seed=20261030
	var r:Dictionary=app.debug_ads.begin(placement,ttl);check(r.ok,"qualified native request "+placement)
	for i in 300:
		await process_frame;app.debug_ads.poll()
		if not app.debug_ads.active_request().get("preparing",false):break
	await process_frame
	var id:String=app.debug_ads.active_request().get("request_id","")
	check(not id.is_empty() and native.shows.size()==1,"one actual native show after preparation "+placement)
	return id
func run()->void:
	check(DisplayServer.get_name()=="headless","headless only")
	root.content_scale_size=Vector2i(1080,1920);root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS;root.size=Vector2i(390,844)
	for placement in ["bottle","slot","undo","shuffle","energy"]:
		for outcome in ["cancel","failed","timeout","background","save_failed"]:
			await make();var id:String=await start(placement,10 if outcome=="timeout" else 120000)
			var prior:Dictionary=app.game.rules.snapshot();var energy_before:int=app.energy.state.energy;var moves_before:int=app.game.moves
			if outcome=="cancel":native.ad_event.emit(id,"dismissed","")
			elif outcome=="failed":native.ad_event.emit(id,"failed","3")
			elif outcome=="timeout":now+=10;app.debug_ads.poll()
			elif outcome=="background":
				app._notification(Node.NOTIFICATION_APPLICATION_PAUSED);native.complete(id)
				check(app.debug_ads.pending_operation().is_empty() and app.game.rules.snapshot()==prior and app.energy.state.energy==energy_before,"background callback cannot mutate before foreground "+placement)
				now+=3600000;app.debug_ads.poll();app._notification(Node.NOTIFICATION_APPLICATION_RESUMED)
			else:
				if placement=="energy":memory.fail_energy=true
				else:memory.fail_progress=true
				native.complete(id)
				check(not app.debug_ads.pending_operation().is_empty() and app.game.rules.snapshot()==prior and app.energy.state.energy==energy_before,"write failure retains consumed proof and original business state "+placement)
				check(not app.debug_ads.begin(placement).ok,"no second ad while receipt save pending "+placement)
				var shows:int=native.shows.size();app._cancel_test_ad()
				check(not app.debug_ads.pending_operation().is_empty() and native.shows.size()==shows,"close cannot discard verified pending proof "+placement)
				memory.fail_energy=false;memory.fail_progress=false
				check(app.debug_ads.retry_pending().get("ok",false) and native.shows.size()==shows,"retry saves without rewatch "+placement)
			await process_frame
			if outcome in ["cancel","failed","timeout"]:
				check(app.game.rules.snapshot()==prior and app.energy.state.energy==energy_before and app.game.moves==moves_before,"non-earned terminal never rewards "+placement+outcome)
				if app._ad_open:app._cancel_test_ad()
				check(not app._ad_open and app.game.state=="playing","close restores native input state "+placement+outcome)
			else:
				check(app.debug_ads.pending_operation().is_empty() and not app._ad_open,"earned operation commits and restores once "+placement+outcome)
				if placement=="energy":check(app.energy.state.energy==30,"energy earns exact refill")
				elif placement=="bottle":check(app.game.rules.bonus_unlocked,"bottle earned")
				elif placement=="slot":check(app.game.rules.slot_unlocked,"slot earned")
				elif placement=="undo":check(app.game.moves==moves_before-1,"undo earned")
				else:check(app.progress.data.pending_attempt.get("board_action_sequence",0)==1,"verified shuffle earned once")
			var after:Dictionary=app.game.rules.snapshot();var final_energy:int=app.energy.state.energy
			native.complete(id);native.ad_event.emit(id,"receipt","verified_test_sdk");await process_frame
			check(app.game.rules.snapshot()==after and app.energy.state.energy==final_energy and native.consumes==(1 if outcome in ["background","save_failed"] else 0),"duplicate/stale native terminal ignored "+placement+outcome)
			failures_rows.append({"placement":placement,"outcome":outcome,"shows":native.shows.size(),"consumes":native.consumes});await dispose()
	# A raw receipt is not proof. An earned result awaiting Java consume cannot
	# be discarded by the app's Close before its verified receipt arrives.
	await make();var id:String=await start("bottle");native.auto_receipt=false
	native.ad_event.emit(id,"receipt","verified_test_sdk");check(not app.game.rules.bonus_unlocked,"unsolicited receipt ignored")
	native.ad_event.emit(id,"earned","");native.ad_event.emit(id,"dismissed","");app._cancel_test_ad()
	check(not app.debug_ads.active_request().is_empty() and not app.game.rules.bonus_unlocked,"earned verification waits safely through Close")
	native.ad_event.emit(id,"receipt","verified_test_sdk");await process_frame
	check(app.game.rules.bonus_unlocked and native.consumes==1 and not app._ad_open,"delayed verified receipt grants once and restores")
	await dispose()
	FileAccess.open("res://native_reward_evidence/native_failure_batch.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"rows":failures_rows},"\t"));print("NATIVE_FAILURE_BATCH ",JSON.stringify({"checks":checks,"failures":failures,"cases":failures_rows.size()}));quit(0 if failures.is_empty() else 1)
