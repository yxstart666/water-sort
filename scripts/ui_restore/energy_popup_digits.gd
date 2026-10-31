extends Label
## Live approved independent numeral glyphs. Unknown balances retain the host font.
const FontPolicy=preload("res://scripts/ui_restore/font_policy.gd")
var numeric:Control
var face:Font
var font_ready:=false
var last_draw_metrics:Dictionary={}
func _ready()->void:
	face=FontPolicy.get_font("lxgw");font_ready=face.has_char(48) and face.has_char(47)
	if not font_ready:push_error("Energy dynamic font lacks digits/slash; system fallback remains disabled")
	name="EnergyCapacity";mouse_filter=Control.MOUSE_FILTER_IGNORE;clip_text=true
	horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	add_theme_font_override("font",face);add_theme_font_size_override("font_size",87)
	add_theme_color_override("font_color",Color.TRANSPARENT);add_theme_color_override("font_shadow_color",Color.TRANSPARENT);add_theme_color_override("font_outline_color",Color.TRANSPARENT);add_theme_constant_override("outline_size",0)
	set_meta("font_exact",false);set_meta("font_candidate_source","numeric_runtime_style_candidate.json");queue_redraw()
func _process(_delta:float)->void:
	if not is_instance_valid(numeric):
		numeric=preload("res://scripts/ui_restore/numeric_art_label.gd").new();numeric.name="ApprovedEnergyGlyphs";add_child(numeric);numeric.configure_family("energy",66)
	numeric.size=size;numeric.text=text.replace(" ","");numeric.visible=numeric.is_complete();queue_redraw()
func _draw()->void:
	if is_instance_valid(numeric) and numeric.is_complete():
		last_draw_metrics=numeric.metrics();last_draw_metrics.source="approved_energy_glyphs";return
	if not font_ready:return
	var tokens:=text.split("/")
	var parts:Array=[tokens[0].strip_edges(),"/",tokens[1].strip_edges()] if tokens.size()==2 else [text,"",""]
	var digit_pixels:=87
	var space:=face.get_string_size(" ",HORIZONTAL_ALIGNMENT_LEFT,-1,digit_pixels).x
	var advances:Array=[];var width:=0.0
	while true:
		advances=[];width=0.0
		for i in 3:
			var pixels:=digit_pixels-4 if i==1 else digit_pixels
			var advance:=face.get_string_size(parts[i],HORIZONTAL_ALIGNMENT_LEFT,-1,pixels).x
			advances.append(advance);width+=advance
		space=face.get_string_size(" ",HORIZONTAL_ALIGNMENT_LEFT,-1,digit_pixels).x;width+=2*space
		if width<=size.x-12 or digit_pixels<=54:break
		digit_pixels-=1
	var x:float=(size.x-width)*.5
	var baseline:float=(size.y-face.get_height(digit_pixels))*.5+face.get_ascent(digit_pixels)
	for i in 3:
		var pixels:=digit_pixels-4 if i==1 else digit_pixels;var position:=Vector2(x,baseline)
		var blue:=3 if i==1 else 4;var white:=1 if i==1 else 2
		draw_string_outline(face,position+Vector2(0,6),parts[i],HORIZONTAL_ALIGNMENT_LEFT,-1,pixels,blue,Color("002d69",.72))
		draw_string_outline(face,position,parts[i],HORIZONTAL_ALIGNMENT_LEFT,-1,pixels,blue,Color("0756bd"))
		draw_string_outline(face,position,parts[i],HORIZONTAL_ALIGNMENT_LEFT,-1,pixels,white,Color.WHITE)
		draw_string(face,position,parts[i],HORIZONTAL_ALIGNMENT_LEFT,-1,pixels,Color.WHITE)
		x+=float(advances[i])+(space if i<2 else 0)
	last_draw_metrics={"text":text,"digit_pixels":digit_pixels,"slash_pixels":digit_pixels-4,"advance_width":width,"baseline":baseline,"font_exact":false}
