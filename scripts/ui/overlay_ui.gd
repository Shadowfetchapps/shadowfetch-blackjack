class_name OverlayUI
extends CanvasLayer
## Full-screen menus with a navigation stack: main menu, pause, settings, table rules,
## strategy chart, statistics, history, achievements, how-to-play and dialogs.

const ThemeFactory = preload("res://scripts/ui/theme_factory.gd")
const BJMoney = preload("res://scripts/engine/bj_money.gd")
const SettingsPage = preload("res://scripts/ui/pages/settings_page.gd")
const RulesPage = preload("res://scripts/ui/pages/rules_page.gd")
const StatsPage = preload("res://scripts/ui/pages/stats_page.gd")
const HistoryPage = preload("res://scripts/ui/pages/history_page.gd")
const AchievementsPage = preload("res://scripts/ui/pages/achievements_page.gd")
const ChartPage = preload("res://scripts/ui/pages/chart_page.gd")

signal play
signal resume
signal restart_session
signal main_menu
signal quit_game
signal rebuy
signal settings_changed
signal appearance_changed
signal replay_tutorial
signal page_changed(name: String)

var _root: Control
var _dim: ColorRect
var _pages: Dictionary = {}
var _stack: Array[String] = []
var current: String = ""
var engine
var _play_button: Button
var _menu_bankroll: Label


func build() -> void:
	layer = 20
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.theme = ThemeFactory.theme()
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	_dim = ColorRect.new()
	_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dim.color = Color(0, 0, 0, 0.55)
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_dim.visible = false
	_root.add_child(_dim)
	_add_page("main", _make_main())
	_add_page("pause", _make_pause())
	_add_page("howto", _make_howto())
	_add_page("broke", _make_broke())
	var settings := SettingsPage.new()
	settings.build(self)
	_add_page("settings", settings)
	var rules := RulesPage.new()
	rules.build(self)
	_add_page("rules", rules)
	var stats := StatsPage.new()
	stats.build(self)
	_add_page("stats", stats)
	var history := HistoryPage.new()
	history.build(self)
	_add_page("history", history)
	var ach := AchievementsPage.new()
	ach.build(self)
	_add_page("achievements", ach)
	var chart := ChartPage.new()
	chart.build(self)
	_add_page("chart", chart)
	hide_all()


func _add_page(name: String, page: Control) -> void:
	page.visible = false
	_root.add_child(page)
	_pages[name] = page


# --- navigation -------------------------------------------------------------

func visible_page() -> bool:
	return not current.is_empty()


func show_page(name: String, push: bool = true) -> void:
	if not _pages.has(name):
		return
	if push and not current.is_empty() and current != name:
		_stack.append(current)
	elif not push:
		_stack.clear()
	current = name
	_dim.visible = name != "main"
	for k in _pages:
		_pages[k].visible = k == name
	var page: Control = _pages[name]
	if page.has_method("refresh"):
		page.refresh()
	if name == "main":
		_refresh_main()
	page.modulate.a = 0.0
	page.create_tween().tween_property(page, "modulate:a", 1.0, 0.18)
	_focus_first(page)
	page_changed.emit(name)


## Esc / B: go back one page, or close the overlay from the top level.
func back() -> bool:
	if current.is_empty():
		return false
	if current == "main" or current == "broke":
		return true
	AudioManager.play("ui_back")
	if _stack.is_empty():
		if current == "pause":
			resume.emit()
		else:
			hide_all()
			resume.emit()
		return true
	var prev: String = _stack.pop_back()
	var rest := _stack.duplicate()
	show_page(prev, false)
	_stack = rest
	return true


func hide_all() -> void:
	current = ""
	_stack.clear()
	_dim.visible = false
	for k in _pages:
		_pages[k].visible = false
	page_changed.emit("")


func _focus_first(node: Node) -> void:
	var b := _find_focusable(node)
	if b:
		b.grab_focus.call_deferred()


func _find_focusable(node: Node) -> Control:
	for c in node.get_children():
		if c is BaseButton and (c as Control).visible and not (c as BaseButton).disabled and (c as Control).focus_mode != Control.FOCUS_NONE:
			return c
		var inner := _find_focusable(c)
		if inner:
			return inner
	return null


# --- shared frame -----------------------------------------------------------

## A centred panel page. Returns { root, body, footer, title }.
func frame(title: String, subtitle: String = "", width: float = 760.0, height: float = 0.0) -> Dictionary:
	var wrap := Control.new()
	wrap.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrap.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(width, height)
	center.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	panel.add_child(v)
	var t := ThemeFactory.label(title, "Heading")
	v.add_child(t)
	var s := ThemeFactory.label(subtitle, "Muted")
	s.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	s.custom_minimum_size = Vector2(width - 60.0, 0)
	s.visible = not subtitle.is_empty()
	v.add_child(s)
	v.add_child(ThemeFactory.hsep())
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 10)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(body)
	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 10)
	footer.alignment = BoxContainer.ALIGNMENT_END
	v.add_child(footer)
	return {"root": wrap, "body": body, "footer": footer, "title": t, "subtitle": s, "panel": panel}


func add_button(box: Container, text: String, cb: Callable, variation: String = "", min_w: int = 200) -> Button:
	var b := ThemeFactory.button(text, variation, min_w, 48)
	b.pressed.connect(func() -> void:
		AudioManager.play("ui_click")
		cb.call()
	)
	box.add_child(b)
	return b


func back_button(box: Container) -> Button:
	return add_button(box, "BACK", func() -> void: back(), "", 160)


# --- main menu --------------------------------------------------------------

func _make_main() -> Control:
	var wrap := Control.new()
	wrap.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shade := TextureRect.new()
	var grad := Gradient.new()
	grad.set_color(0, Color(0, 0, 0, 0.92))
	grad.set_color(1, Color(0, 0, 0, 0.0))
	grad.add_point(0.55, Color(0, 0, 0, 0.7))
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.width = 256
	gt.height = 4
	shade.texture = gt
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	shade.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	shade.offset_right = 1100
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrap.add_child(shade)
	var col := VBoxContainer.new()
	col.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	col.offset_left = 120
	col.offset_right = 760
	col.offset_top = 110
	col.offset_bottom = -70
	col.add_theme_constant_override("separation", 4)
	wrap.add_child(col)
	col.add_child(ThemeFactory.label("SHADOWFETCH", "Caps"))
	var title := ThemeFactory.label("Blackjack", "Title")
	title.add_theme_font_size_override("font_size", 104)
	title.add_theme_color_override("font_color", ThemeFactory.CREAM)
	col.add_child(title)
	var tag := ThemeFactory.label("A private card room  ·  fictional chips only", "Muted")
	tag.add_theme_font_size_override("font_size", 19)
	col.add_child(tag)
	col.add_child(ThemeFactory.spacer(34))
	_play_button = _menu_item(col, "Play", func() -> void: play.emit())
	_menu_item(col, "Table Rules", func() -> void: show_page("rules"))
	_menu_item(col, "Strategy Chart", func() -> void: show_page("chart"))
	_menu_item(col, "Statistics", func() -> void: show_page("stats"))
	_menu_item(col, "Hand History", func() -> void: show_page("history"))
	_menu_item(col, "Achievements", func() -> void: show_page("achievements"))
	_menu_item(col, "Settings", func() -> void: show_page("settings"))
	_menu_item(col, "How to Play", func() -> void: show_page("howto"))
	_menu_item(col, "Quit", func() -> void: quit_game.emit())
	col.add_child(ThemeFactory.expander())
	_menu_bankroll = ThemeFactory.label("", "Muted")
	col.add_child(_menu_bankroll)
	var ver := ThemeFactory.label("Version %s  ·  Play money only — not a gambling service" % ProjectSettings.get_setting("application/config/version", "3"), "Muted")
	ver.add_theme_font_size_override("font_size", 13)
	ver.add_theme_color_override("font_color", ThemeFactory.DIM)
	col.add_child(ver)
	return wrap


func _menu_item(col: VBoxContainer, text: String, cb: Callable) -> Button:
	var b := ThemeFactory.button(text, "GhostButton", 360, 52)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	b.pressed.connect(func() -> void:
		AudioManager.play("ui_click")
		cb.call()
	)
	col.add_child(b)
	return b


func _refresh_main() -> void:
	if engine:
		var in_round: bool = engine.phase != 0
		_play_button.text = "Continue" if in_round or engine.hands_played > 0 else "Play"
		_menu_bankroll.text = "Bankroll  %s   ·   %d achievements of %d" % [BJMoney.format_cents(engine.bankroll_cents), Achievements.unlocked_count(), Achievements.total()]


# --- pause ------------------------------------------------------------------

func _make_pause() -> Control:
	var f := frame("Paused", "The table waits for you.", 520)
	var body: VBoxContainer = f["body"]
	add_button(body, "RESUME", func() -> void: resume.emit(), "PrimaryButton")
	add_button(body, "TABLE RULES", func() -> void: show_page("rules"))
	add_button(body, "STRATEGY CHART", func() -> void: show_page("chart"))
	add_button(body, "STATISTICS", func() -> void: show_page("stats"))
	add_button(body, "HAND HISTORY", func() -> void: show_page("history"))
	add_button(body, "SETTINGS", func() -> void: show_page("settings"))
	add_button(body, "HOW TO PLAY", func() -> void: show_page("howto"))
	body.add_child(ThemeFactory.hsep())
	add_button(body, "RESTART SESSION", func() -> void:
		confirm("Restart session?", "Your bankroll returns to $10,000 in fictional chips. Lifetime statistics and achievements are kept.", "RESTART", func() -> void: restart_session.emit())
	)
	add_button(body, "MAIN MENU", func() -> void: main_menu.emit())
	add_button(body, "QUIT TO DESKTOP", func() -> void: quit_game.emit(), "DangerButton")
	return f["root"]


# --- dialogs ----------------------------------------------------------------

func confirm(title: String, text: String, ok_label: String, on_ok: Callable) -> void:
	if _pages.has("confirm"):
		(_pages["confirm"] as Node).queue_free()
		_pages.erase("confirm")
	var f := frame(title, "", 560)
	var l := ThemeFactory.label(text, "Body")
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(500, 0)
	(f["body"] as VBoxContainer).add_child(l)
	var footer: HBoxContainer = f["footer"]
	add_button(footer, "CANCEL", func() -> void: back(), "", 150)
	add_button(footer, ok_label, func() -> void:
		back()
		on_ok.call()
	, "DangerButton", 170)
	_add_page("confirm", f["root"])
	show_page("confirm")


func _make_broke() -> Control:
	var f := frame("Out of chips", "", 560)
	var l := ThemeFactory.label("The house extends a fresh $10,000 marker in fictional chips. Nothing real was ever at stake — take a breath, then play on.", "Body")
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(500, 0)
	(f["body"] as VBoxContainer).add_child(l)
	var footer: HBoxContainer = f["footer"]
	add_button(footer, "MAIN MENU", func() -> void: main_menu.emit(), "", 160)
	add_button(footer, "REBUY $10,000", func() -> void: rebuy.emit(), "PrimaryButton", 210)
	return f["root"]


# --- how to play ------------------------------------------------------------

func _make_howto() -> Control:
	var f := frame("How to Play", "", 980, 760)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	(f["body"] as VBoxContainer).add_child(scroll)
	var rt := RichTextLabel.new()
	rt.bbcode_enabled = true
	rt.fit_content = true
	rt.scroll_active = false
	rt.custom_minimum_size = Vector2(900, 0)
	rt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rt.text = _howto_text()
	scroll.add_child(rt)
	back_button(f["footer"])
	return f["root"]


func _howto_text() -> String:
	var g := "#dcb86b"
	var h := "[font_size=24][color=%s]%s[/color][/font_size]\n"
	var s := ""
	s += h % [g, "The goal"]
	s += "Finish closer to 21 than the dealer without going over. Aces count 1 or 11, face cards 10, everything else its number. All chips are fictional — there is no cash-out.\n\n"
	s += h % [g, "Betting"]
	s += "Pick a chip in the rack (or press [b]1–6[/b]) to add it to your main bet, or click a betting circle on the felt to place the selected chip there. Right-click a circle to take the last chip back. [b]Z[/b] undoes, [b]X[/b] clears, [b]R[/b] repeats your last bet and deals. Table limits are $1–$10,000 on the main bet and up to $1,000 on each side bet.\n\n"
	s += h % [g, "Your options"]
	s += "[b]Hit (H)[/b] take a card.   [b]Stand (S)[/b] keep your total.   [b]Double (D)[/b] double the bet, take exactly one card.   [b]Split (P)[/b] play a pair as two hands.   [b]Surrender (U)[/b] give up half the bet on your first two cards (when late surrender is on).\n"
	s += "Twenty-one stands automatically. Split aces get one card each (and can be split again only when the table allows re-splitting aces). A 21 made after a split is not a blackjack.\n\n"
	s += h % [g, "Payouts"]
	s += "Blackjack pays 3 to 2 (6 to 5 on tables that say so). Other wins pay even money. Ties push. The dealer checks for blackjack under an ace or ten before you act, so you only lose your original bet to a dealer blackjack.\n\n"
	s += h % [g, "Insurance and even money"]
	s += "When the dealer shows an ace you may insure for half your bet; it pays 2 to 1 if the dealer has blackjack. Holding a blackjack yourself, you are offered [b]even money[/b] instead: a guaranteed 1-to-1 win. Basic strategy declines both.\n\n"
	s += h % [g, "Side bets"]
	s += "[b]Perfect Pairs[/b] (your first two cards): perfect pair 25:1, coloured pair 12:1, mixed pair 6:1.\n"
	s += "[b]21+3[/b] (your two cards + the dealer's up-card as a poker hand): suited trips 100:1, straight flush 40:1, three of a kind 30:1, straight 10:1, flush 5:1. Side bets settle straight after the deal.\n\n"
	s += h % [g, "Table rules"]
	s += "Open [b]Table Rules[/b] to choose decks (1–8), dealer stands or hits soft 17, 3:2 or 6:5, double after split, re-split aces, split limit, late surrender, shoe penetration and side bets. The felt, the strategy chart and the house-edge estimate all follow your choices. Changes take effect on the next deal.\n\n"
	s += h % [g, "Strategy coach and counting trainer"]
	s += "[b]HINT (T)[/b] shows the basic-strategy play for the current rules. In [b]Settings → Gameplay[/b] the Coach can grade every decision; your accuracy is tracked in Statistics either way. Turn on the [b]count trainer[/b] to see the Hi-Lo running count and true count of every card you have seen since the shuffle.\n\n"
	s += h % [g, "Controls"]
	s += "[table=3][cell][b]Action[/b]   [/cell][cell][b]Keyboard[/b]   [/cell][cell][b]Gamepad[/b][/cell]"
	var rows := [
		["Deal / rebet & deal", "Space / R", "Y / X"], ["Add selected chip", "1–6 · click", "A"], ["Choose chip", "1–6", "LB / RB"],
		["Undo / clear", "Z / X", "B / Back"], ["Hit / stand", "H / S", "A / B"], ["Double / split", "D / P", "X / Y"],
		["Surrender / hint", "U / T", "LB / RB"], ["Insurance yes / no", "Y / N", "A / B"], ["Camera view", "C", "Back (in play)"],
		["Pause menu", "Esc", "Start"],
	]
	for r in rows:
		s += "[cell]%s   [/cell][cell]%s   [/cell][cell]%s[/cell]" % r
	s += "[/table]\n\n"
	s += h % [g, "Play responsibly"]
	s += "This is a video game with play money. It does not offer real-money gambling. If gambling stops being fun for you or someone you know, local support services can help."
	return s
