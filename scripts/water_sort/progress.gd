extends "res://scripts/shell/campaign_progress.gd"
## Water-sort-only adapter for the existing menu API. It never reads cargo saves.
## A best record is ONE run: fewest moves, then shortest time on a tie.
const WATER_FILE := "water_sort_progress_v1.json"
const WATER_CAMPAIGN := "water_sort_v1"
const NativeReceipt=preload("res://scripts/services/native_reward_receipt.gd")
const RewardOwner=preload("res://scripts/water_sort/reward_controller.gd")
const WaterRules = preload("res://scripts/experiments/water_sort_v1/rules.gd")
const OrderRules = preload("res://scripts/water_sort/order_rules.gd")
var order_mode := false
var reader: Callable
var writer: Callable
var campaign := WATER_CAMPAIGN
var attempt_prefix := "water_sort:"
var strict_content := false
var board_digests: Array[String] = []
var bound_levels: Array = []
var pack_digest := ""
var compatible_prefix_bindings: Array = []
var accepted_pack_counts: Dictionary = {}
var compatible_order_packs: Array = []
var known_order_boards: Array = []
var last_content_update := ""
var preserve_legacy_attempts:=false

func _init(test_reader: Callable = Callable(), test_writer: Callable = Callable(), configuration: Dictionary = {}) -> void:
	storage_file = str(configuration.get("storage_file",WATER_FILE))
	preserve_legacy_attempts=bool(configuration.get("preserve_legacy_attempts",false))
	campaign = str(configuration.get("campaign",WATER_CAMPAIGN))
	attempt_prefix = str(configuration.get("attempt_prefix","water_sort:"))
	strict_content = bool(configuration.get("strict_content",false))
	order_mode = bool(configuration.get("order_mode",false))
	compatible_order_packs=configuration.get("compatible_order_packs",[]).duplicate()
	compatible_prefix_bindings = configuration.get("compatible_prefixes",[]).duplicate(true)
	level_count = 5
	reader = test_reader
	writer = test_writer
	data = {"schema":2,"campaign":campaign,"completed":[],"records":{},"settlements":{},"serial":0,"pending_attempt":{},"locale":"zh","music":true,"sound":true,"vibration":true}

func bind_level_pack(levels: Array) -> void:
	super.bind_level_pack(levels)
	bound_levels = levels.duplicate(true)
	board_digests.clear()
	known_order_boards.clear()
	var ordered: Array = []
	for level in levels:
		var board: Dictionary={"capacity":4,"bottles":level.bottles} if order_mode else WaterRules.create(level)
		var digest := JSON.stringify([str(level.id),board.capacity,board.bottles]).sha256_text()
		# bottle_locks is an interaction correction, not a new inventory/save
		# format. Keep accepted board digests and all existing checkpoints intact.
		if order_mode: digest=JSON.stringify([digest,level.get("orders",[]),level.get("masks",[]),level.get("bonus_bottle",false)]).sha256_text()
		if order_mode and not level.get("unknown_layers",[]).is_empty(): digest=JSON.stringify([digest,level.unknown_layers]).sha256_text()
		board_digests.append(digest)
		ordered.append(digest)
		known_order_boards.append({digest:level.duplicate(true)})
	pack_digest = JSON.stringify(ordered).sha256_text()
	accepted_pack_counts = {pack_digest:level_count}
	for path in compatible_order_packs:
		var old_levels: Array=JSON.parse_string(FileAccess.get_file_as_string(path)).levels
		if old_levels.size()!=level_count: continue
		var old_digests: Array=[]
		for i in old_levels.size():
			var source: Dictionary=old_levels[i]
			var digest := JSON.stringify([str(source.id),4,source.bottles]).sha256_text()
			digest=JSON.stringify([digest,source.get("orders",[]),source.get("masks",[]),source.get("bonus_bottle",false)]).sha256_text()
			if not source.get("unknown_layers",[]).is_empty(): digest=JSON.stringify([digest,source.unknown_layers]).sha256_text()
			old_digests.append(digest)
			# The same board may have newer non-persisted interaction metadata.
			# Historical aliases must not overwrite its current definition.
			if not known_order_boards[i].has(digest): known_order_boards[i][digest]=source
		accepted_pack_counts[JSON.stringify(old_digests).sha256_text()]=level_count
	for binding in compatible_prefix_bindings:
		if not binding is Dictionary or binding.get("campaign","")!=campaign or not _whole(binding.get("level_count"),1): continue
		var count: int=int(binding.level_count)
		if count>=level_count or not binding.get("board_digests") is Array or not binding.get("level_ids") is Array: continue
		if binding.board_digests.size()!=count or binding.level_ids.size()!=count: continue
		if JSON.stringify(binding.board_digests).sha256_text()!=binding.get("pack_digest",""): continue
		var identical := true
		for index in range(count):
			if board_digests[index]!=binding.board_digests[index] or level_ids[index]!=binding.level_ids[index]: identical=false; break
		if identical: accepted_pack_counts[str(binding.pack_digest)]=count
	# Initialize only brand-new memory. Rebinding an accepted settings-only
	# legacy save must not eagerly mutate its metadata before a successful save.
	if strict_content and not data.has("pack_digest"): data.pack_digest = pack_digest

func _valid_attempt_id(value: Variant) -> bool:
	if not value is String or not value.begins_with(attempt_prefix): return false
	var suffix: String = value.trim_prefix(attempt_prefix)
	return suffix.is_valid_int() and int(suffix)>0 and suffix==str(int(suffix))

func _attempt_within_serial(value: String, serial: int) -> bool:
	return _valid_attempt_id(value) and int(value.trim_prefix(attempt_prefix))<=serial

func _inventory(bottles: Array) -> Dictionary:
	var result: Dictionary = {}
	for bottle in bottles:
		for color in bottle: result[color] = int(result.get(color,0))+1
	return result

func checkpoint_matches_level(index: int, snapshot: Dictionary) -> bool:
	if order_mode:
		return index>=0 and index<bound_levels.size() and OrderRules.matches(attempt_level(index),snapshot)
	if not WaterRules.validation_errors(snapshot).is_empty(): return false
	if not strict_content: return true
	if index<0 or index>=bound_levels.size(): return false
	var original := WaterRules.create(bound_levels[index])
	return snapshot.capacity==original.capacity and snapshot.bottles.size()==original.bottles.size() and _inventory(snapshot.bottles)==_inventory(original.bottles)

func attempt_level(index: int) -> Dictionary:
	var pending: Dictionary=data.pending_attempt
	if order_mode and int(pending.get("index",-1))==index:
		return known_order_boards[index].get(pending.get("board_digest",""),bound_levels[index]).duplicate(true)
	return bound_levels[index].duplicate(true)

func restart_attempt_content() -> bool:
	if not order_mode or data.pending_attempt.is_empty(): return true
	var before: Dictionary=data.duplicate(true)
	var index: int=int(data.pending_attempt.index)
	var previous_snapshot:Dictionary=data.pending_attempt.get("snapshot",{})
	var fresh=OrderRules.new(bound_levels[index])
	# Assistance is an entitlement of this energy-paid attempt, not a move.
	# Preserve it while explicitly replacing the puzzle/visibility definition.
	if fresh.has_bonus():
		if previous_snapshot.get("bonus_unlocked",false):fresh.unlock("bottle")
		if previous_snapshot.get("slot_unlocked",false):fresh.unlock("slot")
	data.pending_attempt.board_digest=board_digests[index]
	data.pending_attempt.snapshot=fresh.snapshot()
	data.pending_attempt.moves=0;data.pending_attempt.seconds=0.0
	if save_progress(): return true
	data=before; return false

func update_pending_content() -> bool:
	last_content_update=""
	if not order_mode or data.pending_attempt.is_empty():return true
	var index:int=int(data.pending_attempt.index)
	if data.pending_attempt.get("board_digest","")==board_digests[index]:return true
	if preserve_legacy_attempts and _known_digest(index,str(data.pending_attempt.get("board_digest",""))):return true
	var before:Dictionary=data.duplicate(true)
	var pending:Dictionary=data.pending_attempt
	var saved:Dictionary=pending.get("snapshot",{})
	var target:Dictionary=bound_levels[index]
	var upgraded:Dictionary=saved.duplicate(true)
	# Historical definitions are decoding inputs only. Play uses current rules.
	if upgraded.has("bottles"):
		if target.get("unknown_layers",[]).is_empty():upgraded.erase("unknown")
		else:
			var original:Array=OrderRules.initial_unknown(target,target.bottles)
			if target.get("bonus_bottle",false):original.append([])
			var old_flags:Array=upgraded.get("unknown",[])
			var flags:Array=[]
			for i in upgraded.bottles.size():
				var visible:Array=[];visible.resize(upgraded.bottles[i].size());visible.fill(false)
				var remaining:int=old_flags[i].count(true) if i<old_flags.size() else 0
				remaining=mini(remaining,original[i].count(true) if i<original.size() else 0)
				remaining=mini(remaining,maxi(0,visible.size()-1))
				for j in remaining:visible[j]=true
				flags.append(visible)
			upgraded.unknown=flags
	var mode:="visibility"
	if not OrderRules.matches(target,upgraded):
		# Incompatible old inventory/order layouts must start the current board,
		# retaining the existing energy-paid identity and earned assistance.
		var fresh=OrderRules.new(target)
		if fresh.has_bonus():
			if saved.get("bonus_unlocked",false):fresh.unlock("bottle")
			if saved.get("slot_unlocked",false):fresh.unlock("slot")
		upgraded=fresh.snapshot();pending.moves=0;pending.seconds=0.0;mode="board"
	data.content_update_backup={"pending_attempt":before.pending_attempt.duplicate(true),"pack_digest":before.get("pack_digest","")}
	pending.board_digest=board_digests[index];pending.snapshot=upgraded
	if save_progress():last_content_update=mode;return true
	data=before;return false

func _known_digest(index: int, digest: String) -> bool:
	return known_order_boards[index].has(digest) if order_mode else board_digests[index]==digest

func load_progress() -> void:
	var saved: Dictionary = reader.call() if reader.is_valid() else Store.read(storage_file)
	if saved.get("ok",false) and _valid_water(saved.get("data",{})):
		data = saved.data.duplicate(true)
		data.vibration = data.get("vibration",true)
		# Godot JSON numbers decode as float. Array.has is type-sensitive;
		# restore the integral representation used by unlock/selection queries.
		# Validation above already rejects fractions and out-of-range numbers.
		data.completed=data.completed.map(func(number): return int(number))
	elif saved.get("ok",false) or saved.get("reason","") != "missing":
		load_error = "invalid_water_sort_progress"
		persistent = false # Preserve an unreadable save, never replace it silently.

func set_preference(key: String, value: Variant) -> void:
	if key != "vibration":
		super.set_preference(key,value)
		return
	if not value is bool: return
	var previous: bool = data.get("vibration",true)
	data.vibration = value
	if not save_progress():
		data.vibration = previous
		load_error = "preference_save_failed"

func has_seen_mechanic(id: String) -> bool:
	return data.get("seen_mechanics",[]).has(id)

func acknowledge_mechanic(id: String) -> bool:
	if id.is_empty(): return false
	if has_seen_mechanic(id): return true
	var before: Dictionary=data.duplicate(true)
	var seen: Array=data.get("seen_mechanics",[]).duplicate()
	seen.append(id); data.seen_mechanics=seen
	if save_progress(): return true
	data=before; return false

func save_progress() -> bool:
	if not persistent: return false
	# Append-only metadata upgrade is committed with the next real save, never
	# as a destructive reset or a separate write while merely loading a save.
	var candidate: Dictionary=data.duplicate(true)
	if strict_content:
		candidate.pack_digest=pack_digest
		candidate.pack_level_count=level_count
		if not _valid_water(candidate):
			load_error="invalid_water_sort_progress"
			return false
	var okay: bool = bool(writer.call(candidate.duplicate(true))) if writer.is_valid() else Store.write(storage_file,candidate)
	if okay: data=candidate
	load_error = "" if okay else "progress_save_failed"
	return okay

func _saved_pack_level_count(value: Dictionary) -> int:
	var count: int=int(accepted_pack_counts.get(value.get("pack_digest",""),0))
	if count<=0: return 0
	if value.has("pack_level_count") and (not _whole(value.pack_level_count,1) or int(value.pack_level_count)!=count): return 0
	return count

func _whole(value: Variant, minimum: int = 0) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) == floorf(float(value)) and value >= minimum

func _valid_water(value: Variant) -> bool:
	if not value is Dictionary or value.get("schema") != 2 or value.get("campaign") != campaign: return false
	if not value.get("completed") is Array or not value.get("records") is Dictionary or not value.get("settlements") is Dictionary or not value.get("pending_attempt") is Dictionary: return false
	var saved_level_count: int=_saved_pack_level_count(value) if strict_content else level_count
	if saved_level_count<=0: return false
	if not _whole(value.get("serial")) or value.get("locale") not in ["zh","en"] or not value.get("music") is bool or not value.get("sound") is bool: return false
	if value.has("vibration") and not value.vibration is bool: return false
	if value.has("seen_mechanics"):
		if not value.seen_mechanics is Array: return false
		var distinct: Array=[]
		for id in value.seen_mechanics:
			if not id is String or id.is_empty() or distinct.has(id): return false
			distinct.append(id)
	for number in value.completed:
		if not _whole(number,1) or number > saved_level_count: return false
		if number > 1 and not value.completed.has(number-1): return false
	for id in value.records:
		if not id is String or (not level_ids.is_empty() and not level_ids.has(id)): return false
		if strict_content and level_ids.find(id)>=saved_level_count: return false
		var record: Variant = value.records[id]
		if not record is Dictionary or not _whole(record.get("moves"),1) or not _valid_time(record.get("seconds")) or not record.get("attempt_id") is String: return false
		if strict_content and (not _attempt_within_serial(record.attempt_id,int(value.serial)) or not _known_digest(level_ids.find(id),record.get("board_digest",""))): return false
	for id in value.settlements:
		if not id is String or id.is_empty() or value.settlements[id] != true: return false
		if strict_content and not _attempt_within_serial(id,int(value.serial)): return false
	var pending: Dictionary = value.pending_attempt
	if not pending.is_empty():
		if not pending.get("id") is String or pending.id.is_empty() or not _whole(pending.get("index")) or pending.index >= saved_level_count: return false
		if strict_content and (not _attempt_within_serial(pending.id,int(value.serial)) or not _known_digest(int(pending.index),pending.get("board_digest",""))): return false
		if pending.has("board_action_sequence") and not _whole(pending.board_action_sequence):return false
		if pending.has("board_action_receipt"):
			var receipt:Variant=pending.board_action_receipt
			if not receipt is Dictionary or not receipt.get("request_id") is String or receipt.request_id.is_empty() or receipt.get("kind") not in ["shuffle","undo"] or not _whole(receipt.get("sequence"),1) or receipt.sequence!=pending.get("board_action_sequence"):return false
			if not receipt.get("after_digest") is String or receipt.after_digest.length()!=64:return false
		if pending.has("board_action_reward"):
			var reward:Variant=pending.board_action_reward
			if not reward is Dictionary or not reward.get("request_id") is String or reward.request_id.is_empty() or reward.get("kind") not in ["shuffle","undo"] or not _whole(reward.get("sequence")) or reward.sequence!=pending.get("board_action_sequence",0):return false
			if not reward.get("expected") is Dictionary or not reward.get("after") is Dictionary or reward.expected!=pending.get("snapshot") or not checkpoint_matches_level(int(pending.index),reward.after) or not _whole(reward.get("moves")) or not _valid_time(reward.get("seconds")):return false
		if pending.has("native_ad_receipts"):
			if not pending.native_ad_receipts is Dictionary:return false
			for request_id in pending.native_ad_receipts:
				var proof:Variant=pending.native_ad_receipts[request_id]
				if not NativeReceipt.valid(proof) or proof.request_id!=request_id or proof.attempt_id!=pending.id or proof.placement=="energy":return false
		if pending.has("native_ad_reward"):
			var reward:Variant=pending.native_ad_reward
			if not reward is Dictionary or not NativeReceipt.valid(reward.get("receipt")) or reward.receipt.attempt_id!=pending.id or reward.receipt.placement=="energy":return false
			if not reward.get("before") is Dictionary or not reward.get("after") is Dictionary or not NativeReceipt.same(reward.before,pending.get("snapshot",{})) or not checkpoint_matches_level(int(pending.index),reward.after):return false
			if not _whole(reward.get("moves")) or not _valid_time(reward.get("seconds")) or not _whole(reward.get("sequence")) or int(reward.sequence)!=int(pending.get("board_action_sequence",0)):return false
		if pending.has("snapshot"):
			if not pending.snapshot is Dictionary: return false
			if order_mode:
				if not OrderRules.matches(known_order_boards[int(pending.index)][pending.board_digest],pending.snapshot): return false
			elif not checkpoint_matches_level(int(pending.index),pending.snapshot): return false
			if not _whole(pending.get("moves")) or not _valid_time(pending.get("seconds")): return false
	return true

func _valid_time(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and value >= 0

func level_key(index: int) -> String:
	return str(level_ids[index]) if index >= 0 and index < level_ids.size() else "water_sort_%02d" % (index+1)

func reserve_attempt(index: int) -> String:
	if not unlocked(index): return ""
	var before: Dictionary = data.duplicate(true)
	data.serial = int(data.serial)+1
	var id := attempt_prefix+str(data.serial)
	data.pending_attempt = {"id":id,"index":index}
	if strict_content:
		data.pending_attempt.board_digest = board_digests[index]
		data.pack_digest = pack_digest
	if save_progress(): return id
	data = before
	return ""

func save_checkpoint(attempt_id: String, snapshot: Dictionary, moves: int, seconds: float) -> bool:
	if data.pending_attempt.get("id","") != attempt_id or not checkpoint_matches_level(int(data.pending_attempt.get("index",-1)),snapshot) or moves < 0 or not _valid_time(seconds): return false
	var before: Dictionary = data.duplicate(true)
	data.pending_attempt.snapshot = snapshot.duplicate(true)
	data.pending_attempt.moves = moves
	data.pending_attempt.seconds = seconds
	if save_progress(): return true
	data = before
	return false

func commit_board_action(attempt_id:String,request_id:String,kind:String,sequence:int,expected:Dictionary,after:Dictionary,moves:int,seconds:float,authority)->Dictionary:
	# Only the reward owner can authorize a consumed, identity-checked result.
	if authority==null or not authority.has_method("authorizes_board_action") or not authority.authorizes_board_action(self,request_id):return {"ok":false,"reason":"unverified_reward"}
	var pending:Dictionary=data.pending_attempt
	if pending.get("id")!=attempt_id or data.settlements.has(attempt_id):return {"ok":false,"reason":"stale_attempt"}
	if kind not in ["shuffle","undo"] or request_id.is_empty():return {"ok":false,"reason":"invalid_action"}
	var digest:=JSON.stringify(after,"",true).sha256_text()
	var receipt:Dictionary=pending.get("board_action_receipt",{})
	if receipt.get("request_id")==request_id:
		return {"ok":receipt.kind==kind and receipt.sequence==sequence+1 and receipt.after_digest==digest,"already_applied":true,"reason":"receipt_replay"}
	if int(pending.get("board_action_sequence",0))!=sequence or pending.get("snapshot",{})!=expected:return {"ok":false,"reason":"stale_board"}
	if pending.get("board_action_reward",{}).get("request_id")!=request_id:return {"ok":false,"reason":"reward_not_saved"}
	if not checkpoint_matches_level(int(pending.index),after) or moves<0 or not _valid_time(seconds):return {"ok":false,"reason":"invalid_board"}
	var prior:Dictionary=data.duplicate(true)
	pending.snapshot=after.duplicate(true);pending.moves=moves;pending.seconds=seconds
	pending.board_action_sequence=sequence+1
	pending.board_action_receipt={"request_id":request_id,"kind":kind,"sequence":sequence+1,"after_digest":digest}
	pending.erase("board_action_reward")
	if save_progress():return {"ok":true,"already_applied":false}
	data=prior
	return {"ok":false,"reason":"reward_save_failed"}

func save_board_action_reward(attempt_id:String,request_id:String,kind:String,sequence:int,expected:Dictionary,after:Dictionary,moves:int,seconds:float,authority)->bool:
	if authority==null or not authority.has_method("authorizes_board_action") or not authority.authorizes_board_action(self,request_id):return false
	var pending:Dictionary=data.pending_attempt
	if pending.get("id")!=attempt_id or data.settlements.has(attempt_id) or pending.get("snapshot",{})!=expected or int(pending.get("board_action_sequence",0))!=sequence:return false
	if request_id.is_empty() or kind not in ["shuffle","undo"] or not checkpoint_matches_level(int(pending.index),after) or moves<0 or not _valid_time(seconds):return false
	var reward:Dictionary={"request_id":request_id,"kind":kind,"sequence":sequence,"expected":expected.duplicate(true),"after":after.duplicate(true),"moves":moves,"seconds":seconds}
	if pending.has("board_action_reward"):return pending.board_action_reward==reward
	var prior:Dictionary=data.duplicate(true);pending.board_action_reward=reward
	if save_progress():return true
	data=prior;return false


func _native_authorized(receipt:Dictionary,authority)->bool:
	return NativeReceipt.valid(receipt) and authority is RewardOwner and NativeReceipt.same(NativeReceipt.identity(receipt),NativeReceipt.identity(authority.pending_operation())) and authority.authorizes_native_progress(self,receipt.request_id)

func stage_native_ad_reward(receipt:Dictionary,before:Dictionary,after:Dictionary,moves:int,seconds:float,sequence:int,authority)->bool:
	if not _native_authorized(receipt,authority):return false
	var pending:Dictionary=data.pending_attempt
	if pending.get("id")!=receipt.attempt_id or data.settlements.has(receipt.attempt_id):return false
	if pending.get("native_ad_receipts",{}).has(receipt.request_id):return pending.native_ad_receipts[receipt.request_id]==NativeReceipt.identity(receipt)
	if not NativeReceipt.same(pending.get("snapshot",{}),before) or int(pending.get("board_action_sequence",0))!=sequence:return false
	if not checkpoint_matches_level(int(pending.index),after) or moves<0 or not _valid_time(seconds):return false
	var entitlement:Dictionary={"receipt":NativeReceipt.identity(receipt),"before":before.duplicate(true),"after":after.duplicate(true),"moves":moves,"seconds":seconds,"sequence":sequence}
	if pending.has("native_ad_reward"):return NativeReceipt.same(pending.native_ad_reward,entitlement)
	var prior:=data.duplicate(true);pending.native_ad_reward=entitlement
	if save_progress():return true
	data=prior;return false

func commit_native_ad_reward(receipt:Dictionary,authority)->Dictionary:
	if not _native_authorized(receipt,authority):return {"ok":false,"reason":"unverified_reward"}
	var pending:Dictionary=data.pending_attempt
	if pending.get("id")!=receipt.attempt_id or data.settlements.has(receipt.attempt_id):return {"ok":false,"reason":"stale_attempt"}
	var applied:Dictionary=pending.get("native_ad_receipts",{})
	if applied.has(receipt.request_id):return {"ok":applied[receipt.request_id]==NativeReceipt.identity(receipt),"already_applied":true}
	var reward:Dictionary=pending.get("native_ad_reward",{})
	if reward.is_empty() or not NativeReceipt.same(reward.receipt,NativeReceipt.identity(receipt)) or not NativeReceipt.same(pending.get("snapshot",{}),reward.before) or int(pending.get("board_action_sequence",0))!=int(reward.sequence):return {"ok":false,"reason":"stale_board"}
	var prior:=data.duplicate(true)
	pending.snapshot=reward.after.duplicate(true);pending.moves=int(reward.moves);pending.seconds=float(reward.seconds)
	if receipt.placement in ["shuffle","undo"]:
		pending.board_action_sequence=int(reward.sequence)+1
		pending.board_action_receipt={"request_id":receipt.request_id,"kind":receipt.placement,"sequence":pending.board_action_sequence,"after_digest":JSON.stringify(reward.after,"",true).sha256_text()}
	pending.native_ad_receipts=applied.duplicate(true);pending.native_ad_receipts[receipt.request_id]=NativeReceipt.identity(receipt);pending.erase("native_ad_reward")
	if save_progress():return {"ok":true,"already_applied":false}
	data=prior;return {"ok":false,"reason":"reward_save_failed"}


func record_result(index: int, moves: int, seconds: float, attempt_id: String) -> bool:
	if data.settlements.has(attempt_id): return true
	if not unlocked(index) or moves <= 0 or not _valid_time(seconds) or data.pending_attempt.get("id","") != attempt_id or int(data.pending_attempt.get("index",-1)) != index: return false
	var before: Dictionary = data.duplicate(true)
	if not completed(index): data.completed.append(index+1)
	var key := level_key(index)
	var old: Dictionary = data.records.get(key,{})
	var result_digest: String=data.pending_attempt.get("board_digest",board_digests[index] if strict_content else "")
	var changed_board: bool=order_mode and not old.is_empty() and old.get("board_digest","")!=result_digest
	if changed_board:
		if not data.has("record_history"): data.record_history={}
		data.record_history[str(old.board_digest)]=old.duplicate(true)
	if old.is_empty() or changed_board or moves < int(old.moves) or (moves == int(old.moves) and seconds < float(old.seconds)):
		data.records[key] = {"moves":moves,"seconds":seconds,"attempt_id":attempt_id}
		if strict_content: data.records[key].board_digest = result_digest
	data.settlements[attempt_id] = true
	data.pending_attempt = {}
	if save_progress(): return true
	data = before
	return false

func best_record(index: int) -> Dictionary:
	if preserve_legacy_attempts and data.records.get(level_key(index),{}).get("board_digest","")!=board_digests[index]:return {}
	return data.records.get(level_key(index),{}).duplicate(true)
