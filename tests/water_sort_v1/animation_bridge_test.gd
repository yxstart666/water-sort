extends SceneTree
var game
var checks:=0
var failures: Array=[]
var wins:=0
var exits:=0
func _initialize() -> void: call_deferred("run")
func check(value: bool, label: String) -> void:
	checks+=1
	if not value: failures.append(label); push_error(label)
func click(node: Control) -> void:
	await process_frame
	var p: Vector2=node.get_global_transform_with_canvas()*(node.size*0.5)
	for pressed in [true,false]:
		var e:=InputEventMouseButton.new();e.position=p;e.global_position=p;e.button_index=MOUSE_BUTTON_LEFT;e.pressed=pressed
		root.push_input(e,true);await process_frame
	await process_frame
func start_pour() -> void:
	await click(game.bottle_nodes[0]);await click(game.bottle_nodes[2])
func sum_visual() -> float:
	var total:=0.0
	for node in game.bottle_nodes: total+=node.visual.volume()
	return total
func settle_visuals() -> void:
	for _frame in range(150):
		if not game._animation_busy(): break
		game._process(0.02)
	if game._animation_busy(): failures.append("visual transaction did not finish including cork")
func run() -> void:
	root.size=Vector2i(540,960)
	game=load("res://scenes/experiments/water_sort_v1.tscn").instantiate()
	game.level_completed.connect(func(_i,_m,_t): wins+=1)
	game.exit_requested.connect(func(): exits+=1)
	root.add_child(game);await process_frame;game.set_process(false)
	await click(game.buttons.Start)
	check(is_instance_valid(game.animator) and not game.animator.is_processing(),"view alone advances actual PourAnimator")
	check(game.POUR_SECONDS==0.84,"official shared glass animation lasts 0.84 seconds")
	for node in game.bottle_nodes:
		check(node.visual is Node2D and node.visual.get_node("GlassFront") is Sprite2D,"click shell contains real glass sprite visual")
	var initial: Dictionary=game.rules.snapshot()
	var home: Vector2=game.bottle_nodes[0].visual.global_position
	await start_pour()
	check(game.moves==1 and game.animator.busy and game.pour_remaining==0.84,"native target click commits once and starts one bounded transaction")
	check(game.bottle_nodes[0].visual.layers==game.rules.bottles[0] and game.bottle_nodes[2].visual.layers==game.rules.bottles[2],"visual logical arrays immediately match committed rules")
	check(game.bottle_nodes[0].visual.volume()==4 and game.bottle_nodes[2].visual.volume()==0,"fractional visuals start from before-state, not teleport to after")
	await click(game.bottle_nodes[1])
	check(game.moves==1 and game.selected==-1,"animation rejects competing input without queueing another move")
	game._process(0.42)
	check(game.animator.phase=="pour" and game.animator.stream_strength>0,"middle of real timeline has aligned pouring stream")
	check(absf(game.bottle_nodes[0].visual.global_rotation)>0.1 and not game.bottle_nodes[0].visual.global_position.is_equal_approx(home),"source actually lifts, travels and tilts")
	var middle_volume: float=game.bottle_nodes[0].visual.volume()
	check(middle_volume>2 and middle_volume<4 and absf(sum_visual()-8)<0.001,"partial source and target conserve all 8 units")
	var middle_position: Vector2=game.bottle_nodes[0].visual.global_position
	game._refresh()
	check(is_equal_approx(middle_volume,game.bottle_nodes[0].visual.volume()) and middle_position.is_equal_approx(game.bottle_nodes[0].visual.global_position),"HUD refresh cannot reset fractional bands or moving geometry")
	await click(game.buttons.Pause)
	var frozen_time: float=game.elapsed
	game._process(1.0)
	check(game.animator.paused and game.elapsed==frozen_time and middle_position.is_equal_approx(game.bottle_nodes[0].visual.global_position),"pause freezes actual pose, volume and solve time")
	check(game.overlay.z_index>game.animator.z_index,"pause modal is above moving glass and stream")
	await click(game.buttons.Resume);game._process(0.42)
	check(not game.animator.busy and game.pour_remaining==0 and game.moves==1,"resume finishes the same transaction exactly once")
	check(game.bottle_nodes[0].visual.global_position.is_equal_approx(home) and is_zero_approx(game.bottle_nodes[0].visual.rotation),"completed source returns to exact rest pose")
	check(game.bottle_nodes[0].visual.volume()==2 and game.bottle_nodes[2].visual.volume()==2 and absf(sum_visual()-8)<0.001,"final visible inventory matches rules")
	await click(game.buttons.Undo)
	check(game.rules.snapshot()==initial and game.bottle_nodes[0].visual.volume()==4,"undo rebuilds original visual and rules together")
	# Leaving midway settles to committed state, never rolls inventory back or loses a paid move.
	game.embedded_mode=true
	await start_pour();game._process(0.42)
	var after: Dictionary=game.rules.snapshot()
	await click(game.buttons.Instructions)
	check(exits==1 and game.state=="paused" and not game.animator.busy and game.pour_remaining==0,"home settles and unlocks animation before exit signal")
	check(game.rules.snapshot()==after and game.moves==1 and game.bottle_nodes[2].visual.volume()==2,"home cancellation preserves committed move and volume")
	check(not game.bottle_nodes[0].visual.transaction_busy and not game.bottle_nodes[2].visual.transaction_busy and game.animator.stream_strength==0,"home clears both transaction locks and stream")
	game.resume_game();await click(game.buttons.Undo)
	# Restart remains responsive during a pour; cancellation preserves the move until confirmation.
	game.embedded_mode=false
	await start_pour();game._process(0.42)
	await click(game.buttons.Restart)
	check(game.state=="restart" and not game.animator.busy and game.rules.snapshot()==after,"mid-pour restart settles safely and asks before resetting")
	await click(game.buttons.CancelRestart)
	check(game.state=="playing" and game.moves==1 and game.rules.snapshot()==after,"cancel restart keeps committed layer state")
	await click(game.buttons.Undo);await start_pour();game._process(0.42)
	await click(game.buttons.Restart);await click(game.buttons.ConfirmRestart)
	check(game.moves==0 and game.rules.snapshot()==initial and not game.animator.busy,"confirmed restart resets model, glass and timer without lingering callback")
	# Locale rebuild and external level replacement safely dispose active visual nodes.
	await start_pour();game._process(0.42);game.set_locale("en")
	check(game.moves==1 and game.rules.snapshot()==after and not game.animator.busy,"locale switch settles active visuals before rebuilding nodes")
	check(game.bottle_nodes[0].visual.layers==after.bottles[0] and game.bottle_nodes[2].visual.volume()==2,"rebuilt localized glass stays in sync")
	game.load_level(0);await process_frame;await start_pour();game._process(0.42);game.load_level(1);await process_frame
	check(game.level_index==1 and game.moves==0 and not game.animator.busy and wins==0,"external new-level load cancels old animator without stale win callback")
	# Last pour + home/restart must settle a single real win, not silently lose or double it.
	game.load_level(0);await process_frame
	for action in [[0,2],[1,0]]:
		await click(game.bottle_nodes[action[0]]);await click(game.bottle_nodes[action[1]]);settle_visuals()
	await click(game.bottle_nodes[1]);await click(game.bottle_nodes[2]);game._process(0.42)
	check(game.rules.is_solved() and game.state=="playing" and wins==0,"last move is logically solved while final visual is active")
	game.embedded_mode=true;await click(game.buttons.Instructions)
	check(game.state=="won" and wins==1 and exits==2 and not game.animator.busy,"leaving last pour settles and reports the real win exactly once")
	game.prepare_to_leave();game._finish_pour()
	check(wins==1,"repeated exit and result evaluation cannot duplicate completion")
	game.load_level(0);await process_frame;await start_pour();game._process(0.42)
	game.queue_free();await process_frame;await process_frame
	check(wins==1,"destroying a view during activity does not dispatch a stale result")
	print("WATER_SORT_ANIMATION_BRIDGE ",JSON.stringify({"checks":checks,"failures":failures,"passed":failures.is_empty()}))
	quit(0 if failures.is_empty() else 1)
