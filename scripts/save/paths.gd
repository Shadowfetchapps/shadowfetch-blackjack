class_name BJPaths
extends RefCounted
## XDG locations for settings and player data. `SHADOWFETCH_BJ_HOME` redirects both
## (used by the test suite so developer runs never touch real saves).

const APP_ID := "shadowfetch-blackjack"


static func _sandbox() -> String:
	return OS.get_environment("SHADOWFETCH_BJ_HOME")


static func config_dir() -> String:
	var box := _sandbox()
	if not box.is_empty():
		return box.path_join("config")
	var xdg := OS.get_environment("XDG_CONFIG_HOME")
	if xdg.is_empty():
		xdg = OS.get_environment("HOME").path_join(".config")
	return xdg.path_join(APP_ID)


static func data_dir() -> String:
	var box := _sandbox()
	if not box.is_empty():
		return box.path_join("data")
	var xdg := OS.get_environment("XDG_DATA_HOME")
	if xdg.is_empty():
		xdg = OS.get_environment("HOME").path_join(".local/share")
	return xdg.path_join(APP_ID)


## Writes JSON through a temporary file and a rename so a crash never leaves a
## half-written save behind.
static func write_json(path: String, data: Variant) -> bool:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var tmp := path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(data, "\t"))
	f.close()
	return DirAccess.rename_absolute(tmp, path) == OK


## Returns the parsed JSON, or null when the file is missing. A file that exists but
## cannot be parsed is copied aside as `<name>.corrupt` and `{"__corrupt": true}` is returned.
static func read_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	var text := FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(text)
	if parsed == null:
		var f := FileAccess.open(path + ".corrupt", FileAccess.WRITE)
		if f != null:
			f.store_string(text)
			f.close()
		return {"__corrupt": true}
	return parsed


static func is_headless() -> bool:
	return DisplayServer.get_name() == "headless" or OS.has_feature("headless")
