extends SceneTree
func _initialize()->void:call_deferred("run")
func run()->void:
	var boot=preload("res://scripts/playtest/energy_test_bootstrap.gd").new()
	boot.profile_directory="res://../qa-private/hotkey-"+str(Time.get_ticks_usec());boot.enable_audio=false
	root.add_child(boot);await process_frame
	var e:=InputEventKey.new();e.keycode=KEY_F8;e.pressed=true
	Input.parse_input_event(e);await process_frame
	var first:bool=boot.energy_store.fail_refill_save
	e=InputEventKey.new();e.keycode=KEY_F8;e.pressed=false;Input.parse_input_event(e);await process_frame
	e=InputEventKey.new();e.keycode=KEY_F8;e.pressed=true;Input.parse_input_event(e);await process_frame
	var second:bool=not boot.energy_store.fail_refill_save
	print("ENERGY_HOTKEY_QA ",JSON.stringify({"F8_enabled":first,"F8_disabled":second,"path":"Input.parse_input_event headless"}))
	boot.queue_free();await process_frame;quit(0 if first and second else 1)
