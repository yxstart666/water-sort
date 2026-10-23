extends Control
## Isolated art preview. No app shell, progress file, settlement, or level mutations.
const Effect = preload("res://scripts/water_sort/art/level_complete_effect.gd")
const Bottle = preload("res://scripts/water_sort/art/bottle_visual.gd")
const Typography = preload("res://scripts/ui_restore/typography.gd")
const NAVY := Color("102d47")
const CREAM := Color("fff0d2")
const GOLD := Color("dfbd77")
var effect: Control
var result_panel: Panel
var status_label: Label
var pause_button: Button
var bottles: Array = []
var font: Font
var run_index := 0
var active_key := ""
var seed_value := Effect.DEFAULT_SEED
var _capture_path := ""
var _sample_time := -1.0
var _quit_after_capture := false

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	font = Typography.font("cjk_face0")
	var autoplay := true
	for argument in OS.get_cmdline_user_args():
		if argument == "--no-autoplay": autoplay = false
		if argument.begins_with("--sample="): _sample_time = float(argument.trim_prefix("--sample="))
		if argument.begins_with("--seed="): seed_value = int(argument.trim_prefix("--seed="))
		if argument.begins_with("--capture="): _capture_path = argument.trim_prefix("--capture=")
		if argument == "--quit-after-capture": _quit_after_capture = true
	_build()
	if autoplay or _sample_time >= 0.0:
		replay()
		if _sample_time >= 0.0:
			effect.set_process(false)
			effect.advance(_sample_time)
			effect.set_paused(true)
			pause_button.text = "继续"
	if not _capture_path.is_empty(): _capture.call_deferred()
	print("LEVEL_COMPLETE_DEMO_READY ready_at=", Effect.PRESENTATION_DELAY, " tail=", Effect.DURATION, " seed=", seed_value)

func _build() -> void:
	_label(self, "COLOR AT REST  /  02", Rect2(0, 90, 1080, 50), 23, GOLD)
	_label(self, "颜色归位，轻轻庆祝。", Rect2(0, 162, 1080, 90), 52, CREAM)
	_label(self, "独立动效预览 · 不读取或写入游戏进度", Rect2(0, 276, 1080, 52), 24, Color("9ab2bf"))
	var stage := Node2D.new()
	stage.name = "ApprovedCorkedBottles"
	add_child(stage)
	for index in 3:
		var bottle := Bottle.new()
		bottle.name = "CorkedBottle%d" % index
		bottle.position = Vector2(248 + index * 292, 650)
		bottle.scale = Vector2.ONE * 1.10
		stage.add_child(bottle)
		var color: String = ["yellow", "red", "blue"][index]
		bottle.set_layers([color, color, color, color])
		bottles.append(bottle)
	# Particle canvas is behind the modal and cannot intercept pointer input.
	effect = Effect.new()
	effect.name = "LevelCompleteEffect"
	add_child(effect)
	effect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	effect.presentation_ready.connect(_on_presentation_ready)
	effect.finished.connect(_on_effect_finished)
	result_panel = Panel.new()
	result_panel.name = "PreviewResultPanel"
	result_panel.position = Vector2(150, 1140)
	result_panel.size = Vector2(780, 440)
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = CREAM
	panel_style.border_color = GOLD
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(38)
	panel_style.shadow_color = Color(0.02, 0.04, 0.08, 0.24)
	panel_style.shadow_size = 22
	result_panel.add_theme_stylebox_override("panel", panel_style)
	add_child(result_panel)
	_label(result_panel, "完成", Rect2(0, 35, 780, 78), 52, NAVY)
	_label(result_panel, "步数 / 用时保留在原有结果界面", Rect2(0, 119, 780, 50), 24, Color("56717c"))
	_button(result_panel, "下一关", Rect2(70, 204, 640, 82), next_preview, true)
	_button(result_panel, "再玩一次", Rect2(70, 310, 302, 76), replay)
	_button(result_panel, "返回主页", Rect2(408, 310, 302, 76), leave_preview)
	result_panel.hide()
	status_label = _label(self, "点击重播，查看完整的一次反馈", Rect2(0, 1632, 1080, 48), 25, Color("9ab2bf"))
	pause_button = _button(self, "暂停", Rect2(112, 1714, 246, 82), toggle_pause)
	_button(self, "重播动效", Rect2(410, 1714, 266, 82), replay)
	_button(self, "跳过动效", Rect2(728, 1714, 246, 82), skip_effect)
	_label(self, "空格暂停 · R重播 · 回车跳过 · → 单帧", Rect2(0, 1827, 1080, 48), 20, Color("7796a8"))

func replay() -> void:
	effect.cancel()
	result_panel.hide()
	run_index += 1
	active_key = "preview-attempt-%d" % run_index
	effect.play_once(active_key, seed_value)
	pause_button.text = "暂停"
	status_label.text = "轻量侧边彩屑，0.42秒后显示结果"

func _on_presentation_ready(key: String) -> void:
	if key != active_key: return
	result_panel.show()
	status_label.text = "结果已可操作，剩余粒子不阻挡按钮"
	print("LEVEL_COMPLETE_PREVIEW_PRESENTATION key=", key, " elapsed=", effect.elapsed)

func _on_effect_finished(key: String, cancelled: bool) -> void:
	print("LEVEL_COMPLETE_PREVIEW_FINISHED key=", key, " cancelled=", cancelled)

func next_preview() -> void:
	effect.cancel()
	result_panel.hide()
	for index in bottles.size():
		var color: String = ["green", "purple", "yellow"][(index + run_index) % 3]
		bottles[index].set_layers([color, color, color, color])
	active_key = ""
	status_label.text = "已进入下一预览，旧粒子立即停止"

func leave_preview() -> void:
	effect.cancel()
	result_panel.hide()
	active_key = ""
	status_label.text = "已离开结果预览，旧动效不会再弹出界面"

func skip_effect() -> void:
	effect.skip()

func toggle_pause() -> void:
	if not effect.busy: return
	effect.set_paused(not effect.paused)
	pause_button.text = "继续" if effect.paused else "暂停"

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_SPACE: toggle_pause()
			KEY_R: replay()
			KEY_ENTER: skip_effect()
			KEY_RIGHT:
				if not effect.busy: replay()
				effect.set_process(false)
				effect.set_paused(false)
				effect.advance(1.0 / 60.0)
				effect.set_paused(true)

func _label(parent: Node, text: String, box: Rect2, pixels: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.position = box.position
	label.size = box.size
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", pixels)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label

func _button(parent: Node, text: String, box: Rect2, callback: Callable, primary := false) -> Button:
	var button := Button.new()
	button.text = text
	button.position = box.position
	button.size = box.size
	button.add_theme_font_override("font", font)
	button.add_theme_font_size_override("font_size", 26)
	button.add_theme_color_override("font_color", NAVY if primary else CREAM)
	for state in ["normal", "hover", "pressed", "focus"]:
		var style := StyleBoxFlat.new()
		style.bg_color = GOLD if primary else Color("23425a")
		if state == "hover" or state == "pressed": style.bg_color = style.bg_color.lightened(0.10)
		style.border_color = Color("76909a") if state == "focus" else Color("627b84")
		style.set_border_width_all(2 if state == "focus" else 1)
		style.set_corner_radius_all(22)
		button.add_theme_stylebox_override(state, style)
	button.pressed.connect(callback)
	parent.add_child(button)
	return button

func _capture() -> void:
	await RenderingServer.frame_post_draw
	var error := get_viewport().get_texture().get_image().save_png(_capture_path)
	print("LEVEL_COMPLETE_FRAME_SAVED path=", _capture_path, " code=", error)
	if _quit_after_capture: get_tree().quit(error)

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, Vector2(1080, 1920)), NAVY)
	for index in range(14, 0, -1):
		draw_circle(Vector2(540, 868), 135 + index * 24, Color(0.32, 0.58, 0.67, 0.0035))
	draw_line(Vector2(120, 1090), Vector2(960, 1090), Color(0.80, 0.74, 0.57, 0.23), 1.0, true)
	for index in 3:
		for ring in range(7, 0, -1):
			draw_set_transform(Vector2(248 + index * 292, 1075), 0.0, Vector2(1.0, 0.15))
			draw_circle(Vector2.ZERO, 62 + ring * 3, Color(0.015, 0.035, 0.065, 0.022))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
