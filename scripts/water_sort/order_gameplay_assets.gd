extends RefCounted
## Main-page source art only; no QA screenshot or template sample is rendered.
const DELIVERY_SHA := "324e70116c777e0704a985ebf0278e1cef5bc6c9"
const ROOT := "res://art/reference2-delivery-20261024/"
const FINISH := ROOT+"reference2_finish_assets_v1/sprites/"
const Layout = preload("res://scripts/water_sort/order_gameplay_layout.gd")
const BACKGROUND := ROOT+"reference2_background_cleanplate_v1/assets/background_native_940x1672.png"
const REFERENCE := "res://references/ui_batch1_pause/water_gameplay_target.png"
const BOTTLE_MATERIAL_SHA := "ebfb9b3658851a36879626ef07c81bc9b2255245"
const CURRENT_BOTTLE_STATUS := "reference3 v2 + paired highlight fix; shared live palette and alpha-weighted volume"
const RESTORE_ROOT := "res://art/gameplay-restore-20261025/"
const REF3 := RESTORE_ROOT+"deliverables/water_sort/"
const BOTTLE_ROOT := REF3+"reference3_cartoon_bottle_v2/assets/"
const BOTTLE_BACK := REF3+"reference3_cartoon_bottle_v2_highlight_fix/assets/glass_back_transmission.png"
const BOTTLE_FRONT := REF3+"reference3_cartoon_bottle_v2_highlight_fix/assets/glass_front_material.png"
const LIQUID_MASK := BOTTLE_ROOT+"pour_cavity_mask.png"
const POUR_MASK := LIQUID_MASK
const CORK := BOTTLE_ROOT+"cork_seated.png"
const CLOTH_PACKAGE := "res://art/colorpause/approved_cloth_order/"
const CLOTH := CLOTH_PACKAGE+"runtime/cloth_overlay_cut.png"
const CLOTH_STATUS := "Approved fitted cloth; approved ANY required1/2 remaining1/2 zh/en and zh blue required1 remaining1; other specified-color cards missing"
const WRAPPED_MASK := BOTTLE_ROOT+"wrapped_visible_mask.png"
const EFFECTS := REF3+"reference3_pour_frame_atlas_v3/assets/"
const CLOTH_CARD := CLOTH_PACKAGE+"runtime/order_card_blue_x1_cut.png"
const APPROVED_PLAY := "res://art/colorpause/approved_play_v1_6/runtime/play_square.png"
const BOTTLE_STATES := ROOT+"reference2_order_bottle_states_v1/assets/"
const LIQUID_SHADER := "res://scripts/water_sort/art/delivered_liquid.gdshader"
const LIQUID_PALETTE := {
	"red":Color("E31C16"),"orange":Color("F47718"),"yellow":Color("FFC313"),"green":Color("83B718"),"blue":Color("2422D0"),"purple":Color("702CC1"),"pink":Color("D82A95"),"cyan":Color("12BFD1")}
const TOP_PALETTE := {
	"red":Color("EB504A"),"orange":Color("F89748"),"yellow":Color("FFD54D"),"green":Color("9DCB3F"),"blue":Color("4142DB"),"purple":Color("8E50D4"),"pink":Color("E358AE"),"cyan":Color("43CDD9")}

# Exact native pixel contract. Keep the existing374-unit mouth-to-bottom frame;
# logical capacity and shoulder fill fraction remain independent of PNG size.
const BOTTLE_CONTRACT := {
	"canvas":Vector2(165,410),"pivot":Vector2(82.5,400),"mouth":Vector2(82.5,19),
	"full_top":86.0,"empty_bottom":378.0,"outlet_left":53.0,"outlet_right":112.0,
	"normalization":374.0/(378.0-19.0),"surface_radii":Vector2(55.5,17.0),
	"cork_top_left":Vector2(50.5,-3),"cork_compression_center_y":22.0,
	"order_icon_source_scale":410.0/137.0,"order_icon_mouth":Vector2(35,13)
}
const UI_SLOTS := {
	"background":{"normal":BACKGROUND,"host":"OrderView background"},
	"level_plate":{"normal":ROOT+"reference2_top_hud_v1/assets/level_title_blank.png","host":"Level"},
	"stats_plate":{"normal":ROOT+"reference2_top_hud_v1/assets/step_pill_blank.png","host":"StepValue/TimeValue"},
	"delivery_counter":{"normal":ROOT+"reference2_completion_strip_v1/assets/completion_strip_reference2_empty.png","host":"DeliveryCount"},
	"pause":{"normal":ROOT+"reference2_replay_settings_buttons_v1/assets/settings_button_blank.png","icon":ROOT+"reference2_replay_settings_buttons_v1/assets/settings_icon_original.png","host":"Pause"},
	"order_card":{"normal":ROOT+"reference2_order_feedback_r2/assets/order_card_pending_white.png","locked":ROOT+"reference2_order_status_v1/assets/order_trial_card_blank.png","complete":ROOT+"reference2_order_feedback_r2/assets/order_card_complete_gold.png","host":"OrderHud"},
	"order_bottle":{"normal":BOTTLE_FRONT,"palette":"LIQUID_PALETTE","host":"OrderTarget live BottleVisual"},
	"undo":{"normal":ROOT+"reference2_undo_button_v1/assets/undo_button_blank.png","icon":ROOT+"reference2_undo_button_v1/assets/undo_arrow_original.png","host":"Undo"},
	"restart":{"normal":ROOT+"reference2_replay_settings_buttons_v1/assets/replay_button_blank.png","icon":ROOT+"reference2_replay_settings_buttons_v1/assets/replay_icon_original.png","host":"Restart"},
	"trial_bottle":{"normal":ROOT+"reference2_replay_settings_buttons_v1/assets/replay_button_blank.png","host":"BonusBottle"},
	"bottle_lock":{"normal":ROOT+"reference2_misc_states_v1/assets/whole_bottle_lock_gold.png","host":"OrderHud mask"}
}

static func tag(node: Node, slot: String) -> void:
	node.set_meta("gameplay_asset_slot",slot)
	node.set_meta("gameplay_art_placeholder",false)

static func font(locale: String) -> Font:
	return preload("res://scripts/ui_restore/font_policy.gd").get_font("latin" if locale=="en" else "sc")

static func image(parent: Node, id: String, rect: Rect2=Rect2()) -> TextureRect:
	var spec:=Layout.element(id)
	var sprite:=TextureRect.new(); sprite.name="Reference2_"+id
	sprite.texture=load(ROOT+str(spec.source))
	sprite.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	sprite.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	sprite.mouse_filter=Control.MOUSE_FILTER_IGNORE
	sprite.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
	var area:=rect if rect.has_area() else Layout.element_rect(id)
	if rect==Rect2() and id in ["energy","energy_icon"]: area.position.y-=13.5*Layout.DESIGN_SCALE
	sprite.position=area.position; sprite.size=area.size
	parent.add_child(sprite); return sprite

static func text_style(label: Label, locale: String, pixels: int, ink:=Color("fff9ef")) -> void:
	label.add_theme_font_override("font",font(locale))
	label.add_theme_font_size_override("font_size",roundi(pixels*Layout.DESIGN_SCALE))
	label.add_theme_color_override("font_color",ink)
	label.clip_text=true

static func skin_button(button: Button, base_id: String, icon_id: String, caption_id: String, locale: String) -> void:
	# Keep the actual Button and its existing callback. Its old StyleBox/text no
	# longer paints over the delivered layers; every child ignores input.
	for state in ["normal","hover","pressed","disabled","focus"]:
		button.add_theme_stylebox_override(state,StyleBoxEmpty.new())
	button.text=""
	button.set_meta("reference2_button",true)
	var origin:=button.position
	if base_id in ["undo","replay"]: origin.y-=(1480.0-1422.0)*Layout.DESIGN_SCALE
	for id in [base_id,icon_id]:
		var rect:=Layout.element_rect(id); rect.position-=origin
		image(button,id,rect)
	if not caption_id.is_empty():
		var spec:=Layout.element(caption_id)
		var label:=Label.new(); label.name="Reference2Caption"
		label.mouse_filter=Control.MOUSE_FILTER_IGNORE
		label.position=Layout.DESIGN_OFFSET+Vector2(spec.position[0],spec.position[1])*Layout.DESIGN_SCALE-origin-Vector2(button.size.x*0.5,24*Layout.DESIGN_SCALE)
		label.size=Vector2(button.size.x,48*Layout.DESIGN_SCALE)
		label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; label.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
		label.text=("撤回" if locale=="zh" else "Undo") if caption_id=="undo_label" else ("重玩" if locale=="zh" else "Replay")
		text_style(label,locale,int(spec.font_px)); button.add_child(label)

static func update_button(button: Button, locale: String="zh") -> void:
	button.text=""
	var caption:=button.get_node_or_null("Reference2Caption") as Label
	if caption!=null:
		caption.text=("撤回" if locale=="zh" else "Undo") if button.name=="Undo" else (("刷新颜色" if locale=="zh" else "Refresh") if button.name=="RefreshColors" else ("重玩" if locale=="zh" else "Replay"))
		caption.add_theme_font_override("font",font(locale))
		button.tooltip_text=caption.text
		button.accessibility_name=caption.text
		if caption.get_meta("tool_caption",false): fit_tool_caption(button)
	var tint:=Color(0.58,0.63,0.74,0.72) if button.disabled else Color.WHITE
	for child in button.get_children():
		if child is CanvasItem: child.modulate=tint

static func fit_tool_caption(button: Button) -> void:
	var caption:=button.get_node_or_null("Reference2Caption") as Label
	if caption==null:return
	var inset:=Vector2(button.size.x*.14,button.size.y*.60)
	var box:=Rect2(inset,Vector2(button.size.x*.72,button.size.y*.22))
	preload("res://scripts/ui_restore/typography.gd").center_label(caption,box,roundi(22*Layout.DESIGN_SCALE))
