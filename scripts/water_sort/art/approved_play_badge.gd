extends Control
## Transparent-canvas compensation shared by approved game and popup placements.
const Assets=preload("res://scripts/water_sort/order_gameplay_assets.gd")
const TEXTURE=preload(Assets.APPROVED_PLAY)
const CANVAS:=Vector2(1033,983)
const STRONG_RECT:=Rect2(34,20,962,899)
var visible_box:=Rect2()
func _init()->void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
	texture_repeat=CanvasItem.TEXTURE_REPEAT_DISABLED
static func sprite_box(strong_box:Rect2)->Rect2:
	var factor:=strong_box.size.x/STRONG_RECT.size.x
	return Rect2(strong_box.position-STRONG_RECT.position*factor,CANVAS*factor)
func _draw()->void:
	if visible_box.has_area():draw_texture_rect(TEXTURE,sprite_box(visible_box),false)
