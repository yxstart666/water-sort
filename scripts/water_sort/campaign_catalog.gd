extends RefCounted
## Explicit campaign selection. The project scene selects the current v2 playtest;
## plain constructor/catalog defaults preserve the original-five compatibility API.
const V1 := "water_sort_v1"
const V2 := "water_sort_campaign_v2"
static func configuration(campaign: String = V1) -> Dictionary:
	if campaign == V2:
		return {"campaign":V2,"storage_file":"water_sort_progress_campaign_v2.json","attempt_prefix":"water_sort_campaign_v2:","level_path":"res://data/water_sort/campaign_v2/levels.json","strict_content":true,"celebration":true,"compatible_prefixes":[JSON.parse_string(FileAccess.get_file_as_string("res://data/water_sort/campaign_v2/legacy20_binding.json"))]}
	return {"campaign":V1,"storage_file":"water_sort_progress_v1.json","attempt_prefix":"water_sort:","level_path":"res://data/experiments/water_sort_v1/levels.json","strict_content":false,"celebration":false}
