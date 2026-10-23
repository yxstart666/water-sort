extends Control
signal start_level(index: int)
signal preferences_changed(values: Dictionary)
signal energy_requested
signal energy_closed
signal ui_clicked
signal tutorial_requested
signal ranking_return_to_game
const Progress = preload("res://scripts/shell/campaign_progress.gd")
const Typography = preload("res://scripts/ui_restore/typography.gd")
const MENUS = "res://assets/ui_restore/menu_candidates_v1/"
const REFERENCE = Vector2(941, 1672)
var progress = Progress.new()
var energy_state: Dictionary = {} # Inject authoritative energy service snapshot.
var page := "home"
var page_index := 0
var ranking_tab := "level"
var ranking_level_index := 0
var ranking_origin := "home"
var review_obscures_modal := false
var resume_index := -1
var energy_open := false
var energy_only := false
var notice_message := ""
var notice_title := ""
var settings_open := false
var language_expanded := false
var energy_header: Control
var board: Control
var modal: Control
var settings_guide_compositions: Dictionary
var compositions: Dictionary
var textures := {}
var errors: Array = []
var buttons := {}
var label_nodes := {}

func _ready() -> void:
	settings_guide_compositions = JSON.parse_string(FileAccess.get_file_as_string("res://scripts/shell/settings_guide_compositions.json"))
	compositions = JSON.parse_string(FileAccess.get_file_as_string("res://scripts/shell/compositions.json"))
	board = Control.new()
	board.mouse_filter = Control.MOUSE_FILTER_IGNORE
	board.size = REFERENCE
	add_child(board)
	resized.connect(_fit)
	show_page("home")

func locale() -> String:
	return str(progress.data.get("locale", "zh"))

func _fit() -> void:
	var factor := minf(size.x / REFERENCE.x, size.y / REFERENCE.y)
	board.scale = Vector2.ONE * factor
	board.position = (size - REFERENCE * factor) * 0.5
	if is_instance_valid(energy_header):
		var header_scale := minf(size.x/1080.0,size.y/1920.0)
		energy_header.scale = Vector2.ONE*header_scale
		energy_header.position = (size-Vector2(1080,1920)*header_scale)*0.5

func _clear(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()

func show_page(value: String) -> void:
	if value not in ["home", "levels", "ranking"]:
		return
	page = value
	settings_open = false
	energy_open = false
	language_expanded = false
	_refresh()

func _refresh() -> void:
	if is_instance_valid(energy_header):
		remove_child(energy_header)
		energy_header.queue_free()
	energy_header = null
	_clear(board)
	buttons.clear()
	label_nodes.clear()
	modal = null
	if energy_only:
		_draw_energy()
		_fit()
		return
	var key := ("ranking_total_not_connected_" if page == "ranking" else page + "_localized_") + locale()
	var page_spec: Dictionary = _ranking_spec() if page == "ranking" else compositions[key]
	_compose(board, page_spec, true)
	energy_header = Control.new()
	energy_header.name = "UnifiedEnergyCanvas1080x1920"
	energy_header.size = Vector2(1080,1920)
	energy_header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(energy_header)
	for layer in compositions[key].layers:
		if layer.id == "unified_energy_hud": _sprite(energy_header,layer)
	for field in compositions[key].labels:
		if field.id == "energy": _label(energy_header,field,_value(field))
	if page == "home":
		_hit(board, "home_start", [158,1092,629,192], func(): _start(continue_index()))
		_hit(board, "home_levels", [51,1378,411,137], _open_levels)
		_hit(board, "home_ranking", [480,1378,411,138], func(): show_ranking("home"))
		_hit(board, "home_settings", [810,24,116,116], func(): settings_open = true; _refresh())
		_hit(energy_header, "home_energy", [24,14,262,116], _energy)
	elif page == "levels":
		_hit(board, "back", [810,24,116,116], func(): show_page("home"))
		_hit(board, "previous", [222,1243,136,94], func(): page_index = maxi(0,page_index-1); _refresh(), page_index > 0)
		_hit(board, "next", [585,1243,136,94], func(): page_index = mini((progress.level_count-1)/20,page_index+1); _refresh(), (page_index+1)*20 < progress.level_count)
		_hit(board, "continue", [141,1406,660,166], func(): _start(continue_index()))
		_hit(energy_header, "levels_energy", [24,14,262,116], _energy)
	else:
		_hit(board, "back", [810,24,116,116], _return_from_ranking)
		_hit(board, "ranking_return", [143,1418,657,164], _return_from_ranking)
		_hit(board, "ranking_level", [202,353,269,116], func(): _select_ranking_tab("level"))
		_hit(board, "ranking_total", [471,353,270,116], func(): _select_ranking_tab("total"))
		_hit(energy_header, "ranking_energy", [24,14,262,116], _energy)
	if settings_open and not review_obscures_modal:
		_draw_settings()
	elif energy_open:
		_draw_energy()
	if not notice_message.is_empty(): _draw_notice()
	_fit()

func _open_levels() -> void:
	page_index = continue_index() / 20
	show_page("levels")

func _start(index: int) -> void:
	if progress.unlocked(index) or index == resume_index:
		start_level.emit(index)

func _energy() -> void:
	energy_requested.emit()
	energy_open = true
	_refresh()

func _texture(path: String) -> Texture2D:
	if not textures.has(path):
		var image := Image.new()
		if image.load_png_from_buffer(FileAccess.get_file_as_bytes(path)) != OK:
			errors.append(path)
			return null
		image.generate_mipmaps()
		textures[path] = ImageTexture.create_from_image(image)
	return textures[path]

func _compose(parent: Node, spec: Dictionary, dynamic: bool = false) -> void:
	for original in spec.get("layers", []):
		var layer: Dictionary = original.duplicate(true)
		var id := str(layer.get("id", ""))
		if dynamic and id == "unified_energy_hud": continue
		if dynamic and page == "levels" and id.begins_with("level_slot_"):
			continue
		if dynamic and page == "levels" and id == "levels_previous" and page_index > 0:
			layer.file = MENUS + "assets/levels/levels_previous.png"
		_sprite(parent,layer)
	for field in spec.get("labels", []):
		if dynamic and field.id == "energy": continue
		if dynamic and page == "levels" and (str(field.id).begins_with("level_slot_") or field.id == "current"):
			continue
		_label(parent,field,_value(field) if dynamic else _resolved_text(str(field.get("text", ""))))
	if dynamic and page == "levels":
		_cells(parent)

func _sprite(parent: Node, layer: Dictionary) -> void:
	if layer.has("9patch_margins_px"):
		var patch := NinePatchRect.new()
		patch.texture = _texture(layer.file)
		patch.position = Vector2(layer.top_left_px[0],layer.top_left_px[1])
		patch.size = Vector2(layer.display_size_px[0],layer.display_size_px[1])
		for edge in range(4): patch.set_patch_margin(edge,int(layer["9patch_margins_px"][edge]))
		patch.z_index = int(layer.get("z",30))
		patch.mouse_filter = Control.MOUSE_FILTER_IGNORE
		parent.add_child(patch)
		return
	var node := Sprite2D.new()
	node.texture = _texture(layer.file)
	if layer.has("source_crop_px"):
		var crop: Array=layer.source_crop_px
		var atlas:=AtlasTexture.new()
		atlas.atlas=node.texture
		atlas.region=Rect2(crop[0],crop[1],crop[2],crop[3])
		node.texture=atlas
	node.name = str(layer.get("id",str(layer.file).get_file()))
	node.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	node.centered = false
	if layer.has("render_size_px") and node.texture != null:
		node.scale = Vector2(layer.render_size_px[0],layer.render_size_px[1]) / node.texture.get_size()
	node.position = Vector2(layer.top_left_px[0],layer.top_left_px[1])
	node.z_index = int(layer.get("z",30))
	if layer.has("rotation_degrees"):
		node.rotation_degrees = layer.rotation_degrees
		if node.texture != null:
			node.position += node.texture.get_size()
	parent.add_child(node)

func _label(parent: Node, field: Dictionary, value: String) -> void:
	var node := Label.new()
	if field.has("id"): label_nodes[field.id] = node
	var r: Array = field.rect_px
	node.position = Vector2(r[0],r[1])
	node.size = Vector2(r[2],r[3])
	node.text = value
	node.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	node.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	node.add_theme_font_override("font", Typography.font("latin" if locale() == "en" or str(field.get("id","")) in ["energy","capacity","recovery_time","cost_value","personal_time"] else "cjk_face0"))
	node.add_theme_font_size_override("font_size",int(field.get("font_px",36)))
	node.add_theme_color_override("font_color",Color(field.get("color","#123A59")))
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.z_index = int(field.get("z",99))
	parent.add_child(node)
	Typography.center_label(node,Rect2(r[0],r[1],r[2],r[3]))

func _value(field: Dictionary) -> String:
	var id: String = field.id
	if id == "energy":
		return "%s/%s" % [energy_state.get("current","--"),energy_state.get("capacity","--")]
	if id == "home_continue":
		var copy := ("继续第%s关" if locale() == "zh" else "Continue Level %s") if resume_index >= 0 else ("开始第%s关" if locale() == "zh" else "Play Level %s")
		return copy % (continue_index()+1)
	if id == "page_range":
		return "%s–%s" % [page_index*20+1,mini((page_index+1)*20,progress.level_count)]
	if id == "cost_value" or page == "levels" and id == "cost":
		return str(energy_state.get("cost","--"))
	return str(field.get("text", "")).replace("{level}", str(continue_index()+1))

func _cells(parent: Node) -> void:
	for slot in range(20):
		var index := page_index*20+slot
		if index >= progress.level_count: break
		var x: int = [102,254,404,553,702][slot%5]
		var y: int = [524,692,868,1048][slot/5]
		var state := "completed" if progress.completed(index) else ("current" if progress.unlocked(index) or index == resume_index else "locked")
		_sprite(parent,{"file":MENUS+"assets/levels/level_cell_"+state+"_empty.png","top_left_px":[x,y],"z":30})
		_label(parent,{"rect_px":[x+25,y+21,90,70],"font_px":40},str(index+1))
		_hit(parent,"level_"+str(index+1),[x,y,139,146],func(): _start(index),progress.unlocked(index) or index == resume_index)

func _hit(parent: Node, id: String, r: Array, action: Callable, enabled: bool = true) -> void:
	var button := Button.new()
	button.name = id
	button.position = Vector2(r[0],r[1])
	button.size = Vector2(r[2],r[3])
	button.flat = true
	button.disabled = not enabled
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if enabled else Control.CURSOR_ARROW
	for state in ["normal","hover","pressed","disabled","focus"]:
		button.add_theme_stylebox_override(state,StyleBoxEmpty.new())
	button.z_index = 100
	button.pressed.connect(func(): action.call(); ui_clicked.emit())
	parent.add_child(button)
	buttons[id] = button

func _new_modal() -> Control:
	modal = Control.new()
	modal.size = REFERENCE
	modal.z_index = 200
	board.add_child(modal)
	var dim := ColorRect.new()
	dim.size = REFERENCE
	dim.color = Color(7.0/255,29.0/255,56.0/255,148.0/255)
	dim.gui_input.connect(func(event):
		if language_expanded and event is InputEventMouseButton and event.pressed:
			language_expanded = false
			get_viewport().set_input_as_handled()
			_refresh())
	modal.add_child(dim)
	return modal

func _draw_settings() -> void:
	_new_modal()
	var key := "home_settings_guide_%s_music_%s_sound_%s_%s" % [locale(),"on" if progress.data.music else "off","on" if progress.data.sound else "off","expanded" if language_expanded else "closed"]
	var spec: Dictionary = settings_guide_compositions[key]
	_compose(modal,spec)
	var aliases := {"close":"close_settings","music_toggle":"music_toggle_row","sound_toggle":"sound_toggle_row","language_dropdown":"language_field"}
	for target in spec.active_hit_targets:
		var id: String = aliases.get(target.id,target.id)
		_hit(modal,id,target.rect,func(): _settings_action(id))

func _settings_action(id: String) -> void:
	match id:
		"close_settings": settings_open = false
		"music_toggle_row": progress.set_preference("music",not progress.data.music)
		"sound_toggle_row": progress.set_preference("sound",not progress.data.sound)
		"language_field": language_expanded = true
		"how_to_play": tutorial_requested.emit()
		_:
			if id.contains("zh") or id.contains("chinese"):
				progress.set_preference("locale","zh"); language_expanded = false
			elif id.contains("en") or id.contains("english"):
				progress.set_preference("locale","en"); language_expanded = false
	preferences_changed.emit(progress.data.duplicate(true))
	_refresh()

func show_notice(kind: String) -> void:
	_new_modal()
	_compose(modal,compositions[kind+"_"+locale()])
	_hit(modal,"notice_close",[731,579,93,94],_refresh)
	_hit(modal,"notice_action",[165,930,610,128],_refresh)

func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if not notice_message.is_empty(): notice_message = ""; notice_title = ""; _refresh()
		elif language_expanded: language_expanded = false; _refresh()
		elif settings_open: settings_open = false; _refresh()
		elif is_instance_valid(modal):
			energy_open = false
			if energy_only: energy_closed.emit()
			else: _refresh()
		elif page == "ranking": _return_from_ranking()
		elif page != "home": show_page("home")
		get_viewport().set_input_as_handled()

func update_energy(snapshot: Dictionary) -> void:
	energy_state = {"current": snapshot.get("energy") if snapshot.get("energy") != null else "--", "capacity":snapshot.get("cap",30), "cost":5,"next_recovery_seconds":snapshot.get("next_recovery_seconds") if snapshot.get("next_recovery_seconds") != null else 0, "ok":snapshot.get("ok",true)}
	if is_instance_valid(board):
		for button in buttons.values():
			if is_instance_valid(button) and button.button_pressed: return
		_refresh()

func _resolved_text(value: String) -> String:
	var seconds := int(energy_state.get("next_recovery_seconds",0))
	return value.replace("{current}",str(energy_state.get("current","--"))).replace("{cap}",str(energy_state.get("capacity","--"))).replace("{cost}",str(energy_state.get("cost","--"))).replace("{minutes}","2").replace("{amount}","1").replace("{level}",str(continue_index()+1)).replace("{mm}","%02d" % (seconds/60)).replace("{ss}","%02d" % (seconds%60))

func _draw_energy() -> void:
	_new_modal()
	var value: Variant = energy_state.get("current")
	var full: bool = (value is int or value is float) and value == energy_state.get("capacity",30)
	var spec: Dictionary = compositions[("energy_full_" if full else "energy_ad_unavailable_")+locale()].duplicate(true)
	for field in spec.labels:
		if field.id == "title" and not full:
			var current: Variant = energy_state.get("current")
			if not (current is int or current is float): field.text = "体力不可用" if locale()=="zh" else "Energy Unavailable"
			elif current >= 5: field.text = "体力补给" if locale()=="zh" else "Restore Energy"
		if field.id == "capacity": field.text = "%s / %s" % [energy_state.get("current","--"),energy_state.get("capacity","--")]
		if field.id == "recovery_time":
			var seconds := int(energy_state.get("next_recovery_seconds",0))
			field.text = "%02d:%02d" % [seconds/60,seconds%60]
	_compose(modal,spec)
	var close := func():
		energy_open = false
		if energy_only: energy_closed.emit()
		else: _refresh()
	_hit(modal,"energy_close",[731,579,93,94] if full else [731,429,93,94],close)
	_hit(modal,"energy_later",[165,930,610,128] if full else [158,1163,625,93],close)

func show_error(message: String, title: String = "") -> void:
	notice_message = message
	notice_title = title if not title.is_empty() else ("暂时无法保存" if locale() == "zh" else "Save unavailable")
	_refresh()

func _draw_notice() -> void:
	_new_modal()
	var spec: Dictionary = compositions["ad_unavailable_"+locale()].duplicate(true)
	for field in spec.labels:
		if field.id == "title": field.text = notice_title
		if field.id == "body": field.text = notice_message
	_compose(modal,spec)
	var dismiss := func(): notice_message = ""; notice_title = ""; _refresh()
	_hit(modal,"error_close",[731,579,93,94],dismiss)
	_hit(modal,"error_action",[165,930,610,128],dismiss)

func continue_index() -> int:
	return resume_index if resume_index >= 0 and resume_index < progress.level_count else progress.current_index()

func energy_rect_canvas() -> Rect2:
	return energy_header.get_global_transform_with_canvas()*Rect2(24,30.81,262,82.38) if is_instance_valid(energy_header) else Rect2()

func show_ranking(origin: String = "home") -> void:
	ranking_origin = origin if origin in ["home", "game", "levels"] else "home"
	ranking_level_index = continue_index()
	ranking_tab = "level"
	show_page("ranking")

func _select_ranking_tab(tab: String) -> void:
	if tab not in ["level", "total"]: return
	ranking_tab = tab
	_refresh()

func _return_from_ranking() -> void:
	if ranking_origin == "game":
		ranking_return_to_game.emit()
	else:
		show_page(ranking_origin)

func _ranking_spec() -> Dictionary:
	var spec: Dictionary = compositions["ranking_total_not_connected_" + locale()].duplicate(true)
	var layers: Array = []
	for layer in spec.layers:
		if str(layer.get("id", "")).begins_with("tabs_"):
			if layer.id != "tabs_" + ranking_tab + "_selected_empty": continue
		layers.append(layer)
	spec.layers = layers
	var zh := locale() == "zh"
	for field in spec.labels:
		match field.id:
			"tab_level": field.color = "#FFFFFF" if ranking_tab == "level" else "#123A59"
			"tab_total": field.color = "#FFFFFF" if ranking_tab == "total" else "#123A59"
			"header_metric": field.text = ("步数" if ranking_tab == "level" else "通关数") if zh else ("Steps" if ranking_tab == "level" else "Levels\nCleared")
			"header_time": field.text = ("用时" if ranking_tab == "level" else "总耗时") if zh else ("Time" if ranking_tab == "level" else "Total\nTime")
			"level_name": field.text = (("第 %s 关" if zh else "Level %s") % (ranking_level_index + 1)) if ranking_tab == "level" else ("全部关卡" if zh else "All Levels")
			"status_title": field.text = "全球排行暂未接入" if zh else "Global ranking is not connected"
			"status_body": field.text = "本关全球记录暂不可用" if zh and ranking_tab == "level" else ("全球累计记录暂不可用" if zh else "Online records are unavailable")
			"personal_title": field.text = ("本机本关" if ranking_tab == "level" else "本机累计") if zh else ("On this device" if ranking_tab == "level" else "Local total")
			"personal_metric":
				field.text = (("已通关" if progress.completed(ranking_level_index) else "未通关") if zh else ("Cleared" if progress.completed(ranking_level_index) else "Not cleared")) if ranking_tab == "level" else str(progress.data.get("completed", []).size())
				field.font_px = 28 if zh else 22
				field.rect_px = [430,1227,194,60]
			"service_hint": field.text = "仅显示本机进度，不代表全球名次" if zh else "Local progress only, not a global rank"
			"return": field.text = ("返回游戏" if ranking_origin == "game" else ("返回选关" if ranking_origin == "levels" else "返回主页")) if zh else ("Back to Game" if ranking_origin == "game" else ("Back to Levels" if ranking_origin == "levels" else "Back to Home"))
	return spec

func set_review_obscured(value: bool) -> void:
	review_obscures_modal = value
	_refresh()
