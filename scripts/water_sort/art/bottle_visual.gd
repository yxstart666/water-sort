extends Node2D
## Reusable view only. Logical layers are bottom-to-top; fractional amounts are visual.
signal seal_finished
const SEAL_DURATION := 0.22
const CORK = preload("res://assets/water_sort/bottles/v1/cork.png")
const Geometry = preload("res://scripts/water_sort/art/liquid_geometry.gd")
const GLASS_DEPTH = preload("res://scripts/water_sort/art/glass_depth_mask.gdshader")
const SHELL = preload("res://assets/water_sort/bottles/v1/glass_shell.png")
const DEFAULT_PALETTE := {
	"red": Color("eb3043"), "blue": Color("148be8"), "yellow": Color("f2d414"),
	"green": Color("11b866"), "purple": Color("a651f3"), "orange": Color("f57810"),
	"pink": Color("ed29b2"), "cyan": Color("13cbd7")}
# Pigment stays opaque. Highlights are narrow accents, not a white wash.
const EDGE_DARKEN := 0.08
const SURFACE_LIGHTEN := 0.10
const CAUSTIC_ALPHA := 0.025
const INCOMING_CORE_ALPHA := 0.96
const INCOMING_HIGHLIGHT_ALPHA := 0.14
const RIPPLE_ALPHA := 0.18
const STREAM_HIGHLIGHT_ALPHA := 0.16
const LIQUID_AA_WIDTH_DESIGN_PX := 0.65
var palette: Dictionary = DEFAULT_PALETTE.duplicate()
var capacity := 4.0
var layers: Array = []
var bands: Array = []
var unknown_layers: Array = []

func visible_bands() -> Array:
	if not unknown_layers.has(true): return bands
	var result: Array=[]; var bottom:=0.0
	for band in bands:
		var left: float=band.amount
		while left>0.00001:
			var unit:=int(floor(bottom+0.00001))
			var amount:=minf(left,float(unit+1)-bottom)
			var hidden: bool=unit<unknown_layers.size() and unknown_layers[unit]
			result.append({"amount":amount,"color":"unknown" if hidden else band.color})
			bottom+=amount; left-=amount
	return result
var transaction_busy := false
var incoming_color := Color.TRANSPARENT
var incoming_strength := 0.0
var incoming_time := 0.0
var selected := false
var shell: Sprite2D
var cork: Sprite2D
var sealed := false
var seal_animating := false
var seal_progress := 0.0
var seal_elapsed := 0.0
var _seal_notified := false
var seal_duration := SEAL_DURATION
var seal_drop_distance := 47.0
var settle_strength := 0.0
var settle_clock := 0.0
var delivered_layers: Node2D

func presentation_bounds() -> Rect2:
	if is_instance_valid(delivered_layers): return delivered_layers.presentation_bounds()
	return Rect2(-80,-28,160,420) # Existing classic renderer's visual envelope.

func use_delivered_layers() -> void:
	if is_instance_valid(delivered_layers): return
	palette=preload("res://scripts/water_sort/order_gameplay_assets.gd").LIQUID_PALETTE.duplicate()
	# Opt-in visual skin only. Classic callers keep the original renderer.
	var renderer=load("res://scripts/water_sort/art/delivered_bottle_layers.gd").new()
	delivered_layers=renderer; renderer.visual=self
	add_child(renderer)
	shell.hide(); get_node("GlassRearFoot").hide()
	# Keep the reviewed cork timeline as a pose driver, without drawing old art.
	cork.texture=null
	renderer.sync(); queue_redraw()

func _ready() -> void:
	# Smooth continuous art explicitly; never inherit a pixel-art nearest filter.
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	shell = Sprite2D.new()
	shell.name = "GlassFront"
	shell.texture = SHELL
	shell.centered = false
	shell.position = Vector2(-512.0, -180.0) * 0.32
	shell.scale = Vector2.ONE * 0.32
	var front_material := ShaderMaterial.new()
	front_material.shader = GLASS_DEPTH
	front_material.set_shader_parameter("rear_pass",false)
	shell.material = front_material
	shell.z_index = 3
	var rear_glass := Sprite2D.new()
	rear_glass.name = "GlassRearFoot"
	rear_glass.texture = SHELL
	rear_glass.centered = false
	rear_glass.position = shell.position
	rear_glass.scale = shell.scale
	var rear_material := ShaderMaterial.new()
	rear_material.shader = GLASS_DEPTH
	rear_material.set_shader_parameter("rear_pass",true)
	rear_glass.material = rear_material
	rear_glass.z_index = -1
	add_child(rear_glass)
	add_child(shell)
	cork = Sprite2D.new()
	cork.name = "CompletionCork"
	var atlas := AtlasTexture.new()
	atlas.atlas = CORK
	atlas.region = Rect2(351,185,834,663)
	cork.texture = atlas
	cork.centered = false
	cork.scale = Vector2(72.0/834.0,44.0/663.0)
	cork.position = Vector2(-36,-24)
	cork.z_index = 2
	cork.visible = sealed
	add_child(cork)
	queue_redraw()

func set_layers(value: Array, bottle_capacity := 4.0) -> void:
	layers = value.duplicate()
	capacity = bottle_capacity
	bands = to_bands(value)
	sync_seal_immediate(is_complete())
	queue_redraw()

func is_complete() -> bool:
	return not unknown_layers.has(true) and complete_layers(layers,capacity)

static func complete_layers(value: Array, bottle_capacity := 4.0) -> bool:
	if value.size() != int(bottle_capacity) or value.is_empty(): return false
	for color in value:
		if color != value[0]: return false
	return true

## Snapshot restore/undo/restart is immediate and never repeats a celebration.
func sync_seal_immediate(value: bool) -> void:
	sealed = value
	seal_animating = false
	seal_progress = 1.0 if value else 0.0
	seal_elapsed = seal_duration if value else 0.0
	_seal_notified = value
	if is_instance_valid(cork):
		cork.visible = value
		cork.position = Vector2(-36,-24)
		cork.modulate.a = 1.0
		cork.scale.y = 44.0/663.0
	if is_instance_valid(delivered_layers): delivered_layers.sync_cork()

## Pure timeline sampling: the PourAnimator owns the only clock, including pause.
func sample_seal(progress_value: float) -> void:
	if not is_complete():
		sync_seal_immediate(false)
		return
	var p := clampf(progress_value,0.0,1.0)
	seal_progress = p
	seal_elapsed = p*seal_duration
	seal_animating = p < 1.0
	sealed = p >= 1.0
	if is_instance_valid(cork):
		cork.visible = true
		cork.modulate.a = 1.0
		var offset := 0.0
		if p < 0.76:
			var descend := p/0.76
			offset = lerpf(-seal_drop_distance,2.5,descend*descend*(3.0-2.0*descend))
		else:
			var settle := (p-0.76)/0.24
			offset = lerpf(2.5,0.0,settle*settle*(3.0-2.0*settle))
		cork.position = Vector2(-36,-24+offset)
		cork.scale.y = (44.0/663.0)*(1.0-0.025*sin(p*PI))
	if is_instance_valid(delivered_layers): delivered_layers.sync_cork()
	if sealed and not _seal_notified:
		_seal_notified = true
		seal_finished.emit()

func sample_unseal(progress_value: float) -> void:
	var p := clampf(progress_value,0.0,1.0)
	sealed = false
	seal_animating = false
	seal_progress = 1.0-p
	_seal_notified = false
	if is_instance_valid(cork):
		cork.visible = p < 1.0
		cork.position = Vector2(-36,-24-42.0*p*p*(3.0-2.0*p))
		cork.modulate.a = 1.0-p
	if is_instance_valid(delivered_layers): delivered_layers.sync_cork()

static func to_bands(value: Array) -> Array:
	var result: Array = []
	for color in value:
		if not result.is_empty() and result[-1].color == str(color): result[-1].amount += 1.0
		else: result.append({"color": str(color), "amount": 1.0})
	return result

func set_visual_bands(value: Array) -> void:
	bands = value.duplicate(true)
	queue_redraw()

func volume() -> float:
	var total := 0.0
	for item in bands: total += float(item.amount)
	return total

func color_for(key: String) -> Color:
	return palette.get(key, DEFAULT_PALETTE.blue)

func mouth_world(side := 0.0) -> Vector2:
	if is_instance_valid(delivered_layers):
		var radius: float=(delivered_layers.OUTLET_RIGHT-delivered_layers.OUTLET_LEFT)*0.5
		return to_global(Vector2(side*radius*delivered_layers.ART_SCALE,0))
	return to_global(Vector2(side * 34.0, 0))

func flow_angle(units: float) -> float:
	if is_instance_valid(delivered_layers): return delivered_layers.spill_angle(units/capacity)
	return Geometry.spill_angle(units,capacity)

func flow_lip(direction: float) -> Vector2:
	return delivered_layers.lip(direction) if is_instance_valid(delivered_layers) else Vector2(direction*34.0,0)

func flow_cavity() -> PackedVector2Array:
	if not is_instance_valid(delivered_layers): return Geometry.cavity()
	var result:=PackedVector2Array()
	for point in delivered_layers.cavity: result.append((point-delivered_layers.MOUTH)*delivered_layers.ART_SCALE)
	return result

func impact_world() -> Vector2:
	return to_global(Vector2(0, Geometry.threshold(volume(), capacity, global_rotation)))

static func outer_liquid_edges(shape: PackedVector2Array) -> Array[Vector2]:
	var result: Array[Vector2]=[]
	var cavity:=Geometry.cavity()
	for i in shape.size():
		var a: Vector2=shape[i]
		var b: Vector2=shape[(i+1)%shape.size()]
		if a.distance_squared_to(b)<0.000001: continue
		for j in cavity.size():
			var c: Vector2=cavity[j]
			var d: Vector2=cavity[(j+1)%cavity.size()]
			if Geometry2D.get_closest_point_to_segment(a,c,d).distance_squared_to(a)<0.000025 and Geometry2D.get_closest_point_to_segment(b,c,d).distance_squared_to(b)<0.000025:
				result.append(a);result.append(b);break
	return result

func _draw_outer_liquid_aa(shape: PackedVector2Array, liquid: Color) -> void:
	# Compatibility has no 2D MSAA. Native antialiased lines add subpixel coverage
	# only at the outer liquid contour, safely behind the unchanged glass rim.
	var edges:=outer_liquid_edges(shape)
	var width:=LIQUID_AA_WIDTH_DESIGN_PX/maxf(absf(global_scale.x),0.01)
	for i in range(0,edges.size(),2):
		var shade:=absf((edges[i].x+edges[i+1].x)*0.5)/68.0
		draw_line(edges[i],edges[i+1],liquid.darkened(shade*EDGE_DARKEN),width,true)

func _draw() -> void:
	if is_instance_valid(delivered_layers):
		delivered_layers.sync()
		return
	var angle := global_rotation
	var poly := Geometry.cavity()
	# Back-glass is a separate subtle tint. The centre stays truly transparent when empty.
	draw_colored_polygon(poly, Color(0.61, 0.83, 0.90, 0.028))
	var cumulative := 0.0
	for item in bands:
		var amount := float(item.amount)
		if amount < 0.00001: continue
		var liquid := color_for(item.color)
		var shape := Geometry.band(cumulative, cumulative + amount, capacity, angle)
		if shape.size() >= 3 and Geometry.area(shape) > 0.05 and not Geometry2D.triangulate_polygon(shape).is_empty():
			var colors := PackedColorArray()
			for point in shape:
				var shade := absf(point.x) / 68.0
				colors.append(liquid.darkened(shade * EDGE_DARKEN))
			draw_polygon(shape, colors)
			_draw_outer_liquid_aa(shape,liquid)
			# A translucent caustic highlight, strictly clipped inside this liquid band.
			var shine := Geometry.clip(shape, Vector2.RIGHT, -48.0)
			shine = Geometry.clip(shine, Vector2.RIGHT, -40.0, false)
			if shine.size() >= 3 and Geometry.area(shine) > 0.05 and not Geometry2D.triangulate_polygon(shine).is_empty(): draw_colored_polygon(shine, Color(1, 1, 1, CAUSTIC_ALPHA))
		cumulative += amount
		var surface := Geometry.surface(cumulative, capacity, angle)
		if surface.size() == 2:
			var a := surface[0].lerp(surface[1], 0.025)
			var b := surface[0].lerp(surface[1], 0.975)
			draw_line(a, b, liquid.lightened(SURFACE_LIGHTEN), 2.2, true)
			if cumulative >= volume() - 0.001:
				# Meniscus has a shallow dark underside and a bright glass-contact line.
				draw_line(a + Geometry.gravity_normal(angle)*2, b + Geometry.gravity_normal(angle)*2, liquid.darkened(0.10), 1.2, true)
				if settle_strength>0.001:
					var ripple := PackedVector2Array()
					for j in 17:
						var fraction := j/16.0
						ripple.append(a.lerp(b,fraction)+Vector2(0,sin(fraction*TAU+settle_clock*38)*1.8*settle_strength*sin(fraction*PI)))
					draw_polyline(ripple,Color(liquid.lightened(0.3),0.55*settle_strength),1.5,true)
	if incoming_strength > 0.0001:
		var bottom := clampf(Geometry.threshold(volume(), capacity, angle), 5.0, 367.0)
		var stream := PackedVector2Array([Vector2(-3, 0), Vector2(3, 0), Vector2(4, bottom), Vector2(-4, bottom)])
		stream = Geometry.clip(stream, Vector2.DOWN, 0)
		var c := incoming_color
		c.a = INCOMING_CORE_ALPHA * incoming_strength
		draw_colored_polygon(stream, c)
		draw_line(Vector2(-0.8, 2), Vector2(-0.8, bottom), Color(1,1,1,INCOMING_HIGHLIGHT_ALPHA*incoming_strength), 1.8, true)
		if bottom > 8:
			var ripple_width := 10.0 + 5.0 * sin(incoming_time * 25.0)
			draw_arc(Vector2(0,bottom+1), ripple_width, PI, TAU, 20, Color(1,1,1,RIPPLE_ALPHA*incoming_strength), 1.7, true)
