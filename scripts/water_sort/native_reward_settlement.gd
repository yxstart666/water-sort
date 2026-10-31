extends RefCounted
## Native-specific durable receipt backend; shared router still owns eligibility.
const Receipt=preload("res://scripts/services/native_reward_receipt.gd")
const Orders=preload("res://scripts/water_sort/order_rules.gd")
static func prepare_bonus(router,placement:String)->void:
	var host=router.host;var game=host.game;var context:Dictionary=router._context()
	var after=Orders.new(game.rules.level);after.restore(game.rules.snapshot());after.unlock(placement)
	router._prepared={"placement":placement,"attempt_id":context.attempt_id,"scope":context.scope,"before":game.rules.snapshot(),"after":after.snapshot(),"history":game.history.duplicate(true),"moves":game.moves,"after_moves":game.moves,"seconds":game.elapsed,"sequence":int(host.progress.data.pending_attempt.get("board_action_sequence",0))}
static func settle(router,op:Dictionary)->Dictionary:
	var host=router.host
	if op.placement=="energy":
		if not host.energy.stage_native_refill(op,router):return {"ok":false,"reason":"reward_receipt_save_failed"}
		var result:Dictionary=host.energy.commit_native_refill(op,router)
		return {"ok":result.get("accepted",false),"reason":result.get("reason","")}
	var action:Dictionary=router._prepared
	if not router._action_matches(action):return {"ok":false,"reason":"stale_board"}
	if not host.progress.stage_native_ad_reward(op,action.before,action.after,int(action.after_moves),float(action.seconds),int(action.sequence),router):return {"ok":false,"reason":"reward_receipt_save_failed"}
	var result:Dictionary=host.progress.commit_native_ad_reward(op,router)
	if not result.get("ok",false):return result
	if not result.get("already_applied",false):
		if op.placement in ["bottle","slot"]:
			host.game.rules.unlock(op.placement)
		else:
			host.game.rules.restore(action.after);host.game.moves=int(action.after_moves)
			if op.placement=="shuffle":host.game.history.clear()
			elif not host.game.history.is_empty():host.game.history.pop_back()
			host.game.selected=-1;host.game.restore_presentation()
	return {"ok":true}
static func recover(router)->bool:
	if not router.is_native() or not router._operation.is_empty():return false
	var host=router.host;var energy_reward:Dictionary=host.energy.state.get("native_ad_reward",{})
	if not energy_reward.is_empty():
		if not Receipt.valid(energy_reward):return false
		router._operation=energy_reward.duplicate(true);router._operation.scope=router._context().scope
		router.save_failed.emit("saved_reward_ready");return true
	var reward:Dictionary=host.progress.data.pending_attempt.get("native_ad_reward",{})
	if reward.is_empty() or not host.game.visible or not Receipt.valid(reward.get("receipt")) or reward.receipt.attempt_id!=host.attempt_id:return false
	if not Receipt.same(host.game.rules.snapshot(),reward.before):return false
	var context:Dictionary=router._context();var game=host.game
	router._prepared={"placement":reward.receipt.placement,"attempt_id":context.attempt_id,"scope":context.scope,"before":game.rules.snapshot(),"history":game.history.duplicate(true),"moves":game.moves,"sequence":int(reward.sequence),"after":reward.after.duplicate(true),"after_moves":int(reward.moves),"seconds":float(reward.seconds)}
	router._operation=reward.receipt.duplicate(true);router._operation.scope=context.scope
	router.save_failed.emit("saved_reward_ready");return true
