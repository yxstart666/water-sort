extends Control
const Art=preload("res://scripts/ui_restore/approved_ui_art.gd")
const REFERENCE:=Vector2(915,1719)
var locale:="zh"
var buttons:Dictionary={}
var title_label:Label
var body_label:Label
var panel:NinePatchRect
var group:Control
var no_history:Label
var last_state:=""
func _ready()->void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE;size=REFERENCE
	group=Control.new();group.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(group)
	panel=NinePatchRect.new();panel.texture=Art.texture("stuck","panel_blank");panel.position=Vector2(50,215);panel.size=Vector2(815,1437);panel.mouse_filter=Control.MOUSE_FILTER_IGNORE;panel.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	for edge in 4:panel.set_patch_margin(edge,114)
	group.add_child(panel)
	Art.picture(group,"stuck","hero_card_normal")
	Art.picture(group,"stuck","title_normal" if locale=="zh" else "title_blank")
	title_label=Art.label(group,"Title","暂时无路可走" if locale=="zh" else "No moves left",Rect2(180,165,555,125),76,Color.WHITE,5);title_label.visible=locale!="zh"
	body_label=Art.label(group,"Body","当前没有合法倒法。\n撤回上一步，或重新试试。" if locale=="zh" else "No legal pours left.\nUndo a move or try again.",Rect2(143,805,639,136),51)
	if locale=="zh":body_label.hide();Art.picture(group,"stuck","body_zh")
	no_history=Art.label(group,"NoUndoHistory","目前没有可撤回的步骤。" if locale=="zh" else "No move to undo yet.",Rect2(143,941,639,48),34);no_history.hide()
func add_action(id:String,caption:String,callback:Callable)->Button:
	var key:String={"BlockedUndo":"undo","ResultRestart":"replay","ResultInstructions":"home","RescueBottle":"bonus"}[id]
	var button:=Art.button(group,"stuck",key+("_button_normal" if locale=="zh" else "_button_blank"),callback)
	button.name=id;button.tooltip_text=caption;button.accessibility_name=caption;button.pressed_offset=4;buttons[id]=button
	if locale!="zh":
		var icon:=Art.picture(button,"stuck",key+"_icon");icon.position-=button.position;icon.z_index=1
		var r:=Art.box("stuck",key+"_label_zh");r.position-=button.position
		Art.label(button,id+"Caption",{"undo":"Undo move","replay":"Restart","home":"Home","bonus":"Add bottle"}[key],r,62 if key in ["undo","bonus"] else 52,Color.WHITE,4)
	_reflow.call_deferred();return button
func _process(_delta:float)->void:
	var state:=str(buttons.has("RescueBottle"))+str(buttons.has("BlockedUndo") and buttons.BlockedUndo.disabled)
	var game=get_parent().get_parent()
	var capability:Variant=game.get("reward_capability")
	if typeof(capability)==TYPE_CALLABLE and capability.is_valid():state+=str(capability.call())
	if state!=last_state:last_state=state;_reflow()
func _reflow()->void:
	var bonus:bool=buttons.has("RescueBottle")
	var no_undo:bool=buttons.has("BlockedUndo") and buttons.BlockedUndo.disabled
	# Capability is owned by the host. Do not expose a reward route it cannot run.
	var game=get_parent().get_parent()
	var capability:Variant=game.get("reward_capability")
	if bonus and typeof(capability)==TYPE_CALLABLE and capability.is_valid():
		bonus=bool(capability.call())
		buttons.RescueBottle.visible=bonus
	no_history.visible=no_undo
	var extra:=48.0 if no_undo else 0.0
	panel.size.y=1437-(0 if bonus else 178)+extra
	group.position.y=(0 if bonus else 89)-extra*.5
	for id in buttons:
		var key:String={"BlockedUndo":"undo","ResultRestart":"replay","ResultInstructions":"home","RescueBottle":"bonus"}[id]
		buttons[id].position=Art.box("stuck",key+"_button_normal").position+Vector2(0,extra)
