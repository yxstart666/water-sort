extends "res://tests/water_sort_campaign50/memory_fixture.gd"
const Home = preload("res://scripts/water_sort/home_menu.gd")
var selected: Array=[]
var home

func press(id: String) -> void:
	check(home.buttons.has(id) and not home.buttons[id].disabled,"selector control %s is present and enabled" % id)
	if home.buttons.has(id) and not home.buttons[id].disabled:
		await click_ui(home.buttons[id])

func inspect_page(index: int, first: int, last: int, previous: bool, next: bool) -> void:
	check(home.page=="levels" and home.page_index==index,"selector uses page%d index" % (index+1))
	check(home.label_nodes.page_range.text=="%d–%d" % [first,last],"selector reports exact range %d–%d" % [first,last])
	var ids: Array=[]
	for key in home.buttons:
		if str(key).begins_with("level_"): ids.append(int(str(key).trim_prefix("level_")))
	ids.sort()
	check(ids==range(first,last+1),"page%d exposes only %d–%d level buttons" % [index+1,first,last])
	check(home.buttons.previous.disabled!=previous and home.buttons.next.disabled!=next,"page%d previous/next enabled states are bounded" % (index+1))
	assert_selector_arrow_art(home)
	for number in ids:
		check(not home.buttons["level_%d" % number].disabled,"completed selector level%d is enabled" % number)
		var label: Label=home.label_nodes["best_%d" % (number-1)]
		check(label.position.y>=524 and label.position.y+label.size.y<1243,"page%d level%d record fits within four-row grid" % [index+1,number])
	check(not home.buttons.has("level_51"),"page%d never exposes level51" % (index+1))

func run() -> void:
	report_context={"home_menu_sha256":FileAccess.get_sha256("res://scripts/water_sort/home_menu.gd"),"tested_content":"native menu with synthetic append50 in-memory progress; no gameplay claims"}
	root.size=Vector2i(1080,1920)
	var active: Array=appended_fifty()
	var progress=progress_fixture("all",V2,active)
	for index in range(50):
		var id: String=progress.reserve_attempt(index)
		check(progress.record_result(index,index+3,9.25+index,id),"selector in-memory level%d record exists" % (index+1))
	home=Home.new()
	home.progress=progress
	home.size=Vector2(1080,1920)
	home.start_level.connect(func(index: int): selected.append(index))
	root.add_child(home)
	home.update_energy({"ok":true,"energy":30.0,"cap":30.0,"next_recovery_seconds":null})
	await process_frame
	for locale in ["zh","en"]:
		progress.set_preference("locale",locale)
		home.show_page("home")
		check(home.label_nodes.water_sort_campaign.text==("50 关 · 逐关解锁" if locale=="zh" else "50 levels · Unlock as you play"),locale+" home uses honest fifty-level campaign caption")
		check(home.label_nodes.home_continue.text==("开始第50关" if locale=="zh" else "Play Level 50"),locale+" all-won continue points to last level50")
		check(home.label_nodes.energy.text=="30/30",locale+" shared-energy label normalizes integral JSON floats")
		await press("home_levels")
		inspect_page(2,41,50,true,false)
		await assert_disabled_arrow_click(home,"next")
		await press("previous")
		inspect_page(1,21,40,true,true)
		await press("previous")
		inspect_page(0,1,20,false,true)
		await assert_disabled_arrow_click(home,"previous")
		await press("level_20")
		await press("next")
		inspect_page(1,21,40,true,true)
		await press("level_21")
		await press("next")
		inspect_page(2,41,50,true,false)
		await assert_disabled_arrow_click(home,"next")
		await press("level_50")
		check(selected.slice(selected.size()-3)==[19,20,49],locale+" old20, appended21 and final50 selector inputs emit exact zero-based targets")
	check(home.errors.is_empty(),"selector native menu art loaded without asset errors")
	var old_home=Home.new()
	old_home.progress=progress_fixture("retained-five",V1)
	old_home.size=Vector2(1080,1920)
	root.add_child(old_home)
	old_home.show_page("levels")
	await process_frame
	check(old_home.board.get_node("levels_next").texture==old_home._texture("res://assets/art_review/static_menus_v1/unpacked/STATIC_MENU_ASSETS_CANDIDATE_v1/assets/levels/levels_next.png"),"original-five selector keeps its pre-existing normal next artwork; v2 boundary fix does not restyle it")
	check(old_home.board.get_node("levels_previous").texture==old_home._texture("res://assets/art_review/night_state_supplement_v1/unpacked/STATIC_NIGHT_STATE_SUPPLEMENT_v1/assets/levels_previous_disabled.png"),"original-five selector preserves its pre-existing first-page previous artwork")
	old_home.queue_free()
	home.queue_free()
	await process_frame
	report("WATER_SORT_CAMPAIGN50_SELECTOR","selector_results.json")
