extends SceneTree
# Focus notifications must not add children during a scene-tree traversal.
var failures: Array=[]
var checks:=0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok: failures.append(label);push_error(label)
func run() -> void:
	var game=load("res://scenes/experiments/water_sort_v1.tscn").instantiate()
	root.add_child(game);await process_frame;game.set_process(false);game.resume_from_instructions()
	game.select_bottle(0);game.select_bottle(2);game._process(0.42)
	var snapshot: Dictionary=game.rules.snapshot()
	var moves: int=game.moves
	var elapsed: float=game.elapsed
	var position: Vector2=game.bottle_nodes[0].visual.global_position
	var volume: float=game.bottle_nodes[0].visual.volume()
	# Propagation recreates the unsafe notification traversal from the GUI.
	game.propagate_notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	game.propagate_notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	await process_frame
	check(game.state=="paused" and is_instance_valid(game.overlay),"focus loss builds a pause overlay after notification traversal")
	check(game.buttons.has("Resume") and game.buttons.Resume.is_inside_tree(),"pause overlay has a live resume button")
	game._process(1.0)
	check(game.elapsed==elapsed and game.bottle_nodes[0].visual.global_position==position and is_equal_approx(game.bottle_nodes[0].visual.volume(),volume),"focus pause freezes clock, pose and mass")
	check(game.rules.snapshot()==snapshot and game.moves==moves,"focus pause retains the committed puzzle and move")
	game.resume_game()
	check(game.state=="playing" and not is_instance_valid(game.overlay),"focus pause can resume normally")
	game._process(1.0)
	check(not game.animator.busy and game.moves==moves and game.rules.snapshot()==snapshot,"resume completes the same move once")
	print("WATER_SORT_FOCUS_PAUSE ",JSON.stringify({"checks":checks,"failures":failures,"passed":failures.is_empty()}))
	game.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
