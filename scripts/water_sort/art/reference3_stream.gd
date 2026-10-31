extends Node2D
## Renders neutral approved textures once-tinted inside target's glass layers.
const Assets=preload("res://scripts/water_sort/order_gameplay_assets.gd")
const HEAD=preload(Assets.EFFECTS+"flow_head_atlas.png")
const CORE=preload(Assets.EFFECTS+"open_stream_core.png")
const DROP=preload(Assets.EFFECTS+"transport_drop.png")
var animator
var exterior:=false
static var drop_area:=0.0
static func path_uv(base:float,local_y:float,total_length:float)->float:
	return clampf((base+local_y)/maxf(.00001,total_length),0.0,1.0)
func _ready() -> void:
	texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
	if drop_area==0:
		var image:=DROP.get_image()
		for y in image.get_height():
			for x in image.get_width(): drop_area+=image.get_pixel(x,y).a
func _draw() -> void:
	if not is_instance_valid(animator) or not animator.busy or animator.mass.is_empty(): return
	var segments: Array=animator.mass.segments
	if segments.is_empty(): return
	var skin=animator.target.delivered_layers
	var outlet:=to_local(animator.outlet)
	var mouth:=to_local(animator.target.mouth_world())
	var surface:=to_local(skin.to_global(Vector2(skin.MOUTH.x,skin.surface_y())-skin.PIVOT))
	var outside_length:=outlet.distance_to(mouth)
	var inside_length:=mouth.distance_to(surface)
	var total_length:=outside_length+inside_length
	var start:=outlet if exterior else mouth
	var finish:=mouth if exterior else surface
	var base:=0.0 if exterior else outside_length
	var delta:=finish-start; var length:=delta.length()
	if length<0.01: return
	var tint: Color=Assets.TOP_PALETTE[animator.color_key]
	var ribbons: Array=segments.filter(func(s): return s.kind!=2)
	draw_set_transform(start,atan2(-delta.x,delta.y))
	if not ribbons.is_empty():
		var low:=1.0; var high:=0.0; var join:=-1.0; var has_main:=false; var has_film:=false
		for seg in ribbons:
			low=minf(low,seg.from); high=maxf(high,seg.to)
			if seg.kind==0: has_main=true; join=seg.from
			else: has_film=true
		low=maxf(0.0,low*total_length-base)/length
		high=minf(length,high*total_length-base)/length
		join=(join*total_length-base)/length
		var tick:=int((animator.mass.clock-28.0/30.0)*30.0)
		if high<=low: ribbons=[]
		if high>low and tick<4:
			# The approved head occupies the same global UV as subsequent core.
			# Both draw nodes sample ONE atlas path. Resetting UV at the mouth
			# clips the growing head twice and exposes a gap on longer air segments.
			var uv_low:=path_uv(base,low*length,total_length)
			var uv_high:=path_uv(base,high*length,total_length)
			var region:=Rect2(clampi(tick,0,3)*32,uv_low*256,32,(uv_high-uv_low)*256)
			draw_texture_rect_region(HEAD,Rect2(-16,low*length,32,(high-low)*length),region,tint,false,false)
		elif high>low:
			var y:=low*length
			while y<high*length:
				var p:=(y+0.25)/length
				var width:=32.0 if has_main else 21.0
				if has_main and has_film: width=21.0+11.0*smoothstep(join-0.065,join+0.065,p)
				if low>0: width*=sqrt(maxf(0,1.0-pow(1.0-clampf((y-low*length)/5.0,0,1),2)))
				var height:=minf(1.0,high*length-y)
				var uv:=path_uv(base,y+0.25,total_length)
				if width>0.01: draw_texture_rect_region(CORE,Rect2(-width*0.5,y,width,height),Rect2(0,clampf(uv*256,0,255),32,1),tint,false,false)
				y+=1.0
	for seg in segments:
		if seg.kind!=2: continue
		var factor:=sqrt(seg.units*animator.moved*8070.785294117648/drop_area)
		var flatten:=1.0-0.55*clampf((seg.center-0.82)/0.18,0,1)
		var size:=Vector2(20.0/flatten,24.0*flatten)*factor
		var y:=minf(seg.center*total_length-size.y*0.5,total_length-size.y)-base
		var clipped_top:=maxf(y,0.0); var clipped_bottom:=minf(y+size.y,length)
		if clipped_bottom>clipped_top:
			var region:=Rect2(0,(clipped_top-y)/size.y*24,20,(clipped_bottom-clipped_top)/size.y*24)
			draw_texture_rect_region(DROP,Rect2(-size.x*0.5,clipped_top,size.x,clipped_bottom-clipped_top),region,tint,false,false)
	draw_set_transform(Vector2.ZERO)
