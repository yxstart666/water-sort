extends "res://tests/water_sort_campaign50/memory_fixture.gd"
const Entry=preload("res://scenes/water_sort/orders_v3.tscn")
const Layout=preload("res://scripts/ui_restore/screen_layout.gd")
func run()->void:
	root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_size=Vector2i(1080,1920)
	check(ProjectSettings.get_setting("application/run/main_scene")=="res://scenes/playtest/current_test.tscn","default real-energy entry")
	check(FileAccess.get_sha256("res://assets/colorpause_ui_20261030/home/home_logo_starfield_merged_v2.png")=="24e171cef8e36de1cad7e2f2e5b2608c45b504ea38322773a3926741b952f31e","exact approved fused source")
	check(FileAccess.get_sha256("res://assets/colorpause_ui_20261030/secondary_popups/sprites/restart_title_zh-CN.webp")=="b067f3374831477cf789d14d5761f0eddc02f8a42a78c53b7e5014357a83f655","exact restart alpha source")
	check(FileAccess.get_sha256("res://data/water_sort/orders_v3/candidates/c3_full50_20261030.json")=="8462bdcf1ff468a075a35cd9ec5d5adceaa48a9dd52a823aaf9de45589eba08f","C3 data unchanged; no new level acceptance")
	for dims in [Vector2i(320,480),Vector2i(390,844),Vector2i(430,932)]:
		root.size=dims
		for locale in ["zh","en"]:
			reset_memory();var app=Entry.instantiate();app.enable_audio=false;app.progress=progress_fixture("home-update",Catalog.V3);app.energy=energy_fixture();app.progress.set_preference("locale",locale)
			root.add_child(app);await process_frame;await process_frame
			var h=app.home;var policy=Layout.policy(h);policy._sync_background()
			check(policy.background.texture==Layout.HOME_BACKGROUND,"home-only fused texture "+str(dims)+locale)
			check(policy.background.size==root.get_visible_rect().size,"full-window background coverage")
			check(policy.background.stretch_mode==TextureRect.STRETCH_KEEP_ASPECT_COVERED and policy.background.mouse_filter==Control.MOUSE_FILTER_IGNORE,"uniform noninteractive backdrop")
			check(policy.background.texture.get_image().has_mipmaps(),"background imported mipmaps")
			check(h.find_child("HomeHeroApproved512",true,false)==null and h.find_child("HomeHeroFrameCandidate",true,false)==null,"no duplicate old hero or frame")
			check(h.find_child("HomeTitleCandidate",true,false)!=null,"independent title remains")
			check(h.buttons.has("home_start") and h.buttons.has("home_settings"),"native interactive buttons remain")
			check(not h.start_breath_enabled,"Start breathing remains disabled")
			await click_ui(h.buttons.home_settings);check(is_instance_valid(h.modal),"settings opens")
			await click_ui(h.buttons.close_settings);await create_timer(.2).timeout
			await click_ui(h.buttons.home_levels);policy._sync_background();check(policy.background.texture==Layout.BACKGROUND,"levels keeps existing background")
			await click_ui(h.buttons.back);policy._sync_background();check(policy.background.texture==Layout.HOME_BACKGROUND,"home reentry restores fused background")
			app._menu_start(0);await process_frame;policy._sync_background()
			check(app.game.visible and not h.visible,"legal first level actually enters game")
			check(policy.background.texture==Layout.BACKGROUND,"game keeps existing background")
			app.show_home();await process_frame;policy._sync_background();check(policy.background.texture==Layout.HOME_BACKGROUND,"game return restores home background")
			app.queue_free();await process_frame
	var result:={"checks":checks,"failures":failures,"headless":true,"native_visual":"NOT_RUN"}
	FileAccess.open("res://../current_home_result.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	print("CURRENT_HOME "+JSON.stringify(result));quit(0 if failures.is_empty() else 1)
