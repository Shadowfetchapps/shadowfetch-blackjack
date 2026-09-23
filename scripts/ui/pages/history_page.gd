extends Control
## The most recent rounds, newest first: cards, decisions, dealer hand, side bets
## and the net result.

const ThemeFactory = preload("res://scripts/ui/theme_factory.gd")
const BJMoney = preload("res://scripts/engine/bj_money.gd")
const BJSideBets = preload("res://scripts/engine/bj_side_bets.gd")

const ACTION_WORDS := {"H": "hit", "S": "stand", "D": "double", "P": "split", "R": "surrender"}
const SUITS := {"S": "♠", "H": "♥", "D": "♦", "C": "♣"}

var overlay
var _list: VBoxContainer
var _empty: Label


func build(p_overlay) -> void:
	overlay = p_overlay
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var f: Dictionary = overlay.frame("Hand History", "Your last %d rounds, newest first." % StatsStore.HISTORY_LIMIT, 1040, 760)
	add_child(f["root"])
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	(f["body"] as VBoxContainer).add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 8)
	scroll.add_child(_list)
	_empty = ThemeFactory.label("No hands yet. Take a seat and deal.", "Muted")
	(f["body"] as VBoxContainer).add_child(_empty)
	overlay.back_button(f["footer"])


func refresh() -> void:
	for c in _list.get_children():
		c.queue_free()
	var rounds: Array = StatsStore.history.duplicate()
	rounds.reverse()
	_empty.visible = rounds.is_empty()
	for rec in rounds:
		_list.add_child(_row(rec))


func _row(rec: Dictionary) -> Control:
	var card := PanelContainer.new()
	card.theme_type_variation = "Card"
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	card.add_child(row)
	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(90, 0)
	left.add_theme_constant_override("separation", 0)
	row.add_child(left)
	left.add_child(ThemeFactory.label("#%d" % int(rec.get("id", rec.get("round", 0))), "ValueSmall"))
	var t := Time.get_datetime_dict_from_unix_time(int(rec.get("time", 0)) + _tz_offset())
	var when := ThemeFactory.label("%02d:%02d" % [t["hour"], t["minute"]], "Muted")
	when.add_theme_font_size_override("font_size", 13)
	left.add_child(when)
	var rt := RichTextLabel.new()
	rt.bbcode_enabled = true
	rt.fit_content = true
	rt.scroll_active = false
	rt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rt.text = _describe(rec)
	row.add_child(rt)
	var net := int(rec.get("net", 0))
	var amt := ThemeFactory.label(BJMoney.format_signed_short(net) if net != 0 else "push", "ValueSmall")
	amt.custom_minimum_size = Vector2(130, 0)
	amt.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	amt.add_theme_color_override("font_color", ThemeFactory.money_color(net))
	row.add_child(amt)
	return card


func _describe(rec: Dictionary) -> String:
	var lines: PackedStringArray = PackedStringArray()
	var hands: Array = rec.get("hands", [])
	for i in hands.size():
		var h: Dictionary = hands[i]
		var label := "You" if hands.size() == 1 else "Hand %d" % (i + 1)
		var acts := PackedStringArray()
		for ch in str(h.get("actions", "")):
			if ACTION_WORDS.has(ch):
				acts.append(ACTION_WORDS[ch])
		var act_text := ("  ·  " + ", ".join(acts)) if not acts.is_empty() else ""
		lines.append("[color=#a8a295]%s[/color]  %s  [b]%s[/b]%s  [color=%s]%s[/color]" % [
			label, _cards(h.get("cards", [])), str(h.get("text", "")), act_text, _outcome_color(str(h.get("outcome", ""))), _outcome_word(str(h.get("outcome", "")))
		])
	var dealer: Dictionary = rec.get("dealer", {})
	lines.append("[color=#a8a295]Dealer[/color]  %s  [b]%s[/b]" % [_cards(dealer.get("cards", [])), str(dealer.get("text", ""))])
	var extras := PackedStringArray()
	for s in rec.get("side", []):
		var won: bool = int(s.get("payout", 0)) > 0
		extras.append("%s %s" % [BJSideBets.title(str(s.get("kind", ""))), ("%s %s" % [BJSideBets.result_title(str(s.get("result", ""))), BJMoney.format_signed_short(int(s.get("net", 0)))]) if won else "lost"])
	if int(rec.get("insurance", 0)) > 0:
		extras.append("Insurance %s" % ("won" if int(rec.get("insurance_payout", 0)) > 0 else "lost"))
	if bool(rec.get("even_money", false)):
		extras.append("Even money taken")
	var d := int(rec.get("decisions", 0))
	if d > 0:
		extras.append("Strategy %d/%d" % [int(rec.get("correct", 0)), d])
	extras.append(str(rec.get("rules", "")))
	lines.append("[color=#7d786f][font_size=14]%s[/font_size][/color]" % "   ·   ".join(extras))
	return "\n".join(lines)


func _cards(keys: Array) -> String:
	var out := PackedStringArray()
	for k in keys:
		var key := str(k)
		var suit := key.substr(key.length() - 1)
		var rank := key.substr(0, key.length() - 1)
		var col := "#efe9dc"
		match suit:
			"H":
				col = "#f06a62"
			"D":
				col = "#6aa6ff" if SettingsStore.four_color else "#f06a62"
			"C":
				col = "#63c784" if SettingsStore.four_color else "#efe9dc"
		out.append("[color=%s]%s%s[/color]" % [col, rank, SUITS.get(suit, "")])
	return " ".join(out)


func _outcome_word(o: String) -> String:
	match o:
		"win":
			return "WIN"
		"blackjack":
			return "BLACKJACK"
		"even_money":
			return "EVEN MONEY"
		"push":
			return "PUSH"
		"lose":
			return "LOSE"
		"bust":
			return "BUST"
		"surrender":
			return "SURRENDER"
	return o.to_upper()


func _outcome_color(o: String) -> String:
	match o:
		"win", "blackjack", "even_money":
			return "#73d992"
		"push":
			return "#a8a295"
	return "#f06a62"


func _tz_offset() -> int:
	var tz := Time.get_time_zone_from_system()
	return int(tz.get("bias", 0)) * 60
