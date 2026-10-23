extends Control
## Standalone art review: 3 bottles, real two-colour puzzle, reusable pour timeline.
const BottleVisual = preload("res://scripts/water_sort/art/bottle_visual.gd")
const PourAnimator = preload("res://scripts/water_sort/art/pour_animator.gd")
const Rules = preload("res://scripts/experiments/water_sort_v1/rules.gd")
const Typography = preload("res://scripts/ui_restore/typography.gd")
const INITIAL := [["red", "red", "yellow", "yellow"], ["yellow", "yellow", "red", "red"], []]
const MOVES := [Vector2i(0,2), Vector2i(1,0), Vector2i(1,2)]
const NAVY := Color("102d47")
const CREAM := Color("fff0d2")
const GOLD := Color("dfbd77")
var bottles: Array = []
var animator: Node2D
var rules: RefCounted
var move_index := 0
var autoplay := true
var wait_time := 0.85
var completed_round := false
var playback_scale := 1.0
var title_label: Label
var status_label: Label
var step_label: Label
var pause_button: Button
var font: Font
var stage: Node2D
var frame_capture := ""
var capture_time := -1.0
var capture_done := false
var elapsed_total := 0.0

func _ready() -> void:
	font = Typography.font("cjk_face0")
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build()
	reset_demo()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture="): frame_capture = arg.trim_prefix("--capture=")
		if arg.begins_with("--sample="): capture_time = float(arg.trim_prefix("--sample="))
		if arg == "--no-autoplay": autoplay = false
		if arg.begins_with("--speed="): playback_scale = float(arg.trim_prefix("--speed="))
	if capture_time >= 0:
		autoplay = false
		play_next()
		animator.advance(capture_time)
		animator.set_paused(true)
	print("BOTTLE_ART_DEMO_READY duration=", animator.duration, " committed_before_animation=true")

func _build() -> void:
	stage = Node2D.new(); stage.name = "BottleStage"; add_child(stage)
	_label("LIQUID STUDY  /  01", Vector2(0,65), Vector2(1080,45), 23, GOLD)
	title_label = _label("一倒，恰好。", Vector2(0,138), Vector2(1080,100), 64, CREAM)
	_label("清透玻璃 · 柔和流动 · 色彩归位", Vector2(0,250), Vector2(1080,48), 25, Color("92adbb"))
	for i in 3:
		var bottle := BottleVisual.new()
		bottle.name = "Bottle%d" % (i+1)
		bottle.position = Vector2(250 + i*290, 900)
		bottle.scale = Vector2.ONE * 1.33
		stage.add_child(bottle)
		bottles.append(bottle)
		_label("%02d" % (i+1), Vector2(190+i*290,1460),Vector2(120,50),24,Color("9eafaf"))
	animator = PourAnimator.new()
	animator.name = "PourAnimator"
	animator.z_index = 20
	stage.add_child(animator)
	animator.completed.connect(_on_pour_complete)
	animator.phase_changed.connect(_on_phase)
	step_label = _label("01 / 03", Vector2(0,1510), Vector2(1080,44), 24, GOLD)
	status_label = _label("只移动最上方的同色液体", Vector2(0,1560),Vector2(1080,50),28,CREAM)
	pause_button = _button("暂停", Vector2(176,1660), Vector2(220,80), toggle_pause)
	_button("重新播放", Vector2(430,1660), Vector2(230,80), replay)
	_button("慢动作", Vector2(694,1660), Vector2(210,80), toggle_slow)
	_label("同一套瓶身与动效，可替换任意液体颜色", Vector2(0,1803),Vector2(1080,42),21,Color("7796a8"))

func _label(text: String, at: Vector2, dimensions: Vector2, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text; label.position = at; label.size = dimensions
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	add_child(label)
	return label

func _button(text: String, at: Vector2, dimensions: Vector2, callback: Callable) -> Button:
	var button := Button.new()
	button.text=text; button.position=at; button.size=dimensions
	button.add_theme_font_override("font",font)
	button.add_theme_font_size_override("font_size",26)
	button.add_theme_color_override("font_color",CREAM)
	for state in ["normal","hover","pressed"]:
		var box := StyleBoxFlat.new()
		box.bg_color = Color("23425a") if state == "normal" else Color("31546a")
		box.border_color=Color("627b84")
		box.set_border_width_all(1); box.set_corner_radius_all(24)
		button.add_theme_stylebox_override(state,box)
	button.pressed.connect(callback)
	add_child(button)
	return button

func reset_demo() -> void:
	if animator.busy: animator.cancel(true)
	rules = Rules.new({"capacity":4,"bottles":INITIAL.duplicate(true)})
	move_index=0; completed_round=false; wait_time=0.85
	for i in 3:
		bottles[i].position=Vector2(250+i*290,900)
		bottles[i].rotation=0
		bottles[i].set_layers(rules.bottles[i])
	status_label.text="只移动最上方的同色液体"
	step_label.text="01 / 03"
	queue_redraw()

func replay() -> void:
	autoplay=true
	pause_button.text="暂停"
	reset_demo()
	wait_time=0.25

func toggle_pause() -> void:
	autoplay=not autoplay
	animator.set_paused(not autoplay)
	pause_button.text="继续" if not autoplay else "暂停"

func toggle_slow() -> void:
	playback_scale=0.35 if playback_scale > 0.5 else 1.0
	status_label.text="慢动作 · 看清每一滴" if playback_scale < 0.5 else "原速 · 干净利落的一倒"

func play_next() -> bool:
	if animator.busy or move_index>=MOVES.size(): return false
	var move: Vector2i=MOVES[move_index]
	var before: Dictionary=rules.snapshot()
	if rules.pour(move.x,move.y)<=0: return false
	var after: Dictionary=rules.snapshot()
	var result: bool=animator.play(bottles[move.x],bottles[move.y],before.bottles[move.x],before.bottles[move.y],after.bottles[move.x],after.bottles[move.y])
	if result:
		step_label.text="%02d / 03" % (move_index+1)
		status_label.text=["金黄流入空瓶","珊瑚红汇成一瓶","最后一倒，色彩归位"][move_index]
		move_index+=1
	return result

func _on_pour_complete(_committed: bool) -> void:
	wait_time=0.60
	if rules and rules.is_solved():
		completed_round=true; wait_time=1.65
		status_label.text="刚刚好，两瓶纯色。"
		step_label.text="完成  ✓"

func _on_phase(_value: String) -> void:
	queue_redraw()

func _process(delta: float) -> void:
	elapsed_total+=delta
	# Animator auto-process is disabled here so slow motion affects the entire timeline.
	animator.set_process(false)
	if animator.busy: animator.advance(delta*playback_scale)
	elif autoplay:
		wait_time-=delta*playback_scale
		if wait_time<=0:
			if completed_round: reset_demo()
			else: play_next()
	if not frame_capture.is_empty() and not capture_done:
		capture_done=true
		_capture.call_deferred()

func _capture() -> void:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var error := image.save_png(frame_capture)
	print("ART_FRAME_SAVED path=",frame_capture," code=",error)

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_SPACE: toggle_pause()
			KEY_R: replay()
			KEY_S: toggle_slow()
			KEY_RIGHT:
				if not animator.busy: play_next(); animator.set_paused(true)
				animator.paused=false; animator.advance(1.0/60.0); animator.paused=true

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO,Vector2(1080,1920)),NAVY)
	# Layered calm vignette and a slim warm pedestal, not an opaque bottle background.
	for i in range(16,0,-1):
		var alpha := 0.0035
		draw_circle(Vector2(540,1030), 215+i*25, Color(0.32,0.58,0.67,alpha))
	draw_line(Vector2(120,1445),Vector2(960,1445),Color(0.80,0.74,0.57,0.23),1.0,true)
	for i in 3:
		var center := Vector2(250+i*290,1420)
		for j in range(8,0,-1):
			draw_set_transform(center,0,Vector2(1,0.18))
			draw_circle(Vector2.ZERO,73+j*3,Color(0.015,0.035,0.065,0.018))
		draw_set_transform(Vector2.ZERO,0,Vector2.ONE)
	for point in [Vector2(178,629),Vector2(895,685),Vector2(847,545)]:
		draw_circle(point,2.0,Color(0.85,0.74,0.48,0.35))
