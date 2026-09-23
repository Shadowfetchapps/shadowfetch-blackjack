extends Control
## Lifetime statistics, strategy accuracy and a chart of this session's bankroll.

const ThemeFactory = preload("res://scripts/ui/theme_factory.gd")
const BJMoney = preload("res://scripts/engine/bj_money.gd")

var overlay
var _grid: GridContainer
var _chart: Control


func build(p_overlay) -> void:
	overlay = p_overlay
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var f: Dictionary = overlay.frame("Statistics", "", 1120, 0)
	add_child(f["root"])
	var body: VBoxContainer = f["body"]
	var chart_card := PanelContainer.new()
	chart_card.theme_type_variation = "Card"
	body.add_child(chart_card)
	var cv := VBoxContainer.new()
	chart_card.add_child(cv)
	cv.add_child(ThemeFactory.label("THIS SESSION'S BANKROLL", "Subheading"))
	_chart = TrailChart.new()
	_chart.custom_minimum_size = Vector2(1040, 170)
	cv.add_child(_chart)
	_grid = GridContainer.new()
	_grid.columns = 4
	_grid.add_theme_constant_override("h_separation", 10)
	_grid.add_theme_constant_override("v_separation", 10)
	body.add_child(_grid)
	var footer: HBoxContainer = f["footer"]
	overlay.add_button(footer, "RESET STATISTICS", func() -> void:
		overlay.confirm("Reset all statistics?", "Lifetime totals, hand history and achievements are erased and your bankroll returns to $10,000. This cannot be undone.", "RESET", func() -> void:
			StatsStore.reset_all()
			Achievements.reset()
			overlay.main_menu.emit()
		)
	, "DangerButton", 220)
	footer.add_child(ThemeFactory.expander())
	overlay.back_button(footer)


func refresh() -> void:
	for c in _grid.get_children():
		c.queue_free()
	var s = StatsStore
	var tiles := [
		["BANKROLL", BJMoney.format_short(s.bankroll_cents), ThemeFactory.CREAM],
		["LIFETIME RESULT", BJMoney.format_signed_short(s.lifetime_profit_cents), ThemeFactory.money_color(s.lifetime_profit_cents)],
		["HANDS PLAYED", _n(s.hands), ThemeFactory.CREAM],
		["WIN RATE", "%.1f%%" % s.win_percent(), ThemeFactory.CREAM],
		["WINS · LOSSES · PUSHES", "%s · %s · %s" % [_n(s.wins), _n(s.losses), _n(s.pushes)], ThemeFactory.CREAM],
		["BLACKJACKS", _n(s.blackjacks), ThemeFactory.GOLD_BRIGHT],
		["BEST WIN STREAK", _n(s.best_streak), ThemeFactory.CREAM],
		["LARGEST ROUND WIN", BJMoney.format_short(s.largest_win_cents), ThemeFactory.GOOD],
		["TOTAL WAGERED", BJMoney.format_compact(s.total_wagered_cents), ThemeFactory.CREAM],
		["DOUBLES WON", "%s / %s" % [_n(s.doubles_won), _n(s.doubles)], ThemeFactory.CREAM],
		["SPLITS · SURRENDERS", "%s · %s" % [_n(s.splits), _n(s.surrenders)], ThemeFactory.CREAM],
		["INSURANCE WON", "%s / %s" % [_n(s.insurance_won), _n(s.insurance_taken)], ThemeFactory.CREAM],
		["SIDE BETS WON", "%s / %s" % [_n(s.side_bets_won), _n(s.side_bets_placed)], ThemeFactory.CREAM],
		["SIDE BET RESULT", BJMoney.format_signed_short(s.side_net_cents), ThemeFactory.money_color(s.side_net_cents)],
		["STRATEGY ACCURACY", "%.1f%%" % s.strategy_accuracy() if s.decisions > 0 else "—", ThemeFactory.GOLD_BRIGHT],
		["BEST BY-THE-BOOK RUN", _n(s.best_strategy_run), ThemeFactory.CREAM],
	]
	for t in tiles:
		var card := PanelContainer.new()
		card.theme_type_variation = "Card"
		card.custom_minimum_size = Vector2(254, 0)
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 0)
		card.add_child(v)
		var h := ThemeFactory.label(t[0], "Subheading")
		h.add_theme_font_size_override("font_size", 11)
		v.add_child(h)
		var val := ThemeFactory.label(t[1], "ValueSmall")
		val.add_theme_color_override("font_color", t[2])
		v.add_child(val)
		_grid.add_child(card)
	_chart.values = StatsStore.trail.duplicate()
	_chart.queue_redraw()


func _n(v: int) -> String:
	var s := str(v)
	var out := ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return s + out


class TrailChart:
	extends Control
	var values: Array = []

	func _draw() -> void:
		var gold := Color(0.87, 0.72, 0.42)
		var font := get_theme_default_font()
		if values.size() < 2:
			draw_string(font, Vector2(8, size.y * 0.55), "Play a few hands to see your bankroll over the session.", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0.68, 0.65, 0.59))
			return
		var lo := float(values.min())
		var hi := float(values.max())
		var start := float(values[0])
		lo = minf(lo, start)
		hi = maxf(hi, start)
		if hi - lo < 1.0:
			hi += 100.0
			lo -= 100.0
		var pad := (hi - lo) * 0.12
		lo -= pad
		hi += pad
		var left := 70.0
		var w := size.x - left - 8.0
		var h := size.y - 16.0
		var pts := PackedVector2Array()
		for i in values.size():
			var x := left + w * float(i) / float(values.size() - 1)
			var y := 8.0 + h * (1.0 - (float(values[i]) - lo) / (hi - lo))
			pts.append(Vector2(x, y))
		var base_y := 8.0 + h * (1.0 - (start - lo) / (hi - lo))
		draw_line(Vector2(left, base_y), Vector2(size.x - 8, base_y), Color(1, 1, 1, 0.18), 1.0)
		for k in 3:
			var val := lo + (hi - lo) * float(k) / 2.0
			var y := 8.0 + h * (1.0 - float(k) / 2.0)
			draw_string(font, Vector2(0, y + 5), "$%s" % _short(val / 100.0), HORIZONTAL_ALIGNMENT_LEFT, left - 8, 12, Color(0.55, 0.53, 0.5))
		var fill := PackedVector2Array(pts)
		fill.append(Vector2(pts[pts.size() - 1].x, 8.0 + h))
		fill.append(Vector2(left, 8.0 + h))
		draw_colored_polygon(fill, Color(gold, 0.10))
		draw_polyline(pts, gold, 2.5, true)
		var last := pts[pts.size() - 1]
		var up := float(values.back()) >= start
		draw_circle(last, 5.0, Color(0.45, 0.85, 0.58) if up else Color(0.94, 0.42, 0.38))

	func _short(v: float) -> String:
		if absf(v) >= 1000000.0:
			return "%.1fM" % (v / 1000000.0)
		if absf(v) >= 1000.0:
			return "%.1fK" % (v / 1000.0)
		return "%d" % int(v)
