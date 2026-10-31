extends "res://scripts/water_sort/order_action_dialog.gd"
signal completed
signal cancelled
signal retry_requested
var retry_mode:=false
var unavailable:=false
var placement:=""
var preparing:=false
func _ready() -> void:
	if retry_mode:
		_build_save_retry(); return
	dialog_kind="ad"
	heading=("广告暂不可用" if locale=="zh" else "Ad Unavailable") if unavailable else ("测试广告" if locale=="zh" else "Test Ad")
	body=("尚未接入正式广告服务。" if locale=="zh" else "No advertising SDK is connected.") if unavailable else ("仅用于开发测试" if locale=="zh" else "For development testing only")
	if preparing:
		heading="准备重排" if locale=="zh" else "Preparing shuffle"
		body="正在验证可解盘面，尚未开始广告。" if locale=="zh" else "Checking a solvable board. No ad has started."
	if not unavailable and not preparing:
		body+="\n"+({"bottle":"增加空瓶","slot":"增加订单位","energy":"体力回满","shuffle":"重排剩余颜色一次","undo":"撤回一步"}.get(placement,"") if locale=="zh" else {"bottle":"Extra bottle","slot":"Extra order slot","energy":"Refill energy","shuffle":"Shuffle remaining colors once","undo":"Undo one move"}.get(placement,""))
	super._ready()
	if not unavailable and not preparing:
		add_action("AdCompleted","已看完" if locale=="zh" else "Completed",func(): completed.emit())
	add_action("AdCancel",("返回" if locale=="zh" else "Back") if unavailable else ("不看，退出" if locale=="zh" else "Cancel"),func(): cancelled.emit())
	buttons.AdClose=add_close("AdClose",func():
		if not dispatched: dispatched=true; cancelled.emit())
func _build_save_retry()->void:
	name="RewardSaveRetryDialog";dialog_kind="reward_retry";mouse_filter=Control.MOUSE_FILTER_STOP
	var copy:Dictionary=preload("res://scripts/ui_restore/reward_retry_content.gd").for_locale(locale)
	heading=copy.title;body=copy.body
	shade=ColorRect.new();shade.color=Color("071d38",0.58);shade.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(shade)
	canvas=preload("res://scripts/ui_restore/reward_retry_view.gd").new();canvas.locale=locale;canvas.content=copy
	canvas.retry_requested.connect(func(): _dispatch_save_retry(false))
	canvas.dismiss_requested.connect(func(): _dispatch_save_retry(true))
	add_child(canvas);buttons=canvas.buttons;frame=canvas.frame;title_label=canvas.title_label;body_label=canvas.body_label
	resized.connect(_fit);_fit()
func _dispatch_save_retry(dismiss:bool)->void:
	if dispatched:return
	dispatched=true
	for button in buttons.values():button.disabled=true
	if dismiss:cancelled.emit()
	else:retry_requested.emit()
func _fit()->void:
	if not retry_mode:super._fit();return
	if not is_instance_valid(canvas):return
	var reference:=Vector2(320,600)
	if preload("res://scripts/ui_restore/screen_layout.gd").fit_modal(self,canvas,reference,shade):return
	shade.size=size;canvas.size=reference;canvas.scale=Vector2.ONE*minf(size.x/reference.x,size.y/reference.y)
	canvas.position=(size-reference*canvas.scale)*.5
func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		if not dispatched: dispatched=true; cancelled.emit()
