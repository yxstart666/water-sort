extends SceneTree
# Memory-only stress fixtures. Never loads a candidate pack or writes progress.
const Silhouette=preload("res://tests/water_sort_art/sweep_path.gd")
const Rules=preload("res://scripts/experiments/water_sort_v1/rules.gd")
var game
var checks:=0
var failures: Array=[]
var frames:=0
var paths:=0
var min_y:=INF
var min_x:=INF
var max_x:=-INF
var max_stream:=0.0
var sample_count:=300
var totals: Array=[7,8,9]
var only_source:=-1
var only_target:=-1
var only_amount:=-1
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok: failures.append(label);push_error(label)
func outline(node: Node2D, margin:=0.0) -> PackedVector2Array:
	var result:=PackedVector2Array()
	var points: Array=Silhouette.OUTER.duplicate()
	if node.cork.visible:
		points=[Vector2(-49,-8),Vector2(-36,-8),Vector2(-36,node.cork.position.y-3.0),Vector2(36,node.cork.position.y-3.0),Vector2(36,-8)]+points.slice(1)
	for point in points: result.append(node.to_global(point))
	if margin>0:
		var expanded:=Geometry2D.offset_polygon(result,margin)
		if not expanded.is_empty(): return expanded[0]
	return result
func fixture(total: int, source: int, target: int, amount: int) -> Dictionary:
	var bottles: Array=[]
	for i in total: bottles.append([])
	for _i in 4-amount: bottles[source].append("blue");bottles[target].append("red")
	for _i in amount: bottles[source].append("red")
	var balance:=-1
	for i in total:
		if i!=source and i!=target: balance=i;break
	for _i in amount: bottles[balance].append("blue")
	for i in total:
		if i not in [source,target,balance]:
			for _j in 4: bottles[i].append("obstacle_"+str(i))
	return {"title":"Two-row geometry fixture","capacity":4,"bottles":bottles}
func install(level: Dictionary) -> void:
	game.levels=[level];game.load_level(0)
func sample(source: int, target: int, amount: int, label: String) -> void:
	var before: Dictionary=game.rules.snapshot()
	game.select_bottle(source);game.select_bottle(target)
	check(game.animator.busy and game.moves==1,label+" commits and animates")
	if not game.animator.busy: return
	check(game.animator.moved==amount,label+" moves requested layers")
	check(is_equal_approx(game.animator.duration,0.84) and game.animator.transaction_duration<=0.893,label+" retains approved bounded timing")
	var after: Dictionary=game.rules.snapshot()
	var seconds: float=game.animator.transaction_duration
	var collisions:=0
	var stream_hits:=0
	var left:=INF
	var right:=-INF
	var top:=INF
	var bottom:=-INF
	var first_hits: Array=[]
	var visual=game.bottle_nodes[source].visual
	var fixed: Dictionary={}
	for i in game.bottle_nodes.size():
		if i!=source and i!=target: fixed[i]=outline(game.bottle_nodes[i].visual,3.0)
	for frame in sample_count+1:
		if frame>0: game.animator.advance(seconds/float(sample_count)+0.0000001)
		frames+=1
		var moving:=outline(visual)
		for point in moving:
			left=minf(left,point.x);right=maxf(right,point.x);top=minf(top,point.y);bottom=maxf(bottom,point.y)
		for i in game.bottle_nodes.size():
			if i==source: continue
			var obstacle: PackedVector2Array=outline(game.bottle_nodes[i].visual,3.0) if i==target else fixed[i]
			if not Geometry2D.intersect_polygons(moving,obstacle).is_empty():
				collisions+=1
				if first_hits.size()<3: first_hits.append({"frame":frame,"phase":game.animator.phase,"bottle":i,"position":str(visual.global_position)})
			if game.animator.stream_strength>0.001 and i!=target:
				var a: Vector2=game.animator.outlet
				var b: Vector2=game.animator.target.mouth_world()
				var stream:=PackedVector2Array([a+Vector2(-6,0),a+Vector2(6,0),b+Vector2(6,0),b+Vector2(-6,0)])
				if not Geometry2D.intersect_polygons(stream,obstacle).is_empty(): stream_hits+=1
		if game.animator.stream_strength>0: max_stream=maxf(max_stream,game.animator.outlet.distance_to(game.animator.target.mouth_world()))
		if game.animator.target.seal_animating:
			check(game.animator.progress==1.0 and game.animator.stream_strength==0.0 and is_equal_approx(game.animator.target.volume(),float(after.bottles[target].size())),label+" liquid is finished before cork descent")
		check(absf(visual.volume()+game.bottle_nodes[target].visual.volume()-float(before.bottles[source].size()+before.bottles[target].size()))<0.001,label+" conserves liquid frame"+str(frame))
	paths+=1;min_y=minf(min_y,top);min_x=minf(min_x,left);max_x=maxf(max_x,right)
	if collisions>0 or stream_hits>0 or left<20 or right>1060 or top<459 or bottom>1585:
		print("TWO_ROW_PATH_FAIL ",JSON.stringify({"label":label,"collisions":collisions,"stream_hits":stream_hits,"first_hits":first_hits,"bounds":[left,top,right,bottom]}))
	check(collisions==0,label+" swept glass/cork clears every standing bottle")
	check(stream_hits==0,label+" stream passes only through its clear target lane")
	check(left>=20 and right<=1060 and top>=459 and bottom<=1585,label+" stays within board below HUD and above buttons")
	check(not game.animator.busy and game.pour_remaining==0,label+" settles without locks or wait queue")
	game.undo_move()
	check(game.rules.snapshot()==before and game.moves==0,label+" undo restores exact fixture")
	game.select_bottle(source);game.select_bottle(target);game.animator.advance(game.animator.remaining_seconds()+0.001)
	check(game.rules.snapshot()==after,label+" retry after undo is identical")
func interrupted_flows(total: int) -> void:
	var source:=total-1
	install(fixture(total,source,0,2))
	var before: Dictionary=game.rules.snapshot()
	for fraction in [0.08,0.22,0.33,0.50,0.80,0.95]:
		game.rules.restore(before);game.moves=0;game.history.clear();game.state="playing";game._clear_overlay();game._refresh()
		game.select_bottle(source);game.select_bottle(0);game.animator.advance(game.POUR_SECONDS*fraction)
		var committed: Dictionary=game.rules.snapshot()
		var position: Vector2=game.bottle_nodes[source].visual.global_position
		var volume: float=game.bottle_nodes[source].visual.volume()
		game.pause_game();game._process(1.0)
		check(game.animator.paused and position==game.bottle_nodes[source].visual.global_position and is_equal_approx(volume,game.bottle_nodes[source].visual.volume()),"pause freezes multi-row phase "+str(fraction))
		game.resume_game();game._settle_animation(true)
		check(not game.animator.busy and game.rules.snapshot()==committed,"cancel commits multi-row phase "+str(fraction))
		check(not game.bottle_nodes[source].visual.transaction_busy and not game.bottle_nodes[0].visual.transaction_busy,"cancel releases both locks")
		game.undo_move();check(game.rules.snapshot()==before,"undo after cancelled multi-row phase")
	# Reversing a completed full bottle exercises lifting/removing the stopper.
	var reverse_level:=fixture(total,source,0,4)
	# Keep two unrelated bottles mixed so this legal reversal is not blocked by
	# the game's correct terminal win overlay.
	var mixed: Array=[]
	for i in total:
		if i not in [source,0,1]: mixed.append(i)
	var color_a=reverse_level.bottles[mixed[0]][3]
	var color_b=reverse_level.bottles[mixed[1]][3]
	reverse_level.bottles[mixed[0]][3]=color_b
	reverse_level.bottles[mixed[1]][3]=color_a
	install(reverse_level)
	game.select_bottle(source);game.select_bottle(0);game.animator.advance(game.animator.remaining_seconds()+0.001)
	check(game.bottle_nodes[0].visual.sealed,"reverse starts with a real seated stopper")
	game.select_bottle(0);game.select_bottle(source)
	check(game.animator.busy and game.animator.source_was_sealed,"completed bottle can reverse along the route")
	game.animator.advance(game.animator.remaining_seconds()+0.001)
	check(game.bottle_nodes[source].visual.sealed and not game.bottle_nodes[0].visual.sealed,"reverse returns stopper with authoritative full bottle")
func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--samples="): sample_count=int(arg.trim_prefix("--samples="))
		if arg.begins_with("--total="): totals=[int(arg.trim_prefix("--total="))]
		if arg.begins_with("--source="): only_source=int(arg.trim_prefix("--source="))
		if arg.begins_with("--target="): only_target=int(arg.trim_prefix("--target="))
		if arg.begins_with("--amount="): only_amount=int(arg.trim_prefix("--amount="))
	game=load("res://scenes/experiments/water_sort_v1.tscn").instantiate();root.add_child(game);await process_frame;game.set_process(false)
	for total in totals:
		install(fixture(total,total-1,0,2))
		check(game.bottle_nodes.size()==total and game.animator.multi_row_route,"fixture uses real two-row view")
		for i in total:
			var node: Control=game.bottle_nodes[i]
			check(node.size.x/3.0>=48 and node.visual.global_scale.x>=0.68,"independent readable glass and >=48dp target")
			for j in range(i): check(not node.get_rect().intersects(game.bottle_nodes[j].get_rect()),"two-row touch rectangles never overlap")
		# Selection moves the Control as well as the glass. Its raised hit box
		# must not overlap a bottle in the other row either.
		for selected_index in total:
			game.selected=selected_index;game._sync_bottles()
			for i in total:
				for j in range(i): check(not game.bottle_nodes[i].get_rect().intersects(game.bottle_nodes[j].get_rect()),"selected two-row touch rectangles never overlap")
		game.selected=-1;game._sync_bottles()
		for source in total:
			if only_source>=0 and source!=only_source: continue
			for target in total:
				if source==target or (only_target>=0 and target!=only_target): continue
				for amount in [1,2,3,4]:
					if only_amount>=0 and amount!=only_amount: continue
					install(fixture(total,source,target,amount))
					sample(source,target,amount,"%d bottles %d->%d amount%d" %[total,source,target,amount])
		interrupted_flows(total)
	print("WATER_SORT_TWO_ROW_SWEEP ",JSON.stringify({"checks":checks,"failures":failures,"passed":failures.is_empty(),"paths":paths,"frames":frames,"minimum_y":min_y,"x_range":[min_x,max_x],"maximum_stream_length":max_stream,"samples_per_path":sample_count+1}))
	game.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
