extends Control
const Art = preload("res://scripts/water_sort/p2_art.gd")
var tween: Tween
var lit: Array[TextureRect] = []
var glows: Array[TextureRect] = []
func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var page: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/p2_ui/victory_layouts.json")).pages[0]
	for layer in page.layers:
		if layer.type == "optionalGlow":
			var glow: TextureRect = Art.add_layer(self,layer); glow.modulate.a=0; glows.append(glow)
		elif layer.type == "animatedStar":
			Art.add_layer(self,layer,layer.initialTexture)
			var star: TextureRect = Art.add_layer(self,layer,layer.litTexture)
			star.modulate.a=0; star.pivot_offset=star.size*0.5; lit.append(star)
	tween=create_tween().set_parallel(true)
	for i in 3:
		var delay: float=[0.08,0.30,0.52][i]
		tween.tween_property(lit[i],"modulate:a",1.0,0.08).set_delay(delay)
		tween.tween_property(glows[i],"modulate:a",0.65,0.16).set_delay(delay)
		tween.tween_property(lit[i],"scale",Vector2.ONE*1.1,0.12).set_delay(delay)
		tween.tween_property(lit[i],"scale",Vector2.ONE,0.18).set_delay(delay+0.12)
func _exit_tree() -> void:
	if tween and tween.is_valid(): tween.kill()
