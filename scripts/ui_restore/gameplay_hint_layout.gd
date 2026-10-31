extends RefCounted
## Readability only: leaves hint visibility, rules and bottle geometry to the host.
const Layout=preload("res://scripts/water_sort/order_gameplay_layout.gd")
const TouchUnits=preload("res://scripts/ui_restore/touch_units.gd")
const MINIMUM_LOGICAL_FONT:=14.0
const COMPACT:Dictionary={
	"Fill matching bottles. Deliver every order.":"Fill bottles. Deliver all orders.",
	"1. Tap the highlighted red bottle":"1. Tap the highlighted red bottle",
	"2. Tap the other red bottle to fill it":"2. Fill the other red bottle",
	"Match the top color, or pour into an empty bottle":"Match colors or use empty bottles.",
	"Full bottles fly into matching order cards":"Full bottles deliver their orders.",
	"Start with bottle 2's red top. Reveal the bottom layer step by step.":"Pour red from 2 to reveal colors.",
	"先倒第2瓶顶层红色，逐步揭开底层颜色。":"第2瓶先倒红色，再揭开底色",
	"先倒出第2瓶顶部红色，逐步移走覆盖层。":"第2瓶先倒红色，再揭开底色",
	"Undo after this pour; queue cleared.":"Undo after pour. Queue cleared.",
	"Wait for current actions to finish before shuffling.":"Wait for moves before shuffling.",
	"Unlock assistance after the current pour finishes.":"Finish this pour to unlock help.",
	"Next source selected. Tap its target.":"Next bottle selected. Tap a target.",
	"Board changed; queued pour cancelled.":"Board changed; queue cancelled.",
	"Bottle still locked; queued pour cancelled.":"Bottle locked; queue cancelled.",
	"Waiting for committed actions before undo.":"Finish current moves, then undo.",
	"Follow the pointer for your first order":"Follow the hand for order one.",
	"Accepted; continuing when the current pour finishes.":"Accepted; waiting for this pour.",
	"Not enough pouring space; choose another pair.":"Space blocked. Pick another pair.",
	"Accepted; continuing when the crossing path clears.":"Accepted; waiting for clear space.",
	"瓶子尚未解锁，该排队步骤已取消":"瓶子未解锁，排队步骤已取消",
	"当前倾倒空间不足，请选择另一对瓶子":"倒水空间不足，请另选一对瓶子"
}
static func update(game)->void:
	if not is_instance_valid(game) or not game.labels.has("Guide"):return
	var tx:Transform2D=game.get_window().get_final_transform()*game.get_global_transform_with_canvas()
	var native_scale:=maxf(.0001,tx.y.length())
	var density:=TouchUnits.minimum_window_pixels()/TouchUnits.MINIMUM_LOGICAL
	var pixels:=maxi(roundi(22*Layout.DESIGN_SCALE),ceili(MINIMUM_LOGICAL_FONT*density/native_scale))
	for id in ["Guide","Status"]:
		var label:Label=game.labels[id]
		if not label.visible:continue
		# Only compact complete known phrases; no arbitrary ellipsis or tiny text.
		if pixels>roundi(22*Layout.DESIGN_SCALE) and COMPACT.has(label.text):label.text=COMPACT[label.text]
		label.add_theme_font_size_override("font_size",pixels)
		label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		label.position=Vector2(42,Layout.SLOTS.guide.position.y)
		label.size.x=996
		var face:Font=label.get_theme_font("font")
		var height:=face.get_multiline_string_size(label.text,HORIZONTAL_ALIGNMENT_CENTER,label.size.x,pixels).y+8
		label.size.y=maxf(height,face.get_height(pixels)+8)
		label.clip_text=false
		label.set_meta("minimum_logical_font",MINIMUM_LOGICAL_FONT)
		label.set_meta("actual_logical_font",pixels*native_scale/density)
		label.set_meta("hint_layout_source","native-density font floor; unchanged host visibility")
