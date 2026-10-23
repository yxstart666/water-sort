extends Control
signal level_start_requested(index: int)
signal level_completed(index: int, move_count: int, elapsed_seconds: float)
signal exit_requested
var embedded_mode := false
var locale := "zh"
var completion_reported := false
# Deliberately independent: no main, progress/energy stores, ads, rankings or cargo rules.
const Rules = preload("res://scripts/experiments/water_sort_v1/rules.gd")
const Bottle = preload("res://scripts/experiments/water_sort_v1/bottle.gd")
const Typography = preload("res://scripts/ui_restore/typography.gd")
const LEVEL_PATH := "res://data/experiments/water_sort_v1/levels.json"
var level_path := LEVEL_PATH
const PourAnimator = preload("res://scripts/water_sort/art/pour_animator.gd")
const POUR_SECONDS := 0.84
const NAVY := Color("142d48")
const CREAM := Color("fff1ce")
const GOLD := Color("d6b267")
var levels: Array = []
var level_index := 0
var rules
var moves := 0
var elapsed := 0.0
var history: Array = []
var selected := -1
var state := "intro" # intro / playing / paused / won / stuck / restart
var return_state := "playing"
var has_started := false
var pour_remaining := 0.0
var pour_from := -1
var pour_to := -1
var animator: Node2D
var suppress_animation_completion := false
var message_remaining := 0.0
var bottle_nodes: Array = []
var buttons: Dictionary = {}
var labels: Dictionary = {}
var overlay: Control
var board: Control
var face: Font
var last_clock_second := -1

func t(zh: String, en: String) -> String:
	return en if locale == "en" else zh

func set_locale(value: String) -> void:
	locale="en" if value=="en" else "zh"
	if not is_node_ready() or rules==null: return
	_settle_animation(true)
	# Rebuild only presentation; all puzzle/history/timing state remains untouched.
	var prior_state: String=state
	var prior_return: String=return_state
	for child in get_children(): remove_child(child); child.queue_free()
	bottle_nodes.clear(); buttons.clear(); labels.clear(); overlay=null
	message_remaining=0; _build_shell(); _build_bottles(); _refresh()
	match prior_state:
		"intro": show_instructions()
		"paused": state="playing"; pause_game()
		"restart": state=prior_return; request_restart()
		"won", "stuck": _result_overlay(prior_state=="won")

func _request_level(index: int) -> void:
	if embedded_mode: level_start_requested.emit(index)
	else: load_level(index)

func _return_entry() -> void:
	if not embedded_mode: show_instructions(); return
	prepare_to_leave()
	exit_requested.emit()

func _animation_busy() -> bool:
	return pour_remaining>0 or (is_instance_valid(animator) and animator.busy)

func _settle_animation(evaluate: bool=true) -> void:
	if not is_instance_valid(animator) or not animator.busy: return
	var previous: bool=suppress_animation_completion
	suppress_animation_completion=not evaluate
	animator.cancel(true) # Rules already committed; never roll visual inventory backwards.
	suppress_animation_completion=previous
	pour_remaining=0

func prepare_to_leave() -> void:
	_settle_animation(true)
	if state=="playing": pause_game()

func _on_pour_completed(committed: bool) -> void:
	pour_remaining=0
	if suppress_animation_completion or not is_inside_tree() or is_queued_for_deletion(): return
	var ancestor: Node=get_parent()
	while ancestor!=null:
		if ancestor.is_queued_for_deletion(): return
		ancestor=ancestor.get_parent()
	if is_instance_valid(animator) and is_instance_valid(animator.source) and not animator.source.is_inside_tree(): return
	if not committed: push_error("Committed game move cannot visually roll back")
	_finish_pour()

func _exit_tree() -> void:
	suppress_animation_completion=true
	_settle_animation(false)

func resume_game() -> void:
	if state=="intro": resume_from_instructions()
	elif state=="paused": state="playing"; _clear_overlay(); _refresh()

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	face = Typography.font("cjk_face0")
	var pack = JSON.parse_string(FileAccess.get_file_as_string(level_path))
	if not pack is Dictionary or not pack.get("levels") is Array or pack.levels.is_empty():
		push_error("Water sort prototype has no valid level pack")
		return
	levels = pack.levels
	_build_shell()
	load_level(0)
	show_instructions()
	if embedded_mode: print("WATER_SORT_VIEW_READY levels=",levels.size()," embedded=true")
	else: print("WATER_SORT_V1_READY levels=",levels.size()," memory_only=true energy=false")

func _style(fill: Color, edge: Color = GOLD, radius: int = 24) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color=fill; box.border_color=edge; box.set_border_width_all(3)
	box.set_corner_radius_all(radius)
	box.shadow_color=Color(0.02,0.06,0.12,0.3); box.shadow_size=5; box.shadow_offset=Vector2(0,5)
	return box

func _label(parent: Node, id: String, value: String, rect: Rect2, pixels: int=34, color: Color=CREAM) -> Label:
	var node := Label.new(); node.name=id; node.text=value
	node.position=rect.position; node.size=rect.size
	node.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	node.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	node.add_theme_font_override("font",face); node.add_theme_font_size_override("font_size",pixels)
	node.add_theme_color_override("font_color",color); node.mouse_filter=Control.MOUSE_FILTER_IGNORE
	parent.add_child(node); labels[id]=node
	return node

func _button(parent: Node, id: String, value: String, rect: Rect2, action: Callable, dark: bool=false) -> Button:
	var node := Button.new(); node.name=id; node.text=value; node.position=rect.position; node.size=rect.size
	node.add_theme_font_override("font",face); node.add_theme_font_size_override("font_size",34)
	var fill := Color("294863") if dark else CREAM
	var ink := CREAM if dark else NAVY
	for key in ["font_color","font_hover_color","font_pressed_color","font_focus_color"]: node.add_theme_color_override(key,ink)
	node.add_theme_color_override("font_disabled_color",Color("7d8c98"))
	node.add_theme_stylebox_override("normal",_style(fill))
	node.add_theme_stylebox_override("hover",_style(fill.lightened(0.07),Color("fff0be")))
	node.add_theme_stylebox_override("pressed",_style(fill.darkened(0.12)))
	node.add_theme_stylebox_override("disabled",_style(Color("364957"),Color("60727e")))
	node.add_theme_stylebox_override("focus",StyleBoxEmpty.new())
	node.mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
	node.pressed.connect(action); parent.add_child(node); buttons[id]=node
	return node

func _build_shell() -> void:
	_label(self,"Title",(t("Color Sort · 倒瓶子","Color Sort") if embedded_mode else t("倒瓶子 · 玩法测试版","Color Sort · Playtest")),Rect2(70,85,940,84),52)
	_label(self,"Prototype","",Rect2(70,176,940,52),28,Color("c5d6e3"))
	_button(self,"Instructions",(t("返回主页","Home") if embedded_mode else t("返回说明","Instructions")),Rect2(64,271,230,76),_return_entry,true)
	_label(self,"Level","",Rect2(320,260,440,92),38)
	_button(self,"Pause",t("暂停","Pause"),Rect2(816,271,200,76),pause_game,true)
	_label(self,"Stats","",Rect2(140,375,800,64),36)
	_label(self,"LevelName","",Rect2(100,176,880,60),32,Color("c5d6e3"))
	board=Control.new(); board.name="Bottles"; board.mouse_filter=Control.MOUSE_FILTER_IGNORE; add_child(board)
	animator=PourAnimator.new(); animator.name="PourAnimator"; animator.duration=POUR_SECONDS
	animator.z_index=20; board.add_child(animator); animator.set_process(false)
	animator.completed.connect(_on_pour_completed)
	_label(self,"Status","",Rect2(90,1420,900,100),34)
	_button(self,"Undo",t("撤销","Undo"),Rect2(94,1570,420,100),undo_move)
	_button(self,"Restart",t("重开本关","Restart"),Rect2(566,1570,420,100),request_restart)
	_label(self,"RuleHint",t("先点源瓶，再点空瓶或顶部同色的瓶子","Tap a source, then an empty or matching bottle."),Rect2(64,1712,952,60),30,Color("c5d6e3"))
	_label(self,"Footnote",(t("首批 5 关 · 本机保存","First 5 levels · Saved on this device") if embedded_mode else t("首批 5 关 · 玻璃瓶玩法测试 · 进度仅本次保存","5 levels · Glass-bottle playtest · This session only")),Rect2(64,1810,952,52),26,Color("8faabc"))

func load_level(index: int) -> void:
	if index < 0 or index >= levels.size(): return
	_settle_animation(false)
	level_index=index; rules=Rules.new(levels[index]); moves=0; elapsed=0.0; history.clear(); completion_reported=false
	selected=-1; pour_remaining=0; message_remaining=0; last_clock_second=-1; has_started=true; state="playing"
	_clear_overlay(); _build_bottles(); _refresh()

# Both rows are centered independently. The middle band handles lower pours;
# explicit transit lanes handle lower-to-upper plane changes, so equal rows do
# not need a permanent visual offset. Touch targets remain 50.7dp at 360dp width.
func _two_row_slot(total: int, index: int) -> Vector2:
	var upper_count := total / 2
	var upper := index < upper_count
	var row_count := upper_count if upper else total-upper_count
	var column := index if upper else index-upper_count
	var x := 540.0 + (float(column)-float(row_count-1)*0.5)*208.0
	# Equal rows are centered and aligned. Cross-row travel changes columns in
	# the open middle band instead of permanently skewing the resting layout.
	return Vector2(x,758.0 if upper else 1320.0)

func _build_bottles() -> void:
	for node in bottle_nodes: board.remove_child(node); node.queue_free()
	bottle_nodes.clear()
	var total: int=rules.bottles.size()
	var two_rows := total>=7
	animator.safe_row_route=total>=4
	animator.multi_row_route=two_rows
	animator.multi_row_ceiling_world_y=(board.get_global_transform()*Vector2(0,758)).y
	animator.row_clearance_local=40.0 if two_rows else 56.0
	animator.hover_clearance_local=417.0 if two_rows else 424.0
	animator.swept_row_clearance_local=29.0 if two_rows else 44.0
	# Use the existing bottom hint line for feedback, freeing the upper travel
	# band. Only the two-row action buttons move 30px down for lower-row space.
	labels.Status.position=Vector2(90,1712 if two_rows else 1420)
	labels.Status.size=Vector2(900,60 if two_rows else 100)
	labels.RuleHint.visible=not two_rows
	buttons.Undo.position.y=1600 if two_rows else 1570
	buttons.Restart.position.y=1600 if two_rows else 1570
	animator.multi_row_transit_lanes_world_x=PackedFloat32Array()
	if two_rows:
		var upper_count := total/2
		for column in upper_count+1:
			var lane_x := _two_row_slot(total,0).x-104.0+float(column)*208.0
			animator.multi_row_transit_lanes_world_x.append((board.get_global_transform()*Vector2(lane_x,0)).x)
	for i in range(total):
		var bottle_size:=Vector2(152,296) if two_rows else (Vector2(176,410) if total<=4 else Vector2(152,320))
		var spacing:=(205.0 if total==3 else 230.0) if total<=4 else (164.0 if total==6 else 176.0)
		var x: float=540.0-(float(total-1)*spacing+bottle_size.x)/2.0+i*spacing
		var y:=970.0 if total<=4 else 1060.0
		var node=Bottle.new(); node.name="Bottle"+str(i); node.index=i; node.capacity=rules.capacity
		if total==6 or two_rows: node.visual_scale_limit=0.68
		node.position=(_two_row_slot(total,i)-Vector2(bottle_size.x*0.5,22)) if two_rows else Vector2(x,y)
		node.size=bottle_size; node.set_meta("rest_position",node.position)
		node.chosen.connect(select_bottle); board.add_child(node); bottle_nodes.append(node)

func _sync_bottles(update_layers: bool=true) -> void:
	for i in range(bottle_nodes.size()):
		var node=bottle_nodes[i]
		if update_layers: node.layers=rules.bottles[i].duplicate()
		node.selected=i==selected
		node.locked=state!="playing" or _animation_busy()
		node.position=node.get_meta("rest_position")-Vector2(0,22 if node.selected else 0)
		node.rotation=0; node.queue_redraw()

func _refresh() -> void:
	labels.Level.text=t("第 %d / %d 关","Level %d / %d") % [level_index+1,levels.size()]
	labels.LevelName.text=str(levels[level_index].get("title","")) if locale=="zh" else ["Make an empty bottle","Reveal the colors below","Think before the biggest pour","Five-color relay","Keep a path open"][mini(level_index,4)]
	labels.Stats.text=t("%d 步     %02d:%02d","%d moves     %02d:%02d") % [moves,int(elapsed)/60,int(elapsed)%60]
	buttons.Undo.disabled=history.is_empty() or state!="playing" or _animation_busy()
	buttons.Restart.disabled=state!="playing"
	buttons.Pause.disabled=state!="playing"
	buttons.Instructions.disabled=state=="intro"
	if message_remaining<=0:
		labels.Status.text=t("请选择目标瓶","Choose a destination") if selected>=0 else t("把每种颜色分别装满一瓶","Fill each bottle with one color")
		labels.Status.add_theme_color_override("font_color",CREAM)
	if is_instance_valid(animator): animator.set_paused(state!="playing")
	_sync_bottles(); queue_redraw()

func select_bottle(index: int) -> void:
	if state!="playing" or _animation_busy() or index<0 or index>=bottle_nodes.size(): return
	if selected==index:
		selected=-1; _refresh(); return
	if selected<0:
		if rules.bottles[index].is_empty():
			_feedback(t("这是空瓶，先选有颜色的瓶子","Choose a bottle with liquid first"),index); return
		selected=index; message_remaining=0; _refresh(); return
	if not rules.can_pour(selected,index):
		_feedback(t("只能倒入空瓶或顶部同色、未满的瓶子","Use an empty or matching bottle with free space"),index); return
	var before: Dictionary=rules.snapshot()
	var source: int=selected
	var amount: int=rules.pour(source,index)
	if amount<=0: return
	history.append({"snapshot":before,"moves":moves})
	moves+=1; selected=-1; message_remaining=0
	pour_from=source; pour_to=index; pour_remaining=POUR_SECONDS
	_sync_bottles(false) # Remove selection lift before recording exact animator rest poses.
	# Start from the currently displayed before-state, preserving its cork for unsealing.
	# Refresh only after the animator claims both visuals, so committed layers cannot
	# flash a finished cork or erase a completed source cork before it is lifted.
	var accepted: bool=animator.play(bottle_nodes[source].visual,bottle_nodes[index].visual,before.bottles[source],before.bottles[index],rules.bottles[source],rules.bottles[index])
	_refresh()
	if not accepted:
		push_error("Pour visual rejected a committed legal move; settling to authoritative layers")
		_finish_pour()
	else:
		labels.Status.text=t("正在倒入 %d 层","Pouring %d layers") % amount

func _feedback(value: String, index: int=-1) -> void:
	labels.Status.text=value; labels.Status.add_theme_color_override("font_color",Color("ffb3a1")); message_remaining=1.8
	if index>=0: bottle_nodes[index].invalid_flash=0.3; bottle_nodes[index].queue_redraw()

func _process(delta: float) -> void:
	if rules==null: return
	if state=="playing":
		elapsed+=delta
		if int(elapsed)!=last_clock_second:
			last_clock_second=int(elapsed)
			labels.Stats.text=t("%d 步     %02d:%02d","%d moves     %02d:%02d") % [moves,int(elapsed)/60,int(elapsed)%60]
		if is_instance_valid(animator) and animator.busy:
			animator.set_paused(false)
			animator.advance(delta) # Exactly one owner advances the shared glass timeline.
			pour_remaining=(float(animator.remaining_seconds()) if animator.has_method("remaining_seconds") else maxf(0.0001,animator.duration-animator.elapsed)) if animator.busy else 0.0
		if message_remaining>0:
			message_remaining=maxf(0,message_remaining-delta)
			if message_remaining==0: _refresh()
	for node in bottle_nodes:
		if node.invalid_flash>0:
			node.invalid_flash=maxf(0,node.invalid_flash-delta); node.queue_redraw()

func _finish_pour() -> void:
	if is_instance_valid(animator) and animator.busy: return
	pour_remaining=0; _refresh()
	if rules.is_solved():
		state="won"; _result_overlay(true)
		if not completion_reported:
			completion_reported=true
			level_completed.emit(level_index,moves,elapsed)
	elif not _has_legal_move():
		state="stuck"; _result_overlay(false)

func _has_legal_move() -> bool:
	for source in range(rules.bottles.size()):
		for target in range(rules.bottles.size()):
			if rules.can_pour(source,target): return true
	return false

func undo_move() -> void:
	if history.is_empty() or _animation_busy() or state not in ["playing","stuck","won"]: return
	var prior: Dictionary=history.pop_back()
	rules.restore(prior.snapshot); moves=int(prior.moves); selected=-1; state="playing"; message_remaining=0
	# Undo reverses the move, not thinking time. No time exploit and no negative clock.
	_clear_overlay(); _refresh()

func _cancel_restart() -> void:
	state=return_state; _clear_overlay(); _refresh()
	if state in ["won","stuck"]: _result_overlay(state=="won")

func request_restart() -> void:
	_settle_animation(true)
	return_state=state; state="restart"; _refresh()
	_make_overlay(t("重开这一关？","Restart this level?"),t("瓶子和步数会重置，计时重新开始。","Bottles, moves and time will reset."))
	_button(overlay,"ConfirmRestart",t("确认重开","Restart level"),Rect2(170,1025,740,92),func(): _request_level(level_index))
	_button(overlay,"CancelRestart",t("继续当前局","Keep playing"),Rect2(170,1150,740,92),_cancel_restart,true)

func pause_game() -> void:
	if state!="playing": return
	state="paused"; _refresh(); _make_overlay(t("已暂停","Paused"),t("用时已暂停，返回后继续当前局。","The clock is paused. Your puzzle is unchanged."))
	_button(overlay,"Resume",t("继续游戏","Resume"),Rect2(170,1025,740,100),func(): state="playing"; _clear_overlay(); _refresh())
	_button(overlay,"PauseInstructions",t("查看说明","How to play"),Rect2(170,1160,740,92),show_instructions,true)

func show_instructions() -> void:
	if rules==null: return
	if state!="intro": return_state=state
	state="intro"; _refresh()
	_make_overlay(t("倒瓶子 · 玩法说明","How to play"),t("先点有颜色的源瓶，再点目标瓶。\n只能倒入空瓶或顶部同色的瓶子。\n顶端连续同色会一次倒入，直到目标满。\n把每种颜色装满各自的瓶子即可过关。\n\n可随时撤销、重开；说明与暂停不计时。","Tap a source bottle, then a destination.\nPour into empty bottles or matching top colors.\nThe top color pours together until the bottle fills.\nFill each bottle with just one color to win.\n\nUndo and restart are always available.\nInstructions and pause screens stop the clock."))
	labels.OverlayBody.position=Vector2(160,670); labels.OverlayBody.size=Vector2(760,500)
	labels.OverlayTitle.position=Vector2(160,570)
	_button(overlay,"Start",t("开始游戏","Start game") if moves==0 and elapsed<0.1 and level_index==0 else t("返回当前局","Back to game"),Rect2(170,1240,740,100),resume_from_instructions)

func resume_from_instructions() -> void:
	state=return_state
	if state in ["intro","paused","restart"]: state="playing"
	_clear_overlay(); _refresh()
	if state in ["won","stuck"]: _result_overlay(state=="won")

func next_level() -> void:
	if state!="won" or level_index+1>=levels.size(): return
	_request_level(level_index+1)

func _result_overlay(won: bool) -> void:
	_refresh()
	var final: bool=level_index+1==levels.size()
	var title: String=(t("5 关挑战完成","All 5 levels complete") if final else t("本关完成","Level complete")) if won else t("暂时无路可走","No moves left")
	var body: String=(t("%d 步 · 用时 %02d:%02d\n%s","%d moves · %02d:%02d\n%s") % [moves,int(elapsed)/60,int(elapsed)%60,t("已完成当前全部关卡。","You finished all current levels.") if final else t("所有颜色已各自归位。","Every color is in its own bottle.")] ) if won else t("当前没有合法倒法。\n撤销上一步，或重新试试。","There are no legal pours.\nUndo a move or try again.")
	_make_overlay(title,body)
	if won and not final:
		_button(overlay,"Next",t("下一关","Next level"),Rect2(170,1025,740,100),next_level)
	elif won:
		_button(overlay,"ReplayAll",t("从第 1 关再玩","Play again from level 1"),Rect2(170,1025,740,100),func(): _request_level(0))
	else:
		_button(overlay,"BlockedUndo",t("撤销上一步","Undo last move"),Rect2(170,1025,740,100),undo_move).disabled=history.is_empty()
	_button(overlay,"ResultRestart",t("重玩本关","Replay level"),Rect2(170,1160,350,92),func(): _request_level(level_index),true)
	_button(overlay,"ResultInstructions",(t("返回主页","Home") if embedded_mode else t("返回说明","Instructions")),Rect2(560,1160,350,92),_return_entry,true)

func _clear_overlay() -> void:
	if is_instance_valid(overlay):
		remove_child(overlay); overlay.queue_free()
	overlay=null
	for id in ["Start","ConfirmRestart","CancelRestart","Resume","PauseInstructions","Next","ReplayAll","BlockedUndo","ResultRestart","ResultInstructions"]: buttons.erase(id)

func _make_overlay(title: String, body: String) -> void:
	_clear_overlay()
	overlay=Control.new(); overlay.name="Overlay"; overlay.size=Vector2(1080,1920); overlay.z_index=100; overlay.mouse_filter=Control.MOUSE_FILTER_STOP
	add_child(overlay)
	var shade:=ColorRect.new(); shade.color=Color(0.02,0.06,0.12,0.72); shade.size=overlay.size; shade.mouse_filter=Control.MOUSE_FILTER_IGNORE; overlay.add_child(shade)
	var panel:=Panel.new(); panel.position=Vector2(110,520); panel.size=Vector2(860,870); panel.add_theme_stylebox_override("panel",_style(CREAM,GOLD,36)); panel.mouse_filter=Control.MOUSE_FILTER_IGNORE; overlay.add_child(panel)
	_label(overlay,"OverlayTitle",title,Rect2(160,620,760,100),48,NAVY)
	_label(overlay,"OverlayBody",body,Rect2(160,755,760,210),32,NAVY)

func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if state=="playing": pause_game()
		elif state=="paused": state="playing"; _clear_overlay(); _refresh()
		elif state=="intro": resume_from_instructions()
		get_viewport().set_input_as_handled()

func _notification(what: int) -> void:
	if what==NOTIFICATION_APPLICATION_FOCUS_OUT and is_inside_tree() and state=="playing":
		# Notifications may arrive while Godot is traversing children. Do not add
		# the pause overlay until that traversal has completed. pause_game retains
		# its state guard, so queued duplicates cannot create multiple overlays.
		pause_game.call_deferred()

func _draw() -> void:
	draw_rect(Rect2(0,0,1080,1920),NAVY)
	draw_circle(Vector2(1080,560),460,Color("193651"))
	draw_circle(Vector2(-180,1550),620,Color("18344f"))
	draw_line(Vector2(90,245),Vector2(990,245),Color("806f50"),2,true)
	draw_line(Vector2(90,1778),Vector2(990,1778),Color("52687a"),2,true)
