extends RefCounted
## Explicit campaign selection. The project scene selects the current v2 playtest;
## plain constructor/catalog defaults preserve the original-five compatibility API.
const V1 := "water_sort_v1"
const V2 := "water_sort_campaign_v2"
const V3 := "water_sort_orders_v3"
static func configuration(campaign: String = V1) -> Dictionary:
	if campaign == V3:
		if ProjectSettings.get_setting("gameplay/order_pack_candidate","")=="c3_full50_20261030":
			# Fresh content namespace. No old checkpoints/records/receipts are imported.
			var config=configuration_legacy_orders()
			config.level_path="res://data/water_sort/orders_v3/candidates/c3_full50_20261030.json"
			config.storage_file="water_sort_progress_orders_c3_full50_20261030.json"
			config.attempt_prefix="water_sort_orders_c3_full50_20261030:"
			config.compatible_order_packs=[]
			config.preserve_legacy_attempts=false
			return config
		if ProjectSettings.get_setting("gameplay/order_pack_candidate","")=="batch_c_20261030":
			var config=configuration_legacy_orders()
			config.level_path="res://data/water_sort/orders_v3/candidates/batch_c_20261030.json"
			config.storage_file="water_sort_progress_orders_batch_c_candidate.json"
			config.preserve_legacy_attempts=true
			config.compatible_order_packs.append("res://data/water_sort/orders_v3/levels.json")
			return config
		return configuration_legacy_orders()
	if campaign == V2:
		return {"campaign":V2,"storage_file":"water_sort_progress_campaign_v2.json","attempt_prefix":"water_sort_campaign_v2:","level_path":"res://data/water_sort/campaign_v2/levels.json","strict_content":true,"celebration":true,"compatible_prefixes":[JSON.parse_string(FileAccess.get_file_as_string("res://data/water_sort/campaign_v2/legacy20_binding.json"))]}
	return {"campaign":V1,"storage_file":"water_sort_progress_v1.json","attempt_prefix":"water_sort:","level_path":"res://data/experiments/water_sort_v1/levels.json","strict_content":false,"celebration":false}
static func configuration_legacy_orders()->Dictionary:
		return {"campaign":V3,"storage_file":"water_sort_progress_orders_v3.json","attempt_prefix":"water_sort_orders_v3:","level_path":"res://data/water_sort/orders_v3/levels.json","strict_content":true,"celebration":true,"order_mode":true,"compatible_order_packs":["res://data/water_sort/orders_v3/legacy_initial_pack.json","res://data/water_sort/orders_v3/legacy_pre_cover_lock_pack.json","res://data/water_sort/orders_v3/legacy_pre_unknown_pack.json","res://data/water_sort/orders_v3/legacy_middle_unknown_pack.json"]}
