extends SceneTree
const Bootstrap=preload("res://scripts/playtest/energy_test_bootstrap.gd")
const Energy=preload("res://scripts/services/energy_service.gd")
var checks:Array=[]
var boot
var app
var fake_now:=100000
var memory:Dictionary={}
func _initialize()->void:call_deferred("run")
func check(id:String,passed:bool,detail:Variant=null)->void:
	checks.append({"id":id,"pass":passed,"detail":detail})
	print("ENERGY_CHECK ",JSON.stringify(checks[-1]))
func _read()->Dictionary:return {"ok":false,"reason":"missing"} if memory.is_empty() else {"ok":true,"data":memory.duplicate(true)}
func _write(value:Dictionary)->bool:memory=value.duplicate(true);return true
func run()->void:
	boot=Bootstrap.new();boot.profile_directory="res://../qa-private/profile-"+str(Time.get_ticks_usec());boot.enable_audio=false
	root.add_child(boot);await process_frame;await process_frame
	app=boot.app
	check("real_service_no_fake_clock",app.energy.get_script()==Energy and not app.energy.clock.is_valid())
	check("initial_30",app.energy.snapshot().energy==30)
	check("full_no_countdown",app.energy.snapshot().next_recovery_seconds==null)
	check("all50_unlock_only",app.progress.level_count==50 and app.progress.unlocked(49) and app.progress.data.completed.is_empty())
	app._menu_start(1);await process_frame
	var paid_id:String=app.attempt_id
	check("new_start_cost5",app.energy.snapshot().energy==25,app.energy.snapshot())
	check("real_countdown",int(app.energy.snapshot().next_recovery_seconds) in range(115,121))
	app.game.pause_game();app.game.request_restart();await process_frame
	var cancel=app.game.find_child("CancelRestart",true,false)
	check("cancel_restart_present",cancel!=null)
	if cancel!=null:cancel.pressed.emit()
	check("cancel_free_same_attempt",app.energy.snapshot().energy==25 and app.attempt_id==paid_id)
	app.game.request_restart();await process_frame
	var confirm=app.game.find_child("ConfirmRestart",true,false)
	check("confirm_restart_present",confirm!=null)
	if confirm!=null:confirm.pressed.emit()
	await process_frame
	check("confirmed_unfinished_restart_free",app.energy.snapshot().energy==25 and app.attempt_id==paid_id)
	app.show_home();app._menu_start(1);await process_frame
	check("return_continue_no_extra_charge",app.energy.snapshot().energy==25 and app.attempt_id==paid_id)
	app._show_game_energy();await process_frame
	check("in_game_energy_popup",is_instance_valid(app.energy_popup))
	app._close_game_energy();await process_frame
	check("energy_close_no_charge",app.energy.snapshot().energy==25 and not is_instance_valid(app.energy_popup))
	app.show_home();app._menu_start(2);await process_frame
	check("different_level_cost5",app.energy.snapshot().energy==20 and app.attempt_id!=paid_id)
	for index in [3,4,5,6]:
		app.show_home();app._menu_start(index);await process_frame
	check("six_starts_zero",app.energy.snapshot().energy==0)
	var before_id:String=app.attempt_id
	var before_pending:Dictionary=app.progress.data.pending_attempt.duplicate(true)
	app.show_home();app._menu_start(7);await process_frame
	check("insufficient_opens_popup",app.home.energy_open and app.home.visible and app.energy.snapshot().energy==0)
	check("insufficient_keeps_attempt",app.attempt_id==before_id and app.progress.data.pending_attempt==before_pending)
	var reloaded=Energy.new(Callable(),boot.energy_store.read,boot.energy_store.write)
	check("disk_reload_zero",reloaded.snapshot().energy==0)
	app.request_development_ad("energy");await process_frame
	check("mock_ad_open",is_instance_valid(app.ad_dialog) and app.debug_ads.provider_kind=="development_mock")
	app.ad_dialog.cancelled.emit();await process_frame
	check("ad_cancel_no_refill",app.energy.snapshot().energy==0 and not app._ad_open)
	boot.energy_store.fail_refill_save=true
	app.request_development_ad("energy");await process_frame
	app.ad_dialog.completed.emit();await process_frame
	check("failed_reward_write_retry_dialog",is_instance_valid(app.ad_dialog) and app.ad_dialog.retry_mode and app.energy.state.energy==0)
	check("failed_reward_stored_pending",not app.debug_ads.pending_operation().is_empty())
	boot.energy_store.fail_refill_save=false
	app.ad_dialog.retry_requested.emit();await process_frame
	check("retry_refills30",app.energy.snapshot().energy==30 and not app._ad_open)
	var ledger_count:int=app.energy.state.get("development_ad_receipts",{}).size()
	app.debug_ads.retry_pending();app.debug_ads.complete()
	check("duplicate_callbacks_no_reward",app.energy.snapshot().energy==30 and ledger_count==1 and app.energy.state.development_ad_receipts.size()==1)
	check("full_after_reward_no_countdown",app.energy.snapshot().next_recovery_seconds==null)
	var final_reload=Energy.new(Callable(),boot.energy_store.read,boot.energy_store.write)
	check("reward_durable_reload",final_reload.snapshot().energy==30 and final_reload.state.development_ad_receipts.size()==1)
	# Isolated unit clock only: entry above always used real OS wall time.
	var unit=Energy.new(func():return fake_now,_read,_write)
	unit.enter_attempt("clock-test")
	fake_now+=119;check("119s_no_tick",unit.snapshot().energy==25 and unit.snapshot().next_recovery_seconds==1)
	fake_now+=1;check("120s_one_tick",unit.snapshot().energy==26 and unit.snapshot().next_recovery_seconds==120)
	fake_now+=240
	var offline=Energy.new(func():return fake_now,_read,_write)
	check("offline_reload_two_ticks",offline.snapshot().energy==28)
	fake_now-=180;check("clock_rollback_no_gain",offline.snapshot().energy==28)
	fake_now+=1200;check("offline_cap30",offline.snapshot().energy==30 and offline.snapshot().next_recovery_seconds==null)
	check("same_entry_idempotent",offline.enter_attempt("clock-test").delta==0)
	offline.enter_attempt("win-test");check("new_id_cost5_unit",offline.snapshot().energy==25)
	check("win_refund5",offline.complete_attempt("win-test").delta==5 and offline.snapshot().energy==30)
	check("win_duplicate_no_refund",offline.complete_attempt("win-test").delta==0)
	var failed:int=checks.filter(func(x):return not x.pass).size()
	var f=FileAccess.open("res://../energy-qa-results.json",FileAccess.WRITE)
	f.store_string(JSON.stringify({"checks":checks,"failed":failed,"scope":"headless real AppShell signals + real disk storage; unit clock tests separately labelled; no GUI/MCP or SDK"},"\t"));f.close()
	print("ENERGY_QA_DONE ",checks.size()," CHECKS ",failed," FAIL")
	boot.queue_free();await process_frame;quit(1 if failed else 0)
