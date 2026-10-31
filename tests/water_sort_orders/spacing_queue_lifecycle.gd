extends "res://tests/water_sort_orders/final_queue_boundary_test.gd"
var fixture_count:=10
func setup()->void:
	# Independent cases must not retain the AppShell P1 modal opened by the
	# previous explicit rewarded-undo request. No reward is simulated/granted.
	if is_instance_valid(app.p1_confirmation):app._close_p1_confirmation()
	var bottles:Array=[["red","red","red"],["red"],["green","green","green"],["green"],["blue","blue","blue"],["blue"],[],[]]
	while bottles.size()<fixture_count:bottles.append(["purple"])
	g.levels[1]={"id":2,"bottles":bottles,"orders":["red","green","blue","orange"]}
	g.load_level(1);app._show_game();g.set_process(false)
	await click_ui(g.bottle_nodes[0]);await click_ui(g.bottle_nodes[1]);g._process(.05)
	await click_ui(g.bottle_nodes[1]);await click_ui(g.bottle_nodes[6])
	check(g.presentation.input_queue.size()==1,"real conflicting clicks prepare internal queued intent")
func run()->void:
	root.content_scale_size=Vector2i(1080,1920);root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--count="):fixture_count=int(arg.trim_prefix("--count="))
		if arg.begins_with("--width="):root.size.x=int(arg.trim_prefix("--width="))
		if arg.begins_with("--height="):root.size.y=int(arg.trim_prefix("--height="))
	print("SPACING_QUEUE_FIXTURE ",fixture_count," window=",root.size," explicit_mock_cli=",OS.get_cmdline_user_args().has("--dev-test-ads"))
	await super.run()
