extends Node

const _Log = preload("res://scripts/engine/bj_log.gd")
const APP_ID := "shadowfetch-blackjack"
const SETTINGS_VERSION := 1

var resolution: Vector2i = Vector2i(1920, 1080)
var fullscreen: bool = false
var vsync: bool = true
var quality: String = "high"
var aa: int = 4
var shadows: bool = true
var animation_speed: float = 1.0
var master_volume: float = 0.80
var music_volume: float = 0.22
var fx_volume: float = 0.85
var ambient_volume: float = 0.28
var muted: bool = false
var seen_tutorial: bool = false

signal settings_changed


func _ready() -> void:
	load_settings()
	if not _is_headless():
		apply_display()
		apply_audio()


func _sandbox() -> String:
	return OS.get_environment("SHADOWFETCH_BJ_HOME")


func config_dir() -> String:
	var box := _sandbox()
	if not box.is_empty():
		return box.path_join("config")
	var xdg := OS.get_environment("XDG_CONFIG_HOME")
	if xdg.is_empty():
		xdg = OS.get_environment("HOME").path_join(".config")
	return xdg.path_join(APP_ID)


func data_dir() -> String:
	var box := _sandbox()
	if not box.is_empty():
		return box.path_join("data")
	var xdg := OS.get_environment("XDG_DATA_HOME")
	if xdg.is_empty():
		xdg = OS.get_environment("HOME").path_join(".local/share")
	return xdg.path_join(APP_ID)


func settings_path() -> String:
	return config_dir().path_join("settings.json")


func ensure_dirs() -> void:
	DirAccess.make_dir_recursive_absolute(config_dir())
	DirAccess.make_dir_recursive_absolute(data_dir())


func to_dict() -> Dictionary:
	return {
		"version": SETTINGS_VERSION,
		"resolution": [resolution.x, resolution.y],
		"fullscreen": fullscreen,
		"vsync": vsync,
		"quality": quality,
		"aa": aa,
		"shadows": shadows,
		"animation_speed": animation_speed,
		"master_volume": master_volume,
		"music_volume": music_volume,
		"fx_volume": fx_volume,
		"ambient_volume": ambient_volume,
		"muted": muted,
		"seen_tutorial": seen_tutorial,
	}


func reset_defaults() -> void:
	resolution = Vector2i(1920, 1080)
	fullscreen = false
	vsync = true
	quality = "high"
	aa = 4
	shadows = true
	animation_speed = 1.0
	master_volume = 0.80
	music_volume = 0.22
	fx_volume = 0.85
	ambient_volume = 0.28
	muted = false
	seen_tutorial = seen_tutorial


func from_dict(d: Dictionary) -> void:
	var res: Variant = d.get("resolution", [resolution.x, resolution.y])
	if res is Array and res.size() >= 2:
		var rx := int(res[0])
		var ry := int(res[1])
		if rx >= 640 and ry >= 480 and rx <= 7680 and ry <= 4320:
			resolution = Vector2i(rx, ry)
	fullscreen = bool(d.get("fullscreen", fullscreen))
	vsync = bool(d.get("vsync", vsync))
	var q := str(d.get("quality", quality)).to_lower()
	if q in ["low", "medium", "high", "ultra"]:
		quality = q
	aa = clampi(int(d.get("aa", aa)), 0, 8)
	shadows = bool(d.get("shadows", shadows))
	animation_speed = clampf(float(d.get("animation_speed", animation_speed)), 0.35, 2.5)
	master_volume = clampf(float(d.get("master_volume", master_volume)), 0.0, 1.0)
	music_volume = clampf(float(d.get("music_volume", music_volume)), 0.0, 1.0)
	fx_volume = clampf(float(d.get("fx_volume", fx_volume)), 0.0, 1.0)
	ambient_volume = clampf(float(d.get("ambient_volume", ambient_volume)), 0.0, 1.0)
	muted = bool(d.get("muted", muted))
	seen_tutorial = bool(d.get("seen_tutorial", seen_tutorial))


func save_settings() -> void:
	ensure_dirs()
	var f := FileAccess.open(settings_path(), FileAccess.WRITE)
	if f == null:
		_Log.warn("Could not write settings")
		return
	f.store_string(JSON.stringify(to_dict(), "\t"))
	settings_changed.emit()


func load_settings() -> void:
	var path := settings_path()
	if not FileAccess.file_exists(path):
		return
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		_Log.warn("Could not read settings; using defaults")
		return
	var text := f.get_as_text()
	var parsed: Variant = JSON.parse_string(text)
	if parsed is Dictionary:
		from_dict(parsed)
	else:
		_Log.warn("Corrupt settings.json — restoring defaults")
		reset_defaults()
		save_settings()


func apply_display() -> void:
	if _is_headless():
		return
	Engine.max_fps = 0
	DisplayServer.window_set_vsync_mode(
		DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED
	)
	if fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_size(resolution)
	var vp := get_viewport()
	if vp == null:
		return
	match aa:
		8:
			vp.msaa_3d = Viewport.MSAA_8X
		4:
			vp.msaa_3d = Viewport.MSAA_4X
		2:
			vp.msaa_3d = Viewport.MSAA_2X
		_:
			vp.msaa_3d = Viewport.MSAA_DISABLED
	# TAA / FXAA smear Control HUD text. Keep 3D AA on MSAA only.
	vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
	vp.use_taa = false
	if quality == "ultra" and aa == 0:
		vp.msaa_3d = Viewport.MSAA_8X


func apply_audio() -> void:
	_set_bus("Master", master_volume, muted)
	_set_bus("Music", music_volume, muted)
	_set_bus("FX", fx_volume, muted)
	_set_bus("Ambient", ambient_volume, muted)


func shadow_size() -> int:
	if not shadows:
		return 0
	match quality:
		"ultra":
			return 8192
		"high":
			return 4096
		"medium":
			return 2048
		_:
			return 1024


func bloom_enabled() -> bool:
	return false


func anim_scale() -> float:
	return 1.0 / maxf(animation_speed, 0.35)


func _set_bus(name: String, linear: float, mute: bool) -> void:
	var idx := AudioServer.get_bus_index(name)
	if idx < 0:
		return
	AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(linear, 0.0001)))
	AudioServer.set_bus_mute(idx, mute or linear <= 0.001)


func _is_headless() -> bool:
	return DisplayServer.get_name() == "headless" or OS.has_feature("headless")
