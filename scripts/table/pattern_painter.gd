class_name PatternPainter
extends Node2D
## Procedural room textures (baked once): patterned carpet, deco wallpaper, and
## two abstract art-deco canvases for the frames on the back wall.

var kind := "carpet"
var tex_size := Vector2i(1024, 1024)


func _draw() -> void:
	match kind:
		"carpet":
			_carpet()
		"wallpaper":
			_wallpaper()
		"art_fan":
			_art_fan()
		"art_lines":
			_art_lines()
		"sign":
			_sign()
		"placard":
			_placard()


func _carpet() -> void:
	var s := Vector2(tex_size)
	draw_rect(Rect2(Vector2.ZERO, s), Color(0.075, 0.028, 0.030))
	var cell := s.x / 4.0
	var gold := Color(0.55, 0.40, 0.18, 0.55)
	var wine := Color(0.14, 0.04, 0.05)
	for y in 5:
		for x in 5:
			var c := Vector2(x * cell, y * cell)
			var d := PackedVector2Array([c + Vector2(0, -cell * 0.46), c + Vector2(cell * 0.46, 0), c + Vector2(0, cell * 0.46), c + Vector2(-cell * 0.46, 0)])
			draw_colored_polygon(d, wine)
			d.append(d[0])
			draw_polyline(d, gold, 3.0, true)
			draw_circle(c, cell * 0.07, gold)
			var h := c + Vector2(cell * 0.5, cell * 0.5)
			for k in 4:
				var a := PI * 0.5 * k
				draw_line(h + Vector2(cos(a), sin(a)) * cell * 0.08, h + Vector2(cos(a), sin(a)) * cell * 0.2, Color(gold, 0.35), 2.0, true)


func _wallpaper() -> void:
	var s := Vector2(tex_size)
	draw_rect(Rect2(Vector2.ZERO, s), Color(0.030, 0.052, 0.042))
	var line := Color(0.62, 0.48, 0.22, 0.32)
	var cols := 4
	var w := s.x / cols
	for r in 5:
		for c in cols + 1:
			var base := Vector2(c * w + (w * 0.5 if r % 2 else 0.0), r * w * 0.5)
			for k in 6:
				var rad := w * (0.48 - k * 0.075)
				if rad > 2.0:
					draw_arc(base, rad, PI, TAU, 48, line, 2.0, true)
			for k in 7:
				var a := PI + PI * float(k) / 6.0
				draw_line(base, base + Vector2(cos(a), sin(a)) * w * 0.48, Color(line, 0.18), 1.5, true)


func _art_fan() -> void:
	var s := Vector2(tex_size)
	draw_rect(Rect2(Vector2.ZERO, s), Color(0.035, 0.035, 0.04))
	var gold := Color(0.86, 0.68, 0.32)
	var c := Vector2(s.x * 0.5, s.y * 0.78)
	for k in 9:
		var rad := s.x * (0.46 - k * 0.045)
		draw_arc(c, rad, PI * 1.02, TAU * 0.99, 96, Color(gold, 0.9 - k * 0.08), 4.0, true)
	for k in 13:
		var a := PI + PI * float(k) / 12.0
		draw_line(c, c + Vector2(cos(a), sin(a)) * s.x * 0.46, Color(gold, 0.35), 2.0, true)
	draw_circle(c, s.x * 0.05, Color(0.10, 0.36, 0.24))
	draw_rect(Rect2(Vector2(s.x * 0.08, s.y * 0.84), Vector2(s.x * 0.84, 4)), gold)


func _art_lines() -> void:
	var s := Vector2(tex_size)
	draw_rect(Rect2(Vector2.ZERO, s), Color(0.035, 0.035, 0.04))
	var gold := Color(0.86, 0.68, 0.32)
	var green := Color(0.09, 0.32, 0.21)
	draw_rect(Rect2(Vector2(s.x * 0.2, s.y * 0.12), Vector2(s.x * 0.6, s.y * 0.76)), green)
	for k in 7:
		var x := s.x * (0.24 + k * 0.087)
		draw_line(Vector2(x, s.y * 0.16), Vector2(x, s.y * 0.84), Color(gold, 0.7), 3.0, true)
	draw_circle(Vector2(s.x * 0.5, s.y * 0.38), s.x * 0.16, Color(0.035, 0.035, 0.04))
	draw_arc(Vector2(s.x * 0.5, s.y * 0.38), s.x * 0.16, 0, TAU, 96, gold, 5.0, true)
	draw_arc(Vector2(s.x * 0.5, s.y * 0.38), s.x * 0.11, 0, TAU, 96, Color(gold, 0.5), 3.0, true)


func _sign() -> void:
	var s := Vector2(tex_size)
	draw_rect(Rect2(Vector2.ZERO, s), Color(0, 0, 0, 1))
	var font := preload("res://scripts/ui/fonts.gd").display("bold")
	var size := int(s.y * 0.55)
	var text := "SHADOWFETCH"
	var tw := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var spacing := s.y * 0.06
	var total := tw + spacing * (text.length() - 1)
	var x := (s.x - total) * 0.5
	for i in text.length():
		draw_char(font, Vector2(x, s.y * 0.72), text[i], size, Color(1.0, 0.86, 0.55))
		x += font.get_char_size(text.unicode_at(i), size).x + spacing


func _placard() -> void:
	var s := Vector2(tex_size)
	draw_rect(Rect2(Vector2.ZERO, s), Color(0.03, 0.03, 0.035))
	var gold := Color(0.88, 0.72, 0.40)
	draw_rect(Rect2(Vector2(10, 10), s - Vector2(20, 20)), gold, false, 4.0)
	var fonts := preload("res://scripts/ui/fonts.gd")
	var ui := fonts.ui("semibold")
	var disp := fonts.display("bold")
	_center(ui, "TABLE LIMITS", s.y * 0.30, int(s.y * 0.13), Color(0.9, 0.86, 0.76))
	_center(disp, "$1 – $10,000", s.y * 0.62, int(s.y * 0.25), gold)
	_center(ui, "SIDE BETS TO $1,000", s.y * 0.86, int(s.y * 0.10), Color(0.9, 0.86, 0.76, 0.8))


func _center(font: Font, text: String, y: float, size: int, col: Color) -> void:
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	draw_string(font, Vector2((tex_size.x - w) * 0.5, y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)
