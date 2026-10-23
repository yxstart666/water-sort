extends SceneTree
## V2-only actual-font metrics. No app shell, progress or energy stores are opened.
const View=preload("res://scripts/water_sort/campaign_view.gd")
const OldView=preload("res://scripts/experiments/water_sort_v1/view.gd")
var game
var checks:=0
var failures: Array[String]=[]
var largest_hint_lines:=0
var largest_body_lines:=0
func _initialize() -> void: call_deferred("run")
func check(okay: bool, label: String) -> void:
	checks+=1
	if not okay: failures.append(label);push_error(label)
func fit_label(id: String, height: float=-1.0) -> void:
	var label: Label=game.labels[id]
	var font: Font=label.get_theme_font("font")
	var pixels:=label.get_theme_font_size("font_size")
	var bound:=label.size
	var expected_width: float={"Title":940,"Level":440,"Stats":800,"LevelName":880,"Status":900,"RuleHint":952,"OverlayTitle":760,"OverlayBody":760}.get(id,bound.x)
	check(is_equal_approx(bound.x,expected_width),"%s %s retains authored width %.1f instead of expanding" %[game.locale,id,expected_width])
	if height>0: bound.y=height
	if label.autowrap_mode!=TextServer.AUTOWRAP_OFF:
		var required:=font.get_height(pixels)*label.get_line_count()
		check(required<=bound.y+0.01,"%s/%d %s wrapped text height %.1f <= %.1f (%d lines at%d)" % [game.locale,game.level_index+1,id,required,bound.y,label.get_line_count(),pixels])
		if id=="RuleHint": largest_hint_lines=maxi(largest_hint_lines,label.get_line_count())
		if id=="OverlayBody": largest_body_lines=maxi(largest_body_lines,label.get_line_count())
	else:
		for line in label.text.split("\n"):
			check(font.get_string_size(line,HORIZONTAL_ALIGNMENT_LEFT,-1,pixels).x<=bound.x-4,"%s/%d %s text fits width at%d: %s" % [game.locale,game.level_index+1,id,pixels,line])
	check(font.get_height(pixels)<=bound.y+0.01,"%s %s font line fits existing height" %[game.locale,id])
func fit_buttons() -> void:
	for id in game.buttons:
		var button: Button=game.buttons[id]
		if not is_instance_valid(button) or not button.is_visible_in_tree(): continue
		var font: Font=button.get_theme_font("font")
		var expected_width: float={"Instructions":230,"Pause":200,"Undo":420,"Restart":420,"ResultRestart":350,"ResultInstructions":350}.get(id,740)
		check(is_equal_approx(button.size.x,expected_width),"%s %s retains authored button width" %[game.locale,id])
		check(button.get_theme_font_size("font_size")==42,"v2 button %s is 42px" % id)
		check(font.get_string_size(button.text,HORIZONTAL_ALIGNMENT_LEFT,-1,42).x<=button.size.x-24,"%s %s button fits 42px text and 12px side padding" %[game.locale,id])
func run() -> void:
	var runtime_sha: String=FileAccess.get_sha256("res://data/water_sort/campaign_v2/levels.json")
	root.size=Vector2i(1080,1920)
	game=View.new();game.embedded_mode=true;root.add_child(game);game.set_process(false)
	check(game.levels.size()==50,"font metrics exercise the actual fifty-level runtime, not synthetic compatibility boards")
	var geometry: Array=[]
	for index in range(50):
		game.load_level(index)
		var positions: Array=[]
		for bottle in game.bottle_nodes: positions.append([bottle.position,bottle.size])
		geometry.append(positions)
	for language in ["zh","en"]:
		game.set_locale(language)
		for index in range(50):
			game.load_level(index);await process_frame
			for id in ["Title","Level","Stats","LevelName","Status","RuleHint"]: fit_label(id)
			check(game.labels.RuleHint.get_theme_font_size("font_size")>=36,"v2 hint never shrinks below 36px")
			check(game.labels.RuleHint.get_line_count()<=2,"%s level%d hint uses at most two existing lines" %[language,index+1])
			for bottle_index in game.bottle_nodes.size():
				var bottle=game.bottle_nodes[bottle_index]
				check([bottle.position,bottle.size]==geometry[index][bottle_index],"font refresh preserves exact bottle rectangles")
			fit_buttons()
		game.load_level(0)
		game.show_instructions();await process_frame
		fit_label("OverlayTitle");fit_label("OverlayBody",500);fit_buttons()
		game.resume_from_instructions();game.pause_game();await process_frame
		fit_label("OverlayTitle");fit_label("OverlayBody",210);fit_buttons()
		game.resume_game();game.request_restart();await process_frame
		fit_label("OverlayTitle");fit_label("OverlayBody",210);fit_buttons()
		for index in [0,19,20,39,40,49]:
			game.load_level(index);game.state="won";game._result_overlay(true);await process_frame
			fit_label("OverlayTitle");fit_label("OverlayBody",210);fit_buttons()
		game.load_level(0);game.state="stuck";game._result_overlay(false);await process_frame
		fit_label("OverlayTitle");fit_label("OverlayBody",210);fit_buttons()
	game.queue_free();await process_frame
	var old=OldView.new();old.embedded_mode=true;root.add_child(old);old.set_process(false);await process_frame
	check(old.labels.Title.get_theme_font_size("font_size")==52 and old.buttons.Undo.get_theme_font_size("font_size")==34,"original five-level typography is unchanged")
	old.queue_free();await process_frame
	check(FileAccess.get_sha256("res://data/water_sort/campaign_v2/levels.json")==runtime_sha,"actual fifty-level runtime remains fixed throughout font metric run")
	var result: Dictionary={"runtime_pack_sha256":runtime_sha,"passed":failures.is_empty(),"checks":checks,"failures":failures,"largest_hint_lines":largest_hint_lines,"largest_body_lines":largest_body_lines,"storage":"view-only; no progress or energy","visual_approval":false}
	FileAccess.open("res://tests/water_sort_campaign50/font_readability_results.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t")+"\n")
	print("WATER_SORT_CAMPAIGN50_FONT_READABILITY ",JSON.stringify(result));quit(0 if failures.is_empty() else 1)
