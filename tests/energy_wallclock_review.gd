extends SceneTree
const Bootstrap=preload("res://scripts/playtest/energy_test_bootstrap.gd")
const Energy=preload("res://scripts/services/energy_service.gd")
var checks:Array=[]
var samples:Array=[]
var boot
var started:int
func _initialize()->void:call_deferred("run")
func check(id:String,ok:bool,detail:Variant=null)->void:
	checks.append({"id":id,"pass":ok,"detail":detail})
	print("REAL_CLOCK_CHECK ",JSON.stringify(checks[-1]))
func save(stage:String)->void:
	var data={"stage":stage,"elapsed_monotonic_seconds":(Time.get_ticks_msec()-started)/1000.0,"wall_unix":Time.get_unix_time_from_system(),"checks":checks,"samples":samples,"injected_clock":false,"real_sdk":false,"headless":true}
	FileAccess.open("res://closeout_evidence/energy_wallclock.json",FileAccess.WRITE).store_string(JSON.stringify(data,"\t"))
func run()->void:
	Engine.max_fps=30
	boot=Bootstrap.new();boot.profile_directory="res://qa-private/real-wallclock";boot.enable_audio=false
	root.add_child(boot);await process_frame;await process_frame
	var app=boot.app
	check("real_service_and_system_clock",app.energy.get_script()==Energy and not app.energy.clock.is_valid())
	app._menu_start(1);await process_frame
	started=Time.get_ticks_msec()
	check("start_cost_5",app.energy.snapshot().energy==25)
	app._show_game_energy();await process_frame;await process_frame
	check("popup_pauses_game",is_instance_valid(app.energy_popup) and app.game.process_mode==Node.PROCESS_MODE_DISABLED)
	var popup_id:int=app.energy_popup.get_instance_id()
	var checkpoints:Array=[0,30,60,90,115,123]
	for seconds in checkpoints:
		var remaining:float=float(seconds)-(Time.get_ticks_msec()-started)/1000.0
		if remaining>0:await create_timer(remaining).timeout
		var snapshot:Dictionary=app.energy.snapshot()
		var view=app.energy_popup.find_child("ApprovedEnergyPopup",true,false)
		var row={"elapsed_monotonic_seconds":(Time.get_ticks_msec()-started)/1000.0,"wall_unix":Time.get_unix_time_from_system(),"energy":snapshot.energy,"countdown":snapshot.next_recovery_seconds,"same_popup":app.energy_popup.get_instance_id()==popup_id,"model":view.model.duplicate(true) if is_instance_valid(view) else {}}
		samples.append(row);print("REAL_CLOCK_SAMPLE ",JSON.stringify(row));save("waiting" if seconds<123 else "elapsed")
		if seconds<=115:check("no_early_gain_"+str(seconds),snapshot.energy==25)
	check("real_elapsed_at_least_120",Time.get_ticks_msec()-started>=120000)
	check("exactly_one_real_tick",app.energy.snapshot().energy==26)
	await create_timer(1.2).timeout
	var popup_view=app.energy_popup.find_child("ApprovedEnergyPopup",true,false)
	check("live_popup_reflects26",is_instance_valid(popup_view) and str(popup_view.model.get("capacity","")).replace(" ","")=="26/30",popup_view.model if is_instance_valid(popup_view) else {})
	var reload=Energy.new(Callable(),boot.energy_store.read,boot.energy_store.write)
	check("recovery_saved_on_disk",reload.snapshot().energy==26)
	app._close_game_energy();await process_frame;await process_frame
	check("close_restores_playing",not is_instance_valid(app.energy_popup) and app.game.process_mode==Node.PROCESS_MODE_INHERIT and app.game.state=="playing")
	app._show_game_energy();await process_frame;app._close_game_energy();await process_frame
	check("reopen_close_no_extra_tick",app.energy.snapshot().energy==26 and app.game.state=="playing")
	var failed:int=checks.filter(func(x):return not x.pass).size()
	save("passed" if failed==0 else "failed")
	print("REAL_CLOCK_DONE ",JSON.stringify({"checks":checks.size(),"failures":failed,"elapsed_seconds":(Time.get_ticks_msec()-started)/1000.0}))
	app.debug_ads.shutdown();boot.free();await process_frame;quit(0 if failed==0 else 1)
