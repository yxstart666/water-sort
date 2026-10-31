extends RefCounted
const ROOT:="res://art/colorpause/ui_unified_20261030/"
const ButtonArt=preload("res://scripts/ui_restore/approved_art_button.gd")
static var manifests:Dictionary={}
static func entry(page:String,id:String)->Dictionary:
	if not manifests.has(page):
		var data:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(ROOT+page+"/manifest.json"));var map:Dictionary={}
		for item in data.get("assets",data.get("layers",[])):
			map[item.get("id",item.get("key",""))]=item
		manifests[page]=map
	return manifests[page].get(id,{})
static func texture(page:String,id:String)->Texture2D:return load(ROOT+page+"/"+str(entry(page,id).file))
static func box(page:String,id:String)->Rect2:
	var item:=entry(page,id);var r:Array=item.get("rect_xywh",item.get("rect_px",[]))
	return Rect2(r[0],r[1],r[2],r[3]) if item.has("rect_xywh") else Rect2(r[0],r[1],r[2]-r[0],r[3]-r[1])
static func picture(parent:Node,page:String,id:String,target:=Rect2())->TextureRect:
	var node:=TextureRect.new();node.name=id;node.texture=texture(page,id);node.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;node.stretch_mode=TextureRect.STRETCH_SCALE;node.mouse_filter=Control.MOUSE_FILTER_IGNORE;node.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var rect:=target if target.has_area() else box(page,id);node.position=rect.position;node.size=rect.size;node.z_index=int(entry(page,id).get("z",0));parent.add_child(node);return node
static func button(parent:Node,page:String,id:String,action:Callable,target:=Rect2(),pressed:="",disabled:="")->Button:
	var node:=ButtonArt.new();node.name=id;node.normal_texture=texture(page,id)
	if not pressed.is_empty():node.pressed_texture=texture(page,pressed)
	if not disabled.is_empty():node.disabled_texture=texture(page,disabled)
	var rect:=target if target.has_area() else box(page,id);node.position=rect.position;node.size=rect.size;node.z_index=70;parent.add_child(node);node.pressed.connect(action);return node
static func label(parent:Node,id:String,value:String,rect:Rect2,pixels:int,color:=Color("0942a5"),outline:=0)->Label:
	var node:=Label.new();node.name=id;node.text=value;node.position=rect.position;node.size=rect.size;node.mouse_filter=Control.MOUSE_FILTER_IGNORE;node.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;node.vertical_alignment=VERTICAL_ALIGNMENT_CENTER;node.add_theme_font_override("font",preload("res://scripts/ui_restore/font_policy.gd").get_font("lxgw"));node.add_theme_font_size_override("font_size",pixels);node.add_theme_color_override("font_color",color);node.add_theme_constant_override("outline_size",outline);node.add_theme_color_override("font_outline_color",Color("0052ae"));node.z_index=75;parent.add_child(node);return node
