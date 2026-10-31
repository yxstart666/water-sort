extends "res://scripts/ui_restore/touch_hit.gd"
var normal_texture:Texture2D
var pressed_texture:Texture2D
var disabled_texture:Texture2D
var art_box:=Rect2()
var pressed_offset:=0.0
var art:TextureRect
var held:=false
var last_disabled:=false
var disabled_material:ShaderMaterial
var state_overlay_texture:Texture2D
var state_overlay_box:=Rect2()
var state_overlay:TextureRect
func _ready()->void:
	flat=true;focus_mode=Control.FOCUS_ALL;mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
	for state in ["normal","hover","pressed","disabled","focus"]:add_theme_stylebox_override(state,StyleBoxEmpty.new())
	art=TextureRect.new();art.name="ApprovedWholeMaterial";art.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;art.stretch_mode=TextureRect.STRETCH_SCALE;art.mouse_filter=Control.MOUSE_FILTER_IGNORE;art.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS;add_child(art)
	state_overlay=TextureRect.new();state_overlay.mouse_filter=Control.MOUSE_FILTER_IGNORE;state_overlay.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;state_overlay.stretch_mode=TextureRect.STRETCH_SCALE;state_overlay.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS;add_child(state_overlay)
	var shader:=Shader.new();shader.code="shader_type canvas_item; void fragment(){vec4 c=texture(TEXTURE,UV);float y=dot(c.rgb,vec3(.299,.587,.114));COLOR=vec4(mix(vec3(y),c.rgb,.20)*.72,c.a);}";disabled_material=ShaderMaterial.new();disabled_material.shader=shader
	button_down.connect(func():held=true;refresh_material());button_up.connect(func():held=false;refresh_material());mouse_exited.connect(func():held=false;refresh_material());resized.connect(refresh_material)
	refresh_material()
func _process(_delta:float)->void:
	if last_disabled!=disabled:refresh_material()
func refresh_material()->void:
	if not is_instance_valid(art):return
	last_disabled=disabled
	var box:=art_box if art_box.has_area() else Rect2(Vector2.ZERO,size)
	art.position=box.position+Vector2(0,pressed_offset if held and not disabled else 0);art.size=box.size
	art.texture=disabled_texture if disabled and disabled_texture!=null else (pressed_texture if held and pressed_texture!=null else normal_texture)
	art.material=disabled_material if disabled and disabled_texture==null else null
	art.modulate=Color(.94,.94,.94) if held and pressed_texture==null and not disabled else Color.WHITE
	state_overlay.texture=state_overlay_texture;state_overlay.position=state_overlay_box.position;state_overlay.size=state_overlay_box.size
	state_overlay.visible=state_overlay_texture!=null and ((disabled and disabled_texture!=null) or (held and pressed_texture!=null))
	for child in get_children():
		if child is CanvasItem and child!=art:child.modulate=Color(.65,.65,.65) if disabled else Color.WHITE
