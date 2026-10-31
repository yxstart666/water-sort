extends Node2D
## Exact approved slices in the original165x410 canvas, transformed from its mouth.
## Shared shell, true specified color and live count; rules remain authoritative.
const Assets=preload("res://scripts/water_sort/order_gameplay_assets.gd")
const CLOTH_POSITION:=Vector2(13.680866965620337,6.456544502617801)
const CLOTH_SCALE:=Vector2(.20478325859491778,.181151832460733)
const CARD_POSITION:=Vector2(31.20222222222222,88.64666666666665)
const CARD_SCALE:=.3177777777777778
const ANY_ROOT:="res://art/colorpause/approved_any_unlock/"
const AnyCard=preload(ANY_ROOT+"scene/approved_any_unlock_card.tscn")
const AnyCount=preload("res://scripts/water_sort/art/approved_any_count.gd")
const SpecifiedCard=preload("res://scripts/water_sort/art/specified_color_card.gd")
var cloth_texture:Texture2D=preload(Assets.CLOTH)
var tag_texture:Texture2D=preload(Assets.CLOTH_CARD)
var cloth_rect:=Rect2(CLOTH_POSITION,Vector2(677,1917)*CLOTH_SCALE)
var tag_rect:=Rect2(CARD_POSITION,Vector2(326,456)*CARD_SCALE)
var condition:Dictionary={}
var locked:=true
var enlarged:=false # Compatibility only: illustration scales its whole existing bottle.
var locale:="zh"
var card_available:=false
var missing_variant:=""
var any_card:Node2D
var any_count:Node2D
var specified_card:Node2D
func _init()->void:
	name="BottleCover";z_index=4
	texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	texture_repeat=CanvasItem.TEXTURE_REPEAT_DISABLED
	var canvas:=Node2D.new();canvas.name="OriginalBottleCanvas"
	canvas.position=-Assets.BOTTLE_CONTRACT.mouth*Assets.BOTTLE_CONTRACT.normalization
	canvas.scale=Vector2.ONE*Assets.BOTTLE_CONTRACT.normalization
	add_child(canvas)
	any_card=AnyCard.instantiate();canvas.add_child(any_card)
	# Preserve the delivered scene/source bytes, but remove its old descriptive
	# text sprite from the live card. The approved revision is icon plus count.
	var old_text=any_card.get_node("ObjectiveText")
	any_card.remove_child(old_text);old_text.free()
	any_count=AnyCount.new();any_card.add_child(any_count)
	# The supplied scene's standalone z=11 is rebased into this bottle-local
	# cover stack (z=4). Shell, icon and count stay below moving glass z=8.
	any_card.z_index=0;any_card.visible=false
	specified_card=SpecifiedCard.new();canvas.add_child(specified_card)
static func approved_card_matches(progress:Dictionary,language:String)->bool:
	return language in ["zh","en"] and SpecifiedCard.supported(progress)
static func approved_any_matches(progress:Dictionary,language:String)->bool:
	return language in ["zh","en"] and progress.get("kind","")=="any" and int(progress.get("required",0)) in [1,2] and int(progress.get("remaining",0)) in [1,2] and int(progress.remaining)<=int(progress.required)
func configure(progress:Dictionary,language:String,is_locked:=true)->void:
	condition=progress.duplicate();locale=language;locked=is_locked
	visible=int(condition.get("remaining",0))>0
	var show_any:=approved_any_matches(condition,locale)
	any_card.visible=visible and show_any
	any_count.remaining=int(condition.get("remaining",0)) if show_any else 0
	specified_card.hide()
	if visible and condition.get("kind","")=="color":specified_card.configure(condition)
	card_available=approved_card_matches(condition,locale) or show_any
	missing_variant="" if card_available or not visible else "%s/%s/required%d/remaining%d/%s"%[str(condition.get("kind","any")),str(condition.get("color","")),int(condition.get("required",0)),int(condition.get("remaining",0)),locale]
	set_meta("approved_task_card_available",card_available)
	set_meta("missing_task_card_variant",missing_variant)
	queue_redraw()
func _draw()->void:
	if not visible or condition.is_empty():return
	var factor:float=Assets.BOTTLE_CONTRACT.normalization
	draw_texture_rect(cloth_texture,Rect2((cloth_rect.position-Assets.BOTTLE_CONTRACT.mouth)*factor,cloth_rect.size*factor),false)
