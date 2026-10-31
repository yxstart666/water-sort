extends "res://tests/water_sort_campaign50/memory_fixture.gd"
const ResultView=preload("res://scripts/water_sort/order_action_dialog.gd")
const RewardView=preload("res://scripts/water_sort/p1_reward_dialog.gd")
var callbacks:=0
var cancellations:=0
var texture_paths:Array[String]=[]
var texts:Array[String]=[]
func inspect(node:Node)->void:
	if node is TextureRect or node is NinePatchRect:
		check(node.texture!=null,"texture loaded: "+str(node.get_path()))
		if node.texture:
			texture_paths.append(node.texture.resource_path)
			check(node.texture.get_image().has_mipmaps(),"mipmap: "+node.texture.resource_path)
			check(node.texture_filter==CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS,"explicit mipmap filter")
	if node is Label:texts.append(node.text)
	for child in node.get_children():inspect(child)
func run()->void:
	reset_memory()
	var host=preload("res://scenes/water_sort/orders_v3.tscn").instantiate()
	host.enable_audio=false;host.progress=progress_fixture("victory-dependencies",Catalog.V3);host.energy=energy_fixture()
	root.add_child(host);await process_frame;await process_frame
	check(root.has_meta("screen_layout"),"real host screen layout installed")
	for spec in [["steps","9d34ad2c74bafb8aa61823b052f09ad95e28ac7fdf792ea6393d54c2abcc3e80",Vector2(130,74)],["time","2fda4df2db08ff95e30f60bfe1d5278eebe2f84634cd521dc7701f1b4ac26b1c",Vector2(126,74)],["next","9f74421dfa76c5373e516492db4f437aeebc803c60e527f6d6b544e40e945c2c",Vector2(306,120)]]:
		var path="res://assets/p2_ui/runtime/victory_window/label_"+spec[0]+"_zh-CN.png"
		check(FileAccess.get_sha256(path)==spec[1],"approved alpha bytes "+spec[0])
		check(load(path).get_size()==spec[2],"source dimensions unchanged")
	for dims in [Vector2i(320,480),Vector2i(390,844),Vector2i(430,932),Vector2i(370,697)]:
		root.size=dims
		for locale in ["zh","en"]:
			for primary in ["Next","ReplayAll"]:
				var dialog=ResultView.new();dialog.locale=locale;dialog.dialog_kind="won";dialog.result_level=50 if primary=="ReplayAll" else 2;dialog.result_moves=17;dialog.result_seconds=125;dialog.size=Vector2(dims)
				root.add_child(dialog)
				var button=dialog.add_action(primary,primary,func():callbacks+=1)
				dialog.add_action("ResultRestart","Restart",func():callbacks+=1)
				dialog.add_action("ResultInstructions","Home",func():callbacks+=1)
				await process_frame
				texture_paths.clear();texts.clear();inspect(dialog)
				check("17" in texts and "02:05" in texts,"real result values retained")
				check(dialog.celebration!=null and not button.disabled,"next available during celebration")
				if locale=="zh":
					for label in ["steps","time"]:
						check("res://assets/p2_ui/runtime/victory_window/label_"+label+"_zh-CN.png" in texture_paths,"actual corrected label bound")
					if primary=="Next":check("res://assets/p2_ui/runtime/victory_window/label_next_zh-CN.png" in texture_paths,"actual next label bound")
				var before=callbacks;button.pressed.emit();button.pressed.emit()
				check(callbacks==before+1,"result callback once")
				dialog.queue_free();await process_frame
				check(not is_instance_valid(dialog),"animation view disposed")
			for placement in ["bottle","shuffle","undo"]:
				for action in ["close","confirm"]:
					var reward=RewardView.new();reward.locale=locale;reward.placement=placement;reward.size=Vector2(dims)
					reward.confirmed.connect(func():callbacks+=1);reward.cancelled.connect(func():cancellations+=1);root.add_child(reward);await process_frame
					texture_paths.clear();texts.clear();inspect(reward)
					check(reward.hit_buttons.size()==2,"close and video inputs exist")
					var before=callbacks;var cancel_before=cancellations
					reward._dispatch(action);reward._dispatch(action)
					check(callbacks==before+(0 if action=="close" else 1) and cancellations==cancel_before+(1 if action=="close" else 0),"reward dispatch once without fake grant")
					reward.queue_free();await process_frame
	var before=callbacks;await create_timer(.7).timeout;check(callbacks==before,"no late celebration callbacks")
	host.queue_free();await process_frame
	print("VICTORY_REWARD "+JSON.stringify({"checks":checks,"failures":failures,"native_visual":"NOT_RUN"}));quit(0 if failures.is_empty() else 1)
