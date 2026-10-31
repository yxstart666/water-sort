extends Control
## One continuous sandbox transaction. No progress, rewards, energy or storage.
const Visual=preload("res://scripts/water_sort/art/bottle_visual.gd")
const Animator=preload("res://scripts/water_sort/art/pour_animator.gd")
const Assets=preload("res://scripts/water_sort/order_gameplay_assets.gd")
const HAND_ART=preload(Assets.RESTORE_ROOT+"accepted_tutorial_v4/assets/skins/blue_gold_refined/images/tutorial_hand.png")
const COMPLETE_ART=preload(Assets.RESTORE_ROOT+"accepted_tutorial_v4/assets/skins/blue_gold_refined/images/icon_complete.png")
const UI=preload("res://scripts/water_sort/reference2_ui.gd")
const Rules=preload("res://scripts/water_sort/order_rules.gd")
var sandbox
var paused:=false
var feedback:=""
var bottle_buttons: Array[Button]=[]
var locale:="zh"
var source
var target
var motion
var hand_layer: Node2D
var guide_pointer: Node2D
var guide_stage := ""
var clock:=0.0
var started:=false
var collected:=false
var stage:="tap_source"
var stage_age:=0.0
var any_explanation:Label
var caption_label:Label
var step_faces:Array[Control]=[]
var step_labels:Array[Label]=[]
const SCALE:=0.65
const ANY_EXPLANATION_ZH:="完成任意颜色订单，归零后移除布罩"
const ANY_EXPLANATION_EN:="Clear any-color orders. At zero, the cloth comes off."
const ANY_EXPLANATION_RECT:=Rect2(110,1160,720,240)
func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	var panel=UI.consolidated_panel(self,"HelpPanel",Rect2(68,350,804,1100)); panel.show_behind_parent=true
	var titles:Array=["1 选右瓶","2 倒绿色","3 满瓶"] if locale=="zh" else ["1 Pick","2 Pour","3 Fill"]
	for i in 3:
		var face:=UI.picture(self,"GuideStep"+str(i),"res://assets/colorpause_ui_20261030/sprites/cyan_normal_clean.webp",Rect2(95+i*250,405,230,90));face.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS;step_faces.append(face)
		var label:=UI.label(face,"GuideStepLabel",titles[i],Rect2(8,5,214,72),locale,60,UI.PANEL_INK);label.add_theme_font_override("font",preload("res://scripts/ui_restore/font_policy.gd").get_font("lxgw"));step_labels.append(label)
	for i in 2:
		var bottle:=Visual.new(); add_child(bottle); bottle.use_delivered_layers()
		bottle.scale=Vector2.ONE*SCALE
		if i==0: source=bottle
		else: target=bottle
	motion=Animator.new(); motion.auto_seal=false; motion.relaxed_timing=true
	motion.travel_lift=32; motion.hover_clearance_local=45
	add_child(motion); motion.set_process(false)
	hand_layer=Node2D.new(); hand_layer.z_index=30; add_child(hand_layer)
	guide_pointer=preload("res://scripts/water_sort/tutorial_hand.gd").create_pointer(940.0/390.0); hand_layer.add_child(guide_pointer)
	for i in 2:
		var button:=Button.new(); button.name="TargetBottle" if i==0 else "SourceBottle"
		button.position=Vector2(220 if i==0 else 590,650); button.size=Vector2(150,330)
		button.flat=true; button.z_index=40; button.focus_mode=Control.FOCUS_NONE
		for state_name in ["normal","hover","pressed","disabled","focus"]: button.add_theme_stylebox_override(state_name,StyleBoxEmpty.new())
		button.pressed.connect(func(): choose_bottle(i))
		add_child(button); bottle_buttons.append(button)
		preload("res://scripts/ui_restore/touch_hit.gd").attach(button)
	# Use the existing teaching panel's lower blank area; its two interactive
	# bottle targets, caption baseline1042 and return button1500 stay untouched.
	caption_label=preload("res://scripts/ui_restore/data_text.gd").label(self,"GuideCaption","",Rect2(150,990,640,170),60,true)
	caption_label.add_theme_color_override("font_color",UI.PANEL_INK)
	any_explanation=UI.label(self,"AnyUnlockExplanation",ANY_EXPLANATION_ZH if locale=="zh" else ANY_EXPLANATION_EN,ANY_EXPLANATION_RECT,locale,60,UI.PANEL_INK,true)
	any_explanation.add_theme_font_override("font",preload("res://scripts/ui_restore/font_policy.gd").get_font("lxgw"))
	_reset()
func _reset() -> void:
	if motion.busy: motion.cancel(true)
	source.position=Vector2(650,690); target.position=Vector2(280,690)
	source.scale=Vector2.ONE*SCALE; target.scale=Vector2.ONE*SCALE
	source.rotation=0; target.rotation=0; source.show(); target.show()
	source.set_layers(["red","red","green","green"]); target.set_layers(["green","green"])
	source.sync_seal_immediate(false); target.sync_seal_immediate(false)
	clock=0; started=false; collected=false; stage="tap_source"; stage_age=0.0
	sandbox=Rules.new({"bottles":[["green","green"],["red","red","green","green"]],"orders":[]})
	feedback=""; paused=false
	_update_guide(); _sync_step_headers()

func choose_bottle(index: int) -> void:
	if paused or stage not in ["tap_source","tap_target"]: return
	var expected:=1 if stage=="tap_source" else 0
	if index!=expected:
		feedback=("请先点击右侧高亮源瓶" if stage=="tap_source" else "请点击左侧目标瓶") if locale=="zh" else ("Tap the right bottle." if stage=="tap_source" else "Tap the left bottle to pour")
		queue_redraw(); return
	feedback=""
	if stage=="tap_source":
		source.position.y-=22
		source.delivered_layers.set_surface_selected(true); _set_stage("tap_target")
	else:
		var before: Dictionary=sandbox.snapshot()
		if sandbox.pour(1,0)!=2: return
		source.delivered_layers.set_surface_selected(false)
		started=motion.play(source,target,before.bottles[1],before.bottles[0],sandbox.bottles[1],sandbox.bottles[0])
		if started: _set_stage("pour")
	queue_redraw(); hand_layer.queue_redraw()

func set_paused(value: bool) -> void:
	paused=value; motion.set_paused(value); _update_guide()

func _notification(what: int) -> void:
	if what==NOTIFICATION_APPLICATION_FOCUS_OUT and is_instance_valid(motion): set_paused(true)
	elif what==NOTIFICATION_APPLICATION_FOCUS_IN and is_instance_valid(motion): set_paused(false)
func _set_stage(value: String) -> void:
	stage=value; stage_age=0.0; _update_guide(); _sync_step_headers()
func _process(delta: float) -> void:
	_update_guide()
	if paused: return
	clock+=delta; stage_age+=delta
	match stage:
		"pour":
			motion.advance(delta)
			if not motion.busy:
				source.position.y=690
				_set_stage("settle")
		"settle":
			if stage_age>=0.55: _set_stage("seal")
		"seal":
			target.sample_seal(minf(1.0,stage_age/0.30))
			if target.sealed: _set_stage("hold")
		"hold":
			if stage_age>=0.4:
				collected=true; _set_stage("done")
	source.delivered_layers.advance_surface(delta); target.delivered_layers.advance_surface(delta)
	queue_redraw(); hand_layer.queue_redraw()

func _draw() -> void:
	if not is_instance_valid(source): return
	var step:=0 if stage=="tap_source" else (1 if stage in ["tap_target","pour"] else 2)
	var font: Font=preload("res://scripts/ui_restore/font_policy.gd").get_font("lxgw")
	var captions: Array=["选右侧源瓶，把上层绿色倒入左瓶","只倒绿色，底部红色留在源瓶","左侧满绿完成，右侧保留半瓶红色"] if locale=="zh" else ["Choose the right bottle.","Green pours. Red stays.","Left full. Red stays right."]
	var caption: String=feedback if not feedback.is_empty() else captions[step]
	if feedback.is_empty() and stage=="tap_target": caption="点击左侧目标瓶，倒入绿色" if locale=="zh" else "Tap left to pour green."
	caption_label.text=caption
	if collected:
		draw_texture_rect(COMPLETE_ART,Rect2(target.position+Vector2(55,100),Vector2(68,68)),false)

func _sync_step_headers() -> void:
	var active:=0 if stage=="tap_source" else (1 if stage in ["tap_target","pour"] else 2)
	for i in step_faces.size():
		step_faces[i].modulate=Color.WHITE if i==active else Color(0.7,0.78,0.86,0.8)

func _update_guide() -> void:
	if not is_instance_valid(guide_pointer): return
	var phase: String=("source" if stage=="tap_source" else ("target" if stage=="tap_target" else "")) if not paused and is_visible_in_tree() else ""
	if phase==guide_stage and (phase.is_empty() or guide_pointer.visible): return
	guide_stage=phase
	if phase.is_empty(): guide_pointer.stop_guide(); return
	guide_pointer.show_phase(phase,func():
		var bottle=source if phase=="source" else target
		if not is_instance_valid(bottle) or not bottle.is_visible_in_tree(): return null
		var transform: Transform2D=hand_layer.get_global_transform().affine_inverse()*bottle.get_global_transform()
		return (transform*bottle.presentation_bounds()).get_center())

func set_guide_reduced_motion(enabled: bool) -> void:
	if is_instance_valid(guide_pointer): guide_pointer.set_motion_preference(enabled)
