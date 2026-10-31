extends Control
## Native water-sort app. Persistence is isolated from the cargo game.
const WaterProgress = preload("res://scripts/water_sort/progress.gd")
const CampaignCatalog = preload("res://scripts/water_sort/campaign_catalog.gd")
const CampaignView = preload("res://scripts/water_sort/campaign_view.gd")
const OrderView = preload("res://scripts/water_sort/order_view.gd")
@export_enum("water_sort_v1","water_sort_campaign_v2","water_sort_orders_v3") var campaign_id := "water_sort_v1"
const HomeMenu = preload("res://scripts/water_sort/home_menu.gd")
const GameView = preload("res://scripts/experiments/water_sort_v1/view.gd")
const EnergyService = preload("res://scripts/services/energy_service.gd")
const LocalStore = preload("res://scripts/services/local_store.gd")
const AudioService = preload("res://scripts/services/game_audio.gd")
const HapticsService = preload("res://scripts/services/game_haptics.gd")
const AdProviders=preload("res://scripts/services/ad_provider_factory.gd")
const NativeAdStatus=preload("res://scripts/water_sort/native_ad_status_dialog.gd")
var ad_controller_factory:Callable
var _native_status_placement:=""
var _ad_capability_dirty:=false
const DevelopmentRewards = preload("res://scripts/water_sort/debug_ad_controller.gd")
const TestAdDialog = preload("res://scripts/water_sort/debug_ad_dialog.gd")
const ENERGY_FILE := "water_sort_energy_v1.json"
const LEVEL_PATH := "res://data/experiments/water_sort_v1/levels.json"
const CHECKPOINT_ERROR_ZH := "本次进度未保存，请勿关闭程序。\n当前棋盘仅在本次运行中保留。\n请继续当前局后，再次返回重试。"
const CHECKPOINT_ERROR_EN := "Progress was not saved. Keep the app open.\nYour puzzle is only kept in this session.\nContinue, then return here to retry saving."
var progress
var energy
var home
var game
var audio
var haptics = HapticsService.new()
var enable_audio := true
var attempt_id := ""
var attempt_index := -1
var loaded_attempt := false
var pending_result: Dictionary = {}
var energy_elapsed := 0.0
var last_energy: Dictionary = {}
var click_serial := 0
var initialized := false
var game_energy_badge: Control
var game_energy_label: Label
var energy_popup
var energy_return_state := ""
var checkpoint_failed_attempt := ""
var checkpoint_notice_queued := false
var debug_ads
var ad_dialog
var _ad_open := false
var _ad_return_state := ""
var _shutting_down := false
var screen_layout

func _ready() -> void:
	screen_layout=preload("res://scripts/ui_restore/screen_layout.gd").new();add_child(screen_layout)
	var local_theme:=Theme.new();local_theme.default_font=preload("res://scripts/ui_restore/font_policy.gd").get_font("sc");theme=local_theme
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if OS.is_debug_build() and OS.get_cmdline_user_args().has("--dev-test-ads"):
		ProjectSettings.set_setting(DevelopmentRewards.SETTING,true)
	var configuration := CampaignCatalog.configuration(campaign_id)
	var pack: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(configuration.level_path))
	if progress == null:
		progress = WaterProgress.new(Callable(),Callable(),configuration)
		progress.bind_level_pack(pack.levels)
		progress.load_progress()
	else: progress.bind_level_pack(pack.levels)
	if energy == null:
		energy = EnergyService.new(Callable(),func(): return LocalStore.read(ENERGY_FILE),func(value): return LocalStore.write(ENERGY_FILE,value))
	# Saved wins recover interrupted rewards; energy receipts are idempotent.
	for settled in progress.data.settlements: energy.complete_attempt(str(settled))
	if not progress.data.pending_attempt.is_empty():
		attempt_id = str(progress.data.pending_attempt.id)
		attempt_index = int(progress.data.pending_attempt.index)
	if enable_audio:
		audio = AudioService.new()
		audio.name = "WaterSortAudio"
		add_child(audio)
	game = OrderView.new() if bool(configuration.get("order_mode",false)) else (CampaignView.new() if bool(configuration.celebration) else GameView.new())
	game.name = "WaterSortGame"
	game.embedded_mode = true
	game.set_locale(str(progress.data.locale))
	game.level_start_requested.connect(_start_level)
	game.level_completed.connect(_level_completed)
	game.exit_requested.connect(show_home)
	if game is OrderView:
		game.mechanism_seen=progress.has_seen_mechanic
		game.mechanism_acknowledge=progress.acknowledge_mechanic
		game.preference_changed.connect(_pause_preference_changed)
		game.tactile_requested.connect(func(): haptics.tap())
		game.level_select_requested.connect(_show_level_select)
		game.reward_requested.connect(request_development_ad)
		game.reward_cancel_requested.connect(_cancel_test_ad)
		game.reward_context_changed.connect(_invalidate_ad_context)
	screen_layout.mount_game(game)
	game.hide()
	game.process_mode = Node.PROCESS_MODE_DISABLED
	home = HomeMenu.new()
	home.name = "WaterSortHome"
	home.progress = progress
	home.start_level.connect(_menu_start)
	home.preferences_changed.connect(_preferences_changed)
	home.ui_clicked.connect(_ui_click)
	home.tutorial_requested.connect(_show_rules)
	home.energy_ad_requested.connect(func(): request_development_ad("energy"))
	home.page_changed.connect(_invalidate_ad_context)
	add_child(home)
	debug_ads=ad_controller_factory.call(self) if ad_controller_factory.is_valid() else AdProviders.create_controller(self)
	if game is OrderView:
		game.reward_capability = func(): return debug_ads != null and debug_ads.is_enabled() and (not debug_ads.is_native() or debug_ads.adapter.ready())
	debug_ads.request_started.connect(func(_request): _show_test_ad())
	debug_ads.finished.connect(_test_ad_finished)
	debug_ads.save_failed.connect(func(_reason): _show_test_ad(true))
	debug_ads.status_changed.connect(_native_ad_status_changed)
	home.privacy_action=func():debug_ads.show_privacy_options()
	debug_ads.initialize_provider()
	home.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_preferences_changed(progress.data)
	initialized = true
	show_home()
	if debug_ads.is_native():debug_ads.resume_saved_reward.call_deferred()
	if not progress.load_error.is_empty(): _error("本机进度无法读取，原文件已保留。请先修复存档再开始。","The local save could not be read. The original file was preserved.")
	print("WATER_SORT_APP_READY levels=",pack.levels.size()," local_progress=true energy=30/-5/+5/120s")
	var source_hashes:Dictionary={}
	for path in ["scripts/water_sort/order_presentation.gd","scripts/water_sort/art/pour_animator.gd","scripts/water_sort/art/board_pour_path.gd","scripts/water_sort/order_rules.gd","scripts/water_sort/reference2_ui.gd","scripts/water_sort/order_gameplay_layout.gd","scripts/water_sort/progress.gd","scripts/water_sort/pause_button_face.gd","scripts/water_sort/art/reference3_volume.gd","scripts/water_sort/art/delivered_bottle_layers.gd"]:
		source_hashes[path]=FileAccess.get_sha256("res://"+path)
	print("WATER_SORT_RUNTIME_ID ",JSON.stringify({"engine":Engine.get_version_info().string,"executable":OS.get_executable_path(),"project":ProjectSettings.globalize_path("res://"),"scene":get_tree().current_scene.scene_file_path if is_instance_valid(get_tree().current_scene) else scene_file_path,"content_version":pack.get("content_version",""),"level_pack_sha256":FileAccess.get_sha256(configuration.level_path),"source_sha256":source_hashes}))

func _preferences_changed(values: Dictionary) -> void:
	haptics.enabled = bool(values.get("vibration",true))
	get_window().title="Color Pause" if str(values.get("locale","zh"))=="en" else "彩瓶时光"
	if game.locale != str(values.get("locale","zh")): game.set_locale(str(values.get("locale","zh")))
	if game is OrderView: game.set_pause_preferences(values)
	if initialized: _ensure_game_energy()
	if audio != null: audio.set_preferences(bool(values.get("music",true)),bool(values.get("sound",true)))

func _pause_preference_changed(key: String, value: Variant) -> void:
	progress.set_preference(key,value)
	_preferences_changed(progress.data)
	if progress.data.get(key)!=value:
		_error("设置未能保存，请稍后重试。当前关卡已保留。","Unable to save settings. Your current puzzle is preserved.")

func _show_level_select() -> void:
	show_home()
	home._open_levels()

func _ui_click() -> void:
	haptics.tap()
	click_serial += 1
	if audio != null: audio.play_event("click","menu:%d" % click_serial)

func _show_rules() -> void:
	if campaign_id==CampaignCatalog.V3:
		home.show_error("选源瓶 → 同色或空瓶 → 装满后匹配订单" if progress.data.locale=="zh" else "Choose a source → Match or use an empty bottle → Fill and deliver orders","玩法说明" if progress.data.locale=="zh" else "How to play")
		return
	home.show_error("先点源瓶，再点空瓶或顶部同色且未满的瓶子。\n顶端连续同色会一起倒入，直到目标瓶装满。\n每种颜色装满一瓶即可过关。\n暂停和返回主页不计时；未完成局重开不额外扣体力。" if progress.data.locale=="zh" else "Tap a source bottle, then an empty bottle or one with the same top color.\nThe matching top layers pour until the destination is full.\nFill one bottle with each color to win.\nPause and Home stop the timer. Restarting an unfinished attempt costs no extra energy.","玩法说明" if progress.data.locale=="zh" else "How to play")

func _error(zh: String, en: String) -> void:
	if not home.visible: show_home()
	home.show_error(zh if progress.data.locale=="zh" else en)

func _menu_start(index: int) -> void:
	if debug_ads!=null and debug_ads.holds_board_reward():_show_test_ad(true);return
	if not pending_result.is_empty() and not _settle_pending(): return
	if index==attempt_index and not attempt_id.is_empty() and not progress.data.settlements.has(attempt_id):
		if game is OrderView and not progress.update_pending_content():
			_error("无法保存新版进度，原局已保留。请重试。","Unable to save the updated puzzle. Your original progress is preserved. Please retry.")
			return
		if game is OrderView and not progress.last_content_update.is_empty():loaded_attempt=false
		if not _enter_energy(attempt_id): return
		if not loaded_attempt:
			_bind_completion_key()
			if game is OrderView: game.levels[index]=progress.attempt_level(index)
			game.load_level(index)
			loaded_attempt = true
			_restore_checkpoint()
		_show_game()
		if game is OrderView: game.resume_from_menu()
		elif game.state=="paused": game.resume_game()
		if debug_ads!=null:debug_ads.resume_saved_reward()
		return
	_start_level(index)

func _start_level(index: int) -> void:
	if debug_ads!=null and debug_ads.holds_board_reward():_show_test_ad(true);return
	if progress.data.pending_attempt.has("board_action_reward"):_menu_start(attempt_index);return
	if index < 0 or index >= progress.level_count or not progress.unlocked(index): return
	_invalidate_ad_context()
	if not pending_result.is_empty() and not _settle_pending(): return
	var same_unfinished: bool = index==attempt_index and not attempt_id.is_empty() and not progress.data.settlements.has(attempt_id)
	if not same_unfinished:
		# Refusal must not throw away an existing paid puzzle or checkpoint.
		var available: Dictionary = energy.snapshot()
		if not available.get("ok",false):
			_error("体力记录暂时不可用，当前关卡已保留。","Energy is unavailable. Your current puzzle is preserved.")
			return
		if int(available.get("energy",0)) < EnergyService.COST:
			show_home()
			home.energy_open = true
			home._refresh()
			return
		var previous_pending: Dictionary = progress.data.pending_attempt.duplicate(true)
		var fresh: String = progress.reserve_attempt(index)
		if fresh.is_empty():
			_error("无法保存新的一局，未扣除体力。","Unable to save a new attempt. No energy was charged.")
			return
		var entry: Dictionary = energy.enter_attempt(fresh)
		if not entry.get("accepted",false):
			# Keep the serial monotonic, but restore the old paid attempt.
			progress.data.pending_attempt = previous_pending
			progress.save_progress()
			_error("无法保存体力变化，当前关卡已保留。","Unable to save the energy change. Your current puzzle is preserved.")
			return
		attempt_id = fresh
		attempt_index = index
		loaded_attempt = false
	elif not _enter_energy(attempt_id): return
	if game is OrderView:
		if not progress.restart_attempt_content():
			_error("无法保存重开状态，当前关卡已保留。","Unable to save restart. Your current puzzle is preserved.")
			return
		game.levels=progress.bound_levels.duplicate(true)
	_bind_completion_key()
	game.load_level(index)
	loaded_attempt = true
	if game is OrderView:_restore_checkpoint()
	_checkpoint()
	if audio != null: audio.reset_epoch()
	_show_game()

func _bind_completion_key() -> void:
	if game is CampaignView: game.completion_key = attempt_id

func _enter_energy(id: String) -> bool:
	var result: Dictionary = energy.enter_attempt(id)
	if result.get("accepted",false): return true
	show_home()
	if result.get("reason")=="insufficient_energy":
		home.energy_open = true
		home._refresh()
	else: _error("体力记录暂时不可用，未开始新的一局。","The energy record is unavailable. The new attempt has not started.")
	return false

func _show_game() -> void:
	home.hide()
	home.process_mode = Node.PROCESS_MODE_DISABLED
	game.process_mode = Node.PROCESS_MODE_INHERIT
	game.show()
	if game.locale != str(progress.data.locale): game.set_locale(str(progress.data.locale))
	_ensure_game_energy()
	if audio != null: audio.set_gameplay_paused(false)
	if debug_ads!=null and debug_ads.is_native() and debug_ads.can_settle_pending():_surface_native_pending.call_deferred()

func show_home(save_current := true) -> void:
	if not initialized: return
	if debug_ads!=null and debug_ads.holds_board_reward():_show_test_ad(true);return
	_invalidate_ad_context()
	if loaded_attempt: game.prepare_to_leave()
	if save_current: _checkpoint()
	game.hide()
	game.process_mode = Node.PROCESS_MODE_DISABLED
	home.process_mode = Node.PROCESS_MODE_INHERIT
	home.show()
	home.resume_index = attempt_index if not attempt_id.is_empty() and not progress.data.settlements.has(attempt_id) else -1
	home.show_page("home")
	_refresh_energy()
	if audio != null: audio.set_gameplay_paused(true)
	if debug_ads!=null and debug_ads.is_native() and debug_ads.can_settle_pending():_surface_native_pending.call_deferred()

func _checkpoint() -> bool:
	var saved := true
	if loaded_attempt and not attempt_id.is_empty() and not progress.data.settlements.has(attempt_id) and game.rules!=null:
		saved=progress.save_checkpoint(attempt_id,game.rules.snapshot(),int(game.moves),float(game.elapsed))
	checkpoint_failed_attempt="" if saved else attempt_id
	var old_notice: bool=is_instance_valid(home) and home.notice_message in [CHECKPOINT_ERROR_ZH,CHECKPOINT_ERROR_EN]
	if (not saved or old_notice) and not checkpoint_notice_queued:
		# Lifecycle notifications may run during tree traversal. Merge them and
		# present afterward; _error would navigate and checkpoint recursively.
		checkpoint_notice_queued=true
		_present_checkpoint_failure.call_deferred()
	return saved

func _present_checkpoint_failure() -> void:
	checkpoint_notice_queued=false
	if not initialized: return
	if checkpoint_failed_attempt.is_empty() or checkpoint_failed_attempt!=attempt_id or progress.data.settlements.has(attempt_id):
		if home.notice_message in [CHECKPOINT_ERROR_ZH,CHECKPOINT_ERROR_EN]:
			home.notice_message=""; home.notice_title=""; home._refresh()
		return
	# Let an already opened modal finish its own dismissal. Replacing it here
	# would hide its controls and strand its energy/settings open flag.
	# An earned-but-unsaved reward owns its current context until retry or an
	# explicit navigation. A lifecycle error must not navigate and invalidate it.
	# Keep the failed-checkpoint marker; the generic notice resumes if no reward
	# remains, or clears only after a confirmed durable board-reward commit.
	var reward_pending:bool=debug_ads!=null and not debug_ads.pending_operation().is_empty()
	if _ad_open or reward_pending or is_instance_valid(energy_popup) or (home.visible and (home.energy_open or home.settings_open)):
		checkpoint_notice_queued=true
		get_tree().process_frame.connect(_present_checkpoint_failure,CONNECT_ONE_SHOT)
		return
	if not home.visible:
		show_home(false) # The failed write was already attempted. Do not retry here.
	if checkpoint_failed_attempt.is_empty() or progress.data.settlements.has(attempt_id): return
	# Keep a more specific caller error, e.g. an unsaved victory settlement.
	if not home.notice_message.is_empty() and home.notice_message not in [CHECKPOINT_ERROR_ZH,CHECKPOINT_ERROR_EN]: return
	var message: String=CHECKPOINT_ERROR_ZH if progress.data.locale=="zh" else CHECKPOINT_ERROR_EN
	if home.notice_message!=message: home.show_error(message)

func _restore_checkpoint() -> void:
	var pending: Dictionary = progress.data.pending_attempt
	if not pending.has("snapshot"): return
	if progress.checkpoint_matches_level(attempt_index,pending.snapshot) and game.rules.restore(pending.snapshot):
		game.moves = int(pending.moves)
		game.elapsed = float(pending.seconds)
		if game.has_method("restore_presentation"): game.restore_presentation()
		game._refresh()
		if game is OrderView and not progress.last_content_update.is_empty() and game.state=="playing":
			var board_changed:bool=progress.last_content_update=="board"
			game._feedback(("本局已更新为新版盘面，体力和辅助已保留。" if board_changed else "问号已统一从瓶底排列，进度和辅助已保留。") if game.locale=="zh" else ("Puzzle updated. This attempt's energy and assistance are preserved." if board_changed else "Hidden layers now start at the bottom. Progress and assistance are preserved."))
			game.message_remaining=5.0
			progress.last_content_update=""
		if game.rules.is_solved():
			game.state = "won"
			_level_completed(attempt_index,int(game.moves),float(game.elapsed))
			if game.has_method("present_completed_checkpoint"): game.present_completed_checkpoint()
			else: game._result_overlay(true)

func _level_completed(index: int, moves: int, seconds: float) -> void:
	if index!=attempt_index or attempt_id.is_empty() or game.rules==null or not game.rules.is_solved(): return
	if progress.data.settlements.has(attempt_id): return
	pending_result = {"index":index,"moves":moves,"seconds":seconds,"attempt_id":attempt_id}
	_settle_pending()

func _settle_pending() -> bool:
	if pending_result.is_empty(): return true
	var result: Dictionary = pending_result
	if not progress.record_result(int(result.index),int(result.moves),float(result.seconds),str(result.attempt_id)):
		_error("通关成绩尚未保存，请稍后重试。当前关卡会保留。","The result has not been saved yet. Your current attempt is preserved; please retry.")
		return false
	var reward: Dictionary = energy.complete_attempt(str(result.attempt_id))
	if not reward.get("accepted",false): _error("通关已保存，体力奖励暂未写入。下次启动会自动重试，奖励不会重复。","Your result is saved. The energy reward will retry on the next launch without duplication.")
	pending_result = {}
	home.resume_index = -1
	if audio != null:
		audio.set_gameplay_paused(false)
		audio.play_event("victory","win:"+str(result.attempt_id))
	_refresh_energy()
	return true

func _refresh_energy() -> void:
	var snapshot: Dictionary = energy.snapshot()
	snapshot.ad_available=debug_ads!=null and debug_ads.can_begin("energy")
	snapshot.ad_retry_available=debug_ads!=null and debug_ads.can_settle_pending() and debug_ads.pending_operation().get("placement")=="energy"
	if snapshot != last_energy:
		last_energy = snapshot.duplicate(true)
		home.update_energy(snapshot)
		if is_instance_valid(energy_popup): energy_popup.update_energy(snapshot)
	if is_instance_valid(game_energy_label):
		game_energy_label.text = ("%d/%d" % [int(snapshot.energy),int(snapshot.get("cap",30))]) if snapshot.get("energy") is int or snapshot.get("energy") is float else "--/%d" % int(snapshot.get("cap",30))

func _process(delta: float) -> void:
	if not initialized: return
	if debug_ads!=null: debug_ads.poll()
	if _ad_capability_dirty and not game._animation_busy():
		_ad_capability_dirty=false
		if game is OrderView:game._refresh()
		_refresh_energy()
	energy_elapsed += delta
	if energy_elapsed >= 1.0:
		energy_elapsed = 0.0
		_refresh_energy()
	if audio != null and game.visible: audio.set_gameplay_paused(game.state!="playing")

func _notification(what: int) -> void:
	if initialized and debug_ads!=null:
		if what in [NOTIFICATION_APPLICATION_FOCUS_OUT,NOTIFICATION_APPLICATION_PAUSED]:debug_ads.set_backgrounded(true)
		elif what in [NOTIFICATION_APPLICATION_FOCUS_IN,NOTIFICATION_APPLICATION_RESUMED]:debug_ads.set_backgrounded(false)
	if initialized and what in [NOTIFICATION_APPLICATION_FOCUS_OUT,NOTIFICATION_APPLICATION_PAUSED,NOTIFICATION_WM_CLOSE_REQUEST]: _checkpoint()

func _ensure_game_energy() -> void:
	if is_instance_valid(game_energy_badge) and game_energy_badge.get_parent()==game: return
	game_energy_badge = Control.new()
	game_energy_badge.name = "WaterSortEnergyCanvas1080x1920"
	game_energy_badge.size = Vector2(1080,1920)
	game_energy_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	game.add_child(game_energy_badge)
	if is_instance_valid(game.overlay): game.move_child(game_energy_badge,game.overlay.get_index())
	# Main gameplay owns its940-art skin; the energy service/callback stays here.
	if game is OrderView:
		game_energy_label=game.build_gameplay_energy_badge(game_energy_badge)
	else:
		# Keep the badge below later game overlays, never above pause/result dialogs.
		for source in home.compositions["home_localized_zh"].layers:
			if source.get("id","")=="unified_energy_hud":
				var layer: Dictionary = source.duplicate(true)
				layer.z = 0
				home._sprite(game_energy_badge,layer)
		game_energy_label = Label.new()
		game_energy_label.name = "EnergyAmount"
		game_energy_label.position = Vector2(93,43)
		game_energy_label.size = Vector2(120,60)
		game_energy_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		game_energy_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		game_energy_label.add_theme_font_override("font",HomeMenu.Typography.font("latin"))
		game_energy_label.add_theme_font_size_override("font_size",35)
		game_energy_label.add_theme_color_override("font_color",Color("123a59"))
		game_energy_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		game_energy_badge.add_child(game_energy_label)
	var button := Button.new()
	button.name = "OpenEnergy"
	button.position = Vector2(24,14)
	button.size = Vector2(262,116)
	if game is OrderView:
		var hit: Rect2=game.gameplay_energy_hit_rect()
		button.position=hit.position; button.size=hit.size
	button.flat = true
	preload("res://scripts/ui_restore/touch_hit.gd").attach(button)
	for state in ["normal","hover","pressed","disabled","focus"]: button.add_theme_stylebox_override(state,StyleBoxEmpty.new())
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.pressed.connect(_show_game_energy)
	game_energy_badge.add_child(button)
	_refresh_energy()

func _show_game_energy() -> void:
	if is_instance_valid(energy_popup): return
	_invalidate_ad_context()
	energy_return_state = str(game.state)
	if game.state=="playing": game.pause_game()
	_checkpoint()
	game.process_mode = Node.PROCESS_MODE_DISABLED
	energy_popup = HomeMenu.new()
	energy_popup.name = "WaterSortEnergyPopup"
	energy_popup.progress = progress
	energy_popup.energy_only = true
	energy_popup.energy_closed.connect(_close_game_energy)
	energy_popup.energy_ad_requested.connect(func(): request_development_ad("energy"))
	add_child(energy_popup)
	energy_popup.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var snapshot: Dictionary=energy.snapshot()
	snapshot.ad_available=debug_ads!=null and debug_ads.can_begin("energy")
	snapshot.ad_retry_available=debug_ads!=null and debug_ads.can_settle_pending() and debug_ads.pending_operation().get("placement")=="energy"
	energy_popup.update_energy(snapshot)

func _close_game_energy() -> void:
	if not is_instance_valid(energy_popup): return
	_invalidate_ad_context()
	remove_child(energy_popup)
	energy_popup.queue_free()
	energy_popup = null
	game.process_mode = Node.PROCESS_MODE_INHERIT
	if energy_return_state=="playing": game.resume_game()
	energy_return_state = ""

var p1_confirmation: Control
var p1_return_state := ""

func request_development_ad(placement: String) -> Dictionary:
	if placement not in ["shuffle", "undo", "bottle"]:
		return _begin_development_ad(placement)
	if is_instance_valid(p1_confirmation) or _ad_open:
		return {"ok":false,"reason":"busy"}
	if not game.visible or game.state not in ["playing", "stuck"]:
		return {"ok":false,"reason":"game_busy"}
	if debug_ads!=null and debug_ads.pending_operation().get("placement","")==placement and debug_ads.can_settle_pending():
		return _begin_development_ad(placement)
	p1_return_state = str(game.state)
	game.state = "reward"; game._refresh()
	var dialog = preload("res://scripts/water_sort/p1_reward_dialog.gd").new()
	dialog.placement = placement; dialog.locale = str(progress.data.locale); dialog.z_index = 300
	p1_confirmation = dialog
	add_child(dialog); dialog.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dialog.cancelled.connect(func(): _close_p1_confirmation())
	dialog.confirmed.connect(func():
		_close_p1_confirmation()
		_begin_development_ad(placement))
	return {"ok":true,"confirmation":true}

func _close_p1_confirmation() -> void:
	if is_instance_valid(p1_confirmation):
		remove_child(p1_confirmation); p1_confirmation.queue_free()
	p1_confirmation = null
	if not p1_return_state.is_empty() and is_instance_valid(game) and game.state == "reward":
		game.state = p1_return_state; game._refresh()
		if game is OrderView: game.restore_after_reward()
	p1_return_state = ""

func _begin_development_ad(placement: String) -> Dictionary:
	if debug_ads==null: return {"ok":false,"reason":"reward_unavailable"}
	var pending: Dictionary=debug_ads.pending_operation()
	if not pending.is_empty() and pending.placement==placement and debug_ads.can_settle_pending():
		_show_test_ad(true); return {"ok":true,"retry_pending":true}
	var result: Dictionary=debug_ads.begin(placement)
	if debug_ads.is_native() and not result.get("ok",false):
		_show_native_ad_status(placement);return result
	if not result.get("ok",false) and result.get("reason")=="reward_unavailable" and not _ad_open:
		_show_test_ad(false,true)
	elif not result.get("ok",false) and not _ad_open and game is OrderView:
		game.restore_after_reward()
	return result

func _show_test_ad(retry_mode := false, unavailable := false) -> void:
	if _shutting_down: return
	if retry_mode and (debug_ads==null or debug_ads.pending_operation().is_empty()):return
	if debug_ads!=null and debug_ads.is_native() and not retry_mode:
		_show_native_ad_status(str(debug_ads.active_request().get("placement",_native_status_placement)));return
	if not _ad_open:
		_ad_open=true; _ad_return_state=str(game.state) if game.visible else ""
		if game.visible: game.state="reward"; game._refresh()
	if is_instance_valid(ad_dialog): remove_child(ad_dialog); ad_dialog.queue_free()
	var dialog:=TestAdDialog.new()
	dialog.locale=str(progress.data.locale); dialog.retry_mode=retry_mode; dialog.unavailable=unavailable
	dialog.placement=str((debug_ads.pending_operation() if retry_mode else debug_ads.active_request()).get("placement",""))
	dialog.preparing=bool(debug_ads.active_request().get("preparing",false))
	dialog.size=size; dialog.z_index=300
	var identity: Dictionary=debug_ads.pending_operation() if retry_mode else debug_ads.active_request()
	# Capture a stable value: a freed Node capture errors before any guard runs.
	var dialog_id: int=dialog.get_instance_id()
	dialog.completed.connect(func():
		if is_instance_valid(ad_dialog) and ad_dialog.get_instance_id()==dialog_id and debug_ads.matches_identity(identity): debug_ads.complete())
	dialog.retry_requested.connect(func():
		if is_instance_valid(ad_dialog) and ad_dialog.get_instance_id()==dialog_id and debug_ads.matches_identity(identity,true): debug_ads.retry_pending())
	dialog.cancelled.connect(func():
		if is_instance_valid(ad_dialog) and ad_dialog.get_instance_id()==dialog_id: _cancel_test_ad())
	ad_dialog=dialog; add_child(dialog)
	dialog.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_refresh_energy()

func _cancel_test_ad() -> void:
	if debug_ads!=null and (not debug_ads.active_request().is_empty() or not debug_ads.pending_operation().is_empty()): debug_ads.cancel()
	else: _close_test_ad()

func _close_test_ad(reevaluate_board:=true) -> void:
	if is_instance_valid(ad_dialog): remove_child(ad_dialog); ad_dialog.queue_free()
	ad_dialog=null
	if _ad_open and not _ad_return_state.is_empty(): game.state=_ad_return_state; game._refresh()
	_ad_open=false; _ad_return_state=""
	if reevaluate_board and game is OrderView: game.restore_after_reward()

func _test_ad_finished(outcome: String, _reason: String, placement: String) -> void:
	if _shutting_down: return
	# A late invalidation after a closed dialog cannot reset a newer UI state.
	if not _ad_open: return
	_close_test_ad(false)
	if debug_ads!=null and debug_ads.is_native() and outcome in ["failed","expired"] and (_reason.is_valid_int() or _reason in ["callback_timeout","native_not_ready","native_plugin_unavailable","not_ready","no_activity","receipt_rejected"]):
		_show_native_ad_status(placement);return
	if outcome=="completed" and placement in ["bottle","slot","shuffle","undo"]:
		# Controller emits completed only AFTER the board checkpoint/receipt write
		# succeeds. That durable write supersedes the earlier lifecycle failure.
		checkpoint_failed_attempt=""
	if placement in ["bottle","slot"] and game is OrderView:
		if outcome=="completed":
			game.state="playing"
			game.display_slots=game.rules.slots() if game.rules.last_events.is_empty() else game.rules.last_events[0].slots_before
			game.presentation.queue_events()
		game.restore_after_reward()
	elif placement in ["shuffle","undo"] and game is OrderView:
		game.restore_after_reward()
		if outcome=="failed":game._feedback(game.t("暂未找到可解重排，未开始广告，原盘面已保留。可重试。","No verified shuffle found. No ad started; your board is unchanged. Try again."))
	_refresh_energy()

func _invalidate_ad_context() -> void:
	_close_p1_confirmation()
	if debug_ads!=null: debug_ads.invalidate("context_changed")
	if _ad_open: _close_test_ad()

func _exit_tree() -> void:
	_shutting_down=true
	if debug_ads!=null: debug_ads.shutdown()

func _native_ad_status_changed(_state:String,_detail:String)->void:
	if _shutting_down:return
	_ad_capability_dirty=true
	home.privacy_required=debug_ads.privacy_options_required()
	if home.visible:home.refresh_privacy_entry()
	if _ad_open and debug_ads.pending_operation().is_empty():_show_native_ad_status(_native_status_placement)
func _surface_native_pending()->void:
	if not _shutting_down and debug_ads!=null and debug_ads.is_native() and debug_ads.can_settle_pending():_show_test_ad(true)
func _show_native_ad_status(placement:String)->void:
	if _shutting_down:return
	_native_status_placement=placement
	if not _ad_open:
		_ad_open=true;_ad_return_state=str(game.state) if game.visible else ""
		if game.visible:game.state="reward";game._refresh()
	if is_instance_valid(ad_dialog):remove_child(ad_dialog);ad_dialog.queue_free()
	var dialog:=NativeAdStatus.new();dialog.locale=str(progress.data.locale);dialog.placement=placement;dialog.status=debug_ads.native_status();dialog.z_index=300
	dialog.status.preparing=bool(debug_ads.active_request().get("preparing",false))
	dialog.status.request_active=not debug_ads.active_request().is_empty() and not dialog.status.preparing
	var native_dialog_id:int=dialog.get_instance_id()
	dialog.cancelled.connect(func():
		if is_instance_valid(ad_dialog) and ad_dialog.get_instance_id()==native_dialog_id:_cancel_test_ad())
	dialog.retry_requested.connect(func():
		if not is_instance_valid(ad_dialog) or ad_dialog.get_instance_id()!=native_dialog_id:return
		if debug_ads.native_status().get("ready",false):
			_close_test_ad();_begin_development_ad(placement)
		else:
			debug_ads.retry_native_loading();_show_native_ad_status(placement))
	dialog.privacy_requested.connect(func():
		if is_instance_valid(ad_dialog) and ad_dialog.get_instance_id()==native_dialog_id:debug_ads.show_privacy_options())
	ad_dialog=dialog;add_child(dialog);dialog.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);_refresh_energy()
