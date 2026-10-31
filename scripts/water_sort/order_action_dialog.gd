extends Control
## Fixed delivery presentation; existing game callbacks own every state change.
const UI=preload("res://scripts/water_sort/reference2_ui.gd")
const P2Art=preload("res://scripts/water_sort/p2_art.gd")
const REFERENCE=Vector2(940,1672)
var locale:="zh"
var dialog_kind:="result"
var heading:=""
var body:=""
var result_moves:=0
var result_seconds:=0.0
var result_level:=0
var canvas: Control
var shade: ColorRect
var title_label: Label
var body_label: Label
var buttons: Dictionary={}
var dispatched:=false
var frame:Control
var title_bar:Control
var celebration:Control
var p2_victory:=false
var p2_title_art:Control
var restart_view:Control
var stuck_view:Control
func _ready() -> void:
	name="OrderActionDialog"; mouse_filter=Control.MOUSE_FILTER_STOP
	shade=ColorRect.new(); shade.color=Color("071d38",0.58); shade.mouse_filter=Control.MOUSE_FILTER_IGNORE; add_child(shade)
	if dialog_kind=="restart":
		restart_view=preload("res://scripts/ui_restore/restart_dialog_view.gd").new()
		restart_view.locale=locale; restart_view.body=body; restart_view.heading=heading
		canvas=restart_view; canvas.size=Vector2(320,569); add_child(canvas)
		frame=restart_view.frame; title_label=restart_view.title_label; body_label=restart_view.body_label
		resized.connect(_fit); _fit(); return
	if dialog_kind=="stuck":
		stuck_view=preload("res://scripts/ui_restore/stuck_formal_view.gd").new();stuck_view.locale=locale;canvas=stuck_view;add_child(canvas)
		frame=stuck_view.panel;title_label=stuck_view.title_label;body_label=stuck_view.body_label
		resized.connect(_fit);_fit();return
	if dialog_kind=="won":
		_build_p2_victory(); resized.connect(_fit); _fit(); return
	canvas=Control.new(); canvas.size=REFERENCE; canvas.mouse_filter=Control.MOUSE_FILTER_IGNORE; add_child(canvas)
	canvas.set_meta("light_ui_surface",true)
	var won:=dialog_kind=="won"
	frame=UI.consolidated_panel(canvas,"PanelArt",Rect2(106,500,728,600))
	title_bar=preload("res://scripts/water_sort/consolidated_frame.gd").new();title_bar.name="TitleChrome";title_bar.kind="title";canvas.add_child(title_bar)
	title_label=UI.label(canvas,"Title",heading,Rect2(145,421,650,80) if won else Rect2(132,546,676,90),locale,40)
	title_label.add_theme_font_override("font",preload("res://scripts/ui_restore/font_policy.gd").get_font("lxgw"));title_label.add_theme_color_override("font_color",Color.WHITE);title_label.add_theme_color_override("font_outline_color",Color("0052ae"));title_label.add_theme_constant_override("outline_size",5)
	body_label=UI.label(canvas,"Body",body,Rect2(160,710,620,105) if won else Rect2(136,670,668,280),locale,30,UI.INK,true)
	if won:
		celebration=preload("res://scripts/water_sort/p0_star_sequence.gd").new()
		canvas.add_child(celebration)
		body_label.text="全部颜色订单已交付！" if locale=="zh" else "All color orders delivered!"
		UI.label(canvas,"ResultLevel",("第 %d 关" if locale=="zh" else "Level %d") % result_level,Rect2(180,499,580,44),locale,28)
		UI.label(canvas,"MovesLabel","使用步数" if locale=="zh" else "Moves",Rect2(160,550,280,50),locale,32)
		UI.label(canvas,"TimeLabel","用时" if locale=="zh" else "Time",Rect2(500,550,280,50),locale,32)
		UI.label(canvas,"MovesValue",str(result_moves),Rect2(160,604,280,92),locale,60,Color("975410"))
		UI.label(canvas,"TimeValue","%02d:%02d" % [int(result_seconds)/60,int(result_seconds)%60],Rect2(500,604,280,92),locale,60,Color("975410"))
	resized.connect(_fit); _fit(); _layout_content.call_deferred()
func _fit() -> void:
	if not is_instance_valid(canvas): return
	var reference:=Vector2(915,1719) if is_instance_valid(stuck_view) else Vector2(320,569) if is_instance_valid(restart_view) else (Vector2(320,603) if p2_victory else REFERENCE)
	if preload("res://scripts/ui_restore/screen_layout.gd").fit_modal(self,canvas,reference,shade):return
	shade.size=size; canvas.scale=Vector2.ONE*minf(size.x/reference.x,size.y/reference.y)
	canvas.position=(size-reference*canvas.scale)*0.5
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton or event is InputEventScreenTouch: accept_event()
func add_action(id: String, caption: String, action: Callable) -> Button:
	if is_instance_valid(stuck_view):
		var button:Button=stuck_view.add_action(id,caption,func():
			if dispatched:return
			dispatched=true
			for other in buttons.values():other.disabled=true
			action.call())
		buttons[id]=button;return button
	if is_instance_valid(restart_view):
		var button:Button=restart_view.add_action(id,caption,func():
			if dispatched: return
			dispatched=true
			for other in restart_view.buttons.values(): other.disabled=true
			action.call())
		buttons[id]=button; return button
	if p2_victory: return _p2_action(id,caption,action)
	var secondary:=id in ["ResultRestart","ResultInstructions","CancelRestart","AdCancel","RewardCancel","RescueBottle"]
	var button:=UI.button(canvas,id,caption,Rect2(160,834,620,140 if secondary else 152),locale,func():
		if dispatched: return
		dispatched=true
		for other in buttons.values(): other.disabled=true
		action.call(),secondary)
	if id=="RescueBottle":
		var content=preload("res://scripts/water_sort/art/approved_play_caption.gd").new()
		content.caption=caption;button.text="";button.tooltip_text=caption
		button.add_child(content);content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	buttons[id]=button; _layout_content.call_deferred(); return button

func add_close(id:String,action:Callable)->Button:
	var button:=UI.close_button(canvas,id,Rect2(0,0,126,126),action)
	buttons[id]=button;_layout_content.call_deferred();return button

func _layout_content()->void:
	if p2_victory or is_instance_valid(stuck_view):return
	if not is_instance_valid(frame):return
	var rows:Array=[];var paired:=false
	for id in buttons:
		if id.ends_with("Close"):continue
		if id in ["ResultRestart","ResultInstructions"]:
			if not paired:rows.append(["ResultRestart","ResultInstructions"]);paired=true
		else:rows.append([id])
	body_label.size.x=520
	var body_font: Font=body_label.get_theme_font("font")
	var body_height:=clampf(body_font.get_multiline_string_size(body_label.text,HORIZONTAL_ALIGNMENT_CENTER,body_label.size.x,body_label.get_theme_font_size("font_size")).y+body_font.get_height(body_label.get_theme_font_size("font_size"))+24,64,1000)
	var content_y:=165.0+76.0+18.0
	if dialog_kind=="won":content_y+=400
	var body_y:=content_y;content_y+=body_height+26
	var row_positions:Array=[]
	for row in rows:
		var height:float=140.0 if row.size()>1 else buttons[row[0]].size.y
		row_positions.append(content_y);content_y+=preload("res://scripts/ui_restore/screen_layout.gd").row_stride(canvas,height,18)
	var height:=content_y+130
	frame.position=Vector2(106,(REFERENCE.y-height)*0.5);frame.size=Vector2(728,height)
	var y:=frame.position.y
	title_bar.position=Vector2(195,y+115);title_bar.size=Vector2(550,130)
	title_label.position=Vector2(210,y+140);title_label.size=Vector2(520,76)
	body_label.position=Vector2(210,y+body_y);body_label.size=Vector2(520,body_height)
	if dialog_kind=="won":
		celebration.position=Vector2(205,y+325)
		for spec in [["ResultLevel",Rect2(160,y+136,620,46)],["MovesLabel",Rect2(160,y+188,280,44)],["TimeLabel",Rect2(500,y+188,280,44)],["MovesValue",Rect2(160,y+232,280,88)],["TimeValue",Rect2(500,y+232,280,88)]]:
			var node:Control=canvas.get_node(spec[0]);node.position=spec[1].position;node.size=spec[1].size
	for i in rows.size():
		var row:Array=rows[i]
		for j in row.size():
			if not buttons.has(row[j]):continue
			var button:Button=buttons[row[j]]
			button.position=Vector2(210+j*270,y+row_positions[i]);button.size.x=250 if row.size()>1 else 520
			UI.fit_button_text(button)
	for id in buttons:
		if id.ends_with("Close"):
			buttons[id].position=frame.position+Vector2(608,-4);buttons[id].size=Vector2(126,126)
			title_label.position.x=210;title_label.size.x=520
	# Action/close controls determine the final heading width after creation.
	# Fit again here so localized ink cannot retain the initial wider font size.
	var title_font:Font=title_label.get_theme_font("font")
	var title_pixels:=40
	while title_pixels>18 and (title_font.get_string_size(title_label.text,HORIZONTAL_ALIGNMENT_LEFT,-1,title_pixels).x>title_label.size.x-8 or title_font.get_height(title_pixels)>title_label.size.y):title_pixels-=1
	title_label.add_theme_font_size_override("font_size",title_pixels)

func _build_p2_victory()->void:
	p2_victory=true; canvas=Control.new(); canvas.size=Vector2(320,603); canvas.mouse_filter=Control.MOUSE_FILTER_IGNORE; add_child(canvas)
	var page: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/p2_ui/victory_layouts.json")).pages[0]
	for layer in page.layers:
		var source: String=layer.source
		if locale=="zh" and float(layer.rectDp[1])>=432:continue
		if layer.type in ["animatedStar","optionalGlow"] or source.contains("label_next_") or source.contains("label_home_") or source.contains("label_levels_") or source.contains("icon_home") or source.contains("icon_levels_list"):continue
		var use_layer: Dictionary=layer.duplicate(true)
		var path_override: String=""
		if locale=="en":
			if source.contains("title_success_"): path_override="res://assets/colorpause_ui_20261030/english_art_labels/labels/level_complete_en.webp"
			elif source.contains("label_steps_"): path_override="res://assets/colorpause_ui_20261030/english_art_labels/labels/moves_en.webp"
			elif source.contains("label_time_"): path_override="res://assets/colorpause_ui_20261030/english_art_labels/labels/time_en.webp"
		var visual=P2Art.add_layer(canvas,use_layer,path_override)
		if source.contains("title_success_"): p2_title_art=visual
	celebration=preload("res://scripts/water_sort/p2_stars.gd").new(); canvas.add_child(celebration)
	title_label=_p2_text("",Rect2(65,57,190,51),18); title_label.hide()
	title_label.add_theme_color_override("font_color",Color.WHITE)
	title_label.add_theme_color_override("font_outline_color",Color("0759b9"))
	title_label.add_theme_constant_override("outline_size",3)
	body_label=Label.new(); body_label.hide(); canvas.add_child(body_label)
	_p2_text(("第 %d 关" if locale=="zh" else "Level %d") % result_level,Rect2(65,119,190,20),13)
	for spec in page.numeric_containers:
		var r:Array=spec.rectDp
		_p2_text(str(result_moves) if spec.key=="steps" else "%02d:%02d" % [int(result_seconds)/60,int(result_seconds)%60],Rect2(r[0],r[1],r[2],r[3]),20)

func _p2_text(value:String,box:Rect2,font_size:int)->Label:
	var label:=Label.new(); label.text=value; label.position=box.position; label.size=box.size
	label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; label.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font",preload("res://scripts/ui_restore/font_policy.gd").get_font("lxgw"))
	label.add_theme_font_size_override("font_size",font_size); label.add_theme_color_override("font_color",Color("0759b9"))
	label.mouse_filter=Control.MOUSE_FILTER_IGNORE; canvas.add_child(label)
	preload("res://scripts/ui_restore/typography.gd").center_label(label,box,12)
	return label

func _p2_image(path:String,box:Rect2)->void:
	P2Art.add_layer(canvas,{"type":"sprite","source":path,"rectDp":[box.position.x,box.position.y,box.size.x,box.size.y]})

func _p2_action(id:String,caption:String,action:Callable)->Button:
	var box:=Rect2(40,360,240,72) # Input stops before the secondary row; artwork retains its source rectangle.
	if id=="ResultInstructions": box=Rect2(78.77,432.38,73.53,69)
	elif id=="ResultRestart": box=Rect2(169.45,432.38,73.53,69)
	if id=="Next": _p2_image("runtime/victory_window/label_next_zh-CN.png" if locale=="zh" else "res://assets/colorpause_ui_20261030/english_art_labels/labels/next_level_en.webp",Rect2(90,372.52,140,42.01))
	elif id=="ReplayAll":
		var primary_label: String="res://assets/colorpause_ui_20261030/final_level_restart_zh/labels/restart_from_level_1_zh-CN.webp" if locale=="zh" else "res://assets/colorpause_ui_20261030/english_art_labels/labels/restart_from_level_1_en_2line.webp"
		_p2_image(primary_label,Rect2(52,368,216,52))
		p2_title_art.hide(); title_label.text=("%d 关挑战完成" if locale=="zh" else "All %d levels complete") % result_level; title_label.show()
	elif id=="ResultInstructions":
		if locale=="zh":preload("res://scripts/ui_restore/original_button_art.gd").picture(canvas,"OriginalHomeNormal","full_buttons/button_home_reference.png",box)
		else:
			_p2_image("runtime/controls/icon_home.png",Rect2(99.43,440.09,31.51,31.26))
			_p2_image("res://assets/colorpause_ui_20261030/english_art_labels/labels/home_en.webp",Rect2(91,470.9,49,21.36))
	elif id=="ResultRestart":
		if locale=="zh":preload("res://scripts/ui_restore/original_button_art.gd").picture(canvas,"OriginalReplayNormal","full_buttons/button_replay_reference.png",box)
		else:
			_p2_image("runtime/controls/icon_replay.png",Rect2(190,440,31.51,31.5))
			_p2_image("res://assets/colorpause_ui_20261030/english_art_labels/labels/restart_en.webp",Rect2(181,470,50,22))
	var button:=P2Art.hit(canvas,id,box,func():
		if dispatched:return
		dispatched=true
		for other in buttons.values():other.disabled=true
		action.call())
	button.tooltip_text=caption; buttons[id]=button; return button
