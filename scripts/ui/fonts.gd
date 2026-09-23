class_name BJFonts
extends RefCounted
## Bundled fonts (SIL OFL): Inter for interface text, Noto Serif Display for titles,
## Noto Sans Symbols 2 as a fallback for card suits and symbols.

const UI := {
	"regular": "res://assets/fonts/Inter-Regular.otf",
	"medium": "res://assets/fonts/Inter-Medium.otf",
	"semibold": "res://assets/fonts/Inter-SemiBold.otf",
	"bold": "res://assets/fonts/Inter-Bold.otf",
}
const DISPLAY := {
	"semibold": "res://assets/fonts/NotoSerifDisplay-SemiBold.ttf",
	"bold": "res://assets/fonts/NotoSerifDisplay-Bold.ttf",
}
const SYMBOLS := "res://assets/fonts/NotoSansSymbols2-Regular.ttf"

static var _cache: Dictionary = {}


static func ui(weight: String = "medium") -> Font:
	return _load_font("ui:" + weight, str(UI.get(weight, UI["medium"])))


static func display(weight: String = "bold") -> Font:
	return _load_font("display:" + weight, str(DISPLAY.get(weight, DISPLAY["bold"])))


static func _load_font(key: String, path: String) -> Font:
	if _cache.has(key):
		return _cache[key]
	var font: Font = null
	if ResourceLoader.exists(path):
		var res = load(path)
		if res is FontFile:
			var ff: FontFile = res.duplicate()
			ff.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
			ff.hinting = TextServer.HINTING_LIGHT
			ff.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_AUTO
			ff.generate_mipmaps = true
			var fallbacks: Array[Font] = []
			if ResourceLoader.exists(SYMBOLS):
				var sym = load(SYMBOLS)
				if sym is Font:
					fallbacks.append(sym)
			if key.begins_with("display"):
				var inter = ui("semibold")
				if inter != null:
					fallbacks.append(inter)
			ff.fallbacks = fallbacks
			font = ff
	if font == null:
		font = ThemeDB.fallback_font
	_cache[key] = font
	return font
