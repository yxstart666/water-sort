extends Control
## Presentation only. Source pixels and coordinates come from UI batch 1.
signal resume
signal restart_requested
signal level_select_requested
signal preference_changed(key: String, value: Variant)
signal tutorial_requested
signal ui_clicked
const Typography = preload("res://scripts/ui_restore/typography.gd")
const P2Art = preload("res://scripts/water_sort/p2_art.gd")
const NORMAL := "res://assets/ui_restore/modal_normal_v3/"
const OFF := "res://assets/ui_restore/pause_off_v1/"
const NIGHT := "res://assets/art_review/night_state_supplement_v1/unpacked/STATIC_NIGHT_STATE_SUPPLEMENT_v1/assets/"
const GUIDE := "res://assets/art_review/settings_guide_entry_v1/unpacked/STATIC_SETTINGS_GUIDE_ENTRY_PATCH_CANDIDATE_v1/"
const REFERENCE := Vector2(941,1672)
const VIBRATION_ROW_HEIGHT := 118.0
static var textures: Dictionary = {}
var preferences := {"locale":"zh", "music":true, "sound":true, "vibration":true}
var home_settings := false
var buttons: Dictionary = {}
var art: Dictionary = {}
var captions: Dictionary = {}
var canvas: Control
var shade: ColorRect
var closing := false
var keyboard_navigation := false
var normal: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(NORMAL+"scene_placement.json"))
var off: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(OFF+"scene_placement_and_labels.json"))
var guide: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(GUIDE+"scenes_and_labels.json"))
var contract: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://docs/ui_batch1_pause/contracts/PAUSE_RUNTIME_CONTRACT.json"))
var home_guide: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://scripts/shell/settings_guide_compositions.json"))

func _ready() -> void:
	name="HomeSettingsDialog" if home_settings else "OrderPauseDialog"
	mouse_filter=Control.MOUSE_FILTER_STOP
	shade=ColorRect.new(); shade.color=Color("071d38",0.58)
	shade.mouse_filter=Control.MOUSE_FILTER_IGNORE; add_child(shade)
	resized.connect(_fit)
	_rebuild(); _fit()
	modulate.a=0.0
	create_tween().tween_property(self,"modulate:a",1.0,0.12)

func _input(event: InputEvent) -> void:
	if event is InputEventKey: keyboard_navigation=true
	elif event is InputEventMouseButton or event is InputEventScreenTouch: keyboard_navigation=false

func configure(values: Dictionary) -> void:
	for key in preferences: preferences[key]=values.get(key,preferences[key])
	if is_node_ready(): _rebuild()

func _fit() -> void:
	if not is_instance_valid(canvas): return
	shade.size=size
	var reference := Vector2(320,569) if home_settings else Vector2(320,676)
	if preload("res://scripts/ui_restore/screen_layout.gd").fit_modal(self,canvas,reference,shade):
		_compact_pause(reference);return
	canvas.scale=Vector2.ONE*minf(size.x/reference.x,size.y/reference.y)
	canvas.position=(size-reference*canvas.scale)*0.5
	_compact_pause(reference)

func _compact_pause(reference:Vector2)->void:
	if home_settings:return
	# One transform keeps panel, rows, footer buttons and text as a single group.
	# TouchHit independently preserves a physical 44px region after scaling.
	var previous:=canvas.scale
	canvas.scale*=.88
	canvas.position+=reference*(previous-canvas.scale)*.5

func _scene() -> Dictionary:
	if home_settings:
		return home_guide["home_settings_guide_%s_music_%s_sound_%s_closed" % [preferences.locale,"on" if preferences.music else "off","on" if preferences.sound else "off"]]
	return guide["pause_settings_guide_%s_music_on_sound_on_closed" % preferences.locale]

func _rebuild() -> void:
	if is_instance_valid(canvas): remove_child(canvas); canvas.queue_free()
	buttons.clear(); art.clear(); captions.clear()
	if home_settings:
		canvas=preload("res://scripts/ui_restore/settings_formal_view.gd").new()
		canvas.preferences=preferences.duplicate(true)
		canvas.action=func(id: String): _action(id); ui_clicked.emit()
		canvas.size=Vector2(320,569); add_child(canvas)
		buttons=canvas.buttons
		_fit(); return
	_build_p2_pause(); _fit(); return
	canvas=Control.new(); canvas.size=REFERENCE; canvas.mouse_filter=Control.MOUSE_FILTER_IGNORE; add_child(canvas)
	if home_settings:
		_build_home_settings(); _insert_vibration_row(); _fit(); return
	var locale: String=preferences.locale
	for source in normal.locale_layouts[locale].layers:
		var layer: Dictionary=source.duplicate(true)
		var id: String=layer.id
		var category := "sound" if id.contains("speaker") or id.contains("reused_for_sound") else "music"
		if (id in ["modal_icon_music","modal_icon_speaker"] or id.begins_with("modal_switch_on_")) and not preferences[category]:
			for replacement in off.locales[locale].layers:
				if replacement.id==id.replace("switch_on","switch_off"):
					layer=replacement.duplicate(true); layer.file=OFF+layer.file
		elif id.begins_with("modal_language_dropdown_"):
			layer.file=NIGHT+"pause_language_field_empty_"+locale+".png"
		if not str(layer.file).begins_with("res://"): layer.file=NORMAL+str(layer.file).get_file()
		art[id]=_sprite(canvas,layer)
	_add_reference_dividers()
	for label in off.locales[locale].labels:
		if not preferences["sound" if label.id=="sound_state" else "music"]: _label(canvas,label)
	for label in _scene().labels:
		if label.id=="selected_locale": _label(canvas,label)
	for id in ["close","music_toggle","sound_toggle","language","resume","restart","level_select"]:
		var key: String="language_"+locale if id=="language" else id
		var box: Array=contract.source_rects_941[key].duplicate()
		# The primary close/music rectangles overlap by 13 source pixels. Use
		# the supplied guide's row Y positions (373/491/609), retaining primary
		# X/width and all source pixels. Each 116px row still exceeds 44dp at 360.
		if id in ["close","music_toggle","sound_toggle"]:
			for target in _scene().active_hit_targets:
				if target.id==id: box[1]=target.rect[1]
		_hit(canvas,id,box,func(): _action(id))
	_insert_vibration_row()
	_fit()

func _build_p2_pause() -> void:
	canvas=Control.new(); canvas.size=Vector2(320,676); canvas.mouse_filter=Control.MOUSE_FILTER_IGNORE; add_child(canvas)
	var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/colorpause_ui_20261030_pause_layout.json"))
	var spec: Dictionary=data.pages[0]
	var toggle_index:=0
	var english: Dictionary={"pause":"paused_en", "sound":"sound_en_blue", "music":"music_en_blue", "haptics":"vibration_en_blue", "continue":"continue_en", "home":"home_en", "replay":"restart_en"}
	for source_layer in spec.layers:
		var layer: Dictionary=source_layer.duplicate(true)
		var path: String=str(layer.source).trim_prefix("runtime/")
		if preferences.locale=="zh" and not home_settings and float(layer.rectDp[1])>=547 and float(layer.rectDp[1])<650:continue
		if home_settings and layer.rectDp[1]>=547: continue
		if home_settings and path.contains("labels/pause_zh-CN"):
			path="secondary_popups/sprites/settings_title_zh-CN.webp" if preferences.locale=="zh" else "english_art_labels/labels/settings_en.webp"
		elif home_settings and path.contains("labels/continue_zh-CN"):
			path="secondary_popups/sprites/how_to_play_zh-CN.webp" if preferences.locale=="zh" else "english_art_labels/labels/how_to_play_en.webp"
		if path.contains("toggle_on_composite"):
			var key: String=["sound","music","vibration"][toggle_index]; toggle_index+=1
			if not preferences[key]: path="sprites/toggle_off_assembled_clean.webp"
		if preferences.locale=="en":
			# Four horizontal rows: shared icon/label/action columns, unchanged row hits.
			# Keep the supplied artwork and readable ink height instead of stacking controls.
			if path.contains("toggle_"):
				layer.rectDp=[210,166.2+75.248*(toggle_index-1)-18.5,66,37]
			if path.contains("icon_speaker") or path.contains("icon_music") or path.contains("icon_vibration") or path.contains("icon_language"):
				var center_y:float=float(layer.rectDp[1])+float(layer.rectDp[3])*.5
				layer.rectDp=[43,center_y-20,39,40]
			var label_key: String=str(layer.get("labelKey",""))
			if home_settings and label_key in ["pause","continue"]:
				if label_key=="pause": layer.rectDp=[96,layer.rectDp[1],128,layer.rectDp[3]]
			elif english.has(label_key):
				path="english_art_labels/labels/"+english[label_key]+".webp"
				if label_key in ["sound","music","haptics"]:
					var row:int=["sound","music","haptics"].find(label_key)
					layer.rectDp=[86,166.2+75.248*row-11,118,22]
				elif label_key=="pause": layer.rectDp=[96,layer.rectDp[1],128,layer.rectDp[3]]
				elif label_key in ["home","replay"]: layer.rectDp=[layer.rectDp[0]-8,layer.rectDp[1],layer.rectDp[2]+16,layer.rectDp[3]]
			elif path.ends_with("label_language_zh-CN.webp"):
				# The label and selection share the same vertical center as the other rows.
				path="english_art_labels/labels/language_en_blue.webp"; layer.rectDp=[86,379.944,118,24]
			elif path.ends_with("label_current_zh-CN.webp"):
				path="english_art_labels/labels/english_en.webp"; layer.rectDp=[215,382.944,48,18]
			elif layer.get("id","")=="language_navigation_capsule":
				layer.rectDp=[210,373.444,66,37]
			elif path.ends_with("language_entry/chevron_right.webp"):
				layer.rectDp=[265,384.444,8,15]
		var visual=P2Art.add_layer(canvas,layer,"res://assets/colorpause_ui_20261030/"+path)
		if path.contains("icon_vibration"): art.vibration_icon=visual
		if path.contains("labels/music_"): art.music_title=visual
		if path.contains("labels/sound_"): art.sound_title=visual
		if path.contains("labels/haptics_") or path.contains("labels/vibration_"): art.vibration_title=visual
	if preferences.locale=="zh" and not home_settings:
		var original:=preload("res://scripts/ui_restore/original_button_art.gd")
		art.home_complete=original.picture(canvas,"OriginalHomeNormal","full_buttons/button_home_reference.png",Rect2(48.76,547.47,107.17,100.18))
		art.replay_complete=original.picture(canvas,"OriginalReplayNormal","full_buttons/button_replay_reference.png",Rect2(161.26,547.47,106.29,97.2))
	var targets: Array=[["close",Rect2(260,67,53,53)],["sound_toggle",Rect2(38.08,131.2,243.84,70)],["music_toggle",Rect2(38.08,206.448,243.84,70)],["vibration_toggle",Rect2(38.08,281.696,243.84,70)],["language",Rect2(38.08,356.944,243.84,70)]]
	if home_settings: targets.append(["how_to_play",Rect2(46.3,466.73,227.69,81.3)])
	else: targets.append_array([["resume",Rect2(46.3,466.73,227.69,80.0)],["level_select",Rect2(48.76,547.47,107.17,100.18)],["restart",Rect2(161.26,547.47,106.29,97.2)]])
	for item in targets:
		var id: String=item[0]
		buttons[id]=P2Art.hit(canvas,id,item[1],func(): _action(id); ui_clicked.emit())
	buttons.vibration_toggle.tooltip_text=("触感振动是否生效取决于设备和系统设置" if preferences.locale=="zh" else "Tap feedback depends on device and system settings") if OS.get_name()=="Android" else ("当前平台不支持振动，设置偏好仍会保存" if preferences.locale=="zh" else "Vibration is unavailable on this platform; your preference is saved")

func _insert_vibration_row() -> void:
	# Insert one row while retaining the original art, order and native scale.
	# Only a narrow blank middle band of the existing panel is extended.
	var original=art.compact_settings_empty_panel if home_settings else art.modal_empty_base_728x985_fixed_art
	var panel: NinePatchRect
	var offset:=175.0 if home_settings else 0.0
	if home_settings:
		panel=original; panel.size.y+=VIBRATION_ROW_HEIGHT
	else:
		original.hide()
		panel=NinePatchRect.new()
		panel.texture=original.texture; panel.position=Vector2(107,381)
		panel.size=Vector2(728,985+VIBRATION_ROW_HEIGHT)
		panel.patch_margin_top=340; panel.patch_margin_bottom=643
		panel.patch_margin_left=64; panel.patch_margin_right=64
		panel.z_index=original.z_index; panel.mouse_filter=Control.MOUSE_FILTER_IGNORE
		canvas.add_child(panel)
	for child in canvas.get_children():
		if child==panel or child==original: continue
		if child is Line2D:
			child.position.y+=VIBRATION_ROW_HEIGHT
		elif child.position.y>=725+offset:
			child.position.y+=VIBRATION_ROW_HEIGHT
			if child.has_meta("rest_position"): child.set_meta("rest_position",child.position)
	var locale: String=preferences.locale
	var layer: Dictionary={"id":"vibration_switch","file":NORMAL+"modal_switch_on_"+locale+".png","top_left_px":[545,739+offset]}
	if not preferences.vibration:
		for source in off.locales[locale].layers:
			if source.id=="modal_switch_off_"+locale: layer.file=OFF+source.file
	art.vibration_switch=_sprite(canvas,layer)
	# Three actual localized labels share the exact same typeface, weight,
	# size and visible-ink column. Preserve the supplied PNGs as hidden sources.
	for row in 3:
		var key: String=["music","sound","vibration"][row]
		var original_key: String="modal_text_"+key+"_"+locale
		if art.has(original_key): art[original_key].hide()
		var words: Array=["音乐","音效","振动"] if locale=="zh" else ["Music","Sound","Vibration"]
		_label(canvas,{"id":key+"_title","text":words[row],"rect_px":[308,514+118*row+offset,227,60],"font_px":44,"font_family":"Noto Sans Bold" if locale=="en" else "CJK","color":"#101747"})
		var title: Label=captions[key+"_title"]
		var ink: Rect2=title.get_meta("centered_ink_bounds")
		title.position.x+=308-ink.position.x
		title.set_meta("rest_position",title.position)
	var icon:=Node2D.new(); icon.name="VibrationIcon"; icon.position=Vector2(237,780+offset); icon.z_index=30
	canvas.add_child(icon); art.vibration_icon=icon
	icon.draw.connect(func(): _draw_vibration_icon(icon))
	# Existing delivered switch and UI ink; no formal vibration PNG was supplied.
	icon.queue_redraw()
	if not preferences.vibration:
		var spec: Dictionary=off.locales[locale].labels[0].duplicate(true)
		spec.id="vibration_state"; spec.rect_px[1]+=236+offset
		_label(canvas,spec)
	_hit(canvas,"vibration_toggle",[193,727+offset,597,116],func(): _action("vibration_toggle"))
	buttons.vibration_toggle.tooltip_text=("轻触振动；是否生效取决于设备和系统设置" if locale=="zh" else "Tap feedback depends on device and system settings") if OS.get_name()=="Android" else ("当前平台不支持振动，开关偏好仍会保存" if locale=="zh" else "Vibration is unavailable on this platform; your preference is saved")

func _draw_vibration_icon(icon: Node2D) -> void:
	var ink:=Color("101747")
	var frame:=StyleBoxFlat.new(); frame.bg_color=Color.TRANSPARENT
	frame.border_color=ink; frame.set_border_width_all(6); frame.set_corner_radius_all(6)
	icon.draw_style_box(frame,Rect2(-20,-33,40,66))
	icon.draw_line(Vector2(-8,-22),Vector2(8,-22),ink,4,true)
	icon.draw_circle(Vector2(0,23),3,ink,true,-1,true)
	for side in [-1.0,1.0]:
		icon.draw_polyline(PackedVector2Array([Vector2(side*32,-22),Vector2(side*38,-11),Vector2(side*32,0),Vector2(side*38,11),Vector2(side*32,22)]),ink,5,true)

func _build_home_settings() -> void:
	var scene: Dictionary=_scene()
	for source in scene.layers:
		var layer: Dictionary=source.duplicate(true)
		if layer.id=="language_caret_down": continue
		# The delivered guide resolves these aliases to the formal normal set.
		if str(layer.file).contains("/pause_preview_v1/") or str(layer.file).contains("/pause_preview_v2/"):
			layer.file=NORMAL+str(layer.file).get_file()
		if layer.has("9patch_margins_px"):
			# Only this home-guide panel has an explicit nine-slice contract.
			var panel:=NinePatchRect.new(); panel.name=layer.id; panel.texture=load(layer.file)
			panel.position=Vector2(layer.top_left_px[0],layer.top_left_px[1])
			panel.size=Vector2(layer.display_size_px[0],layer.display_size_px[1])
			for edge in 4: panel.set_patch_margin(edge,int(layer["9patch_margins_px"][edge]))
			panel.z_index=int(layer.z); panel.mouse_filter=Control.MOUSE_FILTER_IGNORE
			canvas.add_child(panel); art[layer.id]=panel
		else:
			var sprite:=_sprite(canvas,layer); art[layer.id]=sprite
	for label in scene.labels: _label(canvas,label)
	for target in scene.active_hit_targets:
		var id: String="language" if target.id=="language_dropdown" else str(target.id)
		_hit(canvas,id,target.rect,func(): _action(id))

func _add_reference_dividers() -> void:
	# The approved zh/en references contain these three rules, omitted from the
	# sliced base. Restore their measured 941x1672 positions with the same scale.
	for spec in [
		["LanguageDivider",Vector2(171,855.5),Vector2(770,855.5),4.0,Color("c2ad9c")],
		["FooterLeftRule",Vector2(273.5,1323),Vector2(343,1323),3.5,Color("b19885")],
		["FooterRightRule",Vector2(597.5,1323),Vector2(667,1323),3.5,Color("b19885")],
	]:
		var line := Line2D.new(); line.name=spec[0]
		line.points=PackedVector2Array([spec[1],spec[2]])
		line.width=spec[3]; line.default_color=spec[4]
		line.begin_cap_mode=Line2D.LINE_CAP_ROUND; line.end_cap_mode=Line2D.LINE_CAP_ROUND
		line.antialiased=true; line.z_index=25; canvas.add_child(line)

func _sprite(parent: Control, layer: Dictionary) -> Sprite2D:
	var path: String=layer.file
	if path.begins_with("reuse://"): path=NIGHT+path.get_file()
	if not textures.has(path):
		var image := Image.new()
		if image.load_png_from_buffer(FileAccess.get_file_as_bytes(path))!=OK:
			push_error("Pause asset unavailable: "+path); return null
		textures[path]=ImageTexture.create_from_image(image)
	var sprite := Sprite2D.new()
	sprite.name=layer.get("id",path.get_file().get_basename())
	sprite.texture=textures[path]
	sprite.position=Vector2(layer.top_left_px[0],layer.top_left_px[1])+sprite.texture.get_size()*0.5
	sprite.rotation_degrees=float(layer.get("rotation_degrees",0))
	sprite.z_index=int(layer.get("z",30)); parent.add_child(sprite)
	sprite.set_meta("source_path",path)
	return sprite

func _label(parent: Control, spec: Dictionary) -> void:
	var label := Label.new(); label.name=spec.id; label.text=spec.text
	if preferences.locale=="en":
		if spec.id=="selected_locale": label.text="English"
	label.mouse_filter=Control.MOUSE_FILTER_IGNORE; label.z_index=80
	var latin: bool=str(spec.get("font_asset",spec.get("font_family",""))).ends_with(".ttf") or str(spec.get("font_family","")).contains("Noto Sans Bold")
	label.add_theme_font_override("font",Typography.font("latin" if latin else "cjk_face0"))
	label.add_theme_font_size_override("font_size",int(spec.font_px))
	label.add_theme_color_override("font_color",Color(spec.color))
	label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; label.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	parent.add_child(label)
	var box: Array=spec.rect_px
	if spec.id=="selected_locale":
		var field: Sprite2D=art["modal_language_dropdown_"+str(preferences.locale)]
		var area:=field.get_rect()
		area.position+=field.position
		box=[area.position.x+12,area.position.y,area.size.x-24,area.size.y]
	Typography.center_label(label,Rect2(box[0],box[1],box[2],box[3]),int(spec.font_px))
	label.set_meta("rest_position",label.position); captions[spec.id]=label

func _hit(parent: Control, id: String, box: Array, action: Callable) -> void:
	var button := Button.new(); button.name=id
	button.position=Vector2(box[0],box[1]); button.size=Vector2(box[2],maxf(box[3],116))
	button.flat=true; button.z_index=100; button.focus_mode=Control.FOCUS_ALL
	button.mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
	for state in ["normal","hover","pressed","disabled","focus"]: button.add_theme_stylebox_override(state,StyleBoxEmpty.new())
	var focus := StyleBoxFlat.new(); focus.bg_color=Color.TRANSPARENT; focus.border_color=Color("123a59")
	focus.set_border_width_all(3); focus.set_corner_radius_all(18); focus.set_expand_margin_all(4)
	button.gui_input.connect(func(event):
		if event is InputEventMouseButton: button.add_theme_stylebox_override("focus",StyleBoxEmpty.new()))
	button.focus_entered.connect(func():
		if keyboard_navigation: button.add_theme_stylebox_override("focus",focus))
	button.button_down.connect(func(): _pressed(id,true))
	button.button_up.connect(func(): _pressed(id,false))
	button.mouse_exited.connect(func(): _pressed(id,false))
	button.pressed.connect(func(): action.call(); ui_clicked.emit())
	parent.add_child(button); buttons[id]=button

func _pressed(id: String, pressed: bool) -> void:
	var key: String={"resume":"modal_resume_", "restart":"modal_restart_", "level_select":"modal_home_", "language":"modal_language_dropdown_"}.get(id,"")+str(preferences.locale)
	if home_settings and id=="how_to_play": key="how_to_play_button"
	if id=="close": key="modal_close"
	if id=="vibration_toggle": key="vibration_switch"
	if id in ["music_toggle","sound_toggle"]: key="modal_switch_on_"+str(preferences.locale)+("_reused_for_sound" if id=="sound_toggle" else "")
	if home_settings and id in ["music_toggle","sound_toggle"]:
		var category:=id.trim_suffix("_toggle")
		key=category+("_on" if preferences[category] else "_off")
	if art.has(key): art[key].modulate=Color(0.92,0.92,0.92) if pressed else Color.WHITE
	var caption: String={"music_toggle":"music_state","sound_toggle":"sound_state","language":"selected_locale"}.get(id,"")
	if id=="vibration_toggle": caption="vibration_state"
	if captions.has(caption) and is_instance_valid(captions[caption]):
		captions[caption].position=captions[caption].get_meta("rest_position")+(Vector2(0,2) if pressed else Vector2.ZERO)
		captions[caption].modulate=Color(0.92,0.92,0.92) if pressed else Color.WHITE

func _action(id: String) -> void:
	if closing: return
	match id:
		"close", "resume": _finish(resume)
		"restart": _finish(restart_requested)
		"level_select": _finish(level_select_requested)
		"music_toggle", "sound_toggle", "vibration_toggle":
			var key := id.trim_suffix("_toggle")
			preference_changed.emit(key,not preferences[key])
		"language": preference_changed.emit("locale","en" if preferences.locale=="zh" else "zh")
		"how_to_play": tutorial_requested.emit()

func _finish(action: Signal) -> void:
	closing=true
	for button in buttons.values(): button.disabled=true
	var tween := create_tween()
	tween.tween_property(self,"modulate:a",0.0,0.12)
	tween.tween_callback(func(): action.emit())

func cancel() -> void:
	if not closing: _finish(resume)
