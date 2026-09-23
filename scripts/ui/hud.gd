class_name GameHUD
extends CanvasLayer
## In-game heads-up display: bankroll, rules, shoe and count, chip rack, contextual
## action bar, bet summary, floating hand badges, result banner, toasts and the
## first-run tutorial. Reads engine state; all decisions go back through signals.

const ThemeFactory = preload("res://scripts/ui/theme_factory.gd")
const BJMoney = preload("res://scripts/engine/bj_money.gd")
const BJSideBets = preload("res://scripts/engine/bj_side_bets.gd")
const BJStrategy = preload("res://scripts/engine/bj_strategy.gd")
const TableLayout = preload("res://scripts/table/table_layout.gd")
const ChipFactory = preload("res://scripts/table/chip_factory.gd")
const Phase = preload("res://scripts/engine/blackjack_engine.gd").Phase

signal action(name: String)
signal chip_pressed(cents: int)
signal tutorial_finished

const ACTIONS := {
	"clear": ["CLEAR", "X"],
	"undo": ["UNDO", "Z"],
	"rebet": ["REBET", "R"],
	"deal": ["DEAL", "SPACE"],
	"insurance_yes": ["INSURANCE", "Y"],
	"insurance_no": ["NO THANKS", "N"],
	"hit": ["HIT", "H"],
	"stand": ["STAND", "S"],
	"double": ["DOUBLE", "D"],
	"split": ["SPLIT", "P"],
	"surrender": ["SURRENDER", "U"],
	"hint": ["HINT", "T"],
	"next_new": ["NEW BET", "ENTER"],
	"next_repeat": ["REBET & DEAL", "SPACE"],
}
const SETS := {
	"betting": ["clear", "undo", "rebet", "deal"],
	"insurance": ["insurance_no", "insurance_yes"],
	"player": ["hit", "stand", "double", "split", "surrender", "hint"],
	"result": ["next_new", "next_repeat"],
}
const PRIMARY := ["deal", "next_repeat", "insurance_yes"]
const CHIP_KEYS := ["1", "2", "3", "4", "5", "6"]

var engine
var table
var _root: Control
var _bank_value: Label
var _session_label: Label
var _shown_bankroll := -1.0
var _rules_label: Label
var _prompt: Label
var _shoe_bar: Control
var _shoe_label: Label
var _count_box: Control
var _count_label: Label
var _chip_buttons: Dictionary = {}
var _chip_rings: Dictionary = {}
var _selected_chip := 2500
var _action_bar: HBoxContainer
var _buttons: Dictionary = {}
var _current_set := ""
var _bet_total: Label
var _bet_lines: VBoxContainer
var _last_label: Label
var _badge_layer: Control
var _badges: Dictionary = {}
var _banner: Control
var _banner_title: Label
var _banner_amount: Label
var _coach: PanelContainer
var _coach_label: Label
var _coach_tween: Tween
var _toast_box: VBoxContainer
var _achievement_box: VBoxContainer
var _callouts: Control
var _tutorial: Control
var _tut_step := 0
var _tut_card: PanelContainer
var _tut_title: Label
var _tut_body: Label
var _tut_next: Button
var _tut_target := Rect2()
var _settled_view := false


func build(p_table) -> void:
	table = p_table
	layer = 10
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.theme = ThemeFactory.theme()
	add_child(_root)
	_badge_layer = Control.new()
	_badge_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_badge_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_badge_layer)
	_callouts = Control.new()
	_callouts.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_callouts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_callouts)
	_build_top_left()
	_build_top_center()
	_build_top_right()
	_build_chip_rack()
	_build_action_bar()
	_build_bet_panel()
	_build_banner()
	_build_coach()
	_build_toasts()
	_build_tutorial()


# --- layout -----------------------------------------------------------------

func _build_top_left() -> void:
	var panel := PanelContainer.new()
	panel.theme_type_variation = "HudPanel"
	panel.position = Vector2(28, 24)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	panel.add_child(v)
	v.add_child(ThemeFactory.label("BANKROLL", "Subheading"))
	_bank_value = ThemeFactory.label("$10,000.00", "Value")
	v.add_child(_bank_value)
	_session_label = ThemeFactory.label("", "Muted")
	_session_label.add_theme_font_size_override("font_size", 14)
	v.add_child(_session_label)


func _build_top_center() -> void:
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER_TOP)
	box.offset_left = -520
	box.offset_right = 520
	box.offset_top = 22
	box.alignment = BoxContainer.ALIGNMENT_BEGIN
	box.add_theme_constant_override("separation", 10)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(box)
	_rules_label = ThemeFactory.label("", "Subheading")
	_rules_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_rules_label)
	_prompt = ThemeFactory.label("", "Caps")
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.add_theme_font_size_override("font_size", 18)
	box.add_child(_prompt)
	_toast_box = VBoxContainer.new()
	_toast_box.alignment = BoxContainer.ALIGNMENT_BEGIN
	_toast_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(_toast_box)


func _build_top_right() -> void:
	var col := VBoxContainer.new()
	col.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	col.offset_left = -390
	col.offset_right = -28
	col.offset_top = 24
	col.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	col.add_theme_constant_override("separation", 10)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(col)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_END
	row.add_theme_constant_override("separation", 8)
	col.add_child(row)
	var chart := ThemeFactory.button("STRATEGY", "", 0, 40)
	chart.tooltip_text = "Basic strategy chart for these rules"
	chart.focus_mode = Control.FOCUS_NONE
	chart.pressed.connect(func() -> void: action.emit("chart"))
	row.add_child(chart)
	var menu := ThemeFactory.button("MENU", "", 0, 40)
	menu.tooltip_text = "Pause menu (Esc)"
	menu.focus_mode = Control.FOCUS_NONE
	menu.pressed.connect(func() -> void: action.emit("menu"))
	row.add_child(menu)
	var panel := PanelContainer.new()
	panel.theme_type_variation = "HudPanel"
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	panel.add_child(v)
	_shoe_label = ThemeFactory.label("SHOE", "Subheading")
	v.add_child(_shoe_label)
	_shoe_bar = ShoeBar.new()
	_shoe_bar.custom_minimum_size = Vector2(326, 10)
	v.add_child(_shoe_bar)
	_count_box = VBoxContainer.new()
	v.add_child(_count_box)
	_count_box.add_child(ThemeFactory.hsep())
	_count_label = ThemeFactory.label("", "Body")
	_count_label.add_theme_font_size_override("font_size", 16)
	_count_box.add_child(_count_label)
	_achievement_box = VBoxContainer.new()
	_achievement_box.add_theme_constant_override("separation", 8)
	_achievement_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(_achievement_box)


func _build_chip_rack() -> void:
	var panel := PanelContainer.new()
	panel.name = "ChipRack"
	panel.theme_type_variation = "HudPanel"
	panel.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	panel.offset_left = 28
	panel.offset_bottom = -26
	panel.offset_top = -170
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_root.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	panel.add_child(v)
	v.add_child(ThemeFactory.label("CHIPS  ·  CLICK A CIRCLE TO PLACE", "Subheading"))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	v.add_child(row)
	for i in BJMoney.CHIP_VALUES.size():
		var cents: int = BJMoney.CHIP_VALUES[i]
		var cell := VBoxContainer.new()
		cell.add_theme_constant_override("separation", 2)
		row.add_child(cell)
		var holder := Control.new()
		holder.custom_minimum_size = Vector2(66, 66)
		cell.add_child(holder)
		var ring := Panel.new()
		var rs := StyleBoxFlat.new()
		rs.bg_color = Color(0, 0, 0, 0)
		rs.border_color = ThemeFactory.GOLD_BRIGHT
		rs.set_border_width_all(3)
		rs.set_corner_radius_all(40)
		ring.add_theme_stylebox_override("panel", rs)
		ring.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ring.visible = false
		holder.add_child(ring)
		var b := TextureButton.new()
		b.focus_mode = Control.FOCUS_NONE
		b.texture_normal = ChipFactory.icon(cents)
		b.ignore_texture_size = true
		b.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		b.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		b.offset_left = 4
		b.offset_top = 4
		b.offset_right = -4
		b.offset_bottom = -4
		b.tooltip_text = "%s chip  (key %s)\nLeft-click a circle to place, right-click to remove" % [BJMoney.chip_label(cents), CHIP_KEYS[i]]
		b.pivot_offset = Vector2(29, 29)
		b.pressed.connect(func() -> void: chip_pressed.emit(cents))
		b.mouse_entered.connect(func() -> void:
			if not b.disabled:
				AudioManager.play("ui_hover")
				b.create_tween().tween_property(b, "scale", Vector2(1.08, 1.08), 0.1)
		)
		b.mouse_exited.connect(func() -> void: b.create_tween().tween_property(b, "scale", Vector2.ONE, 0.1))
		holder.add_child(b)
		cell.add_child(ThemeFactory.keycap(CHIP_KEYS[i]))
		_chip_buttons[cents] = b
		_chip_rings[cents] = ring


func _build_action_bar() -> void:
	_action_bar = HBoxContainer.new()
	_action_bar.name = "ActionBar"
	_action_bar.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_action_bar.offset_left = -470
	_action_bar.offset_right = 470
	_action_bar.offset_top = -104
	_action_bar.offset_bottom = -34
	_action_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	_action_bar.add_theme_constant_override("separation", 10)
	_action_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_action_bar)
	for id in ACTIONS:
		var info: Array = ACTIONS[id]
		var primary: bool = id in PRIMARY
		var b := ThemeFactory.button("", "PrimaryButton" if primary else "", 116, 70)
		if id in ["surrender", "next_repeat", "insurance_no", "insurance_yes"]:
			b.custom_minimum_size.x = 156
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(_emit_action.bind(id))
		var stack := VBoxContainer.new()
		stack.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		stack.alignment = BoxContainer.ALIGNMENT_CENTER
		stack.add_theme_constant_override("separation", 4)
		stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(stack)
		var title := ThemeFactory.label(info[0], "Body")
		title.add_theme_font_override("font", preload("res://scripts/ui/fonts.gd").ui("bold" if primary else "semibold"))
		title.add_theme_font_size_override("font_size", 17)
		title.add_theme_color_override("font_color", ThemeFactory.INK if primary else ThemeFactory.CREAM)
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title.mouse_filter = Control.MOUSE_FILTER_IGNORE
		stack.add_child(title)
		var key := ThemeFactory.keycap(info[1])
		key.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		key.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if primary:
			key.add_theme_color_override("font_color", ThemeFactory.INK)
		stack.add_child(key)
		b.set_meta("title", title)
		b.mouse_entered.connect(func() -> void:
			if not b.disabled and not primary:
				title.add_theme_color_override("font_color", ThemeFactory.GOLD_BRIGHT)
		)
		b.mouse_exited.connect(func() -> void:
			title.add_theme_color_override("font_color", ThemeFactory.INK if primary else ThemeFactory.CREAM)
		)
		b.visible = false
		_action_bar.add_child(b)
		_buttons[id] = b


func _build_bet_panel() -> void:
	var panel := PanelContainer.new()
	panel.name = "BetPanel"
	panel.theme_type_variation = "HudPanel"
	panel.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	panel.offset_right = -28
	panel.offset_bottom = -26
	panel.offset_left = -300
	panel.offset_top = -190
	panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	panel.add_child(v)
	v.add_child(ThemeFactory.label("ON THE TABLE", "Subheading"))
	_bet_total = ThemeFactory.label("$0", "ValueSmall")
	v.add_child(_bet_total)
	_bet_lines = VBoxContainer.new()
	_bet_lines.add_theme_constant_override("separation", 0)
	v.add_child(_bet_lines)
	v.add_child(ThemeFactory.hsep())
	_last_label = ThemeFactory.label("", "Muted")
	_last_label.add_theme_font_size_override("font_size", 14)
	v.add_child(_last_label)


func _build_banner() -> void:
	_banner = VBoxContainer.new()
	_banner.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_banner.offset_left = -500
	_banner.offset_right = 500
	_banner.offset_top = 96
	_banner.offset_bottom = 230
	_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	(_banner as VBoxContainer).alignment = BoxContainer.ALIGNMENT_CENTER
	_banner.pivot_offset = Vector2(500, 60)
	_root.add_child(_banner)
	_banner_title = ThemeFactory.label("", "Title")
	_banner_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner_title.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	_banner_title.add_theme_constant_override("outline_size", 12)
	_banner.add_child(_banner_title)
	_banner_amount = ThemeFactory.label("", "Value")
	_banner_amount.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner_amount.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	_banner_amount.add_theme_constant_override("outline_size", 10)
	_banner.add_child(_banner_amount)
	_banner.modulate.a = 0.0


func _build_coach() -> void:
	_coach = PanelContainer.new()
	_coach.theme_type_variation = "HudPanel"
	_coach.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_coach.offset_top = -168
	_coach.offset_bottom = -120
	_coach.offset_left = -360
	_coach.offset_right = 360
	_coach.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_coach)
	_coach_label = ThemeFactory.label("", "Body")
	_coach_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_coach.add_child(_coach_label)
	_coach.modulate.a = 0.0


func _build_toasts() -> void:
	pass


# --- per-frame --------------------------------------------------------------

func _process(delta: float) -> void:
	if engine == null:
		return
	var target := float(engine.bankroll_cents - engine.pending_total()) if engine.phase == Phase.BETTING else float(engine.bankroll_cents)
	if _shown_bankroll < 0.0:
		_shown_bankroll = target
	if absf(_shown_bankroll - target) > 0.5:
		_shown_bankroll = lerpf(_shown_bankroll, target, minf(1.0, delta * 6.0))
		if absf(_shown_bankroll - target) < 50.0:
			_shown_bankroll = target
	var shown := int(round(_shown_bankroll))
	if shown != int(target):
		shown = int(round(_shown_bankroll / 100.0)) * 100
	_bank_value.text = BJMoney.format_cents(shown)
	_update_badges()
	if _tutorial.visible:
		_update_tutorial_target()


# --- refresh ----------------------------------------------------------------

## Context: { busy: bool, awaiting: bool, selected: int }.
func refresh(p_engine, ctx: Dictionary) -> void:
	engine = p_engine
	var busy: bool = ctx.get("busy", false)
	var awaiting: bool = ctx.get("awaiting", false)
	_selected_chip = int(ctx.get("selected", _selected_chip))
	var legal: PackedStringArray = engine.legal_actions()
	_session_label.text = "Session %s  ·  %d hands  ·  %.0f%% won" % [
		BJMoney.format_signed_short(engine.session_profit_cents), engine.hands_played, engine.win_percent()
	]
	_session_label.add_theme_color_override("font_color", ThemeFactory.money_color(engine.session_profit_cents).lerp(ThemeFactory.MUTED, 0.3))
	_rules_label.text = engine.rules.summary()
	_update_shoe()
	# Prompt.
	var prompt := ""
	match engine.phase:
		Phase.BETTING:
			if engine.is_broke():
				prompt = "Out of chips"
			elif engine.pending_total() == 0:
				prompt = "Place your bet"
			else:
				prompt = "Press DEAL when you are ready"
		Phase.INSURANCE:
			prompt = "Dealer shows an ace — even money?" if engine.even_money_offered else "Dealer shows an ace — insurance?"
		Phase.PLAYER:
			if engine.player_hands.size() > 1:
				prompt = "Your move  ·  hand %d of %d" % [engine.active_hand + 1, engine.player_hands.size()]
			else:
				prompt = "Your move"
		Phase.DEALER:
			prompt = "Dealer plays"
		Phase.SETTLE:
			prompt = ""
	if busy and engine.phase != Phase.SETTLE and engine.phase != Phase.BETTING:
		prompt = "…"
	_prompt.text = prompt.to_upper()
	# Chips.
	for cents in _chip_buttons:
		var b: TextureButton = _chip_buttons[cents]
		var ok: bool = (engine.phase == Phase.BETTING and not busy and engine.can_add_chip(cents, "main")) or (awaiting and not busy and cents <= engine.bankroll_cents)
		b.disabled = not ok
		b.modulate = Color(1, 1, 1, 1) if ok else Color(0.45, 0.45, 0.45, 0.8)
		(_chip_rings[cents] as Control).visible = cents == _selected_chip and ok
	# Actions.
	var set_name := "betting"
	match engine.phase:
		Phase.INSURANCE:
			set_name = "insurance"
		Phase.PLAYER, Phase.DEALER:
			set_name = "player"
		Phase.SETTLE:
			set_name = "result" if awaiting else "player"
	_show_set(set_name)
	for id in _buttons:
		var b: Button = _buttons[id]
		if not b.visible:
			continue
		var enabled := false
		match id:
			"hint":
				enabled = engine.phase in [Phase.PLAYER, Phase.INSURANCE]
			"next_new", "next_repeat":
				enabled = awaiting
				if id == "next_repeat":
					enabled = awaiting and engine.last_bets["main"] <= engine.bankroll_cents
			"rebet":
				enabled = legal.has("rebet") and engine.pending_total() == 0
			_:
				enabled = legal.has(id)
		b.disabled = busy or not enabled
		b.modulate.a = 0.45 if b.disabled else 1.0
	if engine.phase == Phase.INSURANCE:
		(_buttons["insurance_yes"].get_meta("title") as Label).text = "EVEN MONEY" if engine.even_money_offered else "INSURE  %s" % BJMoney.format_short(BJMoney.insurance_cost(engine.player_hands[0].bet_cents))
	_buttons["hint"].visible = _buttons["hint"].visible and SettingsStore.coach_mode != "off"
	_update_bet_panel()


func _show_set(name: String) -> void:
	if name == _current_set:
		return
	_current_set = name
	for id in _buttons:
		(_buttons[id] as Button).visible = false
	for id in SETS[name]:
		(_buttons[id] as Button).visible = true
	_action_bar.modulate.a = 0.0
	_action_bar.create_tween().tween_property(_action_bar, "modulate:a", 1.0, 0.18)


func _update_shoe() -> void:
	var shoe = engine.shoe
	_shoe_label.text = "SHOE  ·  %d DECK%s  ·  %d CARDS LEFT" % [shoe.decks, "" if shoe.decks == 1 else "S", shoe.remaining()]
	_shoe_bar.dealt = shoe.dealt_fraction()
	_shoe_bar.cut = shoe.cut_fraction()
	_shoe_bar.queue_redraw()
	_count_box.visible = SettingsStore.show_count
	if SettingsStore.show_count:
		var tc: float = engine.true_count()
		_count_label.text = "Running %+d   ·   True %+.1f   ·   %.1f decks left" % [engine.running_count, tc, shoe.decks_remaining()]
		_count_label.add_theme_color_override("font_color", ThemeFactory.GOOD if tc >= 2.0 else (ThemeFactory.BAD if tc <= -2.0 else ThemeFactory.CREAM))


func _update_bet_panel() -> void:
	for c in _bet_lines.get_children():
		c.queue_free()
	var lines: Array = []
	var total := 0
	if engine.phase == Phase.BETTING:
		for spot in ["main", "pp", "t3"]:
			var amt: int = engine.bets[spot]
			if amt > 0:
				lines.append([_spot_title(spot), BJMoney.format_short(amt), ThemeFactory.CREAM])
				total += amt
	else:
		for i in engine.player_hands.size():
			var h = engine.player_hands[i]
			var t := "Hand %d" % (i + 1) if engine.player_hands.size() > 1 else "Main bet"
			if h.doubled:
				t += "  ·  doubled"
			lines.append([t, BJMoney.format_short(h.bet_cents), ThemeFactory.CREAM])
			total += h.bet_cents
		for s in engine.side_results:
			var won: bool = int(s["payout"]) > 0
			lines.append([BJSideBets.title(s["kind"]), BJMoney.format_signed_short(int(s["net"])), ThemeFactory.GOOD if won else ThemeFactory.DIM])
		if engine.insurance_cents > 0:
			lines.append(["Insurance", BJMoney.format_short(engine.insurance_cents), ThemeFactory.CREAM])
			total += engine.insurance_cents
	_bet_total.text = BJMoney.format_short(total)
	for l in lines:
		var row := HBoxContainer.new()
		var a := ThemeFactory.label(l[0], "Muted")
		a.add_theme_font_size_override("font_size", 14)
		a.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var b := ThemeFactory.label(l[1], "Body")
		b.add_theme_font_size_override("font_size", 15)
		b.add_theme_color_override("font_color", l[2])
		row.add_child(a)
		row.add_child(b)
		_bet_lines.add_child(row)
	var last: int = engine.last_net_cents
	if engine.hands_played > 0:
		_last_label.text = "Last round  %s" % BJMoney.format_signed_short(last)
		_last_label.add_theme_color_override("font_color", ThemeFactory.money_color(last))
	else:
		_last_label.text = "Table limits  $1 – $10,000"


func _spot_title(spot: String) -> String:
	match spot:
		"pp":
			return "Perfect Pairs"
		"t3":
			return "21+3"
	return "Main bet"


# --- hand badges ------------------------------------------------------------

func set_settled_view(on: bool) -> void:
	_settled_view = on


func _update_badges() -> void:
	var wanted := {}
	var show_totals: bool = SettingsStore.show_totals
	var n: int = engine.player_hands.size()
	for i in n:
		var h = engine.player_hands[i]
		if h.cards.is_empty():
			continue
		var key := "p%d" % i
		var outcome := str(h.outcome) if _settled_view else ""
		if outcome.is_empty() and not show_totals:
			continue
		wanted[key] = true
		var active: bool = engine.phase == Phase.PLAYER and i == engine.active_hand and n > 1
		var bet_text := BJMoney.format_short(h.bet_cents)
		if h.doubled:
			bet_text += "  ·  ×2"
		_badge(key, TableLayout.player_badge(i, n), _hand_title(h, outcome), bet_text, _outcome_style(outcome, active))
	if not engine.dealer.cards.is_empty() and (show_totals or _settled_view):
		var text := ""
		if engine.hole_revealed():
			text = engine.dealer.total_text()
		else:
			var up = engine.dealer_upcard()
			if up != null:
				text = "Showing %s" % ("A" if up.is_ace() else str(up.pip_value()))
		wanted["dealer"] = true
		_badge("dealer", TableLayout.dealer_badge(engine.dealer.cards.size()), text.to_upper(), "DEALER", "dealer")
	for key in _badges.keys():
		if not wanted.has(key):
			(_badges[key] as Node).queue_free()
			_badges.erase(key)


func _hand_title(h, outcome: String) -> String:
	match outcome:
		"win":
			return "WIN  %s" % BJMoney.format_signed_short(h.payout_cents - h.bet_cents)
		"blackjack":
			return "BLACKJACK  %s" % BJMoney.format_signed_short(h.payout_cents - h.bet_cents)
		"even_money":
			return "EVEN MONEY  %s" % BJMoney.format_signed_short(h.payout_cents - h.bet_cents)
		"push":
			return "PUSH"
		"lose":
			return "LOSE  %d" % h.best_total()
		"bust":
			return "BUST  %d" % h.best_total()
		"surrender":
			return "SURRENDERED"
	return h.total_text().to_upper()


func _outcome_style(outcome: String, active: bool) -> String:
	match outcome:
		"win", "even_money":
			return "win"
		"blackjack":
			return "blackjack"
		"lose", "bust", "surrender":
			return "lose"
		"push":
			return "push"
	return "active" if active else "normal"


func _badge(key: String, world: Vector3, title: String, sub: String, style: String) -> void:
	var panel: PanelContainer = _badges.get(key)
	if panel == null:
		panel = PanelContainer.new()
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", -2)
		v.alignment = BoxContainer.ALIGNMENT_CENTER
		panel.add_child(v)
		var t := ThemeFactory.label("", "ValueSmall")
		t.add_theme_font_size_override("font_size", 21)
		t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(t)
		var s := ThemeFactory.label("", "Subheading")
		s.add_theme_font_size_override("font_size", 11)
		s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(s)
		panel.set_meta("title", t)
		panel.set_meta("sub", s)
		_badge_layer.add_child(panel)
		_badges[key] = panel
		panel.modulate.a = 0.0
		panel.create_tween().tween_property(panel, "modulate:a", 1.0, 0.2)
	var tl: Label = panel.get_meta("title")
	var sl: Label = panel.get_meta("sub")
	tl.text = title
	sl.text = sub
	if panel.get_meta("style", "") != style:
		panel.set_meta("style", style)
		var bg := Color(0.02, 0.02, 0.024, 0.82)
		var border := Color(ThemeFactory.GOLD, 0.35)
		var fc := ThemeFactory.CREAM
		var bw := 1
		match style:
			"active":
				border = ThemeFactory.GOLD_BRIGHT
				bw = 2
			"win":
				border = ThemeFactory.GOOD
				fc = ThemeFactory.GOOD
				bw = 2
			"blackjack":
				bg = Color(0.80, 0.64, 0.33, 0.95)
				border = Color(1, 0.9, 0.65)
				fc = ThemeFactory.INK
				bw = 2
			"lose":
				border = Color(ThemeFactory.BAD, 0.8)
				fc = ThemeFactory.BAD
			"push":
				border = ThemeFactory.MUTED
				fc = ThemeFactory.CREAM
			"dealer":
				border = Color(1, 1, 1, 0.12)
		var sb := StyleBoxFlat.new()
		sb.bg_color = bg
		sb.border_color = border
		sb.set_border_width_all(bw)
		sb.set_corner_radius_all(18)
		sb.content_margin_left = 16
		sb.content_margin_right = 16
		sb.content_margin_top = 4
		sb.content_margin_bottom = 6
		sb.shadow_color = Color(0, 0, 0, 0.45)
		sb.shadow_size = 8
		panel.add_theme_stylebox_override("panel", sb)
		tl.add_theme_color_override("font_color", fc)
		sl.add_theme_color_override("font_color", Color(fc, 0.7) if style == "blackjack" else ThemeFactory.MUTED)
		if style in ["win", "blackjack"]:
			panel.pivot_offset = panel.size * 0.5
			panel.scale = Vector2(1.18, 1.18)
			panel.create_tween().tween_property(panel, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if not table.is_visible_point(world):
		panel.visible = false
		return
	panel.visible = true
	var p: Vector2 = table.screen_point(world)
	panel.reset_size()
	panel.position = p - Vector2(panel.size.x * 0.5, 0.0)


func clear_badges() -> void:
	for b in _badges.values():
		(b as Node).queue_free()
	_badges.clear()


# --- banner, callouts, toasts ----------------------------------------------

func show_result(engine_ref) -> void:
	var net: int = engine_ref.last_net_cents
	var title := "PUSH"
	var any_bj := false
	for h in engine_ref.player_hands:
		if h.outcome == "blackjack":
			any_bj = true
	if any_bj:
		title = "BLACKJACK"
	elif net > 0:
		title = "DEALER BUSTS" if engine_ref.dealer.is_bust() else "YOU WIN"
	elif net < 0:
		var all_bust := true
		for h in engine_ref.player_hands:
			if h.outcome != "bust":
				all_bust = false
		if engine_ref.dealer.is_blackjack():
			title = "DEALER BLACKJACK"
		elif all_bust:
			title = "BUST"
		else:
			title = "DEALER WINS"
	_banner_title.text = title
	_banner_title.add_theme_color_override("font_color", ThemeFactory.GOLD_BRIGHT if net >= 0 else Color(0.92, 0.88, 0.82))
	_banner_amount.text = BJMoney.format_signed_short(net) if net != 0 else "bet returned"
	_banner_amount.add_theme_color_override("font_color", ThemeFactory.money_color(net) if net != 0 else ThemeFactory.MUTED)
	_banner.scale = Vector2(0.86, 0.86)
	_banner.pivot_offset = _banner.size * 0.5
	var tw := _banner.create_tween().set_parallel(true)
	tw.tween_property(_banner, "modulate:a", 1.0, 0.25)
	tw.tween_property(_banner, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func hide_result() -> void:
	if _banner.modulate.a > 0.0:
		_banner.create_tween().tween_property(_banner, "modulate:a", 0.0, 0.25)


func show_side_results(results: Array) -> void:
	for s in results:
		var spot: String = s["kind"]
		var won: bool = int(s["payout"]) > 0
		var text: String
		if won:
			text = "%s  %d:1\n%s" % [BJSideBets.result_title(s["result"]).to_upper(), BJSideBets.multiplier(spot, s["result"]), BJMoney.format_signed_short(int(s["net"]))]
		else:
			text = "%s\nno win" % BJSideBets.title(spot).to_upper()
		var l := ThemeFactory.label(text, "Caps")
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.add_theme_font_size_override("font_size", 17 if won else 13)
		l.add_theme_color_override("font_color", ThemeFactory.GOLD_BRIGHT if won else ThemeFactory.MUTED)
		l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
		l.add_theme_constant_override("outline_size", 8)
		_callouts.add_child(l)
		var world := TableLayout.spot_world(spot) + Vector3(0, 0.04, -0.05)
		var p: Vector2 = table.screen_point(world)
		l.reset_size()
		l.position = p - Vector2(l.size.x * 0.5, l.size.y)
		var tw := l.create_tween()
		tw.tween_property(l, "position:y", l.position.y - 26, 2.6).set_trans(Tween.TRANS_SINE)
		tw.parallel().tween_property(l, "modulate:a", 0.0, 0.8).set_delay(1.9)
		tw.tween_callback(l.queue_free)


## Coach feedback or a hint. `good` true = green check, false = amber advice.
func coach(text: String, good: bool) -> void:
	_coach_label.text = ("✓  " if good else "✎  ") + text
	_coach_label.add_theme_color_override("font_color", ThemeFactory.GOOD if good else ThemeFactory.GOLD_BRIGHT)
	if _coach_tween and _coach_tween.is_valid():
		_coach_tween.kill()
	_coach_tween = _coach.create_tween()
	_coach_tween.tween_property(_coach, "modulate:a", 1.0, 0.15)
	_coach_tween.tween_interval(2.8)
	_coach_tween.tween_property(_coach, "modulate:a", 0.0, 0.5)


func highlight_action(id: String) -> void:
	var b: Button = _buttons.get(id)
	if b == null or not b.visible:
		return
	b.pivot_offset = b.size * 0.5
	var tw := b.create_tween()
	for i in 3:
		tw.tween_property(b, "scale", Vector2(1.1, 1.1), 0.14)
		tw.tween_property(b, "scale", Vector2.ONE, 0.14)


func toast(text: String, color: Color = ThemeFactory.CREAM) -> void:
	var panel := PanelContainer.new()
	panel.theme_type_variation = "HudPanel"
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var l := ThemeFactory.label(text, "Body")
	l.add_theme_color_override("font_color", color)
	panel.add_child(l)
	_toast_box.add_child(panel)
	panel.modulate.a = 0.0
	var tw := panel.create_tween()
	tw.tween_property(panel, "modulate:a", 1.0, 0.2)
	tw.tween_interval(2.2)
	tw.tween_property(panel, "modulate:a", 0.0, 0.4)
	tw.tween_callback(panel.queue_free)


var _achievement_queue: Array = []
var _achievement_showing := false


func show_achievement(def: Dictionary) -> void:
	_achievement_queue.append(def)
	if not _achievement_showing:
		_next_achievement()


func _next_achievement() -> void:
	if _achievement_queue.is_empty():
		_achievement_showing = false
		return
	_achievement_showing = true
	_present_achievement(_achievement_queue.pop_front())


func _present_achievement(def: Dictionary) -> void:
	AudioManager.play("achievement")
	var panel := PanelContainer.new()
	panel.theme_type_variation = "HudPanel"
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	panel.add_child(row)
	var medal := Label.new()
	medal.text = str(def.get("icon", "★"))
	medal.theme_type_variation = "ValueSmall"
	medal.add_theme_color_override("font_color", ThemeFactory.INK)
	medal.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	medal.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	medal.custom_minimum_size = Vector2(52, 52)
	var ms := StyleBoxFlat.new()
	ms.bg_color = ThemeFactory.GOLD
	ms.set_corner_radius_all(26)
	medal.add_theme_stylebox_override("normal", ms)
	medal.add_theme_font_size_override("font_size", 18)
	row.add_child(medal)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	row.add_child(v)
	v.add_child(ThemeFactory.label("ACHIEVEMENT UNLOCKED", "Subheading"))
	var t := ThemeFactory.label(str(def.get("title", "")), "ValueSmall")
	t.add_theme_color_override("font_color", ThemeFactory.GOLD_BRIGHT)
	v.add_child(t)
	var d := ThemeFactory.label(str(def.get("desc", "")), "Muted")
	d.add_theme_font_size_override("font_size", 14)
	v.add_child(d)
	_achievement_box.add_child(panel)
	panel.modulate.a = 0.0
	var tw := panel.create_tween()
	tw.tween_property(panel, "modulate:a", 1.0, 0.3)
	tw.tween_interval(3.2)
	tw.tween_property(panel, "modulate:a", 0.0, 0.4)
	tw.tween_callback(panel.queue_free)
	tw.tween_callback(_next_achievement)


func set_visible_hud(on: bool) -> void:
	_root.visible = on


func _emit_action(id: String) -> void:
	AudioManager.play("ui_click")
	action.emit(id)


# --- tutorial ---------------------------------------------------------------

const TUTORIAL := [
	["Welcome to the private table", "Shadowfetch Blackjack is played with fictional chips only — there is no cash-out and no real wagering. Here is a quick tour.", ""],
	["Choose your chips", "Click a chip (or press 1–6) to add it to your main bet. You can also click any betting circle on the felt with the selected chip; right-click a circle to take a chip back.", "ChipRack"],
	["Optional side bets", "Perfect Pairs pays when your first two cards are a pair. 21+3 pays for poker hands made from your two cards and the dealer's up-card.", "spots"],
	["Play your hand", "Press SPACE to deal. On your turn: Hit (H), Stand (S), Double (D), Split (P) or Surrender (U). Every button shows its key.", "ActionBar"],
	["Get advice", "Not sure? Press HINT (T) for the basic-strategy play. Turn on the Coach in Settings → Gameplay to have every decision graded.", "ActionBar"],
	["Everything else", "The menu holds table rules, the strategy chart, statistics, hand history, achievements and settings. Good luck!", "menu"],
]


func _build_tutorial() -> void:
	_tutorial = TutorialDim.new()
	_tutorial.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_tutorial.mouse_filter = Control.MOUSE_FILTER_STOP
	_tutorial.visible = false
	_root.add_child(_tutorial)
	_tut_card = PanelContainer.new()
	_tut_card.custom_minimum_size = Vector2(520, 0)
	_tutorial.add_child(_tut_card)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	_tut_card.add_child(v)
	_tut_title = ThemeFactory.label("", "Heading")
	v.add_child(_tut_title)
	_tut_body = ThemeFactory.label("", "Body")
	_tut_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tut_body.custom_minimum_size = Vector2(470, 0)
	v.add_child(_tut_body)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	v.add_child(row)
	var skip := ThemeFactory.button("SKIP TOUR", "", 150, 44)
	skip.pressed.connect(_finish_tutorial)
	row.add_child(skip)
	row.add_child(ThemeFactory.expander())
	_tut_next = ThemeFactory.button("NEXT", "PrimaryButton", 150, 44)
	_tut_next.pressed.connect(_next_tutorial)
	row.add_child(_tut_next)


func start_tutorial() -> void:
	_tut_step = 0
	_tutorial.visible = true
	_show_tutorial_step()


func tutorial_active() -> bool:
	return _tutorial.visible


func _next_tutorial() -> void:
	AudioManager.play("ui_click")
	_tut_step += 1
	if _tut_step >= TUTORIAL.size():
		_finish_tutorial()
		return
	_show_tutorial_step()


func _finish_tutorial() -> void:
	_tutorial.visible = false
	tutorial_finished.emit()


func _show_tutorial_step() -> void:
	var step: Array = TUTORIAL[_tut_step]
	_tut_title.text = step[0]
	_tut_body.text = step[1]
	_tut_next.text = "LET'S PLAY" if _tut_step == TUTORIAL.size() - 1 else "NEXT"
	_tut_next.grab_focus()
	_update_tutorial_target()


func _update_tutorial_target() -> void:
	var target: String = TUTORIAL[_tut_step][2]
	var rect := Rect2()
	match target:
		"ChipRack":
			rect = _root.get_node("ChipRack").get_global_rect()
		"ActionBar":
			rect = _action_bar.get_global_rect()
		"spots":
			var a: Vector2 = table.screen_point(TableLayout.spot_world("pp"))
			var b: Vector2 = table.screen_point(TableLayout.spot_world("t3"))
			rect = Rect2(a, Vector2.ZERO).expand(b).grow(60)
		"menu":
			rect = Rect2(Vector2(_root.size.x - 390, 18), Vector2(364, 50))
	_tutorial.hole = rect
	_tutorial.queue_redraw()
	_tut_card.reset_size()
	var screen := _root.size
	var pos := (screen - _tut_card.size) * 0.5
	if rect.size != Vector2.ZERO:
		pos.x = clampf(rect.get_center().x - _tut_card.size.x * 0.5, 30, screen.x - _tut_card.size.x - 30)
		if rect.get_center().y > screen.y * 0.5:
			pos.y = rect.position.y - _tut_card.size.y - 28
		else:
			pos.y = rect.end.y + 28
	_tut_card.position = pos


class TutorialDim:
	extends Control
	var hole := Rect2()

	func _draw() -> void:
		var dim := Color(0, 0, 0, 0.62)
		if hole.size == Vector2.ZERO:
			draw_rect(Rect2(Vector2.ZERO, size), dim)
			return
		var h := hole.grow(10)
		draw_rect(Rect2(0, 0, size.x, h.position.y), dim)
		draw_rect(Rect2(0, h.end.y, size.x, size.y - h.end.y), dim)
		draw_rect(Rect2(0, h.position.y, h.position.x, h.size.y), dim)
		draw_rect(Rect2(h.end.x, h.position.y, size.x - h.end.x, h.size.y), dim)
		draw_rect(h, Color(0.99, 0.86, 0.56), false, 2.0)


class ShoeBar:
	extends Control
	var dealt := 0.0
	var cut := 0.75

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		draw_rect(r, Color(1, 1, 1, 0.08))
		draw_rect(Rect2(Vector2.ZERO, Vector2(size.x * dealt, size.y)), Color(0.87, 0.72, 0.42, 0.85))
		var x := size.x * cut
		draw_line(Vector2(x, -3), Vector2(x, size.y + 3), Color(0.94, 0.42, 0.38), 2.0)
