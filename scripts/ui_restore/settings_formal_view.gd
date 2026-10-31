extends Control
const Art=preload("res://scripts/ui_restore/approved_ui_art.gd")
const REFERENCE:=Vector2(915,1719)
var preferences:Dictionary={}
var action:Callable
var buttons:Dictionary={}
var canvas:Control
func _ready()->void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	canvas=Control.new();canvas.size=REFERENCE;canvas.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(canvas)
	var zh:bool=preferences.get("locale","zh")=="zh"
	Art.picture(canvas,"settings","settings_frame_blank")
	Art.picture(canvas,"settings","title_shadow");Art.picture(canvas,"settings","close_shadow")
	Art.picture(canvas,"settings","title_original_zh" if zh else "title_blank")
	if not zh:Art.label(canvas,"SettingsTitle","Settings",Rect2(235,216,445,125),92,Color.WHITE,5)
	for key in ["sound","music","vibration"]:
		Art.picture(canvas,"settings",key+"_row_blank");Art.picture(canvas,"settings",key+"_icon")
		if zh:Art.picture(canvas,"settings",key+"_label_zh")
		else:
			var rect:=Art.box("settings",key+"_label_zh");rect.position.x=294;rect.size.x=245
			Art.label(canvas,key+"_label",{"sound":"Sound","music":"Music","vibration":"Vibration"}[key],rect,52)
		var enabled:bool=preferences.get(key,true)
		var button:=Art.button(canvas,"settings",key+"_toggle_on",action.bind(key+"_toggle"),Art.box("settings",key+"_row_blank"),"toggle_pressed_on" if enabled else "toggle_pressed_off","toggle_disabled_on" if enabled else "toggle_disabled_off")
		button.art_box=Rect2(Art.box("settings",key+"_toggle_on").position-button.position,Vector2(255,145))
		button.normal_texture=Art.texture("settings",key+"_toggle_on" if enabled else "toggle_off")
		button.disabled=key=="vibration" and OS.get_name() not in ["Android","iOS"]
		button.refresh_material();buttons[key+"_toggle"]=button
	Art.picture(canvas,"settings","language_row_blank");Art.picture(canvas,"settings","language_icon")
	if zh:Art.picture(canvas,"settings","language_label_zh")
	else:Art.label(canvas,"LanguageLabel","Language",Rect2(294,1087,245,84),52)
	Art.picture(canvas,"settings","language_shadow",Rect2() if zh else Rect2(531,1061,283,148))
	buttons.language=Art.button(canvas,"settings","language_button_blank_normal",action.bind("language"),Rect2() if zh else Rect2(545,1074,255,117),"language_button_blank_pressed","language_button_blank_disabled")
	Art.picture(canvas,"settings","language_arrow",Rect2() if zh else Rect2(739,1104,40,55)).z_index=75
	var value:=Art.label(canvas,"LiveLanguageValue","简体中文" if zh else "English",Rect2(520,1095,199,65) if zh else Rect2(580,1105,155,51),48 if zh else 40,Color.WHITE,3)
	value.set_meta("dynamic_value",true)
	if zh:Art.picture(canvas,"settings","guide_row_original")
	else:
		Art.picture(canvas,"settings","guide_row_blank");Art.picture(canvas,"settings","guide_question_icon");Art.picture(canvas,"settings","guide_arrow")
		Art.label(canvas,"GuideLabel","How to play",Rect2(305,1295,370,84),56)
	buttons.how_to_play=preload("res://scripts/water_sort/p2_art.gd").hit(canvas,"how_to_play",Art.box("settings","guide_row_blank"),action.bind("how_to_play"));buttons.how_to_play.z_index=80
	buttons.close=Art.button(canvas,"settings","close_normal",action.bind("close"),Rect2(),"close_pressed","close_disabled")
	resized.connect(_fit);_fit()
func _fit()->void:
	if not is_instance_valid(canvas):return
	var k:=minf(size.x/REFERENCE.x,size.y/REFERENCE.y);canvas.scale=Vector2.ONE*k;canvas.position=(size-REFERENCE*k)*.5
