extends "res://tests/water_sort_orders/batch_a_parallel_host.gd"
var rows:Array=[]
func run()->void:
	root.content_scale_size=Vector2i(1080,1920);root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	app=Entry.instantiate();app.enable_audio=false;app.progress=progress_fixture("direction-contract",Catalog.V3);app.energy=energy_fixture();root.add_child(app);await process_frame;app.set_process(false);game=app.game;app._show_game();game.set_process(false)
	var quick:=OS.get_cmdline_user_args().has("--quick")
	for dims in ([Vector2i(390,844)] if quick else [Vector2i(320,480),Vector2i(390,844),Vector2i(430,932)]):
		root.size=dims;await process_frame
		for count in ([10] if quick else [5,10,15]):
			var pairs:Array=[[0,1],[1,0],[3,4],[4,3],[0,4],[4,0]]
			if count>=10:pairs.append_array([[0,6],[6,0],[3,9],[9,3],[0,5],[5,0]])
			for units in ([1] if quick else [1,3]):
				for pair_ids in pairs:
					var bs:Array=[]
					for i in count:bs.append(["purple"])
					bs[pair_ids[0]]=[];bs[pair_ids[1]]=[]
					for i in units:bs[pair_ids[0]].append("red")
					load_case("%dx%d_n%d_u%d_%dto%d"%[dims.x,dims.y,count,units,pair_ids[0],pair_ids[1]],{"id":2,"bottles":bs,"orders":["yellow"]})
					var dx:float=game.bottle_nodes[pair_ids[1]].visual.global_position.x-game.bottle_nodes[pair_ids[0]].visual.global_position.x
					var expected:float=signf(dx);var actual:=0.0;var wrong:=false;var side_error:=0.0;var seen:=false;var poses:Array=[]
					await pair(pair_ids[0],pair_ids[1])
					for tick in 2000:
						for tx in game.transactions:
							var a=tx.animator;actual=a.direction
							if absf(dx)>.01 and a.direction!=expected:wrong=true
							if a.phase=="pour":
								seen=true
								var center:Vector2=a.source.global_position+a.board_center.rotated(a.source.global_rotation)
								if expected!=0:side_error=maxf(side_error,(center.x-a.target.mouth_world().x)*expected)
								if poses.size()<1:poses.append({"source_home":str(a.source_home),"target_home":str(a.target_home),"body_center":str(center),"rotation":a.source.global_rotation,"direction":a.direction,"dock":a.board_dock_offset})
						if not game._animation_busy() and game.presentation.input_queue.is_empty():break
						step(.01)
					check(game.moves==1 and seen,"accepted and real flow "+case_name)
					check(not wrong,"source-target facing immutable "+case_name)
					check(side_error<.1,"source body stays on originating side while pouring "+case_name)
					rows.append({"case":case_name,"dx":dx,"expected":expected,"actual":actual,"moves":game.moves,"wrong":wrong,"side_error":side_error,"poses":poses})
	check(boundary_failures.is_empty(),"full moving body remains in window")
	check(stream_collisions.is_empty() and parked_stream_hits.is_empty(),"full stream avoids wrong bottles")
	check(fixed_target_failures.is_empty(),"receiver stays fixed")
	var result={"checks":checks,"failures":failures,"rows":rows,"boundary":boundary_failures,"stream":parked_stream_hits,"moving":collisions,"intentional_foreground_projection_overlap":parked_overlaps,"source_sha":FileAccess.get_sha256("res://scripts/water_sort/art/pour_animator.gd")}
	FileAccess.open("res://direction_review/direction_contract.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"));print("DIRECTION_CONTRACT ",JSON.stringify({"cases":rows.size(),"checks":checks,"failures":failures,"boundary":boundary_failures.size(),"stream":parked_stream_hits.size()}));app.debug_ads.shutdown();app.free();quit(0 if failures.is_empty() else 1)
