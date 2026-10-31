extends "res://tests/water_sort_campaign50/memory_fixture.gd"
const Entry=preload("res://scenes/water_sort/orders_v3.tscn")
const Router=preload("res://scripts/water_sort/reward_controller.gd")
class Native:
	extends RefCounted
	signal ad_event(id:String,state:String,detail:String)
	var initialized:=0
	var loads:=0
	var shows:Array=[]
	var consumes:=0
	var consent:=true
	var privacy:=false
	var privacy_shows:=0
	var auto_receipt:=true
	func initialize():
		initialized+=1
		ad_event.emit("","initialized" if consent else "unavailable","" if consent else "consent_required")
	func load():
		loads+=1;ad_event.emit("","loaded" if consent else "unavailable","")
	func show(id):shows.append(id);ad_event.emit(id,"shown","")
	func consume(id):
		consumes+=1
		if auto_receipt:ad_event.emit(id,"receipt","verified_test_sdk")
	func invalidate(_id):pass
	func showPrivacyOptions():privacy_shows+=1;ad_event.emit("","privacy_changed","")
	func privacyOptionsRequired():return privacy
	func complete(id):ad_event.emit(id,"earned","");ad_event.emit(id,"dismissed","")
var app
var native
var now:=1000
var rows:Array=[]
func make(configure:Callable=Callable())->void:
	reset_memory();native=Native.new()
	if configure.is_valid():configure.call(native)
	app=Entry.instantiate();app.enable_audio=false;app.progress=progress_fixture("native-host",Catalog.V3);app.energy=energy_fixture()
	app.ad_controller_factory=func(owner):return Router.new(owner,func():return now,"google_test",native)
	root.add_child(app);await process_frame;app.set_process(false);app.game.set_process(false)
	var levels:Array=app.game.levels.duplicate(true);levels[1]={"id":2,"capacity":4,"bottles":[["red","blue","red","blue"],["blue","red","blue","red"],[],[]],"orders":["red","blue"],"bonus_bottle":true}
	app.game.levels=levels;app.progress.bind_level_pack(levels);app.progress.data.completed=[1]
	for mechanic in ["covered_lock_v1","unknown_layers_v1","any_order_lock_v1"]:app.progress.acknowledge_mechanic(mechanic)
	app._menu_start(1);app.game.set_process(false)
func drain()->void:
	for i in 3000:
		if not app.game._animation_busy():break
		app.game._process(.01)
func dispose()->void:
	app.debug_ads.shutdown();app.free();await process_frame
func run()->void:
	root.content_scale_size=Vector2i(1080,1920);root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS;root.size=Vector2i(390,844)
	for placement in ["bottle","slot","energy","undo"]:
		await make()
		if placement=="undo":app.game.select_bottle(0);app.game.select_bottle(2);drain()
		var before:Dictionary=app.game.rules.snapshot();var old_energy:int=app.energy.state.energy;var old_moves:int=app.game.moves
		var result:Dictionary=app.debug_ads.begin(placement);check(result.ok,"native begin "+placement);await process_frame
		check(native.shows.size()==1 and is_instance_valid(app.ad_dialog) and not app.ad_dialog.buttons.has("AdCompleted"),"actual native port and no Mock completed UI "+placement)
		var id:String=app.debug_ads.active_request().get("request_id","")
		check(id.begins_with("google_test:"),"native receipt namespace "+placement)
		native.complete(id);await process_frame
		check(app.debug_ads.pending_operation().is_empty() and not app._ad_open,"native durable terminal restores overlay "+placement)
		if placement in ["bottle","slot"]:check(app.game.rules.bonus_unlocked if placement=="bottle" else app.game.rules.slot_unlocked,"actual bonus granted "+placement)
		elif placement=="energy":check(app.energy.state.energy==30 and app.energy.state.native_ad_receipts.has(id),"actual energy and receipt persisted")
		else:check(app.game.moves==old_moves-1 and app.game.rules.snapshot()!=before,"actual earned undo")
		var saved:String=JSON.stringify(memory.progress);var energy_saved:String=JSON.stringify(memory.energy)
		native.complete(id);native.ad_event.emit(id,"receipt","verified_test_sdk");await process_frame
		check(JSON.stringify(memory.progress)==saved and JSON.stringify(memory.energy)==energy_saved and native.consumes==1,"duplicate native events cannot regrant "+placement)
		rows.append({"placement":placement,"id":id,"shows":native.shows.size(),"consumes":native.consumes});await dispose()
	FileAccess.open("res://native_reward_evidence/native_host_smoke.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"rows":rows},"\t"));print("NATIVE_HOST_SMOKE ",JSON.stringify({"checks":checks,"failures":failures}));quit(0 if failures.is_empty() else 1)
