extends Control
# Input/selection compatibility shell. Glass, clipped liquids and pouring live in BottleVisual.
signal chosen(index: int)
const Visual = preload("res://scripts/water_sort/art/bottle_visual.gd")
const PALETTE = Visual.DEFAULT_PALETTE
var index := 0
var layers: Array = []:
	set(value):
		layers=value.duplicate()
		if is_instance_valid(visual) and not visual.transaction_busy: visual.set_layers(layers,float(capacity))
var capacity := 4
var selected := false
var locked := false
var invalid_flash := 0.0
var visual_scale_limit := 1.0
var visual: Node2D

func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
	visual=Visual.new(); visual.name="GlassBottle"
	visual.position=Vector2(size.x*0.5,22)
	visual.scale=Vector2.ONE*minf(visual_scale_limit,minf((size.x-20.0)/146.0,(size.y-30.0)/390.0))
	add_child(visual); visual.set_layers(layers,float(capacity))

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and event.pressed:
		accept_event()
		if not locked: chosen.emit(index)
	elif event is InputEventScreenTouch and event.pressed and not ProjectSettings.get_setting("input_devices/pointing/emulate_mouse_from_touch",true):
		accept_event()
		if not locked: chosen.emit(index)

func _draw() -> void:
	# Only feedback is drawn here; never draw a second body or a second set of liquids.
	if selected or invalid_flash>0:
		var edge:=Color("ff8989") if invalid_flash>0 else Color("f4d997")
		var box:=StyleBoxFlat.new(); box.bg_color=Color(edge,0.06); box.border_color=Color(edge,0.65)
		box.set_border_width_all(3); box.set_corner_radius_all(30)
		draw_style_box(box,Rect2(Vector2(-8,-10),size+Vector2(16,20)))
	if selected:
		draw_colored_polygon(PackedVector2Array([Vector2(size.x/2,-24),Vector2(size.x/2-12,-42),Vector2(size.x/2+12,-42)]),Color("f4d997"))
