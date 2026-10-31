extends Control
## Approved standalone play mark before the complete localized button caption.
## Parent button keeps its original face, actions and hit rectangle.
const Badge=preload("res://scripts/water_sort/art/approved_play_badge.gd")
const Typography=preload("res://scripts/ui_restore/typography.gd")
const FONT_PIXELS:=52
const GAP:=24.0
const ICON_HEIGHT:=64.0
var caption:=""
var last_disabled:=false
func _init()->void:
	name="ApprovedPlayCaption";mouse_filter=Control.MOUSE_FILTER_IGNORE
	texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
	texture_repeat=CanvasItem.TEXTURE_REPEAT_DISABLED
func _ready()->void:
	resized.connect(queue_redraw)
func _process(_delta:float)->void:
	if get_parent().disabled!=last_disabled:
		last_disabled=get_parent().disabled;queue_redraw()
func metrics()->Dictionary:
	var button:Button=get_parent()
	var font:Font=button.get_theme_font("font")
	var ink:=Typography.ink_bounds(caption,font,FONT_PIXELS)
	var icon_size:=Vector2(962.0/899.0*ICON_HEIGHT,ICON_HEIGHT)
	var width:=icon_size.x+GAP+ink.size.x
	var left:float=(size.x-width)*.5
	var icon:=Rect2(Vector2(left,(size.y-icon_size.y)*.5),icon_size)
	var text_ink:=Rect2(Vector2(icon.end.x+GAP,(size.y-ink.size.y)*.5),ink.size)
	return {"icon_visible":icon,"text_ink":text_ink,"text_baseline":text_ink.position-ink.position,"group_width":width,"font_pixels":FONT_PIXELS,"gap":GAP}
func _draw()->void:
	if not is_instance_valid(get_parent()) or caption.is_empty():return
	var button:Button=get_parent();var layout:=metrics()
	draw_texture_rect(Badge.TEXTURE,Badge.sprite_box(layout.icon_visible),false)
	var ink:Color=button.get_theme_color("font_disabled_color" if button.disabled else "font_color")
	draw_string(button.get_theme_font("font"),layout.text_baseline,caption,HORIZONTAL_ALIGNMENT_LEFT,-1,FONT_PIXELS,ink)
