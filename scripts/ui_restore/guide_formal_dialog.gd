extends Control
const REFERENCE:=Vector2(915,1719)
var locale:="zh"
var energy_text:="30/30"
var closed:Callable
var guide:Control
var background:TextureRect
func _ready()->void:
	mouse_filter=Control.MOUSE_FILTER_STOP
	background=TextureRect.new();background.texture=load("res://art/reference2-delivery-20261024/reference2_background_cleanplate_v1/assets/background_native_940x1672.png");background.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;background.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_COVERED;background.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(background)
	guide=preload("res://scripts/ui_restore/guide_formal_view.gd").new();guide.name="LiveHelpPour";guide.locale=locale;guide.energy_text=energy_text;guide.closed=closed;guide.size=REFERENCE;add_child(guide)
	resized.connect(_fit);_fit()
func _fit()->void:
	if not is_instance_valid(guide):return
	background.size=size
	if preload("res://scripts/ui_restore/screen_layout.gd").fit_modal(self,guide,REFERENCE):return
	var k:=minf(size.x/REFERENCE.x,size.y/REFERENCE.y);guide.scale=Vector2.ONE*k;guide.position=(size-REFERENCE*k)*.5
