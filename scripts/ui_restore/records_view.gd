extends Control
## Data-page view. Host supplies model/tab and owns navigation; only rows scroll.
signal tab_requested(tab:String)
signal back_requested
signal scroll_changed(offset:int)
const Art=preload("res://scripts/ui_restore/recipe_art.gd")
const Text=preload("res://scripts/ui_restore/data_text.gd")
const StatCard=preload("res://scripts/ui_restore/stat_card.gd")
const P2Art=preload("res://scripts/water_sort/p2_art.gd")
var locale:="zh"
var tab:="level"
var model:Dictionary={}
var scroll_offset:=0
var buttons:Dictionary={}
var labels:Dictionary={}
var content:Dictionary
var layout:Dictionary
var scroll:ScrollContainer
func _ready()->void:
	name="RecordsView";mouse_filter=Control.MOUSE_FILTER_IGNORE
	content=preload("res://scripts/ui_restore/records_content.gd").for_locale(locale)
	layout=JSON.parse_string(FileAccess.get_file_as_string("res://assets/colorpause_ui_20261030/layouts/records.json"))
	_layer("sprites/panel_normal_9slice_candidate.webp",layout.panel,[230,230,230,230],.235)
	_layer("sprites/title_normal_9slice_candidate.webp",layout.title_chrome,[350,120,350,120],.165)
	_layer("data_page_components/locale/zh-CN/title_records.webp" if locale=="zh" else "english_art_labels/labels/game_records_en.webp",layout.title_zh if locale=="zh" else layout.title_en)
	_layer("sprites/close_normal_clean.webp",layout.close)
	for i in 2:
		var key:String=["level","total"][i];var r:Array=layout.tabs[i]
		_layer("data_page_components/sprites/ranking_row_selected.webp" if tab==key else "data_page_components/sprites/record_row_unplayed.webp",r,[30,20,30,20],.4)
		_label("Tab"+key,content.summary if i==0 else content.global,Rect2(r[0]+5,r[1]+3,r[2]-10,42),17,true)
		var id:String="ranking_level" if i==0 else "ranking_total"
		buttons[id]=P2Art.hit(self,id,_touch_box(Art.box(r)),func():tab_requested.emit(key));buttons[id].disabled=tab==key
	if tab=="level":_summary()
	else:
		_label("level_name",content.global_title,Rect2(40,292,310,56),24,true)
		_label("service_hint",content.unavailable,Rect2(40,366,310,110),18,true)
	_layer("sprites/cyan_normal_clean.webp",layout.back)
	_layer("data_page_components/recovery/sprites/back_zh-CN.webp" if locale=="zh" else "english_art_labels/labels/back_en.webp",layout.back_zh if locale=="zh" else layout.back_en)
	buttons.ranking_return=P2Art.hit(self,"ranking_return",_touch_box(Art.box(layout.back)),func():back_requested.emit())
	buttons.back=P2Art.hit(self,"back",_touch_box(Art.box(layout.close)),func():back_requested.emit())
	buttons.back.tooltip_text=content.back;buttons.ranking_return.tooltip_text=content.back
func _summary()->void:
	var values:Array=["%d / %d" % [model.completed,model.level_count],str(model.moves),model.time]
	for i in 3:
		var card:=StatCard.new();card.name="StatCard"+str(i);card.caption=[content.cleared,content.moves,content.time][i];card.value=values[i];card.value_id=["level_name","personal_metric","personal_time"][i]
		var box:=Art.box(layout.cards[i]);card.position=box.position;card.size=box.size;add_child(card);labels[card.value_id]=card.value_label
	_layer("data_page_components/sprites/record_section_banner.webp",layout.section)
	_label("records_heading",content.section,Art.box(layout.section),22)
	var col_widths:Array=[130.0,74.0,106.0];var col_left:=40.0
	for i in 3:
		_label("Column"+str(i),content.columns[i],Rect2(col_left,layout.columns[1],col_widths[i],layout.columns[3]),16);col_left+=col_widths[i]
	scroll=ScrollContainer.new();scroll.name="CompletedRecords";scroll.position=Art.box(layout.list).position;scroll.size=Art.box(layout.list).size;scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;scroll.vertical_scroll_mode=ScrollContainer.SCROLL_MODE_SHOW_NEVER;add_child(scroll)
	var list:=VBoxContainer.new();list.name="Rows";list.size_flags_horizontal=Control.SIZE_EXPAND_FILL;list.add_theme_constant_override("separation",8);scroll.add_child(list)
	if model.records.is_empty():
		var empty:=Text.label(list,"records_empty",content.empty,Rect2(0,0,310,145),18,true);empty.custom_minimum_size=Vector2(300,145);labels.records_empty=empty
	for record in model.records:
		var row:=Control.new();row.name="RecordLevel"+str(record.index);row.custom_minimum_size=Vector2(300,51);row.tooltip_text=content.local;list.add_child(row)
		Art.layer(row,{"type":"sprite","source":"data_page_components/sprites/record_row_completed.webp","rectDp":[0,0,300,51]})
		Art.layer(row,{"type":"sprite","source":"data_page_components/sprites/status_completed.webp","rectDp":[8,12,25,25]})
		var columns:Array=[content.level % (int(record.index)+1),str(record.moves),record.time]
		for i in 3:
			var id:String="record_%d_%d" % [record.index,i]
			labels[id]=Text.label(row,id,columns[i],Rect2([36,130,204][i],0,[94,74,96][i],51),18)
	_label("status_title",content.local,Art.box(layout.local_note),14)
	scroll.get_v_scroll_bar().value_changed.connect(func(value:float):scroll_changed.emit(roundi(value)))
	_restore_scroll.call_deferred()
func _restore_scroll()->void:
	if is_instance_valid(scroll):scroll.scroll_vertical=scroll_offset
func _layer(path:String,rect:Array,insets:Array=[],corner_scale:=1.0)->Control:
	var spec:Dictionary={"type":"sprite","source":path,"rectDp":rect}
	if not insets.is_empty():spec.merge({"type":"nineSlice","sourceInsetsLTRB":insets,"uniformCornerScale":corner_scale},true)
	return Art.layer(self,spec)
func _label(id:String,value:String,rect:Rect2,pixels:int,wrap:=false)->Label:
	var label:=Text.label(self,id,value,rect,pixels,wrap);labels[id]=label;return label

func _touch_box(art_box:Rect2)->Rect2:
	#64 source dp × actual short-screen scale0.6916 =44.26px.
	# Grow only transparent input geometry; all art/text coordinates stay fixed.
	var hit_size:=Vector2(maxf(64.0,art_box.size.x),maxf(64.0,art_box.size.y))
	return Rect2(art_box.get_center()-hit_size*.5,hit_size)
