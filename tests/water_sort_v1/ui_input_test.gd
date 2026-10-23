extends SceneTree
# Real viewport input only for player actions; no main or persistence fixtures needed.
var game
var checks:=0
var failures: Array=[]
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
func touch(node: Control) -> void:
	var point: Vector2=root.get_final_transform()*(node.get_global_transform_with_canvas()*(node.size*0.5))
	for pressed in [true,false]:
		var event:=InputEventScreenTouch.new(); event.index=0; event.position=point; event.pressed=pressed
		Input.parse_input_event(event); await process_frame
	await process_frame
func escape() -> void:
	for pressed in [true,false]:
		var event:=InputEventKey.new(); event.keycode=KEY_ESCAPE; event.pressed=pressed
		root.push_input(event,true); await process_frame
func settle() -> void:
	for _frame in range(150):
		if not game._animation_busy(): break
		await create_timer(0.02).timeout
	await process_frame
	if game._animation_busy(): failures.append("glass and cork transaction exceeded bounded settle time")
func state_key() -> String: return JSON.stringify(game.rules.snapshot())
func run() -> void:
	root.size=Vector2i(540,960)
	game=load("res://scenes/experiments/water_sort_v1.tscn").instantiate(); root.add_child(game); await process_frame
	check(game.state=="intro" and game.levels.size()==5,"five-level intro opens without loading cargo main")
	check(game.labels.Title.text=="倒瓶子 · 玩法测试版","new project clearly labeled test artwork, not comparison or production release")
	var initial: String=state_key()
	await create_timer(0.08).timeout
	check(game.elapsed==0,"instructions do not start clock")
	await click(game.bottle_nodes[0])
	check(game.selected==-1 and state_key()==initial,"modal blocks underlying bottle clicks")
	await click(game.buttons.Start)
	check(game.state=="playing" and game.moves==0,"native start opens live puzzle")
	check(game.bottle_nodes.size()==3,"first puzzle renders exactly actual bottles")
	await click(game.bottle_nodes[2])
	check(game.selected==-1 and game.labels.Status.text.contains("空瓶"),"empty source reports reason without action")
	await click(game.bottle_nodes[0])
	check(game.selected==0 and game.bottle_nodes[0].selected,"source selection visible")
	await click(game.bottle_nodes[1])
	check(game.selected==0 and state_key()==initial and game.moves==0,"illegal target leaves all layers and step count unchanged")
	check(game.labels.Status.text.contains("只能"),"illegal pour has explicit guidance")
	await click(game.bottle_nodes[0])
	check(game.selected==-1,"tap selected bottle to cancel")
	await click(game.bottle_nodes[0]); await click(game.bottle_nodes[2])
	check(game.moves==1 and game.pour_remaining>0 and game.rules.bottles[2]==["yellow","yellow"],"native legal pour atomically moves whole top color run")
	await click(game.bottle_nodes[1])
	check(game.moves==1 and game.selected==-1,"rapid tap during short cue cannot double-commit")
	await click(game.buttons.Pause)
	var paused_time: float=game.elapsed
	var paused_pour: float=game.pour_remaining
	await create_timer(0.10).timeout
	check(game.state=="paused" and game.elapsed==paused_time and game.pour_remaining==paused_pour,"pause freezes both timer and interrupted pour cue")
	await click(game.buttons.Resume); await settle()
	check(game.state=="playing" and game.moves==1 and game.pour_remaining==0,"resume completes same move once")
	var thinking_time: float=game.elapsed
	await click(game.buttons.Undo)
	check(state_key()==initial and game.moves==0 and game.elapsed>=thinking_time,"undo restores exact layers and steps without rewinding thinking time")
	check(game.buttons.Undo.disabled,"empty history disables undo")
	await click(game.buttons.Instructions)
	var help_time: float=game.elapsed
	await create_timer(0.08).timeout
	check(game.state=="intro" and game.elapsed==help_time,"return instructions freezes timer and preserves current run")
	await click(game.buttons.Start)
	check(game.state=="playing" and state_key()==initial,"return from instructions is not fake home or restart")
	await click(game.buttons.Restart)
	var confirm_time: float=game.elapsed
	await create_timer(0.08).timeout
	check(game.state=="restart" and game.elapsed==confirm_time,"restart confirmation freezes timer")
	await click(game.buttons.CancelRestart)
	check(game.state=="playing" and state_key()==initial,"cancel restart preserves state")
	await click(game.buttons.Restart); await click(game.buttons.ConfirmRestart)
	check(game.state=="playing" and game.elapsed<0.10 and game.moves==0 and state_key()==initial,"confirmed restart resets current puzzle and clock")
	await touch(game.bottle_nodes[0])
	check(game.selected==0,"native touch selects once without synthetic mouse double toggle")
	await touch(game.bottle_nodes[0])
	check(game.selected==-1,"second native touch deselects once")
	await escape()
	check(game.state=="paused","Escape opens a real paused state")
	await click(game.buttons.PauseInstructions)
	check(game.state=="intro","paused instructions keep puzzle behind overlay")
	await click(game.buttons.Start)
	check(game.state=="playing" and state_key()==initial,"return from paused instructions resumes exact puzzle")
	game.notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	await process_frame # Focus overlays are added after notification traversal.
	check(game.state=="paused","application focus loss safely pauses")
	await escape()
	check(game.state=="playing","Escape resumes without changing score")
	# A genuinely reachable no-move loss: level 2, yellow top from bottle 2 into empty 3.
	game.load_level(1); await process_frame
	var second: String=state_key()
	await click(game.bottle_nodes[2]); await click(game.bottle_nodes[3]); await settle()
	check(game.state=="stuck" and not game._has_legal_move() and game.buttons.has("BlockedUndo"),"real dead-end opens recoverable failure state")
	var stuck_time: float=game.elapsed
	await create_timer(0.06).timeout
	check(game.elapsed==stuck_time,"failure clock freezes")
	await click(game.buttons.BlockedUndo)
	check(game.state=="playing" and game.moves==0 and state_key()==second,"dead-end undo uses actual prior state and is free")
	# Replay independent shortest-path certificates through native hit testing for every move.
	var proofs: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/water_sort_v1/proofs.json"))
	game.load_level(0); await process_frame
	for index in range(5):
		check(game.level_index==index and game.state=="playing","level %d starts in sequence" % (index+1))
		var sequence: Array=proofs.levels[index].shortest_solution
		for step in range(sequence.size()):
			var action: Array=sequence[step]
			await click(game.bottle_nodes[int(action[0])]); await click(game.bottle_nodes[int(action[1])]); await settle()
			check(game.moves==step+1,"level %d native move %d commits exactly once" % [index+1,step+1])
			check(game.pour_remaining==0,"level %d move %d unlocks after one bounded glass animation" % [index+1,step+1])
		check(game.rules.is_solved() and game.state=="won","level %d real win closure" % (index+1))
		var won_time: float=game.elapsed
		await create_timer(0.05).timeout
		check(game.elapsed==won_time,"level %d result freezes clock" % (index+1))
		if index<4:
			check(game.buttons.has("Next"),"next exists before final level")
			await click(game.buttons.Next)
		else:
			check(not game.buttons.has("Next") and game.buttons.has("ReplayAll"),"final level has no nonexistent sixth level")
			await click(game.buttons.ResultInstructions)
			check(game.state=="intro","final win can return to instructions")
			await click(game.buttons.Start)
			check(game.state=="won" and game.buttons.has("ReplayAll"),"return restores final result rather than reopening solved board")
			await click(game.buttons.ReplayAll)
			check(game.level_index==0 and game.state=="playing" and game.moves==0,"final replay starts a clean first puzzle")
	check(ProjectSettings.get_setting("application/run/main_scene")!="res://scenes/main.tscn","new copied project does not boot the cargo main")
	print("WATER_SORT_UI_INPUT ",JSON.stringify({"checks":checks,"failures":failures,"passed":failures.is_empty()}))
	game.queue_free(); await process_frame
	quit(0 if failures.is_empty() else 1)
