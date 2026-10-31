extends Label
## Measured native glyphs remain state-driven. No baked QA caption or synthetic weight.
const FontPolicy=preload("res://scripts/ui_restore/font_policy.gd")
var lines:Array[Label]=[]
var locale:="zh"
var previous_text:=""
func _ready()->void:
	add_theme_color_override("font_color",Color.TRANSPARENT)
	for i in 2:
		var line:=Label.new();line.name="CaptionLine"+str(i+1);line.mouse_filter=Control.MOUSE_FILTER_IGNORE;line.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;line.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
		line.add_theme_font_override("font",FontPolicy.get_font("lxgw"));line.add_theme_font_size_override("font_size",55 if i==0 else 53);line.add_theme_color_override("font_color",Color("042590"));line.add_theme_constant_override("outline_size",0)
		if locale=="zh" and i==0:
			# Tracking only: source five-character row282px; original native ink273px.
			# No embolden or contour modification; second row's native475px matches476px.
			var tracked:=FontVariation.new();tracked.base_font=FontPolicy.get_font("lxgw");tracked.spacing_glyph=2;tracked.variation_embolden=0
			line.add_theme_font_override("font",tracked)
		line.position=Vector2(0,12+i*68);line.size=Vector2(510,68);add_child(line);lines.append(line)
	_sync()
func _process(_delta:float)->void:_sync()
func _sync()->void:
	if text==previous_text:return
	previous_text=text
	var parts:=text.split("\n")
	for i in 2:lines[i].text=parts[i] if i<parts.size() else ""
