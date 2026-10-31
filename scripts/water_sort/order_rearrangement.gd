extends RefCounted
## Bounded, data-only candidate search. Call on a worker, never from input/render.
## A failed search returns no board. Only a full OrderRules replay is a certificate.
const Orders=preload("res://scripts/water_sort/order_rules.gd")
var _level:Dictionary
var _deadline:int
var _node_limit:int
var _nodes:=0
var _seen:Dictionary={}
var _cancel:Callable
var _stopped:=false

func prepare(level:Dictionary,saved:Dictionary,seed_value:int,budget_msec:int=750,node_limit:int=12000,cancel:Callable=Callable())->Dictionary:
	var started:=Time.get_ticks_usec()
	_level=level.duplicate(true);_deadline=started+clampi(budget_msec,1,5000)*1000
	_node_limit=clampi(node_limit,1,50000);_nodes=0;_cancel=cancel;_stopped=false
	var original=Orders.new(_level)
	if not original.restore(saved):return {"ok":false,"reason":"invalid_board"}
	if original.is_solved():return {"ok":false,"reason":"already_solved"}
	var indices:Array=[];var inventory:Array=[]
	for i in original.bottles.size():
		if original.delivered.has(i):continue
		indices.append(i);inventory.append_array(original.bottles[i])
	if inventory.size()<2:return {"ok":false,"reason":"no_rearrangement"}
	var rng:=RandomNumberGenerator.new();rng.seed=seed_value
	var attempts:=0
	while attempts<32 and not _stop():
		attempts+=1
		var pool:=inventory.duplicate();var slots:=indices.duplicate()
		_shuffle(slots,rng)
		if attempts%3==0:
			_shuffle(pool,rng)
		else:
			# Near-sorted candidates reduce search work; swaps keep the action from
			# silently delivering whole orders before the player's next move.
			var colors:Array=[]
			for color in pool:
				if not colors.has(color):colors.append(color)
			_shuffle(colors,rng)
			pool.sort_custom(func(a,b):return colors.find(a)<colors.find(b))
			for unused in range(1+attempts%maxi(2,pool.size()/2)):
				var a:=rng.randi_range(0,pool.size()-1);var b:=rng.randi_range(0,pool.size()-1)
				var value=pool[a];pool[a]=pool[b];pool[b]=value
		var candidate:=saved.duplicate(true);var cursor:=0
		for index in slots:
			var count:int=candidate.bottles[index].size()
			candidate.bottles[index]=pool.slice(cursor,cursor+count);cursor+=count
		if candidate.bottles==saved.bottles:continue
		var rules=Orders.new(_level)
		if not rules.restore(candidate):continue
		rules.settle_orders()
		if rules.delivered!=saved.delivered:continue
		_seen.clear()
		# Reserve time for several candidates; an unlucky permutation must not
		# monopolize the global budget. Every proof still uses the same rules.
		var candidate_deadline:=mini(_deadline,Time.get_ticks_usec()+100000)
		var solved:Variant=_search(rules,0,candidate_deadline)
		if solved is Array and not _stop():
			var verified:=verify(_level,saved,candidate,solved)
			if verified:
				return {"ok":true,"snapshot":candidate,"solution":solved,"nodes":_nodes,"candidates":attempts,"elapsed_usec":Time.get_ticks_usec()-started}
	return {"ok":false,"reason":"cancelled" if _cancel.is_valid() and _cancel.call() else ("budget_exhausted" if _stopped else "no_certified_candidate"),"nodes":_nodes,"candidates":attempts,"elapsed_usec":Time.get_ticks_usec()-started}

static func verify(level:Dictionary,before:Dictionary,after:Dictionary,solution:Array)->bool:
	var rules=Orders.new(level)
	if not Orders.matches(level,before) or not rules.restore(after):return false
	for key in ["capacity","delivered","bonus_unlocked","slot_unlocked","unknown"]:
		if before.get(key)!=after.get(key):return false
	for i in before.bottles.size():
		if before.bottles[i].size()!=after.bottles[i].size():return false
		if before.delivered.has(i) and before.bottles[i]!=after.bottles[i]:return false
	if before.bottles==after.bottles or solution.is_empty():return false
	rules.settle_orders()
	if rules.delivered!=before.delivered:return false
	for move in solution:
		if not move is Array or move.size()!=2 or not move[0] is int or not move[1] is int:return false
		if not rules.can_pour(move[0],move[1]) or rules.pour(move[0],move[1])<=0:return false
	return rules.is_solved()

func _stop()->bool:
	if _nodes>=_node_limit or Time.get_ticks_usec()>=_deadline or (_cancel.is_valid() and _cancel.call()):_stopped=true
	return _stopped

func _shuffle(values:Array,rng:RandomNumberGenerator)->void:
	for i in range(values.size()-1,0,-1):
		var j:=rng.randi_range(0,i);var value=values[i];values[i]=values[j];values[j]=value

func _copy(state):
	# All inputs here were validated or produced by OrderRules.pour. Avoid
	# re-validating the whole level for every internal successor.
	var value=Orders.new()
	value.level=_level;value.bottles=state.bottles.duplicate(true)
	value.unknown=state.unknown.duplicate(true);value.delivered=state.delivered.duplicate()
	value.bonus_unlocked=state.bonus_unlocked;value.slot_unlocked=state.slot_unlocked
	return value

func _search(state,depth:int,candidate_deadline:int)->Variant:
	if _stop() or Time.get_ticks_usec()>=candidate_deadline or depth>=140:return null
	if state.is_solved():return []
	var key:=var_to_str([state.bottles,state.unknown,state.delivered])
	if _seen.has(key):return null
	_seen[key]=true;_nodes+=1
	var options:Array=[]
	for src in state.bottles.size():
		for dst in state.bottles.size():
			if _stop() or Time.get_ticks_usec()>=candidate_deadline:return null
			if not state.can_pour(src,dst):continue
			var next=_copy(state)
			next.pour(src,dst)
			var score:int=100*(next.delivered.size()-state.delivered.size())+10*int(next.complete(dst))+3*int(next.bottles[src].is_empty())+int(not state.bottles[dst].is_empty())
			options.append({"state":next,"src":src,"dst":dst,"score":score})
	options.sort_custom(func(a,b):return a.score>b.score)
	for option in options:
		var tail:Variant=_search(option.state,depth+1,candidate_deadline)
		if tail is Array:
			tail.push_front([option.src,option.dst]);return tail
	return null
