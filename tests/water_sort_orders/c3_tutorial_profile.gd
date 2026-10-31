extends "res://tests/water_sort_campaign50/memory_fixture.gd"
const Entry=preload("res://scenes/water_sort/orders_v3.tscn")
const TestProgress=preload("res://scripts/playtest/difficulty_progress.gd")
const TestEnergy=preload("res://scripts/playtest/difficulty_energy.gd")
const Store=preload("res://scripts/playtest/isolated_profile_store.gd")
var app
var g
var traces:Array=[]
func drain()->void:
 for tick in 4000:
  if not g._animation_busy() and g.presentation.input_queue.is_empty():return
  g._process(.01)
 check(false,"all motion/queued inputs drain")
func run()->void:
 var config:=Catalog.configuration(Catalog.V3)
 check(config.compatible_order_packs.is_empty() and not config.preserve_legacy_attempts,"C3 does not import prior board attempts")
 check(config.storage_file=="water_sort_progress_orders_c3_full50_20261030.json" and config.attempt_prefix=="water_sort_orders_c3_full50_20261030:","independent save and receipt namespace")
 var certificate:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/water_sort_orders/c3_full_certificate.json"))
 for dims in [Vector2i(320,480),Vector2i(390,844),Vector2i(430,932)]:
  root.size=dims
  for locale in ["zh","en"]:
   reset_memory();app=Entry.instantiate();app.enable_audio=false;app.progress=progress_fixture("c3guide",Catalog.V3);app.progress.data.locale=locale;app.energy=energy_fixture();root.add_child(app);await process_frame
   app.set_process(false);g=app.game;g.set_process(false);app._menu_start(0);g.set_process(false);await process_frame
   check(g.rules.level==certificate.levels[0].level and g.bottle_nodes.size()==5,"exact C3 five-bottle L1")
   check(g.tutorial_target()==1 and g.moves==0,"right source1 highlighted")
   check(not g.labels.Guide.text.contains("红") and not g.labels.Guide.text.contains("red"),"no stale red-color sample in actual green first move")
   await click_ui(g.bottle_nodes[2]);check(g.selected==-1 and g.moves==0,"wrong first source leaves guide active")
   await click_ui(g.bottle_nodes[1]);check(g.selected==1 and g.tutorial_target()==0,"real source click targets left0")
   check(not g.labels.Guide.text.contains("装满") and not g.labels.Guide.text.contains("fill"),"first destination copy does not promise full delivery")
   await click_ui(g.bottle_nodes[1]);check(g.selected==-1 and g.tutorial_target()==1,"real source cancel restores first phase")
   await click_ui(g.bottle_nodes[1]);await click_ui(g.bottle_nodes[4]);check(g.moves==0 and g.selected==1,"wrong empty target cannot bypass guide")
   await click_ui(g.bottle_nodes[0]);check(g.moves==1 and g.tutorial_target()==-1,"one successful real pour releases tutorial")
   drain();check(g.state=="playing" and not g.rules.is_solved() and g.rules.delivered.is_empty(),"first guided pour neither wins nor delivers")
   check(not app.progress.completed(0),"no fake first-step completion")
   for index in range(1,7):
    var action:Array=certificate.levels[0].solution[index]
    await click_ui(g.bottle_nodes[int(action[0])]);await click_ui(g.bottle_nodes[int(action[1])]);drain()
    check(g.moves==index+1 and g.tutorial_target()==-1,"six remaining actions autonomous, exact moves")
    if index<6:check(g.state=="playing" and not app.progress.completed(0),"cannot win before final genuine action")
   check(g.moves==7 and g.state=="won" and g.rules.is_solved() and app.progress.completed(0),"seven-pour genuine host win")
   traces.append({"size":str(dims),"locale":locale,"moves":g.moves,"delivered":g.rules.delivered.size(),"state":g.state})
   g.load_level(0);g.set_process(false);check(g.moves==0 and g.tutorial_target()==1,"replay rebinds only first guide")
   g.levels[1].erase("first_move_guide");g.load_level(1);check(g.tutorial_target()==-1,"L2 has no first-level input clamp")
   app.debug_ads.shutdown();app.free();await process_frame
 # Controlled file roundtrip: store paths are under this evidence directory.
 var test_dir:="res://c3_evidence/profile-"+str(Time.get_ticks_usec())
 var store:=Store.new(test_dir)
 var progress=TestProgress.new(store.read,store.write,config);progress.bind_level_pack(pack(Catalog.V3).levels);progress.load_progress()
 check(progress.data.completed.is_empty() and progress.data.records.is_empty(),"new C3 profile has no fake records")
 for index in 50:check(progress.unlocked(index),"test profile unlocks actual ID "+str(index+1))
 check(not progress.unlocked(-1) and not progress.unlocked(50),"only valid fifty IDs allowed")
 var formal=Progress.new(func():return {"ok":false,"reason":"missing"},func(_v):return true,config);formal.bind_level_pack(pack(Catalog.V3).levels);formal.load_progress()
 check(formal.unlocked(0) and not formal.unlocked(1) and formal.data.completed.is_empty(),"production default still normal unlocks")
 app=Entry.instantiate();app.enable_audio=false;app.progress=progress;app.energy=TestEnergy.new();root.add_child(app);await process_frame;app.set_process(false);g=app.game;g.set_process(false)
 var seen:Array=[]
 var Page=preload("res://scripts/ui_restore/level_select_view.gd")
 for page in ceili(50.0/Page.PAGE_SIZE):
  app.home.page_index=page;app.home.show_page("levels");await process_frame
  for index in range(page*Page.PAGE_SIZE,mini(50,(page+1)*Page.PAGE_SIZE)):
   var key="level_"+str(index)
   check(app.home.buttons.has(key),"real selector owns "+key)
   if app.home.buttons.has(key):check(not app.home.buttons[key].disabled,"real selector enabled "+key)
   seen.append(index+1)
 check(seen.size()==50 and seen[49]==50,"pagination reaches level50")
 for index in 50:
  app._menu_start(index);check(app.game.level_index==index and app.game.rules.level.id==index+1,"each selected ID starts exact C3 board")
  check(app.energy.snapshot().energy==30,"difficulty test no energy consumption")
  app.show_home()
 check(app.progress.data.completed.is_empty() and app.progress.data.records.is_empty(),"viewing fifty boards creates no completion records")
 var pending:Dictionary=app.progress.data.pending_attempt.duplicate(true);check(store.writes.size()>0,"actual isolated store wrote attempts")
 app.debug_ads.shutdown();app.free();await process_frame
 var restored=TestProgress.new(store.read,store.write,config);restored.bind_level_pack(pack(Catalog.V3).levels);restored.load_progress()
 var restoration_probe={"before":pending,"after":restored.data.pending_attempt,"restore_error":restored.load_error,"completed":restored.data.completed,"before_json":JSON.stringify(pending),"after_json":JSON.stringify(restored.data.pending_attempt)}
 FileAccess.open("res://c3_evidence/restore_probe.json",FileAccess.WRITE).store_string(JSON.stringify(restoration_probe,"\t"))
 # JSON numbers deserialize as floats. Keep the original strict-object failure
 # in tutorial.stdout.log/restore_probe; compare through the actual wire format.
 check(restored.data.pending_attempt==JSON.parse_string(JSON.stringify(pending)) and restored.data.completed.is_empty(),"C3 file cold restore retains all serialized fields and no forged completion")
 var RulesV3=preload("res://scripts/water_sort/order_rules.gd")
 check(RulesV3.matches(restored.bound_levels[49],restored.data.pending_attempt.snapshot),"restored complete rule state matches exact C3 board")
 app=Entry.instantiate();app.enable_audio=false;app.progress=restored;app.energy=TestEnergy.new();root.add_child(app);await process_frame;app.set_process(false);g=app.game;g.set_process(false);app._menu_start(49)
 check(g.level_index==49 and g.moves==0 and g.rules.snapshot().bottles==pending.snapshot.bottles,"actual cold host resumes L50 exact bottles and moves")
 var first:Array=certificate.levels[49].solution[0];g.select_bottle(int(first[0]));g.select_bottle(int(first[1]));drain();check(g.moves==1,"restored C3 attempt remains playable")
 app.debug_ads.shutdown();app.free();await process_frame
 for path in store.reads+store.writes:check(str(path).begins_with(ProjectSettings.globalize_path(test_dir)),"all save access confined to evidence fixture directory")
 var result={"checks":checks,"failures":failures,"traces":traces,"profile_paths":store.reads+store.writes,"native_pixels":"NOT_RUN"}
 FileAccess.open("res://c3_evidence/tutorial_profile.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"));print("C3_TUTORIAL_PROFILE ",JSON.stringify({"checks":checks,"failures":failures}));quit(0 if failures.is_empty() else 1)
