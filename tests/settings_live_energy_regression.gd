extends SceneTree
const Entry=preload("res://scenes/water_sort/orders_v3.tscn")
const Catalog=preload("res://scripts/water_sort/campaign_catalog.gd")
const Progress=preload("res://scripts/playtest/difficulty_progress.gd")
const Energy=preload("res://scripts/services/energy_service.gd")
var now:=100000
var saved_progress:Dictionary={}
var saved_energy:Dictionary={}
var checks:=0
var failures:Array[String]=[]
var evidence:Array=[]
func _initialize()->void:call_deferred("run")
func check(ok:bool,message:String)->void:
	checks+=1
	if not ok:failures.append(message);push_error(message)
func snapshot_ids(home)->Dictionary:
	var ids:Dictionary={"board":home.board.get_instance_id(),"modal":home.modal.get_instance_id(),"canvas":home.modal.canvas.get_instance_id(),"energy":home.label_nodes.energy.get_instance_id(),"start":home.start_breath_group.get_instance_id()}
	for key in home.modal.buttons:ids[key]=home.modal.buttons[key].get_instance_id()
	return ids
func run()->void:
	check(DisplayServer.get_name()=="headless","this regression is headless only")
	root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS;root.content_scale_size=Vector2i(1080,1920)
	for viewport in [Vector2i(320,480),Vector2i(390,693),Vector2i(1132,2012)]:
		root.size=viewport
		for locale in ["zh","en"]:
			now=100000;saved_progress={};saved_energy={}
			var config:Dictionary=Catalog.configuration(Catalog.V3)
			var pack:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(config.level_path))
			var progress=Progress.new(func():return {"ok":false,"reason":"missing"} if saved_progress.is_empty() else {"ok":true,"data":saved_progress.duplicate(true)},func(value):saved_progress=value.duplicate(true);return true,config)
			progress.bind_level_pack(pack.levels);progress.load_progress();progress.set_preference("locale",locale)
			var energy=Energy.new(func():return now,func():return {"ok":false,"reason":"missing"},func(value):saved_energy=value.duplicate(true);return true)
			energy.enter_attempt("settings-regression")
			var app=Entry.instantiate();app.enable_audio=false;app.progress=progress;app.energy=energy
			root.add_child(app);app.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			await process_frame;await process_frame
			var home=app.home
			check(app.is_processing(),"production AppShell process remains enabled")
			home.buttons.home_settings.pressed.emit()
			await create_timer(.20).timeout
			check(home.settings_open and home.modal.home_settings,"real home settings opened")
			var ids:Dictionary=snapshot_ids(home)
			var prefs:Dictionary=home.modal.preferences.duplicate(true)
			var original_alpha:float=home.modal.modulate.a
			check(is_equal_approx(original_alpha,1.0),"opening fade completed")
			home.modal.buttons.music_toggle.grab_focus()
			for tick in 3:
				now+=1;app._refresh_energy()
				check(snapshot_ids(home)==ids,"energy tick keeps all settings/header/start node identities")
				check(home.modal.preferences==prefs,"energy tick keeps every switch/locale preference")
				check(is_equal_approx(home.modal.modulate.a,original_alpha),"energy tick does not restart fade")
				check(home.modal.buttons.music_toggle.has_focus(),"energy tick preserves focus")
				check(home.energy_state.next_recovery_seconds==120-(tick+1),"countdown state updates while settings remains open")
				check(home.label_nodes.energy.text=="25/30","HUD stays correct while countdown advances")
			# Exercise the real one-second AppShell polling route without calling it manually.
			now+=1;await create_timer(1.10).timeout
			check(home.energy_state.next_recovery_seconds==116,"enabled production timer refreshes state")
			check(snapshot_ids(home)==ids and is_equal_approx(home.modal.modulate.a,1.0),"real timer keeps nodes and completed fade")
			var events:=[0]
			home.preferences_changed.connect(func(_value):events[0]+=1)
			var music_before_press:bool=progress.data.music
			var down:=InputEventKey.new();down.keycode=KEY_SPACE;down.physical_keycode=KEY_SPACE;down.pressed=true
			root.push_input(down);await process_frame
			check(home.modal.buttons.music_toggle.button_pressed,"real engine key press establishes held button")
			now=100120;app._refresh_energy()
			check(snapshot_ids(home)==ids,"recovery while pressed keeps input node")
			check(home.modal.buttons.music_toggle.button_pressed,"pressed state survives recovery")
			check(home.label_nodes.energy.text=="26/30" and home.energy_state.current==26,"actual recovered energy updates HUD, not return-only")
			var up:=InputEventKey.new();up.keycode=KEY_SPACE;up.physical_keycode=KEY_SPACE;up.pressed=false
			root.push_input(up);await process_frame
			check(events[0]==1 and progress.data.music!=music_before_press,"held press releases exactly one saved preference action")
			ids=snapshot_ids(home)
			# Unavailable/full transitions update the same HUD without changing settings controls.
			home.update_energy({"ok":false,"energy":null,"cap":30,"next_recovery_seconds":null})
			check(home.label_nodes.energy.text=="--/30" and home.energy_state.next_recovery_seconds==0,"unavailable HUD/null normalization")
			check(snapshot_ids(home)==ids,"unavailable state does not reset settings")
			app.last_energy={};app._refresh_energy()
			check(home.label_nodes.energy.text=="26/30","real energy restores HUD after unavailable")
			# Explicit preference changes must still rebuild with the new saved state.
			var expected_music:bool=not progress.data.music
			home.modal._action("music_toggle");await process_frame
			check(progress.data.music==expected_music and home.modal.preferences.music==expected_music,"music action persists and renders changed switch")
			check(home.modal.get_instance_id()!=ids.modal,"explicit preference action retains rebuild route")
			var changed_id:int=home.modal.get_instance_id()
			home.modal._action("language");await process_frame
			check(progress.data.locale!=(locale) and home.modal.preferences.locale==progress.data.locale,"language action changes locale and view")
			check(home.modal.get_instance_id()!=changed_id and home.modal.preferences.music==expected_music,"language rebuild retains switch state")
			# Opening Help temporarily replaces Settings; closing Help restores it.
			home.modal._action("how_to_play");await process_frame
			check(home.modal.has_node("LiveHelpPour"),"settings Help opens real guide route")
			var guide_id:int=home.modal.get_instance_id();now+=1;app._refresh_energy()
			check(home.modal.get_instance_id()==guide_id,"existing guide incremental update preserved")
			home.modal.closed.call();await process_frame
			check(home.settings_open and home.modal.home_settings and home.modal.preferences.music==expected_music,"closing guide restores settings and preferences")
			home.modal._action("close");await create_timer(.16).timeout
			check(not home.settings_open and not is_instance_valid(home.modal),"settings close returns to home")
			home.show_page("levels");await process_frame
			check(home.page=="levels" and not home.settings_open,"page navigation still rebuilds correct page")
			home.show_page("home");await process_frame
			home.buttons.home_settings.pressed.emit();await process_frame
			check(home.modal.preferences.locale==progress.data.locale and home.modal.preferences.music==expected_music,"return and reopen restores saved settings")
			evidence.append({"viewport":str(viewport),"initial_locale":locale,"initial_ids":ids,"recovered_hud":"26/30","app_process_enabled":app.is_processing(),"stored_music":progress.data.music,"stored_locale":progress.data.locale})
			app.debug_ads.shutdown();app.free();await process_frame
	var result:Dictionary={"checks":checks,"failures":failures,"evidence":evidence,"headless":true,"native_visual_or_smoothness_pass":false,"user_data_directory":OS.get_user_data_dir()}
	DirAccess.make_dir_recursive_absolute("res://review_settings_energy")
	FileAccess.open("res://review_settings_energy/result.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	print("SETTINGS_LIVE_ENERGY ",JSON.stringify(result));quit(0 if failures.is_empty() else 1)
