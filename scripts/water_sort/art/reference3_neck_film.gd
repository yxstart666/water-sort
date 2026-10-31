extends RefCounted
## Short opaque wall film owns part of the source, not additional liquid.
## Rectangular native-pixel strips remain entirely inside opaque cavity pixels.
const Volume=preload("res://scripts/water_sort/art/reference3_volume.gd")
static var left:=PackedFloat32Array()
static var right:=PackedFloat32Array()
static var max_width:=INF
static func initialize(image: Image) -> void:
	if not left.is_empty(): return
	for y in range(19,75):
		var first:=-1; var last:=-1
		for x in image.get_width():
			if image.get_pixel(x,y).a>=0.9999:
				if first<0: first=x
				last=x
		left.append(first); right.append(last+1); max_width=minf(max_width,last+1-first)
	left.append(left[-1]); right.append(right[-1])
static func sample(total: float, top_units: float, angle: float) -> Dictionary:
	var blend:=smoothstep(0.0,1.0,clampf((0.12-top_units)/0.05,0,1))
	var units:=lerpf(minf(0.045,top_units*0.6),top_units*0.25,blend)
	var width:=minf(units*Volume.UNIT_AREA/56.0,max_width)
	units=width*56.0/Volume.UNIT_AREA
	var walls:=left if angle<0 else right
	var data:=PackedFloat64Array(); var s:=sin(angle); var c:=cos(angle)
	for i in 56:
		var x: float=walls[i] if angle<0 else walls[i]-width
		var y:=float(19+i)
		var minimum:=s*(x if s>=0 else x+width)+c*(y if c>=0 else y+1.0)
		var a:=absf(s)*width; var b:=absf(c)
		data.append_array(PackedFloat64Array([minimum,minimum+a+b,minf(a,b),maxf(a,b),width]))
	var low:=Volume.plane(total,angle); var high:=Volume.plane(maxf(0,total-units),angle)
	for unused in 20:
		var h:=(low+high)*0.5
		if Volume.area_at(angle,h)-Volume.projected_area(data,h)>(total-units)*Volume.UNIT_AREA: low=h
		else: high=h
	return {"plane":(low+high)*0.5,"width":width,"units":units,"walls":walls,"direction":-1.0 if angle<0 else 1.0}
