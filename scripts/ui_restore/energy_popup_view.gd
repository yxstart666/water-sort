extends Control
## Uniform registration of the approved1024x1536 composition. No baked balances.
signal close_requested
signal ad_requested
const FontPolicy=preload("res://scripts/ui_restore/font_policy.gd")
const Typography=preload("res://scripts/ui_restore/typography.gd")
const SourceButton=preload("res://scripts/ui_restore/energy_popup_button.gd")
const Digits=preload("res://scripts/ui_restore/energy_popup_digits.gd")
const ROOT:="res://assets/energy_popup_approved_v1/"
const REFERENCE:=Vector2(1024,1536)
const SOURCE_GROUP:=Rect2(64,165,904,1231)
var locale:="zh"
var model:Dictionary={}
var buttons:Dictionary={}
var labels:Dictionary={}
var art:Dictionary={}
var canvas:Control
var shade:ColorRect
var contract:Dictionary
var primary:Button
var close:Button
var capacity:Label
var fill_clip:Control
var recovery_backing:Panel
var _built:=false
static var textures:Dictionary={}
func _ready()->void:
	name="ApprovedEnergyPopup";mouse_filter=Control.MOUSE_FILTER_STOP
	contract=JSON.parse_string(FileAccess.get_file_as_string(ROOT+"contracts/asset_contract.json"))
	shade=ColorRect.new();shade.color=Color("071d38",.58);shade.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(shade)
	canvas=Control.new();canvas.name="ApprovedEnergySourceCanvas";canvas.size=REFERENCE;canvas.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(canvas)
	for id in ["modal_base_blank","capacity_blank","hero_energy_composite","energy_bar_empty","energy_bar_full","title_blank","title_full_original","title_insufficient_candidate","label_recovery_rule_original"]:art[id]=_picture(id)
	fill_clip=Control.new();fill_clip.name="LiveEnergyFillClip";fill_clip.position=Vector2(150,925);fill_clip.size=Vector2(724,89);fill_clip.clip_contents=true;fill_clip.mouse_filter=Control.MOUSE_FILTER_IGNORE;fill_clip.z_index=35;canvas.add_child(fill_clip)
	var fill:=TextureRect.new();fill.name="OriginalEnergyFill";fill.texture=_texture("energy_bar_fill");fill.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;fill.stretch_mode=TextureRect.STRETCH_SCALE;fill.size=Vector2(724,89);fill.mouse_filter=Control.MOUSE_FILTER_IGNORE;fill.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS;fill_clip.add_child(fill)
	primary=SourceButton.new();primary.name="EnergyPrimary";primary.normal_texture=_texture("button_blank_normal");primary.pressed_texture=_texture("button_blank_pressed");primary.disabled_texture=_texture("button_blank_disabled");primary.position=Vector2(165,1116);primary.size=Vector2(693,204);primary.z_index=45;canvas.add_child(primary)
	primary.pressed.connect(func():
		if model.get("ad_action_available",false):ad_requested.emit()
		else:close_requested.emit())
	art.label_return_original=_picture("label_return_original",primary,Vector2(165,1116));art.label_return_original.z_index=1
	close=SourceButton.new();close.name="EnergyClose";close.normal_texture=_texture("close_normal");close.position=Vector2(814,232);close.size=Vector2(154,154);close.z_index=60;canvas.add_child(close);close.pressed.connect(func():close_requested.emit())
	labels.title=_label("EnergyStateTitle","",Rect2(286,201,464,126),80,Color.WHITE,5);labels.title.z_index=51
	# The widest approved live string (24/30) needs314px including its shadow.
	# Keep the source center569 and face66; use the capsule's spare inner margin.
	capacity=Digits.new();capacity.position=Vector2(407,812);capacity.size=Vector2(324,105);capacity.z_index=32;canvas.add_child(capacity);labels.capacity=capacity
	labels.energy_rule=_label("EnergyRule","",Rect2(270,1025,486,72),48,Color("103477"),0);labels.energy_rule.z_index=41
	labels.recovery_time=_label("EnergyRecoveryTime","",Rect2(280,942,464,55),52,Color.WHITE,6);labels.recovery_time.z_index=36
	labels.recovery_time.add_theme_color_override("font_outline_color",Color("103477"))
	recovery_backing=Panel.new();recovery_backing.name="RecoveryTimeContrast";recovery_backing.mouse_filter=Control.MOUSE_FILTER_IGNORE;recovery_backing.z_index=36
	var backing:=StyleBoxFlat.new();backing.bg_color=Color("103477",.88);backing.set_corner_radius_all(18)
	recovery_backing.add_theme_stylebox_override("panel",backing);canvas.add_child(recovery_backing);labels.recovery_time.z_index=37
	labels.action=_label("EnergyPrimaryCaption","",Rect2(245,1153,534,124),74,Color.WHITE,5,primary,Vector2(165,1116));labels.action.z_index=1
	labels.notice=_label("EnergyHostNotice","",Rect2(250,465,530,235),44,Color("103477"),0);labels.notice.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;labels.notice.z_index=31
	_built=true;resized.connect(_fit);present(model);_fit()
func present(value:Dictionary)->void:
	model=value.duplicate(true)
	if not _built:return
	labels.title.text=str(model.get("heading",""));_fit_text(labels.title,Rect2(286,201,464,126),80,48)
	var full:bool=model.get("state","")=="full";var insufficient:bool=model.get("state","")=="insufficient"
	art.title_full_original.visible=locale=="zh" and full;art.title_insufficient_candidate.visible=locale=="zh" and insufficient
	art.title_blank.visible=not (art.title_full_original.visible or art.title_insufficient_candidate.visible);labels.title.visible=art.title_blank.visible
	capacity.text=str(model.get("capacity","-- / 30"));capacity.queue_redraw()
	var ratio:float=clampf(float(model.get("ratio",0)),0,1)
	art.energy_bar_full.visible=full;art.energy_bar_empty.visible=not full;fill_clip.visible=not full and ratio>0;fill_clip.size=Vector2(724*ratio,89)
	labels.energy_rule.text=str(model.get("rule",""));var readable:bool=model.get("readable",false)
	art.label_recovery_rule_original.visible=locale=="zh" and readable;labels.energy_rule.visible=not art.label_recovery_rule_original.visible
	if locale=="en" and readable:labels.energy_rule.text="1 energy every 2 min"
	if not readable:
		# Heading already states that energy is unavailable. Keep the recovery
		# slot readable, with a complete short action instead of clipped prose.
		labels.energy_rule.text="请稍后重试" if locale=="zh" else "Please try again"
		_fit_text(labels.energy_rule,Rect2(270,1025,486,72),48,42)
	else:_fit_text(labels.energy_rule,Rect2(270,1025,486,72),48,32)
	labels.recovery_time.text=str(model.get("recovery_time",""));labels.recovery_time.visible=not labels.recovery_time.text.is_empty()
	var time_width:float=labels.recovery_time.get_theme_font("font").get_string_size(labels.recovery_time.text,HORIZONTAL_ALIGNMENT_LEFT,-1,52).x+40
	recovery_backing.position=Vector2(512-time_width*.5,941);recovery_backing.size=Vector2(time_width,64);recovery_backing.visible=labels.recovery_time.visible
	var available:bool=model.get("ad_action_available",false)
	var caption:String=str(model.get("ad_caption","")) if available else str(model.get("close_caption",""))
	primary.accessibility_name=caption;primary.tooltip_text=caption
	art.label_return_original.visible=locale=="zh" and not available;labels.action.text=caption;labels.action.visible=not art.label_return_original.visible
	_fit_text(labels.action,Rect2(80,37,534,124),74,42)
	close.accessibility_name="关闭体力弹窗" if locale=="zh" else "Close energy popup"
	buttons.clear();buttons.energy_close=close;buttons.energy_later=close if available else primary
	if available:buttons.energy_watch_ad=primary
	labels.notice.text=str(model.get("notice",""));labels.notice.visible=not labels.notice.text.is_empty();art.hero_energy_composite.visible=not labels.notice.visible
	set_meta("dynamic_font_exact",false)
func _fit()->void:
	if not is_instance_valid(canvas):return
	var available:=Rect2(Vector2.ZERO,size)
	if is_inside_tree() and get_viewport().has_meta("screen_layout"):
		preload("res://scripts/ui_restore/screen_layout.gd").fit_modal(self,canvas,REFERENCE,shade)
		var policy=get_viewport().get_meta("screen_layout");available=get_global_transform_with_canvas().affine_inverse()*policy.safe_rect
	else:shade.position=Vector2.ZERO;shade.size=size
	var k:=minf(available.size.x*.84/SOURCE_GROUP.size.x,available.size.y*.78/SOURCE_GROUP.size.y)
	canvas.scale=Vector2.ONE*k;canvas.position=available.get_center()-SOURCE_GROUP.get_center()*k;set_meta("source_uniform_scale",k)
func _spec(id:String)->Dictionary:
	for item in contract.assets:
		if item.id==id:return item
	push_error("Missing approved energy asset: "+id);return {}
func _texture(id:String)->Texture2D:
	var path:String=ROOT+str(_spec(id).file)
	if not textures.has(path):textures[path]=load(path)
	return textures[path]
func _picture(id:String,parent:Control=null,origin:=Vector2.ZERO)->TextureRect:
	var spec:=_spec(id);var r:Array=spec.rect_xywh
	var picture:=TextureRect.new();picture.name=id;picture.texture=_texture(id);picture.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;picture.stretch_mode=TextureRect.STRETCH_SCALE;picture.position=Vector2(r[0],r[1])-origin;picture.size=Vector2(r[2],r[3]);picture.z_index=int(spec.z);picture.mouse_filter=Control.MOUSE_FILTER_IGNORE;picture.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	picture.set_meta("source_rect",r);picture.set_meta("source_asset_sha256",spec.sha256)
	(parent if parent!=null else canvas).add_child(picture);return picture
func _label(id:String,value:String,box:Rect2,pixels:int,color:Color,outline:int,parent:Control=null,origin:=Vector2.ZERO)->Label:
	var label:=Label.new();label.name=id;label.text=value;label.position=box.position-origin;label.size=box.size;label.clip_text=true;label.mouse_filter=Control.MOUSE_FILTER_IGNORE;label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;label.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font",FontPolicy.get_font("lxgw"));label.add_theme_font_size_override("font_size",pixels);label.add_theme_color_override("font_color",color);label.add_theme_color_override("font_outline_color",Color("0756bd"));label.add_theme_constant_override("outline_size",outline)
	(parent if parent!=null else canvas).add_child(label);return label
func _fit_text(label:Label,box:Rect2,initial:int,minimum:int)->void:
	var face:=label.get_theme_font("font");var pixels:=initial;var outline:=label.get_theme_constant("outline_size")
	while pixels>minimum and face.get_string_size(label.text,HORIZONTAL_ALIGNMENT_LEFT,-1,pixels).x>box.size.x-outline*2-8:pixels-=1
	label.add_theme_font_size_override("font_size",pixels);Typography.center_label(label,box,minimum)
func _gui_input(event:InputEvent)->void:
	if event is InputEventMouseButton or event is InputEventScreenTouch:accept_event()
func _unhandled_key_input(event:InputEvent)->void:
	if event.is_action_pressed("ui_cancel"):close_requested.emit();get_viewport().set_input_as_handled()
