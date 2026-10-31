extends RefCounted
## Production1080 contains the delivered940 canvas uniformly. Pause stays941.
const CANVAS := Vector2(1080,1920)
const DESIGN := Vector2(940,1672)
const DESIGN_SCALE := 1920.0/1672.0
const DESIGN_OFFSET := Vector2((1080.0-940.0*DESIGN_SCALE)*0.5,0)
const MIN_TOUCH := 132.3 #44.1px at360px, including float/transform rounding.
const SLOTS := {
	"energy":Rect2(DESIGN_OFFSET+Vector2(49,32.5)*DESIGN_SCALE,Vector2(233,142)*DESIGN_SCALE),
	"level":Rect2(DESIGN_OFFSET+Vector2(327,62)*DESIGN_SCALE,Vector2(286,83)*DESIGN_SCALE),
	"stats":Rect2(DESIGN_OFFSET+Vector2(267,144)*DESIGN_SCALE,Vector2(407,64)*DESIGN_SCALE),
	"pause":Rect2(DESIGN_OFFSET+Vector2(763,42)*DESIGN_SCALE,Vector2(142,142)*DESIGN_SCALE),
	"count":Rect2(DESIGN_OFFSET+Vector2(342,430)*DESIGN_SCALE,Vector2(256,44)*DESIGN_SCALE),
	# 34 design pixels contain the delivered CJK font's37px runtime line height.
	"guide":Rect2(DESIGN_OFFSET+Vector2(45,482)*DESIGN_SCALE,Vector2(850,34)*DESIGN_SCALE),
	"undo":Rect2(DESIGN_OFFSET+Vector2(271,1480)*DESIGN_SCALE,Vector2(175,174)*DESIGN_SCALE),
	"restart":Rect2(DESIGN_OFFSET+Vector2(496,1480)*DESIGN_SCALE,Vector2(173,174)*DESIGN_SCALE)
}
static var _runtime: Dictionary={}

static func runtime() -> Dictionary:
	if _runtime.is_empty():
		_runtime=JSON.parse_string(FileAccess.get_file_as_string("res://art/reference2-delivery-20261024/reference2_runtime_layouts_v1/layouts/reference2_board_layout_completion_v1__board_8_zh.json"))
	return _runtime

static func element(id: String) -> Dictionary:
	for item in runtime().elements:
		if item.id==id: return item
	return {}

static func design_rect(rect: Rect2) -> Rect2:
	return Rect2(DESIGN_OFFSET+rect.position*DESIGN_SCALE,rect.size*DESIGN_SCALE)

static func element_rect(id: String) -> Rect2:
	var value: Array=element(id).rect
	return design_rect(Rect2(value[0],value[1],value[2],value[3]))
const TWO_ROW := {"tops":[588.5,1007.916666666667],"width":135.0,"pitch":127.44,"max_columns":5}
const THREE_ROW := {"tops":[564.0,880.538181818182,1197.076363636364],"width":108.0,"pitch":118.0,"max_columns":5}
# Five-column boards use spare width to separate actual glass silhouettes.
# A constant gap between native canvases preserves every bottle's scale.
const FIVE_COLUMN_CANVAS_GAP := 16.0
const SINGLE_ART_Y := 780.0
# Include the order count and guide, not only the order-card artwork.
const TOP_TRAVEL_FLOOR := 494.0 # Below the actual order-card artwork.
const TEXT_EXCLUSION := Rect2(280,486,520,138) # Count + centered guide/hint ink.

static func two_rows(total: int) -> bool:
	return total>=6

static func configuration(total: int) -> Dictionary:
	assert(total>=1 and total<=15,"Bottle layout supports1..15 occupied slots")
	if total<=5:
		var single:Dictionary={"rows":1,"columns":total,"counts":[total],"tops":[SINGLE_ART_Y],"width":165.0}
		if total==5:single.pitch=165.0+FIVE_COLUMN_CANVAS_GAP
		return single
	var profile: Dictionary=THREE_ROW if total>10 else TWO_ROW
	var rows:=3 if total>10 else 2
	var counts:Array=[]
	# Equal lower rows share columns; any shorter first row is centered normally.
	# E.g. 13 slots -> 3+5+5, derived from the observed 14-slot 4+5+5 layout.
	var columns:=ceili(float(total)/rows)
	counts.append(total-columns*(rows-1))
	for row in range(1,rows): counts.append(columns)
	var pitch:float=float(profile.width)+FIVE_COLUMN_CANVAS_GAP if columns==5 else float(profile.pitch)
	return {"rows":rows,"columns":columns,"counts":counts,"tops":profile.tops,"width":profile.width,"pitch":pitch}

static func bottle_slot(total: int, index: int, minimum_world_touch:float=MIN_TOUCH) -> Dictionary:
	# Chosen from total inventory at level construction, never remaining bottles.
	var config:=configuration(total)
	var columns: int=config.columns
	var row:=0; var column:=index
	while column>=int(config.counts[row]): column-=int(config.counts[row]); row+=1
	var row_count: int=config.counts[row]
	var native_width: float=config.width
	var pitch: float=float(config.get("pitch",minf(205.0,(680.0-native_width*153.0/165.0)/maxf(1.0,columns-1))))
	# At short aspect ratios the scene is height-fitted, leaving spare width.
	# Allocate that width to real separate native targets, not overlapping halos.
	# The caller freezes the world/window conversion for this built board, and
	# routes query the same slot profile. No bottle scale, row Y or rules change.
	pitch=maxf(pitch,(maxf(MIN_TOUCH,minimum_world_touch)+1.5)/DESIGN_SCALE)
	var native_height:=410.0*native_width/165.0
	var center:=470.0+(column-(row_count-1)*0.5)*pitch
	var top: float=config.tops[row]
	var art:=design_rect(Rect2(center-native_width*0.5,top,native_width,native_height))
	var hit:=art.grow(8.0*DESIGN_SCALE)
	var minimum:=maxf(MIN_TOUCH,minimum_world_touch)
	if hit.size.x<minimum:
		hit=Rect2(Vector2(hit.get_center().x-minimum*0.5,hit.position.y),Vector2(minimum,hit.size.y))
	var hit_width:=minf(hit.size.x,pitch*DESIGN_SCALE-1.5)
	hit=Rect2(Vector2(hit.get_center().x-hit_width*0.5,hit.position.y),Vector2(hit_width,hit.size.y))
	# Keep the enlarged lower bottles' transparent padding off the command hits.
	if row==int(config.rows)-1: hit.size.y=minf(hit.size.y,SLOTS.undo.position.y-2.0-hit.position.y)
	# Selection lifts a control by22 logical pixels. Trim only the upper row's
	# transparent foot padding so a lifted lower hit never overlaps it.
	if row<int(config.rows)-1: hit.size.y=minf(hit.size.y,(float(config.tops[row+1])-8.0)*DESIGN_SCALE-24.0-hit.position.y)
	return {"hit":hit,"art":art,"row":row,"pitch":pitch*DESIGN_SCALE}

static func order_card(slot: int, count: int) -> Rect2:
	return design_rect(Rect2(470+(slot-(count-1)*0.5)*164-78.5,216,157,204))

static func order_anchor(slot: int, count: int) -> Vector2:
	var card:=order_card(slot,count)
	return card.position+Vector2(79,54)*DESIGN_SCALE

static func bonus_button(slot: Dictionary) -> Rect2:
	var hit: Rect2=slot.hit
	return Rect2(hit.get_center()-Vector2(hit.size.x,MIN_TOUCH)*0.5,Vector2(hit.size.x,MIN_TOUCH))

static func place_art(visual: Node2D, bounds: Rect2, area: Rect2, parent_origin: Vector2) -> Rect2:
	# Uniform containment from the active renderer's bounds. Layout owns a slot,
	# never a bottle silhouette, liquid line, outlet or artwork-specific pivot.
	var scale_factor:=minf(area.size.x/bounds.size.x,area.size.y/bounds.size.y)
	var used:=bounds.size*scale_factor
	var top_left:=area.position+Vector2((area.size.x-used.x)*0.5,0)
	visual.scale=Vector2.ONE*scale_factor
	visual.position=top_left-parent_origin-bounds.position*scale_factor
	return Rect2(top_left,used)
