extends Control
## Table rules editor with presets and a live house-edge estimate. Rules are saved
## to SettingsStore and take effect at the next deal.

const ThemeFactory = preload("res://scripts/ui/theme_factory.gd")
const BJRules = preload("res://scripts/engine/bj_rules.gd")
const BJSideBets = preload("res://scripts/engine/bj_side_bets.gd")

var overlay
var _rules: BJRules = BJRules.new()
var _controls: Dictionary = {}
var _edge: Label
var _summary: Label
var _preset_buttons: Dictionary = {}
var _syncing := false
var _pen_label: Label


func build(p_overlay) -> void:
	overlay = p_overlay
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var f: Dictionary = overlay.frame("Table Rules", "Choose the game you want to play. The felt, the strategy chart and the coach all follow these rules. Changes take effect on the next deal; changing decks or penetration brings a fresh shoe.", 980, 0)
	add_child(f["root"])
	var body: VBoxContainer = f["body"]
	var presets := HBoxContainer.new()
	presets.add_theme_constant_override("separation", 8)
	body.add_child(presets)
	presets.add_child(ThemeFactory.label("PRESETS", "Subheading"))
	for key in BJRules.PRESETS:
		var b := ThemeFactory.button(str(BJRules.PRESETS[key]["title"]), "", 0, 40)
		b.toggle_mode = true
		b.pressed.connect(func() -> void:
			AudioManager.play("ui_click")
			var side := _rules.side_bets
			_rules.apply_preset(key)
			_rules.side_bets = side
			_sync()
		)
		presets.add_child(b)
		_preset_buttons[key] = b
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 36)
	body.add_child(cols)
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 6)
	cols.add_child(left)
	var right := VBoxContainer.new()
	right.custom_minimum_size = Vector2(300, 0)
	right.add_theme_constant_override("separation", 6)
	cols.add_child(right)
	_option(left, "decks", "Decks in the shoe", [["1 deck", 1], ["2 decks", 2], ["4 decks", 4], ["6 decks", 6], ["8 decks", 8]])
	_option(left, "dealer_hits_soft_17", "Dealer on soft 17", [["Stands (S17)", false], ["Hits (H17)", true]])
	_option(left, "blackjack_pays_6_5", "Blackjack pays", [["3 to 2", false], ["6 to 5", true]])
	_option(left, "max_hands", "Split up to", [["2 hands", 2], ["3 hands", 3], ["4 hands", 4]])
	_toggle(left, "double_after_split", "Double after split")
	_toggle(left, "resplit_aces", "Re-split aces")
	_toggle(left, "late_surrender", "Late surrender")
	_toggle(left, "side_bets", "Side bets (Perfect Pairs, 21+3)")
	var pen_row := HBoxContainer.new()
	left.add_child(pen_row)
	var pl := ThemeFactory.label("Shoe penetration", "Body")
	pl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pen_row.add_child(pl)
	var s := HSlider.new()
	s.min_value = BJRules.PENETRATION_MIN
	s.max_value = BJRules.PENETRATION_MAX
	s.step = 0.01
	s.custom_minimum_size = Vector2(220, 30)
	s.value_changed.connect(func(v: float) -> void:
		_pen_label.text = "%d%%" % int(round(v * 100.0))
		if _syncing:
			return
		_rules.penetration = v
		_sync()
	)
	pen_row.add_child(s)
	_pen_label = ThemeFactory.label("", "Muted")
	_pen_label.custom_minimum_size = Vector2(56, 0)
	pen_row.add_child(_pen_label)
	_controls["penetration"] = s
	var card := PanelContainer.new()
	card.theme_type_variation = "Card"
	right.add_child(card)
	var cv := VBoxContainer.new()
	card.add_child(cv)
	cv.add_child(ThemeFactory.label("HOUSE EDGE", "Subheading"))
	_edge = ThemeFactory.label("", "Value")
	cv.add_child(_edge)
	var en := ThemeFactory.label("Main bet, perfect basic strategy. An estimate from standard rule-effect figures.", "Muted")
	en.add_theme_font_size_override("font_size", 13)
	en.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	en.custom_minimum_size = Vector2(260, 0)
	cv.add_child(en)
	cv.add_child(ThemeFactory.hsep())
	_summary = ThemeFactory.label("", "Body")
	_summary.add_theme_font_size_override("font_size", 14)
	_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_summary.custom_minimum_size = Vector2(260, 0)
	cv.add_child(_summary)
	var footer: HBoxContainer = f["footer"]
	overlay.add_button(footer, "REVERT", func() -> void: refresh(), "", 150)
	footer.add_child(ThemeFactory.expander())
	overlay.back_button(footer)
	overlay.add_button(footer, "APPLY RULES", func() -> void:
		SettingsStore.set_rules(_rules)
		overlay.back()
	, "PrimaryButton", 200)


func refresh() -> void:
	_rules = SettingsStore.rules.duplicate_rules()
	_sync()


func _sync() -> void:
	_syncing = true
	var d := _rules.to_dict()
	for key in _controls:
		var c = _controls[key]
		if c is OptionButton:
			for i in c.item_count:
				if c.get_item_metadata(i) == d[key]:
					c.select(i)
		elif c is CheckButton:
			c.button_pressed = bool(d[key])
		elif c is HSlider:
			c.value = float(d[key])
	_syncing = false
	var edge := _rules.house_edge_percent()
	_edge.text = "≈ %.2f%%" % edge
	_edge.add_theme_color_override("font_color", ThemeFactory.GOOD if edge < 0.45 else (ThemeFactory.BAD if edge > 1.0 else ThemeFactory.CREAM))
	var lines: PackedStringArray = PackedStringArray()
	lines.append(_rules.summary().replace("  ·  ", " · "))
	if _rules.blackjack_pays_6_5:
		lines.append("6:5 blackjack costs the player about 1.4% — avoid it at real tables.")
	if _rules.side_bets:
		lines.append("Side bets at %d deck%s: Perfect Pairs %.2f%%, 21+3 %.2f%% house edge." % [
			_rules.decks, "" if _rules.decks == 1 else "s",
			BJSideBets.house_edge("pp", _rules.decks), BJSideBets.house_edge("t3", _rules.decks)])
	_summary.text = "\n\n".join(lines)
	var match_key := _rules.matching_preset()
	for key in _preset_buttons:
		(_preset_buttons[key] as Button).set_pressed_no_signal(key == match_key)


func _option(box: VBoxContainer, key: String, title: String, items: Array) -> void:
	var row := HBoxContainer.new()
	box.add_child(row)
	var l := ThemeFactory.label(title, "Body")
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(l)
	var o := OptionButton.new()
	o.custom_minimum_size = Vector2(220, 40)
	for it in items:
		o.add_item(str(it[0]))
		o.set_item_metadata(o.item_count - 1, it[1])
	o.item_selected.connect(func(i: int) -> void:
		if _syncing:
			return
		AudioManager.play("ui_click")
		var d := _rules.to_dict()
		d[key] = o.get_item_metadata(i)
		_rules.from_dict(d)
		_sync()
	)
	row.add_child(o)
	_controls[key] = o


func _toggle(box: VBoxContainer, key: String, title: String) -> void:
	var t := CheckButton.new()
	t.text = title
	t.toggled.connect(func(v: bool) -> void:
		if _syncing:
			return
		AudioManager.play("ui_click")
		var d := _rules.to_dict()
		d[key] = v
		_rules.from_dict(d)
		_sync()
	)
	box.add_child(t)
	_controls[key] = t
