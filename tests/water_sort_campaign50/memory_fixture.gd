extends SceneTree
## Shared headless-only test harness. Every progress/energy read and write is injected.
const Progress = preload("res://scripts/water_sort/progress.gd")
const Energy = preload("res://scripts/services/energy_service.gd")
const Catalog = preload("res://scripts/water_sort/campaign_catalog.gd")
const Rules = preload("res://scripts/experiments/water_sort_v1/rules.gd")
const V1 := "water_sort_v1"
const V2 := "water_sort_campaign_v2"
const V1_PACK_SHA256 := "c499aeebba6a5a3ba7be8f28cff2ca7857297dfe78cb02116480e3ae8f5892ba"
var report_context: Dictionary={}
var checks := 0
var failures: Array[String] = []
var memory := {"progress":{},"energy":{},"now":1000,"fail_progress":false,"fail_energy":false,"progress_writes":0,"energy_writes":0,"attempted_progress":{}}

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
		push_error(label)

func rewarded_undo(app)->void:
	app.debug_ads.set_enabled(true)
	var prior:Dictionary=app.game.rules.snapshot()
	await click_ui(app.game.buttons.Undo)
	for i in 1600:
		if not app.game._animation_busy():break
		app.game._process(.01)
	check(app.debug_ads.active_request().get("placement")=="undo","Undo requires its own ad request")
	check(app.game.rules.snapshot()==prior,"Undo does not change logical board before reward")
	if is_instance_valid(app.ad_dialog) and app.ad_dialog.buttons.has("AdCompleted"):
		await click_ui(app.ad_dialog.buttons.AdCompleted)
	else:check(false,"Undo ad completion control exists")

func pack(campaign: String = V2) -> Dictionary:
	var configuration: Dictionary = Catalog.configuration(campaign)
	return JSON.parse_string(FileAccess.get_file_as_string(str(configuration.level_path)))

func progress_fixture(slot: String, campaign: String = V2, supplied_levels: Array = [], auto_load := true):
	var read := func():
		return {"ok":true,"data":memory.progress[slot].duplicate(true)} if memory.progress.has(slot) else {"ok":false,"reason":"missing"}
	var write := func(value: Dictionary):
		memory.progress_writes += 1
		memory.attempted_progress = value.duplicate(true)
		if memory.fail_progress: return false
		memory.progress[slot] = value.duplicate(true)
		return true
	# Deliberately retain the original two-argument constructor for the v1 default.
	var progress = Progress.new(read,write) if campaign==V1 else Progress.new(read,write,Catalog.configuration(campaign))
	progress.bind_level_pack(supplied_levels if not supplied_levels.is_empty() else pack(campaign).levels)
	if auto_load: progress.load_progress()
	return progress

func energy_fixture():
	return Energy.new(func(): return memory.now,func():
		return {"ok":true,"data":memory.energy.duplicate(true)} if not memory.energy.is_empty() else {"ok":false,"reason":"missing"},func(value: Dictionary):
		memory.energy_writes += 1
		if memory.fail_energy: return false
		memory.energy=value.duplicate(true)
		return true)

func reset_memory() -> void:
	memory={"progress":{},"energy":{},"now":1000,"fail_progress":false,"fail_energy":false,"progress_writes":0,"energy_writes":0,"attempted_progress":{}}

func rejected_save(candidate: Dictionary, label: String, levels: Array = []) -> void:
	memory.progress.rejected=candidate.duplicate(true)
	var before: Dictionary=memory.progress.rejected.duplicate(true)
	var writes: int=int(memory.progress_writes)
	var progress=progress_fixture("rejected",V2,levels)
	check(not progress.persistent and progress.load_error=="invalid_water_sort_progress",label+" is rejected")
	check(not progress.save_progress() and memory.progress.rejected==before and int(memory.progress_writes)==writes,label+" remains unmodified")

func pause_restart(game) -> void:
	# The gameplay duplicate is removed; exercise the retained real pause route.
	await click_ui(game.buttons.Pause)
	await create_timer(0.18).timeout
	check(game.state=="paused" and is_instance_valid(game.overlay),"pause restart entry available")
	await click_ui(game.overlay.buttons.restart)
	await create_timer(0.18).timeout
	check(game.state=="restart","pause restart opens confirmation")

func report(prefix: String, file_name: String) -> void:
	var result := {"checks":checks,"failures":failures,"passed":failures.is_empty(),"storage":"all progress and energy use injected memory readers/writers; no user saves accessed","engine_mode":"headless"}
	result.merge(report_context,true)
	var file := FileAccess.open("res://tests/water_sort_campaign50/"+file_name,FileAccess.WRITE)
	if file: file.store_string(JSON.stringify(result,"\t")+"\n")
	print(prefix," ",JSON.stringify(result))
	quit(0 if failures.is_empty() else 1)

func click_ui(control: Control) -> void:
	check(is_instance_valid(control),"headless viewport click target exists")
	if not is_instance_valid(control): return
	await process_frame
	var point: Vector2=control.get_global_transform_with_canvas()*(control.size*0.5)
	for pressed in [true,false]:
		var event:=InputEventMouseButton.new()
		event.position=point
		event.global_position=point
		event.button_index=MOUSE_BUTTON_LEFT
		event.pressed=pressed
		root.push_input(event,true)
		await process_frame

func assert_selector_arrow_art(menu) -> void:
	for id in ["previous","next"]:
		var node_name: String="levels_"+id
		var arrow=menu.board.get_node_or_null(node_name)
		check(arrow is Sprite2D,"selector %s static art remains an identifiable Sprite2D" % id)
		if not arrow is Sprite2D: continue
		var disabled: bool=menu.page_index<=0 if id=="previous" else (menu.page_index+1)*20>=menu.progress.level_count
		var normal: String="res://assets/ui_restore/menu_candidates_v1/assets/levels/levels_previous.png" if id=="previous" else "res://assets/art_review/static_menus_v1/unpacked/STATIC_MENU_ASSETS_CANDIDATE_v1/assets/levels/levels_next.png"
		var disabled_path: String="res://assets/art_review/night_state_supplement_v1/unpacked/STATIC_NIGHT_STATE_SUPPLEMENT_v1/assets/levels_"+id+"_disabled.png"
		check(arrow.texture==menu._texture(disabled_path if disabled else normal),"page%d %s uses exact existing %s arrow artwork" % [menu.page_index+1,id,"faded gray disabled" if disabled else "normal enabled"])
		check(arrow.texture.get_size()==Vector2(136,94) and arrow.position==Vector2(222 if id=="previous" else 585,1243) and arrow.scale==Vector2.ONE and is_zero_approx(arrow.rotation) and arrow.offset==Vector2.ZERO and not arrow.centered and not arrow.flip_h and not arrow.flip_v and arrow.z_index==30,"page%d %s retains exact authored136x94 image geometry, position and layer" % [menu.page_index+1,id])
		check(arrow.modulate==Color.WHITE and arrow.self_modulate==Color.WHITE and arrow.material==null and arrow.is_visible_in_tree(),"page%d %s reuses authored art without extra tint, material or hiding" % [menu.page_index+1,id])
		var button: Button=menu.buttons[id]
		check(button.disabled==disabled and button.position==arrow.position and button.size==Vector2(136,94),"page%d %s transparent hit target matches visible arrow bounds and disabled state" % [menu.page_index+1,id])
		var image: Image=arrow.texture.get_image()
		var chroma := 0.0
		var samples := 0
		for y in range(image.get_height()):
			for x in range(image.get_width()):
				var color: Color=image.get_pixel(x,y)
				if color.a>0.5:
					chroma+=maxf(color.r,maxf(color.g,color.b))-minf(color.r,minf(color.g,color.b))
					samples+=1
		check(samples>1000 and (chroma/samples<0.06 if disabled else chroma/samples>0.2),"page%d %s visible pixels are %s, not misleadingly bright normal art" % [menu.page_index+1,id,"near-neutral gray" if disabled else "normal full-color"])

func assert_disabled_arrow_click(menu, id: String) -> void:
	check(menu.buttons.has(id) and menu.buttons[id].disabled,"boundary %s is actually input-disabled before click" % id)
	var page_before: int=int(menu.page_index)
	var range_before: String=menu.label_nodes.page_range.text
	var data_before: Dictionary=menu.progress.data.duplicate(true)
	await click_ui(menu.buttons[id])
	check(menu.page=="levels" and menu.page_index==page_before and menu.label_nodes.page_range.text==range_before,"real click on disabled %s arrow cannot navigate past campaign boundary" % id)
	check(menu.progress.data==data_before,"disabled %s click cannot change progress or reserve an attempt" % id)
	assert_selector_arrow_art(menu)

func original_twenty() -> Array:
	return JSON.parse_string(FileAccess.get_file_as_string("res://data/water_sort/campaign_v2/levels20_checkpoint.json")).levels

func appended_fifty() -> Array:
	var result: Array=original_twenty().duplicate(true)
	for index in range(20,50):
		var level: Dictionary=result[index%20].duplicate(true)
		level.id=index+1
		level.title="兼容测试 %d" % (index+1)
		level.title_en="Compatibility fixture %d" % (index+1)
		result.append(level)
	return result

func legacy_snapshot(slot: String, complete_count: int, pending := false) -> Dictionary:
	var levels: Array=original_twenty()
	var progress=progress_fixture(slot,V2,levels)
	var energy=energy_fixture()
	for index in range(complete_count):
		var id: String=progress.reserve_attempt(index)
		check(not id.is_empty() and energy.enter_attempt(id).accepted,"old20 level%d paid entry" % (index+1))
		check(progress.record_result(index,index+4,7.125+index,id) and energy.complete_attempt(id).accepted,"old20 level%d paired record and refund" % (index+1))
	progress.set_preference("locale","en")
	progress.set_preference("music",false)
	progress.set_preference("sound",false)
	if pending:
		var id: String=progress.reserve_attempt(complete_count)
		check(energy.enter_attempt(id).accepted,"old20 unfinished attempt was charged exactly once")
		var rules=Rules.new(levels[complete_count])
		var proofs: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/water_sort_v1/candidate20_v2/certificates.json"))
		var action: Array=proofs.levels[complete_count].shortest_solution[0]
		rules.pour(int(action[0]),int(action[1]))
		check(progress.save_checkpoint(id,rules.snapshot(),1,4.875),"old20 saves an actual in-progress board checkpoint")
	var saved: Dictionary=memory.progress[slot].duplicate(true)
	# The shipped twenty-level adapter predates pack_level_count. Preserve its
	# exact format instead of passing a newly synthesized fifty-level save off
	# as historical data. Every other field comes from the native old20 API.
	saved.erase("pack_level_count")
	memory.progress[slot]=saved.duplicate(true)
	return saved

func without_pack_metadata(value: Dictionary) -> Dictionary:
	var result: Dictionary=value.duplicate(true)
	result.erase("pack_digest")
	result.erase("pack_level_count")
	return result

func run() -> void:
	push_error("Run a concrete test runner, not memory_fixture.gd")
	quit(2)
