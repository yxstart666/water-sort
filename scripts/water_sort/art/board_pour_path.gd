extends RefCounted
var profile_enabled:=false
var profile:Dictionary={"route_calls":0,"route_us":0,"clear_calls":0,"clear_us":0,"edge_calls":0,"edge_us":0}
## Configuration-space routing for glass at its configured static display size.
## Production keeps both rows fixed; only the selected source travels.
var outline: PackedVector2Array
var envelope: PackedVector2Array
var pose_results: Dictionary={}
var edge_results: Dictionary={}
var sweep_obstacles: Dictionary={}
var obstacles: Array=[]:
	set(value):
		obstacles=value; pose_results.clear(); edge_results.clear(); sweep_obstacles.clear()
var bounds: Rect2:
	set(value):
		bounds=value; pose_results.clear(); edge_results.clear()
var step:=24.0
var sweep_step:=2.64:
	set(value):
		sweep_step=value;edge_results.clear();sweep_obstacles.clear()
var radius:=180.0
var row_min:=0.0
var row_max:=0.0
var origin:=Vector2.ZERO
var heap: Array=[]
var checked: Dictionary={}
var expanded:=0
var failed:=false
var grid_fallbacks:=0
var allow_grid:=true
var upper_bottom:=0.0
var lower_top:=0.0
## Per-planner geometry only; no nodes, poses, obstacles or board state retained.
## Translation sweeps reuse their exact angle without repeating every bound scan.
var rotated_geometry: Dictionary={}

func configure(shape: PackedVector2Array, items: Array, area: Rect2, grid_step: float, row_range: Vector2) -> void:
	outline=shape; obstacles=items; bounds=area; step=grid_step
	rotated_geometry.clear()
	row_min=row_range.x; row_max=row_range.y
	for point in shape: radius=maxf(radius,point.length())

func polygon(pose: Vector4) -> PackedVector2Array:
	return Transform2D(pose.z,Vector2(pose.x,pose.y))*outline

func geometry_at(angle: float) -> Dictionary:
	var geometry: Dictionary
	if rotated_geometry.has(angle): geometry=rotated_geometry[angle]
	else:
		var rotated:=Transform2D(angle,Vector2.ZERO)*outline
		var rotated_box:=Rect2(rotated[0],Vector2.ZERO)
		for point in rotated: rotated_box=rotated_box.expand(point)
		var full_box:=rotated_box
		if not envelope.is_empty():
			var full:=Transform2D(angle,Vector2.ZERO)*envelope
			full_box=Rect2(full[0],Vector2.ZERO)
			for point in full: full_box=full_box.expand(point)
		geometry={"shape":rotated,"box":rotated_box,"page_box":full_box}
		if rotated_geometry.size()<512: rotated_geometry[angle]=geometry
	return geometry

func clear(pose: Vector4) -> bool:
	if not profile_enabled:return _clear_impl(pose)
	var t:=Time.get_ticks_usec();var result:=_clear_impl(pose);profile.clear_calls+=1;profile.clear_us+=Time.get_ticks_usec()-t;return result
func _clear_impl(pose:Vector4)->bool:
	if pose_results.has(pose):return pose_results[pose]
	var result:=_clear_uncached(pose)
	if pose_results.size()<4096:pose_results[pose]=result
	return result

func _clear_uncached(pose: Vector4) -> bool:
	var geometry:=geometry_at(pose.z)
	var offset:=Vector2(pose.x,pose.y)
	var box: Rect2=geometry.box; box.position+=offset
	var page_box: Rect2=geometry.page_box; page_box.position+=offset
	if not bounds.encloses(page_box): return false
	var shape:=PackedVector2Array()
	for item in obstacles:
		var shift:=Vector2(0,pose.w if item.upper else 0.0)
		var rect: Rect2=item.rect; rect.position+=shift
		if not rect.intersects(box): continue
		if shape.is_empty(): shape=Transform2D(0,offset)*geometry.shape
		var other: PackedVector2Array=item.polygon
		if item.upper: other=Transform2D(0,shift)*other
		if not Geometry2D.intersect_polygons(shape,other).is_empty(): return false
	return true

func edge(a: Vector4,b: Vector4) -> bool:
	if not profile_enabled:return _edge_impl(a,b)
	var t:=Time.get_ticks_usec();var result:=_edge_impl(a,b);profile.edge_calls+=1;profile.edge_us+=Time.get_ticks_usec()-t;return result
func _edge_impl(a:Vector4,b:Vector4)->bool:
	# Exact directed endpoints: reverse sweeps and differently spaced samples
	# are intentionally distinct. Lifetime is this immutable transfer plan only.
	var key: Array=[a,b,sweep_step,radius]
	if edge_results.has(key):return edge_results[key]
	var result:=_edge_uncached(a,b)
	if edge_results.size()<2048:edge_results[key]=result
	return result

func _edge_uncached(a: Vector4,b: Vector4) -> bool:
	# A fixed-angle translation stays inside the union AABB of its endpoints.
	# Only skip the original sweep when that entire box has no obstacles and
	# the full visual envelope stays in bounds. Any overlap uses the exact sweep.
	if a.z==b.z and a.w==b.w:
		var geometry:=geometry_at(a.z)
		var first:Rect2=geometry.box; first.position+=Vector2(a.x,a.y)
		var last:Rect2=geometry.box; last.position+=Vector2(b.x,b.y)
		var swept:=first.merge(last)
		var page_first:Rect2=geometry.page_box; page_first.position+=Vector2(a.x,a.y)
		var page_last:Rect2=geometry.page_box; page_last.position+=Vector2(b.x,b.y)
		var empty:=bounds.encloses(page_first.merge(page_last))
		if empty:
			for item in obstacles:
				var rect:Rect2=item.rect; rect.position.y+=a.w if item.upper else 0.0
				if rect.intersects(swept): empty=false; break
		if empty: return true
	var reach:=radius
	for point in envelope:reach=maxf(reach,point.length())
	return clear(b) and _swept_interval_clear(a,b,reach)

func _swept_interval_clear(a:Vector4,b:Vector4,reach:float,depth:=0)->bool:
	# A pose sample alone can miss a thin contact between samples. Every point
	# in this interval stays within this translation + rotation bound of its
	# midpoint. Certify that neighbourhood, or subdivide the ambiguous interval.
	# Endpoint boxes plus the interpolation error bound r*d_angle^2/8
	# enclose the entire translating/rotating interval, including concave glass.
	# Empty intervals need no additional polygon construction.
	var first:=geometry_at(a.z);var last:=geometry_at(b.z)
	var first_box:Rect2=first.box;first_box.position+=Vector2(a.x,a.y)
	var last_box:Rect2=last.box;last_box.position+=Vector2(b.x,b.y)
	var first_page:Rect2=first.page_box;first_page.position+=Vector2(a.x,a.y)
	var last_page:Rect2=last.page_box;last_page.position+=Vector2(b.x,b.y)
	var deviation:=reach*(a.z-b.z)*(a.z-b.z)/8.0+.0001
	var swept:=first_box.merge(last_box).grow(deviation)
	var empty:=bounds.encloses(first_page.merge(last_page).grow(deviation))
	if empty:
		for item in obstacles:
			var rect_a:Rect2=item.rect;rect_a.position.y+=a.w if item.upper else 0.0
			var rect_b:Rect2=item.rect;rect_b.position.y+=b.w if item.upper else 0.0
			if swept.intersects(rect_a.merge(rect_b)):empty=false;break
	if empty:return true
	# Subdivide only intervals whose conservative swept box touches something.
	# Uncertified samples retain the original maximum 2.64px spacing; the
	# additional neighbourhood check below closes the gaps between those poses.
	var extent:=maxf(Vector2(a.x,a.y).distance_to(Vector2(b.x,b.y)),absf(a.z-b.z)*reach)
	extent=maxf(extent,absf(a.w-b.w))
	if extent>sweep_step:
		var split:=a.lerp(b,.5)
		return clear(split) and _swept_interval_clear(a,split,reach) and _swept_interval_clear(split,b,reach)
	var motion:=Vector2(a.x,a.y).distance_to(Vector2(b.x,b.y))+absf(a.z-b.z)*reach+absf(a.w-b.w)
	var margin:=maxf(.001,motion*.5)
	var level:=clampi(floori(log(sweep_step/margin)/log(2.0)),-2,11)
	var guard:=sweep_step*pow(0.5,level)
	var middle:=a.lerp(b,.5)
	var geometry:=geometry_at(middle.z)
	var offset:=Vector2(middle.x,middle.y)
	var page:Rect2=geometry.page_box;page.position+=offset
	var clear_margin:=bounds.encloses(page.grow(guard))
	var box:Rect2=geometry.box;box.position+=offset
	if clear_margin:
		if not sweep_obstacles.has(level):
			var expanded_items:Array=[]
			for item in obstacles:
				expanded_items.append({"rect":item.rect.grow(guard),"polygons":Geometry2D.offset_polygon(item.polygon,guard,Geometry2D.JOIN_MITER),"upper":item.upper})
			sweep_obstacles[level]=expanded_items
		var shape:=PackedVector2Array()
		for item in sweep_obstacles[level]:
			var shift:=Vector2(0,middle.w if item.upper else 0.0)
			var rect:Rect2=item.rect;rect.position+=shift
			if not box.intersects(rect):continue
			if shape.is_empty():shape=Transform2D(0,offset)*geometry.shape
			for polygon in item.polygons:
				var other:PackedVector2Array=Transform2D(0,shift)*polygon
				if not Geometry2D.intersect_polygons(shape,other).is_empty():clear_margin=false;break
			if not clear_margin:break
	if clear_margin:return true
	if depth>=8 or not clear(middle):return false
	return _swept_interval_clear(a,middle,reach,depth+1) and _swept_interval_clear(middle,b,reach,depth+1)

func cost(a: Vector4,b: Vector4) -> float:
	return Vector2(a.x,a.y).distance_to(Vector2(b.x,b.y))+absf(a.z-b.z)*radius*0.60+absf(a.w-b.w)*0.55

func push(value: Array) -> void:
	heap.append(value); var i:=heap.size()-1
	while i>0:
		var p: int=(i-1)/2
		if heap[p][0]<=value[0]: break
		heap[i]=heap[p]; i=p
	heap[i]=value

func pop() -> Array:
	var result: Array=heap[0]; var end: Array=heap.pop_back()
	if heap.is_empty(): return result
	var i:=0
	while i*2+1<heap.size():
		var c:=i*2+1
		if c+1<heap.size() and heap[c+1][0]<heap[c][0]: c+=1
		if end[0]<=heap[c][0]: break
		heap[i]=heap[c]; i=c
	heap[i]=end; return result

func decode(key: Vector4i) -> Vector4:
	return Vector4(origin.x+key.x*step,origin.y+key.y*step,key.z*PI/12.0,key.w*step)

func route(start: Vector4,finish: Vector4) -> Array[Vector4]:
	if not profile_enabled:return _route_impl(start,finish)
	var t:=Time.get_ticks_usec();var result:=_route_impl(start,finish);profile.route_calls+=1;profile.route_us+=Time.get_ticks_usec()-t;return result
func _route_impl(start:Vector4,finish:Vector4)->Array[Vector4]:
	heap.clear(); checked.clear(); expanded=0; failed=false
	if not clear(finish): failed=true; return []
	if edge(start,finish): return [start,finish]
	var aligned:=aligned_turn_route(start,finish)
	if not aligned.is_empty():return aligned
	var corridor:=turning_corridor(start,finish)
	if not corridor.is_empty(): return corridor
	var via:=landmark_route(start,finish)
	if not via.is_empty(): return via
	if not allow_grid: failed=true; return []
	grid_fallbacks+=1
	origin=Vector2(start.x,start.y)
	var first:=Vector4i(0,0,roundi(start.z/(PI/12)),roundi(start.w/step))
	var scores: Dictionary={first:0.0}; var previous: Dictionary={}
	var poses: Dictionary={first:start}
	push([cost(start,finish),first])
	var visited: Dictionary={}
	var directions: Array[Vector4i]=[Vector4i(1,0,0,0),Vector4i(-1,0,0,0),Vector4i(0,1,0,0),Vector4i(0,-1,0,0),Vector4i(0,0,1,0),Vector4i(0,0,-1,0),Vector4i(0,0,0,1),Vector4i(0,0,0,-1),Vector4i(0,-1,1,0),Vector4i(0,-1,-1,0),Vector4i(0,1,1,0),Vector4i(0,1,-1,0)]
	while not heap.is_empty() and expanded<24000:
		var current: Vector4i=pop()[1]
		if visited.has(current): continue
		visited[current]=true; expanded+=1
		var pose: Vector4=poses[current]
		if cost(pose,finish)<sweep_step*(108.0/2.64) and edge(pose,finish):
			var result: Array[Vector4]=[finish,pose]
			while previous.has(current):
				current=previous[current]; result.append(poses[current])
			result.reverse()
			# Smooth only through edges that pass the same swept collision test.
			var compact: Array[Vector4]=[result[0]]; var at:=0
			while at<result.size()-1:
				var next:=result.size()-1
				while next>at+1 and not edge(result[at],result[next]): next-=1
				compact.append(result[next]); at=next
			return compact
		for direction in directions:
			var next:=current+direction
			if visited.has(next) or next.z< -11 or next.z>11 or next.w*step<row_min or next.w*step>row_max: continue
			var candidate:=decode(next)
			var score: float=scores[current]+cost(pose,candidate)
			if scores.has(next) and score>=scores[next]: continue
			if not checked.has(next): checked[next]=clear(candidate)
			if not checked[next] or not edge(pose,candidate): continue
			previous[next]=current; scores[next]=score; poses[next]=candidate
			push([score+cost(candidate,finish)*1.75,next])
	failed=true; return []

func aligned_turn_route(start:Vector4,finish:Vector4,prefer_start_height:=false,prefer_local_turn:=false)->Array[Vector4]:
	# Try lift/slide/turn at the actual dock height before the grid. Each
	# candidate uses the same swept edges and page/receiver collision checks.
	for y in ([start.y,finish.y] if prefer_start_height else [finish.y,start.y]):
		var rise:=Vector4(start.x,y,start.z,start.w)
		var across:=Vector4(finish.x,y,start.z,start.w)
		var turn:=Vector4(finish.x,y,finish.z,finish.w)
		var rotate_first:=Vector4(start.x,y,finish.z,finish.w)
		if prefer_local_turn and clear(rise) and clear(rotate_first) and edge(start,rise) and edge(rise,rotate_first) and edge(rotate_first,turn) and edge(turn,finish):
			return [start,rise,rotate_first,turn,finish]
		if clear(rise) and clear(across) and clear(turn) and edge(start,rise) and edge(rise,across) and edge(across,turn) and edge(turn,finish):
			return [start,rise,across,turn,finish]
		if clear(rise) and clear(rotate_first) and edge(start,rise) and edge(rise,rotate_first) and edge(rotate_first,turn) and edge(turn,finish):
			return [start,rise,rotate_first,turn,finish]
	return []

func turning_corridor(start:Vector4,finish:Vector4) -> Array[Vector4]:
	# A full-size source can turn in a free lower-side pocket, then approach
	# the receiver at its final angle. Validate every swept edge identically
	# to grid search; these candidates only avoid expensive blind exploration.
	var reach:=0.0
	for point in envelope: reach=maxf(reach,point.length())
	var left:=bounds.position.x+reach+step
	var right:=bounds.end.x-reach-step
	var bottom:=bounds.end.y-reach-step
	var low:=minf(bottom,maxf(start.y,finish.y)+reach*0.5)
	for x in [clampf(start.x,left,right),clampf(finish.x,left,right),left,right]:
		for y in [low,bottom]:
			var a:=Vector4(x,y,start.z,start.w)
			var b:=Vector4(x,y,finish.z,finish.w)
			if not clear(a) or not clear(b): continue
			if edge(start,a) and edge(a,b) and edge(b,finish):
				return [start,a,b,finish]
	# Large single-row bottles often cannot turn at the outer source column.
	# Try a few inward, elevated pockets before searching a full position grid.
	# Receiver, HUD, bounds and continuous swept checks remain authoritative.
	for rise in [1,2,3,4,5,6]:
		var y:float=minf(start.y,finish.y)-step*rise
		for x in [clampf(start.x,left,right),clampf(finish.x,left,right),left,right]:
			var lifted:=Vector4(start.x,y,start.z,start.w)
			var a:=Vector4(x,y,start.z,start.w)
			var b:=Vector4(x,y,finish.z,finish.w)
			if clear(lifted) and clear(a) and clear(b) and edge(start,lifted) and edge(lifted,a) and edge(a,b) and edge(b,finish):
				return [start,lifted,a,b,finish]
	return []

func landmark_route(start: Vector4,finish: Vector4) -> Array[Vector4]:
	var points: Array[Vector4]=[start,finish]
	var body:=Rect2(envelope[0],Vector2.ZERO)
	for point in envelope: body=body.expand(point)
	var left:=bounds.position.x-body.position.x+step*0.3
	var right:=bounds.end.x-body.end.x-step*0.3
	var top:=bounds.position.y-body.position.y+step*0.3
	for shift in [row_min+step*0.25,0.0,row_max-step*0.25]:
		if shift<row_min or shift>row_max: continue
		var middle: float=(upper_bottom+shift+lower_top)*0.5 if lower_top>0 else (start.y+top)*0.5
		for x in [start.x,finish.x,left,right]:
			for y in [top,middle,start.y]:
				var pose:=Vector4(x,y,0,shift)
				if clear(pose): points.append(pose)
	var scores: Dictionary={0:0.0}; var previous: Dictionary={}; var closed: Dictionary={}
	var frontier: Array=[0]
	while not frontier.is_empty():
		var best:=0
		for i in range(1,frontier.size()):
			if scores[frontier[i]]+cost(points[frontier[i]],finish)<scores[frontier[best]]+cost(points[frontier[best]],finish): best=i
		var current: int=frontier.pop_at(best)
		if current==1:
			var result: Array[Vector4]=[finish]
			while previous.has(current): current=previous[current]; result.append(points[current])
			result.reverse(); return result
		closed[current]=true
		for next in points.size():
			if closed.has(next) or next==current: continue
			var score: float=scores[current]+cost(points[current],points[next])
			if scores.has(next) and score>=scores[next]: continue
			if not edge(points[current],points[next]): continue
			scores[next]=score; previous[next]=current
			if not frontier.has(next): frontier.append(next)
	return []

func sample(path: Array[Vector4],t: float) -> Vector4:
	var length:=0.0
	for i in range(1,path.size()): length+=cost(path[i-1],path[i])
	var distance:=length*clampf(t,0,1)
	for i in range(1,path.size()):
		var segment:=cost(path[i-1],path[i])
		if distance<=segment: return path[i-1].lerp(path[i],distance/maxf(0.001,segment))
		distance-=segment
	return path[-1]
