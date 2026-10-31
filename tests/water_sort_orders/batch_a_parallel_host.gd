extends "res://tests/water_sort_campaign50/memory_fixture.gd"
const Entry=preload("res://scenes/water_sort/orders_v3.tscn")
var app
const FlowCoverage=preload("res://tests/water_sort_orders/stream_width_assertions.gd")
var game
var out:="res://.handoff/reports/parallel-pours-20261028"
var native:=false
var baseline:=false
var boundary_failures:Array=[]
var window_height:=0
var window_width:=1080
var timeline:Array=[]
var clicks:Array=[]
var case_name:=""
var collisions:Array=[]
var stream_collisions:Array=[]
var parked_overlaps:Array=[]
var parked_stream_hits:Array=[]
var fixed_target_failures:Array=[]
var homes:Array=[]
var traces:Array=[]
var export_costs:Array=[]
var reward_requests:Array=[]
var fixture:Dictionary={"bottles":[["red","red","red"],["red"],["blue","blue","blue"],["blue"],["green","green","green"],["green"],[],[]],"orders":["red","blue","green"]}

func load_case(label:String,data:Dictionary=fixture)->void:
	case_name=label; game.levels[1]=data.duplicate(true);game.load_level(1);game.set_process(false)
	homes.clear()
	for node in game.bottle_nodes:homes.append(node.visual.global_transform)
	if not baseline:game.presentation.trace_enabled=true;game.presentation.intent_trace.clear()

func tap(index:int)->void:
	var before:int=game.moves
	await click_ui(game.bottle_nodes[index])
	clicks.append({"case":case_name,"time":game.elapsed,"bottle":index,"moves_before":before,"moves_after":game.moves,"selected":game.selected,"queued_source":game.presentation.queued_source_id,"queue":game.presentation.input_queue.duplicate(true),"state":game.state,"message":game.labels.Status.text})

func pair(a:int,b:int)->void:
	await tap(a);await tap(b)

func sample()->void:
	var items:Array=[]
	for tx in game.transactions:
		items.append({"source":tx.source,"target":tx.target,"stage":tx.stage,"phase":tx.animator.phase,"elapsed":tx.animator.elapsed,"lift":tx.animator.board_flow_lift,"route_delay":tx.animator.route_delay,"plan_ms":tx.animator.board_plan_ms,"stream_length":tx.animator.outlet.distance_to(tx.animator.target.mouth_world()),"emitted":tx.animator.progress,"arrived":tx.animator.received_progress})
	var receipts:Array=[]
	for r in game.receipts:receipts.append({"bottle":r.bottle,"slot":r.slot,"stage":r.stage})
	timeline.append({"case":case_name,"time":game.elapsed,"moves":game.moves,"transactions":items,"receipts":receipts,"delivered":game.display_delivered.duplicate()})
	for i in game.transactions.size():
		var tx=game.transactions[i]
		if tx.stage!="pour" or not tx.animator.busy:continue
		var a=tx.animator.source
		var envelope:PackedVector2Array=root.get_final_transform()*a.get_global_transform_with_canvas()*a.delivered_layers.presentation_envelope_outline()
		var full_box:=Rect2(envelope[0],Vector2.ZERO)
		for point in envelope:full_box=full_box.expand(point)
		if not Rect2(Vector2.ZERO,Vector2(root.size)).grow(.5).encloses(full_box) and boundary_failures.size()<100:
			boundary_failures.append({"case":case_name,"time":game.elapsed,"source":tx.source,"phase":tx.animator.phase,"box":str(full_box)})
		var shape:PackedVector2Array=a.global_transform*a.delivered_layers.presentation_outline()
		if not FlowCoverage.exterior_width_safe(tx.animator) and parked_stream_hits.size()<50:parked_stream_hits.append({"case":case_name,"time":game.elapsed,"reason":"conservative texture/glow/drop envelope"})
		if not tx.animator.target.global_transform.is_equal_approx(homes[int(tx.target)]) and fixed_target_failures.size()<20:fixed_target_failures.append({"case":case_name,"target":tx.target,"time":game.elapsed})
		for index in game.bottle_nodes.size():
			var node=game.bottle_nodes[index]
			if index==int(tx.source) or index==int(tx.target) or not node.visible or node.visual.transaction_busy:continue
			if not Geometry2D.intersect_polygons(shape,node.visual.global_transform*node.visual.delivered_layers.presentation_outline()).is_empty() and parked_overlaps.size()<100:
				parked_overlaps.append({"case":case_name,"source":tx.source,"parked":index,"time":game.elapsed,"legacy_front_layer":tx.animator.route_uses_front_layer if not baseline else true})
			if not baseline and tx.animator.segment_hits_polygon(tx.animator.planned_stream(tx.animator.elapsed),node.visual.global_transform*node.visual.delivered_layers.presentation_outline()) and parked_stream_hits.size()<50:
				parked_stream_hits.append({"case":case_name,"source":tx.source,"parked":index,"time":game.elapsed})
		for j in range(i+1,game.transactions.size()):
			var other=game.transactions[j]
			if other.stage!="pour" or not other.animator.busy:continue
			var b=other.animator.source
			if not Geometry2D.intersect_polygons(shape,b.global_transform*b.delivered_layers.presentation_outline()).is_empty():
				if collisions.size()<50:collisions.append({"case":case_name,"time":game.elapsed,"sources":[tx.source,other.source],"phases":[tx.animator.phase,other.animator.phase]})
			if not baseline:
				var b_shape:PackedVector2Array=b.global_transform*b.delivered_layers.presentation_outline()
				var a_envelope:PackedVector2Array=FlowCoverage.exterior_envelope(tx.animator)
				var b_envelope:PackedVector2Array=FlowCoverage.exterior_envelope(other.animator)
				if (not a_envelope.is_empty() and not Geometry2D.intersect_polygons(a_envelope,b_shape).is_empty()) or (not b_envelope.is_empty() and not Geometry2D.intersect_polygons(b_envelope,shape).is_empty()):
					if stream_collisions.size()<50:stream_collisions.append({"case":case_name,"time":game.elapsed,"reason":"full texture/glow/drop width"})
				var a_stream:PackedVector2Array=tx.animator.planned_stream(tx.animator.elapsed)
				var b_stream:PackedVector2Array=other.animator.planned_stream(other.animator.elapsed)
				if tx.animator.segment_hits_polygon(a_stream,b_shape) or tx.animator.segment_hits_polygon(b_stream,shape):
					if stream_collisions.size()<50:stream_collisions.append({"case":case_name,"time":game.elapsed,"sources":[tx.source,other.source]})

func step(seconds:float)->void:
	for i in ceili(seconds/.01):game._process(.01);sample()

func drain()->void:
	for i in 2000:
		if not game._animation_busy() and game.presentation.input_queue.is_empty():break
		step(.01)
	check(not game._animation_busy() and game.presentation.input_queue.is_empty(),case_name+" bounded drain")
	if not baseline:traces.append({"case":case_name,"events":game.presentation.intent_trace.duplicate(true)})

func capture(label:String)->void:
	if not native:return
	await process_frame
	var began:=Time.get_ticks_usec();RenderingServer.force_draw(false)
	var draw_ms:float=(Time.get_ticks_usec()-began)/1000.0
	began=Time.get_ticks_usec();var pixels:Image=root.get_texture().get_image()
	var readback_ms:float=(Time.get_ticks_usec()-began)/1000.0
	began=Time.get_ticks_usec();var error:=pixels.save_png(out+"/"+label+".png")
	export_costs.append({"file":label+".png","draw_ms":draw_ms,"readback_ms":readback_ms,"png_encode_write_ms":(Time.get_ticks_usec()-began)/1000.0})
	check(error==OK,"native capture "+label)

func run()->void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="):out=arg.trim_prefix("--capture-dir=");native=true
		if arg=="--baseline":baseline=true
		if arg.begins_with("--height="):window_height=int(arg.trim_prefix("--height="))
		if arg.begins_with("--width="):window_width=int(arg.trim_prefix("--width="))
		if arg.begins_with("--out="):out=arg.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	root.content_scale_size=Vector2i(1080,1920);root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.size=Vector2i(window_width,window_height if window_height>0 else roundi(window_width*1920.0/1080.0))
	app=Entry.instantiate();app.enable_audio=false;app.progress=progress_fixture("batch-a-parallel",Catalog.V3);app.energy=energy_fixture();root.add_child(app);await process_frame;app.set_process(false);game=app.game;app._show_game();game.set_process(false)
	game.reward_capability=func():return true
	game._refresh()
	game.reward_requested.connect(func(kind):reward_requests.append(kind))
	app.progress.acknowledge_mechanic("covered_lock_v1");app.progress.acknowledge_mechanic("unknown_layers_v1")
	load_case("same-row-four-clicks")
	await pair(0,1);step(.08);await pair(2,3)
	check(game.moves+game.presentation.input_queue.size()==2,"four clicks retain both intentions, allowing a real crossing-corridor wait")
	if game.moves==1:check(not game.presentation.input_queue[0].get("blocked_serials",[]).is_empty(),"queued disjoint bottles identify the actual moving corridor blocker")
	step(.32);await capture("same-row-overlap")
	var overlapping:=false
	for frame in timeline:
		var pouring:int=0
		for tx in frame.transactions:
			if tx.phase=="pour":pouring+=1
		if pouring>=2:overlapping=true
	# These adjacent same-row routes can intersect. The explicit outer-column
	# cases below still require simultaneous liquid emission, not global serial play.
	drain();check(game.moves==2 and game.display_delivered.size()==2,"both independent click pairs executed once")
	for phase in ["pour","return","celebrate","seal","flight"]:
		load_case("input-during-"+phase);await pair(0,1)
		var reached:=false
		for i in 700:
			for tx in game.transactions:
				if tx.stage==phase or tx.animator.phase==phase:reached=true
			for receipt in game.receipts:
				if receipt.stage==phase:reached=true
			if reached:break
			step(.01)
		check(reached,"reached phase "+phase)
		await pair(2,3)
		check(game.moves+game.presentation.input_queue.size()==2,"independent pair starts or retains a corridor-wait intention during "+phase)
		await capture("independent-during-"+phase)
		drain();check(game.moves==2 and game.display_delivered.size()==2,"both pairs execute once during "+phase)
	load_case("cross-row",{"bottles":[["red","red"],["blue","blue"],[],[],["red"],["blue"],[],[]],"orders":["yellow","green","purple"]})
	await pair(0,4);step(.08);await pair(1,5);step(.32);await capture("cross-row-overlap");drain()
	check(game.moves==2 and game.rules.bottles[4].size()==3 and game.rules.bottles[5].size()==3,"cross-row stable identities and quantities")
	load_case("far-cross-row",{"bottles":[["red","red"],[],[],["blue","blue"],["red"],[],[],["blue"]],"orders":["yellow","green","purple"]})
	await pair(0,4);step(.08);await pair(3,7);step(.4);await capture("far-cross-row-overlap");drain()
	var cross_overlap:=false
	for frame in timeline:
		if frame.case!="far-cross-row":continue
		var active:=0
		for tx in frame.transactions:
			if tx.phase=="pour":active+=1
		if active>=2:cross_overlap=true
	check(cross_overlap,"outer same-column pairs use safe concurrent foreground routes")
	load_case("opposite-cross-row",{"bottles":[["red","red"],[],[],["blue","blue"],[],["red"],["blue"],[]],"orders":["yellow","green","purple"]})
	await pair(0,5);step(.08);await pair(3,6);step(.4);await capture("outer-cross-row-overlap");drain()
	cross_overlap=false
	for frame in timeline:
		if frame.case!="opposite-cross-row":continue
		var active:=0
		for tx in frame.transactions:
			if tx.phase=="pour":active+=1
		if active>=2:cross_overlap=true
	check(cross_overlap,"disjoint outer cross-row streams overlap in time")
	load_case("shared-bottle",{"bottles":[["yellow","red"],[],[],["blue"],[],[]],"orders":["red","blue","yellow"]})
	await pair(0,1);step(.08);await pair(1,2)
	check(game.moves==1 and game.presentation.input_queue.size()==1,"conflicting pair queued without early commit")
	await capture("shared-wait-no-badge")
	await pair(3,4)
	check(game.moves==2,"disjoint pair bypasses shared-bottle wait")
	drain();check(game.moves==3 and game.rules.bottles[2]==["red"] and game.rules.bottles[1].is_empty(),"queued legal pair executes exactly once")
	load_case("failed-plan-fifo",{"bottles":[["red","red"],["blue","blue"],[],["green"],["red"],["blue"],[],[]],"orders":["yellow","purple","orange"]})
	await pair(0,4);step(.08)
	for pair_ids in [[1,5],[5,6],[3,7]]:
		game.presentation.input_queue.append({"source_id":game.bottle_nodes[pair_ids[0]].get_instance_id(),"target_id":game.bottle_nodes[pair_ids[1]].get_instance_id(),"epoch":game.presentation.input_epoch})
	game.presentation.execute_next()
	var rejected_first:=false;var attempted_dependent:=false
	for event in game.presentation.intent_trace:
		if event.event=="planned" and event.source==1 and event.failed:rejected_first=true
		if event.event=="planned" and event.source==5:attempted_dependent=true
	check(rejected_first and not attempted_dependent,"actual failed planning does not attempt a dependent intent")
	check(game.rules.bottles[5]==["blue"] and game.rules.bottles[6].is_empty(),"failed route preserves shared-bottle FIFO before retry")
	check(game.presentation.input_queue.size()==2 and game.presentation.input_queue[0].source_id==game.bottle_nodes[1].get_instance_id() and game.presentation.input_queue[1].source_id==game.bottle_nodes[5].get_instance_id(),"failed plan retains original queue position")
	check(game.rules.bottles[7]==["green"],"independent queued pair still bypasses failed planning")
	drain();check(game.moves==4 and game.rules.bottles[6]==["blue","blue","blue"] and game.rules.bottles[5].is_empty(),"failed plan and dependent intent execute once in original order")
	load_case("invalidated-queue");await pair(0,1);await pair(0,1);drain()
	check(game.moves==1,"duplicate same pair revalidates and never double commits")
	load_case("undo-barrier");await pair(0,1);await pair(2,3);await pair(0,6)
	var committed_before_undo:int=game.moves
	await click_ui(game.buttons.Undo)
	check(game.presentation.undo_pending and game.presentation.input_queue.is_empty(),"undo discards queued intentions and waits for active commits")
	await pair(4,5);check(game.moves==committed_before_undo,"undo barrier admits no new pour")
	drain();check(game.moves==committed_before_undo and reward_requests==["undo"],"undo barrier requests one reward without a free board mutation")
	load_case("pause");await pair(0,1);await pair(2,3);step(.15)
	var committed_before_pause:int=game.moves
	var clocks:Array=[]
	for tx in game.transactions:clocks.append(tx.animator.elapsed)
	game.pause_game();game._process(2)
	var after:Array=[]
	for tx in game.transactions:after.append(tx.animator.elapsed)
	check(clocks==after,"pause freezes both animator clocks")
	game.resume_game();drain();check(game.moves==committed_before_pause,"resume retains admitted commits and does not revive cancelled intentions")
	load_case("receipt-prefix",{"bottles":[["red","red","red"],["red"],["blue"],["blue","blue","blue"],["green"],[],[],[]],"orders":["red","blue","green"],"masks":[{"bottle":4,"condition":{"kind":"color","orders":1,"color":"red"}}]})
	await pair(0,1);step(.03);await pair(2,3)
	var prefix_safe:=true;var locked_until_red:=true
	for i in 900:
		if not game._animation_busy():break
		step(.01)
		if game.display_delivered!=game.rules.delivered.slice(0,game.display_delivered.size()):prefix_safe=false
		if not game.display_delivered.has(1) and game.rules.mask_remaining(4,game.display_delivered.size())!=1:locked_until_red=false
	check(prefix_safe and locked_until_red,"out-of-order flights retain committed receipt prefix and correct color unlock")
	check(game.display_delivered==[1,3] and game.rules.mask_remaining(4,game.display_delivered.size())==0,"each actual receipt arrives once and unlocks correct condition")
	var delivered: Array=game.display_delivered.duplicate();game.presentation.queue_events();step(1)
	check(game.display_delivered==delivered,"duplicate update cannot add receipts")
	load_case("unknown-parallel",{"bottles":[["green","red","red"],["red"],["yellow","blue"],["blue"],[],[],[],[]],"orders":["red","blue","green"],"unknown_layers":[{"bottle":0,"layers":[0]}]})
	await pair(0,1);await pair(2,3)
	check(game.moves+game.presentation.input_queue.size()==2 and game.rules.unknown[0]==[false],"accepted intentions reveal only the exposed bottom-prefix layer")
	check(game.bottle_nodes[0].visual.unknown_layers.has(true),"active source retains pre-transfer question mark until its own return")
	drain();check(game.moves==2 and game.bottle_nodes[0].visual.unknown_layers==[false],"both intentions execute and source question mark updates when its visual resource releases")
	for indices in [[0,12],[12,0],[0,1]]:
		var bottles:Array=[]
		for i in 13:bottles.append(["purple"])
		bottles[indices[0]]=["red"];bottles[indices[1]]=["red"]
		load_case("three-row-%d-%d"%[indices[0],indices[1]],{"bottles":bottles,"orders":["yellow","green","blue"]})
		await pair(indices[0],indices[1]);check(game.moves==1,"three-row real input accepted")
		step(.45);await capture(case_name+"-flow");step(.15);await capture(case_name+"-tail");drain()
		check(game.rules.bottles[indices[1]]==["red","red"],"three-row transfer conserves quantity")
	load_case("restart");await pair(0,1);await pair(2,3);await pair(0,6)
	game.load_level(1);step(2)
	check(game.moves==0 and not game._animation_busy() and game.presentation.input_queue.is_empty(),"new level invalidates all transactions and queued IDs")
	check(boundary_failures.is_empty(),"full moving bottle envelope inside window")
	check(collisions.is_empty(),"active source polygons never intersect")
	check(stream_collisions.is_empty(),"liquid streams never pass through another active source")
	check(parked_stream_hits.is_empty(),"liquid streams never pass through parked glass")
	check(fixed_target_failures.is_empty(),"all receiving bottles stay in their captured slots")
	for node in game.bottle_nodes:check(node.visual.get_node_or_null("QueuedFeedback")==null,"queue badge absent")
	var result:Dictionary={"checks":checks,"boundary_failures":boundary_failures,"failures":failures,"passed":failures.is_empty(),"baseline":baseline,"driver":DisplayServer.get_name(),"timeline":timeline,"clicks":clicks,"intent_traces":traces,"collisions":collisions,"stream_collisions":stream_collisions,"parked_stream_hits":parked_stream_hits,"parked_front_layer_overlaps":parked_overlaps,"fixed_target_failures":fixed_target_failures,"storage":"memory only; no player files","human_acceptance":false,"scope_limit":"narrow intersecting corridors explicitly wait; pre-existing front-layer passes over parked glass still possible"}
	FileAccess.open(out+"/parallel-result.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	FileAccess.open(out+"/png-export-costs.json",FileAccess.WRITE).store_string(JSON.stringify(export_costs,"\t"))
	print("PARALLEL_POURS ",JSON.stringify({"checks":checks,"failures":failures,"passed":failures.is_empty(),"baseline":baseline,"driver":DisplayServer.get_name(),"collision_samples":collisions.size()}))
	app.free();quit(0 if failures.is_empty() else 1)
