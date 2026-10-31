extends "res://tests/water_sort_orders/batch_a_parallel_host.gd"
const Orders=preload("res://scripts/water_sort/order_rules.gd")
var parallel_rows:Array=[]
func observed_drain()->Dictionary:
	var maximum:=0;var maximum_moving:=0;var starts:Dictionary={};var plans:Array=[]
	for tick in 2000:
		for tx in game.transactions:
			if not starts.has(str(tx.serial)) and tx.animator.phase not in ["waiting","route_wait"]:
				starts[str(tx.serial)]={"game_time":game.elapsed,"source":tx.source,"target":tx.target,"phase":tx.animator.phase,"route_delay":tx.animator.route_delay};plans.append(tx.animator.board_plan_ms)
		var moving:=0
		for tx in game.transactions:
			if tx.stage=="pour" and tx.animator.busy and tx.animator.phase not in ["waiting","route_wait"]:moving+=1
		maximum=maxi(maximum,game.transactions.size());maximum_moving=maxi(maximum_moving,moving)
		if not game._animation_busy() and game.presentation.input_queue.is_empty():break
		step(.01)
	check(not game._animation_busy() and game.presentation.input_queue.is_empty(),"new-layout bounded drain "+case_name)
	return {"max_transactions":maximum,"max_actual_moving":maximum_moving,"starts":starts,"plan_ms":plans,"end_game_time":game.elapsed}
func run()->void:
	check(DisplayServer.get_name()=="headless","silent only")
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):out=arg.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	root.content_scale_size=Vector2i(1080,1920);root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	app=Entry.instantiate();app.enable_audio=false;app.progress=progress_fixture("spacing-parallel",Catalog.V3);app.energy=energy_fixture();root.add_child(app);await process_frame;app.set_process(false);game=app.game;app._show_game();game.set_process(false)
	for dims in [Vector2i(320,480),Vector2i(390,844),Vector2i(430,932)]:
		root.size=dims;await process_frame
		for total in [5,10,15]:
			for mode in ["independent_adjacent","independent_cross","dependent_fifo"]:
				var bs:Array=[]
				for i in total:bs.append(["purple"])
				var pairs:Array=[]
				if mode=="dependent_fifo":
					bs[0]=["green","red"];bs[1]=[];bs[2]=["red"];bs[3]=["green"];pairs=[[0,1],[0,3],[2,0],[0,1]]
				else:
					var second_source:=3;var second_target:=4;var first_target:=1
					if mode=="independent_cross" and total>=10:first_target=5;second_source=4;second_target=9
					bs[0]=["red"];bs[first_target]=[];bs[second_source]=["blue"];bs[second_target]=[];pairs=[[0,first_target],[second_source,second_target]]
				var definition={"id":2,"bottles":bs,"orders":["yellow"]};load_case("%s_%d_%dx%d"%[mode,total,dims.x,dims.y],definition)
				var expected=Orders.new(definition)
				for index in pairs.size():
					var p:Array=pairs[index];await pair(p[0],p[1]);expected.pour(p[0],p[1])
					if index==0:step(.05)
				var metrics:=observed_drain()
				check(game.moves==pairs.size() and game.history.size()==pairs.size() and game.rules.snapshot()==expected.snapshot(),"exactly once target/order/result "+case_name)
				var executed:Array=[]
				for event in game.presentation.intent_trace:
					if event.event=="executed":executed.append([event.source,event.target])
				check(executed==pairs,"FIFO serial trace exact "+case_name)
				if mode=="independent_adjacent" and total>=10:check(metrics.max_actual_moving>=2,"original no-shared adjacent groups retain actual overlap "+case_name)
				parallel_rows.append({"case":case_name,"window":[dims.x,dims.y],"count":total,"mode":mode,"expected_pairs":pairs,"executed":executed,"metrics":metrics})
	check(collisions.is_empty(),"no moving bottle pair intersections")
	check(stream_collisions.is_empty() and parked_stream_hits.is_empty(),"no full-width stream/glass or wrong parked bottle intersections")
	check(fixed_target_failures.is_empty(),"receiving poses stay fixed while pouring")
	check(boundary_failures.is_empty(),"moving full body stays in window all sampled stages")
	var result={"checks":checks,"failures":failures,"cases":parallel_rows,"moving_collisions":collisions,"stream_collisions":stream_collisions,"parked_stream_hits":parked_stream_hits,"parked_projection_overlaps":parked_overlaps,"fixed_target_failures":fixed_target_failures,"boundary_failures":boundary_failures,"scope":"New five-column counts5/10/15 at3windows; actual native viewport clicks, real independent adjacent/cross routes and repeated shared-bottle FIFO. Max moving excludes waiting/route_wait;10ms full-path samples. Foreground intentional static 2D projection overlaps reported separately, not silently classified as physical collision."}
	FileAccess.open(out+"/result.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"));print("SPACING_PARALLEL ",JSON.stringify({"checks":checks,"cases":parallel_rows.size(),"failures":failures,"moving_collisions":collisions.size(),"stream_hits":stream_collisions.size()+parked_stream_hits.size(),"boundary":boundary_failures.size()}));app.debug_ads.shutdown();app.free();quit(0 if failures.is_empty() else 1)
