extends "res://tests/water_sort_campaign50/memory_fixture.gd"
const Entry=preload("res://scenes/water_sort/orders_v3.tscn")
var out:=""
var capture:=false
var full:=false
var rows:Array=[]
func snap(id:String,node:Node)->void:
	await process_frame;await process_frame
	var info:Array=[]
	for glyph in node.find_children("Approved*Glyphs","Control",true,false):
		var metrics:Dictionary=glyph.metrics();check(metrics.complete,"approved glyph coverage "+id+" "+metrics.text);metrics.erase("glyphs");info.append(metrics)
	var guide=node.get_node_or_null("LiveHelpPour")
	rows.append({"id":id,"numeric":info,"guide_stage":guide.stage if guide!=null else "","guide_paused":guide.paused if guide!=null else false})
	if capture:
		await create_timer(.08).timeout;RenderingServer.force_draw();await process_frame
		check(root.get_texture().get_image().save_png(out+"/"+id+".png")==OK,"native frame "+id)
func run()->void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):out=arg.trim_prefix("--out=")
		if arg=="--capture":capture=true
		if arg=="--full":full=true
	if out.is_empty():quit(2);return
	DirAccess.make_dir_recursive_absolute(out)
	root.title="ColorPause Final UI Review (isolated memory)"
	root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS;root.content_scale_size=Vector2i(1080,1920)
	var sizes:Array=[Vector2i(320,480),Vector2i(320,569),Vector2i(390,693),Vector2i(430,764),Vector2i(1132,2022),Vector2i(390,844),Vector2i(430,932)] if full else [Vector2i(390,693)]
	for dims in sizes:
		root.size=dims
		for locale in ["zh","en"]:
			reset_memory();var app=Entry.instantiate();app.enable_audio=false;app.progress=progress_fixture("formal-final",Catalog.V3);app.energy=energy_fixture();app.progress.set_preference("locale",locale)
			root.add_child(app);await process_frame;await process_frame;app.set_process(false);app.game.set_process(false)
			var h=app.home;var id:="%dx%d_%s_" % [dims.x,dims.y,locale]
			await snap(id+"home",h)
			await click_ui(h.buttons.home_settings);await snap(id+"settings",h.modal)
			await click_ui(h.buttons.sound_toggle_row);await snap(id+"settings_sound_off",h.modal)
			await click_ui(h.buttons.how_to_play);await snap(id+"guide_pick",h.modal)
			var guide=h.modal.get_node("LiveHelpPour");var before:Dictionary=app.progress.data.duplicate(true)
			await click_ui(guide.bottle_buttons[1]);check(guide.stage=="tap_target","guide actual source click")
			await snap(id+"guide_target",h.modal)
			await click_ui(guide.bottle_buttons[0]);guide.set_process(false);guide.set_paused(false)
			for i in 1200:
				guide._process(.01)
				if guide.stage=="done":break
			check(guide.stage=="done" and guide.sandbox.bottles[0].size()==4,"real renderer sandbox pour completes "+id)
			check(app.progress.data==before,"guide does not mutate progress")
			await snap(id+"guide_done",h.modal)
			await click_ui(h.buttons.rules_close)
			if h.buttons.has("close_settings"):
				await click_ui(h.buttons.close_settings);await create_timer(.20).timeout
			await click_ui(h.buttons.home_levels);await snap(id+"levels1",h)
			for page in maxi(0,ceili(app.progress.level_count/20.0)-1):await click_ui(h.buttons.next)
			await snap(id+"levels_last",h);await click_ui(h.buttons.back)
			h.energy_open=true;h._refresh();await snap(id+"energy_full",h)
			h.update_energy({"energy":7,"cap":30,"ok":true,"next_recovery_seconds":85});await snap(id+"energy_7",h)
			await click_ui(h.buttons.energy_close);app._menu_start(0);var g=app.game;g.set_process(false)
			g.reward_capability=func():return true
			g.state="stuck";g._result_overlay(false);await snap(id+"stuck_no_history",g)
			check(g.overlay.stuck_view!=null,"real stuck route formal view")
			g.overlay.buttons.BlockedUndo.disabled=false;await snap(id+"stuck_with_history",g)
			g.reward_capability=func():return false
			await snap(id+"stuck_no_bonus",g)
			app.queue_free();await process_frame
	var result:={"checks":checks,"failures":failures,"passed":failures.is_empty(),"frames":rows.size(),"rows":rows,"native_visual_accepted":false}
	FileAccess.open(out+"/report.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"));print("FINAL_UI "+JSON.stringify({"checks":checks,"failures":failures,"frames":rows.size()}));quit(0 if failures.is_empty() else 1)
