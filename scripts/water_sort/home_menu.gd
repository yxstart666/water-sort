extends "res://scripts/shell/home_shell.gd"
## Reference2 order-mode pages; classic campaigns retain their existing shell.
const BottleArt = preload("res://scripts/water_sort/art/bottle_visual.gd")
const SettingsDialog = preload("res://scripts/water_sort/pause_dialog.gd")
const UI=preload("res://scripts/water_sort/reference2_ui.gd")
const ContentDialog=preload("res://scripts/water_sort/order_action_dialog.gd")
const MENU=UI.Assets.ROOT+"reference2_menu_polish_v1/"
const HelpPour=preload("res://scripts/water_sort/order_help_pour.gd")
const EnergyDialog=preload("res://scripts/ui_restore/energy_popup_view.gd")
const GuideDialog=preload("res://scripts/ui_restore/guide_formal_dialog.gd")
var privacy_required:=false
var privacy_action:Callable
var records_scroll_offset:=0
var start_breath_group:Control
var start_breath_phase:=0.0
# Safe default after reported discomfort. Re-enable only for explicit native profiling.
var start_breath_enabled:=false
const START_BREATH_AMOUNT:=0.015
const START_BREATH_PERIOD:=2.8
const DISABLED_PAGE_ART := "res://assets/art_review/night_state_supplement_v1/unpacked/STATIC_NIGHT_STATE_SUPPLEMENT_v1/assets/"

func set_start_breath_enabled(enabled:bool)->void:
	start_breath_enabled=enabled;start_breath_phase=0.0
	if is_instance_valid(start_breath_group):start_breath_group.scale=Vector2.ONE

func _process(delta:float)->void:
	if not start_breath_enabled:return
	if not is_instance_valid(start_breath_group) or not start_breath_group.is_inside_tree():return
	if not is_visible_in_tree() or page!="home" or settings_open or energy_open or is_instance_valid(modal) or not notice_message.is_empty():return
	if not buttons.has("home_start") or buttons.home_start.button_pressed:return
	start_breath_phase=fposmod(start_breath_phase+delta*TAU/START_BREATH_PERIOD,TAU)
	start_breath_group.scale=Vector2.ONE*(1.0+sin(start_breath_phase)*START_BREATH_AMOUNT)

func _refresh() -> void:
	if progress.campaign=="water_sort_orders_v3":
		_refresh_reference2(); return
	# Modal siblings must sit after the fixed energy HUD for GUI hit ordering.
	if is_instance_valid(modal) and modal.get_parent()==self:
		remove_child(modal); modal.queue_free(); modal=null
	super._refresh()

func _fit() -> void:
	if progress.campaign=="water_sort_orders_v3" and is_instance_valid(board) and preload("res://scripts/ui_restore/screen_layout.gd").fit_menu(self,board,REFERENCE):return
	super._fit()
	if progress.campaign=="water_sort_orders_v3" and is_instance_valid(energy_header):
		energy_header.position=Vector2.ZERO; energy_header.scale=Vector2.ONE
	if is_instance_valid(modal) and modal.get_parent()==self and not (modal is SettingsDialog or modal is EnergyDialog or modal is GuideDialog):
		modal.position=board.position; modal.scale=board.scale

func energy_rect_canvas() -> Rect2:
	if progress.campaign=="water_sort_orders_v3" and is_instance_valid(energy_header):
		return energy_header.get_global_transform_with_canvas()*Rect2(49,63.5,233,80)
	return super.energy_rect_canvas()

func _new_modal() -> Control:
	var dialog: Control=super._new_modal()
	dialog.reparent(self,false)
	dialog.position=board.position; dialog.scale=board.scale
	return dialog

func _draw_settings() -> void:
	# The read-only guide temporarily replaces Settings; closing it restores it.
	if not notice_message.is_empty(): return
	var dialog:=SettingsDialog.new(); dialog.home_settings=true
	dialog.configure(progress.data); dialog.size=size; dialog.z_index=200
	dialog.resume.connect(func(): settings_open=false; _refresh())
	dialog.preference_changed.connect(func(key, value):
		progress.set_preference(key,value)
		preferences_changed.emit(progress.data.duplicate(true))
		if progress.data.get(key)!=value:
			show_error("设置未能保存，原设置已保留。" if locale()=="zh" else "Unable to save settings. Previous settings are preserved.")
		else: _refresh())
	dialog.tutorial_requested.connect(func(): tutorial_requested.emit())
	dialog.ui_clicked.connect(func(): ui_clicked.emit())
	modal=dialog; add_child(dialog)
	dialog.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var aliases: Dictionary={"close":"close_settings","music_toggle":"music_toggle_row","sound_toggle":"sound_toggle_row","language":"language_field","how_to_play":"how_to_play"}
	for id in aliases: buttons[aliases[id]]=dialog.buttons[id]

func _hit(parent: Node, id: String, r: Array, action: Callable, enabled: bool=true) -> void:
	super._hit(parent,id,r,action,enabled)
	var targets: Dictionary={"home_start":"home_start_"+locale(),"home_levels":"home_select_levels_"+locale(),"home_ranking":"home_leaderboard_"+locale(),"home_settings":"home_settings","continue":"levels_continue_empty","previous":"levels_previous","next":"levels_next","home_energy":"unified_energy_hud","levels_energy":"unified_energy_hud"}
	if not enabled or not targets.has(id): return
	var picture=parent.get_node_or_null(targets[id])
	if not is_instance_valid(picture): return
	var button: Button=buttons[id]
	button.button_down.connect(func(): picture.modulate=Color(0.92,0.92,0.92))
	button.button_up.connect(func(): picture.modulate=Color.WHITE)
	button.mouse_exited.connect(func(): picture.modulate=Color.WHITE)

func _compose(parent: Node, spec: Dictionary, dynamic: bool = false) -> void:
	var clean: Dictionary = spec.duplicate(true)
	var layers: Array = []
	for layer in clean.get("layers",[]):
		if layer.get("id","") in ["home_hero_no_ui","home_logo","warehouse_no_ui"]: continue
		if dynamic and page=="levels" and progress.level_count>5:
			# Click targets are transparent; Button.disabled cannot tint their
			# separate static art. Reuse existing gray boundary art at the same size.
			var id: String=str(layer.get("id",""))
			if id=="levels_previous" and page_index<=0:
				layer.file=DISABLED_PAGE_ART+"levels_previous_disabled.png"
			elif id=="levels_next" and (page_index+1)*20>=progress.level_count:
				layer.file=DISABLED_PAGE_ART+"levels_next_disabled.png"
		layers.append(layer)
	clean.layers = layers
	for field in clean.get("labels",[]):
		match field.get("id",""):
			"home_hint": field.text = ("装满颜色，交付订单" if locale()=="zh" else "Fill colors. Deliver orders.") if progress.campaign=="water_sort_orders_v3" else ("先看颜色，再留好空位" if locale()=="zh" else "Sort the colors. Save an empty bottle.")
			"leaderboard":
				if dynamic and page=="home":
					field.text = "游戏记录" if locale()=="zh" else "Game Records"
					field.font_px = 36 if locale()=="zh" else 28
			"unlock_hint": field.text = "首次通关，解锁下一关" if locale()=="zh" else "Clear each level to unlock the next"
	if dynamic:
		var background := ColorRect.new()
		background.name = "WaterSortMenuBackground"
		background.color = Color("142d48")
		background.size = REFERENCE
		background.mouse_filter = Control.MOUSE_FILTER_IGNORE
		parent.add_child(background)
	super._compose(parent,clean,dynamic)
	if dynamic and page=="home": _home_identity(parent)

func _home_identity(parent: Node) -> void:
	_label(parent,{"id":"water_sort_title","rect_px":[80,190,781,110],"font_px":70,"color":"#FFF1CE"},"彩瓶时光" if locale()=="zh" else "Color Pause")
	_label(parent,{"id":"water_sort_subtitle","rect_px":[100,318,741,70],"font_px":30,"color":"#D6B267"},("颜色订单 · 50 关" if locale()=="zh" else "COLOR ORDERS · 50 LEVELS") if progress.campaign=="water_sort_orders_v3" else ("COLOR SORT" if locale()=="zh" else "A little order. A little color."))
	var brand := TextureRect.new()
	brand.name="ApprovedWaterSortBrand"
	brand.texture=_texture("res://assets/branding/approved_white_red_blue/icon-512.png")
	brand.position=Vector2(240,440); brand.size=Vector2(460,460)
	brand.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	brand.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	brand.mouse_filter=Control.MOUSE_FILTER_IGNORE
	parent.add_child(brand)
	_label(parent,{"id":"water_sort_campaign","rect_px":[120,950,701,70],"font_px":30,"color":"#CAD8E6"},("%d 关 · 逐关解锁" if locale()=="zh" else "%d levels · Unlock as you play") % progress.level_count)

func _cells(parent: Node) -> void:
	super._cells(parent)
	if progress.level_count>5:
		# Twenty selector cells occupy all four rows. Keep their record labels
		# inside the cells rather than appending an off-screen twenty-row list.
		for slot in range(20):
			var index := page_index*20+slot
			if index>=progress.level_count: break
			var record: Dictionary = progress.best_record(index)
			if record.is_empty(): continue
			var x: int = [102,254,404,553,702][slot%5]
			var y: int = [524,692,868,1048][slot/5]
			_label(parent,{"id":"best_"+str(index),"rect_px":[x+8,y+99,123,34],"font_px":22},("%d步" if locale()=="zh" else "%d moves") % int(record.moves))
		return
	_label(parent,{"id":"records_heading","rect_px":[140,729,661,60],"font_px":30},"本机最佳成绩（先比步数，再比用时）" if locale()=="zh" else "Personal best: moves, then time")
	for index in range(progress.level_count):
		var record: Dictionary = progress.best_record(index)
		var result := "尚未通关" if locale()=="zh" else "Not cleared"
		if not record.is_empty(): result = ("%d 步 · %s" if locale()=="zh" else "%d moves · %s") % [int(record.moves),_time(float(record.seconds))]
		var text := ("第 %d 关     %s" if locale()=="zh" else "Level %d     %s") % [index+1,result]
		_label(parent,{"id":"best_"+str(index),"rect_px":[160,806+index*69,621,58],"font_px":29},text)

func _ranking_spec() -> Dictionary:
	var spec := super._ranking_spec()
	var record: Dictionary = progress.best_record(ranking_level_index)
	var sum_seconds := 0.0
	for index in range(progress.level_count): sum_seconds += float(progress.best_record(index).get("seconds",0.0))
	for field in spec.labels:
		match field.id:
			"title": field.text = "游戏记录" if locale()=="zh" else "Game Records"
			"tab_total": field.text = "全部关卡" if locale()=="zh" else "All Levels"
			"status_title": field.text = "仅保存在本机" if locale()=="zh" else "Saved on this device"
			"status_body": field.text = "未接入全球排行榜" if locale()=="zh" else "Global rankings are not connected"
			"personal_metric":
				if ranking_tab=="level": field.text = str(record.moves) if not record.is_empty() else "--"
			"personal_time": field.text = _time(float(record.seconds)) if ranking_tab=="level" and not record.is_empty() else (_time(sum_seconds) if ranking_tab=="total" else "--:--")
			"service_hint": field.text = "最佳步数与用时来自同一次通关" if locale()=="zh" else "Moves and time come from the same best run"
	return spec

func _time(seconds: float) -> String:
	return "%02d:%02d" % [int(seconds)/60,int(seconds)%60]

func _unhandled_key_input(event: InputEvent) -> void:
	if visible and modal is SettingsDialog and event.is_action_pressed("ui_cancel"):
		modal.cancel(); get_viewport().set_input_as_handled(); return
	if visible: super._unhandled_key_input(event)

func _draw_notice() -> void:
	if progress.campaign=="water_sort_orders_v3":
		_reference_notice(); return
	# The existing short ad-unavailable notice is too small for a full rules page.
	if notice_title not in ["玩法说明","How to play"]:
		super._draw_notice()
		return
	_new_modal()
	_sprite(modal,{"file":"res://assets/art_review/night_state_supplement_v1/unpacked/STATIC_NIGHT_STATE_SUPPLEMENT_v1/assets/dialog_base_728x560.png","top_left_px":[107,385],"display_size_px":[728,950],"9patch_margins_px":[64,64,64,64],"z":20})
	_label(modal,{"id":"rules_title","rect_px":[155,455,630,100],"font_px":48},notice_title)
	_label(modal,{"id":"rules_body","rect_px":[165,590,610,475],"font_px":30},notice_message)
	label_nodes.rules_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_sprite(modal,{"file":"res://assets/art_review/nonrobot_animation_bcde_v1/unpacked/batch_d_ui_feedback/batch_d_ui_feedback/assets/button_primary_610x128.png","top_left_px":[165,1145],"z":35})
	_label(modal,{"id":"rules_close_label","rect_px":[190,1164,560,88],"font_px":42},"返回设置" if locale()=="zh" else "Back to Settings")
	_hit(modal,"rules_close",[165,1145,610,128],func(): notice_message=""; notice_title=""; _refresh())

func _value(field: Dictionary) -> String:
	var id := str(field.get("id",""))
	var resuming := resume_index>=0 and resume_index==continue_index()
	if id=="cost" and page=="home":
		return "" if resuming else ("新局消耗" if locale()=="zh" else "New game cost")
	if resuming and (id=="cost_value" or (id=="cost" and page=="levels")): return "0"
	return super._value(field)

func update_energy(snapshot: Dictionary) -> void:
	var normalized := snapshot.duplicate(true)
	for key in ["energy","cap"]:
		if normalized.get(key) is int or normalized.get(key) is float: normalized[key]=int(normalized[key])
	if is_instance_valid(modal) and modal.has_node("LiveHelpPour"):
		# A one-second energy tick must not rebuild the interactive lesson.
		energy_state={"current":normalized.get("energy","--"),"capacity":normalized.get("cap",30),"cost":5,"next_recovery_seconds":normalized.get("next_recovery_seconds",0),"ok":normalized.get("ok",true),"ad_available":normalized.get("ad_available",false),"ad_retry_available":normalized.get("ad_retry_available",false)}
		if label_nodes.has("energy") and is_instance_valid(label_nodes.energy): label_nodes.energy.text="%s/%s" % [energy_state.current,energy_state.capacity]
		for label in modal.find_children("energy","Label",true,false): label.text="%s/%s" % [energy_state.current,energy_state.capacity]
		return
	if progress.campaign=="water_sort_orders_v3" and is_instance_valid(modal) and modal is EnergyDialog:
		energy_state={"current":normalized.get("energy","--"),"capacity":normalized.get("cap",30),"cost":5,"next_recovery_seconds":normalized.get("next_recovery_seconds",0),"ok":normalized.get("ok",true),"ad_available":normalized.get("ad_available",false),"ad_retry_available":normalized.get("ad_retry_available",false),"notice":normalized.get("notice","")}
		# Match the previous pressed-button guard; a tick cannot change its action mid-press.
		for button in modal.buttons.values():
			if is_instance_valid(button) and button.button_pressed:return
		modal.present(_energy_presentation())
		for id in ["energy_close","energy_later","energy_watch_ad"]:buttons.erase(id)
		buttons.merge(modal.buttons,true);label_nodes.merge(modal.labels,true)
		if label_nodes.has("energy") and is_instance_valid(label_nodes.energy):label_nodes.energy.text="%s/%s" % [energy_state.current,energy_state.capacity]
		return
	var settings_visible:bool=settings_open and is_instance_valid(modal) and modal is SettingsDialog and modal.home_settings
	var idle_home:bool=page=="home" and not settings_open and not is_instance_valid(modal)
	if progress.campaign=="water_sort_orders_v3" and is_instance_valid(board) and not energy_only and not energy_open and notice_message.is_empty() and (idle_home or settings_visible):
		# Energy ticks do not change home/settings structure. Keep the active Settings
		# nodes, switches, focus and opening/closing Tween; update its underlying HUD.
		# Preference changes and navigation still use their explicit _refresh routes.
		energy_state={"current":normalized.get("energy") if normalized.get("energy")!=null else "--","capacity":normalized.get("cap",30),"cost":5,"next_recovery_seconds":normalized.get("next_recovery_seconds") if normalized.get("next_recovery_seconds")!=null else 0,"ok":normalized.get("ok",true),"ad_available":normalized.get("ad_available",false),"ad_retry_available":normalized.get("ad_retry_available",false),"notice":normalized.get("notice","")}
		if label_nodes.has("energy") and is_instance_valid(label_nodes.energy):label_nodes.energy.text="%s/%s" % [energy_state.current,energy_state.capacity]
		return
	super.update_energy(normalized)

func _rword(zh: String,en: String) -> String: return zh if locale()=="zh" else en
func _menu_hit(parent: Node,id: String,box: Rect2,action: Callable,enabled:=true) -> void:
	var extent:=Vector2(maxf(150,box.size.x),maxf(150,box.size.y))
	var origin:=box.get_center()-extent*0.5
	_hit(parent,id,[origin.x,origin.y,extent.x,extent.y],action,enabled)
	# Authored button faces stay separate from their accessible hit regions.
	# Apply the same visible press/disabled feedback as dynamic UI buttons.
	for child in parent.get_children():
		if not child.get_meta("pause_button_face",false): continue
		if not child.get_rect().has_point(box.get_center()): continue
		child.modulate=Color.WHITE if enabled else Color(0.48,0.53,0.61,0.8)
		if enabled:
			buttons[id].button_down.connect(func(): if is_instance_valid(child): child.modulate=Color(0.92,0.92,0.92))
			buttons[id].button_up.connect(func(): if is_instance_valid(child): child.modulate=Color.WHITE)
func _menu_bottle(parent: Node,id: String,box: Rect2,layers: Array) -> void:
	var bottle= BottleArt.new(); bottle.name=id; parent.add_child(bottle); bottle.use_delivered_layers()
	var contract: Dictionary=UI.Assets.BOTTLE_CONTRACT
	var factor:=minf(box.size.x/165.0,box.size.y/410.0)
	bottle.scale=Vector2.ONE*factor/float(contract.normalization)
	bottle.position=box.position+(box.size-Vector2(165,410)*factor)*0.5+contract.mouth*factor
	bottle.set_layers(layers)
func _polish_layout(layout_name: String,parent: Node,skip: Callable) -> void:
	var spec: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(MENU+"layouts/"+layout_name+"_"+locale()+".json"))
	var sequence:=0
	if layout_name=="graphical_help":
		var illustration:=HelpPour.new(); illustration.name="LiveHelpPour"; illustration.size=Vector2(940,1672); illustration.locale=locale(); parent.add_child(illustration); illustration.z_index=1
	for item in spec.elements:
		sequence+=1
		if skip.call(item): continue
		if layout_name=="graphical_help" and float(item.rect[1])>=395 and float(item.rect[1])<1416: continue
		var r: Array=item.rect
		var box:=Rect2(r[0],r[1],r[2],r[3])
		if layout_name=="home" and float(item.rect[1]) in [250.0,375.0]: continue
		if layout_name=="home" and locale()=="en":
			if box.position.y==375: continue
		var id: String="MenuElement"+str(sequence)
		if item.kind=="text":
			var caption: String=item.text
			match str(item.get("binding","")):
				"resume_level": caption=(_rword("第 %d 关","Level %d") % (continue_index()+1)) if resume_index>=0 else ""
				"completed_count": caption=_rword("已通关 %d / %d","Cleared %d / %d") % [progress.data.completed.size(),progress.level_count]
				"page_index/page_count": caption="%d / %d" % [page_index+1,ceili(progress.level_count/20.0)]
				"continue_label(actual_resume_level)": caption=_rword("继续第 %d 关","Continue level %d") % (continue_index()+1)
			if layout_name=="home":
				if caption in ["本机记录","Records"]:
					id="home_records_caption"; caption=_rword("游戏记录","Game Records")
				if box.position.y==250:
					id="water_sort_title"; caption=_rword("彩瓶时光","Color Pause")
				if r[1]==375: caption="Color Pause"
				if r[1]==1112 and resume_index<0: caption=_rword("开始游戏","Start playing")
				if r[1]==1515: caption="" # Remove the home resume-energy claim in every state.
			if layout_name=="graphical_help" and box.position.y==1114: id="rules_body"
			var label:=_rlabel(parent,id,caption,box,int(item.font_size),Color(item.color))
			for surface in spec.elements:
				if surface.get("asset","") in ["assets/primary.png","assets/secondary.png"]:
					var r0: Array=surface.rect
					if Rect2(r0[0],r0[1],r0[2],r0[3]).has_point(box.get_center()): label.add_theme_color_override("font_color",UI.PANEL_INK)
			if item.get("align","")=="left": label.horizontal_alignment=HORIZONTAL_ALIGNMENT_LEFT
		elif item.kind=="ninepatch":
			if item.asset in ["assets/primary.png","assets/secondary.png"]:
				UI.face(parent,id,box,item.asset=="assets/secondary.png");continue
			var panel:=UI.panel(parent,id,box)
			panel.texture=UI.texture(MENU+item.asset)
			for edge in 4: panel.set_patch_margin(edge,int(item.margins[edge]))
		else:
			var asset: String=item.asset
			if layout_name=="graphical_help" and asset!="assets/help_card.png":
				continue
			if asset=="assets/pour_diagram.png":
				var illustration:=HelpPour.new(); illustration.name="LiveHelpPour"; illustration.position=box.position; illustration.size=box.size; parent.add_child(illustration)
			elif layout_name=="home" and asset in ["assets/warm.png","assets/blue_low.png","assets/mixed.png"]:
				continue
			else:
				if asset in ["assets/primary.png","assets/secondary.png"]:
					UI.face(parent,id,box,asset=="assets/secondary.png");continue
				var path: String=UI.PRIMARY if asset=="assets/primary.png" else (UI.SECONDARY if asset=="assets/secondary.png" else MENU+asset)
				var picture:=UI.picture(parent,id,path,box); picture.stretch_mode=TextureRect.STRETCH_SCALE
				if asset not in ["assets/primary.png","assets/secondary.png"]:
					for surface in spec.elements:
						if surface.get("asset","")!="assets/secondary.png": continue
						var r0:Array=surface.rect
						if Rect2(r0[0],r0[1],r0[2],r0[3]).has_point(box.get_center()): picture.modulate=UI.PANEL_INK
				if layout_name=="level_select" and ((box.position==Vector2(250,1414) and page_index==0) or (box.position==Vector2(638,1414) and (page_index+1)*20>=progress.level_count)): picture.modulate=Color(0.45,0.5,0.6,0.65)
func _menu_back_art(parent: Node) -> void:
	var base:=UI.picture(parent,"MenuBackBase","res://assets/colorpause_ui_20261030/sprites/blue_square_normal_clean.webp",Rect2(798,54,94,94));base.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS;base.set_meta("pause_button_face",true)
	var arrow:=UI.picture(parent,"MenuBackArrow","res://assets/colorpause_ui_20261030/data_page_components/sprites/pager_chevron_right.webp",Rect2(820,73,50,55));arrow.flip_h=true;arrow.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
func _polish_home() -> void:
	# Candidate title/frame replace the obsolete logo, shared title-strip frame
	# and old tagline. The approved current buttons remain in their exact slots.
	_polish_layout("home",board,func(item): return float(item.rect[1])<160 or float(item.rect[1])==1000 or (float(item.rect[1])>=1080 and float(item.rect[1])<1460))
	board.add_child(preload("res://scripts/ui_restore/home_brand_view.gd").new())
	var pages: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/colorpause_ui_20261030_home_layout.json"))
	var selected: Dictionary={}
	for page_spec in pages.pages:
		if page_spec.viewport[0]==390 and page_spec.locale==("zh-CN" if locale()=="zh" else "en"): selected=page_spec; break
	var pieces: Dictionary={}
	for layer in selected.layers:
		if locale()=="zh" and (str(layer.id).begins_with("levels_") or str(layer.id).begins_with("game_records_")):continue
		if layer.id=="settings":continue
		var a: Array=layer.rectDp.duplicate();
		if str(layer.id).begins_with("main_"):a[1]-=14
		if str(layer.id).begins_with("levels_") or str(layer.id).begins_with("game_records_"):a[1]-=24
		var path: String=str(layer.source).trim_prefix("runtime/")
		if layer.id=="main_label" and resume_index>=0:
			path="controls/labels/continue_zh-CN.webp" if locale()=="zh" else "english_art_labels/labels/continue_en.webp"
		var picture:=UI.picture(board,"NewHome_"+str(layer.id),"res://assets/colorpause_ui_20261030/"+path,_home_scaled_rect(Rect2(a[0],a[1],a[2],a[3])))
		picture.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		pieces[layer.id]=picture
	var original:=preload("res://scripts/ui_restore/original_button_art.gd")
	pieces.settings=original.gear(board,"NewHome_settings",_home_scaled_rect(Rect2(317,11,62,62.45)))
	if locale()=="zh":
		pieces.levels_base=original.picture(board,"NewHome_levels_complete","full_buttons/button_levels_zh_normal.png",_home_scaled_rect(Rect2(81.9,550,109.2,99.87)))
		pieces.game_records_base=original.picture(board,"NewHome_game_records_complete","full_buttons/button_records_zh_normal.png",_home_scaled_rect(Rect2(198.9,550,109.2,99.87)))
	var main_box:Rect2=pieces.main_base.get_rect();main_box.size.y=main_box.size.x*760.0/2070.0
	pieces.main_base.size=main_box.size
	pieces.main_base.texture=load("res://art/colorpause/ui_unified_20261030/start/assets/"+("start_zh_blank_level_slot.png" if locale()=="zh" and resume_index<0 else "start_localized_blank_plate.png"))
	pieces.main_base.stretch_mode=TextureRect.STRETCH_SCALE
	var source_scale:float=main_box.size.x/2070.0
	pieces.main_label.visible=not (locale()=="zh" and resume_index<0)
	pieces.main_label.position=main_box.position+Vector2(350,120)*source_scale;pieces.main_label.size=Vector2(1394,384)*source_scale
	var caption_box:=Rect2(main_box.position+Vector2(750,520)*source_scale,Vector2(558,132)*source_scale)
	var current_level:=preload("res://scripts/ui_restore/data_text.gd").label(board,"HomeCurrentLevel",("第%d关" if locale()=="zh" else "%d") % (continue_index()+1),caption_box,32)
	var binding=preload("res://scripts/ui_restore/numeric_label_binding.gd").new();binding.family="home";binding.face_pixels=77*source_scale;binding.prefix="Level" if locale()=="en" else "";current_level.add_child(binding)
	current_level.accessibility_name=_rword("第%d关","Level %d") % (continue_index()+1);label_nodes.home_current_level=current_level
	var factor:=940.0/390.0
	_home_asset_hit("home_settings",_home_scaled_rect(Rect2(317,11,62,62.45)),func(): settings_open=true; _refresh(),[pieces.settings])
	# Both approved2070x760 plates have the same nontransparent bounds.
	# Exclude the transparent bottom gutter from input so the expanded state cannot
	# steal the adjacent Levels/Records buttons' top edge.
	var main_hit_box:=Rect2(main_box.position+Vector2(22,21)*source_scale,Vector2(2020,699)*source_scale)
	_home_asset_hit("home_start",main_hit_box,func(): _start(continue_index()),[pieces.main_base,pieces.main_label,current_level])
	_home_asset_hit("home_levels",_home_scaled_rect(Rect2(81.9,550,109.2,99.87)),_open_levels,[pieces.levels_base] if locale()=="zh" else [pieces.levels_base,pieces.levels_icon,pieces.levels_label])
	_home_asset_hit("home_ranking",_home_scaled_rect(Rect2(198.9,550,109.2,99.87)),func(): show_ranking("home"),[pieces.game_records_base] if locale()=="zh" else [pieces.game_records_base,pieces.game_records_icon,pieces.game_records_label])
	# One centered scale transforms both the approved material and its actual input region.
	# Retain phase across energy refreshes and returns; there are no stacked Tweens.
	start_breath_group=Control.new();start_breath_group.name="StartButtonBreath";start_breath_group.set_meta("screen_anchor","bottom");start_breath_group.mouse_filter=Control.MOUSE_FILTER_IGNORE;start_breath_group.size=board.size;start_breath_group.pivot_offset=main_box.get_center();board.add_child(start_breath_group)
	for part in [pieces.main_base,pieces.main_label,current_level,buttons.home_start]:
		var original_position:Vector2=part.position;board.remove_child(part);start_breath_group.add_child(part);part.position=original_position
	start_breath_group.scale=Vector2.ONE*(1.0+sin(start_breath_phase)*START_BREATH_AMOUNT) if start_breath_enabled else Vector2.ONE

func _home_scaled_rect(r: Rect2) -> Rect2:
	return Rect2(r.position*(940.0/390.0),r.size*(940.0/390.0))

func _home_asset_hit(id: String, box: Rect2, action: Callable, pieces: Array) -> void:
	_menu_hit(board,id,box,action)
	var button: Button=buttons[id]
	button.button_down.connect(func():
		for part in pieces:
			if is_instance_valid(part): part.modulate=Color(0.9,0.9,0.9))
	button.button_up.connect(func():
		for part in pieces:
			if is_instance_valid(part): part.modulate=Color.WHITE)
	button.mouse_exited.connect(func():
		for part in pieces:
			if is_instance_valid(part): part.modulate=Color.WHITE)
func _rlabel(parent: Node,id: String,value: String,box: Rect2,pixels:=34,color:=UI.INK,wrap_text:=false) -> Label:
	var node:=UI.label(parent,id,value,box,locale(),pixels,color,wrap_text); label_nodes[id]=node; return node
func _rbutton(parent: Node,id: String,value: String,box: Rect2,action: Callable,pill:=false) -> Button:
	if box.size.y<126: box=Rect2(box.position-Vector2(0,(126-box.size.y)*0.5),Vector2(box.size.x,126))
	var node:=UI.button(parent,id,value,box,locale(),func(): action.call(); ui_clicked.emit(),pill); buttons[id]=node; return node

func _new_shared_panel(parent: Node, id: String, box: Rect2) -> NinePatchRect:
	var factor: float=minf(0.69,minf(box.size.x/470.0,box.size.y/470.0))
	var panel:=NinePatchRect.new();panel.name=id;panel.texture=load("res://assets/colorpause_ui_20261030/sprites/panel_normal_9slice_candidate.webp");panel.position=box.position;panel.size=box.size/factor;panel.scale=Vector2.ONE*factor;panel.mouse_filter=Control.MOUSE_FILTER_IGNORE;panel.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	for edge in 4: panel.set_patch_margin(edge,230)
	parent.add_child(panel);return panel
func _refresh_reference2() -> void:
	for child in get_children():
		if child!=board: remove_child(child); child.queue_free()
	energy_header=null; modal=null; buttons.clear(); label_nodes.clear(); _clear(board)
	if energy_only:
		_draw_energy(); _fit(); return
	UI.backdrop(board)
	_reference_energy_header()
	if page=="home":
		_polish_home();refresh_privacy_entry()
	elif page=="levels": _reference_levels()
	else: _reference_records()
	if settings_open and not review_obscures_modal: _draw_settings()
	elif energy_open: _draw_energy()
	if not notice_message.is_empty(): _draw_notice()
	_fit()
func _reference_energy_header() -> void:
	energy_header=Control.new(); energy_header.name="Reference2EnergyHeader"; energy_header.mouse_filter=Control.MOUSE_FILTER_IGNORE; board.add_child(energy_header)
	UI.picture(energy_header,"EnergyPill","reference2_energy_component_v1/assets/energy_pill_base.png",Rect2(49,63.5,233,80))
	UI.picture(energy_header,"EnergyBolt","reference2_energy_component_v1/assets/energy_bolt.png",Rect2(59,69.5,48,68))
	_rlabel(energy_header,"energy","%s/%s" % [energy_state.get("current","--"),energy_state.get("capacity",30)],Rect2(110,80.5,125,46),35)
	UI.picture(energy_header,"EnergyPlus",UI.Assets.FINISH+"plus_gold.png",Rect2(231,83.5,40,40))
	_hit(energy_header,page+"_energy",[49,23.5,233,160],_energy)
func _reference_hero() -> void:
	for index in 2:
		var bottle= BottleArt.new(); bottle.name="Reference2Hero"+str(index); board.add_child(bottle); bottle.use_delivered_layers()
		var contract: Dictionary=UI.Assets.BOTTLE_CONTRACT
		bottle.scale=Vector2.ONE/float(contract.normalization)
		bottle.position=Vector2(285+205*index,580)+contract.mouth
		bottle.set_layers(["blue","green","yellow","red"] if index==0 else ["orange","purple","yellow"])
func _open_levels() -> void:
	if progress.campaign!="water_sort_orders_v3":super._open_levels();return
	page_index=continue_index()/preload("res://scripts/ui_restore/level_select_view.gd").PAGE_SIZE
	show_page("levels")

func _reference_levels() -> void:
	var LevelSelect=preload("res://scripts/ui_restore/level_select_view.gd")
	page_index=clampi(page_index,0,maxi(0,ceili(progress.level_count/float(LevelSelect.PAGE_SIZE))-1))
	var view=LevelSelect.new();view.locale=locale();view.current_index=continue_index();view.page_index=page_index
	var all_allowed:=true
	for index in progress.level_count:
		var allowed:bool=progress.unlocked(index) or index==resume_index
		view.model.append({"allowed":allowed,"completed":progress.completed(index)})
		all_allowed=all_allowed and allowed
	view.all_open_test_profile=all_allowed and bool(ProjectSettings.get_setting("development/difficulty_playtest",false))
	view.select_requested.connect(_start)
	view.page_requested.connect(func(index:int):page_index=index;_refresh())
	view.back_requested.connect(func():show_page("home"))
	view.size=LevelSelect.REFERENCE
	var factor:=minf(940.0/LevelSelect.REFERENCE.x,1672.0/LevelSelect.REFERENCE.y)
	view.scale=Vector2.ONE*factor;view.position=(Vector2(940,1672)-LevelSelect.REFERENCE*factor)*.5
	board.add_child(view);buttons.merge(view.buttons);label_nodes.merge(view.labels)

func _reference_records() -> void:
	var view=preload("res://scripts/ui_restore/records_view.gd").new()
	view.locale=locale();view.tab=ranking_tab;view.scroll_offset=records_scroll_offset
	view.model=preload("res://scripts/ui_restore/records_presenter.gd").from_progress(progress)
	view.size=Vector2(390,694);view.scale=Vector2.ONE*(940.0/390.0)
	view.tab_requested.connect(_select_ranking_tab)
	view.back_requested.connect(_return_from_ranking)
	view.scroll_changed.connect(func(offset:int):records_scroll_offset=offset)
	board.add_child(view)
	buttons.merge(view.buttons);label_nodes.merge(view.labels)

func _energy_presentation() -> Dictionary:
	var value:Variant=energy_state.get("current","--")
	var readable:bool=(value is int or value is float) and bool(energy_state.get("ok",true))
	var full:bool=readable and value>=energy_state.get("capacity",30)
	# Existing host eligibility is retained; the view never starts an ad itself.
	var available:bool=(energy_state.get("ad_retry_available",false) or (readable and not full and energy_state.get("ad_available",false)))
	return preload("res://scripts/ui_restore/energy_dialog_model.gd").present(energy_state,locale(),available,str(energy_state.get("notice","")))

func _draw_energy() -> void:
	if progress.campaign!="water_sort_orders_v3":super._draw_energy();return
	var dialog:=EnergyDialog.new();dialog.locale=locale();dialog.model=_energy_presentation();dialog.size=size;dialog.z_index=200
	dialog.close_requested.connect(func():
		energy_open=false
		if energy_only:energy_closed.emit()
		else:_refresh())
	dialog.ad_requested.connect(func():energy_ad_requested.emit())
	modal=dialog;add_child(dialog);dialog.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	buttons.merge(dialog.buttons,true);label_nodes.merge(dialog.labels,true)

func _reference_notice() -> void:
	var rules: bool=notice_title in ["玩法说明","How to play"]
	if rules:
		var dialog:=GuideDialog.new();dialog.locale=locale();dialog.energy_text="%s/%s" % [energy_state.get("current","--"),energy_state.get("capacity",30)]
		dialog.closed=func():notice_message="";notice_title="";_refresh()
		dialog.size=size;dialog.z_index=200;modal=dialog;add_child(dialog);dialog.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		buttons.merge(dialog.guide.buttons,true)
		return
	_new_modal()
	var dismiss:=func(): notice_message=""; notice_title=""; _refresh()
	var dialog:=ContentDialog.new();dialog.locale=locale();dialog.heading=notice_title;dialog.body=notice_message;dialog.size=Vector2(940,1672)
	modal.add_child(dialog);dialog.shade.hide() # Existing host dimmer uses the pause alpha.
	buttons.error_action=dialog.add_action("NoticeDismiss",_rword("返回","Back"),dismiss)
	buttons.error_close=dialog.add_close("NoticeClose",dismiss)
	label_nodes.title=dialog.title_label;label_nodes.body=dialog.body_label

func refresh_privacy_entry()->void:
	if not is_instance_valid(board):return
	for id in ["privacy_options","privacy_options_Face"]:
		var old=board.get_node_or_null(id)
		if is_instance_valid(old):board.remove_child(old);old.queue_free()
	buttons.erase("privacy_options")
	if page=="home" and privacy_required and privacy_action.is_valid():
		_rbutton(board,"privacy_options",_rword("隐私选择","Privacy choices"),Rect2(350,50,300,126),func():privacy_action.call())
