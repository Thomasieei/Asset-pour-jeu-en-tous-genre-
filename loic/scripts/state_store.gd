extends RefCounted
class_name StateStore
# Write-then-rename keeps the previous complete save readable after interruption.
static func write_json(path: String, value: Dictionary) -> bool:
	var file := FileAccess.open(path+".new",FileAccess.WRITE)
	if not file: return false
	file.store_string(JSON.stringify(value))
	file.flush()
	var error := file.get_error()
	file.close()
	if error != OK: return false
	if FileAccess.file_exists(path) and _valid_current(path):
		if DirAccess.copy_absolute(ProjectSettings.globalize_path(path),ProjectSettings.globalize_path(path+".bak")) != OK: return false
	return DirAccess.rename_absolute(ProjectSettings.globalize_path(path+".new"),ProjectSettings.globalize_path(path)) == OK

static func read_json(path: String) -> Dictionary:
	for candidate in [path,path+".bak"]:
		var file := FileAccess.open(candidate,FileAccess.READ)
		if not file: continue
		var parser := JSON.new()
		if parser.parse(file.get_as_text()) == OK and parser.data is Dictionary:
			return parser.data
	return {}

static func _valid_current(path: String) -> bool:
	var file := FileAccess.open(path,FileAccess.READ)
	if not file: return false
	var parser := JSON.new()
	return parser.parse(file.get_as_text())==OK and parser.data is Dictionary
