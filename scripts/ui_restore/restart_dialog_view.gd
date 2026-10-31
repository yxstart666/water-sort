extends Control
## Restart confirmation view. The host supplies consequences and callbacks.
const Art = preload("res://scripts/ui_restore/recipe_art.gd")
const P2Art = preload("res://scripts/water_sort/p2_art.gd")
const FontPolicy = preload("res://scripts/ui_restore/font_policy.gd")
var locale := "zh"
var body := ""
var heading := ""
var frame: Control
var body_label: Label
var title_label: Label
var buttons: Dictionary = {}
var targets: Dictionary = {}
func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var layouts: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/colorpause_ui_20261030/layouts/restart.json"))
	var spec: Dictionary = layouts[locale]
	for layer in spec.layers:
		if layer.type == "runtimeText": continue
		var node := Art.layer(self, layer)
		if frame == null: frame = node
	for target in spec.hotareas: targets[target.action] = Art.box(target.rectDp)
	if targets.has("restart"): targets.restart_confirm = targets.restart
	title_label = Label.new(); title_label.name = "HostHeading"; title_label.text = heading
	title_label.hide(); add_child(title_label)
	body_label = Label.new(); body_label.name = "HostConsequences"
	body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	body_label.add_theme_font_override("font", FontPolicy.get_font("lxgw"))
	body_label.add_theme_font_size_override("font_size", 15)
	body_label.add_theme_color_override("font_color", Color("0963bd"))
	body_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body_label.position = Vector2(50, 304); body_label.size = Vector2(220, 78)
	body_label.text = body.replace("，", "，\n") if locale == "zh" else body; add_child(body_label)
func add_action(id: String, caption: String, action: Callable) -> Button:
	var slot := "restart_confirm" if id == "ConfirmRestart" else "continue"
	var button := P2Art.hit(self, id, targets[slot], action)
	button.tooltip_text = caption; buttons[id] = button
	if id == "CancelRestart":
		buttons.close = P2Art.hit(self, "close", targets.close, action)
	return button
