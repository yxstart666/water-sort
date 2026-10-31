extends Node2D
static var performance_profile_enabled:=false
static var performance_profiles:Array=[]
static var performance_board_pose_us:=0
static var performance_board_pose_calls:=0
static var performance_spill_us:=0
static var performance_receiver_us:=0
var _perf_pose_start_us:=0
var _perf_pose_start_calls:=0
var performance_play_us:=0
var plan_profile:Dictionary={}
var _perf_last_us:=0
func _perf_mark(label:String)->void:
	if not performance_profile_enabled:return
	var now:=Time.get_ticks_usec();plan_profile.stages_us[label]=now-_perf_last_us;_perf_last_us=now
func _perf_finish()->void:
	if not performance_profile_enabled:return
	_perf_mark("finalize")
	plan_profile.path=board_path.profile.duplicate(true)
	plan_profile.play_us=performance_play_us
	plan_profile.board_pose_us=performance_board_pose_us-_perf_pose_start_us;plan_profile.board_pose_calls=performance_board_pose_calls-_perf_pose_start_calls
	plan_profile.source=board_bottles.find(source.get_parent());plan_profile.target=board_bottles.find(target.get_parent())
	plan_profile.failed=board_path_failed;plan_profile.cache_hit=static_route_cache_hit;plan_profile.plan_ms=board_plan_ms
	performance_profiles.append(plan_profile.duplicate(true))
## One transaction/timeline for every liquid colour. No rule mutations or awaited tweens.
## Pass before/after arrays AFTER atomically committing your gameplay move.
## Each instance owns one complete transfer; order callers reserve bottle resources.
signal completed(committed: bool)
signal phase_changed(phase: String)
const Geometry = preload("res://scripts/water_sort/art/liquid_geometry.gd")
const Visual = preload("res://scripts/water_sort/art/bottle_visual.gd")
const Transfer=preload("res://scripts/water_sort/art/reference3_transfer.gd")
const Stream=preload("res://scripts/water_sort/art/reference3_stream.gd")
const BoardPath=preload("res://scripts/water_sort/art/board_pour_path.gd")
const StaticRoutes=preload("res://scripts/water_sort/art/static_pour_route_cache.gd")
var static_route_cache_hit:=false
var static_route_cache_key:=""
var board_bottles: Array=[]
var board_upper_count:=0
var board_path
var board_origins: Array[Vector2]=[]
var board_approach: Array[Vector4]=[]
var board_return: Array[Vector4]=[]
var board_shift:=0.0
var board_center:=Vector2.ZERO
var board_path_failed:=false
var board_pending:=false
var board_current_shift:=0.0
var board_profiles: Dictionary={}
var board_pose_cache: Dictionary={}
var board_source_shape:=PackedVector2Array()
var board_receiver_shape:=PackedVector2Array()
var board_plan_ms:=0
var board_dock_offset:=0.0 # Short real-lip lateral approach; target never moves.
var board_hud_rect:=Rect2()
var board_fixed_hud:Array=[] # Actual persistent cards/controls, world rectangles.
var board_text_yields:=false # Host must hide its noninteractive strip while busy.
var board_side_crop:=0.0 # Source body only; mouth and water remain on-screen.
var concurrent_animators: Array=[]
var route_delay:=0.0
var board_flow_lift:=0.0
var board_flow_bottom:=INF
var route_uses_front_layer:=false
var board_stream_obstacles: Array=[]
var temporal_candidate_cache:Dictionary={}
var temporal_peer_cache:Dictionary={}
var temporal_horizontal:=Vector2(INF,-INF)
var mass: Dictionary={}
var inflight_units:=0.0
var received_progress:=0.0
var stream_layer: Node2D
var external_stream_layer: Node2D
@export var duration := 0.84
var relaxed_timing:=false
## Order mode matches measured per-unit flow; tutorial/classic retain their timing.
var responsive_timing:=false
var visual_speed:=1.0
var flow_seconds:=0.76
var lift_seconds:=0.18
var align_seconds:=0.32
var return_seconds:=0.34
var surface_finish_sent:=false
## Order mode owns settling/sealing separately. Classic callers keep this default.
var auto_seal := true
@export var travel_lift := 210.0
## Opt in for dense rows / long crossings. Neck-full sources automatically use it.
@export var safe_row_route := false
## Two-row boards may opt in. Upper targets pour above the upper row; lower
## targets pour in the middle band. Plane changes use configured empty columns.
## Defaults deliberately leave the approved three-bottle demo unchanged.
@export var multi_row_route := false
@export var multi_row_ceiling_world_y := 758.0
@export var upper_route_floor_world_y := 460.0
@export var multi_row_transit_lanes_world_x := PackedFloat32Array()
## Optional actual page bounds supplied by the order layout. Classic defaults
## retain their existing route. Body reach comes from the active renderer.
var route_canvas_world_rect := Rect2()
const ROUTE_OUTLINE := [Vector2(-49,-8),Vector2(49,-8),Vector2(49,23),Vector2(43,28),Vector2(43,46),Vector2(58,62),Vector2(73,88),Vector2(73,350),Vector2(68,375),Vector2(50,384),Vector2(-50,384),Vector2(-68,375),Vector2(-73,350),Vector2(-73,88),Vector2(-58,62),Vector2(-43,46),Vector2(-43,28),Vector2(-49,23)]
## Layout-specific spacing; defaults preserve the approved three-bottle demo.
@export var row_clearance_local := 26.0
@export var hover_clearance_local := 417.0
@export var swept_row_clearance_local := 33.0
var wait_for: Array=[]
var busy := false
var paused := false
var phase := "idle"
var elapsed := 0.0
var progress := 0.0
var source: Node2D
var target: Node2D
var source_before: Array = []
var target_before: Array = []
var source_after: Array = []
var target_after: Array = []
var from_bands: Array = []
var to_bands: Array = []
var source_home := Vector2.ZERO
var target_home := Vector2.ZERO
var source_home_rotation := 0.0
var source_home_scale:=Vector2.ONE
var source_home_z := 0
var direction := 1.0
var moved := 0.0
var color_key := ""
var stream_strength := 0.0
var source_start_volume := 0.0
var target_start_volume := 0.0
var splash_time := 0.0
var outlet := Vector2.ZERO
var transaction_duration := 0.84
var needs_target_seal := false
var source_was_sealed := false
var seal_start_time := 0.0
var use_safe_route := false
var _initial_pose: Dictionary = {}
var _final_pose: Dictionary = {}
var _approach_route: Array[Vector2] = []
var _return_route: Array[Vector2] = []
var _multi_raised := Vector2.ZERO
var _multi_dock := Vector2.ZERO
var _multi_return_dock := Vector2.ZERO

func play(from_visual: Node2D, to_visual: Node2D, before_from: Array, before_to: Array, after_from: Array, after_to: Array) -> bool:
	if not performance_profile_enabled:return _play_impl(from_visual,to_visual,before_from,before_to,after_from,after_to)
	var t:=Time.get_ticks_usec();var result:=_play_impl(from_visual,to_visual,before_from,before_to,after_from,after_to);performance_play_us=Time.get_ticks_usec()-t;return result
func _play_impl(from_visual:Node2D,to_visual:Node2D,before_from:Array,before_to:Array,after_from:Array,after_to:Array)->bool:
	if busy or from_visual == to_visual or from_visual.transaction_busy or to_visual.transaction_busy: return false
	var count := before_from.size() - after_from.size()
	if count <= 0 or after_to.size() - before_to.size() != count or after_to.size() > int(to_visual.capacity): return false
	if before_from.is_empty(): return false
	var key := str(before_from[-1])
	for i in range(after_from.size(), before_from.size()):
		if str(before_from[i]) != key: return false
	if before_from.slice(0, after_from.size()) != after_from or after_to.slice(0, before_to.size()) != before_to: return false
	for i in range(before_to.size(), after_to.size()):
		if str(after_to[i]) != key: return false
	if not before_to.is_empty() and str(before_to[-1]) != key: return false
	source = from_visual; target = to_visual
	source_before = before_from.duplicate(); target_before = before_to.duplicate()
	source_after = after_from.duplicate(); target_after = after_to.duplicate()
	from_bands = Visual.to_bands(before_from); to_bands = Visual.to_bands(before_to)
	source_home = source.global_position; target_home = target.global_position
	source_home_rotation = source.rotation; source_home_z = source.z_index
	source_home_scale=source.global_scale
	direction = 1.0 if target_home.x >= source_home.x else -1.0
	# Edge destinations tilt inward. An outward body at these columns would leave
	# the portrait canvas, even though the mouth and stream were still on screen.
	if is_equal_approx(source_home.x,target_home.x) and route_canvas_world_rect.has_area():
		var bounds: Rect2=source.presentation_bounds()
		var reach:=0.0
		for point in [bounds.position,Vector2(bounds.end.x,bounds.position.y),bounds.end,Vector2(bounds.position.x,bounds.end.y)]:
			reach=maxf(reach,point.length()*source.global_scale.x)
		if target_home.x<route_canvas_world_rect.position.x+20.0+reach: direction=-1.0
		elif target_home.x>route_canvas_world_rect.end.x-20.0-reach: direction=1.0
	elif is_equal_approx(source_home.x,target_home.x) and multi_row_route:
		var horizontal_reach := 410.0 * source.global_scale.x
		if target_home.x < 20.0+horizontal_reach: direction=-1.0
		elif target_home.x > 1060.0-horizontal_reach: direction=1.0
	moved = float(count); color_key = key
	surface_finish_sent=false; wait_for.clear()
	board_flow_lift=0.0;board_flow_bottom=INF;route_delay=0.0;route_uses_front_layer=false
	if relaxed_timing:
		lift_seconds=(0.10 if responsive_timing else 0.18)/visual_speed
		align_seconds=(0.16 if responsive_timing else 0.32)/visual_speed
		return_seconds=(0.28 if responsive_timing else 0.34)/visual_speed
		# Fast input shortens transport, never liquid flow or completion feedback.
		flow_seconds=(0.36+0.23*maxf(0.0,moved-1.0)) if responsive_timing else (0.76+0.25*maxf(0.0,moved-1.0))/visual_speed
		duration=lift_seconds+align_seconds+flow_seconds+return_seconds
	source_start_volume = float(before_from.size()); target_start_volume = float(before_to.size())
	source_was_sealed = source.sealed
	needs_target_seal = auto_seal and Visual.complete_layers(after_to,target.capacity)
	seal_start_time = duration*0.80
	transaction_duration = maxf(duration,seal_start_time+Visual.SEAL_DURATION) if needs_target_seal else duration
	use_safe_route = multi_row_route or safe_row_route or Geometry.spill_angle(source_start_volume,source.capacity)<deg_to_rad(50.0)
	target.sync_seal_immediate(false)
	# Committed logical state is available throughout, independently of fractional visuals.
	source.layers = source_after.duplicate(); target.layers = target_after.duplicate()
	source.transaction_busy = true; target.transaction_busy = true
	source.z_index = 8
	# These two poses are constant for this transaction. Do not repeat their
	# polygon/angle solve every frame, especially during long two-row transits.
	if multi_row_route: _prepare_multi_route()
	_initial_pose=_pose_at_volume(source_start_volume)
	_final_pose=_pose_at_volume(source_start_volume-moved)
	board_pending=not board_bottles.is_empty()
	if is_instance_valid(target.delivered_layers):
		if is_instance_valid(stream_layer): stream_layer.queue_free()
		if is_instance_valid(external_stream_layer): external_stream_layer.queue_free()
		stream_layer=Stream.new(); stream_layer.animator=self; stream_layer.z_index=1
		target.delivered_layers.add_child(stream_layer)
		external_stream_layer=Stream.new(); external_stream_layer.animator=self; external_stream_layer.exterior=true; external_stream_layer.z_index=5
		target.delivered_layers.add_child(external_stream_layer)
		# Actual mouth-to-surface distance stretches all cohort phases together.
		var skin=target.delivered_layers
		var surface: Vector2=skin.to_global(Vector2(skin.MOUTH.x,skin.surface_y())-skin.PIVOT)
		var native_distance: float=_initial_pose.outlet.distance_to(surface)/skin.global_scale.x
		if relaxed_timing:
			flow_seconds*=clampf(sqrt(native_distance/220.0),0.9,1.2)
			duration=lift_seconds+align_seconds+flow_seconds+return_seconds
			seal_start_time=duration*0.80
			transaction_duration=maxf(duration,seal_start_time+Visual.SEAL_DURATION) if needs_target_seal else duration
	elapsed = 0.0; progress = 0.0; busy = true; paused = false
	_sample(0.0)
	return true

func remaining_seconds() -> float:
	return maxf(0.0,transaction_duration-elapsed) if busy else 0.0

func set_paused(value: bool) -> void:
	paused = value

func cancel(commit := true) -> void:
	if not busy: return
	_settle(commit)

func _exit_tree() -> void:
	if busy: _settle(true)

func _process(delta: float) -> void:
	if not busy or paused: return
	advance(delta)

## Public deterministic stepping is also used by capture/tests. Pausing never advances mass.
func advance(delta: float) -> void:
	if not busy or paused: return
	if not is_instance_valid(source) or not is_instance_valid(target):
		_settle(true)
		return
	for prior in wait_for:
		if is_instance_valid(prior) and prior.busy:
			_set_phase("waiting")
			return
	wait_for.clear()
	prepare_route()
	if route_delay>0.0:
		route_delay=maxf(0.0,route_delay-delta); _set_phase("route_wait"); return
	elapsed = minf(elapsed + maxf(delta, 0.0), maxf(transaction_duration, 0.01))
	_sample(_sample_time(elapsed))
	if needs_target_seal and elapsed>=seal_start_time:
		target.sample_seal(1.0 if elapsed>=transaction_duration else (elapsed-seal_start_time)/Visual.SEAL_DURATION)
		if elapsed>=duration: _set_phase("seal")
	if elapsed >= maxf(transaction_duration, 0.01): _settle(true)

func prepare_route() -> void:
	if not board_pending: return
	_prepare_board_path(); board_pending=false

func planned_configuration(seconds: float) -> Vector4:
	if board_approach.is_empty() or board_return.is_empty():return _configuration({"position":source_home,"angle":source_home_rotation},0)
	var t:=_sample_time(clampf(seconds,0,transaction_duration))
	var end:=0.68 if multi_row_route else 0.76
	if t<0.36: return board_path.sample(board_approach,smooth(t/0.36))
	if t<end:
		var amount:float=Transfer.emitted(clampf((t-0.36)/(end-0.36),0,1))
		return _configuration(_board_pose(source_start_volume-moved*amount,0),0)
	return board_path.sample(board_return,smooth((t-end)/(1-end)))

func temporal_sample(seconds:float)->Dictionary:
	var pose:=planned_configuration(seconds)
	var bounds:Rect2=Transform2D(pose.z,Vector2(pose.x,pose.y))*Rect2(source.presentation_bounds().position*source.global_scale.x-board_center,source.presentation_bounds().size*source.global_scale.x)
	var stream:=PackedVector2Array()
	var stream_box:=Rect2()
	var t:=_sample_time(seconds);var end:=0.68 if multi_row_route else 0.76
	if t>0.36 and t<end:
		var pivot:=Vector2(pose.x,pose.y)-board_center.rotated(pose.z)
		stream=PackedVector2Array([pivot+(source.flow_lip(direction)*source.global_scale.x).rotated(pose.z),target.mouth_world()])
		stream_box=Rect2(stream[0],Vector2.ZERO).expand(stream[1]).grow(.001)
	return {"pose":pose,"bounds":bounds,"stream":stream,"stream_box":stream_box}

## Conservative horizontal sweep: translation and rotation ranges are combined
## independently, so disjoint intervals prove that neither glass nor stream can
## intersect at any time. Overlapping ranges still use the exact temporal test.
static func rotated_x_range(point:Vector2,first:float,last:float)->Vector2:
	var low:=minf(first,last);var high:=maxf(first,last)
	var a:=point.rotated(low).x;var b:=point.rotated(high).x
	var result:=Vector2(minf(a,b),maxf(a,b))
	var extremum:float=-atan2(point.y,point.x)
	for turn in range(floori((low-extremum)/PI),ceili((high-extremum)/PI)+1):
		var angle:float=extremum+turn*PI
		if angle>=low and angle<=high:
			var x:=point.rotated(angle).x;result.x=minf(result.x,x);result.y=maxf(result.y,x)
	return result

func route_x_range()->Vector2:
	var bounds:=Vector2(INF,-INF)
	for path in [board_approach,board_return]:
		for i in range(1,path.size()):
			var a:Vector4=path[i-1];var b:Vector4=path[i]
			for point in board_path.outline:
				var span:=rotated_x_range(point,a.z,b.z)
				bounds.x=minf(bounds.x,minf(a.x,b.x)+span.x)
				bounds.y=maxf(bounds.y,maxf(a.x,b.x)+span.y)
	var first:float=source.flow_angle(maxf(source_start_volume,.006))*direction
	var last:float=source.flow_angle(maxf(source_start_volume-moved,.006))*direction
	var mouth:Vector2=target.mouth_world();var lip:Vector2=source.flow_lip(direction)
	for point in board_source_shape:
		var span:=rotated_x_range((point-lip)*source.global_scale.x,first,last)
		bounds.x=minf(bounds.x,mouth.x+board_dock_offset+span.x);bounds.y=maxf(bounds.y,mouth.x+board_dock_offset+span.y)
	bounds.x=minf(bounds.x,mouth.x);bounds.y=maxf(bounds.y,mouth.x)
	return bounds

func route_overlaps_active(delay: float=0.0,reuse_candidate:bool=false) -> bool:
	if not performance_profile_enabled:return _route_overlaps_active_impl(delay,reuse_candidate)
	var t:=Time.get_ticks_usec();var result:=_route_overlaps_active_impl(delay,reuse_candidate);plan_profile.temporal_calls+=1;plan_profile.temporal_us+=Time.get_ticks_usec()-t;return result
func _route_overlaps_active_impl(delay:float=0.0,reuse_candidate:bool=false)->bool:
	if not reuse_candidate:
		temporal_candidate_cache.clear();temporal_horizontal=route_x_range()
	var delay_ticks:=roundi(delay/0.01)
	var horizontal:=temporal_horizontal
	for other in concurrent_animators:
		if not is_instance_valid(other) or not other.busy or not is_instance_valid(other.board_path): continue
		var peer_horizontal:Vector2=other.temporal_horizontal
		if horizontal.y<peer_horizontal.x-.001 or peer_horizontal.y<horizontal.x-.001:continue
		var id:int=other.get_instance_id()
		if not temporal_peer_cache.has(id):temporal_peer_cache[id]={}
		var peer_samples:Dictionary=temporal_peer_cache[id]
		# Both paths share one clock. Cache immutable poses across the bounded
		# offset search; a broad phase avoids unnecessary polygon intersections.
		var end:float=maxf(transaction_duration+delay,other.remaining_seconds()+other.route_delay)
		for i in ceili(end/0.01)+1:
			var tick:=clampi(i-delay_ticks,0,ceili(transaction_duration/.01))
			var peer_tick:=mini(i,ceili((other.remaining_seconds()+other.route_delay)/.01))
			if not temporal_candidate_cache.has(tick):temporal_candidate_cache[tick]=temporal_sample(tick*.01)
			if not peer_samples.has(peer_tick):peer_samples[peer_tick]=other.temporal_sample(other.elapsed+maxf(0,peer_tick*.01-other.route_delay))
			var a:Dictionary=temporal_candidate_cache[tick];var b:Dictionary=peer_samples[peer_tick]
			if not a.bounds.intersects(b.bounds) and not a.stream_box.intersects(b.bounds) and not b.stream_box.intersects(a.bounds):continue
			if not a.has("polygon"):a.polygon=board_path.polygon(a.pose)
			if not b.has("polygon"):b.polygon=other.board_path.polygon(b.pose)
			if not Geometry2D.intersect_polygons(a.polygon,b.polygon).is_empty():return true
			if segment_hits_polygon(a.stream,b.polygon) or segment_hits_polygon(b.stream,a.polygon):return true
	return false

func planned_stream(seconds:float)->PackedVector2Array:
	var t:=_sample_time(seconds)
	var end:=0.68 if multi_row_route else 0.76
	if t<=0.36 or t>=end:return PackedVector2Array()
	var pose:=planned_configuration(seconds)
	var pivot:=Vector2(pose.x,pose.y)-board_center.rotated(pose.z)
	return PackedVector2Array([pivot+(source.flow_lip(direction)*source.global_scale.x).rotated(pose.z),target.mouth_world()])

static func segment_hits_polygon(line:PackedVector2Array,shape:PackedVector2Array)->bool:
	if line.size()!=2:return false
	if Geometry2D.is_point_in_polygon(line[0],shape) or Geometry2D.is_point_in_polygon(line[1],shape):return true
	for i in shape.size():
		if Geometry2D.segment_intersects_segment(line[0],line[1],shape[i],shape[(i+1)%shape.size()])!=null:return true
	return false

func stream_hits_parked(pose:Dictionary)->bool:
	var line:=PackedVector2Array([pose.outlet,target.mouth_world()])
	# A peer can reserve a higher pouring lane; the stream still ends at the
	# actual receiver mouth and passes the same full obstacle/temporal checks.
	# Preserve a bounded external stream: 80 canvas units solo, 128 with peers,
	# at most 192 for a lateral edge dock (69px at 390px width).
	# This includes receiver clearance throughout a mixed full bottle's transfer.
	# All collision tests remain mandatory; the receiver mouth never moves.
	var stream_limit:=80.0 if concurrent_animators.is_empty() else 128.0
	# Boundary-derived lateral docks need a short diagonal fall, not a taller lane.
	if absf(board_dock_offset)>36.0*route_canvas_world_rect.size.x/1080.0:stream_limit=192.0
	if board_text_yields and line[0].distance_to(line[1])>stream_limit*route_canvas_world_rect.size.x/1080.0:return true
	if board_side_crop>0 and (not route_canvas_world_rect.has_point(line[0]) or not route_canvas_world_rect.has_point(line[1])):return true
	for item in board_stream_obstacles:
		if segment_hits_polygon(line,item.polygon):return true
	return false

static func smooth(value: float) -> float:
	var t := clampf(value, 0.0, 1.0)
	return t*t*(3.0-2.0*t)

func _set_phase(value: String) -> void:
	if phase != value:
		phase = value
		phase_changed.emit(value)

func _pose_at_volume(units: float) -> Dictionary:
	if is_instance_valid(board_path): return _board_pose(units,board_shift)
	var angle: float=source.flow_angle(maxf(units,0.006))*direction
	# The lower lip is locked above the actual target mouth. No wall-crossing stream.
	var scale_factor := source.global_scale.x
	var lowest := -INF
	var outline: PackedVector2Array=source.delivered_layers.presentation_outline() if is_instance_valid(source.delivered_layers) else source.flow_cavity()
	for point in outline: lowest = maxf(lowest, point.rotated(angle).y)
	var lip: Vector2=source.flow_lip(direction)
	var lower_lip_y := lip.rotated(angle).y
	# Clear every standing bottle on the row, including a non-participating bottle
	# between source and target. The body never clips through its neighbour's mouth.
	var clearance:=row_clearance_local
	if is_instance_valid(source.delivered_layers): clearance=maxf(58.0,18.0+30.0/scale_factor) if route_canvas_world_rect.has_area() else 58.0
	var air_gap := maxf(82.0, lowest - lower_lip_y + clearance) * scale_factor
	var mouth: Vector2 = target.mouth_world()
	var end: Vector2 = mouth + Vector2(0, -air_gap)
	var lip_offset := lip.rotated(angle)*scale_factor
	var position := end-lip_offset
	if multi_row_route:
		position=_clamp_multi_position(position,angle)
		end=position+lip_offset
	return {"angle": angle, "position": position, "outlet": end}

func _board_pose(units: float,_shift: float) -> Dictionary:
	if not performance_profile_enabled:return _board_pose_impl(units,_shift)
	var t:=Time.get_ticks_usec();var result:=_board_pose_impl(units,_shift);performance_board_pose_us+=Time.get_ticks_usec()-t;performance_board_pose_calls+=1;return result
func _board_pose_impl(units:float,_shift:float)->Dictionary:
	var profile_key:=Vector2(units,direction)
	if not board_profiles.has(profile_key):
		# The layout reserves room for the actual volume-dependent spill angle.
		var perf_begin:=Time.get_ticks_usec() if performance_profile_enabled else 0
		var theta: float=source.flow_angle(maxf(units,0.006))*direction
		if performance_profile_enabled:performance_spill_us+=Time.get_ticks_usec()-perf_begin
		board_profiles[profile_key]={"angle":theta,"lip":source.flow_lip(direction)*source.global_scale.x}
	var profile: Dictionary=board_profiles[profile_key]
	var angle: float=profile.angle; var lip: Vector2=profile.lip
	# The existing profile cache already fixes the angle for this exact engine
	# profile key. Volumes resolving to that same angle produce the same pose;
	# avoid repeating receiver clipping without introducing new quantization.
	var pose_key:Array=[angle,direction,board_flow_lift,board_flow_bottom,board_dock_offset]
	if board_pose_cache.has(pose_key):return board_pose_cache[pose_key]
	# The receiving mouth is the actual target node, never a translated proxy.
	var mouth:Vector2=target.mouth_world()
	var gap:=route_canvas_world_rect.size.x/1080.0*8.0
	# Dock by the receiving mouth and actual receiver outline. The old rule
	# lifted the entire rotated body above the mouth, reserving a whole empty row.
	# A source body may extend beside the receiver, never through its glass.
	var pivot:=mouth+Vector2(board_dock_offset,-gap-board_flow_lift)-lip.rotated(angle)
	var receiver: PackedVector2Array=board_receiver_shape
	var source_shape: PackedVector2Array=board_source_shape
	var perf_receiver_begin:=Time.get_ticks_usec() if performance_profile_enabled else 0
	for attempt in 100:
		var candidate:=Transform2D(angle,pivot).scaled_local(source.global_scale)*source_shape
		if Geometry2D.intersect_polygons(candidate,receiver).is_empty(): break
		pivot.y-=4.0*route_canvas_world_rect.size.x/1080.0
	if performance_profile_enabled:performance_receiver_us+=Time.get_ticks_usec()-perf_receiver_begin
	if is_finite(board_flow_bottom):
		var lowest:float=-INF
		for point in source_shape:lowest=maxf(lowest,(point*source.global_scale.x).rotated(angle).y)
		pivot.y=minf(pivot.y,board_flow_bottom-lowest)
	var result:Dictionary={"angle":angle,"position":pivot,"outlet":pivot+lip.rotated(angle)}
	board_pose_cache[pose_key]=result
	return result

func _configuration(pose: Dictionary,shift: float) -> Vector4:
	var center: Vector2=pose.position+board_center.rotated(pose.angle)
	return Vector4(center.x,center.y,pose.angle,shift)

func _facing_candidates(preferred:float,reverse_first:bool=false)->Array[float]:
	# Navigation must not swap the source across the receiver to find a route.
	# Only equal-x slots may try both directions. Geometry/temporal tests still apply.
	if not is_equal_approx(source_home.x,target_home.x):
		return [1.0 if target_home.x>source_home.x else -1.0]
	return [-preferred,preferred] if reverse_first else [preferred,-preferred]

func _directional_dock_offsets(scale_world:float)->Array:
	var offsets:Array=[0,-12,12,-24,24,-36,36] if concurrent_animators.is_empty() else [0,-96,96,-48,48]
	if not board_text_yields:return [0]
	# Derive the minimum lateral clearance from the entire visible bottle at
	# every pouring pose. This does not clamp animation after collision planning.
	var old_offset:=board_dock_offset
	board_dock_offset=0.0
	var lower:=-INF;var upper:=INF
	for i in 25:
		var pose:=_board_pose(source_start_volume-moved*i/24.0,0)
		var conf:=_configuration(pose,0)
		var box:Rect2=board_path.geometry_at(conf.z).page_box
		box.position+=Vector2(conf.x,conf.y)
		lower=maxf(lower,board_path.bounds.position.x+4.0*scale_world-box.position.x)
		upper=minf(upper,board_path.bounds.end.x-4.0*scale_world-box.end.x)
	board_dock_offset=old_offset
	if lower<=upper:
		var needed:=clampf(0.0,lower,upper)/scale_world
		if absf(needed)>.001 and absf(needed)<=128.0:offsets.append(needed)
	return offsets

func route_candidate()->Dictionary:
	return {"direction":direction,"lift":board_flow_lift,"bottom":board_flow_bottom,"dock":board_dock_offset,"front":route_uses_front_layer,"approach":board_approach.duplicate(),"return_path":board_return.duplicate(),"first":_board_pose(source_start_volume,0),"last":_board_pose(source_start_volume-moved,0)}

func _prepare_board_path() -> void:
	var planning_start:=Time.get_ticks_msec()
	if performance_profile_enabled:
		_perf_last_us=Time.get_ticks_usec();plan_profile={"stages_us":{},"temporal_us":0,"temporal_calls":0}
		_perf_pose_start_us=performance_board_pose_us;_perf_pose_start_calls=performance_board_pose_calls
	var requested_direction:=direction
	temporal_candidate_cache.clear();temporal_peer_cache.clear()
	board_path=BoardPath.new(); board_origins.clear(); board_approach.clear(); board_return.clear()
	board_path.profile_enabled=performance_profile_enabled
	board_pose_cache.clear()
	board_source_shape=source.delivered_layers.presentation_outline()
	board_receiver_shape=target.global_transform*target.delivered_layers.presentation_outline()
	board_shift=0; board_current_shift=0; board_dock_offset=0; board_path_failed=false; board_profiles.clear()
	board_center=Vector2(0,185)*source.global_scale.x
	var shape: PackedVector2Array=source.delivered_layers.presentation_outline().duplicate()
	for i in shape.size(): shape[i]=shape[i]*source.global_scale.x-board_center
	var obstacles: Array=[]
	var upper_top:=INF; var upper_bottom:=-INF; var lower_top:=INF
	for i in board_bottles.size():
		var node=board_bottles[i]; board_origins.append(node.global_position)
		if not node.visible: continue
		var visual=node.visual
		var poly: PackedVector2Array=visual.global_transform*visual.delivered_layers.presentation_outline()
		# A peer will return to its captured home. Plan around that reserved seat,
		# never around a transient rotation captured halfway through its motion.
		for other in concurrent_animators:
			if is_instance_valid(other) and other.busy and other.source==visual:
				poly=Transform2D(other.source_home_rotation,other.source_home).scaled_local(other.source_home_scale)*visual.delivered_layers.presentation_outline()
		var box:=Rect2(poly[0],Vector2.ZERO)
		for p in poly: box=box.expand(p)
		if i<board_upper_count: upper_top=minf(upper_top,box.position.y); upper_bottom=maxf(upper_bottom,box.end.y)
		else: lower_top=minf(lower_top,box.position.y)
		if visual!=source: obstacles.append({"polygon":poly,"rect":box,"upper":i<board_upper_count,"receiver":visual==target})
	var scale_world:=route_canvas_world_rect.size.x/1080.0
	var area:=route_canvas_world_rect
	area.position.y=upper_route_floor_world_y; area.size.y=route_canvas_world_rect.position.y+1690*scale_world-area.position.y
	# Returning glass must fit the real page, not the old offscreen side pocket.
	# The existing envelope/swept checks reject an outward turn and select another
	# dock/corridor through the same planner. Never clamp a rendered pose afterward:
	# that would invalidate the collision/stream trajectory which was preflighted.
	var row_range:=Vector2.ZERO
	var layout=preload("res://scripts/water_sort/order_gameplay_layout.gd")
	board_hud_rect=Rect2(route_canvas_world_rect.position+layout.TEXT_EXCLUSION.position*scale_world,layout.TEXT_EXCLUSION.size*scale_world)
	var hud_polygon:=PackedVector2Array([board_hud_rect.position,Vector2(board_hud_rect.end.x,board_hud_rect.position.y),board_hud_rect.end,Vector2(board_hud_rect.position.x,board_hud_rect.end.y)])
	var hud_obstacles:Array=[]
	if not board_text_yields:hud_obstacles.append({"polygon":hud_polygon,"rect":board_hud_rect,"upper":false,"fixed_hud":true})
	for rect in board_fixed_hud:
		var polygon:=PackedVector2Array([rect.position,Vector2(rect.end.x,rect.position.y),rect.end,Vector2(rect.position.x,rect.end.y)])
		hud_obstacles.append({"polygon":polygon,"rect":rect,"upper":false,"fixed_hud":true})
	obstacles.append_array(hud_obstacles)
	board_stream_obstacles=obstacles.filter(func(item):return not item.get("receiver",false))
	# Only the source travels. Target and spectators keep their original slots.
	board_path.configure(shape,obstacles,area,48*scale_world,row_range)
	board_path.sweep_step=2.64*scale_world
	board_path.allow_grid=false
	board_path.upper_bottom=upper_bottom if is_finite(upper_bottom) else 0.0
	board_path.lower_top=lower_top if is_finite(lower_top) else 0.0
	# Preserve every visible pixel, without treating transparent texture corners
	# as glass. This changes neither receiver/HUD nor stream collision checks.
	for point in source.delivered_layers.presentation_envelope_outline():board_path.envelope.append(point*source.global_scale.x-board_center)
	var start:=_configuration({"position":source_home,"angle":source_home_rotation},0)
	_perf_mark("geometry_setup")
	# Exact serialized geometry/volume key: any changed bound, envelope, static
	# glass, HUD, scale, source or receiver invalidates this proof. Peer motion
	# is intentionally absent and always checked afresh before admission.
	var static_key:=StaticRoutes.key(["source-side-v1",start,source_start_volume,target_start_volume,moved,requested_direction,board_path.outline,board_path.envelope,obstacles,area,row_range,board_path.step,board_path.sweep_step,board_text_yields,board_upper_count,board_receiver_shape,not concurrent_animators.is_empty()])
	var cached:Dictionary=StaticRoutes.fetch(static_key)
	static_route_cache_key=static_key
	var peer_proofs:Array=[]
	for peer in concurrent_animators:
		peer_proofs.append([peer.source_home,peer.source_home_rotation,peer.source_home_scale,peer.source_start_volume,peer.target_start_volume,peer.moved,peer.target.mouth_world(),peer.direction,peer.board_flow_lift,peer.board_flow_bottom,peer.board_dock_offset,peer.board_approach,peer.board_return,peer.transaction_duration,peer.elapsed,peer.route_delay,peer.board_source_shape,peer.board_path.outline,peer.board_path.envelope,peer.multi_row_route,peer.relaxed_timing,peer.responsive_timing,peer.visual_speed])
	var rejection_key:=StaticRoutes.key([static_key,transaction_duration,visual_speed,multi_row_route,relaxed_timing,responsive_timing,peer_proofs])
	_perf_mark("cache_key_build")
	if not peer_proofs.is_empty() and StaticRoutes.was_rejected(rejection_key):
		board_path_failed=true;board_plan_ms=Time.get_ticks_msec()-planning_start;_perf_finish();return
	static_route_cache_hit=false
	if not cached.is_empty() and float(cached.direction) in _facing_candidates(requested_direction):
		direction=cached.direction;board_flow_lift=cached.lift;board_flow_bottom=cached.bottom;board_dock_offset=cached.dock;route_uses_front_layer=cached.front
		board_approach=cached.approach;board_return=cached.return_path
		if cached.front:board_path.obstacles=obstacles.filter(func(item):return item.get("receiver",false) or item.get("fixed_hud",false))
		if not route_overlaps_active():
			_initial_pose=cached.first;_final_pose=cached.last;static_route_cache_hit=true;board_plan_ms=Time.get_ticks_msec()-planning_start;_perf_finish();return
		board_path.obstacles=obstacles;direction=requested_direction;board_flow_lift=0;board_flow_bottom=INF;board_dock_offset=0;route_uses_front_layer=false
	var candidates: Array[float]=[0.0]
	_perf_mark("cache_admission")
	var found:=false
	var flow_candidates:=0
	var valid_candidates:Array=[]
	for shift in candidates:
		if shift<row_range.x or shift>row_range.y: continue
		var clear:=true
		for i in 25:
			var pose:=_board_pose(source_start_volume-moved*i/24.0,shift)
			if not board_path.clear(_configuration(pose,shift)) or stream_hits_parked(pose): clear=false; break
		if not clear: continue
		flow_candidates+=1
		var first:=_board_pose(source_start_volume,shift)
		board_approach=board_path.route(start,_configuration(first,shift))
		if board_approach.is_empty(): continue
		board_return=board_path.route(_configuration(_board_pose(source_start_volume-moved,shift),shift),start)
		if board_return.is_empty(): continue
		board_shift=shift; _initial_pose=first; _final_pose=_board_pose(source_start_volume-moved,shift); found=true; break
	if found:
		valid_candidates.append(route_candidate())
		if route_overlaps_active():found=false
	_perf_mark("primary_route_search")
	if not found:
		# Try the established foreground route before an expensive all-glass
		# grid search. This retains the receiver/HUD and full moving-peer and
		# stream checks; parked glass keeps the existing presentation contract.
		var parked_obstacles:Array=board_path.obstacles
		board_path.obstacles=obstacles.filter(func(item):return item.get("receiver",false) or item.get("fixed_hud",false))
		# Short lateral docks first; only small raised alternatives. An unseen
		# conflict waits safely instead of manufacturing an unapproved long column.
		for fore_lift in ([0,48,96] if not concurrent_animators.is_empty() else [0]):
			board_flow_lift=float(fore_lift)*scale_world
			for facing in _facing_candidates(requested_direction,not concurrent_animators.is_empty()):
				direction=facing
				# Try the same safe short docks already supported by the final fallback
				# before paying for a grid search around every parked bottle.
				for offset in _directional_dock_offsets(scale_world):
					board_dock_offset=float(offset)*scale_world
					var safe:=true
					for i in 25:
						var pose:=_board_pose(source_start_volume-moved*i/24.0,0)
						if not board_path.clear(_configuration(pose,0)) or stream_hits_parked(pose):safe=false;break
					if not safe:continue
					board_approach=board_path.route(start,_configuration(_board_pose(source_start_volume,0),0))
					if board_approach.is_empty():continue
					board_return=board_path.route(_configuration(_board_pose(source_start_volume-moved,0),0),start)
					if board_return.is_empty():continue
					# A geometrically safe foreground route can conflict only in time.
					# Retain it for the same bounded temporal-offset search as all-glass
					# candidates, rather than dropping it until the peer finishes.
					route_uses_front_layer=true
					valid_candidates.append(route_candidate())
					if route_overlaps_active():
						var original_approach:Array[Vector4]=board_approach
						var original_return:Array[Vector4]=board_return
						var alternate_approach:Array[Vector4]=board_path.aligned_turn_route(start,_configuration(_board_pose(source_start_volume,0),0),true,true)
						var alternate_return:Array[Vector4]=board_path.aligned_turn_route(_configuration(_board_pose(source_start_volume-moved,0),0),start,true,true)
						var peer_clear:=false
						for approach in [alternate_approach,original_approach]:
							if approach.is_empty():continue
							for returning in [alternate_return,original_return]:
								if returning.is_empty():continue
								board_approach=approach;board_return=returning
								valid_candidates.append(route_candidate())
								if not route_overlaps_active():peer_clear=true;break
							if peer_clear:break
						if not peer_clear:route_uses_front_layer=false;continue
					_initial_pose=_board_pose(source_start_volume,0);_final_pose=_board_pose(source_start_volume-moved,0)
					route_uses_front_layer=true;found=true;break
				if found:break
			if found:break
		if not found:
			board_path.obstacles=parked_obstacles;board_dock_offset=0.0
	_perf_mark("foreground_search")
	if not found:
		# Try real mouth-aligned elevated docks with all parked glass retained.
		# A longer vertical free-falling stream is preferable to glass intersecting
		# a neighbour. Neither the receiver nor the board moves for this route.
		var preferred_direction:=requested_direction
		# Active peers use bounded, swept-validated candidates. If none fit,
		# the intention waits for their release; exhaustive grid exploration is
		# reserved for the retry with no moving peer, never an input-time stall.
		board_path.allow_grid=concurrent_animators.is_empty()
		for elevation in [-1,0,60,120,180,240,300,360,420,480,540,600,660]:
			board_flow_bottom=upper_top-8*scale_world if elevation<0 else INF
			board_flow_lift=maxf(0,float(elevation))*scale_world
			for facing in _facing_candidates(preferred_direction):
				direction=facing
				var safe:=true
				for i in 25:
					if not board_path.clear(_configuration(_board_pose(source_start_volume-moved*i/24.0,0),0)) or stream_hits_parked(_board_pose(source_start_volume-moved*i/24.0,0)):safe=false;break
				if not safe:continue
				var first:=_board_pose(source_start_volume,0)
				board_approach=board_path.route(start,_configuration(first,0))
				if board_approach.is_empty():continue
				board_return=board_path.route(_configuration(_board_pose(source_start_volume-moved,0),0),start)
				if board_return.is_empty():continue
				valid_candidates.append(route_candidate())
				if route_overlaps_active():continue
				_initial_pose=first;_final_pose=_board_pose(source_start_volume-moved,0);found=true;break
			if found:break
	_perf_mark("elevated_search")
	if not found and not concurrent_animators.is_empty():
		# Re-run only geometrically valid candidates with a bounded start offset.
		# This reserves a crossing corridor, never the whole board/receipt phase.
		var latest:=0.0
		for other in concurrent_animators:
			if is_instance_valid(other):latest=maxf(latest,other.remaining_seconds()+other.route_delay)
		var best_delay:=INF
		var chosen:Dictionary={}
		for candidate in valid_candidates:
			direction=candidate.direction;board_flow_lift=candidate.lift;board_flow_bottom=candidate.bottom
			board_dock_offset=candidate.dock;route_uses_front_layer=candidate.front
			board_approach=candidate.approach;board_return=candidate.return_path
			temporal_candidate_cache.clear();temporal_horizontal=route_x_range()
			# Reuse each geometrically validated route. Only its start offset
			# changes; all temporal collision checks stay at the original10ms.
			for delay_tick in range(1,ceili(minf(latest,best_delay)/.10)+2):
				var delay:=delay_tick*.10
				if delay>=best_delay:break
				if route_overlaps_active(delay,true):continue
				for refine in range(1,5):
					var shorter:float=(delay_tick-1)*.10+refine*.02
					if not route_overlaps_active(shorter,true):delay=shorter;break
				best_delay=delay;chosen=candidate;break
		if not chosen.is_empty():
			direction=chosen.direction;board_flow_lift=chosen.lift;board_flow_bottom=chosen.bottom
			board_dock_offset=chosen.dock;route_uses_front_layer=chosen.front
			board_approach=chosen.approach;board_return=chosen.return_path
			route_delay=best_delay;_initial_pose=chosen.first;_final_pose=chosen.last;found=true
			# Publish the chosen sweep, never the last rejected candidate's cache.
			temporal_candidate_cache.clear();temporal_peer_cache.clear();temporal_horizontal=route_x_range()
	_perf_mark("delay_search")
	if not found and concurrent_animators.is_empty():
		board_flow_lift=0.0;board_flow_bottom=INF
		route_uses_front_layer=true
		# In a 2D board the selected source may travel IN FRONT of parked glass.
		# Never move spectators to manufacture a corridor. The receiver remains
		# an obstacle throughout, and the page/HUD bounds remain mandatory.
		var receiver_obstacles: Array=[]
		var target_shape: PackedVector2Array=target.global_transform*target.delivered_layers.presentation_outline()
		var target_box:=Rect2(target_shape[0],Vector2.ZERO)
		for point in target_shape: target_box=target_box.expand(point)
		receiver_obstacles.append({"polygon":target_shape,"rect":target_box,"upper":false})
		receiver_obstacles.append_array(hud_obstacles)
		board_path.obstacles=receiver_obstacles
		# Test both physical tilt directions at the real target mouth. Layout
		# provides rotation clearance; never bridge an invalid dock with a pipe.
		var preferred_direction:=requested_direction
		for grid_enabled in ([false,true] if concurrent_animators.is_empty() else [false]):
			board_path.allow_grid=grid_enabled
			for facing in _facing_candidates(preferred_direction):
				direction=facing
				for dock in _directional_dock_offsets(scale_world):
					board_dock_offset=float(dock)*scale_world;board_flow_lift=0.0
					var safe:=true
					for i in 25:
						if not board_path.clear(_configuration(_board_pose(source_start_volume-moved*i/24.0,0),0)) or stream_hits_parked(_board_pose(source_start_volume-moved*i/24.0,0)): safe=false; break
					if not safe: continue
					var first:=_board_pose(source_start_volume,0)
					board_approach=board_path.route(start,_configuration(first,0))
					if board_approach.is_empty(): continue
					board_return=board_path.route(_configuration(_board_pose(source_start_volume-moved,0),0),start)
					if not board_return.is_empty() and not route_overlaps_active():
						_initial_pose=first; _final_pose=_board_pose(source_start_volume-moved,0); found=true; break
				if found: break
			if found: break
	if not found:
		board_path_failed=true
		if not concurrent_animators.is_empty():StaticRoutes.reject(rejection_key)
		if concurrent_animators.is_empty():push_error("No full-size collision-free board route found: "+str({"source":board_bottles.find(source.get_parent()),"target":board_bottles.find(target.get_parent()),"candidates":flow_candidates,"nodes":board_path.expanded,"range":row_range,"angle":source.flow_angle(maxf(0.006,source_start_volume-moved))}))
	if found:StaticRoutes.put(static_key,route_candidate())
	board_plan_ms=Time.get_ticks_msec()-planning_start
	_perf_finish()

func _apply_board_configuration(value: Vector4) -> void:
	board_current_shift=value.w
	source.global_rotation=value.z
	source.global_position=Vector2(value.x,value.y)-board_center.rotated(value.z)

func _travel_anchor(start: Vector2, start_angle: float, finish: Vector2, finish_angle: float, p: float, angle: float) -> Vector2:
	var center := Vector2(0,185.0) * source.global_scale.x
	var from_center := start + center.rotated(start_angle)
	var to_center := finish + center.rotated(finish_angle)
	# Nearly-empty bottles rotate past horizontal; their returning base swings
	# farther toward the adjacent column and needs a little extra clearance.
	var extra_lift := maxf(0.0, rad_to_deg(absf(finish_angle-start_angle))-90.0)*2.0
	return from_center.lerp(to_center,p) - center.rotated(angle) + Vector2(0,-(travel_lift+extra_lift)*source.global_scale.x*sin(p*PI))

func _route_ceiling() -> float:
	return target_home.y if multi_row_route else minf(source_home.y,target_home.y)

func _hover_home() -> Vector2:
	return Vector2(source_home.x,_route_ceiling()-hover_clearance_local*source.global_scale.x)

func _target_hover() -> Vector2:
	return _multi_dock if multi_row_route else Vector2(target_home.x,_hover_home().y)

func _clamp_multi_position(position: Vector2, angle: float) -> Vector2:
	var low:=INF
	var high:=-INF
	var outline: PackedVector2Array=source.delivered_layers.presentation_outline() if is_instance_valid(source.delivered_layers) else PackedVector2Array(ROUTE_OUTLINE)
	for point in outline:
		var y: float=point.rotated(angle).y*source.global_scale.x
		low=minf(low,y);high=maxf(high,y)
	var floor_y:=upper_route_floor_world_y
	if target_home.y>multi_row_ceiling_world_y+100.0:
		floor_y=multi_row_ceiling_world_y+384.0*source.global_scale.x+3.25
	var bottom_y:=target_home.y-(18.0*source.global_scale.x+30.0 if is_instance_valid(source.delivered_layers) else 27.0*source.global_scale.x)-3.25
	position.y=clampf(position.y,floor_y-low,bottom_y-high)
	return position

func _prepare_multi_route() -> void:
	var hover_offset:=hover_clearance_local*source.global_scale.x
	var target_hover_y:=target_home.y-hover_offset
	_multi_dock=Vector2(target_home.x-direction*110.0,target_hover_y)
	var points: Array[Vector2]=[]
	var source_lower:=source_home.y>multi_row_ceiling_world_y+100.0
	var target_upper:=target_home.y<multi_row_ceiling_world_y+100.0
	if source_lower and target_upper:
		var middle_y:=source_home.y-hover_offset
		points.append(Vector2(source_home.x,middle_y))
		var lane:=source_home.x
		var best:=INF
		for candidate in multi_row_transit_lanes_world_x:
			var cost: float=absf(candidate-source_home.x)+absf(candidate-_multi_dock.x)
			if cost<best: best=cost;lane=candidate
		if absf(lane-source_home.x)>0.01: points.append(Vector2(lane,middle_y))
		points.append(Vector2(lane,target_hover_y))
	else:
		# A top-row source descends through its own now-empty column. A lower
		# source only rises into the middle band for another lower target.
		points.append(Vector2(source_home.x,target_hover_y))
	points.append(_multi_dock)
	_multi_raised=source_home.lerp(points[0],0.42)
	_approach_route=[_multi_raised]
	for point in points: _approach_route.append(point)
	_multi_return_dock=_multi_dock
	_return_route=[]
	if not source_lower and not target_upper and absf(source_home.x-target_home.x)<1.0:
		# An aligned upper source must rise out of the lower cork's column
		# before its descent begins. Combine the short return-to-column with
		# rotation, rather than stopping under the descending cork first.
		_multi_return_dock=points[0]
		_return_route=[_multi_return_dock,source_home]
	else:
		for i in range(points.size()-1,-1,-1): _return_route.append(points[i])
		_return_route.append(source_home)

func _route_point(points: Array[Vector2], value: float) -> Vector2:
	var length:=0.0
	for i in range(1,points.size()): length+=points[i-1].distance_to(points[i])
	var distance:=clampf(value,0,1)*length
	for i in range(1,points.size()):
		var segment:=points[i-1].distance_to(points[i])
		if distance<=segment and segment>0.0001: return points[i-1].lerp(points[i],smooth(distance/segment))
		distance-=segment
	return points[-1]

func _clear_row_center(start: Vector2, start_angle: float, finish: Vector2, finish_angle: float, p: float) -> Vector2:
	var center := Vector2(0,185.0)*source.global_scale.x
	var angle := lerpf(start_angle,finish_angle,p)
	var position := (start+center.rotated(start_angle)).lerp(finish+center.rotated(finish_angle),p)-center.rotated(angle)
	# Maintain a true swept-body ceiling, not just a high mouth trajectory.
	var lowest := -INF
	for point in [Vector2(-49,-8),Vector2(49,-8),Vector2(-73,88),Vector2(73,88),Vector2(-73,350),Vector2(73,350),Vector2(-50,384),Vector2(50,384)]:
		lowest = maxf(lowest,point.rotated(angle).y)
	if multi_row_route: return _clamp_multi_position(position,angle)
	position.y = minf(position.y,_route_ceiling()-(lowest+swept_row_clearance_local)*source.global_scale.x)
	return position

func _sample_time(seconds: float) -> float:
	if not relaxed_timing: return minf(seconds/maxf(duration,0.01),1.0)
	var clock:=seconds
	var end:=0.68 if multi_row_route else 0.76
	var travel_end:=lift_seconds+align_seconds
	if clock<lift_seconds: return 0.12*clock/lift_seconds
	if clock<travel_end: return lerpf(0.12,0.36,(clock-lift_seconds)/align_seconds)
	if clock<travel_end+flow_seconds: return lerpf(0.36,end,(clock-travel_end)/flow_seconds)
	return lerpf(end,1.0,clampf((clock-travel_end-flow_seconds)/return_seconds,0.0,1.0))

func _sample(t: float) -> void:
	if board_pending:
		_set_phase("waiting"); return
	var lift_end := 0.12
	var travel_end := 0.36
	var flow_end := 0.68 if multi_row_route else 0.76
	var raised := source_home + Vector2(0, -28 * source.global_scale.y)
	var hover := _hover_home()
	if use_safe_route: raised = source_home.lerp(hover,0.42)
	if multi_row_route: raised=_multi_raised
	var start_pose: Dictionary = _initial_pose
	var end_pose: Dictionary = _final_pose
	stream_strength = 0.0
	progress = 0.0
	received_progress=0.0; inflight_units=0.0; mass={}
	if t < lift_end:
		_set_phase("lift")
		source.global_position = source_home.lerp(raised, smooth(t/lift_end))
		source.rotation = source_home_rotation
	elif t < travel_end:
		_set_phase("align")
		var raw := (t-lift_end)/(travel_end-lift_end)
		if multi_row_route:
			if t<0.28:
				source.global_rotation=source_home_rotation
				source.global_position=_route_point(_approach_route,(t-lift_end)/(0.28-lift_end))
			else:
				var p:=smooth((t-0.28)/(travel_end-0.28))
				source.global_rotation=lerpf(source_home_rotation,start_pose.angle,p)
				source.global_position=_clear_row_center(_multi_dock,source_home_rotation,start_pose.position,start_pose.angle,p)
		elif use_safe_route:
			if raw<0.40:
				source.global_rotation = source_home_rotation
				source.global_position = raised.lerp(hover,smooth(raw/0.40))
			else:
				var p := smooth((raw-0.40)/0.60)
				source.global_rotation = lerpf(source_home_rotation,start_pose.angle,p)
				source.global_position = _clear_row_center(hover,source_home_rotation,start_pose.position,start_pose.angle,p)
		else:
			var p := smooth(raw)
			source.global_rotation = lerpf(source_home_rotation, start_pose.angle, p)
			source.global_position = _travel_anchor(raised, source_home_rotation, start_pose.position, start_pose.angle, p, source.global_rotation)
	elif t < flow_end:
		_set_phase("pour")
		var p := clampf((t-travel_end)/(flow_end-travel_end), 0, 1)
		if is_instance_valid(source.delivered_layers):
			mass=Transfer.sample(p); progress=mass.emitted
			received_progress=mass.arrived; inflight_units=moved*mass.inflight
		else:
			progress=smooth(p); received_progress=progress
		var pose := _pose_at_volume(source_start_volume - moved * progress)
		source.global_position = pose.position
		source.global_rotation = pose.angle
		outlet = pose.outlet
		stream_strength = minf(1.0, minf(p/0.09, (1.0-p)/0.09))
		if not mass.is_empty(): stream_strength=1.0 if mass.inflight>0.000001 else 0.0
	else:
		_set_phase("return")
		progress = 1.0
		received_progress=1.0
		if relaxed_timing and not surface_finish_sent and is_instance_valid(target.delivered_layers):
			target.delivered_layers.receive_stream(false,source.color_for(color_key)); surface_finish_sent=true
		var raw := (t-flow_end)/(1.0-flow_end)
		if multi_row_route:
			if t<0.74:
				var p:=smooth((t-flow_end)/(0.74-flow_end))
				source.global_rotation=lerpf(end_pose.angle,source_home_rotation,p)
				source.global_position=_clear_row_center(end_pose.position,end_pose.angle,_multi_return_dock,source_home_rotation,p)
			else:
				source.global_rotation=source_home_rotation
				source.global_position=_route_point(_return_route,(t-0.74)/0.26)
		elif use_safe_route:
			if raw<0.60:
				var p := smooth(raw/0.60)
				source.global_rotation = lerpf(end_pose.angle,source_home_rotation,p)
				source.global_position = _clear_row_center(end_pose.position,end_pose.angle,hover,source_home_rotation,p)
			else:
				source.global_rotation = source_home_rotation
				source.global_position = hover.lerp(source_home,smooth((raw-0.60)/0.40))
		else:
			var p := smooth(raw)
			source.global_rotation = lerpf(end_pose.angle, source_home_rotation, p)
			source.global_position = _travel_anchor(end_pose.position, end_pose.angle, source_home, source_home_rotation, p, source.global_rotation)
	if is_instance_valid(board_path) and not board_path_failed:
		if t<travel_end: _apply_board_configuration(board_path.sample(board_approach,smooth(t/travel_end)))
		elif t<flow_end: _apply_board_configuration(_configuration(_board_pose(source_start_volume-moved*progress,board_shift),board_shift))
		else: _apply_board_configuration(board_path.sample(board_return,smooth((t-flow_end)/(1-flow_end))))
		outlet=source.to_global(source.flow_lip(direction))
	# A delivered skin can have a taller neck/cork than ROUTE_OUTLINE. Apply the
	# page's existing top exclusion to its actual transformed art at EVERY travel
	# phase, including upright lane changes. Classic routes have no page opt-in.
	if route_canvas_world_rect.has_area() and is_instance_valid(source.delivered_layers) and not is_instance_valid(board_path):
		var envelope: Rect2=source.global_transform*source.presentation_bounds()
		if envelope.position.y<upper_route_floor_world_y:
			source.global_position.y+=upper_route_floor_world_y-envelope.position.y
		if phase=="pour": outlet=source.to_global(source.flow_lip(direction))
	if source_was_sealed: source.sample_unseal(clampf(t/lift_end,0,1))
	var visual_source := from_bands.duplicate(true)
	visual_source[-1].amount = float(visual_source[-1].amount) - moved*progress
	var visual_target := to_bands.duplicate(true)
	if visual_target.is_empty() or visual_target[-1].color != color_key: visual_target.append({"color":color_key,"amount":moved*received_progress})
	else: visual_target[-1].amount = float(visual_target[-1].amount)+moved*received_progress
	source.set_visual_bands(visual_source)
	target.set_visual_bands(visual_target)
	if is_instance_valid(target.delivered_layers):
		if not mass.is_empty(): target.delivered_layers.receive_transfer(mass,source.color_for(color_key))
		elif phase!="pour": target.delivered_layers.receive_stream(false,source.color_for(color_key))
	if is_instance_valid(stream_layer): stream_layer.queue_redraw()
	if is_instance_valid(external_stream_layer): external_stream_layer.queue_redraw()
	target.incoming_color = source.color_for(color_key)
	target.incoming_strength = stream_strength
	target.incoming_time = elapsed
	target.queue_redraw()
	queue_redraw()

func _settle(commit: bool) -> void:
	board_path=null
	board_pending=false; board_current_shift=0
	if is_instance_valid(source):
		source.global_position = source_home; source.rotation = source_home_rotation
		source.z_index = source_home_z; source.transaction_busy = false
		source.set_layers(source_after if commit else source_before, source.capacity)
		if commit and relaxed_timing and is_instance_valid(source.delivered_layers): source.delivered_layers.pulse_surface(true)
	if is_instance_valid(target):
		target.transaction_busy = false; target.incoming_strength = 0.0
		if is_instance_valid(target.delivered_layers): target.delivered_layers.receive_stream(false,source.color_for(color_key))
		target.set_layers(target_after if commit else target_before, target.capacity)
		if commit and not auto_seal: target.sync_seal_immediate(false)
	busy = false; paused = false; stream_strength = 0.0
	mass={}; inflight_units=0.0
	if is_instance_valid(stream_layer): stream_layer.queue_free()
	if is_instance_valid(external_stream_layer): external_stream_layer.queue_free()
	_set_phase("idle")
	queue_redraw()
	completed.emit(commit)

func _draw() -> void:
	if is_instance_valid(source) and is_instance_valid(source.delivered_layers): return
	if not busy or stream_strength <= 0.001: return
	var a := to_local(outlet)
	var b := to_local(target.mouth_world() + Vector2(0, 2))
	var points := PackedVector2Array()
	for i in 17:
		var t := float(i)/16.0
		var point:=a.lerp(b,t)
		if is_instance_valid(source.delivered_layers):
			var outward: Vector2=to_local(source.global_position-source.global_transform.y*20.0)-to_local(source.global_position)
			point=(1.0-t)*(1.0-t)*a+2.0*(1.0-t)*t*(a+outward)+t*t*b
		points.append(point+Vector2(sin(t*TAU*1.2+elapsed*20.0)*0.65*sin(t*PI),0))
	var liquid: Color = source.color_for(color_key)
	var width := 7.0 * source.global_scale.x * stream_strength
	draw_polyline(points, Color(liquid, 0.22), width+5.0, true)
	draw_polyline(points, liquid, width, true)
	var highlight := points.duplicate()
	for i in highlight.size(): highlight[i] += Vector2(-width*0.2,0)
	draw_polyline(highlight, Color(1,1,1,Visual.STREAM_HIGHLIGHT_ALPHA*stream_strength), maxf(width*0.24,0.7), true)
