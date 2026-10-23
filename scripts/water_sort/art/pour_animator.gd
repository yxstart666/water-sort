extends Node2D
## One transaction/timeline for every liquid colour. No rule mutations or awaited tweens.
## Pass before/after arrays AFTER atomically committing your gameplay move.
## Multiple animators may operate on disjoint bottles at the same time.
signal completed(committed: bool)
signal phase_changed(phase: String)
const Geometry = preload("res://scripts/water_sort/art/liquid_geometry.gd")
const Visual = preload("res://scripts/water_sort/art/bottle_visual.gd")
@export var duration := 0.84
@export var travel_lift := 210.0
## Opt in for dense rows / long crossings. Neck-full sources automatically use it.
@export var safe_row_route := false
## Two-row boards may opt in. Upper targets pour above the upper row; lower
## targets pour in the middle band. Plane changes use configured empty columns.
## Defaults deliberately leave the approved three-bottle demo unchanged.
@export var multi_row_route := false
@export var multi_row_ceiling_world_y := 758.0
@export var multi_row_transit_lanes_world_x := PackedFloat32Array()
const ROUTE_OUTLINE := [Vector2(-49,-8),Vector2(49,-8),Vector2(49,23),Vector2(43,28),Vector2(43,46),Vector2(58,62),Vector2(73,88),Vector2(73,350),Vector2(68,375),Vector2(50,384),Vector2(-50,384),Vector2(-68,375),Vector2(-73,350),Vector2(-73,88),Vector2(-58,62),Vector2(-43,46),Vector2(-43,28),Vector2(-49,23)]
## Layout-specific spacing; defaults preserve the approved three-bottle demo.
@export var row_clearance_local := 26.0
@export var hover_clearance_local := 417.0
@export var swept_row_clearance_local := 33.0
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
	direction = 1.0 if target_home.x >= source_home.x else -1.0
	# Edge destinations tilt inward. An outward body at these columns would leave
	# the portrait canvas, even though the mouth and stream were still on screen.
	if multi_row_route:
		var horizontal_reach := 410.0 * source.global_scale.x
		if target_home.x < 20.0+horizontal_reach: direction=-1.0
		elif target_home.x > 1060.0-horizontal_reach: direction=1.0
	moved = float(count); color_key = key
	source_start_volume = float(before_from.size()); target_start_volume = float(before_to.size())
	source_was_sealed = source.sealed
	needs_target_seal = Visual.complete_layers(after_to,target.capacity)
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
	elapsed = minf(elapsed + maxf(delta, 0.0), maxf(transaction_duration, 0.01))
	_sample(minf(elapsed / maxf(duration, 0.01),1.0))
	if needs_target_seal and elapsed>=seal_start_time:
		target.sample_seal(1.0 if elapsed>=transaction_duration else (elapsed-seal_start_time)/Visual.SEAL_DURATION)
		if elapsed>=duration: _set_phase("seal")
	if elapsed >= maxf(transaction_duration, 0.01): _settle(true)

static func smooth(value: float) -> float:
	var t := clampf(value, 0.0, 1.0)
	return t*t*(3.0-2.0*t)

func _set_phase(value: String) -> void:
	if phase != value:
		phase = value
		phase_changed.emit(value)

func _pose_at_volume(units: float) -> Dictionary:
	var angle := Geometry.spill_angle(maxf(units, 0.006), source.capacity) * direction
	# The lower lip is locked above the actual target mouth. No wall-crossing stream.
	var scale_factor := source.global_scale.x
	var lowest := -INF
	for point in Geometry.cavity(): lowest = maxf(lowest, point.rotated(angle).y)
	var lower_lip_y := Vector2(direction * 34.0, 0).rotated(angle).y
	# Clear every standing bottle on the row, including a non-participating bottle
	# between source and target. The body never clips through its neighbour's mouth.
	var air_gap := maxf(82.0, lowest - lower_lip_y + row_clearance_local) * scale_factor
	var mouth: Vector2 = target.mouth_world()
	var end: Vector2 = mouth + Vector2(0, -air_gap)
	var lip_offset := Vector2(direction * 34.0, 0).rotated(angle) * scale_factor
	var position := end-lip_offset
	if multi_row_route:
		position=_clamp_multi_position(position,angle)
		end=position+lip_offset
	return {"angle": angle, "position": position, "outlet": end}

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
	for point in ROUTE_OUTLINE:
		var y: float=point.rotated(angle).y*source.global_scale.x
		low=minf(low,y);high=maxf(high,y)
	var floor_y:=460.0
	if target_home.y>multi_row_ceiling_world_y+100.0:
		floor_y=multi_row_ceiling_world_y+384.0*source.global_scale.x+3.25
	var bottom_y:=target_home.y-27.0*source.global_scale.x-3.25
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

func _sample(t: float) -> void:
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
		progress = smooth(p)
		var pose := _pose_at_volume(source_start_volume - moved * progress)
		source.global_position = pose.position
		source.global_rotation = pose.angle
		outlet = pose.outlet
		stream_strength = minf(1.0, minf(p/0.09, (1.0-p)/0.09))
	else:
		_set_phase("return")
		progress = 1.0
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
	if source_was_sealed: source.sample_unseal(clampf(t/lift_end,0,1))
	var visual_source := from_bands.duplicate(true)
	visual_source[-1].amount = float(visual_source[-1].amount) - moved*progress
	var visual_target := to_bands.duplicate(true)
	if visual_target.is_empty() or visual_target[-1].color != color_key: visual_target.append({"color":color_key,"amount":moved*progress})
	else: visual_target[-1].amount = float(visual_target[-1].amount)+moved*progress
	source.set_visual_bands(visual_source)
	target.set_visual_bands(visual_target)
	target.incoming_color = source.color_for(color_key)
	target.incoming_strength = stream_strength
	target.incoming_time = elapsed
	target.queue_redraw()
	queue_redraw()

func _settle(commit: bool) -> void:
	if is_instance_valid(source):
		source.global_position = source_home; source.rotation = source_home_rotation
		source.z_index = source_home_z; source.transaction_busy = false
		source.set_layers(source_after if commit else source_before, source.capacity)
	if is_instance_valid(target):
		target.transaction_busy = false; target.incoming_strength = 0.0
		target.set_layers(target_after if commit else target_before, target.capacity)
	busy = false; paused = false; stream_strength = 0.0
	_set_phase("idle")
	queue_redraw()
	completed.emit(commit)

func _draw() -> void:
	if not busy or stream_strength <= 0.001: return
	var a := to_local(outlet)
	var b := to_local(target.mouth_world() + Vector2(0, 2))
	var points := PackedVector2Array()
	for i in 17:
		var t := float(i)/16.0
		points.append(a.lerp(b,t)+Vector2(sin(t*TAU*1.2+elapsed*20.0)*0.65*sin(t*PI),0))
	var liquid: Color = source.color_for(color_key)
	var width := 7.0 * source.global_scale.x * stream_strength
	draw_polyline(points, Color(liquid, 0.22), width+5.0, true)
	draw_polyline(points, liquid, width, true)
	var highlight := points.duplicate()
	for i in highlight.size(): highlight[i] += Vector2(-width*0.2,0)
	draw_polyline(highlight, Color(1,1,1,Visual.STREAM_HIGHLIGHT_ALPHA*stream_strength), maxf(width*0.24,0.7), true)
