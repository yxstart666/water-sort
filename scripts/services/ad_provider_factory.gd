extends RefCounted
## No automatic mock fallback. Configuration cannot turn a test build into live advertising.
const TestAdapter = preload("res://scripts/services/android_test_ad_adapter.gd")
const MockAdapter = preload("res://scripts/services/development_ad_adapter.gd")
static func create_controller(owner,platform:String=OS.get_name()):
    # This shipped singleton is test-only. Android never falls back to Mock,
    # including when the singleton is absent or its API contract is incomplete.
    if platform=="Android":
        return load("res://scripts/water_sort/reward_controller.gd").new(owner,Callable(),"google_test")
    return load("res://scripts/water_sort/debug_ad_controller.gd").new(owner)
static func create(config: Dictionary) -> Dictionary:
    var provider: String = str(config.get("provider", "disabled"))
    if provider == "disabled": return {"ok": true, "provider": provider, "adapter": null}
    if provider == "development_mock":
        if not OS.is_debug_build() or ProjectSettings.get_setting("development/mock_ads_enabled", false) != true:
            return {"ok": false, "reason": "mock_disabled", "adapter": null}
        return {"ok": true, "provider": provider, "adapter": MockAdapter.new()}
    if provider == "google_test":
        var adapter = TestAdapter.new()
        if not adapter.available(): return {"ok": false, "reason": "native_plugin_unavailable", "adapter": null}
        return {"ok": true, "provider": provider, "adapter": adapter}
    if provider == "google_live":
        # A separate reviewed native implementation and real account configuration are required.
        return {"ok": false, "reason": "live_provider_not_implemented", "adapter": null}
    return {"ok": false, "reason": "unknown_provider", "adapter": null}
