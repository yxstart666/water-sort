extends RefCounted
const FontPolicy=preload("res://scripts/ui_restore/font_policy.gd")
static func label(parent:Control,id:String,value:String,box:Rect2,pixels:int,wrap:=false)->Label:
	var node:=Label.new();node.name=id;node.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var font:=FontPolicy.get_font("lxgw");node.add_theme_font_override("font",font)
	if not wrap:
		while pixels>12 and font.get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,pixels).x>box.size.x-4:pixels-=1
	node.add_theme_font_size_override("font_size",pixels);node.add_theme_color_override("font_color",Color("145eaf"))
	node.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;node.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	node.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART if wrap else TextServer.AUTOWRAP_OFF
	node.position=box.position;node.size=box.size;node.text=value;parent.add_child(node)
	if not wrap:preload("res://scripts/ui_restore/typography.gd").center_label(node,box,12)
	return node
