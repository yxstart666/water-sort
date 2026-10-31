extends RefCounted
## Small presentation primitives for the fixed reference2 delivery. No routes or state.
const Assets=preload("res://scripts/water_sort/order_gameplay_assets.gd")
const PauseFace=preload("res://scripts/water_sort/pause_button_face.gd")
const ConsolidatedFrame=preload("res://scripts/water_sort/consolidated_frame.gd")
const Typography=preload("res://scripts/ui_restore/typography.gd")
const ROOT=Assets.ROOT
const BLUE=ROOT+"reference2_replay_settings_buttons_v1/assets/replay_button_blank.png"
const PILL=ROOT+"reference2_top_hud_v1/assets/step_pill_blank.png"
const INK=Color("fff5de")
const PANEL="res://assets/ui_restore/modal_normal_v3/modal_empty_base_728x985_fixed_art.png"
const PRIMARY="res://assets/ui_restore/modal_normal_v3/modal_resume_zh.png"
const SECONDARY="res://assets/ui_restore/modal_normal_v3/modal_restart_zh.png"
const PANEL_INK=Color("101747")
static var textures: Dictionary={}
static func texture(path: String) -> Texture2D:
	var resolved:=path if path.begins_with("res://") else ROOT+path.trim_prefix("deliverables/water_sort/")
	if not textures.has(resolved): textures[resolved]=load(resolved)
	return textures[resolved]
static func picture(parent: Node, id: String, path: String, box: Rect2) -> TextureRect:
	var node:=TextureRect.new(); node.name=id; node.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	node.texture=texture(path); node.position=box.position; node.size=box.size
	node.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	node.mouse_filter=Control.MOUSE_FILTER_IGNORE; node.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
	parent.add_child(node); return node
static func face(parent:Node,id:String,box:Rect2,secondary:=false)->Control:
	var node:=PauseFace.new();node.name=id;node.secondary=secondary;node.position=box.position;node.size=box.size
	parent.add_child(node);return node
static func close_button(parent:Node,id:String,box:Rect2,action:Callable)->Button:
	var node:=Button.new();node.name=id;node.position=box.position;node.size=box.size;node.focus_mode=Control.FOCUS_NONE
	for state in ["normal","hover","pressed","disabled","focus"]:node.add_theme_stylebox_override(state,StyleBoxEmpty.new())
	parent.add_child(node)
	var art:=picture(node,"PauseClose","res://assets/colorpause_ui_20261030/sprites/close_normal_clean.webp",Rect2((box.size-Vector2(112,112))*0.5,Vector2(112,112)))
	art.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	node.button_down.connect(func():art.modulate=Color(0.92,0.92,0.92))
	node.button_up.connect(func():art.modulate=Color.WHITE)
	node.pressed.connect(action);preload("res://scripts/ui_restore/touch_hit.gd").attach(node);return node
static func panel(parent: Node, id: String, box: Rect2, pill:=false) -> Control:
	if pill:return face(parent,id,box,true)
	var node:=NinePatchRect.new(); node.name=id; node.texture=texture(SECONDARY if pill else PANEL)
	node.position=box.position; node.size=box.size; node.mouse_filter=Control.MOUSE_FILTER_IGNORE
	for edge in 4: node.set_patch_margin(edge,30 if pill else 64)
	parent.add_child(node); return node
static func consolidated_panel(parent: Node, id: String, box: Rect2) -> Control:
	var node:=ConsolidatedFrame.new();node.name=id;node.kind="panel";node.position=box.position;node.size=box.size
	parent.add_child(node);return node
static func label(parent: Node, id: String, value: String, box: Rect2, locale: String, pixels:=34, color:=INK, wrap_text:=false) -> Label:
	# Labels on an explicitly marked light surface inherit its readable ink.
	if parent.get_meta("light_ui_surface",false) and color==INK: color=PANEL_INK
	var node:=Label.new(); node.name=id; node.text=value
	node.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; node.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	node.mouse_filter=Control.MOUSE_FILTER_IGNORE; node.clip_text=true
	node.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART if wrap_text else TextServer.AUTOWRAP_OFF
	var font:Font=Typography.font("latin" if locale=="en" else "cjk_face0")
	node.add_theme_font_override("font",font); node.add_theme_color_override("font_color",color)
	if not wrap_text:
		while pixels>18 and (font.get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,pixels).x>box.size.x-8 or font.get_height(pixels)>box.size.y): pixels-=1
	node.add_theme_font_size_override("font_size",pixels); node.position=box.position; node.size=box.size
	parent.add_child(node); return node
static func button(parent: Node, id: String, caption: String, box: Rect2, locale: String, action: Callable, pill:=false) -> Button:
	var node:=Button.new(); node.name=id; node.text=caption; node.position=box.position; node.size=box.size
	node.mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
	var font: Font=Typography.font("latin" if locale=="en" else "cjk_face0"); node.add_theme_font_override("font",font)
	var pixels:=40
	while pixels>20 and font.get_string_size(caption,HORIZONTAL_ALIGNMENT_LEFT,-1,pixels).x>box.size.x-36: pixels-=1
	node.add_theme_font_size_override("font_size",pixels)
	for state in ["normal","hover","pressed","focus","disabled"]:
		node.add_theme_stylebox_override(state,StyleBoxEmpty.new())
		node.add_theme_color_override("font_color" if state=="normal" else "font_"+state+"_color",Color("687783") if state=="disabled" else PANEL_INK)
	if action.is_valid(): node.pressed.connect(action)
	else: node.disabled=true
	parent.add_child(node)
	var skin:=ConsolidatedFrame.new();skin.name="PauseButtonFace";skin.kind="button";skin.show_behind_parent=true
	node.add_child(skin);skin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var base_tint:=Color(0.72,0.78,0.86) if pill else Color.WHITE;skin.modulate=base_tint
	node.button_down.connect(func(): if is_instance_valid(skin): skin.modulate=base_tint*Color(0.9,0.9,0.9))
	node.button_up.connect(func(): if is_instance_valid(skin): skin.modulate=base_tint)
	node.mouse_exited.connect(func(): if is_instance_valid(skin): skin.modulate=base_tint)
	preload("res://scripts/ui_restore/touch_hit.gd").attach(node)
	return node
static func fit_button_text(node:Button)->void:
	var font:Font=node.get_theme_font("font");var pixels:=40
	while pixels>18 and font.get_string_size(node.text,HORIZONTAL_ALIGNMENT_LEFT,-1,pixels).x>node.size.x-36:pixels-=1
	node.add_theme_font_size_override("font_size",pixels)
static func backdrop(parent: Node) -> void:
	picture(parent,"Reference2Background",Assets.BACKGROUND,Rect2(0,0,940,1672))
