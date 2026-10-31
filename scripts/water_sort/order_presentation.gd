extends RefCounted
## Presentation only. Rules atomically commit inventory/order history at pour time.
## Each receipt reserves one event in a slot FIFO; callbacks never mutate rules.
const Animator = preload("res://scripts/water_sort/art/pour_animator.gd")
const Visual = preload("res://scripts/water_sort/art/bottle_visual.gd")
const SETTLE := 0.10
const CELEBRATE := 0.90
const SEAL := 0.16
const READY_HOLD := 0.22
const FLIGHT := 0.38
const CHECK := 0.16
const REPLACE := 0.14
var game
var clearing := false
var last_valid_time:=-100.0
var rapid_count:=0
const MAX_QUEUED_POURS:=3
var input_epoch:=0
var input_queue: Array=[]
var queued_source_id:=0
var undo_pending:=false
var commit_serial:=0
var trace_enabled:=false
var intent_trace: Array=[]

func trace_intent(event: String, detail: Dictionary={}) -> void:
	if not trace_enabled: return
	var entry: Dictionary={"event":event,"time":game.elapsed,"moves":game.moves,"epoch":input_epoch,"selected":game.selected,"queued_source":queued_source_id}
	entry.merge(detail); intent_trace.append(entry)
	if intent_trace.size()>512: intent_trace.pop_front()

func clear_inputs(cancel_undo: bool=true) -> void:
	for intent in input_queue: trace_intent("cancelled",{"intent":intent.duplicate(),"reason":"lifecycle_or_undo"})
	input_queue.clear(); queued_source_id=0; input_epoch+=1
	if cancel_undo:undo_pending=false
	sync_queue_feedback()

func sync_queue_feedback() -> void:
	# Intent remains internal. Available sources use the existing selection lift;
	# busy sources stay parked, with ordinary status text instead of a badge.
	pass

func queue_click(index: int) -> void:
	var id: int=game.bottle_nodes[index].get_instance_id()
	if queued_source_id==id:
		trace_intent("cancelled",{"source_id":id,"reason":"repeat_pending_source"})
		queued_source_id=0; game._feedback(game.t("已取消排队选择","Queued selection cancelled")); return
	if queued_source_id==0:
		if input_queue.size()>=MAX_QUEUED_POURS:
			game._feedback(game.t("最多排队3步，请稍候","Queue full (3). Please wait.")); return
		queued_source_id=id; trace_intent("selected_pending",{"source_id":id})
		game._feedback(game.t("已选下一步源瓶，请点目标瓶","Next source selected. Tap its target.")); return
	var intent: Dictionary={"source_id":queued_source_id,"target_id":id,"epoch":input_epoch}
	queued_source_id=0
	# A maximal pour already commits its inventory. Repeating that exact busy
	# pair cannot pour again unless an intervening queued operation will change
	# one of its bottles. Do not let spam consume a slot needed by another move.
	var intervening:=input_queue.any(func(q):return q.source_id in [intent.source_id,intent.target_id] or q.target_id in [intent.source_id,intent.target_id])
	if not intervening:
		for tx in game.transactions:
			if tx.source_id==intent.source_id and tx.target_id==intent.target_id and tx.epoch==intent.epoch:
				trace_intent("cancelled",{"intent":intent.duplicate(),"reason":"duplicate_active_intent"})
				return
	if input_queue.size()>=MAX_QUEUED_POURS:
		trace_intent("cancelled",{"intent":intent,"reason":"queue_full"})
		game._feedback(game.t("最多排队3步，请稍候","Queue full (3). Please wait.")); return
	# Retry metadata (e.g. blocked_serials) is not part of the user's identity.
	# A repeated click pair must also deduplicate an existing route-wait intent.
	if not input_queue.is_empty() and input_queue[-1].source_id==intent.source_id and input_queue[-1].target_id==intent.target_id and input_queue[-1].epoch==intent.epoch:
		trace_intent("cancelled",{"intent":intent,"reason":"duplicate_intent"})
		game._feedback(game.t("这一步已排队","That pour is already queued")); return
	input_queue.append(intent)
	trace_intent("queued",{"intent":intent.duplicate()})
	game._feedback(game.t("已排队 %d 步","%d pours queued") % input_queue.size())

func execute_next() -> void:
	if game.state!="playing" or undo_pending: return
	# FIFO for shared bottles, while disjoint intentions may pass a blocked pair.
	var reserved: Array=[]
	for intent in input_queue.duplicate():
		var a:=-1; var b:=-1
		for i in game.bottle_nodes.size():
			var id: int=game.bottle_nodes[i].get_instance_id()
			if id==int(intent.source_id): a=i
			if id==int(intent.target_id): b=i
		var corridor_busy:=false
		for tx in game.transactions:
			# A serial reserves the moving glass/stream corridor only while its
			# pour animator is active. Later target feedback remains protected by
			# bottle_busy() and the normal route/stream preflight on retry.
			if intent.get("blocked_serials",[]).has(tx.serial) and tx.stage=="pour" and tx.animator.busy:corridor_busy=true
		if a>=0 and b>=0 and (corridor_busy or bottle_busy(a) or bottle_busy(b) or reserved.has(a) or reserved.has(b)):
			reserved.append(a); reserved.append(b); continue
		var original_index:int=input_queue.find(intent)
		input_queue.erase(intent)
		if intent.epoch!=input_epoch or a<0 or b<0 or not game.rules.can_pour(a,b):
			trace_intent("cancelled",{"intent":intent.duplicate(),"reason":"stale_identity_or_rule"})
			game._feedback(game.t("局面已改变，该排队步骤已取消","Board changed; queued pour cancelled.")); continue
		if game.rules.bottle_lock_remaining(a,game.display_delivered.size())>0 or game.rules.bottle_lock_remaining(b,game.display_delivered.size())>0:
			trace_intent("cancelled",{"intent":intent.duplicate(),"reason":"receipt_not_presented"})
			game._feedback(game.t("瓶子尚未解锁，该排队步骤已取消","Bottle still locked; queued pour cancelled.")); continue
		var selection: int=game.selected
		var moves_before:int=game.moves
		game.selected=a; commit_selection(b)
		if game.moves==moves_before:
			# A failed preflight may requeue this exact intention. Keep its
			# original position and reserve its bottles for this scan, so only
			# independent intentions can bypass it.
			reserved.append(a);reserved.append(b)
			if not input_queue.is_empty():
				var retry:Dictionary=input_queue[-1]
				if retry.source_id==intent.source_id and retry.target_id==intent.target_id and retry.epoch==intent.epoch:
					input_queue.pop_back();input_queue.insert(mini(original_index,input_queue.size()),retry)
		if selection>=0 and selection!=a and selection!=b and not bottle_busy(selection): game.selected=selection
	sync_queue_feedback()

func _init(owner_view) -> void:
	game=owner_view

func busy() -> bool:
	return not game.transactions.is_empty() or not game.receipts.is_empty()

func bottle_busy(index: int) -> bool:
	# Includes the source's return trip, not just its liquid-emission phase.
	if game.bottle_nodes[index].visual.transaction_busy: return true
	for tx in game.transactions:
		if int(tx.target)==index or (int(tx.source)==index and tx.stage=="pour"): return true
	for receipt in game.receipts:
		if int(receipt.bottle)==index: return true
	return false

func sync(update_layers: bool=true) -> void:
	for i in game.bottle_nodes.size():
		var node=game.bottle_nodes[i]
		if update_layers and not node.visual.transaction_busy:
			node.visual.unknown_layers=game.rules.unknown[i].duplicate()
		if update_layers: node.layers=game.rules.bottles[i].duplicate()
		node.selected=i==game.selected
		if is_instance_valid(node.visual.delivered_layers):
			node.visual.delivered_layers.set_surface_selected(node.selected)
			node.visual.delivered_layers.cover_upper_layers=false
			# Approved fitted cloth occludes the intact original glass and liquid.
			# No extra mask is used to manufacture a tighter registration.
		var cover=node.visual.get_node_or_null("BottleCover")
		if is_instance_valid(cover):
			cover.configure(game.rules.mask_progress(i,game.display_delivered.size()),game.locale,game.rules.bottle_lock_remaining(i,game.display_delivered.size())>0)
		# A still-visible receipt bottle must acknowledge input too. Its queued
		# intent is validated against final authoritative state before execution.
		node.locked=game.state!="playing"
		if not node.visual.transaction_busy:
			node.position=node.get_meta("rest_position")-Vector2(0,22 if node.selected else 0)
		node.visible=not game.display_delivered.has(i)
		if i==game.rules.bonus_index() and not game.rules.bonus_unlocked:
			node.locked=true; node.modulate.a=1.0
		else: node.modulate.a=1.0
		node.queue_redraw()
	sync_queue_feedback()

func new_animator(source_index: int):
	var result=game.animator
	if not game.transactions.is_empty():
		result=Animator.new(); game.board.add_child(result); result.z_index=20
		for key in ["safe_row_route","multi_row_route","multi_row_ceiling_world_y","upper_route_floor_world_y","multi_row_transit_lanes_world_x","route_canvas_world_rect","row_clearance_local","hover_clearance_local","swept_row_clearance_local"]:
			result.set(key,game.animator.get(key))
	result.auto_seal=false; result.set_process(false)
	result.relaxed_timing=true
	result.responsive_timing=true
	result.safe_row_route=true
	result.hover_clearance_local=470.0
	if result.multi_row_route:
		# Collected upper bottles open real transit columns. Separator lanes alone
		# are too narrow on dense boards; test clearance against standing glass.
		var candidates:=PackedFloat32Array(game.animator.multi_row_transit_lanes_world_x)
		var moving=game.bottle_nodes[source_index].visual
		var half_width: float=moving.presentation_bounds().size.x*moving.global_scale.x*0.5
		for i in game.bottle_nodes.size():
			var node=game.bottle_nodes[i]
			if game.display_delivered.has(i) and node.visual.mouth_world().y<result.multi_row_ceiling_world_y+100.0: candidates.append(node.visual.global_position.x)
		var clear:=PackedFloat32Array()
		for x in candidates:
			var blocked:=false
			for i in game.bottle_nodes.size():
				var node=game.bottle_nodes[i]
				if i==source_index or game.display_delivered.has(i) or node.visual.mouth_world().y>result.multi_row_ceiling_world_y+100.0: continue
				var width: float=node.visual.presentation_bounds().size.x*node.visual.global_scale.x*0.5
				if absf(x-node.visual.global_position.x)<half_width+width+8: blocked=true; break
			if not blocked: clear.append(x)
		if not clear.is_empty(): result.multi_row_transit_lanes_world_x=clear

	result.visual_speed=minf(1.35,1.0+0.12*rapid_count)
	result.board_bottles=game.bottle_nodes.duplicate()
	result.board_text_yields=true
	result.board_fixed_hud=game.hud.persistent_obstacles()
	# Crop only the moving source at the side edges on two-row boards. Genuine
	# order cards, target glass and the on-screen short water segment stay protected.
	result.board_side_crop=160.0*game.board.get_global_transform().get_scale().x if game.bottle_nodes.size() in range(6,11) else 0.0
	result.concurrent_animators=[]
	for tx in game.transactions:
		if tx.stage=="pour" and tx.animator.busy:
			tx.animator.prepare_route()
			result.concurrent_animators.append(tx.animator)
	result.board_upper_count=preload("res://scripts/water_sort/order_gameplay_layout.gd").configuration(game.bottle_nodes.size()).counts[0] if result.multi_row_route else 0
	return result

func select(index: int) -> void:
	trace_intent("click",{"bottle":index,"state":game.state})
	if game.state!="playing" or index<0 or index>=game.bottle_nodes.size(): return
	if undo_pending:
		trace_intent("rejected",{"bottle":index,"reason":"undo_barrier"})
		game._feedback(game.t("正在等待已提交动作结束后撤回","Waiting for committed actions before undo.")); return
	if queued_source_id!=0 or bottle_busy(index) or queued_bottle(index):
		if queued_source_id==0 and game.selected>=0:
			queued_source_id=game.bottle_nodes[game.selected].get_instance_id()
			game.selected=-1; sync()
		queue_click(index)
		execute_next()
		sync_queue_feedback()
		return
	var previous_moves:int=game.moves
	var previous_selected:int=game.selected
	commit_selection(index)
	if game.moves==previous_moves:
		trace_intent("selected" if game.selected>=0 and game.selected!=previous_selected else "selection_feedback",{"bottle":index,"selection":game.selected,"message":game.labels.Status.text})

func queued_bottle(index: int) -> bool:
	var id: int=game.bottle_nodes[index].get_instance_id()
	for intent in input_queue:
		if int(intent.source_id)==id or int(intent.target_id)==id: return true
	return false

func commit_selection(index: int) -> void:
	var g=game
	if g.state!="playing" or index<0 or index>=g.bottle_nodes.size() or bottle_busy(index) or g.rules.delivered.has(index): return
	var locked_orders: int=g.rules.bottle_lock_remaining(index,g.display_delivered.size())
	if locked_orders>0:
		g.mask_hint_text=g.hud.mask_caption(index,locked_orders)
		g._feedback(g.mask_hint_text); g.message_remaining=4.0
		return
	var guide_target:int=g.tutorial_target()
	if guide_target>=0 and index!=guide_target and index!=g.selected:
		g._feedback(g.t("先跟着手指完成第一份订单","Follow the pointer for your first order")); return
	if index==g.rules.bonus_index() and not g.rules.bonus_unlocked:
		g.open_reward("bottle"); return
	if g.rules.complete(index):
		g.selected=-1; g.message_remaining=0; g._refresh()
		g._feedback(g.t("已装满，等待匹配订单","Ready for a matching order"))
		return
	if g.selected==index: g.selected=-1; g._refresh(); return
	if g.selected<0:
		if g.rules.bottles[index].is_empty(): g._feedback(g.t("先选有颜色的瓶子","Choose a bottle with liquid first"),index); return
		g.selected=index; g.message_remaining=0; g._refresh(); return
	if bottle_busy(g.selected) or not g.rules.can_pour(g.selected,index):
		# An incompatible second tap is a source change, not a sticky failed pour.
		# Completed waiting bottles are sealed and cannot become a new source.
		g.selected=index if not g.rules.bottles[index].is_empty() and not g.rules.complete(index) else -1
		g.message_remaining=0; g._refresh(); return
	var before: Dictionary=g.rules.snapshot()
	var source: int=g.selected
	var amount: int=g.rules.pour(source,index)
	if amount<=0: return
	var previous_rapid:int=rapid_count
	var previous_valid:float=last_valid_time
	var gap: float=g.elapsed-last_valid_time
	rapid_count=mini(3,rapid_count+1) if gap>=0 and gap<0.65 else 0
	last_valid_time=g.elapsed
	g.history.append({"snapshot":before,"moves":g.moves})
	g.moves+=1; g.selected=-1; g.message_remaining=0
	g.pour_from=source; g.pour_to=index
	sync(false)
	var anim=new_animator(source)
	commit_serial+=1
	var tx := {"source":source,"target":index,"source_id":g.bottle_nodes[source].get_instance_id(),"target_id":g.bottle_nodes[index].get_instance_id(),"serial":commit_serial,"epoch":input_epoch,"stage":"pour","age":0.0,"animator":anim,"full":g.rules.complete(index)}
	g.transactions.append(tx)
	var target=g.bottle_nodes[index].visual
	target.seal_duration=SEAL; target.seal_drop_distance=22.0
	var accepted: bool=anim.play(g.bottle_nodes[source].visual,target,before.bottles[source],before.bottles[index],g.rules.bottles[source],g.rules.bottles[index])
	if accepted: anim.prepare_route()
	trace_intent("planned",{"serial":commit_serial,"source":source,"target":index,"cpu_ms":anim.board_plan_ms,"failed":not accepted or anim.board_path_failed})
	if not accepted or anim.board_path_failed:
		# Preflight is synchronous: no frame/callback can observe a half-admitted
		# move. A contested route remains an intention, not a counted pour.
		var suppress:bool=g.suppress_animation_completion
		g.suppress_animation_completion=true;anim.cancel(false);g.suppress_animation_completion=suppress
		g.transactions.erase(tx)
		g.rules.restore(before);g.history.pop_back();g.moves-=1
		rapid_count=previous_rapid;last_valid_time=previous_valid
		var blockers:Array=[]
		for prior in g.transactions:
			if prior.animator.busy:blockers.append(prior.serial)
		if not blockers.is_empty() and input_queue.size()<MAX_QUEUED_POURS:
			var intent:Dictionary={"source_id":tx.source_id,"target_id":tx.target_id,"epoch":input_epoch,"blocked_serials":blockers}
			input_queue.append(intent);trace_intent("queued",{"intent":intent.duplicate(),"reason":"crossing_route"})
			g._feedback(g.t("已接收，当前倾倒完成后继续","Accepted; continuing when the current pour finishes."))
		else:
			trace_intent("cancelled",{"source":source,"target":index,"reason":"no_safe_route"})
			g._feedback(g.t("当前倾倒空间不足，请选择另一对瓶子","Not enough pouring space; choose another pair."))
		if anim!=g.animator:anim.queue_free()
		g._refresh();return
	trace_intent("executed",{"source":source,"target":index,"source_id":tx.source_id,"target_id":tx.target_id,"serial":commit_serial,"amount":amount,"route_delay":anim.route_delay})
	queue_events()
	g._refresh()
	if anim.route_delay>0.0:
		trace_intent("waiting_route",{"serial":commit_serial,"seconds":anim.route_delay})
		g._feedback(g.t("已接收，等交叉路线空闲后继续","Accepted; continuing when the crossing path clears."))

func queue_events() -> void:
	for event in game.rules.last_events:
		var receipt: Dictionary=event.duplicate(true)
		receipt.merge({"stage":"queued","age":0.0,"visual":null,"home":Vector2.ZERO,"scale":Vector2.ONE})
		game.receipts.append(receipt)
	game.rules.last_events.clear()

func release_transaction(tx: Dictionary) -> void:
	trace_intent("released",{"serial":tx.serial,"reason":"lifecycle" if clearing else "presentation_finished"})
	var visual=game.bottle_nodes[int(tx.target)].visual
	visual.transaction_busy=false; visual.settle_strength=0; visual.queue_redraw()
	if tx.full: visual.sync_seal_immediate(true)
	game.transactions.erase(tx)
	if tx.animator!=game.animator: tx.animator.queue_free()
	else: game.animator.phase="idle"

func advance(delta: float) -> void:
	var g=game
	for node in g.bottle_nodes:
		if is_instance_valid(node.visual.delivered_layers): node.visual.delivered_layers.advance_surface(delta)
	for tx in g.transactions.duplicate():
		var anim=tx.animator
		var visual=g.bottle_nodes[int(tx.target)].visual
		match tx.stage:
			"pour":
				anim.set_paused(false); anim.advance(delta)
				if anim.elapsed>0 and not tx.get("started",false):
					tx.started=true;trace_intent("started",{"serial":tx.serial,"source":tx.source,"target":tx.target})
				if not anim.busy:
					if not tx.full: release_transaction(tx)
					else:
						tx.stage="settle"; tx.age=0.0; visual.transaction_busy=true
						visual.sync_seal_immediate(false); visual.settle_strength=1.0
			"settle":
				tx.age+=delta; visual.settle_clock=tx.age
				visual.settle_strength=1.0-clampf(tx.age/SETTLE,0,1); visual.queue_redraw()
				var skin=visual.delivered_layers
				var surface_finished: bool=not is_instance_valid(skin) or (not skin.receiving and (not skin.had_contact or skin.tail_age>=skin.TAIL_DURATION))
				if tx.age+0.00001>=SETTLE and surface_finished:
					tx.stage="celebrate"; tx.age=0.0; anim.phase="celebrate"
					g.hud.full_ready(int(tx.target))
			"celebrate":
				tx.age+=delta
				if tx.age+0.00001>=CELEBRATE:
					tx.stage="seal"; tx.age=0.0; anim.phase="seal"
					visual.sample_seal(0.0)
			"seal":
				tx.age+=delta; visual.sample_seal(tx.age/SEAL)
				if tx.age+0.00001>=SEAL:
					tx.stage="ready_hold"; tx.age=0.0; anim.phase="ready_hold"
			"ready_hold":
				tx.age+=delta
				if tx.age+0.00001>=READY_HOLD: release_transaction(tx)
	start_ready_receipts()
	for receipt in g.receipts.duplicate():
		if receipt.stage=="queued": continue
		receipt.age+=delta
		var slot: int=receipt.slot
		match receipt.stage:
			"flight":
				var p:=clampf(receipt.age/FLIGHT,0,1)
				var smooth:=p*p*(3.0-2.0*p)
				var visual=receipt.visual
				visual.global_position=receipt.home.lerp(g.hud.receiving_anchor(slot),smooth)+Vector2(0,-55*sin(p*PI))
				visual.scale=receipt.scale.lerp(g.hud.receiving_scale(),smooth)
				g.hud.slot_state(slot,"flight",p)
				# Different slots may fly concurrently, but reveal/unlock uses the
				# original committed receipt prefix, including specified-color masks.
				if p>=1 and int(receipt.completed)==g.display_delivered.size()+1:
					g.display_delivered.append(int(receipt.bottle))
					trace_intent("receipt_arrived",{"bottle":receipt.bottle,"slot":receipt.slot,"completed":receipt.completed})
					restore_flight(receipt); receipt.stage="check"; receipt.age=0.0
					g.hud.slot_state(slot,"check",0.0)
					g._refresh()
			"check":
				g.hud.slot_state(slot,"check",clampf(receipt.age/CHECK,0,1))
				if receipt.age+0.00001>=CHECK:
					g.display_slots[slot]=receipt.slots_after[slot]
					if str(g.display_slots[slot]).is_empty(): finish_receipt(receipt)
					else:
						receipt.stage="replace"; receipt.age=0.0; g.hud.slot_state(slot,"replace",0.0)
			"replace":
				g.hud.slot_state(slot,"replace",clampf(receipt.age/REPLACE,0,1))
				if receipt.age+0.00001>=REPLACE: finish_receipt(receipt)
	g.deliveries=g.receipts.filter(func(item): return item.stage!="queued")
	g.flight_time=float(g.deliveries[0].age) if not g.deliveries.is_empty() else 0.0
	g.pour_remaining=0.0
	for tx in g.transactions:
		g.pour_remaining=maxf(g.pour_remaining,float(tx.animator.remaining_seconds()))
	if not undo_pending: execute_next()
	if not busy():
		if undo_pending:
			undo_pending=false; g.undo_move(); return
		g._finish_pour()
		if g.state=="playing": execute_next()
		else: clear_inputs()
	else: sync()
	g._sync_motion_hud()

func start_ready_receipts() -> void:
	var reserved: Array=[]
	for receipt in game.receipts:
		var slot: int=receipt.slot
		if reserved.has(slot): continue
		reserved.append(slot)
		if receipt.stage!="queued": continue
		var waiting := false
		for tx in game.transactions:
			if int(tx.target)==int(receipt.bottle) or (int(tx.source)==int(receipt.bottle) and tx.animator.busy): waiting=true
		if waiting: continue
		var visual=game.bottle_nodes[int(receipt.bottle)].visual
		receipt.visual=visual; receipt.home=visual.global_position; receipt.local_home=visual.position; receipt.scale=visual.scale
		visual.transaction_busy=true; visual.sync_seal_immediate(true); visual.z_index=40
		receipt.stage="flight"; receipt.age=0.0
		game.hud.slot_state(slot,"flight",0.0)

func restore_flight(receipt: Dictionary) -> void:
	if is_instance_valid(receipt.visual):
		# Parent row may make room during another pour; restore the bottle's local
		# seat, not a world position captured while that row was displaced.
		receipt.visual.position=receipt.local_home; receipt.visual.scale=receipt.scale
		receipt.visual.modulate=Color.WHITE; receipt.visual.z_index=0
		receipt.visual.transaction_busy=false
		receipt.visual=null

func finish_receipt(receipt: Dictionary) -> void:
	if not game.receipts.has(receipt): return
	game.hud.slot_state(int(receipt.slot),"idle",0)
	game.receipts.erase(receipt)

func clear() -> void:
	if clearing: return
	clear_inputs()
	last_valid_time=-100.0; rapid_count=0
	clearing=true
	var prior: bool=game.suppress_animation_completion
	game.suppress_animation_completion=true
	for tx in game.transactions.duplicate():
		tx.animator.cancel(true)
		release_transaction(tx)
	for receipt in game.receipts: restore_flight(receipt)
	game.receipts.clear(); game.deliveries.clear(); game.flight_time=0; game.pour_remaining=0
	if is_instance_valid(game.hud): game.hud.clear_states()
	game.suppress_animation_completion=prior
	clearing=false
	game._sync_motion_hud()
