extends "res://tests/water_sort_orders/native_reward_host_smoke.gd"
func pointer(point:Vector2,down:bool)->void:
	var event:=InputEventMouseButton.new();event.position=point;event.global_position=point;event.button_index=MOUSE_BUTTON_LEFT;event.pressed=down;root.push_input(event,true)
func run()->void:
	check(DisplayServer.get_name()=="headless","headless only")
	root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS;root.content_scale_size=Vector2i(1080,1920)
	for size in [Vector2i(320,480),Vector2i(390,844),Vector2i(430,932)]:
		root.size=size
		for locale in ["zh","en"]:
			for id in ["home_start","home_settings","home_levels","home_ranking"]:
				await make(func(api):api.privacy=true);app.progress.data.locale=locale;app.show_home();await process_frame;await process_frame
				var button:Button=app.home.buttons[id];var instance:int=button.get_instance_id();var point:Vector2=button.get_global_transform_with_canvas()*(button.size*.5)
				pointer(point,true);check(button.button_pressed,"native home original pressed "+id)
				memory.now+=1;app._process(1.01);native.ad_event.emit("","loaded","");await process_frame;await process_frame
				check(is_instance_id_valid(instance),"energy/native status does not replace held original "+id)
				pointer(point,false);await process_frame;await process_frame
				var activated:bool=app.game.visible if id=="home_start" else (app.home.settings_open if id=="home_settings" else app.home.page==("levels" if id=="home_levels" else "ranking"))
				check(activated,"native status/tick release activates "+id+str(size)+locale)
				await dispose()
	FileAccess.open("res://native_reward_evidence/native_input_tick.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures},"\t"))
	print("NATIVE_INPUT_TICK ",JSON.stringify({"checks":checks,"failures":failures}));quit(0 if failures.is_empty() else 1)
