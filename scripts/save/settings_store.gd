extends Node
## Autoload `SettingsStore`: display, audio, gameplay, appearance, accessibility and
## table-rule preferences. Schema v3; v1/v2 files migrate automatically.

const _Log = preload("res://scripts/engine/bj_log.gd")
const _Paths = preload("res://scripts/save/paths.gd")
const _Rules = preload("res://scripts/engine/bj_rules.gd")

const SETTINGS_VERSION := 3
const QUALITIES: PackedStringArray = ["low", "medium", "high", "ultra"]
const COACH_MODES: PackedStringArray = ["off", "hints", "coach"]
const CAMERA_MODES: PackedStringArray = ["seated", "overhead"]
const FELT_COLORS: PackedStringArray = ["emerald", "midnight", "crimson", "charcoal"]
const CARD_BACKS: PackedStringArray = ["emerald", "onyx", "crimson", "sapphire"]
const RESOLUTIONS: Array[Vector2i] = [
	Vector2i(1280, 720), Vector2i(1600, 900), Vector2i(1920, 1080), Vector2i(2560, 1440), Vector2i(3840, 2160)
]

signal settings_changed
signal appearance_changed
signal rules_changed

# Display
var resolution: Vector2i = Vector2i(1920, 1080)
var fullscreen: bool = false
var vsync: bool = true
var quality: String = "high"
var aa: int = 4
var shadows: bool = true
# Audio
var master_volume: float = 0.80
var music_volume: float = 0.35
var fx_volume: float = 0.85
var ambient_volume: float = 0.30
var muted: bool = false
# Gameplay
var animation_speed: float = 1.0
var coach_mode: String = "hints"
var show_count: bool = false
var show_totals: bool = true
var seen_tutorial: bool = false
# Appearance
var camera_mode: String = "seated"
var felt_color: String = "emerald"
var card_back: String = "emerald"
var four_color: bool = false
# Accessibility
var ui_scale: float = 1.0
var reduced_motion: bool = false
var camera_sway: bool = true
# Table
var rules: _Rules = _Rules.new()


func _ready() -> void:
	load_settings()
	if not _Paths.is_headless():
		apply_display()
		apply_audio()


func config_dir() -> String:
	return _Paths.config_dir()


func data_dir() -> String:
	return _Paths.data_dir()


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
		"master_volume": master_volume,
		"music_volume": music_volume,
		"fx_volume": fx_volume,
		"ambient_volume": ambient_volume,
		"muted": muted,
		"animation_speed": animation_speed,
		"coach_mode": coach_mode,
		"show_count": show_count,
		"show_totals": show_totals,
		"seen_tutorial": seen_tutorial,
		"camera_mode": camera_mode,
		"felt_color": felt_color,
		"card_back": card_back,
		"four_color": four_color,
		"ui_scale": ui_scale,
		"reduced_motion": reduced_motion,
		"camera_sway": camera_sway,
		"rules": rules.to_dict(),
	}


func reset_defaults(keep_tutorial: bool = true) -> void:
	var seen := seen_tutorial
	resolution = Vector2i(1920, 1080)
	fullscreen = false
	vsync = true
	quality = "high"
	aa = 4
	shadows = true
	master_volume = 0.80
	music_volume = 0.35
	fx_volume = 0.85
	ambient_volume = 0.30
	muted = false
	animation_speed = 1.0
	coach_mode = "hints"
	show_count = false
	show_totals = true
	camera_mode = "seated"
	felt_color = "emerald"
	card_back = "emerald"
	four_color = false
	ui_scale = 1.0
	reduced_motion = false
	camera_sway = true
	rules = _Rules.new()
	seen_tutorial = seen if keep_tutorial else false


## Loads validated values. Unknown or out-of-range values keep their defaults.
func from_dict(d: Dictionary) -> void:
	var res: Variant = d.get("resolution", [resolution.x, resolution.y])
	if res is Array and res.size() >= 2:
		var rx := int(res[0])
		var ry := int(res[1])
		if rx >= 640 and ry >= 480 and rx <= 7680 and ry <= 4320:
			resolution = Vector2i(rx, ry)
	fullscreen = bool(d.get("fullscreen", fullscreen))
	vsync = bool(d.get("vsync", vsync))
	quality = _pick(str(d.get("quality", quality)).to_lower(), QUALITIES, quality)
	var aa_v := int(d.get("aa", aa))
	aa = aa_v if aa_v in [0, 2, 4, 8] else aa
	shadows = bool(d.get("shadows", shadows))
	master_volume = _unit(d.get("master_volume", master_volume))
	music_volume = _unit(d.get("music_volume", music_volume))
	fx_volume = _unit(d.get("fx_volume", fx_volume))
	ambient_volume = _unit(d.get("ambient_volume", ambient_volume))
	muted = bool(d.get("muted", muted))
	animation_speed = clampf(float(d.get("animation_speed", animation_speed)), 0.5, 2.5)
	coach_mode = _pick(str(d.get("coach_mode", coach_mode)), COACH_MODES, coach_mode)
	show_count = bool(d.get("show_count", show_count))
	show_totals = bool(d.get("show_totals", show_totals))
	seen_tutorial = bool(d.get("seen_tutorial", seen_tutorial))
	camera_mode = _pick(str(d.get("camera_mode", camera_mode)), CAMERA_MODES, camera_mode)
	felt_color = _pick(str(d.get("felt_color", felt_color)), FELT_COLORS, felt_color)
	card_back = _pick(str(d.get("card_back", card_back)), CARD_BACKS, card_back)
	four_color = bool(d.get("four_color", four_color))
	ui_scale = clampf(float(d.get("ui_scale", ui_scale)), 0.8, 1.5)
	reduced_motion = bool(d.get("reduced_motion", reduced_motion))
	camera_sway = bool(d.get("camera_sway", camera_sway))
	# v1/v2 kept two table rules at the top level.
	if d.has("dealer_hits_soft_17"):
		rules.dealer_hits_soft_17 = bool(d["dealer_hits_soft_17"])
	if d.has("late_surrender"):
		rules.late_surrender = bool(d["late_surrender"])
	var r: Variant = d.get("rules", null)
	if r is Dictionary:
		rules.from_dict(r)


func save_settings() -> void:
	if not _Paths.write_json(settings_path(), to_dict()):
		_Log.warn("Could not write settings")
	settings_changed.emit()


func load_settings() -> void:
	var parsed: Variant = _Paths.read_json(settings_path())
	if parsed == null:
		return
	if parsed is Dictionary and not parsed.has("__corrupt"):
		from_dict(parsed)
		if int(parsed.get("version", 1)) < SETTINGS_VERSION:
			_Log.info("Migrated settings.json to v%d" % SETTINGS_VERSION)
			save_settings()
	else:
		_Log.warn("Corrupt settings.json (kept as settings.json.corrupt) — restoring defaults")
		reset_defaults()
		save_settings()


func set_rules(r: _Rules) -> void:
	rules = r.duplicate_rules()
	save_settings()
	rules_changed.emit()


func notify_appearance() -> void:
	save_settings()
	appearance_changed.emit()


func apply_display() -> void:
	if _Paths.is_headless():
		return
	Engine.max_fps = 0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED)
	var mode := DisplayServer.window_get_mode()
	if fullscreen:
		if mode != DisplayServer.WINDOW_MODE_FULLSCREEN and mode != DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		if mode == DisplayServer.WINDOW_MODE_FULLSCREEN or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_WINDOWED:
			var screen := DisplayServer.screen_get_usable_rect()
			var size := resolution
			if screen.size.x > 0:
				size = Vector2i(mini(size.x, screen.size.x), mini(size.y, screen.size.y))
			if DisplayServer.window_get_size() != size:
				DisplayServer.window_set_size(size)
				if screen.size.x > 0:
					DisplayServer.window_set_position(screen.position + (screen.size - size) / 2)
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
	# TAA / FXAA smear HUD text; 3D anti-aliasing stays on MSAA.
	vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
	vp.use_taa = false
	vp.anisotropic_filtering_level = Viewport.ANISOTROPY_16X if quality in ["high", "ultra"] else Viewport.ANISOTROPY_4X
	get_tree().root.content_scale_factor = ui_scale


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
	return quality != "low"


func anim_scale() -> float:
	return 1.0 / maxf(animation_speed, 0.35)


func motion_enabled() -> bool:
	return not reduced_motion


func _set_bus(name: String, linear: float, mute: bool) -> void:
	var idx := AudioServer.get_bus_index(name)
	if idx < 0:
		return
	AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(linear, 0.0001)))
	AudioServer.set_bus_mute(idx, mute or linear <= 0.001)


func _pick(value: String, allowed: PackedStringArray, fallback: String) -> String:
	return value if allowed.has(value) else fallback


func _unit(v: Variant) -> float:
	if v is float or v is int:
		return clampf(float(v), 0.0, 1.0)
	return 0.5
