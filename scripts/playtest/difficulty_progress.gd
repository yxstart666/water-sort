extends "res://scripts/water_sort/progress.gd"
## Test profile only. Unlock eligibility never fabricates completion or records.
func unlocked(index:int)->bool:
	return index>=0 and index<level_count
func _valid_water(value:Variant)->bool:
	# Difficulty review can clear level50 before level1. Preserve those genuine
	# results without manufacturing a completed prefix. All other validation is
	# still supplied by the unchanged production progress adapter.
	if not value is Dictionary or not value.get("completed") is Array:return false
	var seen:Dictionary={}
	var count:int=_saved_pack_level_count(value) if strict_content else level_count
	for number in value.completed:
		if not _whole(number,1) or int(number)>count or seen.has(int(number)):return false
		seen[int(number)]=true
	var candidate:Dictionary=value.duplicate(true);candidate.completed=[]
	return super._valid_water(candidate)
