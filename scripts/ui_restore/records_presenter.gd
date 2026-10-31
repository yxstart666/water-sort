extends RefCounted
## Read-only mapping of the host's completed best runs. No synthetic records.
static func duration(seconds:float)->String:
	return "%02d:%02d" % [int(seconds)/60,int(seconds)%60]
static func from_progress(progress)->Dictionary:
	var rows:Array=[];var moves:=0;var seconds:=0.0
	for index in progress.level_count:
		var best:Dictionary=progress.best_record(index)
		if not progress.completed(index) or best.is_empty():continue
		rows.append({"index":index,"moves":int(best.moves),"time":duration(float(best.seconds))})
		moves+=int(best.moves);seconds+=float(best.seconds)
	return {"completed":progress.data.completed.size(),"level_count":progress.level_count,"moves":moves,"time":duration(seconds),"records":rows}
