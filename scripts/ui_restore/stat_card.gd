extends Control
## Independent blank art + localized caption + host value. No data aggregation.
const Art=preload("res://scripts/ui_restore/recipe_art.gd")
const Text=preload("res://scripts/ui_restore/data_text.gd")
var caption:=""
var value:=""
var value_id:="Value"
var value_label:Label
func _ready()->void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	Art.layer(self,{"type":"sprite","source":"data_page_components/recovery/sprites/summary_card_shell.webp","rectDp":[0,0,size.x,size.y]})
	Text.label(self,"Caption",caption,Rect2(6,9,size.x-12,22),16)
	value_label=Text.label(self,value_id,value,Rect2(6,33,size.x-12,27),23)
