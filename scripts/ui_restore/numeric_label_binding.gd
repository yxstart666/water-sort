extends Control
## Keep the host Label's live semantic text while drawing approved independent glyphs.
const Numeric=preload("res://scripts/ui_restore/numeric_art_label.gd")
var host:Label
var family:="levels"
var face_pixels:=91.0
var prefix:=""
var numeral:Control
var prefix_label:Label
var _last_text:=""
var _last_size:=Vector2.ZERO
var _layout_current:=false
func _ready()->void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	host=get_parent() as Label
	for color in ["font_color","font_outline_color","font_shadow_color"]:host.add_theme_color_override(color,Color.TRANSPARENT)
	numeral=Numeric.new();numeral.name="ApprovedDynamicGlyphs";add_child(numeral);numeral.configure_family(family,face_pixels)
	if not prefix.is_empty():
		prefix_label=preload("res://scripts/ui_restore/approved_ui_art.gd").label(self,"NativeLevelPrefix",prefix,Rect2(),roundi(face_pixels*1.3),Color.WHITE,1)
		prefix_label.add_theme_color_override("font_outline_color",Color("ae5700"))
		prefix_label.theme_changed.connect(func(): _layout_current=false)
	_sync()
func _process(_delta:float)->void:_sync()
func _sync()->void:
	# Parent breathing changes only its transform, never this local geometry.
	# Re-measure the prefix and resolve glyphs only when semantic text/size/theme changes.
	if _layout_current and _last_text==host.text and _last_size==host.size:return
	_last_text=host.text;_last_size=host.size;_layout_current=true
	size=host.size;numeral.size=size
	numeral.text=host.text.replace(" ","")
	if is_instance_valid(prefix_label):
		var font:Font=prefix_label.get_theme_font("font");var width:=font.get_string_size(prefix,HORIZONTAL_ALIGNMENT_LEFT,-1,prefix_label.get_theme_font_size("font_size")).x
		var digit_width:float=numeral.metrics().source_ink_bounds.size.x*face_pixels/100
		var gap:=face_pixels*.22;var x:float=(size.x-width-gap-digit_width)*.5
		prefix_label.position=Vector2(x,0);prefix_label.size=Vector2(width,size.y)
		numeral.content_rect=Rect2(x+width+gap,0,digit_width+.01,size.y)
	if not numeral.is_complete():push_error("Approved numeric layout missing coverage: "+host.name+" "+host.text)
