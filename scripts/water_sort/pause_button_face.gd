extends Control
## Lossless runtime slices of the accepted pause buttons. Center strips contain
## no icon or baked lettering; original rims, highlights and shadows are reused.
const PRIMARY=preload("res://assets/ui_restore/modal_normal_v3/modal_resume_zh.png")
const SECONDARY=preload("res://assets/ui_restore/modal_normal_v3/modal_restart_zh.png")
var secondary:=false
var button:Button
var pressed:=false
func _ready()->void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
	set_meta("pause_button_face",true)
	resized.connect(queue_redraw)
	if is_instance_valid(button):
		button.button_down.connect(func():pressed=true;queue_redraw())
		button.button_up.connect(func():pressed=false;queue_redraw())
		button.mouse_exited.connect(func():pressed=false;queue_redraw())
func _process(_delta:float)->void:
	if is_instance_valid(button):
		var tint:=Color(0.48,0.53,0.61,0.8) if button.disabled else (Color(0.92,0.92,0.92) if pressed else Color.WHITE)
		if modulate!=tint:modulate=tint
func _draw()->void:
	var image:Texture2D=SECONDARY if secondary else PRIMARY
	var native:Vector2=image.get_size();var cap:=minf(100.0*size.y/native.y,size.x*0.45)
	draw_texture_rect_region(image,Rect2(0,0,cap,size.y),Rect2(0,0,100,native.y))
	draw_texture_rect_region(image,Rect2(cap,0,maxf(0,size.x-2*cap),size.y),Rect2(104,0,20,native.y))
	draw_texture_rect_region(image,Rect2(size.x-cap,0,cap,size.y),Rect2(native.x-100,0,100,native.y))
