extends Node2D
## Approved compact ANY count, in the original326x456 card canvas.
const FONT=preload("res://art/reference2-delivery-20261024/reference2_sc_font_v1/fonts/NotoSansCJKsc-Bold.otf")
const FILL:=Color8(250,251,255)
const OUTLINE:=Color8(3,6,23)
const TIMES_BASELINE:=Vector2(51,375)
const NUMBER_BASELINE:=Vector2(157,420)
const TIMES_PIXELS:=100
const NUMBER_PIXELS:=200
const TIMES_OUTLINE:=3
const NUMBER_OUTLINE:=5
var remaining:=2:
	set(value):
		if remaining==value:return
		remaining=value;queue_redraw()
func _init()->void:
	name="ObjectiveCount"
	texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
	texture_repeat=CanvasItem.TEXTURE_REPEAT_DISABLED
func _draw()->void:
	if remaining not in [1,2]:return
	var font: Font=preload("res://scripts/ui_restore/font_policy.gd").get_font("sc")
	# Keep each source-pixel baseline and outline exact; only the parent card
	# applies the already-approved single uniform bottle transform.
	# Pass the approved3px/5px values directly. Renderer alpha bounds are a
	# raster reference, not a reason to alter outline width or stretch glyphs.
	draw_string_outline(font,TIMES_BASELINE,"×",HORIZONTAL_ALIGNMENT_LEFT,-1,TIMES_PIXELS,TIMES_OUTLINE,OUTLINE)
	draw_string_outline(font,NUMBER_BASELINE,str(remaining),HORIZONTAL_ALIGNMENT_LEFT,-1,NUMBER_PIXELS,NUMBER_OUTLINE,OUTLINE)
	draw_string(font,TIMES_BASELINE,"×",HORIZONTAL_ALIGNMENT_LEFT,-1,TIMES_PIXELS,FILL)
	draw_string(font,NUMBER_BASELINE,str(remaining),HORIZONTAL_ALIGNMENT_LEFT,-1,NUMBER_PIXELS,FILL)
