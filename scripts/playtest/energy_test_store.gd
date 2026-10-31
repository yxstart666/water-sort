extends RefCounted
var directory:String
var fail_refill_save:=false
func _init(path:String)->void:
	directory=ProjectSettings.globalize_path(path).simplify_path()
func read()->Dictionary:
	var path:=directory.path_join("energy_test_v1.json")
	if not FileAccess.file_exists(path):return {"ok":false,"reason":"missing"}
	var parser:=JSON.new()
	if parser.parse(FileAccess.get_file_as_string(path))!=OK or not parser.data is Dictionary:return {"ok":false,"reason":"damaged"}
	return {"ok":true,"data":parser.data}
func write(value:Dictionary)->bool:
	if fail_refill_save:
		var prior:=read()
		var old:Dictionary=prior.get("data",{}).get("development_ad_receipts",{})
		if value.get("development_ad_receipts",{}).size()>old.size():return false
	if DirAccess.make_dir_recursive_absolute(directory)!=OK:return false
	var path:=directory.path_join("energy_test_v1.json")
	var file:=FileAccess.open(path+".tmp",FileAccess.WRITE)
	if file==null:return false
	file.store_string(JSON.stringify(value,"\t"));file.flush()
	var ok:=file.get_error()==OK;file.close()
	return ok and DirAccess.rename_absolute(path+".tmp",path)==OK
