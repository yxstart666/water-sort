extends "res://tests/water_sort_orders/batch_a_parallel_host.gd"
var rows:Array=[]
func run()->void:
	root.content_scale_size=Vector2i(1080,1920);root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	app=Entry.instantiate();app.enable_audio=false;app.progress=progress_fixture("l6-direction",Catalog.V3);app.energy=energy_fixture();root.add_child(app);await process_frame;app.set_process(false);game=app.game;app._show_game();game.set_process(false)
	var cert:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/water_sort_orders/c3_full_certificate.json"));var original:Dictionary=cert.levels[5].level
	app.progress.acknowledge_mechanic("unknown_layers_v1")
	var quick:=OS.get_cmdline_user_args().has("--quick")
	for dims in ([Vector2i(1073,2017)] if quick else [Vector2i(320,480),Vector2i(390,844),Vector2i(430,932),Vector2i(1073,2017)]):
		root.size=dims;await process_frame
		for mirrored in ([false] if quick else [false,true]):
			var definition:Dictionary=original.duplicate(true)
			if mirrored:
				definition.bottles.reverse()
				for item in definition.unknown_layers:item.bottle=4-int(item.bottle)
			load_case("real_C3_L6_%dx%d_mirror%s"%[dims.x,dims.y,mirrored],definition)
			for action in cert.levels[5].solution:
				var from:int=int(action[0]);var to:int=int(action[1])
				if mirrored:from=4-from;to=4-to
				var dx:float=game.bottle_nodes[to].visual.global_position.x-game.bottle_nodes[from].visual.global_position.x
				var side_error:=0.0;var wrong:=false;var seen:=false;var evidence:Dictionary={};var prior:int=game.moves
				await pair(from,to)
				for tick in 2000:
					for tx in game.transactions:
						var a=tx.animator
						if absf(dx)>.01 and a.direction!=signf(dx):wrong=true
						if a.phase=="pour":
							var center:Vector2=a.source.global_position+a.board_center.rotated(a.source.global_rotation)
							side_error=maxf(side_error,(center.x-a.target.mouth_world().x)*signf(dx))
						if a.phase=="pour" and evidence.is_empty():
							seen=true;evidence={"source_home":str(a.source_home),"target_home":str(a.target_home),"source_position":str(a.source.global_position),"mouth":str(a.outlet),"direction":a.direction,"rotation":a.source.global_rotation,"phase":a.phase,"elapsed":a.elapsed}
					if not game._animation_busy() and game.presentation.input_queue.is_empty():break
					step(.01)
				check(game.moves==prior+1 and seen,"real L6 accepted "+str([from,to])+case_name)
				check(side_error<.1,"real L6 body center remains on originating side "+case_name)
				check(not wrong,"real L6 direction follows home positions "+str([from,to])+case_name)
				rows.append({"case":case_name,"pair":[from,to],"dx":dx,"wrong":wrong,"evidence":evidence,"moves":game.moves})
			check(game.rules.is_solved(),"real L6 full thirteen-pour win "+case_name)
	check(boundary_failures.is_empty(),"L6 all visible glass in window")
	check(parked_stream_hits.is_empty() and stream_collisions.is_empty(),"L6 no wrong bottle stream")
	FileAccess.open("res://direction_review/c3_l6_direction.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"rows":rows,"boundary":boundary_failures,"stream":parked_stream_hits,"source_sha":FileAccess.get_sha256("res://scripts/water_sort/art/pour_animator.gd")},"\t"));print("C3_L6_DIRECTION ",JSON.stringify({"checks":checks,"failures":failures,"moves":rows.size(),"boundary":boundary_failures.size(),"stream":parked_stream_hits.size()}));app.debug_ads.shutdown();app.free();quit(0 if failures.is_empty() else 1)
