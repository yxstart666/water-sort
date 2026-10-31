extends Node2D
## Art-only adapter. Rules own color matching, remaining count and unlocking.
const ROOT:="res://art/colorpause/approved_color_unlock/"
const Art=preload(ROOT+"scene/specified_color_card_art.tscn")
const Count=preload("res://scripts/water_sort/art/approved_any_count.gd")
const COLORS:={
	"red":preload(ROOT+"runtime/target_red_card_layer.png"),
	"orange":preload(ROOT+"runtime/target_orange_card_layer.png"),
	"yellow":preload(ROOT+"runtime/target_yellow_card_layer.png"),
	"green":preload(ROOT+"runtime/target_green_card_layer.png"),
	"blue":preload(ROOT+"runtime/target_blue_card_layer.png"),
	"purple":preload(ROOT+"runtime/target_purple_card_layer.png"),
	"pink":preload(ROOT+"runtime/target_pink_card_layer.png"),
	"cyan":preload(ROOT+"runtime/target_cyan_card_layer.png")
}
var art:Node2D
var count:Node2D
var color:=""
var last_error:=""
func _init()->void:
	name="SpecifiedColorCard";texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	art=Art.instantiate();add_child(art)
	for child in art.get_children():
		if child is CanvasItem:child.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	count=Count.new();art.get_node("LiveCountMount").add_child(count)
	hide()
static func supported(progress:Dictionary)->bool:
	return progress.get("kind","")=="color" and COLORS.has(str(progress.get("color",""))) and int(progress.get("required",0)) in [1,2] and int(progress.get("remaining",0)) in [1,2] and int(progress.remaining)<=int(progress.required)
func configure(progress:Dictionary)->bool:
	hide();last_error="";color=str(progress.get("color",""));count.remaining=0
	if int(progress.get("remaining",0))<=0:return true
	if not supported(progress):
		last_error="Unsupported specified color/count: "+JSON.stringify(progress)
		push_error(last_error)
		return false
	art.get_node("TargetColorIcon").texture=COLORS[color]
	count.remaining=int(progress.remaining)
	show();return true
