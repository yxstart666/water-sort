extends "res://tests/water_sort_orders/native_reward_host_smoke.gd"
const Factory=preload("res://scripts/services/ad_provider_factory.gd")
const Receipt=preload("res://scripts/services/native_reward_receipt.gd")
func save_fingerprint()->String:return JSON.stringify([memory.progress,memory.energy])
func run()->void:
	check(DisplayServer.get_name()=="headless","silent test only")
	root.content_scale_size=Vector2i(1080,1920);root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS;root.size=Vector2i(390,844)
	await make(func(api):api.consent=false)
	check(native.initialized==1 and native.loads==0 and not app.debug_ads.can_begin("bottle"),"consent denial never loads/shows or enables reward")
	var before:=save_fingerprint();var result:Dictionary=app._begin_development_ad("bottle");await process_frame
	check(not result.ok and native.shows.is_empty() and save_fingerprint()==before,"denied consent cannot award or show")
	check(app._ad_open and not app.ad_dialog.buttons.has("AdCompleted"),"denied status is closable and never mock completion")
	await click_ui(app.ad_dialog.buttons.NativeAdCancel)
	check(not app._ad_open and app.game.state=="playing","denied status Back restores game")
	await dispose()
	await make()
	ProjectSettings.set_setting("development/mock_ads_enabled",true)
	var absent=Factory.create_controller(app,"Android")
	check(absent.is_native() and not absent.is_enabled() and not absent.begin("bottle").ok,"Android with missing singleton fails closed even when Mock flag true")
	absent.shutdown();ProjectSettings.set_setting("development/mock_ads_enabled",false)
	before=save_fingerprint()
	var forged={"request_id":"google_test:forged:1","placement":"energy","attempt_id":"fake","context_id":"fake","source":"google_test_sdk","outcome":"completed","reason":"verified_test_sdk"}
	check(not app.energy.stage_native_refill(forged,null) and not app.energy.commit_native_refill(forged,app.debug_ads).accepted,"forged native dictionary cannot refill")
	check(not app.progress.commit_native_ad_reward(forged,app.debug_ads).ok,"forged native dictionary cannot mutate board")
	for key in forged:
		var broken:Dictionary=forged.duplicate(true);broken[key]=false;check(not Receipt.valid(broken),"reject malformed identity "+key)
	check(save_fingerprint()==before,"forgery checks write no state")
	result=app.debug_ads.begin("bottle");check(result.ok,"real owned request begins")
	check(not app.debug_ads.begin("slot").ok and not app.debug_ads.complete().ok,"double request and manual completion denied")
	await process_frame;var id:String=app.debug_ads.active_request().request_id
	var spoof:Dictionary=forged.duplicate(true);spoof.request_id=id
	app.debug_ads.adapter.result_ready.emit(spoof);app.debug_ads.adapter.inner.result_ready.emit(spoof)
	check(not app.game.rules.bonus_unlocked and not app.debug_ads.active_request().is_empty(),"untrusted signals cannot substitute owned one-use receipt")
	native.ad_event.emit(id,"receipt","verified_test_sdk");native.ad_event.emit(id,"earned","")
	check(not app.game.rules.bonus_unlocked,"earned alone still waits for dismissal")
	native.ad_event.emit(id,"dismissed","");await process_frame
	check(app.game.rules.bonus_unlocked and native.consumes==1,"legitimate earned/receipt/dismissed grants once")
	await dispose()
	# A native readiness change during the real shuffle worker must terminate the
	# preparing overlay, not leave it waiting after begin() refused to show.
	await make();app.debug_ads.rearrangement_seed=20261030
	result=app.debug_ads.begin("shuffle");check(result.ok,"real asynchronous solvability preparation begins")
	native.ad_event.emit("","load_failed","3")
	for i in 300:
		await process_frame;app.debug_ads.poll()
		if not app.debug_ads.active_request().get("preparing",false):break
	await process_frame
	check(native.shows.is_empty() and app.debug_ads.active_request().is_empty(),"lost readiness after shuffle preparation never shows or strands request")
	check(app._ad_open and app.ad_dialog.buttons.has("NativeAdCancel"),"failed asynchronous begin surfaces closable native status")
	app._cancel_test_ad();check(not app._ad_open and app.game.state=="playing","shuffle readiness failure restores input")
	await dispose()
	# Privacy visibility is UMP supplied, never guessed from language or location.
	for locale in ["zh","en"]:
		for size in [Vector2i(320,480),Vector2i(390,844),Vector2i(430,932)]:
			root.size=size;await process_frame;await make(func(api):api.privacy=true)
			app.progress.data.locale=locale;app.show_home();await process_frame
			check(app.home.buttons.has("privacy_options"),"required privacy action visible "+locale+str(size))
			var button=app.home.buttons.get("privacy_options")
			if button!=null:
				await click_ui(button)
				check(native.privacy_shows==1 and native.loads==2,"privacy callback reloads after choice form "+locale+str(size))
				native.privacy=false;native.ad_event.emit("","privacy_changed","");await process_frame
				check(not app.home.buttons.has("privacy_options"),"no residual privacy target when UMP not required "+locale+str(size))
			await dispose()
	# Save-only callbacks from an obsolete status View cannot close a new View.
	await make();app._show_native_ad_status("bottle");var old=app.ad_dialog
	app._show_native_ad_status("slot");var current=app.ad_dialog;old.cancelled.emit();old.retry_requested.emit();old.privacy_requested.emit()
	check(app.ad_dialog==current and native.shows.is_empty(),"old dialog callbacks cannot act on a new native status")
	app._cancel_test_ad();await dispose()
	FileAccess.open("res://native_reward_evidence/native_negative_batch.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures},"\t"))
	print("NATIVE_NEGATIVE_BATCH ",JSON.stringify({"checks":checks,"failures":failures}));quit(0 if failures.is_empty() else 1)
