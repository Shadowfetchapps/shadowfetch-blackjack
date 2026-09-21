class_name GameHUD
extends CanvasLayer

const ThemeFactory = preload("res://scripts/ui/theme_factory.gd")
const BJMoney = preload("res://scripts/engine/bj_money.gd")

signal action(name: String)
signal chip(cents: int)

var bankroll_label: Label
var bet_label: Label
var player_label: Label
var dealer_label: Label
var session_label: Label
var status_label: Label
var _buttons: Dictionary = {}
var _chip_buttons: Dictionary = {}


func build() -> void:
	layer = 10
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_top_bar(root)
	_right_actions(root)
	_left_chips(root)
	status_label = ThemeFactory.label("", 24, ThemeFactory.GOLD)
	status_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	status_label.offset_top = 78
	status_label.offset_left = -320
	status_label.offset_right = 320
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(status_label)


func _top_bar(root: Control) -> void:
	var bar := HBoxContainer.new()
	bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	bar.offset_left = 20
	bar.offset_right = -20
	bar.offset_top = 14
	bar.offset_bottom = 64
	bar.add_theme_constant_override("separation", 22)
	root.add_child(bar)
	bankroll_label = ThemeFactory.label("Bankroll  $10,000.00", 20)
	bet_label = ThemeFactory.label("Bet  $0.00", 20, ThemeFactory.GOLD)
	player_label = ThemeFactory.label("You  —", 18)
	dealer_label = ThemeFactory.label("Dealer  —", 18)
	session_label = ThemeFactory.label("Session  $0.00", 16, ThemeFactory.MUTED)
	for l in [bankroll_label, bet_label, player_label, dealer_label, session_label]:
		bar.add_child(l)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(spacer)
	var menu_btn := ThemeFactory.button("MENU", 100)
	menu_btn.pressed.connect(func() -> void: action.emit("menu"))
	bar.add_child(menu_btn)


func _right_actions(root: Control) -> void:
	var bar := VBoxContainer.new()
	bar.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	bar.offset_left = -188
	bar.offset_right = -20
	bar.offset_top = -220
	bar.offset_bottom = 260
	bar.add_theme_constant_override("separation", 8)
	root.add_child(bar)
	for pair in [
		["deal", "DEAL  [SPACE]"],
		["hit", "HIT  [H]"],
		["stand", "STAND  [S]"],
		["double", "DOUBLE  [D]"],
		["split", "SPLIT  [P]"],
		["surrender", "SURRENDER  [U]"],
		["insurance_yes", "INSURE"],
		["insurance_no", "NO INS."],
		["undo", "UNDO"],
		["clear", "CLEAR"],
		["rebet", "REBET"],
		["repeat", "REPEAT"],
	]:
		var b := ThemeFactory.button(pair[1], 160)
		b.pressed.connect(_emit.bind(pair[0]))
		bar.add_child(b)
		_buttons[pair[0]] = b


func _left_chips(root: Control) -> void:
	var bar := VBoxContainer.new()
	bar.set_anchors_preset(Control.PRESET_CENTER_LEFT)
	bar.offset_left = 20
	bar.offset_right = 160
	bar.offset_top = -160
	bar.offset_bottom = 200
	bar.add_theme_constant_override("separation", 8)
	root.add_child(bar)
	bar.add_child(ThemeFactory.label("CHIPS", 14, ThemeFactory.GOLD))
	var i := 0
	for cents in BJMoney.CHIP_VALUES:
		var b := ThemeFactory.button(BJMoney.CHIP_LABELS[i], 120)
		b.pressed.connect(func() -> void: chip.emit(cents))
		bar.add_child(b)
		_chip_buttons[cents] = b
		i += 1


func _emit(name: String) -> void:
	action.emit(name)


func set_status(text: String) -> void:
	status_label.text = text


func refresh(engine, legal: PackedStringArray) -> void:
	bankroll_label.text = "Bankroll  " + BJMoney.format_cents(engine.bankroll_cents)
	var shown_bet: int = engine.current_bet_cents
	if engine.player_hands.size() > 0 and engine.phase != 0:
		shown_bet = 0
		for h in engine.player_hands:
			shown_bet += h.bet_cents
		shown_bet += engine.insurance_cents
	bet_label.text = "Bet  " + BJMoney.format_cents(shown_bet)
	if engine.player_hands.size() == 1:
		var h = engine.player_hands[0]
		player_label.text = "You  %s%s" % [h.best_total(), " soft" if h.is_soft() else ""]
	elif engine.player_hands.size() > 1:
		var parts: PackedStringArray = PackedStringArray()
		for i in engine.player_hands.size():
			var mark := "*" if i == engine.active_hand else ""
			parts.append("%s%d%s" % [mark, engine.player_hands[i].best_total(), mark])
		player_label.text = "You  " + " / ".join(parts)
	else:
		player_label.text = "You  —"
	if engine.dealer.cards.size() >= 2 and engine.phase in [3, 4]:
		dealer_label.text = "Dealer  %d" % engine.dealer.best_total()
	elif engine.dealer.cards.size() >= 2:
		var up = engine.dealer_upcard()
		dealer_label.text = "Dealer  %s" % (up.rank_name() if up else "—")
	else:
		dealer_label.text = "Dealer  —"
	session_label.text = "Session  %s   %d hands   %.1f%%" % [
		BJMoney.format_signed(engine.session_profit_cents),
		engine.hands_played,
		engine.win_percent(),
	]
	for key in _buttons:
		_buttons[key].disabled = not legal.has(key)
	for cents in _chip_buttons:
		_chip_buttons[cents].disabled = not legal.has("chip_%d" % cents)
