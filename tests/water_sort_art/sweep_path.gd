extends SceneTree
## Full-transaction swept silhouette checks, including lift/travel/return, not just pour.
## Art still requires rendered-frame/video review; these guard against a known overlap.
const Visual=preload("res://scripts/water_sort/art/bottle_visual.gd")
const Animator=preload("res://scripts/water_sort/art/pour_animator.gd")
const OUTER := [Vector2(-49,-8),Vector2(49,-8),Vector2(49,23),Vector2(43,28),
	Vector2(43,46),Vector2(58,62),Vector2(73,88),Vector2(73,350),Vector2(68,375),
	Vector2(50,384),Vector2(-50,384),Vector2(-68,375),Vector2(-73,350),
	Vector2(-73,88),Vector2(-58,62),Vector2(-43,46),Vector2(-43,28),Vector2(-49,23)]
var failures := 0
var sampled_frames := 0

func _initialize() -> void: call_deferred("run")

func silhouette(visual: Node2D, margin := 0.0) -> PackedVector2Array:
	var poly:=PackedVector2Array()
	for point in OUTER:
		var adjusted: Vector2=point
		if visual.sealed and adjusted.y==-8: adjusted.y=-24
		poly.append(visual.to_global(adjusted))
	if margin>0:
		var expanded:=Geometry2D.offset_polygon(poly,margin)
		if not expanded.is_empty(): return expanded[0]
	return poly

func check(condition: bool, label: String) -> void:
	if not condition:
		failures+=1
		push_error(label)

func run() -> void:
	var stage:=Node2D.new();root.add_child(stage)
	var bottles: Array=[]
	for i in 3:
		var visual:=Visual.new();stage.add_child(visual)
		visual.scale=Vector2.ONE*1.33;bottles.append(visual)
	var animator:=Animator.new();stage.add_child(animator);animator.set_process(false)
	var initial: Array=[["red","red","yellow","yellow"],["yellow","yellow","red","red"],[]]
	var fixtures: Array=[
		[0,2,initial[0],[],["red","red"],["yellow","yellow"]],
		[1,0,initial[1],["red","red"],["yellow","yellow"],["red","red","red","red"]],
		[1,2,["yellow","yellow"],["yellow","yellow"],[],["yellow","yellow","yellow","yellow"]]]
	for mirror in [false,true]:
		for i in 3: bottles[i].position=Vector2(830-i*290 if mirror else 250+i*290,900)
		var state: Array=initial.duplicate(true)
		for fixture in fixtures:
			for i in 3: bottles[i].set_layers(state[i])
			var src:=int(fixture[0]);var dst:=int(fixture[1])
			check(animator.play(bottles[src],bottles[dst],fixture[2],fixture[3],fixture[4],fixture[5]),"sweep transaction started")
			var collisions:=0;var cork_collisions:=0;var minimum_y:=INF;var minimum_x:=INF;var maximum_x:=-INF
			for frame in 601:
				if frame>0: animator.advance(animator.transaction_duration/600.0+0.0000001)
				sampled_frames+=1
				var moving:=silhouette(bottles[src])
				for point in moving:
					minimum_y=minf(minimum_y,point.y)
					minimum_x=minf(minimum_x,point.x);maximum_x=maxf(maximum_x,point.x)
				for i in 3:
					if i!=src and not Geometry2D.intersect_polygons(moving,silhouette(bottles[i],3.0)).is_empty(): collisions+=1
					if i!=src and bottles[i].cork.visible:
						var stopper := PackedVector2Array()
						for point in [Vector2.ZERO,Vector2(834,0),Vector2(834,663),Vector2(0,663)]: stopper.append(bottles[i].cork.to_global(point))
						if not Geometry2D.intersect_polygons(moving,stopper).is_empty(): cork_collisions+=1
			state[src]=fixture[4].duplicate();state[dst]=fixture[5].duplicate()
			check(cork_collisions==0,"moving bottle does not hit a descending or seated stopper")
			check(collisions==0,"source silhouette intersects a standing bottle anywhere on timeline")
			check(minimum_y>=318.0,"moving bottle remains below title/subtitle and 20 px gap")
			check(minimum_x>=80 and maximum_x<=1000,"moving bottle remains within canvas margins")
			print("SWEPT_PATH mirror=",mirror," move=",src,"->",dst," collisions=",collisions," cork_collisions=",cork_collisions," title_min_y=",minimum_y," x_range=",minimum_x,",",maximum_x)
	stage.queue_free();await process_frame
	print("SWEPT_PATH_TESTS frames=",sampled_frames," margin_px=3 failures=",failures)
	quit(0 if failures==0 else 1)
