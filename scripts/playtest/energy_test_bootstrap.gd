extends Node
## Test composition only. Real wall-clock EnergyService and unchanged AppShell.
const Entry=preload("res://scenes/water_sort/orders_v3.tscn")
const Catalog=preload("res://scripts/water_sort/campaign_catalog.gd")
const TestProgress=preload("res://scripts/playtest/difficulty_progress.gd")
const ProgressStore=preload("res://scripts/playtest/isolated_profile_store.gd")
const Energy=preload("res://scripts/services/energy_service.gd")
const EnergyStore=preload("res://scripts/playtest/energy_test_store.gd")
var profile_directory:="res://.energy-test-profile-v1"
var enable_audio:=true
var app
var progress_store
var energy_store
var badge:Label
func _ready()->void:
	ProjectSettings.set_setting("development/mock_ads_enabled",true)
	var config:Dictionary=Catalog.configuration(Catalog.V3)
	var pack:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(config.level_path))
	progress_store=ProgressStore.new(profile_directory)
	energy_store=EnergyStore.new(profile_directory)
	var progress=TestProgress.new(progress_store.read,progress_store.write,config)
	progress.bind_level_pack(pack.levels);progress.load_progress()
	app=Entry.instantiate();app.progress=progress
	app.energy=Energy.new(Callable(),energy_store.read,energy_store.write)
	app.enable_audio=enable_audio
	add_child(app)
	# Entry-only static fallback: home _process exclusively animates Start.
	app.home.set_process(false)
	app.home.start_breath_phase=0.0
	if is_instance_valid(app.home.start_breath_group):app.home.start_breath_group.scale=Vector2.ONE
	badge=Label.new();badge.mouse_filter=Control.MOUSE_FILTER_IGNORE;badge.z_index=1000
	badge.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	badge.add_theme_font_override("font",preload("res://scripts/ui_restore/font_policy.gd").get_font("sc"))
	badge.add_theme_font_size_override("font_size",24);badge.add_theme_color_override("font_color",Color("17335b"))
	app.add_child(badge);badge.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE);badge.offset_top=3;badge.offset_bottom=48
	_update_caption()
	print("ENERGY_TEST_READY ",JSON.stringify({"real_energy":true,"real_clock":true,"cap":30,"cost":5,"recovery_seconds":120,"profile":energy_store.directory,"mock_ads":true,"sdk":false}))
func _process(_delta:float)->void:
	if is_instance_valid(app):_update_caption()
func _unhandled_key_input(event:InputEvent)->void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_F8:
		energy_store.fail_refill_save=not energy_store.fail_refill_save
		_update_caption();get_viewport().set_input_as_handled()
func _update_caption()->void:
	var zh:bool=app.progress.data.locale=="zh"
	get_window().title="彩瓶体力测试 · 独立存档 · 模拟广告" if zh else "Color Pause Energy Test · Separate Profile · Mock Ads"
	badge.text=("体力测试 · 真实120秒恢复 · 模拟广告" if zh else "ENERGY TEST · REAL 120s RECOVERY · MOCK ADS")
	if energy_store.fail_refill_save:badge.text+=(" · F8保存失败开启" if zh else " · F8 SAVE FAILURE ON")
