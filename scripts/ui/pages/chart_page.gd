extends Control
## Basic-strategy chart generated from BJStrategy for the rules currently saved,
## so it always matches the coach and the table.

const ThemeFactory = preload("res://scripts/ui/theme_factory.gd")
const BJStrategy = preload("res://scripts/engine/bj_strategy.gd")

const CELL := Vector2(40, 30)
const COLORS := {
	"H": [Color(0.20, 0.20, 0.22), Color(0.88, 0.86, 0.82)],
	"S": [Color(0.13, 0.40, 0.27), Color(0.93, 0.97, 0.93)],
	"D": [Color(0.82, 0.64, 0.30), Color(0.08, 0.06, 0.04)],
	"Ds": [Color(0.66, 0.52, 0.24), Color(0.08, 0.06, 0.04)],
	"P": [Color(0.20, 0.38, 0.66), Color(0.94, 0.96, 1.0)],
	"Rh": [Color(0.62, 0.20, 0.20), Color(1.0, 0.92, 0.9)],
	"Rs": [Color(0.62, 0.20, 0.20), Color(1.0, 0.92, 0.9)],
	"Rp": [Color(0.62, 0.20, 0.20), Color(1.0, 0.92, 0.9)],
}

var overlay
var _grids: HBoxContainer
var _subtitle: Label


func build(p_overlay) -> void:
	overlay = p_overlay
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var f: Dictionary = overlay.frame("Basic Strategy", " ", 1500, 0)
	add_child(f["root"])
	var body: VBoxContainer = f["body"]
	_subtitle = f["subtitle"]
	_grids = HBoxContainer.new()
	_grids.add_theme_constant_override("separation", 40)
	_grids.alignment = BoxContainer.ALIGNMENT_CENTER
	body.add_child(_grids)
	var legend := HBoxContainer.new()
	legend.add_theme_constant_override("separation", 18)
	legend.alignment = BoxContainer.ALIGNMENT_CENTER
	body.add_child(legend)
	for item in [["H", "Hit"], ["S", "Stand"], ["D", "Double, else hit"], ["Ds", "Double, else stand"], ["P", "Split"], ["Rh", "Surrender, else hit"], ["Rs", "Surrender, else stand"], ["Rp", "Surrender, else split"]]:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		row.add_child(_cell(item[0]))
		row.add_child(ThemeFactory.label(item[1], "Muted"))
		legend.add_child(row)
	overlay.back_button(f["footer"])


func refresh() -> void:
	var rules = SettingsStore.rules
	_subtitle.text = "For the saved table rules: %s. The HINT button and the coach use exactly this chart." % rules.summary().replace("  ·  ", " · ")
	for c in _grids.get_children():
		c.queue_free()
	var chart := BJStrategy.chart(rules)
	_grids.add_child(_grid("HARD TOTALS", chart["hard"]))
	_grids.add_child(_grid("SOFT TOTALS", chart["soft"]))
	_grids.add_child(_grid("PAIRS", chart["pairs"]))


func _grid(title: String, rows: Array) -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	v.add_child(ThemeFactory.label(title, "Caps"))
	var g := GridContainer.new()
	g.columns = 11
	g.add_theme_constant_override("h_separation", 3)
	g.add_theme_constant_override("v_separation", 3)
	v.add_child(g)
	var corner := ThemeFactory.label("", "Muted")
	corner.custom_minimum_size = Vector2(56, CELL.y)
	g.add_child(corner)
	for up in ["2", "3", "4", "5", "6", "7", "8", "9", "10", "A"]:
		var h := ThemeFactory.label(up, "Subheading")
		h.custom_minimum_size = CELL
		h.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		h.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		g.add_child(h)
	for r in rows:
		var lab := ThemeFactory.label(str(r[0]), "Body")
		lab.custom_minimum_size = Vector2(56, CELL.y)
		lab.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		g.add_child(lab)
		for code in r[1]:
			g.add_child(_cell(code))
	return v


func _cell(code: String) -> Control:
	var l := Label.new()
	l.text = code
	l.custom_minimum_size = CELL
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.theme_type_variation = "Body"
	l.add_theme_font_size_override("font_size", 14)
	var c: Array = COLORS.get(code, COLORS["H"])
	var sb := StyleBoxFlat.new()
	sb.bg_color = c[0]
	sb.set_corner_radius_all(4)
	l.add_theme_stylebox_override("normal", sb)
	l.add_theme_color_override("font_color", c[1])
	return l
