extends "res://scripts/water_sort/order_action_dialog.gd"
## No completion button. Native SDK alone supplies earned/receipt callbacks.
signal cancelled
signal retry_requested
signal privacy_requested
var status:Dictionary={}
var placement:=""
func _ready()->void:
	dialog_kind="ad"
	heading="原生测试广告" if locale=="zh" else "Native Test Ad"
	var reward:Dictionary={"bottle":"增加空瓶","slot":"增加订单位","energy":"体力回满","shuffle":"刷新剩余颜色一次","undo":"撤回一步"} if locale=="zh" else {"bottle":"Extra bottle","slot":"Extra order slot","energy":"Refill energy","shuffle":"Refresh remaining colors once","undo":"Undo one move"}
	var state:String=str(status.get("state","unavailable"))
	if status.get("preparing",false):body="正在验证可解盘面，尚未开始广告。\n" if locale=="zh" else "Checking a solvable board. No ad has started.\n"
	elif status.get("request_active",false):body="广告结果确认中，请稍候。\n" if locale=="zh" else "Waiting for the ad result.\n"
	elif status.get("ready",false):body="观看测试广告后获得：" if locale=="zh" else "Watch a test ad to receive: "
	elif state in ["initializing","initialized","loading"]:body="广告准备中，可稍后重试或返回。奖励仅在观看完成并确认后发放。\n" if locale=="zh" else "Preparing an ad. Retry shortly or go back. Rewards require confirmed completion.\n"
	else:body="广告暂不可用，可重试或返回。未发放奖励。\n" if locale=="zh" else "An ad is unavailable. Retry or go back. No reward was granted.\n"
	body+=str(reward.get(placement,""))
	super._ready()
	if not status.get("preparing",false) and not status.get("request_active",false):add_action("NativeAdRetry",("观看视频" if locale=="zh" else "Watch video") if status.get("ready",false) else ("重试加载" if locale=="zh" else "Retry loading"),func():retry_requested.emit())
	if status.get("privacy_required",false):add_action("NativePrivacy", "隐私选择" if locale=="zh" else "Privacy choices",func():privacy_requested.emit())
	add_action("NativeAdCancel","返回" if locale=="zh" else "Back",func():cancelled.emit())
	buttons.NativeAdClose=add_close("NativeAdClose",func():if not dispatched:dispatched=true;cancelled.emit())
func _unhandled_key_input(event:InputEvent)->void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		if not dispatched:dispatched=true;cancelled.emit()
