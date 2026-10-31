extends "res://tests/water_sort_orders/all_positions_route_test.gd"
const Before=preload("res://tests/water_sort_orders/spacing_layout_before.gd")
const After=preload("res://scripts/water_sort/order_gameplay_layout.gd")
const Cache=preload("res://scripts/water_sort/art/static_pour_route_cache.gd")
var cache_rows:Array=[]
var canonical_positions:Array=[]
func plan(old_positions:bool)->Dictionary:
	# _refresh intentionally reuses existing nodes/rest metadata. Restore the
	# controlled preflight fixture before applying either set of x origins.
	for i in count:
		g.bottle_nodes[i].position=canonical_positions[i]
		g.bottle_nodes[i].set_meta("rest_position",canonical_positions[i])
	reset_case(0,count-1,3,2,0)
	if old_positions:
		for i in count:
			var delta:Vector2=Before.bottle_slot(count,i).art.position-After.bottle_slot(count,i).art.position
			var node=g.bottle_nodes[i];node.position+=delta;node.set_meta("rest_position",node.get_meta("rest_position")+delta)
	var source=g.bottle_nodes[0].visual;var target=g.bottle_nodes[count-1].visual
	var source_home:Transform2D=source.global_transform;var target_home:Transform2D=target.global_transform
	var anim=g.presentation.new_animator(0)
	var accepted:bool=anim.play(source,target,["blue","red","red"],[],["blue"],["red","red"])
	if accepted:anim.prepare_route()
	var result={"old_positions":old_positions,"count":count,"accepted":accepted and not anim.board_path_failed,"key":anim.static_route_cache_key,"hit":anim.static_route_cache_hit,"source_home":str(source_home),"target_home":str(target_home),"mouth":str(target.mouth_world()),"plan_ms":anim.board_plan_ms}
	g.suppress_animation_completion=true;anim.cancel(false);g.suppress_animation_completion=false
	return result
func run()->void:
	check(DisplayServer.get_name()=="headless","silent only")
	root.content_scale_size=Vector2i(1080,1920);root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS;root.size=Vector2i(390,844)
	app=Entry.instantiate();app.enable_audio=false;app.progress=progress_fixture("spacing-cache",Catalog.V3);app.energy=energy_fixture();root.add_child(app);await process_frame;app.set_process(false);g=app.game;g.set_process(false);app._show_game()
	for total in [5,9,10,13,14,15]:
		count=total;var initial:Array=[]
		for i in count:initial.append(["purple"])
		g.levels[1]={"id":2,"bottles":initial,"orders":["red","blue","green","yellow"]};g.load_level(1);g.set_process(false)
		canonical_positions.clear()
		for node in g.bottle_nodes:canonical_positions.append(node.get_meta("rest_position"))
		Cache.values.clear();Cache.order.clear();Cache.rejected.clear();Cache.rejected_order.clear()
		var old=plan(true);var cold=plan(false);var warm=plan(false)
		check(old.accepted and cold.accepted and warm.accepted,"old/new actual geometry preflight accepted "+str(count))
		check(not old.hit and not cold.hit and warm.hit,"geometry transition misses old cache then same new geometry hits "+str(count))
		check(old.key!=cold.key and cold.key==warm.key,"old/new route identities include shifted source/target/obstacles "+str(count))
		check(old.source_home!=cold.source_home and old.target_home!=cold.target_home and cold.target_home==warm.target_home,"actual origins and target mouth changed; repeated pose stable "+str(count))
		cache_rows.append({"count":count,"old":old,"new_cold":cold,"new_warm":warm})
	var result={"checks":checks,"failures":failures,"cases":cache_rows,"scope":"Single process seeds real Animator cache under pre-delta visual x origins, resets actual new layout, then repeats; no production file or algorithm switches, no cleared cache between old/cold/warm; full old/new target/origin cache identities required"}
	FileAccess.open("res://spacing_integration_evidence/cache_transition.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"));print("SPACING_CACHE ",JSON.stringify({"checks":checks,"failures":failures}));app.debug_ads.shutdown();app.free();quit(0 if failures.is_empty() else 1)
