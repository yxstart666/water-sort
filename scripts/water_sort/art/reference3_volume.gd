extends RefCounted
## Exact alpha-weighted rectangle integration of the approved cavity PNG.
## Coordinates stay in native pixels; optical caps never enter liquid volume.
const Assets=preload("res://scripts/water_sort/order_gameplay_assets.gd")
const UNIT_AREA:=8070.785294117648
static var rectangles: Array=[]
static var spill_rectangles:=PackedFloat64Array()
static var spill_groups:=PackedFloat64Array()
static var mouth_index:=PackedInt32Array()
static var mouth_index_bins:=0
static var mouth_index_maximum:=0.0
static var mouth_index_loaded:=false
static var mouth_index_status:="not_loaded"
static var projections: Dictionary={}
static var planes: Dictionary={}
static var spill_index:Dictionary={}
static var spill_index_loaded:=false
static func spill_bracket(fraction:float)->Dictionary:
	if not spill_index_loaded:
		spill_index_loaded=true
		var path:="res://data/water_sort/rendering/spill_brackets.json"
		if FileAccess.file_exists(path):
			var candidate:Variant=JSON.parse_string(FileAccess.get_file_as_string(path))
			if candidate is Dictionary and candidate.get("source_sha256")==FileAccess.get_sha256(Assets.BOTTLE_ROOT+"cavity_rectangles.json") and candidate.get("unit_area")==UNIT_AREA:
				spill_index=candidate
	if spill_index.is_empty():return {}
	var values:Array=spill_index.fractions;var first:=0;var last:=values.size()-1
	if fraction<float(values[-1]) or fraction>float(values[0]):return {}
	while last-first>1:
		var middle:int=(first+last)/2
		if float(values[middle])>fraction:first=middle
		else:last=middle
	var step:float=float(spill_index.maximum_angle)/(values.size()-1)
	return {"low":first*step,"high":last*step,"area_low":float(values[first])*liquid_full_area(),"area_high":float(values[last])*liquid_full_area()}
static func liquid_full_area()->float:return UNIT_AREA*4.0
static func project(angle: float) -> PackedFloat64Array:
	if projections.has(angle): return projections[angle]
	if rectangles.is_empty(): rectangles=JSON.parse_string(FileAccess.get_file_as_string(Assets.BOTTLE_ROOT+"cavity_rectangles.json")).rectangles
	var s:=sin(angle); var c:=cos(angle)
	var data:=PackedFloat64Array()
	for r in rectangles:
		var x: float=r[0] if s>=0 else r[0]+r[2]
		var y: float=r[1] if c>=0 else r[1]+r[3]
		var minimum:=s*x+c*y
		var a: float=absf(s)*r[2]; var b: float=absf(c)*r[3]
		data.append_array(PackedFloat64Array([minimum,minimum+a+b,minf(a,b),maxf(a,b),r[2]*r[3]*r[4]]))
	if projections.size()>128: projections.clear()
	projections[angle]=data
	return data
static func area_at(angle: float, height: float) -> float:
	return projected_area(project(angle),height)
## A precomputed conservative classification, not an angle/volume lookup.
## Empty rectangles contribute zero; full rectangles add the original area in
## original order. Every ambiguous rectangle uses the same exact integration.
## The .01px guard exceeds native float32 mouth-projection rounding. Invalid or
## mismatched dependencies fall back to the exact generic implementation.
static func spill_mouth_area_at(angle:float,height:float)->float:
	if not mouth_index_loaded:
		mouth_index_loaded=true;mouth_index_status="fallback_missing"
		var manifest_path:="res://data/water_sort/rendering/spill_rectangle_index.json"
		var binary_path:="res://data/water_sort/rendering/spill_rectangle_index.bin"
		if FileAccess.file_exists(manifest_path) and FileAccess.file_exists(binary_path):
			mouth_index_status="fallback_invalid"
			var meta:Variant=JSON.parse_string(FileAccess.get_file_as_string(manifest_path))
			var mouth:Vector2=Vector2(Assets.BOTTLE_CONTRACT.outlet_right,Assets.BOTTLE_CONTRACT.mouth.y)
			if meta is Dictionary and meta.get("schema")==1 and meta.get("source_sha256")==FileAccess.get_sha256(Assets.BOTTLE_ROOT+"cavity_rectangles.json") and meta.get("binary_sha256")==FileAccess.get_sha256(binary_path) and meta.get("mouth")==[mouth.x,mouth.y] and float(meta.get("classification_margin_native_pixels",0))>=.01:
				var file:=FileAccess.open(binary_path,FileAccess.READ)
				var data:=file.get_buffer(file.get_length()).to_int32_array()
				var bins:=int(meta.get("bins",0));var codes:=int(meta.get("codes",0))
				if bins>0 and data.size()==bins+1+codes and data[0]==0 and data[bins]==codes and int(meta.get("offset_count",0))==bins+1:
					mouth_index=data;mouth_index_bins=bins;mouth_index_maximum=float(meta.maximum_angle);mouth_index_status="verified"
	if mouth_index.is_empty() or angle<0 or angle>=mouth_index_maximum:return spill_area_at(angle,height)
	var s:=sin(angle);var c:=cos(angle)
	var mouth:=Vector2(Assets.BOTTLE_CONTRACT.outlet_right,Assets.BOTTLE_CONTRACT.mouth.y)
	if height!=mouth.dot(Vector2(s,c)):return spill_area_at(angle,height)
	# Initialize the approved flat native rectangles via the generic path once.
	if spill_rectangles.is_empty():spill_area_at(angle,height)
	var bin:=clampi(floori(angle/(mouth_index_maximum/mouth_index_bins)),0,mouth_index_bins-1)
	var offset:=mouth_index_bins+1;var area:=0.0
	for entry in range(offset+mouth_index[bin],offset+mouth_index[bin+1]):
		var code:=mouth_index[entry];var i:=(absi(code)-1)*5
		if code>0:
			area+=spill_rectangles[i+4];continue
		var x:float=spill_rectangles[i] if s>=0 else spill_rectangles[i]+spill_rectangles[i+2]
		var y:float=spill_rectangles[i+1] if c>=0 else spill_rectangles[i+1]+spill_rectangles[i+3]
		var minimum:=s*x+c*y
		var a:float=absf(s)*spill_rectangles[i+2];var b:float=absf(c)*spill_rectangles[i+3]
		var maximum:=minimum+a+b
		if height<=minimum:area+=spill_rectangles[i+4]
		elif height<maximum:
			var t:=maximum-height;var lo:=minf(a,b);var hi:=maxf(a,b);var part:float
			if lo<0.000000000001:part=t/hi
			elif t<lo:part=t*t/(2.0*lo*hi)
			elif t<=hi:part=(t-lo*.5)/hi
			else:
				var rest:=lo+hi-t;part=1.0-rest*rest/(2.0*lo*hi)
			area+=spill_rectangles[i+4]*part
	return area
## Same rectangle integration and arithmetic, fused into one traversal for
## spill-root probes. No projected-array allocation or approximation/LUT.
static func spill_area_at(angle:float,height:float)->float:
	if spill_rectangles.is_empty():
		if rectangles.is_empty():rectangles=JSON.parse_string(FileAccess.get_file_as_string(Assets.BOTTLE_ROOT+"cavity_rectangles.json")).rectangles
		for r in rectangles:spill_rectangles.append_array(PackedFloat64Array([r[0],r[1],r[2],r[3],r[2]*r[3]*r[4]]))
		# Consecutive groups retain the original rectangle/addition order.
		# Fully filled groups still add each original area individually; there
		# is no reordered sum or quantized plane/angle.
		for first in range(0,rectangles.size(),16):
			var end:=mini(first+16,rectangles.size());var bounds:=Rect2(Vector2(rectangles[first][0],rectangles[first][1]),Vector2.ZERO)
			for j in range(first,end):
				var r:Array=rectangles[j];bounds=bounds.expand(Vector2(r[0],r[1]));bounds=bounds.expand(Vector2(r[0]+r[2],r[1]+r[3]))
			spill_groups.append_array(PackedFloat64Array([first*5,end*5,bounds.position.x,bounds.position.y,bounds.end.x,bounds.end.y]))
	var s:=sin(angle);var c:=cos(angle);var area:=0.0
	for group in range(0,spill_groups.size(),6):
		var first:=int(spill_groups[group]);var end:=int(spill_groups[group+1])
		var x0:float=spill_groups[group+2] if s>=0 else spill_groups[group+4]
		var y0:float=spill_groups[group+3] if c>=0 else spill_groups[group+5]
		var x1:float=spill_groups[group+4] if s>=0 else spill_groups[group+2]
		var y1:float=spill_groups[group+5] if c>=0 else spill_groups[group+3]
		# Conservative guard only disables shortcuts near a block edge.
		if height>s*x1+c*y1+0.00000001:continue
		if height<s*x0+c*y0-0.00000001:
			for i in range(first,end,5):area+=spill_rectangles[i+4]
			continue
		for i in range(first,end,5):
			var x:float=spill_rectangles[i] if s>=0 else spill_rectangles[i]+spill_rectangles[i+2]
			var y:float=spill_rectangles[i+1] if c>=0 else spill_rectangles[i+1]+spill_rectangles[i+3]
			var minimum:=s*x+c*y
			var a:float=absf(s)*spill_rectangles[i+2];var b:float=absf(c)*spill_rectangles[i+3]
			var maximum:=minimum+a+b
			if height<=minimum:area+=spill_rectangles[i+4]
			elif height<maximum:
				var t:=maximum-height;var lo:=minf(a,b);var hi:=maxf(a,b);var part:float
				if lo<0.000000000001:part=t/hi
				elif t<lo:part=t*t/(2.0*lo*hi)
				elif t<=hi:part=(t-lo*.5)/hi
				else:
					var rest:=lo+hi-t;part=1.0-rest*rest/(2.0*lo*hi)
				area+=spill_rectangles[i+4]*part
	return area
static func projected_area(data: PackedFloat64Array, height: float) -> float:
	var area:=0.0
	for i in range(0,data.size(),5):
		if height<=data[i]: area+=data[i+4]
		elif height<data[i+1]:
			var t:=data[i+1]-height; var lo:=data[i+2]; var hi:=data[i+3]
			var part: float
			if lo<0.000000000001: part=t/hi
			elif t<lo: part=t*t/(2.0*lo*hi)
			elif t<=hi: part=(t-lo*0.5)/hi
			else:
				var rest:=lo+hi-t; part=1.0-rest*rest/(2.0*lo*hi)
			area+=data[i+4]*part
	return area
static func plane(units: float, angle: float) -> float:
	var key:=Vector2(units,angle)
	if planes.has(key): return planes[key]
	var data:=project(angle); var low:=INF; var high:=-INF
	for i in range(0,data.size(),5): low=minf(low,data[i]); high=maxf(high,data[i+1])
	if units<=0.00000001: return high
	var desired:=units*UNIT_AREA
	for unused in 25:
		var middle:=(low+high)*0.5
		if projected_area(data,middle)>desired: low=middle
		else: high=middle
	var answer:=(low+high)*0.5
	if planes.size()>512: planes.clear()
	planes[key]=answer
	return answer
