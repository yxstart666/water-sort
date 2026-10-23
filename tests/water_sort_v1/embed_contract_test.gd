extends SceneTree
var game
var checks:=0
var failures: Array=[]
var events: Dictionary={"requests":[],"completed":[],"exits":0}
func _initialize() -> void: call_deferred("run")
func check(value: bool, label: String) -> void:
	checks+=1
	if not value: failures.append(label); push_error(label)
func click(node: Control) -> void:
	await process_frame
	var point: Vector2=node.get_global_transform_with_canvas()*(node.size*0.5)
	for pressed in [true,false]:
		var event:=InputEventMouseButton.new(); event.position=point; event.global_position=point
		event.button_index=MOUSE_BUTTON_LEFT; event.pressed=pressed
		root.push_input(event,true); await process_frame
	await process_frame
func settle() -> void:
	for _frame in range(150):
		if not game._animation_busy(): break
		await create_timer(0.02).timeout
	await process_frame
	if game._animation_busy(): failures.append("glass and cork transaction exceeded bounded settle time")
func run() -> void:
	root.size=Vector2i(540,960)
	game=load("res://scenes/experiments/water_sort_v1.tscn").instantiate()
	game.embedded_mode=true; game.set_locale("en")
	game.level_start_requested.connect(func(index): events.requests.append(index))
	game.level_completed.connect(func(index,moves,elapsed): events.completed.append({"index":index,"moves":moves,"elapsed":elapsed}))
	game.exit_requested.connect(func(): events.exits+=1)
	root.add_child(game); await process_frame
	check(game.state=="intro" and events.requests.is_empty() and events.completed.is_empty(),"embedded ready is frozen and never purchases or completes a level")
	check(game.labels.Title.text=="Color Sort" and game.labels.OverlayTitle.text=="How to play","locale can be set before tree entry")
	game.load_level(0); await process_frame
	check(game.buttons.Instructions.text=="Home" and game.labels.Footnote.text.contains("Saved"),"embedded UI names real home and local persistence")
	check(game.bottle_nodes[0].size==Vector2(176,410),"single row bottles enlarged for phone-sized window")
	await click(game.bottle_nodes[0])
	var before: String=JSON.stringify(game.rules.snapshot())
	var elapsed: float=game.elapsed
	game.set_locale("zh"); await process_frame
	check(JSON.stringify(game.rules.snapshot())==before and game.selected==0 and game.elapsed>=elapsed and game.moves==0,"locale redraw preserves selected source, liquid, time and score")
	check(game.labels.Title.text=="Color Sort · 倒瓶子" and game.buttons.Instructions.text=="返回主页","embedded Chinese title and home route")
	game.set_locale("en"); await process_frame
	await click(game.bottle_nodes[0]) # cancel selected source
	await click(game.buttons.Restart)
	check(game.labels.OverlayTitle.text=="Restart this level?","English restart dialog")
	await click(game.buttons.ConfirmRestart)
	check(events.requests==[0] and game.state=="restart" and JSON.stringify(game.rules.snapshot())==before,"restart requests authorization before mutating puzzle or timer")
	await click(game.buttons.CancelRestart)
	check(game.state=="playing","denied or cancelled external restart leaves current run available")
	await click(game.buttons.Instructions)
	check(events.exits==1 and game.state=="paused","home exit freezes playing state before emitting")
	var paused_time: float=game.elapsed
	await create_timer(0.08).timeout
	check(game.elapsed==paused_time,"home transition never runs hidden gameplay clock")
	game.resume_game(); await process_frame
	check(game.state=="playing" and JSON.stringify(game.rules.snapshot())==before,"shell resume continues same run")
	for action in [[0,2],[1,0],[1,2]]:
		await click(game.bottle_nodes[action[0]]); await click(game.bottle_nodes[action[1]]); await settle()
	check(game.state=="won" and events.completed.size()==1,"one completed signal after real solution")
	check(events.completed[0].index==0 and events.completed[0].moves==3 and events.completed[0].elapsed>0,"completion carries real level, moves and elapsed")
	game._finish_pour(); game._finish_pour()
	check(events.completed.size()==1,"repeated completion evaluation cannot duplicate reward signal")
	await click(game.buttons.Next)
	check(events.requests==[0,1] and game.state=="won" and game.level_index==0,"next only requests level, allowing shell to reject without losing result")
	await click(game.buttons.ResultInstructions)
	check(events.exits==2 and game.state=="won","home exit preserves won status and outcome")
	game.set_locale("zh"); await process_frame
	check(game.state=="won" and events.completed.size()==1 and game.labels.OverlayTitle.text=="本关完成","locale switch preserves completion without emitting again")
	game.load_level(2); await process_frame
	check(game.bottle_nodes[0].size==Vector2(152,320) and not game.completion_reported,"accepted new level resets completion guard and keeps single-row touch targets above 48 dp at 360 dp")
	for node in game.bottle_nodes:
		var rest: Vector2=node.get_meta("rest_position")
		check(rest.x>=70 and rest.x+node.size.x<=1010 and rest.y+node.size.y<1420,"bottle targets stay within board and above status")
	game.load_level(1); await process_frame
	await click(game.bottle_nodes[2]); await click(game.bottle_nodes[3]); await settle()
	check(game.state=="stuck" and events.completed.size()==1,"dead-end never emits a win")
	await click(game.buttons.ResultInstructions)
	check(events.exits==3 and game.state=="stuck","home exit preserves recoverable failure state")
	print("WATER_SORT_EMBED_CONTRACT ",JSON.stringify({"checks":checks,"failures":failures,"passed":failures.is_empty()}))
	game.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
