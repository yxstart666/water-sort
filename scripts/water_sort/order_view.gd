extends "res://scripts/water_sort/campaign_view.gd"
const Orders = preload("res://scripts/water_sort/order_rules.gd")
const Hud = preload("res://scripts/water_sort/order_hud.gd")
const RewardGate = preload("res://scripts/water_sort/reward_gate.gd")
const PauseDialog = preload("res://scripts/water_sort/pause_dialog.gd")
const ActionDialog = preload("res://scripts/water_sort/order_action_dialog.gd")
const Presentation = preload("res://scripts/water_sort/order_presentation.gd")
const GameplayLayout = preload("res://scripts/water_sort/order_gameplay_layout.gd")
const GameplayAssets = preload("res://scripts/water_sort/order_gameplay_assets.gd")
const BackgroundTexture = preload("res://art/reference2-delivery-20261024/reference2_background_cleanplate_v1/assets/background_native_940x1672.png")
signal preference_changed(key: String, value: Variant)
signal tactile_requested
signal level_select_requested
signal reward_requested(placement: String)
signal reward_cancel_requested
signal reward_context_changed
var pause_preferences := {"locale":"zh", "music":true, "sound":true, "vibration":true}
var hud
var display_slots: Array = []
var display_delivered: Array = []
var deliveries: Array = []
var flight_time := 0.0
var flight_visual
var flight_home := Vector2.ZERO
var flight_scale := Vector2.ONE
var reward_gate = RewardGate.new()
var reward_request := -1
var mechanism_seen: Callable
var mechanism_acknowledge: Callable
var reward_capability: Callable
var mask_hint_text:=""
var pending_full_bottle := -1
var transactions: Array=[]
var receipts: Array=[]
var presentation
var first_move_guide=preload("res://scripts/water_sort/first_move_guide.gd").new()
# Fixed reference2 native layers are opt-in for this order page only.
# False retains the original renderer as a local fallback without changing rules.
var use_delivered_bottle_art := true
var minimum_bottle_touch_world:=GameplayLayout.MIN_TOUCH
const FLIGHT_SECONDS := Presentation.FLIGHT

func _init() -> void:
	level_path = str(Catalog.configuration(Catalog.V3).level_path)

func set_pause_preferences(values: Dictionary) -> void:
	for key in pause_preferences: pause_preferences[key]=values.get(key,pause_preferences[key])
	if overlay is PauseDialog:
		overlay.configure(pause_preferences); buttons.Resume=overlay.buttons.resume

func pause_game() -> void:
	if state!="playing": return
	presentation.clear_inputs(false)
	state="paused"; _refresh(); _show_pause()

func _show_pause() -> void:
	_clear_overlay()
	var dialog := PauseDialog.new()
	dialog.size=Vector2(1080,1920); dialog.z_index=100
	pause_preferences.locale=locale; dialog.configure(pause_preferences)
	dialog.resume.connect(resume_game)
	dialog.restart_requested.connect(request_restart)
	dialog.level_select_requested.connect(func(): level_select_requested.emit())
	dialog.preference_changed.connect(func(key, value): preference_changed.emit(key,value))
	dialog.ui_clicked.connect(func(): tactile_requested.emit())
	overlay=dialog; add_child(dialog)
	dialog.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	buttons.Resume=dialog.buttons.resume

func _cancel_restart() -> void:
	super._cancel_restart()
	if state=="paused": _show_pause()

func request_restart() -> void:
	if state!="paused": super.request_restart(); return
	# Keep the committed transaction frozen until confirmation, including on cancel.
	return_state=state; state="restart"; _refresh()
	_make_overlay(t("重开这一关？","Restart this level?"),t("瓶子和步数会重置，计时重新开始。","Bottles, moves and time will reset."))
	_button(overlay,"ConfirmRestart",t("确认重开","Restart level"),Rect2(170,1025,740,92),func(): _request_level(level_index))
	_button(overlay,"CancelRestart",t("继续当前局","Keep playing"),Rect2(170,1150,740,92),_cancel_restart,true)

func set_locale(value: String) -> void:
	# Localizing an open pause must not settle an in-flight pour/cork/delivery.
	if is_node_ready() and state=="paused" and overlay is PauseDialog:
		locale="en" if value=="en" else "zh"
		pause_preferences.locale=locale
		labels.Title.text=t("彩瓶时光 · 颜色订单","Color Pause · Orders")
		for key in ["Instructions","Pause","Undo","Restart","BonusBottle"]:
			if not buttons.has(key) or not is_instance_valid(buttons[key]): continue
			match key:
				"Instructions": buttons[key].text=t("返回主页","Home") if embedded_mode else t("返回说明","Instructions")
				"Pause": buttons[key].text=t("暂停","Pause")
				"Undo": buttons[key].text=t("撤回","Undo")
				"Restart": buttons[key].text=t("重玩","Restart")
				"BonusBottle": buttons[key].text=""
		message_remaining=0; _refresh(); overlay.configure(pause_preferences)
		return
	super.set_locale(value)

func _build_shell() -> void:
	super._build_shell()
	if presentation==null: presentation=Presentation.new(self)
	buttons.Instructions.hide() # Home is available from the approved pause menu.
	for key in ["Title","Prototype","LevelName","RuleHint","Footnote"]: labels[key].hide()
	_place_control(labels.Level,GameplayLayout.SLOTS.level)
	labels.Level.add_theme_font_size_override("font_size",48)
	_place_control(labels.Stats,GameplayLayout.SLOTS.stats)
	labels.Stats.add_theme_font_size_override("font_size",32)
	_label(self,"DeliveryCount","",GameplayLayout.SLOTS.count,32)
	_label(self,"Guide","",GameplayLayout.SLOTS.guide,30)
	labels.Guide.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	_place_control(labels.Status,GameplayLayout.SLOTS.guide)
	labels.Status.add_theme_font_size_override("font_size",30)
	labels.Status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	for binding in [["Pause","pause"],["Undo","undo"],["Restart","restart"]]:
		var button: Button=buttons[binding[0]]
		_place_control(button,GameplayLayout.SLOTS[binding[1]])
		_style_gameplay_button(button)
		GameplayAssets.tag(button,binding[1])
	_build_reference2_chrome()
	GameplayAssets.tag(labels.Level,"level_plate")
	GameplayAssets.tag(labels.Stats,"stats_plate")
	GameplayAssets.tag(labels.DeliveryCount,"delivery_counter")
	hud=Hud.new(); hud.name="OrderBags"; hud.game=self; add_child(hud)
	GameplayAssets.tag(hud,"order_card")

func _build_reference2_chrome() -> void:
	for id in ["title","completion"]:
		var art:=GameplayAssets.image(self,id); art.z_index=0
	for id in ["Level","DeliveryCount","Guide","Status"]: labels[id].z_index=1
	GameplayAssets.text_style(labels.Level,locale,38,Color("081d50"))
	GameplayAssets.text_style(labels.DeliveryCount,locale,int(GameplayLayout.element("completion_value").font_px))
	GameplayAssets.text_style(labels.Guide,locale,22)
	GameplayAssets.text_style(labels.Status,locale,22)
	labels.Stats.hide()
	for item in [["StepValue",Rect2(337,147,114,58)],["TimeValue",Rect2(546,147,126,58)]]:
		var label:=_label(self,item[0],"",GameplayLayout.design_rect(item[1]),32)
		GameplayAssets.text_style(label,locale,32); label.z_index=1; label.hide()
	GameplayAssets.skin_button(buttons.Pause,"settings","settings_icon","",locale)
	GameplayAssets.skin_button(buttons.Undo,"undo","undo_icon","undo_label",locale)
	GameplayAssets.skin_button(buttons.Restart,"replay","replay_icon","replay_label",locale)
	# Independent approved transparent icons; both buttons retain their own hits.
	var refresh = _button(self,"RefreshColors",t("刷新颜色","Refresh colors"),GameplayLayout.SLOTS.undo,request_color_shuffle)
	_style_gameplay_button(refresh)
	GameplayAssets.skin_button(refresh,"undo","undo_icon","undo_label",locale)
	for spec in [[refresh,"refresh_curved_arrows.png"],[buttons.Undo,"undo_curved_arrow.png"]]:
		var button: Button=spec[0]; button.get_node("Reference2_undo_icon").hide()
		var icon:=TextureRect.new(); icon.name="ApprovedToolIcon"
		icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE; icon.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture=preload("res://scripts/ui_restore/refresh_palette_art.gd").SMALL if button==refresh else load("res://assets/p3_ui/"+str(spec[1])); icon.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		icon.position=button.size*Vector2(.18,.05); icon.size=button.size*Vector2(.64,.62)
		icon.mouse_filter=Control.MOUSE_FILTER_IGNORE; button.add_child(icon)
		var caption: Label=button.get_node("Reference2Caption")
		caption.set_meta("tool_caption",true)
		caption.add_theme_font_size_override("font_size",roundi(26*GameplayLayout.DESIGN_SCALE))
		GameplayAssets.fit_tool_caption(button)
	_place_control(buttons.Undo,GameplayLayout.SLOTS.restart)

func _update_reference2_values() -> void:
	if labels.has("StepValue"):
		labels.StepValue.text=t("%d步","%d") % moves
		labels.TimeValue.text="%02d:%02d" % [int(elapsed)/60,int(elapsed)%60]
		# Long counters fit within their own authored pill, never over its icon.
		for id in ["StepValue","TimeValue"]:
			var label: Label=labels[id]
			var pixels:=32
			while pixels>24 and label.get_theme_font("font").get_string_size(label.text,HORIZONTAL_ALIGNMENT_LEFT,-1,roundi(pixels*GameplayLayout.DESIGN_SCALE)).x>label.size.x: pixels-=1
			GameplayAssets.text_style(label,locale,pixels)
	for id in ["Pause","Undo","Restart","RefreshColors"]:
		if buttons.has(id): GameplayAssets.update_button(buttons[id],locale)

func build_gameplay_energy_badge(parent: Control) -> Label:
	GameplayAssets.image(parent,"energy"); GameplayAssets.image(parent,"energy_icon")
	var value:=Label.new(); value.name="EnergyAmount"
	var area:=GameplayLayout.design_rect(Rect2(114,74.5,118,58))
	value.position=area.position; value.size=area.size
	value.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; value.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	value.mouse_filter=Control.MOUSE_FILTER_IGNORE
	GameplayAssets.text_style(value,locale,35); parent.add_child(value)
	var ui=preload("res://scripts/water_sort/reference2_ui.gd")
	ui.picture(parent,"EnergyAdd",GameplayAssets.FINISH+"plus_gold.png",GameplayLayout.design_rect(Rect2(231,83.5,40,40)))
	return value

func _place_control(control: Control, rect: Rect2) -> void:
	control.position=rect.position; control.size=rect.size

func _style_gameplay_button(button: Button) -> void:
	for state_name in ["normal","hover","pressed","disabled","focus"]:
		var style:=StyleBoxTexture.new()
		style.texture=preload("res://art/reference2-delivery-20261024/reference2_replay_settings_buttons_v1/assets/replay_button_blank.png")
		for edge in 4: style.set_texture_margin(edge,48); style.set_content_margin(edge,0)
		style.modulate_color=Color(0.48,0.53,0.61,0.8) if state_name=="disabled" else (Color(0.82,0.82,0.82) if state_name=="pressed" else Color.WHITE)
		button.add_theme_stylebox_override(state_name,style)
	for key in ["font_color","font_hover_color","font_pressed_color","font_focus_color"]:
		button.add_theme_color_override(key,CREAM)
	button.add_theme_font_size_override("font_size",32)

func gameplay_energy_hit_rect() -> Rect2:
	return GameplayLayout.SLOTS.energy

func _draw() -> void:
	if preload("res://scripts/ui_restore/screen_layout.gd").policy(self)!=null:return
	draw_rect(Rect2(Vector2.ZERO,GameplayLayout.CANVAS),NAVY)
	draw_texture_rect(BackgroundTexture,GameplayLayout.design_rect(Rect2(Vector2.ZERO,GameplayLayout.DESIGN)),false)

func load_level(index: int) -> void:
	if index<0 or index>=levels.size(): return
	reward_context_changed.emit()
	_settle_animation(false); cancel_completion(); reward_gate.cancel()
	level_index=index; rules=Orders.new(levels[index]); moves=0; elapsed=0; history.clear()
	completion_reported=false; selected=-1; pour_remaining=0; message_remaining=0; last_clock_second=-1
	has_started=true; state="playing"; reward_gate=RewardGate.new()
	display_delivered=[]; display_slots=rules.slots(); deliveries.clear()
	_clear_overlay(); _build_bottles(); _refresh()
	_show_new_mechanisms()

func _show_new_mechanisms() -> void:
	if not mechanism_seen.is_valid() or not mechanism_acknowledge.is_valid(): return
	var items: Array=[]
	if not rules.level.get("masks",[]).is_empty() and not mechanism_seen.call("covered_lock_v1"):
		var mask: Dictionary=rules.level.masks[0]
		var condition: Dictionary=rules.condition_progress(mask)
		var covered_layers:Array=rules.bottles[int(mask.bottle)].duplicate()
		var text: String=hud.mask_caption(int(mask.bottle),int(condition.remaining))
		text+=t("\n解锁前不能选中、倒入或倒出。","\nLocked bottles cannot receive or pour.")
		var illustration:=func():
			var art=preload("res://scripts/water_sort/cover_intro_art.gd").new()
			art.color=str(condition.color) if condition.kind=="color" else "green"
			art.condition=condition.duplicate(); art.locale=locale
			art.covered_demo_layers=covered_layers.duplicate()
			return art
		items.append({"id":"covered_lock_v1","body":text,"illustration":illustration})
	var any_item:Dictionary=preload("res://scripts/water_sort/any_order_intro.gd").pending(rules,locale,mechanism_seen)
	if not any_item.is_empty():items.append(any_item)
	if not rules.level.get("unknown_layers",[]).is_empty() and not mechanism_seen.call("unknown_layers_v1"):
		var hidden_count:int=rules.level.unknown_layers[0].layers.size()
		var demo_layers:Array=rules.bottles[int(rules.level.unknown_layers[0].bottle)].duplicate()
		var illustration:=func():
			var art=preload("res://scripts/water_sort/cover_intro_art.gd").new(); art.unknown_demo=true;art.unknown_demo_count=hidden_count;art.unknown_demo_layers=demo_layers;return art
		items.append({"id":"unknown_layers_v1","body":t("问号从瓶底连续排列，从上往下逐层揭开。\n移走覆盖层，只揭开紧接着的一层。瓶子可正常使用。","Hidden layers start at the bottom. Reveal them top to bottom.\nRemove the covering liquid to reveal one layer. The bottle stays usable."),"illustration":illustration})
	if items.is_empty(): return
	var intro=preload("res://scripts/water_sort/mechanism_intro.gd").new()
	intro.locale=locale; intro.items=items
	intro.acknowledge=mechanism_acknowledge
	intro.finished.connect(func(): state="playing"; overlay=null; _refresh())
	_clear_overlay(); state="mechanism_intro"; overlay=intro; add_child(intro); _refresh()

func _build_bottles() -> void:
	super._build_bottles()
	if not rules is Orders: return
	# Window event coordinates, not source design pixels or a guessed DPR.
	# Freeze one profile for this board so route-lane queries share its centers.
	var window_tx:Transform2D=get_window().get_final_transform()*board.get_global_transform_with_canvas()
	minimum_bottle_touch_world=maxf(GameplayLayout.MIN_TOUCH,preload("res://scripts/ui_restore/touch_units.gd").minimum_window_pixels()/maxf(.0001,window_tx.x.length()))
	var total: int=rules.bottles.size()
	var rows := GameplayLayout.two_rows(total)
	for i in bottle_nodes.size():
		var node=bottle_nodes[i]
		node.selection_outline=false
		if use_delivered_bottle_art: node.visual.use_delivered_layers()
		if rules.mask_remaining(i)>0:
			var cover=preload("res://scripts/water_sort/art/bottle_cover.gd").new()
			node.visual.add_child(cover)
		var slot: Dictionary=GameplayLayout.bottle_slot(total,i,minimum_bottle_touch_world)
		_place_control(node,slot.hit)
		var actual: Rect2
		if use_delivered_bottle_art:
			# Uniform native-canvas mapping: transparent source margins do not
			# enlarge the glass when fitting its used-alpha rectangle.
			var contract: Dictionary=GameplayAssets.BOTTLE_CONTRACT
			var factor: float=slot.art.size.x/(contract.canvas.x*contract.normalization)
			node.visual.scale=Vector2.ONE*factor
			node.visual.position=slot.art.position-node.position+contract.mouth*contract.normalization*factor
			actual=Rect2(node.position+node.visual.position+node.visual.presentation_bounds().position*factor,node.visual.presentation_bounds().size*factor)
		else: actual=GameplayLayout.place_art(node.visual,node.visual.presentation_bounds(),slot.art,node.position)
		node.set_meta("rest_position",node.position); node.set_meta("art_rect",actual)
		GameplayAssets.tag(node,"bottle")
	if use_delivered_bottle_art and is_instance_valid(hud): hud.use_delivered_layers()
	animator.multi_row_route=rows
	animator.route_canvas_world_rect=board.get_global_transform()*Rect2(Vector2.ZERO,GameplayLayout.CANVAS)
	# Actual order cards are individual persistent obstacles. The header is still
	# protected; noninteractive completion/guide chrome yields during motion.
	animator.upper_route_floor_world_y=(board.get_global_transform()*Vector2(0,240)).y
	animator.multi_row_ceiling_world_y=bottle_nodes[0].visual.mouth_world().y
	animator.multi_row_transit_lanes_world_x=PackedFloat32Array()
	if rows:
		var count: int=GameplayLayout.configuration(total).columns
		var spacing: float=GameplayLayout.bottle_slot(total,0,minimum_bottle_touch_world).pitch
		for column in count+1:
			animator.multi_row_transit_lanes_world_x.append((board.get_global_transform()*Vector2(540-count*spacing*0.5+column*spacing,0)).x)
	_place_control(buttons.Undo,GameplayLayout.SLOTS.restart)
	_place_control(buttons.Restart,GameplayLayout.SLOTS.restart)
	_place_control(buttons.RefreshColors,GameplayLayout.SLOTS.undo)
	_place_control(labels.Status,GameplayLayout.SLOTS.guide)
	labels.RuleHint.hide(); labels.Footnote.hide()
	if buttons.has("BonusBottle") and is_instance_valid(buttons.BonusBottle): buttons.BonusBottle.queue_free()
	if buttons.has("BonusSlot") and is_instance_valid(buttons.BonusSlot): buttons.BonusSlot.queue_free()
	if rules.has_bonus():
		var b=_button(self,"BonusBottle","",GameplayLayout.bonus_button(GameplayLayout.bottle_slot(total,rules.bonus_index(),minimum_bottle_touch_world)),func(): open_reward("bottle"),true)
		for state_name in ["normal","hover","pressed","disabled","focus"]: b.add_theme_stylebox_override(state_name,StyleBoxEmpty.new())
		# Preserve the original hit target; art follows the full alpha128 glass.
		var bonus_visual=bottle_nodes[rules.bonus_index()].visual
		var contract:Dictionary=GameplayAssets.BOTTLE_CONTRACT
		var native_glass:=Rect2((Vector2(19,11)-contract.mouth)*contract.normalization,Vector2(128,387)*contract.normalization)
		var bottle_in_button:Rect2=b.get_global_transform().affine_inverse()*bonus_visual.get_global_transform()*native_glass
		var visible_width:=bottle_in_button.size.x*.60
		var visible_size:=Vector2(visible_width,visible_width*899.0/962.0)
		var visible_center:=bottle_in_button.position+bottle_in_button.size*Vector2(.5,.52)
		var badge=preload("res://scripts/water_sort/art/approved_play_badge.gd").new()
		badge.name="VideoAd";badge.visible_box=Rect2(visible_center-visible_size*.5,visible_size)
		b.add_child(badge);badge.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		GameplayAssets.tag(b,"trial_bottle")
		b.add_theme_font_size_override("font_size",28)
		b.z_index=40
		var slot=_button(self,"BonusSlot","",GameplayLayout.order_card(3,4),func(): open_reward("slot"),true)
		for key in ["normal","hover","pressed","focus","disabled"]: slot.add_theme_stylebox_override(key,StyleBoxEmpty.new())
		slot.z_index=40

func refresh_bottle_layout_if_idle() -> bool:
	if not rules is Orders or state not in ["playing","stuck"] or not is_instance_valid(board):return false
	var tx:Transform2D=get_window().get_final_transform()*board.get_global_transform_with_canvas()
	var desired:=maxf(GameplayLayout.MIN_TOUCH,preload("res://scripts/ui_restore/touch_units.gd").minimum_window_pixels()/maxf(.0001,tx.x.length()))
	if is_equal_approx(desired,minimum_bottle_touch_world):return false
	# Keep every transaction/queued intent bound to the same object and pose.
	# A held pointer or selected bottle also owns its current geometry until release.
	if _animation_busy() or selected>=0 or Input.is_anything_pressed():return false
	if presentation==null or not presentation.input_queue.is_empty() or presentation.queued_source_id!=0 or presentation.undo_pending:return false
	for node in bottle_nodes:
		if node.visual.transaction_busy or node.visual.seal_animating:return false
	minimum_bottle_touch_world=desired
	var total:int=rules.bottles.size()
	var rows:=GameplayLayout.two_rows(total)
	for i in bottle_nodes.size():
		var node=bottle_nodes[i]
		var slot: Dictionary=GameplayLayout.bottle_slot(total,i,minimum_bottle_touch_world)
		_place_control(node,slot.hit)
		var actual: Rect2
		if use_delivered_bottle_art:
			# Uniform native-canvas mapping: transparent source margins do not
			# enlarge the glass when fitting its used-alpha rectangle.
			var contract: Dictionary=GameplayAssets.BOTTLE_CONTRACT
			var factor: float=slot.art.size.x/(contract.canvas.x*contract.normalization)
			node.visual.scale=Vector2.ONE*factor
			node.visual.position=slot.art.position-node.position+contract.mouth*contract.normalization*factor
			actual=Rect2(node.position+node.visual.position+node.visual.presentation_bounds().position*factor,node.visual.presentation_bounds().size*factor)
		else: actual=GameplayLayout.place_art(node.visual,node.visual.presentation_bounds(),slot.art,node.position)
		node.set_meta("rest_position",node.position); node.set_meta("art_rect",actual)
		GameplayAssets.tag(node,"bottle")
	animator.multi_row_route=rows
	animator.route_canvas_world_rect=board.get_global_transform()*Rect2(Vector2.ZERO,GameplayLayout.CANVAS)
	# Actual order cards are individual persistent obstacles. The header is still
	# protected; noninteractive completion/guide chrome yields during motion.
	animator.upper_route_floor_world_y=(board.get_global_transform()*Vector2(0,240)).y
	animator.multi_row_ceiling_world_y=bottle_nodes[0].visual.mouth_world().y
	animator.multi_row_transit_lanes_world_x=PackedFloat32Array()
	if rows:
		var count: int=GameplayLayout.configuration(total).columns
		var spacing: float=GameplayLayout.bottle_slot(total,0,minimum_bottle_touch_world).pitch
		for column in count+1:
			animator.multi_row_transit_lanes_world_x.append((board.get_global_transform()*Vector2(540-count*spacing*0.5+column*spacing,0)).x)
	if rules.has_bonus() and buttons.has("BonusBottle") and is_instance_valid(buttons.BonusBottle):
		var b:Button=buttons.BonusBottle
		_place_control(b,GameplayLayout.bonus_button(GameplayLayout.bottle_slot(total,rules.bonus_index(),minimum_bottle_touch_world)))
		var badge=b.get_node_or_null("VideoAd")
		if is_instance_valid(badge):
			var contract:Dictionary=GameplayAssets.BOTTLE_CONTRACT
			var glass:=Rect2((Vector2(19,11)-contract.mouth)*contract.normalization,Vector2(128,387)*contract.normalization)
			var relative:Rect2=b.get_global_transform().affine_inverse()*bottle_nodes[rules.bonus_index()].visual.get_global_transform()*glass
			var width:=relative.size.x*.60
			var extent:=Vector2(width,width*899.0/962.0)
			badge.visible_box=Rect2(relative.position+relative.size*Vector2(.5,.52)-extent*.5,extent);badge.queue_redraw()
	return true

func _sync_bottles(update_layers: bool=true) -> void:
	if rules is Orders and presentation!=null: presentation.sync(update_layers)
	else: super._sync_bottles(update_layers)

func _refresh_campaign_copy() -> void:
	# Order guide replaces classic per-level sorting hints.
	if not rules is Orders or not labels.has("Guide"): return
	if presentation!=null and state!="playing": presentation.clear_inputs(false)
	if buttons.has("Undo"): buttons.Undo.disabled=history.is_empty() or state not in ["playing","stuck"] or completion_reported
	var available := reward_capability.is_valid() and bool(reward_capability.call())
	for id in ["Undo","RefreshColors"]:
		if buttons.has(id): buttons[id].visible = available
	if buttons.has("RefreshColors"):
		buttons.RefreshColors.disabled = state not in ["playing","stuck"] or completion_reported or _animation_busy() or not presentation.input_queue.is_empty()
	# Restart remains in the pause dialog; no duplicate gameplay-page entry.
	if buttons.has("Restart"):
		buttons.Restart.hide();buttons.Restart.disabled=true
		buttons.Restart.mouse_filter=Control.MOUSE_FILTER_IGNORE;buttons.Restart.focus_mode=Control.FOCUS_NONE
	labels.LevelName.hide(); labels.RuleHint.hide(); labels.Footnote.hide()
	labels.Level.text=t("第 %d 关","Level %d") % (level_index+1)
	var remaining: int=rules.level.orders.size()-display_delivered.size()
	var copy: String=t("装满同色瓶，完成上方全部订单","Fill matching bottles. Deliver every order.")
	if tutorial_target()>=0:
		# Metadata may point at any top color and the first pour need not fill a
		# bottle. Copy follows the real guided action, never a sample board.
		copy=t("① 点击发亮的源瓶","1. Tap the highlighted source") if selected<0 else t("② 再点发亮的目标瓶","2. Tap the highlighted target")
	elif level_index==0 and display_delivered.size()<=1:
		copy=t("同色才能合并，也可以倒进空瓶周转","Match the top color, or pour into an empty bottle")
	elif moves==0 and rules.level.has("unknown_start_hint"):
		copy=str(rules.level.unknown_start_hint.get(locale,""))
	if not deliveries.is_empty(): copy=t("满瓶自动送入同色订单卡","Full bottles fly into matching order cards")
	elif remaining==1: copy=t("还差最后 1 个订单，加油！","One last order to deliver!")
	labels.Guide.text=copy
	labels.DeliveryCount.text=t("已完成 %d / %d","Delivered %d / %d") % [display_delivered.size(),rules.level.orders.size()]
	# Restore the delivered counter typography, fitting only unusually long values.
	var counter_pixels: int=int(GameplayLayout.element("completion_value").font_px)
	var counter_font: Font=GameplayAssets.font(locale)
	while counter_pixels>22 and counter_font.get_string_size(labels.DeliveryCount.text,HORIZONTAL_ALIGNMENT_LEFT,-1,roundi(counter_pixels*GameplayLayout.DESIGN_SCALE)).x>labels.DeliveryCount.size.x:
		counter_pixels-=1
	GameplayAssets.text_style(labels.DeliveryCount,locale,counter_pixels)
	labels.Status.visible=message_remaining>0 or (selected>=0 and not (level_index==0 and moves==0))
	labels.Guide.visible=not labels.Status.visible
	var readable_mask_hint: bool=message_remaining>0 and not mask_hint_text.is_empty() and labels.Status.text==mask_hint_text
	_place_control(labels.Status,Rect2(42,552,996,60) if readable_mask_hint else GameplayLayout.SLOTS.guide)
	labels.Status.add_theme_font_size_override("font_size",36 if readable_mask_hint else 22)
	if buttons.has("BonusBottle") and is_instance_valid(buttons.BonusBottle):
		buttons.BonusBottle.visible=not rules.bonus_unlocked
		buttons.BonusBottle.disabled=state!="playing"
	if buttons.has("BonusSlot") and is_instance_valid(buttons.BonusSlot):
		buttons.BonusSlot.visible=not rules.slot_unlocked
		buttons.BonusSlot.disabled=state!="playing"
	if is_instance_valid(hud): hud.queue_redraw()
	_update_reference2_values()
	_sync_motion_hud()

func _sync_motion_hud() -> void:
	if not labels.has("DeliveryCount"):return
	var occupied:=not transactions.is_empty() or not receipts.is_empty()
	# Derive one shared visibility state; one completed source cannot reveal the
	# strip while a second source is still moving. Pausing freezes occupancy.
	labels.DeliveryCount.visible=not occupied
	var strip=get_node_or_null("Reference2_completion")
	if strip!=null:strip.visible=not occupied
	labels.Status.visible=not occupied and (message_remaining>0 or (selected>=0 and not (level_index==0 and moves==0)))
	labels.Guide.visible=not occupied and not labels.Status.visible

func tutorial_target() -> int:
	return first_move_guide.target(self)

func select_bottle(index: int) -> void:
	var previous_selection: int = selected
	var previous_moves: int = moves
	var previous_queue:int=presentation.queued_source_id if presentation!=null else 0
	var previous_queue_size:int=presentation.input_queue.size() if presentation!=null else 0
	if rules is Orders and presentation!=null: presentation.select(index)
	if previous_selection>=0 and previous_selection!=selected and moves==previous_moves and previous_selection<bottle_nodes.size():
		var skin=bottle_nodes[previous_selection].visual.delivered_layers
		if is_instance_valid(skin):skin.release_selection_surface()
	if selected != previous_selection or moves != previous_moves or presentation.queued_source_id!=previous_queue or presentation.input_queue.size()!=previous_queue_size:tactile_requested.emit()

func _feedback(value: String, index: int=-1) -> void:
	super._feedback(value,index)
	_refresh_campaign_copy()

func _animation_busy() -> bool:
	return presentation.busy() if presentation!=null else false

func _finish_pour() -> void:
	if _animation_busy() or suppress_animation_completion: return
	super._finish_pour()

func _start_flight() -> void:
	if presentation!=null: presentation.start_ready_receipts()

func _process(delta: float) -> void:
	refresh_bottle_layout_if_idle()
	if not rules is Orders or state!="playing": return
	elapsed+=delta
	if int(elapsed)!=last_clock_second:
		last_clock_second=int(elapsed)
		labels.Stats.text=t("%d 步     %02d:%02d","%d moves     %02d:%02d") % [moves,int(elapsed)/60,int(elapsed)%60]
		_update_reference2_values()
	if message_remaining>0:
		message_remaining=maxf(0,message_remaining-delta)
		if message_remaining<=0: _refresh_campaign_copy()
	for node in bottle_nodes:
		if node.invalid_flash>0:
			node.invalid_flash=maxf(0,node.invalid_flash-delta); node.queue_redraw()
	if is_instance_valid(hud): hud.advance(delta)
	if presentation!=null: presentation.advance(delta)

func _reset_flight_visual() -> void:
	if is_instance_valid(flight_visual):
		flight_visual.global_position=flight_home; flight_visual.scale=flight_scale
		flight_visual.modulate=Color.WHITE; flight_visual.z_index=0
	flight_visual=null

func _settle_animation(evaluate: bool=true) -> void:
	if presentation!=null: presentation.clear()
	pending_full_bottle=-1
	_reset_flight_visual(); deliveries.clear()
	if rules is Orders:
		rules.last_events.clear(); display_delivered=rules.delivered.duplicate(); display_slots=rules.slots()
		if evaluate and not completion_reported and rules.is_solved() and is_inside_tree(): super._finish_pour()

func restore_presentation() -> void:
	rules.settle_orders(); rules.last_events.clear()
	display_delivered=rules.delivered.duplicate(); display_slots=rules.slots()
	if moves>0 and state=="intro": resume_from_instructions()
	_refresh()

func undo_move() -> void:
	presentation.clear_inputs()
	selected=-1
	if history.is_empty() or completion_reported: return
	if _animation_busy():
		presentation.undo_pending=true
		_feedback(t("本次倒水结束后撤回；排队已清空","Undo after this pour; queue cleared.")); return
	if state in ["playing","stuck"]:reward_requested.emit("undo")

func request_color_shuffle() -> void:
	if state not in ["playing","stuck"] or completion_reported:return
	if _animation_busy() or not presentation.input_queue.is_empty():
		_feedback(t("请等待当前动作完成后重排","Wait for current actions to finish before shuffling."));return
	presentation.clear_inputs();selected=-1
	reward_requested.emit("shuffle")

func open_reward(kind: String) -> void:
	if state not in ["playing","stuck"] or not rules.has_bonus():return
	if _animation_busy():
		_feedback(t("当前倒水结束后可解锁辅助","Unlock assistance after the current pour finishes."));return
	if (kind=="bottle" and rules.bonus_unlocked) or (kind=="slot" and rules.slot_unlocked): return
	reward_requested.emit(kind)

func finish_reward(outcome: String) -> void:
	# Compatibility callers cannot authenticate an ad with outcome strings.
	if outcome=="cancelled": reward_cancel_requested.emit()

func restore_after_reward() -> void:
	if state not in ["playing","stuck"]: return
	# The rescue button dispatched the old ActionDialog and disabled its hits.
	# Re-evaluate authoritative rules after the owner has committed/rolled back
	# the reward and queued receipts; never leave that stale input shield alive.
	_clear_overlay(); state="playing"
	_finish_pour(); _refresh()

func resume_from_menu() -> void:
	if state=="paused": resume_game()
	if state not in ["playing","stuck"]: return
	# Home dispatches and locks the old result dialog before hiding this view.
	# Rebuild from the current rules/history rather than re-enabling stale hits.
	restore_after_reward()

func prepare_to_leave() -> void:
	reward_context_changed.emit()
	super.prepare_to_leave()

func _unhandled_key_input(event: InputEvent) -> void:
	if state=="restart" and return_state=="paused" and event.is_action_pressed("ui_cancel"):
		_cancel_restart(); get_viewport().set_input_as_handled(); return
	if state=="paused" and overlay is PauseDialog and event.is_action_pressed("ui_cancel"):
		overlay.cancel(); get_viewport().set_input_as_handled(); return
	if state=="reward" and event.is_action_pressed("ui_cancel"):
		finish_reward("cancelled"); get_viewport().set_input_as_handled(); return
	super._unhandled_key_input(event)

func show_instructions() -> void:
	if rules==null: return
	if state!="intro": return_state=state
	state="intro"; _refresh()
	_make_overlay(t("颜色订单 · 玩法说明","Color orders · How to play"),t("先点源瓶，再点空瓶或顶部同色的瓶子。\n同色装满后封口，匹配上方订单时自动收集。\n暂时没有匹配订单的满瓶会等待。\n完成全部订单才能过关。\n完成订单可揭开隐藏颜色；撤回会还原订单。","Tap a source, then an empty or matching bottle.\nFull bottles deliver to matching orders.\nOther full bottles wait for their order.\nDeliver every order to win.\nOrders reveal covered colors. Undo restores orders."))
	_button(overlay,"Start",t("返回当前局","Back to game"),Rect2(),resume_from_instructions)

func _make_overlay(title: String, body: String) -> void:
	if state in ["won","restart","stuck","intro","instructions"]:
		_clear_overlay()
		var dialog:=ActionDialog.new()
		dialog.locale=locale; dialog.dialog_kind=state; dialog.heading=title
		dialog.result_moves=moves; dialog.result_seconds=elapsed; dialog.result_level=level_index+1
		dialog.body=(t("%d 步 · 用时 %02d:%02d\n全部颜色订单已交付！","%d moves · %02d:%02d\nAll color orders delivered!") % [moves,int(elapsed)/60,int(elapsed)%60]) if state=="won" else body
		if state=="stuck" and history.is_empty(): dialog.body+=t("\n目前没有可撤回的步骤。","\nThere are no moves to undo yet.")
		dialog.size=Vector2(1080,1920); dialog.z_index=100
		overlay=dialog; add_child(dialog)
		dialog.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		labels.OverlayTitle=dialog.title_label; labels.OverlayBody=dialog.body_label
		return
	if title==t("倒瓶子 · 玩法说明","How to play"):
		# Bypass the classic copy replacement in the campaign adapter below.
		title=t("颜色订单 · 玩法说明","Color orders · How to play")
		body=t("先点源瓶，再点空瓶或顶部同色的瓶子。\n同色装满后封口，匹配上方订单时自动收集。\n暂时没有匹配订单的满瓶会等待。\n完成全部订单才能过关。\n订单可揭开隐藏颜色；撤回会还原订单。","Tap a source, then an empty or matching bottle.\nFull bottles deliver to matching orders.\nOther full bottles wait for their order.\nDeliver every order to win.\nOrders reveal covered colors. Undo restores orders.")
	super._make_overlay(title,body)

func _button(parent: Node, id: String, value: String, rect: Rect2, action: Callable, dark: bool=false) -> Button:
	if parent is ActionDialog:
		var button: Button=parent.add_action(id,value,action)
		buttons[id]=button
		return button
	return super._button(parent,id,value,rect,action,dark)

func _result_overlay(won: bool) -> void:
	super._result_overlay(won)
	if not won and rules is Orders and rules.has_bonus() and not rules.bonus_unlocked:
		_button(overlay,"RescueBottle",t("增加空瓶","Extra bottle"),Rect2(170,1270,740,80),func(): open_reward("bottle"),true)

func _clear_overlay() -> void:
	super._clear_overlay()
	for id in ["RewardConfirm","RewardCancel","RescueBottle"]: buttons.erase(id)
