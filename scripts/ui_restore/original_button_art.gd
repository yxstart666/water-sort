extends RefCounted
## Approved whole normal materials, registered uniformly. No icon/letter reassembly.
const ROOT:="res://assets/approved_ui_sources_v1/assets/"
static func picture(parent:Control,id:String,path:String,box:Rect2)->TextureRect:
	var texture:Texture2D=load(ROOT+path)
	var k:=minf(box.size.x/texture.get_width(),box.size.y/texture.get_height())
	var result:=TextureRect.new();result.name=id;result.texture=texture
	result.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;result.stretch_mode=TextureRect.STRETCH_SCALE
	result.size=texture.get_size()*k;result.position=box.get_center()-result.size*.5
	result.mouse_filter=Control.MOUSE_FILTER_IGNORE;result.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	result.set_meta("original_complete_material",true);parent.add_child(result);return result
static func gear(parent:Control,id:String,old_canvas:Rect2)->TextureRect:
	# Original small ink [5,6,130,129]; repaired source body [43,52,1207,1207].
	var old_k:=old_canvas.size.x/138.0
	var target:=Rect2(old_canvas.position+Vector2(5,6)*old_k,Vector2(125,123)*old_k)
	var k:=minf(target.size.x/1164.0,target.size.y/1155.0)
	var result:=picture(parent,id,"highres/settings_v1_raw.png",Rect2(Vector2.ZERO,Vector2.ONE*1254*k))
	result.position=target.get_center()-Vector2(625,629.5)*k
	result.set_meta("registered_body_target",target);return result
