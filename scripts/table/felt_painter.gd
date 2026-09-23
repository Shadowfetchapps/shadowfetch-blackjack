class_name FeltPainter
extends Node2D
## Draws the printed felt layout (rules arcs, insurance band, betting circles) into
## a texture that maps onto the half-disc felt mesh. Baked once by TextureBaker and
## re-baked whenever the table rules or felt colour change.

const TableLayout = preload("res://scripts/table/table_layout.gd")
const BJFonts = preload("res://scripts/ui/fonts.gd")

const FELTS := {
	"emerald": Color(0.030, 0.195, 0.112),
	"midnight": Color(0.028, 0.072, 0.180),
	"crimson": Color(0.245, 0.036, 0.052),
	"charcoal": Color(0.075, 0.080, 0.086),
}

var tex_size := Vector2i(4096, 2048)
var felt_key := "emerald"
var line_bj := "BLACKJACK PAYS 3 TO 2"
var line_rule := "DEALER MUST STAND ON ALL 17s"
var side_bets := true

var _gold := Color(0.87, 0.71, 0.38, 0.92)
var _gold_dim := Color(0.87, 0.71, 0.38, 0.45)
var _cream := Color(0.95, 0.91, 0.80, 0.78)


func _draw() -> void:
	var w := float(tex_size.x)
	var h := float(tex_size.y)
	var c := Vector2(w * 0.5, 0.0)
	var base: Color = FELTS.get(felt_key, FELTS["emerald"])
	draw_rect(Rect2(Vector2.ZERO, Vector2(w, h)), base.darkened(0.25))
	# Soft pool of lighter felt around the play area.
	var steps := 48
	for i in steps:
		var t := float(i) / float(steps)
		var r := h * (1.02 - t * 0.85)
		var col := base.lerp(base.lightened(0.14), t)
		draw_circle(c + Vector2(0, h * 0.18 * t), r, col)
	# Border lines just inside the rail.
	draw_arc(c, h * 0.972, 0.0, PI, 512, _gold, h * 0.0045, true)
	draw_arc(c, h * 0.952, 0.0, PI, 512, _gold_dim, h * 0.0016, true)
	# Rules arcs.
	var display := BJFonts.display("bold")
	var ui := BJFonts.ui("semibold")
	_arc_text(line_bj, display, int(h * 0.050), h * 0.372, 90.0, _gold, h * 0.004)
	_arc_text(line_rule, ui, int(h * 0.026), h * 0.308, 90.0, _cream, h * 0.006)
	# Insurance band.
	var a0 := deg_to_rad(38.0)
	var a1 := deg_to_rad(142.0)
	draw_arc(c, h * 0.408, a0, a1, 256, _gold, h * 0.0030, true)
	draw_arc(c, h * 0.468, a0, a1, 256, _gold, h * 0.0030, true)
	for a in [a0, a1]:
		draw_line(c + Vector2(cos(a), sin(a)) * h * 0.408, c + Vector2(cos(a), sin(a)) * h * 0.468, _gold, h * 0.003, true)
	_arc_text("INSURANCE PAYS 2 TO 1", ui, int(h * 0.024), h * 0.446, 90.0, _gold, h * 0.009)
	# Emblem near the dealer.
	# Decorative empty seats.
	for deg in TableLayout.OTHER_SEATS:
		var a := deg_to_rad(deg)
		var p := c + Vector2(cos(a), sin(a)) * h * 0.745
		_ring(p, h * (TableLayout.SPOTS["main"]["radius"] / TableLayout.FELT_RADIUS), _gold_dim, h)
	# Player spots.
	_bet_circle(_spot_px("main"), _spot_r("main"), h, display)
	if side_bets:
		_side_circle(_spot_px("pp"), _spot_r("pp"), h, ui, "PERFECT PAIRS")
		_side_circle(_spot_px("t3"), _spot_r("t3"), h, display, "21+3")


func _spot_px(spot: String) -> Vector2:
	var p: Vector2 = TableLayout.SPOTS[spot]["pos"]
	var uv := TableLayout.felt_uv(p.x, p.y)
	return Vector2(uv.x * tex_size.x, uv.y * tex_size.y)


func _spot_r(spot: String) -> float:
	return float(TableLayout.SPOTS[spot]["radius"]) / TableLayout.FELT_RADIUS * tex_size.y


func _ring(p: Vector2, r: float, col: Color, h: float) -> void:
	draw_arc(p, r, 0.0, TAU, 128, col, h * 0.0035, true)
	draw_arc(p, r * 0.86, 0.0, TAU, 128, Color(col, col.a * 0.6), h * 0.0014, true)


func _bet_circle(p: Vector2, r: float, h: float, font: Font) -> void:
	draw_circle(p, r, Color(0, 0, 0, 0.12))
	draw_arc(p, r, 0.0, TAU, 160, _gold, h * 0.0050, true)
	draw_arc(p, r * 0.87, 0.0, TAU, 160, _gold_dim, h * 0.0018, true)
	var dots := 24
	for i in dots:
		var a := TAU * float(i) / float(dots)
		draw_circle(p + Vector2(cos(a), sin(a)) * r * 1.09, h * 0.0022, _gold_dim)
	_spade(p, r * 0.34, Color(_gold, 0.28))


func _side_circle(p: Vector2, r: float, h: float, font: Font, label: String) -> void:
	draw_circle(p, r, Color(0, 0, 0, 0.10))
	draw_arc(p, r, 0.0, TAU, 128, _gold, h * 0.0040, true)
	draw_arc(p, r * 0.84, 0.0, TAU, 128, _gold_dim, h * 0.0014, true)
	var c := Vector2(tex_size.x * 0.5, 0.0)
	var rel := p - c
	var ang := rad_to_deg(atan2(rel.y, rel.x))
	var size := int(h * (0.021 if label.length() > 6 else 0.030))
	_arc_text(label, font, size, rel.length() - r * 1.42, ang, _cream, h * 0.004)


## Draws `text` centred on `center_deg` along a circle around the dealer point,
## reading left-to-right for the seated player.
func _arc_text(text: String, font: Font, size: int, radius: float, center_deg: float, col: Color, spacing: float = 0.0) -> void:
	if font == null or text.is_empty():
		return
	var c := Vector2(tex_size.x * 0.5, 0.0)
	var advances: Array[float] = []
	var total := 0.0
	for i in text.length():
		var adv := font.get_char_size(text.unicode_at(i), size).x
		advances.append(adv)
		total += adv
	total += spacing * float(text.length() - 1)
	var cap := font.get_ascent(size) * 0.72
	var theta := deg_to_rad(center_deg) + total / radius * 0.5
	var acc := 0.0
	for i in text.length():
		var adv := advances[i]
		var th := theta - (acc + adv * 0.5) / radius
		var pos := c + Vector2(cos(th), sin(th)) * radius
		draw_set_transform(pos, th - PI * 0.5, Vector2.ONE)
		draw_char(font, Vector2(-adv * 0.5, cap * 0.5), text[i], size, col)
		acc += adv + spacing
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _spade(p: Vector2, s: float, col: Color) -> void:
	# Heart-like body from two circles and a point, plus a flared stem.
	draw_circle(p + Vector2(-0.30 * s, 0.10 * s), 0.34 * s, col)
	draw_circle(p + Vector2(0.30 * s, 0.10 * s), 0.34 * s, col)
	draw_colored_polygon(PackedVector2Array([
		p + Vector2(-0.62 * s, 0.02 * s), p + Vector2(0, -0.95 * s), p + Vector2(0.62 * s, 0.02 * s), p + Vector2(0, 0.30 * s)
	]), col)
	draw_colored_polygon(PackedVector2Array([
		p + Vector2(0, 0.20 * s), p + Vector2(0.24 * s, 0.78 * s), p + Vector2(-0.24 * s, 0.78 * s)
	]), col)
