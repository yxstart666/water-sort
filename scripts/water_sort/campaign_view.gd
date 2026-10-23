extends "res://scripts/experiments/water_sort_v1/view.gd"
## Thin opt-in presentation adapter. Rules, layout, input, pour and cork logic
## remain inherited so the reviewed animation is not forked.
const Catalog = preload("res://scripts/water_sort/campaign_catalog.gd")
const CompleteEffect = preload("res://scripts/water_sort/art/level_complete_effect.gd")
var completion_key := ""
var effect
var awaiting_key := ""
var defer_win_overlay := false

func _init() -> void:
	level_path = str(Catalog.configuration(Catalog.V2).level_path)

func _ready() -> void:
	super._ready()
	print("WATER_SORT_CAMPAIGN_V2_READY levels=",levels.size()," opt_in=true")

func _ensure_effect() -> void:
	if is_instance_valid(effect) and not effect.is_queued_for_deletion(): return
	effect = CompleteEffect.new()
	effect.name = "LevelCompleteEffect"
	effect.size = Vector2(1080,1920)
	effect.z_index = 50 # Always below inherited result modal z=100.
	effect.presentation_ready.connect(_presentation_ready)
	add_child(effect)

func cancel_completion() -> void:
	awaiting_key = ""
	if is_instance_valid(effect): effect.cancel()

func _presentation_ready(key: String) -> void:
	if key!=awaiting_key or key!=completion_key or state!="won" or not is_visible_in_tree() or is_queued_for_deletion(): return
	awaiting_key = ""
	_result_overlay(true)

func _finish_pour() -> void:
	var fresh_win: bool = rules!=null and rules.is_solved() and not completion_reported
	defer_win_overlay = fresh_win
	super._finish_pour() # Emits settlement only after the inherited cork finishes.
	defer_win_overlay = false
	if not fresh_win or state!="won" or not is_visible_in_tree() or is_queued_for_deletion(): return
	_ensure_effect()
	awaiting_key = completion_key
	if completion_key.is_empty() or not effect.play_once(completion_key):
		awaiting_key = ""
		_result_overlay(true)

func present_completed_checkpoint() -> void:
	# Recovery already settled the paid attempt. Never replay settlement or a
	# second celebration just because a solved checkpoint was restored.
	cancel_completion()
	completion_reported = true
	_result_overlay(true)

func _result_overlay(won: bool) -> void:
	if won and (defer_win_overlay or not awaiting_key.is_empty()):
		_refresh()
		return
	super._result_overlay(won)
	if won and level_index+1==levels.size():
		labels.OverlayTitle.text=t("%d 关挑战完成","All %d levels complete") % levels.size()

func _build_shell() -> void:
	super._build_shell()
	_refresh_campaign_copy()

func _refresh_campaign_copy() -> void:
	if labels.has("Footnote"): labels.Footnote.text=t("%d 关 · 本机保存","%d levels · Saved on this device") % levels.size()
	if rules==null or levels.is_empty() or level_index>=levels.size(): return
	var level: Dictionary = levels[level_index]
	labels.LevelName.text=str(level.get("title_en","")) if locale=="en" else str(level.get("title",""))
	labels.RuleHint.text=str(level.get("hint_en","")) if locale=="en" else str(level.get("hint",""))
	labels.RuleHint.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	labels.RuleHint.add_theme_font_size_override("font_size",36)
	labels.RuleHint.position.y=1695
	labels.RuleHint.size.y=105

func _refresh() -> void:
	super._refresh()
	_refresh_campaign_copy()

func load_level(index: int) -> void:
	cancel_completion()
	super.load_level(index)

func prepare_to_leave() -> void:
	super.prepare_to_leave()
	cancel_completion()

func set_locale(value: String) -> void:
	cancel_completion()
	_settle_animation(true)
	cancel_completion()
	super.set_locale(value)
	# The inherited presentation rebuild deliberately removes all old children.
	effect=null

func undo_move() -> void:
	cancel_completion()
	super.undo_move()

func request_restart() -> void:
	_settle_animation(true)
	cancel_completion()
	super.request_restart()

func _exit_tree() -> void:
	cancel_completion()
	super._exit_tree()

# Readability is v2-only. Keep every inherited rectangle, hit target, bottle,
# transit lane and animation boundary unchanged.
func _label(parent: Node, id: String, value: String, rect: Rect2, pixels: int=34, color: Color=CREAM) -> Label:
	var readable: int = {"Title":60,"Level":44,"Stats":44,"LevelName":38,"Status":36,"RuleHint":36,"OverlayTitle":58,"OverlayBody":40}.get(id,pixels)
	var node := super._label(parent,id,value,rect,readable,color)
	if id=="OverlayBody":
		node.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		node.size=rect.size
	return node

func _button(parent: Node, id: String, value: String, rect: Rect2, action: Callable, dark: bool=false) -> Button:
	var node := super._button(parent,id,value,rect,action,dark)
	node.add_theme_font_size_override("font_size",42)
	return node

func _make_overlay(title: String, body: String) -> void:
	# Supply compact copy before the inherited Label is created, avoiding its
	# no-wrap minimum width briefly expanding the authored modal rectangle.
	if title==t("倒瓶子 · 玩法说明","How to play"):
		body=t("先点有颜色的瓶子，再点目标瓶。\n目标需为空瓶，或顶部同色且未满。\n顶端连续同色会一起倒入。\n每种颜色装满一瓶，即可过关。\n\n撤销免费；未完成局重开不额外扣体力。\n暂停和查看说明不计时。","Tap a bottle, then a target.\nUse an empty or matching bottle.\nThe top color pours together.\nFill one bottle with each color.\n\nUndo is free. An unfinished\nrestart costs no extra energy.\nPause and rules stop the clock.")
	elif body=="The clock is paused. Your puzzle is unchanged.":
		body="The clock is paused.\nYour puzzle is unchanged."
	elif body=="Bottles, moves and time will reset.":
		body="Bottles, moves and time\nwill reset."
	super._make_overlay(title,body)
