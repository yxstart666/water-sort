extends Control
## Native water-sort app. Persistence is isolated from the cargo game.
const WaterProgress = preload("res://scripts/water_sort/progress.gd")
const CampaignCatalog = preload("res://scripts/water_sort/campaign_catalog.gd")
const CampaignView = preload("res://scripts/water_sort/campaign_view.gd")
@export_enum("water_sort_v1","water_sort_campaign_v2") var campaign_id := "water_sort_v1"
const HomeMenu = preload("res://scripts/water_sort/home_menu.gd")
const GameView = preload("res://scripts/experiments/water_sort_v1/view.gd")
const EnergyService = preload("res://scripts/services/energy_service.gd")
const LocalStore = preload("res://scripts/services/local_store.gd")
const AudioService = preload("res://scripts/services/game_audio.gd")
const ENERGY_FILE := "water_sort_energy_v1.json"
const LEVEL_PATH := "res://data/experiments/water_sort_v1/levels.json"
var progress
var energy
var home
var game
var audio
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

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
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
	game = CampaignView.new() if bool(configuration.celebration) else GameView.new()
	game.name = "WaterSortGame"
	game.embedded_mode = true
	game.set_locale(str(progress.data.locale))
	game.level_start_requested.connect(_start_level)
	game.level_completed.connect(_level_completed)
	game.exit_requested.connect(show_home)
	add_child(game)
	game.hide()
	game.process_mode = Node.PROCESS_MODE_DISABLED
	home = HomeMenu.new()
	home.name = "WaterSortHome"
	home.progress = progress
	home.start_level.connect(_menu_start)
	home.preferences_changed.connect(_preferences_changed)
	home.ui_clicked.connect(_ui_click)
	home.tutorial_requested.connect(_show_rules)
	add_child(home)
	home.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_preferences_changed(progress.data)
	initialized = true
	show_home()
	if not progress.load_error.is_empty(): _error("本机进度无法读取，原文件已保留。请先修复存档再开始。","The local save could not be read. The original file was preserved.")
	print("WATER_SORT_APP_READY levels=",pack.levels.size()," local_progress=true energy=30/-5/+5/120s")

func _preferences_changed(values: Dictionary) -> void:
	if game.locale != str(values.get("locale","zh")): game.set_locale(str(values.get("locale","zh")))
	if initialized: _ensure_game_energy()
	if audio != null: audio.set_preferences(bool(values.get("music",true)),bool(values.get("sound",true)))

func _ui_click() -> void:
	click_serial += 1
	if audio != null: audio.play_event("click","menu:%d" % click_serial)

func _show_rules() -> void:
	home.show_error("先点源瓶，再点空瓶或顶部同色且未满的瓶子。\n顶端连续同色会一起倒入，直到目标瓶装满。\n每种颜色装满一瓶即可过关。\n暂停和返回主页不计时；未完成局重开不额外扣体力。" if progress.data.locale=="zh" else "Tap a source bottle, then an empty bottle or one with the same top color.\nThe matching top layers pour until the destination is full.\nFill one bottle with each color to win.\nPause and Home stop the timer. Restarting an unfinished attempt costs no extra energy.","玩法说明" if progress.data.locale=="zh" else "How to play")

func _error(zh: String, en: String) -> void:
	if not home.visible: show_home()
	home.show_error(zh if progress.data.locale=="zh" else en)

func _menu_start(index: int) -> void:
	if not pending_result.is_empty() and not _settle_pending(): return
	if index==attempt_index and not attempt_id.is_empty() and not progress.data.settlements.has(attempt_id):
		if not _enter_energy(attempt_id): return
		if not loaded_attempt:
			_bind_completion_key()
			game.load_level(index)
			loaded_attempt = true
			_restore_checkpoint()
		_show_game()
		if game.state=="paused": game.resume_game()
		return
	_start_level(index)

func _start_level(index: int) -> void:
	if index < 0 or index >= progress.level_count or not progress.unlocked(index): return
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
	_bind_completion_key()
	game.load_level(index)
	loaded_attempt = true
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

func show_home() -> void:
	if not initialized: return
	if loaded_attempt: game.prepare_to_leave()
	_checkpoint()
	game.hide()
	game.process_mode = Node.PROCESS_MODE_DISABLED
	home.process_mode = Node.PROCESS_MODE_INHERIT
	home.show()
	home.resume_index = attempt_index if not attempt_id.is_empty() and not progress.data.settlements.has(attempt_id) else -1
	home.show_page("home")
	_refresh_energy()
	if audio != null: audio.set_gameplay_paused(true)

func _checkpoint() -> void:
	if not loaded_attempt or attempt_id.is_empty() or progress.data.settlements.has(attempt_id): return
	if game.rules == null: return
	progress.save_checkpoint(attempt_id,game.rules.snapshot(),int(game.moves),float(game.elapsed))

func _restore_checkpoint() -> void:
	var pending: Dictionary = progress.data.pending_attempt
	if not pending.has("snapshot"): return
	if progress.checkpoint_matches_level(attempt_index,pending.snapshot) and game.rules.restore(pending.snapshot):
		game.moves = int(pending.moves)
		game.elapsed = float(pending.seconds)
		game._refresh()
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
	if snapshot != last_energy:
		last_energy = snapshot.duplicate(true)
		home.update_energy(snapshot)
		if is_instance_valid(energy_popup): energy_popup.update_energy(snapshot)
	if is_instance_valid(game_energy_label):
		game_energy_label.text = ("%d/%d" % [int(snapshot.energy),int(snapshot.get("cap",30))]) if snapshot.get("energy") is int or snapshot.get("energy") is float else "--/%d" % int(snapshot.get("cap",30))

func _process(delta: float) -> void:
	if not initialized: return
	energy_elapsed += delta
	if energy_elapsed >= 1.0:
		energy_elapsed = 0.0
		_refresh_energy()
	if audio != null and game.visible: audio.set_gameplay_paused(game.state!="playing")

func _notification(what: int) -> void:
	if initialized and what in [NOTIFICATION_APPLICATION_FOCUS_OUT,NOTIFICATION_APPLICATION_PAUSED,NOTIFICATION_WM_CLOSE_REQUEST]: _checkpoint()

func _ensure_game_energy() -> void:
	if is_instance_valid(game_energy_badge) and game_energy_badge.get_parent()==game: return
	game_energy_badge = Control.new()
	game_energy_badge.name = "WaterSortEnergyCanvas1080x1920"
	game_energy_badge.size = Vector2(1080,1920)
	game_energy_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	game.add_child(game_energy_badge)
	if is_instance_valid(game.overlay): game.move_child(game_energy_badge,game.overlay.get_index())
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
	button.flat = true
	for state in ["normal","hover","pressed","disabled","focus"]: button.add_theme_stylebox_override(state,StyleBoxEmpty.new())
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.pressed.connect(_show_game_energy)
	game_energy_badge.add_child(button)
	_refresh_energy()

func _show_game_energy() -> void:
	if is_instance_valid(energy_popup): return
	energy_return_state = str(game.state)
	if game.state=="playing": game.pause_game()
	_checkpoint()
	game.process_mode = Node.PROCESS_MODE_DISABLED
	energy_popup = HomeMenu.new()
	energy_popup.name = "WaterSortEnergyPopup"
	energy_popup.progress = progress
	energy_popup.energy_only = true
	energy_popup.energy_closed.connect(_close_game_energy)
	add_child(energy_popup)
	energy_popup.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	energy_popup.update_energy(energy.snapshot())

func _close_game_energy() -> void:
	if not is_instance_valid(energy_popup): return
	remove_child(energy_popup)
	energy_popup.queue_free()
	energy_popup = null
	game.process_mode = Node.PROCESS_MODE_INHERIT
	if energy_return_state=="playing": game.resume_game()
	energy_return_state = ""
