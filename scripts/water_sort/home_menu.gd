extends "res://scripts/shell/home_shell.gd"
## Reuse the approved menu controls, settings, fonts and cream/gold frames.
## Cargo illustrations and cargo copy are deliberately omitted, not overwritten.
const BottleArt = preload("res://scripts/water_sort/art/bottle_visual.gd")
const DISABLED_PAGE_ART := "res://assets/art_review/night_state_supplement_v1/unpacked/STATIC_NIGHT_STATE_SUPPLEMENT_v1/assets/"

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
			"home_hint": field.text = "先看颜色，再留好空位" if locale()=="zh" else "Sort the colors. Save an empty bottle."
			"leaderboard":
				if dynamic and page=="home":
					field.text = "本机记录" if locale()=="zh" else "My Records"
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
	_label(parent,{"id":"water_sort_title","rect_px":[80,190,781,110],"font_px":70,"color":"#FFF1CE"},"倒瓶子" if locale()=="zh" else "Color Sort")
	_label(parent,{"id":"water_sort_subtitle","rect_px":[100,318,741,70],"font_px":30,"color":"#D6B267"},"COLOR SORT" if locale()=="zh" else "A little order. A little color.")
	var colors := [["red","red","yellow","yellow"],["yellow","yellow","red","red"],[]]
	for i in range(3):
		var bottle := BottleArt.new()
		bottle.name = "HomeBottle"+str(i)
		bottle.position = Vector2(261+i*210,550+(30 if i!=1 else 0))
		bottle.scale = Vector2.ONE*0.86
		parent.add_child(bottle)
		bottle.set_layers(colors[i],4.0) # Decorative Node2D has no input surface.
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
			"title": field.text = "本机成绩" if locale()=="zh" else "My Records"
			"status_title": field.text = "仅保存本机成绩" if locale()=="zh" else "Saved on this device"
			"status_body": field.text = "未接入全球排行榜" if locale()=="zh" else "Global rankings are not connected"
			"personal_metric":
				if ranking_tab=="level": field.text = str(record.moves) if not record.is_empty() else "--"
			"personal_time": field.text = _time(float(record.seconds)) if ranking_tab=="level" and not record.is_empty() else (_time(sum_seconds) if ranking_tab=="total" else "--:--")
			"service_hint": field.text = "最佳步数与用时来自同一次通关" if locale()=="zh" else "Moves and time come from the same best run"
	return spec

func _time(seconds: float) -> String:
	return "%02d:%02d" % [int(seconds)/60,int(seconds)%60]

func _unhandled_key_input(event: InputEvent) -> void:
	if visible: super._unhandled_key_input(event)

func _draw_notice() -> void:
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
		return ("续玩不扣体力" if locale()=="zh" else "Resume, no charge") if resuming else ("新局消耗" if locale()=="zh" else "New game cost")
	if resuming and (id=="cost_value" or (id=="cost" and page=="levels")): return "0"
	return super._value(field)

func update_energy(snapshot: Dictionary) -> void:
	var normalized := snapshot.duplicate(true)
	for key in ["energy","cap"]:
		if normalized.get(key) is int or normalized.get(key) is float: normalized[key]=int(normalized[key])
	super.update_energy(normalized)
