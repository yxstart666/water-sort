extends "res://tests/water_sort_campaign50/memory_fixture.gd"
const Entry=preload("res://scenes/water_sort/orders_v3.tscn")
var rows:Array=[]
func run()->void:
 print("DIAG_WINDOW ",root.size," ",root.content_scale_size," ",root.get_final_transform())
 var dims:=Vector2i(390,844)
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--width="):dims.x=int(arg.split("=")[1])
  if arg.begins_with("--height="):dims.y=int(arg.split("=")[1])
 root.size=dims
 await process_frame
 print("DIAG_WINDOW_SET ",root.size," ",root.get_final_transform())
 check(DisplayServer.get_name()=="headless","headless only")
 var cert:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/water_sort_orders/c3_full_certificate.json"))
 for index in 50:
  reset_memory();var app=Entry.instantiate();app.enable_audio=false;app.progress=progress_fixture("ac-replay",Catalog.V3);app.energy=energy_fixture()
  for i in index:app.progress.data.completed.append(i+1)
  app.progress.acknowledge_mechanic("covered_lock_v1");app.progress.acknowledge_mechanic("unknown_layers_v1")
  app.progress.acknowledge_mechanic("any_order_lock_v1") # Separate unseen/ack/save-failure test covers this modal.
  root.add_child(app);await process_frame;app.set_process(false);var g=app.game;g.set_process(false);app._menu_start(index);g.set_process(false)
  check(g.rules.level==cert.levels[index].level,"exact candidate level object "+str(index+1))
  var poured:=0
  for action in cert.levels[index].solution:
   g.select_bottle(int(action[0]));g.select_bottle(int(action[1]));poured+=1
   check(g.moves==poured,"real presentation accepts certificate move")
   for tick in 3000:
    if not g._animation_busy():break
    g._process(.01)
   check(not g._animation_busy(),"presentation/receipts complete")
  check(g.rules.is_solved() and g.state=="won","real host win "+str(index+1))
  check(g.moves==cert.levels[index].solution.size() and app.progress.completed(index),"durable memory settlement correct")
  rows.append({"id":index+1,"moves":g.moves,"state":g.state,"settled":app.progress.completed(index)})
  print("CAMPAIGN_REPLAY ",index+1," moves=",g.moves)
  app.debug_ads.shutdown();app.free();await process_frame
 var d={"checks":checks,"failures":failures,"rows":rows,"pack_sha256":FileAccess.get_sha256(Catalog.configuration(Catalog.V3).level_path)}
 FileAccess.open("res://c3_evidence/campaign_replay.json",FileAccess.WRITE).store_string(JSON.stringify(d," "));print("BATCH_AC_REPLAY ",JSON.stringify({"checks":checks,"failures":failures,"levels":rows.size()}));quit(0 if failures.is_empty() else 1)
