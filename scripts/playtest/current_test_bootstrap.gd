extends "res://scripts/playtest/energy_test_bootstrap.gd"
## Current user playtest: real energy, all existing C3 levels, separate files.
func _init()->void:
	profile_directory="res://.current-energy-profile-v1"
func _update_caption()->void:
	var zh:bool=app.progress.data.locale=="zh"
	var title:="彩瓶时光 · 当前测试版 · 真实体力" if zh else "Color Pause · Current Playtest · Real Energy"
	if get_window().title!=title:get_window().title=title
	var text:="测试版 · 真实体力 · 模拟广告" if zh else "PLAYTEST · REAL ENERGY · MOCK ADS"
	if energy_store.fail_refill_save:text+=(" · F8保存失败开启" if zh else " · F8 SAVE FAILURE ON")
	if badge.text!=text:badge.text=text
