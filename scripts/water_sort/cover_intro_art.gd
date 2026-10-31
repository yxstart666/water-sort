extends Control
## Project-specific illustration adapter; never mutates the game or stores.
const Visual=preload("res://scripts/water_sort/art/bottle_visual.gd")
const Assets=preload("res://scripts/water_sort/order_gameplay_assets.gd")
var color:="green"
var covered_demo_layers:Array=[]
var unknown_demo:=false
var unknown_demo_count:=3
var unknown_demo_layers:Array=[]
var condition: Dictionary={"kind":"any","color":"","required":1,"completed":0,"remaining":1}
var locale:="zh"
var bottle
var cover
var age:=0.0
func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	bottle=Visual.new(); bottle.show_behind_parent=true; add_child(bottle); bottle.use_delivered_layers()
	bottle.scale=Vector2.ONE*1.2/float(Assets.BOTTLE_CONTRACT.normalization)
	# BottleVisual is already anchored at its mouth; only Y needs the canvas inset.
	bottle.position=Vector2(470,560+Assets.BOTTLE_CONTRACT.mouth.y*1.2)
	if unknown_demo:
		bottle.unknown_layers=[unknown_demo_count>=1,unknown_demo_count>=2,unknown_demo_count>=3,false]
		bottle.set_layers(unknown_demo_layers if not unknown_demo_layers.is_empty() else ["red","blue","green","yellow"])
	else:
		bottle.set_layers(covered_demo_layers if not covered_demo_layers.is_empty() else [color,color,color,color])
		# This locked mechanism illustration is not a completed delivery bottle.
		# Its old auto-seal must not protrude above the approved closed cloth.
		bottle.sync_seal_immediate(false)
		bottle.delivered_layers.cover_upper_layers=false
		bottle.delivered_layers.sync()
		cover=preload("res://scripts/water_sort/art/bottle_cover.gd").new()
		cover.enlarged=true
		bottle.add_child(cover); cover.configure(condition,locale)
	queue_redraw()
func _process(delta: float) -> void:
	age+=delta; queue_redraw()
func _draw() -> void:
	var fade:=maxf(0,1-age/1.3)
	for i in 12:
		var angle:=i*TAU/12.0+age*0.1
		var origin:=Vector2(470,800)
		draw_line(origin+Vector2.from_angle(angle)*160,origin+Vector2.from_angle(angle)*300,Color(1,0.8,0.25,fade*0.4),5,true)
	# Cover and tag remain bottle-local and unchanged until the modal closes.
