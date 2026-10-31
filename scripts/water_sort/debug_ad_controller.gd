extends "res://scripts/water_sort/reward_controller.gd"
## Backward-compatible desktop/mock facade; never selected for Android.
static func enabled()->bool:
	var flag:Variant=ProjectSettings.get_setting("development/mock_ads_enabled",false)
	return OS.is_debug_build() and flag is bool and flag
func _init(owner_app,test_clock:Callable=Callable())->void:
	super(owner_app,test_clock,"development_mock")
