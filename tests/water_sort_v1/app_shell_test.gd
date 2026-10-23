extends SceneTree
const Progress = preload("res://scripts/water_sort/progress.gd")
const Energy = preload("res://scripts/services/energy_service.gd")
const App = preload("res://scripts/water_sort/app_shell.gd")
var checks := 0
var failures: Array = []
var memory := {"progress":{},"energy":{},"now":1000,"fail":false,"fail_energy":false}
var app
func _initialize() -> void: call_deferred("run")
func check(value: bool,label: String) -> void:
	checks += 1
	if not value: failures.append(label); push_error(label)
func progress_fixture():
	return Progress.new(func(): return {"ok":false,"reason":"missing"} if memory.progress.is_empty() else {"ok":true,"data":memory.progress.duplicate(true)},func(value):
		if memory.fail: return false
		memory.progress = value.duplicate(true); return true)
func energy_fixture():
	return Energy.new(func(): return memory.now,func(): return {"ok":false,"reason":"missing"} if memory.energy.is_empty() else {"ok":true,"data":memory.energy.duplicate(true)},func(value):
		if memory.fail_energy: return false
		memory.energy = value.duplicate(true); return true)
func make_app():
	var node = App.new()
	node.progress = progress_fixture(); node.progress.load_progress()
	node.energy = energy_fixture(); node.enable_audio = false
	root.add_child(node)
	return node
func click(node: Control) -> void:
	await process_frame
	var point: Vector2 = node.get_global_transform_with_canvas()*(node.size*0.5)
	for pressed in [true,false]:
		var event := InputEventMouseButton.new(); event.position = point; event.global_position = point; event.button_index = MOUSE_BUTTON_LEFT; event.pressed = pressed
		root.push_input(event,true); await process_frame
func solve_first() -> void:
	for action in [[0,2],[1,0],[1,2]]:
		await click(app.game.bottle_nodes[action[0]])
		await click(app.game.bottle_nodes[action[1]])
		await settle()
func settle() -> void:
	for _frame in range(150):
		if not app.game._animation_busy(): break
		await create_timer(0.02).timeout
	await process_frame
	if app.game._animation_busy(): failures.append("glass and cork transaction exceeded bounded settle time")
func run() -> void:
	root.size=Vector2i(540,960)
	app = make_app(); await process_frame
	check(app.home.visible and not app.game.visible,"starts at real home")
	check(app.progress.level_count==5 and app.progress.unlocked(0) and not app.progress.unlocked(1),"only first of five levels initially unlocked")
	check(app.energy.snapshot().energy==30,"new water sort energy is 30")
	await click(app.home.buttons.home_levels)
	check(app.home.page=="levels" and app.home.buttons.level_2.disabled,"selection locks future levels")
	check(app.home.label_nodes.best_0.text.contains("尚未通关"),"no fake personal records")
	await click(app.home.buttons.back)
	await click(app.home.buttons.home_start)
	check(app.game.visible and app.game.state=="playing" and app.energy.snapshot().energy==25,"start buys one attempt before play")
	check(app.game_energy_label.text=="25/30","game HUD shows authoritative charged balance")
	var game_energy_rect: Rect2 = app.game_energy_badge.get_global_transform_with_canvas()*Rect2(24,30.81,262,82.38)
	check(game_energy_rect.is_equal_approx(app.home.energy_rect_canvas()),"game and menu energy artwork occupy the exact same screen rectangle")
	await click(app.game_energy_badge.get_node("OpenEnergy"))
	check(is_instance_valid(app.energy_popup) and app.game.state=="paused","in-game energy opens real modal and freezes game")
	var popup_seconds: float=app.game.elapsed
	await create_timer(0.05).timeout
	check(app.game.elapsed==popup_seconds,"energy modal does not consume solve time")
	await click(app.energy_popup.buttons.energy_later)
	check(not is_instance_valid(app.energy_popup) and app.game.state=="playing" and app.energy.snapshot().energy==25,"closing energy resumes same paid attempt")
	var first_id: String = app.attempt_id
	await click(app.game.bottle_nodes[0]); await click(app.game.bottle_nodes[2]); await settle()
	check(app.game.moves==1,"gameplay mutates real puzzle")
	var snapshot: Dictionary = app.game.rules.snapshot()
	await click(app.game.buttons.Instructions)
	check(app.home.visible and app.home.resume_index==0 and app.game.state=="paused","home preserves paid attempt")
	var seconds: float = app.game.elapsed
	await create_timer(0.05).timeout
	check(app.game.elapsed==seconds,"home pauses timer")
	await click(app.home.buttons.home_settings)
	await click(app.home.buttons.music_toggle_row)
	check(not app.progress.data.music,"settings change durable water sort preference")
	await click(app.home.buttons.how_to_play)
	check(app.home.notice_title=="玩法说明" and app.home.label_nodes.rules_body.autowrap_mode==TextServer.AUTOWRAP_WORD_SMART,"rules use dedicated readable wrapping panel")
	await click(app.home.buttons.rules_close)
	check(app.home.settings_open and app.home.buttons.has("close_settings"),"rules dismiss returns to settings rather than starting a game")
	app.home._settings_action("language_en")
	check(app.progress.data.locale=="en" and app.game.locale=="en","language preference reaches native game")
	await click(app.home.buttons.close_settings)
	await click(app.home.buttons.home_start)
	check(app.game.rules.snapshot()==snapshot and app.game.moves==1 and app.energy.snapshot().energy==25 and app.attempt_id==first_id,"resume preserves board, moves and single energy charge")
	await click(app.game.buttons.Restart); await click(app.game.buttons.ConfirmRestart)
	check(app.game.moves==0 and app.attempt_id==first_id and app.energy.snapshot().energy==25,"unfinished restart is same paid attempt")
	await solve_first()
	check(app.game.state=="won" and app.progress.completed(0) and app.progress.unlocked(1),"real solution saves completion and unlocks next")
	check(app.energy.snapshot().energy==30,"first victory refunds exactly five")
	check(app.progress.best_record(0).moves==3,"real three-move record saved")
	var record: Dictionary = app.progress.best_record(0)
	app.game._finish_pour(); app.game._finish_pour()
	check(app.energy.state.serial==2 and app.progress.best_record(0)==record,"duplicate victory cannot reward twice")
	await click(app.game.buttons.ResultRestart)
	check(app.attempt_id!=first_id and app.energy.snapshot().energy==25 and app.game.moves==0,"replaying a won level creates exactly one new paid attempt")
	await solve_first()
	await click(app.game.buttons.Next)
	check(app.game.level_index==1 and app.energy.snapshot().energy==25,"next level uses unlocked second stage and charges entry")
	var legal: Dictionary=app.game.rules.available_moves(app.game.rules.snapshot())[0]
	await click(app.game.bottle_nodes[legal.from]); await click(app.game.bottle_nodes[legal.to]); await settle()
	check(app.game.moves==1,"second level checkpoint contains actual gameplay, not initial board only")
	await click(app.game.buttons.Instructions)
	var pending_id: String=app.attempt_id
	var pending_board: Dictionary=app.game.rules.snapshot()
	app.queue_free(); await process_frame
	app = make_app(); await process_frame
	check(app.progress.completed(0) and not app.progress.data.music,"relaunch restores water sort completion and settings")
	await click(app.home.buttons.home_start)
	check(app.game.level_index==1 and app.attempt_id==pending_id and app.game.rules.snapshot()==pending_board and app.energy.snapshot().energy==25,"relaunch resumes paid checkpoint without second charge")
	check(app.game.moves==1 and app.game.locale=="en","relaunch restores move count and locale")
	var protected_id: String=app.attempt_id
	var protected_snapshot: Dictionary=app.game.rules.snapshot()
	var protected_pending: Dictionary=app.progress.data.pending_attempt.duplicate(true)
	app.energy.state.energy=0
	app._start_level(0)
	check(app.attempt_id==protected_id and app.progress.data.pending_attempt.snapshot==protected_pending.snapshot and app.game.rules.snapshot()==protected_snapshot,"insufficient energy cannot discard another paid puzzle")
	check(app.home.energy_open,"insufficient energy explains natural recovery without fake ads")
	app._menu_start(1)
	check(app.game.visible and app.energy.state.energy==0 and app.attempt_id==protected_id,"zero-energy player can still resume an already-paid attempt")
	app.energy.state.energy=25
	memory.fail_energy=true
	app._start_level(0)
	check(app.attempt_id==protected_id and app.game.rules.snapshot()==protected_snapshot and app.energy.state.energy==25,"failed energy write preserves previous paid board and balance")
	memory.fail_energy=false
	app.home.notice_message=""; app.home.notice_title=""
	app.show_home()
	memory.now+=120
	app._refresh_energy()
	check(app.energy.snapshot().energy==26,"energy regenerates one each 120 seconds")
	# Pure progress tests verify score pair semantics and failed-write rollback.
	var p = progress_fixture(); p.bind_level_pack(app.game.levels); p.load_progress()
	var id: String=p.reserve_attempt(0)
	check(p.record_result(0,2,90.0,id),"record accepts fewer moves with slower time")
	check(p.best_record(0).moves==2 and p.best_record(0).seconds==90.0,"never mixes fastest time from a different run")
	id=p.reserve_attempt(0); p.record_result(0,3,1.0,id)
	check(p.best_record(0).moves==2 and p.best_record(0).seconds==90.0,"faster higher-move result does not replace best")
	id=p.reserve_attempt(0); p.record_result(0,2,60.0,id)
	check(p.best_record(0).moves==2 and p.best_record(0).seconds==60.0,"tie uses faster paired run")
	var before: Dictionary=p.data.duplicate(true)
	memory.fail=true
	check(p.reserve_attempt(0)=="" and p.data==before,"failed write rolls back attempt reservation")
	memory.fail=false
	check(app.home.errors.is_empty(),"all reused menu assets loaded")
	var invalid=Progress.new(func(): return {"ok":true,"data":{"schema":2,"campaign":"lane_campaign100"}},func(_value): failures.append("must not overwrite incompatible save"); return false)
	invalid.load_progress()
	check(not invalid.persistent and not invalid.save_progress(),"incompatible save is preserved, not overwritten")
	check(Progress.WATER_FILE!="campaign_progress_lane100_v1.json" and App.ENERGY_FILE!="energy.json","water sort never addresses cargo filenames")
	# End-to-end every shipped level through actual view signals and UI clicks.
	app.queue_free(); await process_frame
	memory = {"progress":{},"energy":{},"now":2000,"fail":false,"fail_energy":false}
	app=make_app(); await process_frame
	var proofs: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/water_sort_v1/proofs.json"))
	await click(app.home.buttons.home_start)
	for level in range(5):
		check(app.game.level_index==level and app.energy.snapshot().energy==25,"campaign entry %d charges exactly five" % (level+1))
		for action in proofs.levels[level].shortest_solution:
			await click(app.game.bottle_nodes[int(action[0])]); await click(app.game.bottle_nodes[int(action[1])]); await settle()
		check(app.game.state=="won" and app.progress.completed(level) and app.energy.snapshot().energy==30,"campaign level %d wins, saves and rewards" % (level+1))
		check(app.progress.best_record(level).moves==int(proofs.levels[level].shortest_moves),"campaign level %d stores verified real moves" % (level+1))
		if level<4: await click(app.game.buttons.Next)
	check(app.progress.data.completed.size()==5 and app.progress.data.settlements.size()==5 and app.energy.state.serial==10,"five levels create exactly five entries and five rewards")
	check(app.game.buttons.has("ReplayAll") and not app.game.buttons.has("Next"),"final level has honest finished campaign state")
	await click(app.game.buttons.ResultInstructions)
	await click(app.home.buttons.home_levels)
	check(not app.home.buttons.level_5.disabled and app.home.label_nodes.best_4.text.contains("15"),"final home selection retains all unlocks and actual records")
	await click(app.home.buttons.level_5)
	check(app.game.level_index==4 and app.game.state=="playing" and app.energy.state.energy==25,"all-complete campaign remains replayable from selection")
	print(JSON.stringify({"status":"passed" if failures.is_empty() else "failed","checks":checks,"failures":failures,"storage":"all memory fixtures; no user progress touched"}))
	app.queue_free(); await process_frame
	quit(0 if failures.is_empty() else 1)
