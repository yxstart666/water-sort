extends Control
## Presentation only: a consumed reward awaits persistence. The host owns retry,
## dismissal and receipt identity. This view never requests or completes an ad.
signal retry_requested
signal dismiss_requested
const Art=preload("res://scripts/ui_restore/recipe_art.gd")
const P2Art=preload("res://scripts/water_sort/p2_art.gd")
const FontPolicy=preload("res://scripts/ui_restore/font_policy.gd")
const REFERENCE=Vector2(320,600)
var locale:="zh"
var content:Dictionary={}
var frame:Control
var title_label:Label
var body_label:Label
var buttons:Dictionary={}
func _ready()->void:
	name="RewardSaveRetryView";mouse_filter=Control.MOUSE_FILTER_IGNORE
	var layouts:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/colorpause_ui_20261030/layouts/reward_retry.json"))
	var spec:Dictionary=layouts[locale]
	for layer in spec.layers:
		if layer.type=="runtimeText":continue
		var visual:=Art.layer(self,layer)
		if frame==null:frame=visual
	title_label=Label.new();title_label.name="HostHeading";title_label.add_theme_font_override("font",FontPolicy.get_font("lxgw"));title_label.text=content.title;title_label.hide();add_child(title_label)
	body_label=Label.new();body_label.name="PendingRewardExplanation"
	body_label.add_theme_font_override("font",FontPolicy.get_font("lxgw"))
	body_label.add_theme_font_size_override("font_size",15)
	body_label.add_theme_color_override("font_color",Color("0963bd"))
	body_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	body_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;body_label.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	body_label.mouse_filter=Control.MOUSE_FILTER_IGNORE
	body_label.position=Vector2(38.4,157);body_label.size=Vector2(243.2,108)
	body_label.text=content.body;add_child(body_label)
	for target in spec.hotareas:
		var retry:bool=target.action=="AdRetry"
		var id:="AdRetry" if retry else "AdClose"
		var callback:Callable=func():
			if retry:retry_requested.emit()
			else:dismiss_requested.emit()
		var hit_box:=Art.box(target.rectDp)
		# At short320x480, the600dp canvas fits by height (0.8).
		# A60.4dp invisible target remains48.32px; artwork is unchanged.
		if not retry:hit_box=hit_box.grow(7.0)
		buttons[id]=P2Art.hit(self,id,hit_box,callback)
		buttons[id].tooltip_text=content.retry if retry else content.dismiss
	# Existing callers use either AdCancel or AdClose for the same dismiss request.
	# The delivered layout has one close icon; it does not cancel the earned receipt.
	buttons.AdCancel=buttons.AdClose
