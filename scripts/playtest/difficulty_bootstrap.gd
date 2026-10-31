extends Node
## Separate launch composition. Production Progress/Energy/AppShell stay intact.
const Entry=preload("res://scenes/water_sort/orders_v3.tscn")
const Catalog=preload("res://scripts/water_sort/campaign_catalog.gd")
const TestProgress=preload("res://scripts/playtest/difficulty_progress.gd")
const TestEnergy=preload("res://scripts/playtest/difficulty_energy.gd")
const ProfileStore=preload("res://scripts/playtest/isolated_profile_store.gd")
const DEFAULT_PROFILE="res://.c3-difficulty-profile-v1"
var profile_directory:=DEFAULT_PROFILE
var enable_audio:=true
var app
var store
var badge:Label
var last_locale:=""
func _ready()->void:
	assert(ProjectSettings.get_setting("development/difficulty_playtest",false)==true)
	var config:Dictionary=Catalog.configuration(Catalog.V3)
	var pack:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(config.level_path))
	assert(pack.levels.size()==50)
	store=ProfileStore.new(profile_directory)
	var progress=TestProgress.new(store.read,store.write,config)
	progress.bind_level_pack(pack.levels);progress.load_progress()
	app=Entry.instantiate();app.progress=progress;app.energy=TestEnergy.new();app.enable_audio=enable_audio
	add_child(app)
	badge=Label.new();badge.mouse_filter=Control.MOUSE_FILTER_IGNORE;badge.z_index=1000
	badge.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;badge.add_theme_font_override("font",preload("res://scripts/ui_restore/font_policy.gd").get_font("sc"));badge.add_theme_font_size_override("font_size",28)
	badge.add_theme_color_override("font_color",Color("17335b"));app.add_child(badge)
	badge.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE);badge.offset_top=3;badge.offset_bottom=50
	_update_caption()
	print("COLORPAUSE_DIFFICULTY_READY ",JSON.stringify({"build_id":"C3_UI_PLAYTEST_20261031","levels":50,"all_selectable":true,"energy_exempt":true,"profile_directory":store.directory,"completed":progress.data.completed.size(),"level_pack_sha256":FileAccess.get_sha256(config.level_path),"test_ads":app.debug_ads.enabled(),"real_sdk":false}))
func _process(_delta:float)->void:
	if not is_instance_valid(app):return
	var expected:="彩瓶时光 · C3 难度测试版 · 全50关开放" if app.progress.data.locale=="zh" else "Color Pause · C3 Difficulty Test · All 50 Levels"
	if app.progress.data.locale!=last_locale or get_window().title!=expected:_update_caption()
func _update_caption()->void:
	last_locale=app.progress.data.locale
	badge.text="C3 难度测试版 · 全50关开放 · 免体力" if last_locale=="zh" else "C3 DIFFICULTY TEST · ALL 50 LEVELS · NO ENERGY COST"
	get_window().title="彩瓶时光 · C3 难度测试版 · 全50关开放" if last_locale=="zh" else "Color Pause · C3 Difficulty Test · All 50 Levels"
