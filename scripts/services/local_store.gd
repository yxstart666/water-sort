extends RefCounted

const SCHEMA = 2

static func base_dir() -> String:
	# Editor runs stay in the project; native exports use platform app data.
	if OS.has_feature("editor"):
		return ProjectSettings.globalize_path("res://.local/userdata")
	return OS.get_user_data_dir()

static func path(name: String) -> String:
	return base_dir().path_join(name)

static func write(name: String, data: Dictionary) -> bool:
	if DirAccess.make_dir_recursive_absolute(base_dir()) != OK:
		return false
	var file = FileAccess.open(path(name + ".tmp"), FileAccess.WRITE)
	if file == null:
		return false
	var payload := JSON.stringify(data, "\t")
	file.store_string(payload)
	file.flush()
	# Never replace the last good save if the temporary write was incomplete.
	var complete := file.get_error() == OK and file.get_length() == payload.to_utf8_buffer().size()
	file.close()
	if not complete:
		return false
	return DirAccess.rename_absolute(path(name + ".tmp"), path(name)) == OK

static func read(name: String) -> Dictionary:
	if not FileAccess.file_exists(path(name)):
		return {"ok": false, "reason": "missing"}
	var file = FileAccess.open(path(name), FileAccess.READ)
	if file == null:
		return {"ok": false, "reason": "unreadable"}
	var parsed = JSON.new()
	if parsed.parse(file.get_as_text()) != OK or not parsed.data is Dictionary:
		return {"ok": false, "reason": "damaged"}
	if parsed.data.get("schema", -1) != SCHEMA:
		return {"ok": false, "reason": "incompatible"}
	return {"ok": true, "data": parsed.data}
