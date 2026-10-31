extends "res://tests/water_sort_campaign50/memory_fixture.gd"
const Entry=preload("res://scenes/water_sort/orders_v3.tscn")
const OrderRules=preload("res://scripts/water_sort/order_rules.gd")
var app
var g
var count:=2
var source_start:=0
var source_end:=15
var four_cards:=false
var unreachable:=0
var out:=""
var results:Array=[]
var attempted:=0
var accepted:=0
var completed:=0
var maximum_plan:=0
var worst_plan:Dictionary={}
var maximum_flow:=0.0
var total_ms:=0
func color_inventory(bottles:Array)->Dictionary:
	var inventory:Dictionary={}
	for bottle in bottles:
		for color in bottle:inventory[color]=int(inventory.get(color,0))+1
	return inventory
func exterior_width_safe(anim)->bool:
	if anim.mass.is_empty() or anim.mass.segments.is_empty():return true
	# Current reference3_stream.gd draws straight external rectangles, followed
	# by a separate internal segment. This conservative bound includes the whole
	# 32px texture width (also all alpha/glow), taper and actual drop width.
	var half_width:float=16.0*anim.target.delivered_layers.global_scale.x
	for seg in anim.mass.segments:
		if seg.kind!=2:continue
		var flatten:float=1.0-0.55*clampf((seg.center-0.82)/0.18,0,1)
		var factor:float=sqrt(seg.units*anim.moved*8070.785294117648/anim.external_stream_layer.drop_area)
		half_width=maxf(half_width,10.0/flatten*factor*anim.target.delivered_layers.global_scale.x)
	var mouth:Vector2=anim.target.mouth_world();var delta:Vector2=mouth-anim.outlet
	var normal:Vector2=delta.normalized().orthogonal()*half_width
	var shape:=PackedVector2Array([anim.outlet+normal,mouth+normal,mouth-normal,anim.outlet-normal])
	var box:=Rect2(shape[0],Vector2.ZERO)
	for p in shape:box=box.expand(p)
	for obstacle in anim.board_stream_obstacles:
		if box.intersects(obstacle.rect) and not Geometry2D.intersect_polygons(shape,obstacle.polygon).is_empty():return false
	return true
func reset_case(source:int,target:int,volume:int,units:int,fill:int)->void:
	g._settle_animation(false);g.presentation.clear_inputs()
	var bs:Array=[]
	for i in count:bs.append(["purple"])
	bs[source]=[];bs[target]=[]
	for i in volume-units:bs[source].append("blue")
	for i in units:bs[source].append("red")
	for i in fill:bs[target].append("red")
	var initial_bottles:Array=bs.duplicate(true)
	if four_cards:
		initial_bottles=bs.slice(0,count-1).duplicate(true)
		for color in bs[count-1]:
			for bottle in initial_bottles:
				if bottle.size()<4:bottle.append(color);break
	g.rules=OrderRules.new({"id":2,"bottles":initial_bottles,"orders":["red","blue","green","yellow"],"bonus_bottle":four_cards})
	if four_cards:
		g.rules.bottles=bs.duplicate(true)
		for i in count:g.rules.unknown[i].resize(bs[i].size());g.rules.unknown[i].fill(false)
		g.rules.bonus_unlocked=true;g.rules.slot_unlocked=true
	g.moves=0;g.history.clear();g.display_delivered.clear();g.selected=-1;g.state="playing";g._refresh()
func record_failure(data:Dictionary,reason:String)->void:
	if results.size()<1000:
		var item=data.duplicate();item.reason=reason;results.append(item)
func run()->void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--count="):count=int(arg.trim_prefix("--count="))
		if arg.begins_with("--source-start="):source_start=int(arg.trim_prefix("--source-start="))
		if arg.begins_with("--source-end="):source_end=int(arg.trim_prefix("--source-end="))
		if arg=="--four-cards":four_cards=true
		if arg.begins_with("--out="):out=arg.trim_prefix("--out=")
	root.size=Vector2i(360,640)
	app=Entry.instantiate();app.enable_audio=false;app.progress=progress_fixture("all-positions",Catalog.V3);app.energy=energy_fixture()
	root.add_child(app);await process_frame;app.set_process(false);g=app.game;g.set_process(false)
	var initial:Array=[]
	for i in count-(1 if four_cards else 0):initial.append(["purple"])
	g.levels[1]={"id":2,"bottles":initial,"orders":["red","blue","green","yellow"],"bonus_bottle":four_cards};g.load_level(1);app._show_game();g.set_process(false)
	var began:=Time.get_ticks_msec()
	for source in range(source_start,mini(count,source_end)):
		for target in count:
			if source==target:continue
			for volume in range(1,5):
				for fill in range(4):
					for units in range(1,mini(volume,4-fill)+1):
						if units==4:continue # Known full single-colour bottle is rule-ineligible.
						if four_cards and count==2 and volume+fill>4:unreachable+=1;continue # One original bottle cannot supply more than four units.
						reset_case(source,target,volume,units,fill)
						var data={"count":count,"pair":[source,target],"source_volume":volume,"units":units,"target_fill":fill}
						attempted+=1
						if not g.rules.can_pour(source,target):record_failure(data,"fixture unexpectedly rule-ineligible");continue
						var before:Dictionary=g.rules.snapshot();var target_home:Transform2D=g.bottle_nodes[target].visual.global_transform
						g.select_bottle(source);g.select_bottle(target)
						if g.moves!=1 or g.transactions.is_empty():
							data.unchanged=g.rules.snapshot()==before and g.moves==0;record_failure(data,"legal pair rejected by presentation");continue
						accepted+=1
						var anim=g.transactions[0].animator
						if anim.board_plan_ms>maximum_plan:
							maximum_plan=anim.board_plan_ms;worst_plan=data.duplicate();worst_plan.merge({"ms":maximum_plan,"direction":anim.direction,"dock_offset":anim.board_dock_offset,"front_layer":anim.route_uses_front_layer,"grid_nodes":anim.board_path.expanded,"cache":"per-transaction path cache reset; renderer static shape caches warm after startup"})
						var safe:=true;var wide_safe:=true;var glass_safe:=true;var fixed:=true;var max_flow:=0.0
						for tick in 300:
							if not g._animation_busy():break
							g._process(.025)
							if anim.busy and is_instance_valid(anim.board_path):
								var current_pose:Dictionary={"position":anim.source.global_position,"angle":anim.source.global_rotation}
								if not anim.board_path.clear(anim._configuration(current_pose,0)):
									if glass_safe:data.first_glass_contact={"tick":tick,"phase":anim.phase,"pose":str(anim._configuration(current_pose,0))}
									glass_safe=false
							if anim.busy and anim.phase=="pour":
								max_flow=maxf(max_flow,anim.outlet.distance_to(anim.target.mouth_world()))
								if anim.stream_hits_parked({"outlet":anim.outlet}):safe=false
								if not exterior_width_safe(anim):wide_safe=false
								if not anim.target.global_transform.is_equal_approx(target_home):fixed=false
						maximum_flow=maxf(maximum_flow,max_flow)
						var correct:bool=g.rules.bottles[source].size()==volume-units and g.rules.bottles[target].size()==fill+units and g.moves==1 and g.history.size()==1 and color_inventory(g.rules.bottles)==color_inventory(before.bottles)
						var unlocked:bool=not g._animation_busy() and not g.bottle_nodes[source].visual.transaction_busy and not g.bottle_nodes[target].visual.transaction_busy
						var receipts_once:bool=g.rules.delivered.count(target)==(1 if fill+units==4 else 0)
						if safe and wide_safe and glass_safe and fixed and correct and unlocked and receipts_once:completed+=1
						else:
							data.merge({"safe":safe,"wide_safe":wide_safe,"glass_safe":glass_safe,"fixed":fixed,"correct":correct,"unlocked":unlocked,"receipt_once":receipts_once,"flow":max_flow});record_failure(data,"animation or accounting invariant")
				await process_frame # Release transient stream nodes; no real saves.
		print("ALL_POSITIONS_PROGRESS ",JSON.stringify({"count":count,"source":source,"attempted":attempted,"accepted":accepted,"completed":completed,"failures":results.size()}))
		if not out.is_empty():FileAccess.open(out+".progress.json",FileAccess.WRITE).store_string(JSON.stringify({"source_start":source_start,"source_completed":source,"count":count,"four_cards":four_cards,"attempted":attempted,"completed":completed,"failures":results,"worst_plan":worst_plan}))
	var result={"count":count,"four_cards":four_cards,"source_range":[source_start,mini(count,source_end)],"expected":(mini(count,source_end)-source_start)*(count-1)*29-unreachable,"unreachable_stock_cases":unreachable,"attempted":attempted,"accepted":accepted,"completed":completed,"failures":results,"maximum_plan_ms":maximum_plan,"worst_plan":worst_plan,"maximum_external_logical":maximum_flow,"seconds":(Time.get_ticks_msec()-began)/1000.0,"scope":"360x640; every ordered slot pair and 29 canonical legal volume/transfer/target-fill combinations; real rules/input/presentation, isolated memory; actual animation sampled at 25ms including conservative full texture/glow/drop width; explicit four-card variant models already earned bottle+slot; no ad capability visibility claim"}
	if not out.is_empty():FileAccess.open(out,FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	print("ALL_POSITIONS_RESULT ",JSON.stringify(result));app.free();quit(0 if completed==attempted and attempted==result.expected else 1)
