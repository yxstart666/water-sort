extends RefCounted
## Only the explicitly supplied difficulty-profile directory is accessible.
var directory:String
var reads:Array=[]
var writes:Array=[]
func _init(path:String)->void:
	directory=ProjectSettings.globalize_path(path).simplify_path()
func file_path()->String:return directory.path_join("difficulty_progress_v1.json")
func read()->Dictionary:
	var path:=file_path();reads.append(path)
	if not FileAccess.file_exists(path):return {"ok":false,"reason":"missing"}
	var parsed:=JSON.new()
	if parsed.parse(FileAccess.get_file_as_string(path))!=OK or not parsed.data is Dictionary:return {"ok":false,"reason":"damaged"}
	return {"ok":true,"data":parsed.data}
func write(value:Dictionary)->bool:
	if DirAccess.make_dir_recursive_absolute(directory)!=OK:return false
	var path:=file_path();var temporary:=path+".tmp"
	var file:=FileAccess.open(temporary,FileAccess.WRITE)
	if file==null:return false
	file.store_string(JSON.stringify(value,"\t"));file.flush();var ok:=file.get_error()==OK;file.close()
	if not ok:return false
	if DirAccess.rename_absolute(temporary,path)!=OK:return false
	writes.append(path);return true
