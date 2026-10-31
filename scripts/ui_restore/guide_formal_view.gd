extends "res://scripts/water_sort/order_help_pour.gd"
const Art=preload("res://scripts/ui_restore/approved_ui_art.gd")
var closed:Callable
var energy_text:="30/30"
var buttons:Dictionary={}
var resting_y:=610.0
func _ready()->void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	Art.picture(self,"guide","guide_frame_blank")
	Art.picture(self,"guide","title_original_zh" if locale=="zh" else "title_blank_normal")
	if locale=="zh":
		Art.picture(self,"guide","subtitle_original_zh");Art.picture(self,"guide","rule_original_zh")
	else:
		Art.label(self,"GuideTitle","How to play",Rect2(195,178,525,120),80,Color.WHITE,5)
		Art.label(self,"GuideSubtitle","Tap to sort the colors",Rect2(180,326,560,56),46,Color("b7f2ff"))
		var rule:=Art.label(self,"GuideRule","Fill orders to reduce counts.\nAt zero, the cloth unlocks.",Rect2(109,1272,695,111),44);rule.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	Art.picture(self,"guide","energy_capsule_blank")
	Art.label(self,"energy",energy_text,Rect2(118,71,115,46),38,Color.WHITE,2)
	buttons.rules_back=Art.button(self,"guide","back_normal",closed)
	buttons.rules_close=Art.button(self,"guide","cta_original_zh" if locale=="zh" else "cta_blank_normal",closed,Rect2(),"cta_blank_pressed","cta_blank_disabled")
	if locale=="zh":
		buttons.rules_close.state_overlay_texture=Art.texture("guide","cta_label_zh")
		buttons.rules_close.state_overlay_box=Rect2(Art.box("guide","cta_label_zh").position-buttons.rules_close.position,Art.box("guide","cta_label_zh").size)
		buttons.rules_close.refresh_material()
	if locale!="zh":Art.label(self,"GuideDone","Got it",Rect2(285,1518,345,107),80,Color.WHITE,4)
	for i in 3:
		var face:=Art.picture(self,"guide","step"+str(i+1)+"_active");step_faces.append(face)
		if locale=="zh":Art.picture(self,"guide","step"+str(i+1)+"_label_zh")
		else:Art.label(self,"Step"+str(i),["1 Pick right","2 Pour green","3 Fill"][i],Art.box("guide","step"+str(i+1)+"_blank_native"),39)
	for i in 2:
		var bottle:=Visual.new();bottle.z_index=20;add_child(bottle);bottle.use_delivered_layers()
		if i==0:source=bottle
		else:target=bottle
	motion=Animator.new();motion.auto_seal=false;motion.relaxed_timing=true;motion.travel_lift=32;motion.hover_clearance_local=45;add_child(motion);motion.set_process(false)
	hand_layer=Node2D.new();hand_layer.z_index=60;add_child(hand_layer)
	guide_pointer=preload("res://scripts/water_sort/tutorial_hand.gd").create_pointer(915.0/390.0);hand_layer.add_child(guide_pointer)
	for i in 2:
		var button:=preload("res://scripts/water_sort/p2_art.gd").hit(self,"TargetBottle" if i==0 else "SourceBottle",Rect2(180+i*370,590,190,460),func():choose_bottle(i));button.z_index=65;bottle_buttons.append(button)
	caption_label=preload("res://scripts/ui_restore/guide_caption.gd").new();caption_label.name="GuideCaption";caption_label.locale=locale;caption_label.position=Vector2(200,1094);caption_label.size=Vector2(510,151);caption_label.mouse_filter=Control.MOUSE_FILTER_IGNORE;caption_label.z_index=75;add_child(caption_label)
	_reset()
func _reset()->void:
	super._reset();source.position=Vector2(650,resting_y);target.position=Vector2(280,resting_y)
	source.scale=Vector2.ONE;target.scale=Vector2.ONE
func _set_stage(value:String)->void:
	super._set_stage(value)
	if value=="settle":source.position.y=resting_y
func _sync_step_headers()->void:
	var active:=0 if stage=="tap_source" else (1 if stage in ["tap_target","pour"] else 2)
	for i in step_faces.size():step_faces[i].texture=Art.texture("guide","step"+str(i+1)+("_active" if i==active else "_inactive"))
func _draw()->void:
	if not is_instance_valid(caption_label):return
	var step:=0 if stage=="tap_source" else (1 if stage in ["tap_target","pour"] else 2)
	var captions:Array=["选右侧源瓶\n把上层绿色倒入左瓶","绿色倒入左瓶\n红色留在右瓶","左瓶装满绿色\n右瓶保留红色"] if locale=="zh" else ["Tap right bottle.\nThen tap left.","Green pours left.\nRed stays right.","Left bottle full.\nRed stays right."]
	caption_label.text=captions[step]
	if not feedback.is_empty():
		caption_label.text=("请先选右侧源瓶\n把上层绿色倒入左瓶" if stage=="tap_source" else "请选择左侧目标瓶\n把上层绿色倒入左瓶") if locale=="zh" else ("Tap right bottle.\nThen tap left." if stage=="tap_source" else "Tap left bottle.\nTo pour green.")
	if feedback.is_empty() and stage=="tap_target":caption_label.text="点击左侧目标瓶\n把上层绿色倒入左瓶" if locale=="zh" else "Tap left bottle.\nPour green left."
