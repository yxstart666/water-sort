extends "res://scripts/ui_restore/touch_hit.gd"
## Real native Button; the source materials have one identical alpha silhouette.
var normal_texture:Texture2D
var pressed_texture:Texture2D
var disabled_texture:Texture2D
var art:TextureRect
var held:=false
func _ready()->void:
	flat=true;focus_mode=Control.FOCUS_ALL;mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
	set_meta("touch_native_hit",true)
	for state in ["normal","hover","pressed","disabled","focus"]:add_theme_stylebox_override(state,StyleBoxEmpty.new())
	art=TextureRect.new();art.name="OriginalSourceMaterial";art.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;art.stretch_mode=TextureRect.STRETCH_SCALE;art.mouse_filter=Control.MOUSE_FILTER_IGNORE;art.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	add_child(art);art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	button_down.connect(func():held=true;refresh_material())
	button_up.connect(func():held=false;refresh_material())
	mouse_exited.connect(func():held=false;refresh_material())
	refresh_material()
func refresh_material()->void:
	if not is_instance_valid(art):return
	art.texture=disabled_texture if disabled and disabled_texture!=null else (pressed_texture if held and pressed_texture!=null else normal_texture)
	art.modulate=Color(.92,.92,.92) if held and pressed_texture==null else Color.WHITE
