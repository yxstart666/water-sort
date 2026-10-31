extends Node2D
## Reference2 native glass/mask; never owns rules. Cork has its own small canvas.
const Assets = preload("res://scripts/water_sort/order_gameplay_assets.gd")
const UNKNOWN_FONT = preload("res://art/reference2-delivery-20261024/reference2_dependency_errata_v1/fonts/NotoSans-Bold.ttf")
const BACK = preload(Assets.BOTTLE_BACK)
const FRONT = preload(Assets.BOTTLE_FRONT)
const MASK = preload(Assets.LIQUID_MASK)
const POUR_MASK = preload(Assets.POUR_MASK)
const STATES := Assets.BOTTLE_STATES
const CORK = preload(Assets.CORK)
const LIQUID = preload(Assets.LIQUID_SHADER)
const WRAP = preload("res://scripts/water_sort/art/wrapped_visibility.gdshader")
const VISIBILITY = preload(Assets.WRAPPED_MASK)
const Volume = preload("res://scripts/water_sort/art/reference3_volume.gd")
const Film=preload("res://scripts/water_sort/art/reference3_neck_film.gd")
const IMPACT=preload(Assets.EFFECTS+"impact_tail_atlas.png")
var impact_frame:=-1.0
const Geometry = preload("res://scripts/water_sort/art/liquid_geometry.gd")
const Typography=preload("res://scripts/ui_restore/typography.gd")
const CANVAS: Vector2 = Assets.BOTTLE_CONTRACT.canvas
const PIVOT: Vector2 = Assets.BOTTLE_CONTRACT.pivot
const MOUTH: Vector2 = Assets.BOTTLE_CONTRACT.mouth
const FULL_TOP: float = Assets.BOTTLE_CONTRACT.full_top
const EMPTY_BOTTOM: float = Assets.BOTTLE_CONTRACT.empty_bottom
const ART_SCALE: float = Assets.BOTTLE_CONTRACT.normalization
const OUTLET_LEFT: float = Assets.BOTTLE_CONTRACT.outlet_left
const OUTLET_RIGHT: float = Assets.BOTTLE_CONTRACT.outlet_right
const FLOW_HALF_WIDTH := 7.0/ART_SCALE*0.5
var visual
var liquids: Array[Sprite2D]=[]
var materials: Array[ShaderMaterial]=[]
var cork_art: Sprite2D
var back: Sprite2D
var front: Sprite2D
var surface_fx: Node2D
var completed: Sprite2D
var order_icon := false
var shown_bands := 0
var surface_motion_age:=1.0
var surface_selected:=false
var cover_upper_layers:=false
var unknown_centers: Array[Vector2]=[]
var droplet_age:=1.0
var landing_age:=1.0
const TAIL_DURATION := 0.55
var receiving:=false
var fall_age:=0.0
var tail_age:=1.0
var contact_age:=0.0
var had_contact:=false
var impact_color:=Color.WHITE
static var state_textures: Dictionary={}
static var cavity := PackedVector2Array()
static var liquid_area := 0.0
static var art_bounds := Rect2()
static var outer_outline:=PackedVector2Array()
static var full_outline:=PackedVector2Array()
static var spill_angles: Dictionary={}
static var pose_spill_table:Dictionary={}
static var pose_spill_table_loaded:=false

func presentation_outline() -> PackedVector2Array:
	if not outer_outline.is_empty(): return outer_outline
	var image:=FRONT.get_image()
	var left:=PackedVector2Array(); var right:=PackedVector2Array()
	for y in range(0,int(CANVAS.y),3):
		var first:=-1; var last:=-1
		for x in range(int(CANVAS.x)):
			if image.get_pixel(x,y).a>0.06:
				if first<0: first=x
				last=x
		if first>=0:
			left.append((Vector2(first,y)-MOUTH)*ART_SCALE)
			right.append((Vector2(last+1,y)-MOUTH)*ART_SCALE)
	right.reverse(); left.append_array(right)
	for point in left:
		while outer_outline.size()>=2 and absf((outer_outline[-1]-outer_outline[-2]).cross(point-outer_outline[-1]))<0.001: outer_outline.remove_at(outer_outline.size()-1)
		outer_outline.append(point)
	return outer_outline

func presentation_envelope_outline() -> PackedVector2Array:
	# Convex hull of every nontransparent pixel cell, including the cork.
	# Rotating a used-rect would reserve invisible corners around the neck.
	if not full_outline.is_empty():return full_outline
	var pixels:=PackedVector2Array()
	for item in [[BACK,Vector2.ZERO],[FRONT,Vector2.ZERO],[CORK,Assets.BOTTLE_CONTRACT.cork_top_left]]:
		var image:Image=item[0].get_image();var offset:Vector2=item[1]
		var used:Rect2i=image.get_used_rect()
		for y in range(used.position.y,used.end.y):
			var first:=-1;var last:=-1
			for x in range(used.position.x,used.end.x):
				if image.get_pixel(x,y).a>0.0:
					if first<0:first=x
					last=x
			if first>=0:
				for point in [Vector2(first,y),Vector2(last+1,y),Vector2(last+1,y+1),Vector2(first,y+1)]:pixels.append((point+offset-MOUTH)*ART_SCALE)
	full_outline=Geometry2D.convex_hull(pixels)
	return full_outline

func presentation_bounds() -> Rect2:
	if not art_bounds.has_area():
		var pixels: Rect2=BACK.get_image().get_used_rect()
		pixels=pixels.merge(Rect2(FRONT.get_image().get_used_rect()))
		var cork_bounds:=Rect2(CORK.get_image().get_used_rect())
		cork_bounds.position+=Assets.BOTTLE_CONTRACT.cork_top_left
		pixels=pixels.merge(cork_bounds)
		art_bounds=Rect2((pixels.position-MOUTH)*ART_SCALE,pixels.size*ART_SCALE)
	return art_bounds

func set_surface_selected(value: bool) -> void:
	if value!=surface_selected:
		surface_selected=value; surface_motion_age=0.0
		pulse_surface(false)

func release_selection_surface() -> void:
	if visual.volume()<=0 or visual.transaction_busy: return
	# Reuse the receiving tail at the free surface. No landing transform,
	# inventory change or animation lock is introduced by deselection.
	surface_motion_age=0.0; had_contact=true; receiving=false
	tail_age=0.0; impact_frame=9.37
	impact_color=Assets.TOP_PALETTE.get(str(visual.layers[-1]),Color.WHITE)
	if is_instance_valid(surface_fx): surface_fx.queue_redraw()

func pulse_surface(landed:=false) -> void:
	surface_motion_age=0.0
	if landed: landing_age=0.0

func receive_stream(active: bool, color: Color) -> void:
	impact_color=Assets.TOP_PALETTE.get(str(visual.layers[-1]),color) if not visual.layers.is_empty() else color
	if active and not receiving:
		fall_age=0.0; contact_age=0.0; had_contact=false; tail_age=1.0; impact_frame=-1.0
	if not active and receiving:
		tail_age=0.0 if had_contact else 1.0
	receiving=active
	if not active and had_contact: impact_frame=maxf(9.37,impact_frame)

func receive_transfer(sample: Dictionary, color: Color) -> void:
	impact_color=Assets.TOP_PALETTE.get(visual.layers[-1] if not visual.layers.is_empty() else "green",color)
	if not receiving:
		fall_age=0.0; contact_age=0.0; had_contact=false; tail_age=1.0
	receiving=true
	had_contact=sample.arrived>0.0000001
	impact_frame=(sample.clock-28.0/30.0)*30.0-4.0

func surface_y() -> float:
	return threshold(visual.volume()/visual.capacity,0.0)

func advance_surface(delta: float) -> void:
	if receiving:
		fall_age+=delta
		if 0.5*18000.0*fall_age*fall_age>=surface_y()-MOUTH.y:
			had_contact=true; contact_age+=delta
	else:
		tail_age=minf(1.0,tail_age+delta)
		if had_contact: impact_frame=9.37+tail_age*30.0
	surface_motion_age=minf(0.75,surface_motion_age+delta)
	droplet_age=minf(0.48,droplet_age+delta)
	landing_age=minf(0.30,landing_age+delta)
	position=(PIVOT-MOUTH)*ART_SCALE-Vector2(0,3.0*sin(PI*landing_age/0.30)*exp(-landing_age*8.0))
	queue_redraw()
	if is_instance_valid(surface_fx): surface_fx.queue_redraw()
	visual.queue_redraw()

func _draw_surface_effects() -> void:
	for center in unknown_centers:
		# Keep the font alive through deferred canvas drawing, including when the
		# surrounding Chinese UI holds no other reference to the English font.
		var known_font: Font=preload("res://scripts/ui_restore/font_policy.gd").get_font("latin")
		var ink:Rect2=Typography.ink_bounds("?",known_font,36)
		surface_fx.draw_string(known_font,center-PIVOT-ink.get_center(),"?",HORIZONTAL_ALIGNMENT_LEFT,-1,36,Color("252b36"))
	if visual.volume()<=0 or absf(visual.global_rotation)>0.01 or cover_upper_layers: return
	if not had_contact or impact_frame<0 or impact_frame>=25: return
	var frame:=int(impact_frame)
	var hit:=Vector2(MOUTH.x,surface_y())-PIVOT
	var region:=Rect2((frame%5)*128,(frame/5)*128,128,128)
	surface_fx.draw_texture_rect_region(IMPACT,Rect2(hit-Vector2(64,88),Vector2(128,128)),region,impact_color,false,true)

func _ready() -> void:
	texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
	# Keep BottleVisual's existing mouth-based pose/route untouched. Within the
	# adapter, all layers are base-pivoted exactly as the delivered manifest.
	position=(PIVOT-MOUTH)*ART_SCALE; scale=Vector2.ONE*ART_SCALE
	back=_layer(BACK,"DeliveredBottleBack",-2)
	for i in 4:
		var sprite := _layer(MASK,"DeliveredLiquid"+str(i),0)
		var material := ShaderMaterial.new(); material.shader=LIQUID
		sprite.material=material; liquids.append(sprite); materials.append(material)
	surface_fx=Node2D.new(); surface_fx.name="DeliveredSurfaceEffects"; surface_fx.z_index=1; add_child(surface_fx); surface_fx.draw.connect(_draw_surface_effects)
	cork_art=_layer(CORK,"DeliveredCork",3)
	front=_layer(FRONT,"DeliveredBottleFront",2)
	completed=_layer(null,"DeliveredCompleteState",2); completed.hide()
	# Orbit-star art is a separate pending delivery. Never reuse the old sparkle.
	_build_mask_cavity()
	sync()

func _layer(texture: Texture2D, id: String, depth: int) -> Sprite2D:
	var sprite := Sprite2D.new(); sprite.name=id; sprite.texture=texture
	sprite.centered=false; sprite.position=-PIVOT; sprite.z_index=depth
	add_child(sprite); return sprite

static func _build_mask_cavity() -> void:
	if not cavity.is_empty(): return
	var image := POUR_MASK.get_image()
	Film.initialize(image)
	var left := PackedVector2Array(); var right := PackedVector2Array()
	# Derive the clipping cross-section from the supplied alpha. No substitute
	# bottle contour, white mask image, or additional old glass is drawn.
	for y in range(int(MOUTH.y),int(EMPTY_BOTTOM)+1,2):
		var first := -1; var last := -1
		for x in range(int(CANVAS.x)):
			if image.get_pixel(x,y).a>=0.5:
				if first<0: first=x
				last=x
		if first>=0:
			left.append(Vector2(first,y)); right.append(Vector2(last+1,y))
	var outline:=PackedVector2Array()
	for point in left: outline.append(point)
	right.reverse()
	for point in right: outline.append(point)
	# Remove collinear scan rows; geometry still comes only from supplied alpha.
	for point in outline:
		while cavity.size()>=2 and absf((cavity[-1]-cavity[-2]).cross(point-cavity[-1]))<0.0001: cavity.remove_at(cavity.size()-1)
		cavity.append(point)
	liquid_area=Volume.UNIT_AREA*4.0

static func threshold(fraction: float, angle: float) -> float:
	return Volume.plane(clampf(fraction,0,1)*4.0,angle)

static func plane_chord(level: float, normal: Vector2) -> Dictionary:
	var tangent:=Vector2(normal.y,-normal.x)
	var first:=INF; var last:=-INF
	for i in cavity.size():
		var a:=cavity[i]; var b:=cavity[(i+1)%cavity.size()]
		var da:=a.dot(normal)-level; var db:=b.dot(normal)-level
		if da*db>0.0 or absf(da-db)<0.00001: continue
		var point:=a.lerp(b,da/(da-db)); var along:=point.dot(tangent)
		first=minf(first,along); last=maxf(last,along)
	if first==INF: return {"center":normal*level+tangent*MOUTH.x,"radius":1.0}
	return {"center":normal*level+tangent*((first+last)*0.5),"radius":maxf(1.0,(last-first)*0.5)}

## Exact pre-solved planning knots, bound to the same cavity and outlet.
## Arbitrary animation volumes continue through the original area solver.
static func planning_spill_angle(fraction:float)->float:
	if not pose_spill_table_loaded:
		pose_spill_table_loaded=true
		var path:="res://data/water_sort/rendering/spill_pose_angles.json"
		if FileAccess.file_exists(path):
			var value:Variant=JSON.parse_string(FileAccess.get_file_as_string(path))
			if value is Dictionary and value.get("source_sha256")==FileAccess.get_sha256(Assets.BOTTLE_ROOT+"cavity_rectangles.json") and value.get("unit_area")==Volume.UNIT_AREA and value.get("outlet")==[OUTLET_RIGHT,MOUTH.y] and value.get("denominator")==96 and value.get("angles") is Array and value.angles.size()==97 and value.get("minimum_pose_fraction")==.006/4.0:
				pose_spill_table=value
	if pose_spill_table.is_empty():return NAN
	if fraction==float(pose_spill_table.minimum_pose_fraction):return float(pose_spill_table.minimum_pose_angle)
	var index:=roundi(fraction*96)
	# This tolerance only reconciles arithmetic round-off at an exact grid
	# knot (<4e-8 area pixels); it does not quantize arbitrary liquid volumes.
	if index>=1 and index<=96 and absf(fraction-float(index)/96)<1e-12:return float(pose_spill_table.angles[index])
	return NAN

static func spill_angle(fraction: float) -> float:
	_build_mask_cavity()
	var exact_fraction:=clampf(fraction,0.00001,1.0)
	if spill_angles.has(exact_fraction): return spill_angles[exact_fraction]
	var planned:=planning_spill_angle(exact_fraction)
	if is_finite(planned):
		spill_angles[exact_fraction]=planned;return planned
	var desired:=liquid_area*exact_fraction
	var low:=0.0; var high:=deg_to_rad(179.0)
	# Keep a finite wetted span equal to the existing stream's local width.
	var inside_edge:=Vector2(OUTLET_RIGHT,MOUTH.y)
	var bracket:Dictionary=Volume.spill_bracket(exact_fraction)
	if not bracket.is_empty():
		low=bracket.low;high=bracket.high
		var area_low:float=bracket.area_low;var area_high:float=bracket.area_high
		# Safeguarded secant refinement still evaluates the exact alpha area.
		# If it cannot reach the area tolerance, retain the bracket and bisect.
		for iteration in 4:
			var theta:float=lerpf(low,high,clampf((area_low-desired)/maxf(0.00000001,area_low-area_high),0,1))
			var axis:=Geometry.gravity_normal(theta)
			var held:float=Volume.spill_mouth_area_at(theta,inside_edge.dot(axis))
			if absf(held-desired)<0.0001:
				if spill_angles.size()>=4096:spill_angles.erase(spill_angles.keys()[0])
				spill_angles[exact_fraction]=theta;return theta
			if held>desired:low=theta;area_low=held
			else:high=theta;area_high=held
	for unused in 26:
		var middle: float=(low+high)*0.5
		var axis:=Geometry.gravity_normal(middle)
		if Volume.spill_mouth_area_at(middle,inside_edge.dot(axis))>desired: low=middle
		else: high=middle
	var result: float=(low+high)*0.5
	if spill_angles.size()>=1024: spill_angles.erase(spill_angles.keys()[0])
	spill_angles[exact_fraction]=result
	return result

static func lip(direction: float) -> Vector2:
	var pixel:=Vector2(OUTLET_RIGHT if direction>0 else OUTLET_LEFT,MOUTH.y)
	return (pixel-MOUTH)*ART_SCALE

func outlet_wet() -> bool:
	var angle: float=visual.global_rotation
	var direction:=1.0 if angle>=0 else -1.0
	var pixel:=MOUTH+lip(direction)/ART_SCALE
	return visual.volume()>0.00001 and pixel.dot(Geometry.gravity_normal(angle))>=threshold(visual.volume()/visual.capacity,angle)-0.05

func _static_texture(key: String) -> Texture2D:
	var path:=STATES+key+".png"
	if not FileAccess.file_exists(path): return null # Only the empty state uses a baked image.
	if not state_textures.has(path): state_textures[path]=load(path)
	return state_textures[path]

func _sync_static() -> void:
	if not is_instance_valid(completed): return
	completed.hide()
	back.show(); front.show(); cork_art.visible=visual.cork.visible
	for i in liquids.size(): liquids[i].visible=i<shown_bands
	for sprite in [back,front,cork_art]:
		if sprite.material==null:
			var material:=ShaderMaterial.new(); material.shader=WRAP
			material.set_shader_parameter("visibility_mask",VISIBILITY); sprite.material=material
		sprite.material.set_shader_parameter("covered",cover_upper_layers)
		sprite.material.set_shader_parameter("native_origin",sprite.position+PIVOT)
		sprite.material.set_shader_parameter("native_scale",sprite.scale)

func sync() -> void:
	if not is_instance_valid(visual) or not is_node_ready(): return
	var angle: float=visual.global_rotation
	var normal := Geometry.gravity_normal(angle)
	var mask: Texture2D=POUR_MASK if absf(angle)>0.001 else MASK
	var bottom := 0.0
	var used := 0
	var total: float=visual.volume()
	unknown_centers.clear()
	for band in visual.visible_bands():
		var amount: float=band.amount
		if amount<0.00001: continue
		if used>=liquids.size(): break
		var top := bottom+amount
		var upper := threshold(top/visual.capacity,angle)
		var lower := threshold(bottom/visual.capacity,angle)
		var exposed := top>=total-0.00001
		var film: Dictionary={}
		if exposed and visual.transaction_busy and absf(angle)>0.1 and amount>0.00001:
			film=Film.sample(total,amount,angle); upper=film.plane
		var chord:=plane_chord(upper,normal)
		var bottom_chord:=plane_chord(lower,normal)
		var center: Vector2=chord.center
		var material := materials[used]
		liquids[used].texture=mask
		var hidden: bool=band.color=="unknown"
		# True pigment never reaches a draw material for an unknown unit.
		material.set_shader_parameter("pigment",Color("b9bec8") if hidden else visual.color_for(str(band.color)))
		material.set_shader_parameter("top_pigment",Color("b9bec8") if hidden else Assets.TOP_PALETTE[str(band.color)])
		if hidden:
			# Center in the drawn unit's visible vertical span, including its
			# optical arcs; half of the liquid volume is not half of its height.
			var upper_center:Vector2=chord.center+normal*minf(32.0*chord.radius/111.0,16.0)
			var lower_center:Vector2=bottom_chord.center+normal*minf(32.0*bottom_chord.radius/111.0,16.0)
			if absf(angle)<0.001: lower_center.y=minf(lower_center.y,EMPTY_BOTTOM)
			unknown_centers.append((upper_center+lower_center)*0.5)
		material.set_shader_parameter("film_width",float(film.get("width",0.0)))
		if not film.is_empty():
			material.set_shader_parameter("film_walls",film.walls)
			material.set_shader_parameter("film_direction",film.direction)
		material.set_shader_parameter("gravity_axis",normal)
		material.set_shader_parameter("top_level",upper)
		material.set_shader_parameter("bottom_level",lower)
		material.set_shader_parameter("exposed_surface",exposed)
		material.set_shader_parameter("cover_upper_layers",cover_upper_layers)
		material.set_shader_parameter("visibility_mask",VISIBILITY)
		material.set_shader_parameter("surface_center",center)
		material.set_shader_parameter("ellipse_radius",Vector2(chord.radius,minf(17.0,chord.radius*34.0/111.0)))
		material.set_shader_parameter("bottom_center",bottom_chord.center)
		material.set_shader_parameter("bottom_radius",bottom_chord.radius)
		material.set_shader_parameter("incoming_center_x",MOUTH.x)
		material.set_shader_parameter("incoming",visual.incoming_strength)
		material.set_shader_parameter("ripple",visual.settle_strength)
		material.set_shader_parameter("ripple_clock",visual.settle_clock)
		var slope:=0.045*sin(surface_motion_age*18.0)*exp(-surface_motion_age*7.0) if surface_motion_age<0.75 and not visual.transaction_busy else 0.0
		material.set_shader_parameter("surface_slope",slope)
		liquids[used].show(); used+=1; bottom=top
	for i in range(used,liquids.size()): liquids[i].hide()
	shown_bands=used
	if is_instance_valid(surface_fx): surface_fx.queue_redraw()
	sync_cork()

func sync_cork() -> void:
	if not is_instance_valid(cork_art) or not is_instance_valid(visual.cork): return
	# Existing cork Sprite2D is a texture-free pose driver. Preserve its timeline,
	# opacity and signals while translating its local offset to source pixels.
	var driver: Sprite2D=visual.cork
	var compress := driver.scale.y/(44.0/663.0)
	cork_art.visible=driver.visible
	cork_art.position=-PIVOT+Assets.BOTTLE_CONTRACT.cork_top_left+Vector2(0,(driver.position.y+24.0)/ART_SCALE+Assets.BOTTLE_CONTRACT.cork_compression_center_y*(1.0-compress))
	cork_art.scale=Vector2(1,compress); cork_art.modulate=driver.modulate
	_sync_static()
