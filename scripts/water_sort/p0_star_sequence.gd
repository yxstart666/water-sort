extends Control
## Celebration only: always lights all three, never scores the player.
var tween: Tween
var lit: Array[TextureRect] = []
var glows: Array[TextureRect] = []
func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var names = ["left", "center", "right"]
	var boxes = [Rect2(20,38,170,166), Rect2(178,0,192,192), Rect2(350,38,168,166)]
	for i in 3:
		var box: Rect2 = boxes[i]
		_image(names[i], "unlit", box)
		var glow = _image(names[i], "glow_rebuilt", Rect2(box.position - Vector2.ONE * 35, box.size + Vector2.ONE * 70))
		var star = _image(names[i], "lit", box)
		star.pivot_offset = box.size / 2
		glows.append(glow); lit.append(star)
	play()
func _image(star_name: String, state: String, box: Rect2) -> TextureRect:
	var image := TextureRect.new()
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.texture = load("res://assets/p0_ui/runtime/victory_stars/star_%s_%s.png" % [star_name, state])
	image.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	image.position = box.position; image.size = box.size
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(image); return image
func play() -> void:
	if tween and tween.is_valid(): tween.kill()
	for image in lit: image.modulate.a = 0.0
	for image in glows: image.modulate.a = 0.0
	tween = create_tween().set_parallel(true)
	for i in 3:
		var delay: float = [0.08, 0.30, 0.52][i]
		tween.tween_property(lit[i], "modulate:a", 1.0, 0.08).set_delay(delay)
		tween.tween_property(glows[i], "modulate:a", 0.65, 0.16).set_delay(delay)
		tween.tween_property(lit[i], "scale", Vector2.ONE * 1.1, 0.12).set_delay(delay)
		tween.tween_property(lit[i], "scale", Vector2.ONE, 0.18).set_delay(delay + 0.12)
func _exit_tree() -> void:
	if tween and tween.is_valid(): tween.kill()
