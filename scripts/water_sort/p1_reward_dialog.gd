extends Control
## Artwork-only confirmation. The owner retains all reward authority.
signal confirmed
signal cancelled
var placement := "shuffle"
var locale := "zh"
var canvas: Control
var hit_buttons: Array[Button] = []
var dispatched := false
const ROOT := "res://assets/p1_ui/"
const ROOT_P0 := "res://assets/p0_ui/"

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	var shade := ColorRect.new()
	shade.color = Color(0.027, 0.114, 0.22, 0.58)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	canvas = Control.new()
	canvas.size = Vector2(320, 603)
	canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(canvas)
	var root_path := ROOT_P0 if placement == "bottle" else ROOT
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(root_path + "layouts.json"))
	var page_name := "refresh_colors" if placement == "shuffle" else "undo"
	var page: Dictionary = {}
	if placement == "bottle":
		page = data["320"].add_bottle
	else:
		for item in data.pages:
			if item.page == page_name and item.viewport[0] == 320:
				page = item
				break
	for layer in page.layers:
		var rect: Array = layer.get("runtimeRectDp", layer.get("textureRectDp", layer.get("rectDp", [])))
		if placement=="shuffle" and layer.get("key","")=="hero_refresh_card":
			canvas.add_child(preload("res://scripts/ui_restore/refresh_palette_art.gd").make_hero(Rect2(rect[0],rect[1],rect[2],rect[3])))
			continue
		var rel: String=str(layer.source).trim_prefix("runtime/").replace(".png",".webp")
		if locale=="en" and rel.contains("description_zh-CN"):
			var description:=Label.new()
			description.text={"shuffle":"Shuffle remaining colors once", "undo":"Undo one move", "bottle":"Add one empty bottle"}[placement]
			description.position=Vector2(rect[0],rect[1]); description.size=Vector2(rect[2],rect[3]); description.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; description.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
			description.add_theme_font_override("font",preload("res://scripts/ui_restore/font_policy.gd").get_font("lxgw")); description.add_theme_font_size_override("font_size",13); description.add_theme_color_override("font_color",Color("0759b9")); description.mouse_filter=Control.MOUSE_FILTER_IGNORE; canvas.add_child(description); continue
		if locale=="en" and rel.contains("title_") and rel.ends_with("_zh-CN.webp"):
			rel="english_art_labels/labels/"+({"shuffle":"refresh_colors_en", "undo":"undo_en", "bottle":"add_bottle_en"}[placement])+".webp"
		elif locale=="en" and rel.contains("label_watch_video_zh-CN"):
			rel="english_art_labels/labels/watch_video_en.webp"
		var texture_path := "res://assets/colorpause_ui_20261030/" + rel
		var texture := load(texture_path) as Texture2D
		var control: Control
		if layer.get("method", "") == "9slice":
			var nine := NinePatchRect.new()
			var factor: float = layer.cornerUniformScale
			nine.texture = texture
			nine.position = Vector2(rect[0], rect[1])
			nine.size = Vector2(rect[2], rect[3]) / factor
			nine.scale = Vector2.ONE * factor
			var margins: Array = layer.sourceNineSliceLTRB
			for i in 4: nine.set_patch_margin(i, int(margins[i]))
			control = nine
		else:
			var image := TextureRect.new()
			image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			image.texture = texture
			image.position = Vector2(rect[0], rect[1])
			image.size = Vector2(rect[2], rect[3])
			control = image
		control.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		control.mouse_filter = Control.MOUSE_FILTER_IGNORE
		canvas.add_child(control)
	for hit in page.hitTargets:
		var r: Array = hit.visibleRectDp
		var button := Button.new()
		button.name = "Close" if hit.action == "close" else "WatchVideo"
		button.accessibility_name = "关闭" if hit.action == "close" else ("观看视频，撤回一步" if placement == "undo" else ("观看视频，刷新颜色" if placement == "shuffle" else "观看视频，增加空瓶"))
		if locale=="en": button.accessibility_name = "Close" if hit.action == "close" else "Watch video"
		button.tooltip_text = button.accessibility_name
		button.position = Vector2(r[0], r[1]); button.size = Vector2(r[2], r[3])
		if hit.action=="close":
			var center:=button.position+button.size*0.5;button.size=Vector2(50,50);button.position=center-button.size*0.5
		button.flat = true
		for style in ["normal", "hover", "pressed", "focus", "disabled"]:
			button.add_theme_stylebox_override(style, StyleBoxEmpty.new())
		button.focus_mode = Control.FOCUS_ALL
		button.pressed.connect(_dispatch.bind(str(hit.action)))
		canvas.add_child(button); hit_buttons.append(button)
		preload("res://scripts/ui_restore/touch_hit.gd").attach(button)
		preload("res://scripts/water_sort/p2_art.gd").bind_press_feedback(canvas,button)
	resized.connect(_fit)
	_fit()

func _fit() -> void:
	if preload("res://scripts/ui_restore/screen_layout.gd").fit_modal(self,canvas,Vector2(320,603),null):return
	var factor := minf(size.x / 320.0, size.y / 603.0)
	canvas.scale = Vector2.ONE * factor
	canvas.position = (size - canvas.size * factor) * 0.5

func _dispatch(action: String) -> void:
	if dispatched: return
	dispatched = true
	for button in hit_buttons: button.disabled = true
	if action == "close": cancelled.emit()
	else: confirmed.emit()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton or event is InputEventScreenTouch: accept_event()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_dispatch("close")
