extends "res://tests/water_sort_v1/app_shell_test.gd"
func settle_visuals() -> void:
	for _frame in range(150):
		if not app.game._animation_busy(): break
		app.game._process(0.02)
	if app.game._animation_busy(): failures.append("visual transaction did not finish including cork")
func run() -> void:
	root.size=Vector2i(540,960)
	app=make_app();await process_frame
	for index in range(3):
		var decoration=app.home.board.find_child("HomeBottle"+str(index),true,false)
		check(decoration is Node2D and decoration.get_script().resource_path=="res://scripts/water_sort/art/bottle_visual.gd","home bottle uses same glass component without input surface")
	await click(app.home.buttons.home_start);app.game.set_process(false)
	var paid: String=app.attempt_id
	await click(app.game.bottle_nodes[0]);await click(app.game.bottle_nodes[2]);app.game._process(0.42)
	var middle: Vector2=app.game.bottle_nodes[0].visual.global_position
	var middle_volume: float=app.game.bottle_nodes[0].visual.volume()
	await click(app.game_energy_badge.get_node("OpenEnergy"))
	var seconds: float=app.game.elapsed
	await create_timer(0.08).timeout
	check(app.game.state=="paused" and app.game.animator.busy and app.game.elapsed==seconds,"energy popup freezes active transaction and timer")
	check(app.game.bottle_nodes[0].visual.global_position.is_equal_approx(middle) and is_equal_approx(app.game.bottle_nodes[0].visual.volume(),middle_volume),"energy popup does not reset tilted glass or partial liquid")
	await click(app.energy_popup.buttons.energy_later)
	check(app.game.state=="playing" and app.attempt_id==paid and app.energy.state.energy==25,"closing energy resumes same paid moving transaction")
	app.game._process(0.42)
	await click(app.game.bottle_nodes[1]);await click(app.game.bottle_nodes[0]);app.game._process(0.42)
	var after: Dictionary=app.game.rules.snapshot()
	app.show_home()
	check(app.home.visible and app.game.state=="paused" and not app.game.animator.busy,"direct app Home settles active animation before hiding view")
	check(app.progress.data.pending_attempt.snapshot==after and app.game.moves==2 and app.energy.state.energy==25,"checkpoint stores committed after-state without charge or loss")
	await click(app.home.buttons.home_start)
	check(app.attempt_id==paid and app.game.rules.snapshot()==after and app.game.state=="playing" and app.energy.state.energy==25,"same paid checkpoint resumes without another debit")
	await click(app.game.bottle_nodes[1]);await click(app.game.bottle_nodes[2]);app.game._process(0.42)
	check(app.game.rules.is_solved() and app.game.animator.busy and not app.progress.completed(0),"last move is committed but has not prematurely rewarded during animation")
	app.show_home()
	check(app.game.state=="won" and app.progress.completed(0) and app.energy.state.energy==30,"direct Home during last pour settles real win and refunds once")
	check(app.progress.best_record(0).moves==3 and app.energy.state.serial==2,"settled record and energy entry/reward are paired exactly once")
	app.show_home();app.game.prepare_to_leave()
	check(app.energy.state.serial==2 and app.progress.data.settlements.size()==1,"repeated Home cannot duplicate settlement")
	await click(app.home.buttons.home_start);app.game.set_process(false)
	check(app.game.level_index==1 and app.energy.state.energy==25 and app.attempt_id!=paid,"next home start is a new paid unlocked level")
	var second_paid: String=app.attempt_id
	await click(app.game.bottle_nodes[0]);await click(app.game.bottle_nodes[3]);app.game._process(0.42)
	var saved: Dictionary=app.game.rules.snapshot()
	app._checkpoint();app.queue_free();await process_frame;await process_frame
	app=make_app();await process_frame;await click(app.home.buttons.home_start)
	check(app.attempt_id==second_paid and app.game.rules.snapshot()==saved and app.game.moves==1,"relaunch after interrupted animation restores committed snapshot")
	check(not app.game.animator.busy and app.energy.state.energy==25 and app.energy.state.serial==3,"relaunch starts settled visuals and never repeats entry cost")
	# Simulate closing after the logical winning move but before its animation completes.
	app.queue_free();await process_frame
	memory={"progress":{},"energy":{},"now":2000,"fail":false,"fail_energy":false}
	app=make_app();await process_frame;await click(app.home.buttons.home_start);app.game.set_process(false)
	for action in [[0,2],[1,0]]:
		await click(app.game.bottle_nodes[action[0]]);await click(app.game.bottle_nodes[action[1]]);settle_visuals()
	await click(app.game.bottle_nodes[1]);await click(app.game.bottle_nodes[2]);app.game._process(0.42)
	app._checkpoint();app.queue_free();await process_frame;await process_frame
	app=make_app();await process_frame;await click(app.home.buttons.home_start)
	check(app.game.state=="won" and app.progress.completed(0) and app.energy.state.energy==30 and not app.game.animator.busy,"relaunch after interrupted winning pour settles saved win and refund")
	app.game._finish_pour();app.show_home()
	check(app.energy.state.serial==2 and app.progress.data.settlements.size()==1 and app.progress.best_record(0).moves==3,"restored win cannot be settled or rewarded twice")
	print("WATER_SORT_APP_ANIMATION ",JSON.stringify({"checks":checks,"failures":failures,"passed":failures.is_empty(),"storage":"memory fixtures"}))
	app.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
