extends RefCounted
const ROOT := "res://assets/p2_ui/"
static func add_layer(parent: Control, layer: Dictionary, override_path := "") -> Control:
	var path: String = override_path if not override_path.is_empty() else str(layer.source)
	var rect: Array = layer.rectDp
	if path.begins_with("res://"): pass
	else: path = ROOT + path
	var node: Control
	if layer.type == "nineSlice":
		var nine := NinePatchRect.new(); var factor: float = layer.uniformCornerScale
		nine.texture = load(path); nine.position = Vector2(rect[0], rect[1])
		nine.size = Vector2(rect[2], rect[3]) / factor; nine.scale = Vector2.ONE * factor
		for i in 4: nine.set_patch_margin(i, int(layer.sourceInsetsLTRB[i]))
		node = nine
	else:
		var image := TextureRect.new(); image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		image.texture = load(path); image.position = Vector2(rect[0], rect[1]); image.size = Vector2(rect[2], rect[3])
		node = image
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	parent.add_child(node); return node
static func hit(parent: Control, id: String, box: Rect2, action: Callable) -> Button:
	var button := Button.new(); button.name = id; button.position = box.position; button.size = box.size
	button.flat = true; button.focus_mode = Control.FOCUS_ALL
	for style in ["normal","hover","pressed","disabled","focus"]: button.add_theme_stylebox_override(style, StyleBoxEmpty.new())
	button.pressed.connect(action); parent.add_child(button); bind_press_feedback(parent,button); preload("res://scripts/ui_restore/touch_hit.gd").attach(button); return button

static func bind_press_feedback(parent: Control, button: Button) -> void:
	var affected: Array=[]
	for child in parent.get_children():
		if not (child is TextureRect or child is NinePatchRect): continue
		var art_rect:=Rect2(child.position,child.size*child.scale)
		if button.get_rect().has_point(art_rect.get_center()): affected.append([child,child.modulate])
	button.button_down.connect(func():
		for item in affected:
			if is_instance_valid(item[0]): item[0].modulate=item[1]*Color(0.88,0.88,0.88))
	var restore:=func():
		for item in affected:
			if is_instance_valid(item[0]): item[0].modulate=item[1]
	button.button_up.connect(restore);button.mouse_exited.connect(restore)
