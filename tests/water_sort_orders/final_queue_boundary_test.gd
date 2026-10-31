extends "res://tests/water_sort_campaign50/memory_fixture.gd"
const Entry=preload("res://scenes/water_sort/orders_v3.tscn")
var app
var g
func setup()->void:
	g.levels[1]={"id":2,"bottles":[["red","red","red"],["red"],["green","green","green"],["green"],["blue","blue","blue"],["blue"],[],[]],"orders":["red","green","blue","orange"]}
	g.load_level(1);app._show_game();g.set_process(false)
	await click_ui(g.bottle_nodes[0]);await click_ui(g.bottle_nodes[1]);g._process(.05)
	await click_ui(g.bottle_nodes[1]);await click_ui(g.bottle_nodes[6])
	check(g.presentation.input_queue.size()==1,"real conflicting clicks prepare internal queued intent")
func empty()->void:
	check(g.presentation.input_queue.is_empty() and g.presentation.queued_source_id==0,"lifecycle clears all queued commands")
	for node in g.bottle_nodes:check(node.visual.get_node_or_null("QueuedFeedback")==null,"lifecycle clears visual feedback too")
func drain()->void:
	for i in 2000:
		if not g._animation_busy() and g.presentation.input_queue.is_empty():break
		g._process(.01)
func run()->void:
	app=Entry.instantiate();app.enable_audio=false;app.progress=progress_fixture("queue-boundary",Catalog.V3);app.energy=energy_fixture()
	root.add_child(app);await process_frame;app.set_process(false);g=app.game;g.set_process(false)
	var requests:Array=[];g.reward_requested.connect(func(kind):requests.append(kind))
	await setup();await click_ui(g.buttons.Undo);await drain();empty();check(g.moves==1 and requests==["undo"],"undo waits for current move, clears queue and requests one ad before mutation")
	await setup();await click_ui(g.buttons.Pause);empty();g.resume_game();await drain();check(g.moves==1,"pause cancels queue without future unintended pour")
	await setup();await pause_restart(g);empty();await click_ui(g.buttons.CancelRestart);check(g.state=="paused","cancel restart returns to originating pause");g.resume_game();await drain();check(g.moves==1,"cancelled restart never revives discarded queue")
	await setup();g.load_level(0);empty();check(g.moves==0,"new board retains no previous command")
	await setup();g.open_reward("bottle");check(g.state=="playing" and g.presentation.input_queue.size()==1,"busy assistance does not open an ad or discard input");g.pause_game();empty();g.resume_game();await drain();check(g.moves==1,"cancelled intent never revives after modal return")
	# Repeated source click cancels visible selection without lifting.
	await setup();await click_ui(g.bottle_nodes[4]);await click_ui(g.bottle_nodes[4]);check(g.presentation.queued_source_id==0 and g.bottle_nodes[4].visual.get_node_or_null("QueuedFeedback")==null,"repeat pending source cancels bottle feedback")
	# Duplicate pair suppressed, invalid first intent discarded, later valid executes.
	g.presentation.clear_inputs();await click_ui(g.bottle_nodes[1]);await click_ui(g.bottle_nodes[6]);await click_ui(g.bottle_nodes[2]);await click_ui(g.bottle_nodes[3]);await click_ui(g.bottle_nodes[2]);await click_ui(g.bottle_nodes[3]);check(g.presentation.input_queue.filter(func(item):return item.source_id==g.bottle_nodes[2].get_instance_id() and item.target_id==g.bottle_nodes[3].get_instance_id()).size()<=1 and g.moves<=2,"duplicate pair cannot be queued or committed twice")
	await drain();empty();check(g.moves==2 and g.rules.delivered==[1,3],"invalid collected bottle cancelled; later stable IDs execute once")
	app.free();report("QUEUE_BOUNDARY","queue-boundary-report.json")
