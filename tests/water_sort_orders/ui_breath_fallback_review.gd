extends "res://tests/water_sort_campaign50/memory_fixture.gd"
const Entry=preload("res://scenes/water_sort/orders_v3.tscn")
func run()->void:
	var rows:Array=[]
	root.content_scale_size=Vector2i(1080,1920);root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	for dims in [Vector2i(320,480),Vector2i(390,844),Vector2i(1132,2022)]:
		root.size=dims
		for locale in ["zh","en"]:
			reset_memory();var app=Entry.instantiate();app.enable_audio=false;app.progress=progress_fixture("ui-fallback",Catalog.V3);app.progress.data.locale=locale;app.energy=energy_fixture();root.add_child(app);await process_frame;await process_frame;app.set_process(false)
			var h=app.home;var id:int=h.start_breath_group.get_instance_id();var center:Vector2=h.start_breath_group.position;var stable:=true
			check(not h.start_breath_enabled,"breathing default OFF "+locale)
			for frame in 360:
				h._process(1.0/60.0);stable=stable and h.start_breath_group.scale==Vector2.ONE and h.start_breath_group.position==center
			check(stable,"disabled button stays at unit scale and fixed center")
			for second in 5:h.update_energy({"energy":25,"cap":30,"next_recovery_seconds":120-second,"ok":true})
			check(h.start_breath_group.get_instance_id()==id,"ordinary recovering energy does not rebuild home")
			var numeric_nodes=h.find_children("ApprovedDynamicGlyphs","",true,false)
			for numeric in numeric_nodes:
				numeric.metrics();var binding=numeric.get_parent();binding._sync();numeric.metrics()
				for frame in 30:binding._sync()
				check(not numeric._dirty,"unchanged numeric binding does not invalidate draw geometry")
			app._menu_start(0);app.game.set_process(false);app.game.pause_game();await process_frame;await process_frame
			var dialog=app.game.overlay
			check(is_instance_valid(dialog) and dialog.buttons.has("vibration_toggle"),"real pause built")
			if locale=="en":
				var label_center:float=dialog.art.vibration_title.get_rect().get_center().y
				var matching:=false;var language_y:=0.0;var current_y:=0.0
				for node in dialog.canvas.get_children():
					if not node is TextureRect:continue
					var path:String=node.texture.resource_path
					if path.contains("toggle_") and absf(node.get_rect().get_center().y-label_center)<.1:matching=true
					if path.ends_with("language_en_blue.webp"):language_y=node.get_rect().get_center().y
					if path.ends_with("english_en.webp"):current_y=node.get_rect().get_center().y
				check(matching,"English vibration switch shares label row center")
				check(language_y>0 and absf(language_y-current_y)<.1,"English language and value share row center")
			await click_ui(dialog.buttons.resume);await create_timer(0.16).timeout;check(app.game.state=="playing","pause resume remains functional")
			rows.append({"size":str(dims),"locale":locale,"numeric_bindings":numeric_nodes.size(),"scale_static":stable})
			app.debug_ads.shutdown();app.free();await process_frame
	FileAccess.open("res://direction_review/final/ui_fallback_waited.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"rows":rows,"native_visual":"NOT_RUN","enabled_animation_smoothness":"NOT_CLAIMED"},"\t"));print("UI_BREATH_FALLBACK ",JSON.stringify({"checks":checks,"failures":failures,"cases":rows.size()}));quit(0 if failures.is_empty() else 1)
