extends Control
## Reusable modal queue. Content and persistence are injected by the host.
signal finished
const UI=preload("res://scripts/water_sort/reference2_ui.gd")
var items: Array=[]
var locale:="zh"
var acknowledge: Callable
var index:=0
var board: Control
var shade:ColorRect
var error_label: Label
var armed:=false
var cooldown:=0.3
var explanation:Label
var explanation_panel:NinePatchRect
var dismiss_label:Label
var expanded_explanation:=false
func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_STOP; z_index=120
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade=ColorRect.new(); shade.color=Color(0.01,0.03,0.10,0.78); shade.mouse_filter=Control.MOUSE_FILTER_IGNORE
	add_child(shade); shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	board=Control.new();board.size=Vector2(940,1672); board.mouse_filter=Control.MOUSE_FILTER_IGNORE; add_child(board)
	resized.connect(fit); fit(); show_item()
func fit() -> void:
	if not is_instance_valid(board): return
	if preload("res://scripts/ui_restore/screen_layout.gd").fit_modal(self,board,Vector2(940,1672),shade):return
	var factor:=minf(size.x/940.0,size.y/1672.0)
	board.scale=Vector2.ONE*factor; board.position=(size-Vector2(940,1672)*factor)*0.5
func show_item() -> void:
	for child in board.get_children(): board.remove_child(child); child.queue_free()
	armed=false; cooldown=0.3
	var item: Dictionary=items[index]
	var title_path: String="res://assets/colorpause_ui_20261030/guide_shell/sprites/new_mechanic_zh-CN.webp" if locale=="zh" else "res://assets/colorpause_ui_20261030/english_art_labels/labels/new_mechanic_en.webp"
	var title_art:=UI.picture(board,"IntroTitle",title_path,Rect2(70,260,800,100));title_art.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	if item.get("illustration") is Callable: board.add_child(item.illustration.call())
	# The illustration floats directly over the dimmed board. Only the compact
	# explanation uses the existing panel material, never an opaque bottle box.
	var panel:=NinePatchRect.new();panel.name="IntroExplanationPanel";panel.texture=load("res://assets/colorpause_ui_20261030/sprites/panel_normal_9slice_candidate.webp");panel.position=Vector2(100,1080);panel.size=Vector2(740,240)/0.16;panel.scale=Vector2.ONE*0.16;panel.mouse_filter=Control.MOUSE_FILTER_IGNORE;panel.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	for edge in 4: panel.set_patch_margin(edge,230)
	board.add_child(panel)
	explanation_panel=panel
	expanded_explanation=str(item.get("id",""))=="unknown_layers_v1"
	var text_width:=760.0 if expanded_explanation else 680.0
	var explanation_text:=str(item.body)
	if expanded_explanation and locale=="zh":
		# Preserve every word/punctuation mark; wrap complete Chinese clauses.
		# The42px role stays readable on320-wide short screens.
		explanation_text=explanation_text.replace("\n", "").replace("，", "，\n").replace("。", "。\n").trim_suffix("\n")
	explanation=UI.label(board,"IntroCondition",explanation_text,Rect2((940-text_width)*.5,1118,text_width,164),locale,42 if expanded_explanation else 34,UI.PANEL_INK,true)
	explanation.clip_text=false
	dismiss_label=UI.label(board,"IntroDismiss","点击任意位置继续" if locale=="zh" else "Tap anywhere to continue",Rect2(100,1400,740,80),locale,34)
	error_label=UI.label(board,"IntroSaveError","",Rect2(100,1500,740,100),locale,28,Color("ffb3a8"),true)
	_layout_explanation.call_deferred()
func _layout_explanation()->void:
	if not is_instance_valid(explanation):return
	var font:Font=explanation.get_theme_font("font")
	var count:=explanation.get_line_count()
	var text_height:=maxf(164,ceilf(font.get_height(explanation.get_theme_font_size("font_size"))*count+explanation.get_theme_constant("line_spacing")*maxi(0,count-1)+8))
	var panel_height:=text_height+76
	var top:=minf(1080,1672-24-panel_height-24-60-20-80) if expanded_explanation else 1080.0
	explanation.position.y=top+38;explanation.size.y=text_height
	explanation_panel.position=Vector2(60 if expanded_explanation else 100,top)
	explanation_panel.size=Vector2(820 if expanded_explanation else 740,panel_height)/.16
	if expanded_explanation:
		dismiss_label.position.y=top+panel_height+24;dismiss_label.size.y=60
		error_label.position.y=dismiss_label.position.y+80;error_label.size.y=80
func _process(delta: float) -> void:
	cooldown=maxf(0,cooldown-delta)
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT:
		accept_event()
		if event.pressed: armed=cooldown<=0
		elif armed:
			armed=false; dismiss()
func dismiss() -> void:
	if cooldown>0: return
	cooldown=0.3
	if not acknowledge.is_valid() or not acknowledge.call(str(items[index].id)):
		error_label.text="未能保存，请再次点击重试。" if locale=="zh" else "Could not save. Tap again to retry."
		return
	index+=1
	if index<items.size(): show_item()
	else:
		# Defer removal so this release event cannot reach the board below.
		finished.emit(); call_deferred("queue_free")
