extends Control
## Order frame is presentation only; receipt/display state remains authoritative.
const Visual = preload("res://scripts/water_sort/art/bottle_visual.gd")
const Orders = preload("res://scripts/water_sort/order_rules.gd")
const Layout = preload("res://scripts/water_sort/order_gameplay_layout.gd")
const Assets = preload("res://scripts/water_sort/order_gameplay_assets.gd")
const FULL_FEEDBACK_DURATION := 0.90
const TARGET_SCALE := 137.0*Layout.DESIGN_SCALE/(410.0*Assets.BOTTLE_CONTRACT.normalization)
const PENDING = preload(Assets.ROOT+"reference2_order_edge_fix_v1/assets/order_card_pending_white.png")
const COMPLETE = preload(Assets.ROOT+"reference2_order_feedback_r2/assets/order_card_complete_gold.png")
const BADGE = preload(Assets.ROOT+"reference2_order_feedback_r2/assets/order_complete_badge_52.png")
const TRIAL = preload(Assets.ROOT+"reference2_order_status_v1/assets/order_trial_card_blank.png")
const VIDEO = preload(Assets.FINISH+"icon_video_ad.png")
var game
var clock := 0.0
var bursts: Array = []
var slot_states: Dictionary = {}
var target_bottles: Array = []
var card_foreground: Node2D
var guide_pointer: Node2D
var guide_key := ""
static var card_alpha_rects:Dictionary={}

func persistent_obstacles()->Array:
	var result:Array=[]
	for slot in range(4 if game.rules.has_bonus() else 3):
		var state:=card_visual(slot)
		var frame:Texture2D=TRIAL if state.locked else (COMPLETE if state.complete else PENDING)
		var key:=frame.get_instance_id()
		if not card_alpha_rects.has(key):card_alpha_rects[key]=Rect2(frame.get_image().get_used_rect())
		var rect:=card_rect(slot);var native:Rect2=card_alpha_rects[key]
		var factor:=rect.size/Vector2(frame.get_size())
		# Protect all nonzero-alpha artwork. Transparent export padding is not UI.
		result.append(get_global_transform()*Rect2(rect.position+native.position*factor,native.size*factor))
	return result

func _ready() -> void:
	# Temporary existing frames; replaceable art can be bound without changing
	# receipt state, fill mapping, receiving anchors or independent status marks.
	for slot in 4:
		var target=Visual.new(); target.name="OrderTarget"+str(slot)
		target.scale=Vector2.ONE*TARGET_SCALE; add_child(target)
		Assets.tag(target,"order_bottle")
		target_bottles.append(target)
	card_foreground=Node2D.new(); card_foreground.name="OrderCardForeground"
	card_foreground.z_index=50; add_child(card_foreground)
	card_foreground.draw.connect(_draw_card_foreground)
	guide_pointer=preload("res://scripts/water_sort/tutorial_hand.gd").create_pointer(1080.0/390.0);guide_pointer.z_index=10;add_child(guide_pointer)

func use_delivered_layers() -> void:
	for target in target_bottles:
		target.use_delivered_layers(); target.delivered_layers.order_icon=true

func clear_states() -> void:
	slot_states.clear(); bursts.clear(); queue_redraw()

func slot_state(slot: int, stage: String, progress: float) -> void:
	slot_states[slot]={"stage":stage,"progress":progress}
	queue_redraw()
	if is_instance_valid(card_foreground): card_foreground.queue_redraw()

func receiving_anchor(slot: int) -> Vector2:
	return get_global_transform()*bag_center(slot)

func receiving_scale() -> Vector2:
	return get_global_transform().get_scale()*TARGET_SCALE

func full_ready(index: int) -> void:
	var node=game.bottle_nodes[index]
	var transform: Transform2D=get_global_transform().affine_inverse()*node.visual.get_global_transform()
	var body: Rect2=transform*node.visual.presentation_bounds()
	bursts.append({"point":body.get_center(),"body":body,"radii":Vector2(body.size.x*0.68,body.size.y*0.22),"color":node.visual.color_for(str(game.rules.bottles[index][0])),"age":0.0,"duration":FULL_FEEDBACK_DURATION,"local_ready":true,"bottle":index})

func card_visual(slot: int) -> Dictionary:
	var key: String=str(game.display_slots[slot]) if slot<game.display_slots.size() else ""
	var stage: String=str(slot_states.get(slot,{"stage":"idle"}).stage)
	var locked: bool=slot==3 and not game.rules.slot_unlocked
	return {"key":key,"stage":stage,"locked":locked,"complete":not locked and (stage=="check" or key.is_empty())}

func card_rect(slot: int) -> Rect2:
	return Layout.order_card(slot,4 if game.rules.has_bonus() else 3)

func _draw_card_foreground() -> void:
	if not is_instance_valid(game) or not game.rules is Orders: return
	for slot in range(4 if game.rules.has_bonus() else 3):
		var state:=card_visual(slot)
		var rect:=card_rect(slot)
		var frame: Texture2D=TRIAL if state.locked else (COMPLETE if state.complete else PENDING)
		# Only the genuine lower card lip occludes the arriving bottle. Old thin
		# lines/rings/checks are removed; badge follows actual check/exhaustion.
		var lip:=Rect2(rect.position+Vector2(0,190)*Layout.DESIGN_SCALE,Vector2(157,14)*Layout.DESIGN_SCALE)
		card_foreground.draw_texture_rect_region(frame,lip,Rect2(0,190,157,14))
		if state.complete:
			card_foreground.draw_texture_rect(BADGE,Rect2(rect.position+Vector2(102,8)*Layout.DESIGN_SCALE,Vector2(52,52)*Layout.DESIGN_SCALE),false)

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 35

func bag_center(slot: int) -> Vector2:
	return Layout.order_anchor(slot,4 if game.rules.has_bonus() else 3)

func advance(delta: float) -> void:
	clock += delta
	for particle_burst in bursts: particle_burst.age += delta
	bursts = bursts.filter(func(b): return b.age < float(b.get("duration",0.8)))
	queue_redraw()

func burst(at: Vector2, color: Color) -> void:
	bursts.append({"point":at,"color":color,"age":0.0})

func _text(at: Vector2, value: String, pixels: int, color: Color) -> void:
	var face:=Assets.font(game.locale)
	var width: float = face.get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,pixels).x
	draw_string(face,at-Vector2(width*0.5,0),value,HORIZONTAL_ALIGNMENT_LEFT,-1,pixels,color)

func mask_caption(index: int, remaining: int) -> String:
	var condition: Dictionary=game.rules.mask_progress(index,game.display_delivered.size())
	var color: String=str(condition.color)
	var names: Dictionary={"red":"红色","blue":"蓝色","green":"绿色","yellow":"黄色","orange":"橙色","purple":"紫色","pink":"粉色","cyan":"青色"}
	if condition.kind=="color":
		return game.t("再交付%s订单 × %d","Deliver %s × %d") % [names.get(color,color) if game.locale=="zh" else color,remaining]
	return game.t("再交付任意订单 × %d","Deliver any color × %d") % remaining

func tutorial_pointer_center(index: int) -> Vector2:
	var visual=game.bottle_nodes[index].visual
	var transform: Transform2D=get_global_transform().affine_inverse()*visual.get_global_transform()
	var body: Rect2=transform*visual.presentation_bounds()
	return body.get_center()

func _process(_delta: float) -> void:
	preload("res://scripts/ui_restore/gameplay_hint_layout.gd").update(game)
	if not is_instance_valid(guide_pointer): return
	var target: int=-1
	if is_instance_valid(game) and game.is_visible_in_tree() and game.state=="playing" and game.rules is Orders: target=game.tutorial_target()
	var phase: String="source" if target>=0 and game.selected<0 else "target"
	var key: String=phase+":"+str(target) if target>=0 and target<game.bottle_nodes.size() else ""
	if key==guide_key and (key.is_empty() or guide_pointer.visible): return
	guide_key=key
	if key.is_empty(): guide_pointer.stop_guide(); return
	guide_pointer.show_phase(phase,func():
		if not is_instance_valid(game) or not game.is_visible_in_tree() or game.state!="playing" or target>=game.bottle_nodes.size() or not is_instance_valid(game.bottle_nodes[target]): return null
		return tutorial_pointer_center(target))

func set_guide_reduced_motion(enabled: bool) -> void:
	if is_instance_valid(guide_pointer): guide_pointer.set_motion_preference(enabled)

func _draw() -> void:
	if not is_instance_valid(game) or not game.rules is Orders: return
	# Slot geometry can change when loading a level with assistance slots.
	# Refresh the separate foreground at the same coordinates as the card body.
	if is_instance_valid(card_foreground): card_foreground.queue_redraw()
	for i in range(4 if game.rules.has_bonus() else 3):
		var state:=card_visual(i)
		var center:=bag_center(i)
		var rect:=card_rect(i)
		var frame: Texture2D=TRIAL if state.locked else (COMPLETE if state.complete else PENDING)
		draw_texture_rect(frame,rect,false)
		var enter: float=float(slot_states.get(i,{"progress":1.0}).progress) if state.stage=="replace" else 1.0
		var order_icon=target_bottles[i]
		order_icon.visible=not state.locked and not state.key.is_empty()
		order_icon.position=center+Vector2(0,-12*(1.0-enter))
		order_icon.scale=Vector2.ONE*TARGET_SCALE
		order_icon.modulate=Color.WHITE
		if order_icon.visible and order_icon.layers!=[state.key,state.key,state.key,state.key]: order_icon.set_layers([state.key,state.key,state.key,state.key])
		if state.locked:
			var icon_size:=Vector2(80,56)*Layout.DESIGN_SCALE
			draw_texture_rect(VIDEO,Rect2(rect.get_center()-icon_size*0.5,icon_size),false)
	for i in range(4 if game.rules.has_bonus() else 3,4): target_bottles[i].hide()
	for item in bursts:
		_draw_ready_burst(item)

func _ready_orbit_point(body: Rect2, phase: float) -> Vector2:
	var angle:=phase*TAU*2.0
	return Vector2(body.get_center().x+cos(angle)*body.size.x*0.67,lerpf(body.end.y-6.0,body.position.y+body.size.y*0.20,phase)+sin(angle)*body.size.x*0.17)

func _draw_ready_burst(item: Dictionary) -> void:
	var t: float=clampf(item.age/float(item.get("duration",0.8)),0,1)
	var fade: float=smoothstep(0.0,0.08,t)*(1.0-smoothstep(0.72,1.0,t))
	var body: Rect2=item.get("body",Rect2(item.point-Vector2(35,70),Vector2(70,140)))
	var tint: Color=item.color.lightened(0.65)
	# A rising, bottle-local spiral with a short sparkling wake. It completes
	# while the glass stays still; receipt flight belongs to the next stage.
	for i in 96:
		var lag: float=float(i)/95.0
		var phase: float=t-lag*0.9
		if phase<0: continue
		var point:=_ready_orbit_point(body,phase)
		var alpha:=fade*(1.0-lag)
		var jitter:=Vector2(sin(i*12.9898)*body.size.x*0.26,cos(i*7.37)*body.size.y*0.055)*sqrt(lag)
		draw_circle(point+jitter,1.8+1.8*(1.0-lag),Color(tint,alpha),true,-1,true)
		draw_circle(point-jitter*0.7+Vector2(0,8.0*lag),1.4,Color(tint,alpha*0.65),true,-1,true)
		if i%9==0:
			var star:=PackedVector2Array()
			for tip in 8:
				var ray: float=float(tip)*TAU/8.0+t*2.0
				star.append(point+Vector2(cos(ray),sin(ray))*(7.0 if tip%2==0 else 2.0))
			draw_colored_polygon(star,Color(tint,alpha))
