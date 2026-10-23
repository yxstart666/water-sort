extends SceneTree
const Geometry = preload("res://scripts/water_sort/art/liquid_geometry.gd")
const Visual = preload("res://scripts/water_sort/art/bottle_visual.gd")
const Animator = preload("res://scripts/water_sort/art/pour_animator.gd")
const Rules = preload("res://scripts/experiments/water_sort_v1/rules.gd")
var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func verify(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error(message)

func near(a: float, b: float, tolerance := 0.001) -> bool:
	return absf(a-b)<tolerance

func run() -> void:
	geometry_tests()
	await transaction_tests()
	print("WATER_SORT_ART_TESTS checks=",checks," failures=",failures.size())
	quit(0 if failures.is_empty() else 1)

func geometry_tests() -> void:
	for degrees in [-165,-130,-95,-75,-40,0,40,75,95,130,165]:
		var angle := deg_to_rad(float(degrees))
		for volume in [0.0,0.001,0.2,0.5,1.0,1.99,2.0,2.01,3.0,3.99,4.0]:
			var shape := Geometry.filled(volume,4.0,angle)
			verify(near(Geometry.area(shape),Geometry.full_area()*volume/4.0,0.02),"area preserved angle=%s volume=%s" % [degrees,volume])
			for point in shape:
				verify(Geometry2D.is_point_in_polygon(point,Geometry.cavity()) or Geometry.cavity().has(point) or _on_edge(point),"clip inside cavity")
			var surface := Geometry.surface(volume,4.0,angle)
			if surface.size()==2:
				verify(near(surface[0].rotated(angle).y,surface[1].rotated(angle).y),"world horizontal surface")
		var bottom := Geometry.band(0,2,4,angle)
		var top := Geometry.band(2,4,4,angle)
		verify(near(Geometry.area(bottom)+Geometry.area(top),Geometry.full_area(),0.02),"no gaps/overlap across two-colour boundary")
	for volume in [0.01,0.3,1.0,2.0,3.0,4.0]:
		var angle := Geometry.spill_angle(volume,4.0)
		var level := Geometry.threshold(volume,4.0,angle)
		verify(near(level,Vector2(34,0).dot(Geometry.gravity_normal(angle)),0.002),"surface reaches mouth without wall leak")

func _on_edge(point: Vector2) -> bool:
	var poly := Geometry.cavity()
	for i in poly.size():
		if Geometry2D.get_closest_point_to_segment(point,poly[i],poly[(i+1)%poly.size()]).distance_to(point)<0.001: return true
	return false

func transaction_tests() -> void:
	var stage := Node2D.new(); root.add_child(stage)
	var a := Visual.new(); var b := Visual.new()
	stage.add_child(a); stage.add_child(b)
	var animator := Animator.new(); stage.add_child(animator); animator.set_process(false)
	for direction in [-1.0,1.0]:
		for fixture in [
			[["red","red","yellow","yellow"],[],["red","red"],["yellow","yellow"]],
			[["red","yellow","yellow","yellow"],["yellow","yellow","yellow"],["red","yellow","yellow"],["yellow","yellow","yellow","yellow"]],
			[["red","red"],[],[],["red","red"]]
		]:
			a.position=Vector2(300,450); b.position=Vector2(300+direction*290,450)
			a.scale=Vector2.ONE*1.38; b.scale=Vector2.ONE*1.38
			a.set_layers(fixture[0]); b.set_layers(fixture[1])
			var home := a.position
			verify(animator.play(a,b,fixture[0],fixture[1],fixture[2],fixture[3]),"valid pour starts")
			verify(not animator.play(a,b,fixture[0],fixture[1],fixture[2],fixture[3]),"transaction refuses re-entry")
			verify(a.layers==fixture[2] and b.layers==fixture[3],"committed state exists before animation finishes")
			var expected := float(fixture[0].size()+fixture[1].size())
			for frame in 101:
				animator.advance(animator.transaction_duration/100.0)
				verify(near(a.volume()+b.volume(),expected),"source+target conserved every frame")
				verify(a.volume()>=-0.001 and b.volume()<=4.001,"capacity bounds")
				if animator.phase=="pour" and animator.stream_strength>0.0:
					verify(a.mouth_world(direction).distance_to(animator.outlet)<0.01,"stream starts at lower lip")
					verify(near(animator.outlet.x,b.mouth_world().x),"stream aligns with target opening")
					verify(animator.outlet.y<b.mouth_world().y,"stream flows downward")
					for point in Geometry.cavity():
						verify(a.to_global(point).y<b.mouth_world().y-20,"pouring body clears all standing neighbours")
			verify(not animator.busy and a.position.is_equal_approx(home) and near(a.rotation,0),"exact rest pose restored")
			verify(a.bands==Visual.to_bands(fixture[2]) and b.bands==Visual.to_bands(fixture[3]),"final strata match authoritative state")
	verify(near(animator.row_clearance_local,26.0) and near(animator.hover_clearance_local,417.0) and near(animator.swept_row_clearance_local,33.0),"default clearance preserves approved demo")
	a.position=Vector2(300,900); b.position=Vector2(600,900)
	a.set_layers(["red","red","red","red"]);b.set_layers([])
	animator.play(a,b,["red","red","red","red"],[],[],["red","red","red","red"])
	var default_pose: Dictionary=animator._pose_at_volume(4.0)
	var default_hover: Vector2=animator._hover_home()
	animator.row_clearance_local=56.0;animator.hover_clearance_local=424.0
	var dense_pose: Dictionary=animator._pose_at_volume(4.0)
	verify(near(default_pose.position.y-dense_pose.position.y,30.0*a.global_scale.x),"dense row clearance raises pouring body without changing angle")
	verify(near(default_pose.angle,dense_pose.angle) and near(default_pose.outlet.x,dense_pose.outlet.x),"dense clearance retains lower lip and target alignment")
	verify(near(default_hover.y-animator._hover_home().y,7.0*a.global_scale.x),"dense hover clearance lifts column route independently")
	animator.cancel(true)
	animator.row_clearance_local=26.0;animator.hover_clearance_local=417.0
	# Pause/resume and cancellation retain one authoritative outcome and clear stream/locks.
	var before_a := ["red","red","yellow","yellow"]
	var before_b := []
	var after_a := ["red","red"]
	var after_b := ["yellow","yellow"]
	for commit in [true,false]:
		a.set_layers(before_a); b.set_layers(before_b)
		animator.play(a,b,before_a,before_b,after_a,after_b)
		animator.advance(0.42)
		var volume_before: float=a.volume()
		var position_before := a.position
		animator.set_paused(true); animator.advance(3.0)
		verify(near(a.volume(),volume_before) and a.position==position_before,"pause freezes mass and position")
		animator.set_paused(false); animator.advance(0.02)
		verify(a.volume()<volume_before,"resume continues same transaction")
		animator.cancel(commit)
		verify(not animator.busy and not a.transaction_busy and not b.transaction_busy and b.incoming_strength==0,"cancel clears all locks/stream")
		verify(a.layers==(after_a if commit else before_a),"cancel chooses committed/restored snapshot")
		verify(near(a.volume()+b.volume(),4),"cancel conserves inventory")
	# Invalid moves do not seize bottles, and separate timelines can run concurrently.
	a.set_layers(before_a); b.set_layers(["red"])
	verify(not animator.play(a,b,before_a,["red"],after_a,["red","yellow","yellow"]),"wrong receiving colour rejected")
	verify(not animator.play(a,b,before_a,[],["yellow","yellow"],["red","red"]),"cannot pour through bottom layer")
	verify(not a.transaction_busy and not b.transaction_busy,"invalid transaction leaves locks untouched")
	var c := Visual.new(); var d := Visual.new()
	stage.add_child(c); stage.add_child(d)
	c.position=Vector2(200,900); d.position=Vector2(500,900)
	c.set_layers(before_a); d.set_layers([])
	var second := Animator.new(); stage.add_child(second); second.set_process(false)
	a.set_layers(before_a); b.set_layers([])
	verify(animator.play(a,b,before_a,[],after_a,after_b),"first independent pour")
	verify(not second.play(a,d,before_a,[],after_a,after_b),"second animator cannot seize busy source")
	verify(second.play(c,d,before_a,[],after_a,after_b),"unrelated bottles remain independently interactive")
	animator.advance(0.4); second.advance(0.6)
	verify(near(a.volume()+b.volume()+c.volume()+d.volume(),8),"independent pours conserve total volume")
	animator.cancel(true); second.cancel(true)
	# Removal during an in-flight animation cannot leave the surviving bottle locked.
	c.set_layers(before_a); d.set_layers([])
	second.play(c,d,before_a,[],after_a,after_b)
	second.advance(0.4)
	d.free()
	second.advance(0.1)
	verify(not second.busy and not c.transaction_busy and c.layers==after_a,"removed target safely settles surviving visual")
	# Completion stopper is state-derived, with one timeline and no rule lock.
	var notifications := [0]
	b.seal_finished.connect(func(): notifications[0]+=1)
	a.set_layers(["red","red","red","red"]); b.set_layers([])
	verify(a.sealed and not b.sealed,"restored solved bottle is immediately sealed")
	verify(animator.play(a,b,["red","red","red","red"],[],[],["red","red","red","red"]),"sealed source may legally pour without changing rules")
	verify(animator.source_was_sealed,"initial stopper captured before atomic after state")
	animator.advance(animator.duration*0.12)
	verify(not a.sealed and not a.cork.visible,"source stopper removed before tilt and flow")
	animator.advance(animator.duration*0.88)
	verify(animator.busy and b.seal_animating and not b.sealed,"completion waits for actual stopper settle")
	var seal_before: float=b.seal_progress
	animator.set_paused(true);animator.advance(1.0)
	verify(near(b.seal_progress,seal_before),"pause also freezes stopper")
	animator.set_paused(false);animator.advance(animator.remaining_seconds()+0.001)
	verify(not animator.busy and b.sealed and notifications[0]==1,"stopper completes once before transaction completed")
	b.set_layers(["red","red","red","red"])
	verify(b.sealed and notifications[0]==1,"snapshot refresh does not replay celebration")
	b.set_layers(["red","red"])
	verify(not b.sealed and not b.cork.visible,"undo removes completion stopper immediately")
	b.set_layers(["red","red","yellow","yellow"])
	verify(not b.sealed,"mixed full bottle never seals")
	for commit in [true,false]:
		a.set_layers(["red","red","red","red"]); b.set_layers([])
		animator.play(a,b,["red","red","red","red"],[],[],["red","red","red","red"])
		animator.advance(0.80)
		verify(b.seal_animating,"stopper cancellation fixture is actually mid-descent")
		var count_before: int=notifications[0]
		animator.cancel(commit)
		verify(not animator.busy and not b.seal_animating and not a.seal_animating,"cancel stops stopper and transaction together")
		verify(b.sealed==commit and a.sealed!=commit,"cancel restores committed or original stopper state")
		verify(not a.transaction_busy and not b.transaction_busy and notifications[0]==count_before,"cancel releases locks without replaying celebration")
	verify(near(Geometry.threshold(4,4,0),24.0,0.001),"four units reach neck with 4 px stopper headroom")
	verify(Geometry.cavity().has(Vector2(0,374)),"liquid bottom has shallow curved centre instead of flat bar")
	var rules := Rules.new({"capacity":4,"bottles":[["red","red","yellow","yellow"],["yellow","yellow","red","red"],[]]})
	for move in [Vector2i(0,2),Vector2i(1,0),Vector2i(1,2)]: verify(rules.pour(move.x,move.y)==2,"demo move obeys actual rules")
	verify(rules.is_solved(),"three-step demo truly solves puzzle")
	stage.queue_free()
	await process_frame
