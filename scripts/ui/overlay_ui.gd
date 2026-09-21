class_name OverlayUI
extends CanvasLayer

const ThemeFactory = preload("res://scripts/ui/theme_factory.gd")
const BJMoney = preload("res://scripts/engine/bj_money.gd")

signal play
signal resume
signal restart_session
signal main_menu
signal quit_game
signal settings_changed

var _root: Control
var _pages: Dictionary = {}
var _settings_controls: Dictionary = {}
var current: String = ""
var settings_return: String = "main"


func build() -> void:
	layer = 20
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	_pages["main"] = _make_main()
	_pages["pause"] = _make_pause()
	_pages["settings"] = _make_settings()
	_pages["stats"] = _make_stats()
	_pages["howto"] = _make_howto()
	_pages["tutorial"] = _make_tutorial()
	for k in _pages:
		_root.add_child(_pages[k])
		_pages[k].visible = false
	hide_all()


func hide_all() -> void:
	_root.visible = false
	current = ""
	for k in _pages:
		_pages[k].visible = false


func show_page(name: String) -> void:
	_root.visible = true
	if name == "settings" and current != "" and current != "settings":
		settings_return = current
	current = name
	for k in _pages:
		_pages[k].visible = k == name
	if name == "stats":
		_refresh_stats()
	if name == "settings":
		_sync_settings_controls()


func visible_page() -> bool:
	return _root.visible


func _screen(title: String) -> Control:
	var wrap := Control.new()
	wrap.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	wrap.add_child(ThemeFactory.dimmer())
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	wrap.add_child(center)
	var panel := ThemeFactory.panel(center, false)
	panel.custom_minimum_size = Vector2(560, 520)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.offset_left = 20
	box.offset_right = -20
	box.offset_top = 16
	box.offset_bottom = -16
	box.add_child(ThemeFactory.label(title, 32, ThemeFactory.GOLD))
	wrap.set_meta("box", box)
	return wrap


func _add_btn(box: VBoxContainer, text: String, cb: Callable) -> void:
	var b := ThemeFactory.button(text, 360)
	b.pressed.connect(func() -> void:
		AudioManager.play("button")
		cb.call()
	)
	box.add_child(b)


func _make_main() -> Control:
	var s := _screen("SHADOWFETCH BLACKJACK")
	var box: VBoxContainer = s.get_meta("box")
	box.add_child(ThemeFactory.label("Fictional chips only. No real-money gambling.", 14, ThemeFactory.MUTED))
	_add_btn(box, "PLAY", func() -> void: play.emit())
	_add_btn(box, "SETTINGS", func() -> void: show_page("settings"))
	_add_btn(box, "STATS", func() -> void: show_page("stats"))
	_add_btn(box, "HOW TO PLAY", func() -> void: show_page("howto"))
	_add_btn(box, "QUIT", func() -> void: quit_game.emit())
	return s


func _make_pause() -> Control:
	var s := _screen("PAUSED")
	var box: VBoxContainer = s.get_meta("box")
	_add_btn(box, "RESUME", func() -> void: resume.emit())
	_add_btn(box, "SETTINGS", func() -> void: show_page("settings"))
	_add_btn(box, "RESTART SESSION", func() -> void: restart_session.emit())
	_add_btn(box, "MAIN MENU", func() -> void: main_menu.emit())
	_add_btn(box, "QUIT", func() -> void: quit_game.emit())
	return s


func _make_settings() -> Control:
	var s := _screen("SETTINGS")
	var box: VBoxContainer = s.get_meta("box")
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(480, 320)
	box.add_child(scroll)
	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 8)
	scroll.add_child(inner)
	_res_row(inner)
	_toggle(inner, "Fullscreen", SettingsStore.fullscreen, func(v): SettingsStore.fullscreen = v, "fullscreen")
	_toggle(inner, "VSync", SettingsStore.vsync, func(v): SettingsStore.vsync = v, "vsync")
	_quality_row(inner)
	_aa_row(inner)
	_toggle(inner, "Shadows", SettingsStore.shadows, func(v): SettingsStore.shadows = v, "shadows")
	_slider(inner, "Animation speed", SettingsStore.animation_speed, 0.5, 2.0, func(v): SettingsStore.animation_speed = v, "animation_speed")
	_slider(inner, "Master", SettingsStore.master_volume, 0.0, 1.0, func(v): SettingsStore.master_volume = v, "master_volume")
	_slider(inner, "Music", SettingsStore.music_volume, 0.0, 1.0, func(v): SettingsStore.music_volume = v, "music_volume")
	_slider(inner, "Effects", SettingsStore.fx_volume, 0.0, 1.0, func(v): SettingsStore.fx_volume = v, "fx_volume")
	_slider(inner, "Ambient", SettingsStore.ambient_volume, 0.0, 1.0, func(v): SettingsStore.ambient_volume = v, "ambient_volume")
	_toggle(inner, "Mute", SettingsStore.muted, func(v): SettingsStore.muted = v, "muted")
	inner.add_child(ThemeFactory.label("TABLE RULES · apply on next deal", 14, ThemeFactory.GOLD))
	_toggle(inner, "Dealer hits soft 17", SettingsStore.dealer_hits_soft_17, func(v): SettingsStore.dealer_hits_soft_17 = v, "dealer_hits_soft_17")
	_toggle(inner, "Late surrender", SettingsStore.late_surrender, func(v): SettingsStore.late_surrender = v, "late_surrender")
	var apply := ThemeFactory.button("APPLY & SAVE", 280)
	apply.pressed.connect(func() -> void:
		SettingsStore.apply_display()
		SettingsStore.apply_audio()
		SettingsStore.save_settings()
		settings_changed.emit()
		AudioManager.play("button")
	)
	box.add_child(apply)
	_add_btn(box, "BACK", func() -> void: show_page(settings_return))
	return s


func _res_row(parent: VBoxContainer) -> void:
	var row := HBoxContainer.new()
	row.add_child(ThemeFactory.label("Resolution", 16, ThemeFactory.MUTED))
	var opt := OptionButton.new()
	opt.custom_minimum_size = Vector2(220, 36)
	for r in [Vector2i(1280, 720), Vector2i(1600, 900), Vector2i(1920, 1080), Vector2i(2560, 1440), Vector2i(3840, 2160)]:
		opt.add_item("%d x %d" % [r.x, r.y])
		opt.set_item_metadata(opt.item_count - 1, r)
	opt.item_selected.connect(func(i): SettingsStore.resolution = opt.get_item_metadata(i))
	row.add_child(opt)
	parent.add_child(row)
	_settings_controls["resolution"] = opt


func _quality_row(parent: VBoxContainer) -> void:
	var row := HBoxContainer.new()
	row.add_child(ThemeFactory.label("Quality", 16, ThemeFactory.MUTED))
	var opt := OptionButton.new()
	for q in ["low", "medium", "high", "ultra"]:
		opt.add_item(q.capitalize())
		opt.set_item_metadata(opt.item_count - 1, q)
	opt.item_selected.connect(func(i): SettingsStore.quality = str(opt.get_item_metadata(i)))
	row.add_child(opt)
	parent.add_child(row)
	_settings_controls["quality"] = opt


func _aa_row(parent: VBoxContainer) -> void:
	var row := HBoxContainer.new()
	row.add_child(ThemeFactory.label("Anti-aliasing", 16, ThemeFactory.MUTED))
	var opt := OptionButton.new()
	for pair in [[0, "Off"], [2, "MSAA 2x"], [4, "MSAA 4x"], [8, "MSAA 8x"]]:
		opt.add_item(pair[1])
		opt.set_item_metadata(opt.item_count - 1, pair[0])
	opt.item_selected.connect(func(i): SettingsStore.aa = int(opt.get_item_metadata(i)))
	row.add_child(opt)
	parent.add_child(row)
	_settings_controls["aa"] = opt


func _toggle(parent: VBoxContainer, title: String, start: bool, setter: Callable, key: String = "") -> CheckButton:
	var b := CheckButton.new()
	b.text = title
	b.button_pressed = start
	b.toggled.connect(func(v): setter.call(v))
	parent.add_child(b)
	if not key.is_empty():
		_settings_controls[key] = b
	return b


func _slider(parent: VBoxContainer, title: String, start: float, lo: float, hi: float, setter: Callable, key: String = "") -> void:
	parent.add_child(ThemeFactory.label(title, 15, ThemeFactory.MUTED))
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = 0.05
	s.value = start
	s.custom_minimum_size = Vector2(360, 24)
	s.value_changed.connect(func(v): setter.call(v))
	parent.add_child(s)
	if not key.is_empty():
		_settings_controls[key] = s


func _sync_settings_controls() -> void:
	for key in ["fullscreen", "vsync", "shadows", "muted", "dealer_hits_soft_17", "late_surrender"]:
		if _settings_controls.has(key):
			_settings_controls[key].button_pressed = bool(SettingsStore.get(key))
	for key in ["animation_speed", "master_volume", "music_volume", "fx_volume", "ambient_volume"]:
		if _settings_controls.has(key):
			_settings_controls[key].value = float(SettingsStore.get(key))
	_select_metadata(_settings_controls.get("resolution"), SettingsStore.resolution)
	_select_metadata(_settings_controls.get("quality"), SettingsStore.quality)
	_select_metadata(_settings_controls.get("aa"), SettingsStore.aa)


func _select_metadata(control: OptionButton, value: Variant) -> void:
	if control == null:
		return
	for i in control.item_count:
		if control.get_item_metadata(i) == value:
			control.select(i)
			return


func _make_stats() -> Control:
	var s := _screen("STATISTICS")
	var box: VBoxContainer = s.get_meta("box")
	var body := ThemeFactory.label("", 18, ThemeFactory.CREAM)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	s.set_meta("stats_body", body)
	box.add_child(body)
	_add_btn(box, "RESET ALL STATS", func() -> void:
		StatsStore.reset_all()
		_refresh_stats()
	)
	_add_btn(box, "BACK", func() -> void: show_page("main"))
	return s


func _refresh_stats() -> void:
	var s: Control = _pages["stats"]
	var body: Label = s.get_meta("stats_body")
	body.text = "\n".join([
		"Bankroll   %s" % BJMoney.format_cents(StatsStore.bankroll_cents),
		"Lifetime P/L   %s" % BJMoney.format_signed(StatsStore.lifetime_profit_cents),
		"Session P/L   %s" % BJMoney.format_signed(StatsStore.session_profit_cents),
		"Hands   %d" % StatsStore.hands,
		"Wins / Losses / Pushes   %d / %d / %d" % [StatsStore.wins, StatsStore.losses, StatsStore.pushes],
		"Blackjacks   %d" % StatsStore.blackjacks,
		"Largest win   %s" % BJMoney.format_cents(StatsStore.largest_win_cents),
		"Win rate   %.1f%%" % StatsStore.win_percent(),
		"Last bet   %s" % BJMoney.format_cents(StatsStore.last_bet_cents),
	])


func _make_howto() -> Control:
	var s := _screen("HOW TO PLAY")
	var box: VBoxContainer = s.get_meta("box")
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(scroll)
	var lab := ThemeFactory.label(_howto_text(), 15, ThemeFactory.CREAM)
	lab.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lab.custom_minimum_size = Vector2(500, 0)
	scroll.add_child(lab)
	_add_btn(box, "BACK", func() -> void: show_page("main"))
	return s


func _make_tutorial() -> Control:
	var s := _screen("WELCOME TO THE TABLE")
	var box: VBoxContainer = s.get_meta("box")
	var lab := ThemeFactory.label(_tutorial_text(), 16, ThemeFactory.CREAM)
	lab.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lab.custom_minimum_size = Vector2(500, 0)
	box.add_child(lab)
	_add_btn(box, "SIT DOWN", func() -> void:
		SettingsStore.seen_tutorial = true
		SettingsStore.save_settings()
		hide_all()
		play.emit()
	)
	return s


func _howto_text() -> String:
	return """Goal
Beat the dealer without going over 21. Fictional chips only.

Card values
Aces count as 1 or 11. Face cards are 10. All others are their pip value.

The deal
Place a wager, then Deal. You and the dealer each receive two cards. The dealer keeps one card hidden.

Your actions
Hit — take another card.
Stand — keep your total.
Double — double your bet, take exactly one card, then stand.
Split — if your first two cards share a rank, play them as two hands (up to four). Doubling after a split is allowed. Split aces receive one card each.
Surrender — on your first two cards, forfeit half your wager when late surrender is enabled.

Blackjack
An ace and a ten-value card on the first two cards pays 3 to 2, unless the dealer also has blackjack (push).

Insurance
If the dealer shows an ace you may insure for half your bet. Insurance pays 2 to 1 if the dealer has blackjack.

Dealer
The default table stands on every 17, including soft 17 (ace + 6). You can enable H17 in Table Rules.

Keys
Space Deal   H Hit   S Stand   D Double   P Split   U Surrender   R Repeat   Esc Menu
"""


func _tutorial_text() -> String:
	return """Click chips (or the tray) to build a bet, then press DEAL.

Try to reach 21 without going over. The dealer must stand on all 17s.

A natural blackjack pays 3 to 2. This table uses fictional money only — there is no cash-out and no real wagering.

Open MENU anytime for settings, stats, and a full rules guide."""
