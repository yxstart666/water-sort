extends RefCounted
static func exterior_envelope(anim)->PackedVector2Array:
	if anim.mass.is_empty() or anim.mass.segments.is_empty():return PackedVector2Array()
	# Current reference3_stream.gd draws straight external rectangles, followed
	# by a separate internal segment. This conservative bound includes the whole
	# 32px texture width (also all alpha/glow), taper and actual drop width.
	var half_width:float=16.0*anim.target.delivered_layers.global_scale.x
	for seg in anim.mass.segments:
		if seg.kind!=2:continue
		var flatten:float=1.0-0.55*clampf((seg.center-0.82)/0.18,0,1)
		var factor:float=sqrt(seg.units*anim.moved*8070.785294117648/anim.external_stream_layer.drop_area)
		half_width=maxf(half_width,10.0/flatten*factor*anim.target.delivered_layers.global_scale.x)
	var mouth:Vector2=anim.target.mouth_world();var delta:Vector2=mouth-anim.outlet
	var normal:Vector2=delta.normalized().orthogonal()*half_width
	return PackedVector2Array([anim.outlet+normal,mouth+normal,mouth-normal,anim.outlet-normal])
static func exterior_width_safe(anim)->bool:
	var shape:=exterior_envelope(anim)
	if shape.is_empty():return true
	var box:=Rect2(shape[0],Vector2.ZERO)
	for p in shape:box=box.expand(p)
	for obstacle in anim.board_stream_obstacles:
		if box.intersects(obstacle.rect) and not Geometry2D.intersect_polygons(shape,obstacle.polygon).is_empty():return false
	return true
