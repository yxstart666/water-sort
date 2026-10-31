extends Control
## Source registration: exact approved914x1720 page, dynamic model and actions.
signal select_requested(index:int)
signal page_requested(index:int)
signal back_requested
const Art=preload("res://scripts/ui_restore/recipe_art.gd")
const Text=preload("res://scripts/ui_restore/data_text.gd")
const P2Art=preload("res://scripts/water_sort/p2_art.gd")
const Typography=preload("res://scripts/ui_restore/typography.gd")
const FontPolicy=preload("res://scripts/ui_restore/font_policy.gd")
const PAGE_SIZE:=12
const REFERENCE:=Vector2(914,1720)
const GRID_ORIGIN:=Vector2(119,453)
const GRID_STRIDE:=Vector2(230,221)
const CELL_SIZE:=Vector2(215,210)
const PANEL_RECT:=Rect2(53,237,808,1388)
var locale:="zh"
var model:Array=[]
var current_index:=0
var page_index:=0
var all_open_test_profile:=false
var buttons:Dictionary={}
var labels:Dictionary={}
func _ready()->void:
	name="LevelSelectView";mouse_filter=Control.MOUSE_FILTER_IGNORE
	var panel:=_layer("sprites/panel_normal_9slice_candidate.webp",PANEL_RECT,[176,167,176,160],.50) as NinePatchRect
	# Register the visible frame, excluding the source's transparent padding.
	# Preserve the original corner scale and slice seams after region cropping.
	panel.region_rect=Rect2(54,63,1204,1276)
	_layer("sprites/title_normal_9slice_candidate.webp",Rect2(175,149,561,177),[350,120,350,120],.385)
	_layer("data_page_components/locale/zh-CN/title_levels.webp" if locale=="zh" else "english_art_labels/labels/select_level_en.webp",Rect2(264,175,393,116) if locale=="zh" else Rect2(225,192,464,90))
	_layer("sprites/close_normal_clean.webp",Rect2(748,214,130,135))
	buttons.back=P2Art.hit(self,"back",Rect2(748,214,130,135),func():back_requested.emit())
	_layer("data_page_components/sprites/summary_value_well.webp",Rect2(241,345,432,87),[32,32,32,32],87.0/93.0)
	labels.current=_label("CurrentLevel",("当前关卡：第%d关" if locale=="zh" else "Current level: %d") % (current_index+1),Rect2(268,355,378,65),46,Color("0756c6"))
	for slot in PAGE_SIZE:
		var index:=page_index*PAGE_SIZE+slot
		if index>=model.size():break
		var item:Dictionary=model[index];var allowed:bool=item.allowed;var completed:bool=item.completed;var current:bool=index==current_index
		var box:=Rect2(GRID_ORIGIN+Vector2(slot%3,slot/3)*GRID_STRIDE,CELL_SIZE)
		var state:="current" if current else ("completed" if allowed or completed else "locked")
		_layer("data_page_components/recovery/sprites/level_tile_"+state+".webp",box)
		var number:=_label("LevelNumber"+str(index),str(index+1),Rect2(box.position+Vector2(5,25),Vector2(205,154)),124,Color.WHITE)
		var binding=preload("res://scripts/ui_restore/numeric_label_binding.gd").new();binding.family="levels_gold" if current else ("levels" if allowed or completed else "levels_locked");binding.face_pixels=94 if current else (91 if allowed or completed else 86);number.add_child(binding)
		labels["level_number_"+str(index)]=number
		if completed:_layer("data_page_components/sprites/level_completed.webp",Rect2(box.position+Vector2(147,-3),Vector2(71,72)))
		elif not allowed:_layer("data_page_components/sprites/level_locked.webp",Rect2(box.position+Vector2(143,119),Vector2(64,75)))
		var button:=P2Art.hit(self,"level_"+str(index),box,func():select_requested.emit(index))
		button.disabled=not allowed;button.tooltip_text=("第%d关" if locale=="zh" else "Level %d") % (index+1);buttons["level_"+str(index)]=button
	var hint:="测试版：全部关卡已开放" if locale=="zh" else "Playtest: all levels are open"
	if not all_open_test_profile:hint="完成当前关卡，解锁下一关" if locale=="zh" else "Complete this level to unlock the next"
	labels.unlock_hint=_label("UnlockHint",hint,Rect2(195,1342,524,61),38,Color("0756c6"))
	var count:=maxi(1,ceili(model.size()/float(PAGE_SIZE)))
	_layer("data_page_components/sprites/summary_value_well.webp",Rect2(346,1429,223,80),[32,32,32,32],80.0/93.0)
	labels.page_index=_label("PageIndex","%d / %d" % [page_index+1,count],Rect2(368,1432,179,69),48,Color("0756c6"))
	_pager("previous",Rect2(187,1411,136,126),true,page_index>0)
	_pager("next",Rect2(591,1411,136,126),false,page_index+1<count)
func _label(id:String,value:String,box:Rect2,pixels:int,color:Color)->Label:
	var label:=Text.label(self,id,value,box,pixels)
	var face:=FontPolicy.get_font("lxgw")
	label.add_theme_font_override("font",face);label.add_theme_color_override("font_color",color)
	Typography.center_label(label,box,20);return label
func _pager(id:String,box:Rect2,previous:bool,enabled:bool)->void:
	var base:=_layer("sprites/blue_square_normal_clean.webp",box)
	var arrow:=_layer("data_page_components/sprites/pager_chevron_right.webp",Rect2(box.position+Vector2(42,22),Vector2(57,74))) as TextureRect;arrow.flip_h=previous
	var button:=P2Art.hit(self,id,box,func():page_requested.emit(page_index+(-1 if previous else 1)))
	button.disabled=not enabled;buttons[id]=button
	if not enabled:base.modulate=Color(.65,.7,.78,.65);arrow.modulate=Color(.65,.7,.78,.65)
func _layer(path:String,rect:Rect2,insets:Array=[],factor:=1.0)->Control:
	var spec:Dictionary={"type":"sprite","source":path,"rectDp":[rect.position.x,rect.position.y,rect.size.x,rect.size.y]}
	if not insets.is_empty():spec.merge({"type":"nineSlice","sourceInsetsLTRB":insets,"uniformCornerScale":factor},true)
	return Art.layer(self,spec)
