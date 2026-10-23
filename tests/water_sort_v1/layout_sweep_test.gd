extends SceneTree
# Actual game layout, complete movement silhouettes, and real undo/retry states.
const Silhouette = preload("res://tests/water_sort_art/sweep_path.gd")
var game
var checks:=0
var failures: Array=[]
var sampled_frames:=0
var paths:=0
var minimum_y:=INF
var minimum_x:=INF
var maximum_x:=-INF
var amounts: Dictionary={}
var directions: Dictionary={}
var sample_labels: Array=[]
func _initialize() -> void: call_deferred("run")
func check(value: bool, label: String) -> void:
	checks+=1
	if not value: failures.append(label); push_error(label)
func outline(node: Node2D, margin: float=0) -> PackedVector2Array:
	var result:=PackedVector2Array()
	var points: Array=Silhouette.OUTER.duplicate()
	if is_instance_valid(node.cork) and node.cork.visible:
		# Include the exposed completed cork, and its actual descent/removal height.
		points=[Vector2(-49,-8),Vector2(-36,-8),Vector2(-36,node.cork.position.y-3.0),Vector2(36,node.cork.position.y-3.0),Vector2(36,-8)]+points.slice(1)
	for point in points: result.append(node.to_global(point))
	if margin>0:
		var wider:=Geometry2D.offset_polygon(result,margin)
		if not wider.is_empty(): return wider[0]
	return result
func sweep(source: int, target: int, label: String) -> void:
	game.select_bottle(source);game.select_bottle(target)
	check(game.animator.busy,label+" starts actual glass animator")
	if not game.animator.busy: return
	amounts[int(game.animator.moved)]=true;directions[signi(target-source)]=true
	if not sample_labels.is_empty() and not sample_labels.has(label):
		game.animator.advance(game.animator.remaining_seconds())
		return
	paths+=1
	var full_seconds: float=float(game.animator.remaining_seconds()) if game.animator.has_method("remaining_seconds") else game.POUR_SECONDS
	var collisions:=0
	var first_hits: Array=[]
	var local_min:=INF
	var left:=INF
	var right:=-INF
	for frame in range(601):
		if frame>0: game.animator.advance(full_seconds/600.0+0.0000001)
		sampled_frames+=1
		var moving:=outline(game.bottle_nodes[source].visual)
		for p in moving:
			local_min=minf(local_min,p.y);left=minf(left,p.x);right=maxf(right,p.x)
		for i in game.bottle_nodes.size():
			if i!=source and not Geometry2D.intersect_polygons(moving,outline(game.bottle_nodes[i].visual,3.0)).is_empty():
				collisions+=1
				if first_hits.size()<3: first_hits.append({"frame":frame,"phase":game.animator.phase,"neighbour":i,"source_anchor":str(game.bottle_nodes[source].visual.global_position)})
	minimum_y=minf(minimum_y,local_min);minimum_x=minf(minimum_x,left);maximum_x=maxf(maximum_x,right)
	if collisions>0 or left<20 or right>1060 or local_min<459: print("SWEEP_FAIL ",JSON.stringify({"label":label,"source":source,"target":target,"before":game.animator.source_before,"after":game.animator.source_after,"collisions":collisions,"first_hits":first_hits,"min_y":local_min,"left":left,"right":right}))
	check(collisions==0,label+" has no swept silhouette intersections including neighbours")
	check(local_min>=459.0,label+" stays below HUD bottom439 plus20px clearance")
	check(left>=20.0 and right<=1060.0,label+" stays inside portrait canvas margins")
	check(not game.animator.busy and game.pour_remaining==0,label+" restores exact ready transaction state")
func run() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--failed-paths="):
			sample_labels=JSON.parse_string(FileAccess.get_file_as_string(argument.trim_prefix("--failed-paths=")))
	game=load("res://scenes/experiments/water_sort_v1.tscn").instantiate();root.add_child(game);await process_frame;game.set_process(false)
	var proofs: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/water_sort_v1/proofs.json"))
	for index in range(5):
		game.load_level(index)
		for node in game.bottle_nodes:
			check(node.size.x/3.0>=48.0,"360dp viewport keeps at least48dp-wide independent touch targets")
		for n in range(game.bottle_nodes.size()-1):
			check(not game.bottle_nodes[n].get_rect().intersects(game.bottle_nodes[n+1].get_rect()),"adjacent input hit boxes never overlap")
		var actions: Array=proofs.levels[index].shortest_solution
		for step in range(actions.size()):
			var from:=int(actions[step][0]);var to:=int(actions[step][1])
			var before: Dictionary=game.rules.snapshot()
			sweep(from,to,"level%d step%d" %[index+1,step+1])
			var after: Dictionary=game.rules.snapshot()
			game.undo_move()
			check(game.rules.snapshot()==before,"undo restores actual before-state for a fresh geometric path")
			# Exercise an alternative legal opposite-direction action after undo where available.
			var alternate: Dictionary={}
			for action in game.rules.available_moves(before):
				if signi(int(action.to)-int(action.from))!=signi(to-from): alternate=action;break
			if not alternate.is_empty():
				sweep(int(alternate.from),int(alternate.to),"level%d undo-alternate%d" %[index+1,step+1])
				game.undo_move();check(game.rules.snapshot()==before,"undo alternate retains original puzzle")
			game.select_bottle(from);game.select_bottle(to);game.animator.advance(float(game.animator.remaining_seconds()) if game.animator.has_method("remaining_seconds") else game.POUR_SECONDS)
			check(game.rules.snapshot()==after,"retry after undo produces identical committed layer state")
		check(game.rules.is_solved(),"all shipped solution moves still reach win")
	# Full four-layer pours are legal even when not required by a shortest solution.
	game.load_level(0)
	game.rules.restore({"capacity":4,"bottles":[["red","red","red","red"],["yellow","yellow","yellow","yellow"],[]]})
	game._refresh();sweep(0,2,"full four-layer transfer")
	check(amounts.has(1) and amounts.has(2) and amounts.has(3) and amounts.has(4),"geometry covers every legal moved quantity1..4")
	check(directions.has(-1) and directions.has(1),"geometry covers left and right pouring")
	print("WATER_SORT_LAYOUT_SWEEP ",JSON.stringify({"checks":checks,"failures":failures,"passed":failures.is_empty(),"paths":paths,"frames":sampled_frames,"minimum_y":minimum_y,"x_range":[minimum_x,maximum_x],"moved_quantities":amounts.keys()}))
	game.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
