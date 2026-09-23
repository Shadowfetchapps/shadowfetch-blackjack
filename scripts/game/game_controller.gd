class_name GameController
extends Node3D
## Runs the table session: feeds player input to the engine, then sequences the
## table animations, HUD, audio, statistics and achievements for each result.

const BlackjackEngine = preload("res://scripts/engine/blackjack_engine.gd")
const BJMoney = preload("res://scripts/engine/bj_money.gd")
const BJStrategy = preload("res://scripts/engine/bj_strategy.gd")
const BJLog = preload("res://scripts/engine/bj_log.gd")
const TableView = preload("res://scripts/table/table_view.gd")
const TableLayout = preload("res://scripts/table/table_layout.gd")
const GameHUD = preload("res://scripts/ui/hud.gd")
const OverlayUI = preload("res://scripts/ui/overlay_ui.gd")
const ThemeFactoryRef = preload("res://scripts/ui/theme_factory.gd")
const Phase = BlackjackEngine.Phase

var engine: BlackjackEngine
var table: TableView
var hud: GameHUD
var overlay: OverlayUI
var _busy := false
var _seated := false
var _awaiting_next := false
var _auto_clear_id := 0
var _selected_chip := 2500


func _ready() -> void:
	engine = BlackjackEngine.new(0, SettingsStore.rules)
	StatsStore.hydrate_engine(engine)
	table = TableView.new()
	add_child(table)
	table.build()
	table.spot_clicked.connect(_on_spot_clicked)
	hud = GameHUD.new()
	add_child(hud)
	hud.build(table)
	hud.action.connect(_on_action)
	hud.chip_pressed.connect(_on_chip_pressed)
	hud.tutorial_finished.connect(_on_tutorial_finished)
	overlay = OverlayUI.new()
	overlay.engine = engine
	add_child(overlay)
	overlay.build()
	overlay.play.connect(_sit)
	overlay.resume.connect(_resume)
	overlay.restart_session.connect(_restart)
	overlay.main_menu.connect(_to_main)
	overlay.quit_game.connect(_quit)
	overlay.rebuy.connect(_rebuy)
	overlay.settings_changed.connect(_on_settings_changed)
	overlay.appearance_changed.connect(_on_appearance_changed)
	overlay.replay_tutorial.connect(_replay_tutorial)
	overlay.page_changed.connect(_on_page_changed)
	SettingsStore.rules_changed.connect(_on_rules_saved)
	Achievements.unlocked.connect(hud.show_achievement)
	_selected_chip = _default_chip()
	table.update_shoe(engine)
	table.bake_textures(engine.rules)
	hud.refresh(engine, _ctx())
	hud.set_visible_hud(false)
	table.rig.set_mode("orbit", true)
	AudioManager.set_scene("menu")
	overlay.show_page("main")
	BJLog.info("Table ready")
	var qa := OS.get_environment("SF_BJ_QA")
	if not qa.is_empty():
		_run_qa.call_deferred(qa)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_save_on_exit()


# --- session ----------------------------------------------------------------

func _sit() -> void:
	overlay.hide_all()
	_seated = true
	hud.set_visible_hud(true)
	table.rig.set_mode(SettingsStore.camera_mode)
	AudioManager.set_scene("table")
	_refresh()
	if not SettingsStore.seen_tutorial:
		hud.start_tutorial()
	elif engine.is_broke():
		overlay.show_page("broke")


func _resume() -> void:
	overlay.hide_all()
	if not _seated:
		_sit()
		return
	_refresh()


func _to_main() -> void:
	_seated = false
	hud.set_visible_hud(false)
	table.rig.set_mode("orbit")
	AudioManager.set_scene("menu")
	overlay.show_page("main", false)


func _restart() -> void:
	# Let any in-flight round animation finish before the table is reset under it.
	while _busy:
		await get_tree().process_frame
	_auto_clear_id += 1
	StatsStore.reset_session_keep_lifetime()
	engine.reset_session()
	StatsStore.hydrate_engine(engine)
	_awaiting_next = false
	_busy = false
	table.clear_cards_now()
	table.clear_bet_stacks()
	table.update_shoe(engine)
	hud.hide_result()
	hud.set_settled_view(false)
	overlay.hide_all()
	if not _seated:
		_sit()
	hud.toast("New session  ·  $10,000 in fictional chips")
	_refresh()


func _rebuy() -> void:
	var r := engine.rebuy()
	overlay.hide_all()
	if r.get("ok", false):
		StatsStore.note_rebuy(engine.bankroll_cents)
		Achievements.unlock("fresh_stack")
		hud.toast("Fresh stack  ·  %s" % BJMoney.format_short(engine.bankroll_cents), ThemeFactoryRef.GOLD_BRIGHT)
	if not _seated:
		_sit()
	_refresh()


func _quit() -> void:
	_save_on_exit()
	get_tree().quit()


func _save_on_exit() -> void:
	# A hand in progress is void: its wagers were never saved, so the next launch
	# resumes with the bankroll from before the deal.
	if engine.phase == Phase.BETTING:
		StatsStore.apply_engine(engine)
	SettingsStore.save_settings()


func _replay_tutorial() -> void:
	overlay.hide_all()
	if not _seated:
		_sit()
	hud.start_tutorial()


func _on_tutorial_finished() -> void:
	SettingsStore.seen_tutorial = true
	SettingsStore.save_settings()
	_refresh()


func _on_page_changed(name: String) -> void:
	if name == "main":
		table.rig.set_mode("orbit")


func _on_settings_changed() -> void:
	table.apply_quality()
	_refresh()


func _on_appearance_changed() -> void:
	table.apply_appearance(engine.rules)
	if _seated:
		table.rig.set_mode(SettingsStore.camera_mode)


func _on_rules_saved() -> void:
	if engine.phase == Phase.BETTING and not _busy and not _awaiting_next:
		_apply_pending_rules()
	else:
		hud.toast("New table rules apply from the next deal")


## Brings the engine to the saved rules between rounds. Returns true if the shoe was replaced.
func _apply_pending_rules() -> bool:
	if engine.rules.equals(SettingsStore.rules):
		return false
	var r := engine.set_rules(SettingsStore.rules)
	table.rebake_felt(engine.rules)
	table.show_pending_bets(engine)
	table.update_shoe(engine)
	hud.toast("Table rules updated  ·  %s" % engine.rules.short_summary())
	_refresh()
	return bool(r.get("reshuffled", false))


# --- input ------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		_on_key(event.physical_keycode)
	elif event is InputEventJoypadButton and event.pressed:
		_on_pad(event.button_index)


func _on_key(key: int) -> void:
	if key == KEY_ESCAPE:
		_on_escape()
		return
	if overlay.visible_page() or hud.tutorial_active() or not _seated:
		return
	match key:
		KEY_SPACE:
			if _awaiting_next:
				_next_hand(true)
			else:
				_do("deal")
		KEY_ENTER, KEY_KP_ENTER:
			if _awaiting_next:
				_next_hand(false)
			else:
				_do("deal")
		KEY_H:
			_do("hit")
		KEY_S:
			_do("stand")
		KEY_D:
			_do("double")
		KEY_P:
			_do("split")
		KEY_U:
			_do("surrender")
		KEY_T:
			_do("hint")
		KEY_Y, KEY_I:
			_do("insurance_yes")
		KEY_N:
			_do("insurance_no")
		KEY_R:
			if _awaiting_next:
				_next_hand(true)
			elif engine.pending_total() == 0:
				_do("repeat")
			else:
				_do("deal")
		KEY_Z, KEY_BACKSPACE:
			_do("undo")
		KEY_X, KEY_DELETE:
			_do("clear")
		KEY_C:
			_toggle_camera()
		KEY_F1:
			overlay.show_page("howto")
		KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6:
			var i := key - KEY_1
			_on_chip_pressed(BJMoney.CHIP_VALUES[i])
		KEY_F12:
			_screenshot(OS.get_environment("HOME").path_join("Pictures/shadowfetch-blackjack-%d.png" % Time.get_unix_time_from_system()))


func _on_pad(button: int) -> void:
	if button == JOY_BUTTON_START:
		_on_escape()
		return
	if overlay.visible_page():
		if button == JOY_BUTTON_B:
			overlay.back()
		return
	if hud.tutorial_active() or not _seated:
		return
	match engine.phase:
		Phase.BETTING:
			if _awaiting_next:
				if button == JOY_BUTTON_Y or button == JOY_BUTTON_X:
					_next_hand(true)
				elif button == JOY_BUTTON_A:
					_next_hand(false)
				return
			match button:
				JOY_BUTTON_A:
					_add_chip("main", _selected_chip)
				JOY_BUTTON_Y:
					_do("deal")
				JOY_BUTTON_X:
					_do("repeat" if engine.pending_total() == 0 else "rebet")
				JOY_BUTTON_B:
					_do("undo")
				JOY_BUTTON_BACK:
					_do("clear")
				JOY_BUTTON_LEFT_SHOULDER, JOY_BUTTON_RIGHT_SHOULDER:
					_cycle_chip(1 if button == JOY_BUTTON_RIGHT_SHOULDER else -1)
		Phase.INSURANCE:
			if button == JOY_BUTTON_A:
				_do("insurance_yes")
			elif button == JOY_BUTTON_B:
				_do("insurance_no")
		Phase.PLAYER:
			match button:
				JOY_BUTTON_A:
					_do("hit")
				JOY_BUTTON_B:
					_do("stand")
				JOY_BUTTON_X:
					_do("double")
				JOY_BUTTON_Y:
					_do("split")
				JOY_BUTTON_LEFT_SHOULDER:
					_do("surrender")
				JOY_BUTTON_RIGHT_SHOULDER:
					_do("hint")
				JOY_BUTTON_BACK:
					_toggle_camera()
		Phase.SETTLE:
			if _awaiting_next:
				if button == JOY_BUTTON_Y or button == JOY_BUTTON_X:
					_next_hand(true)
				elif button == JOY_BUTTON_A:
					_next_hand(false)


func _on_escape() -> void:
	if hud.tutorial_active():
		return
	if overlay.visible_page():
		overlay.back()
	elif _seated:
		overlay.show_page("pause")


func _on_action(name: String) -> void:
	match name:
		"menu":
			overlay.show_page("pause")
		"chart":
			overlay.show_page("chart")
		"next_new":
			_next_hand(false)
		"next_repeat":
			_next_hand(true)
		_:
			_do(name)


func _on_chip_pressed(cents: int) -> void:
	_selected_chip = cents
	_add_chip("main", cents)


func _on_spot_clicked(spot: String, button: int) -> void:
	if overlay.visible_page() or hud.tutorial_active() or not _seated:
		return
	if button == 2:
		if engine.phase == Phase.BETTING and not _busy and engine.remove_chip(spot).get("ok", false):
			AudioManager.play("chip")
			table.show_pending_bets(engine)
			_refresh()
		return
	_add_chip(spot, _selected_chip)


func _add_chip(spot: String, cents: int) -> void:
	if _busy or overlay.visible_page():
		return
	if _awaiting_next:
		await _clear_table()
	if engine.phase != Phase.BETTING:
		return
	_apply_pending_rules()
	var r := engine.add_chip(cents, spot)
	if r.get("ok", false):
		AudioManager.play("chip")
		table.show_pending_bets(engine, spot)
	else:
		_explain(str(r.get("reason", "")))
	_refresh()


func _cycle_chip(dir: int) -> void:
	var i := BJMoney.CHIP_VALUES.find(_selected_chip)
	i = wrapi(i + dir, 0, BJMoney.CHIP_VALUES.size())
	_selected_chip = BJMoney.CHIP_VALUES[i]
	AudioManager.play("ui_hover")
	_refresh()


func _toggle_camera() -> void:
	SettingsStore.camera_mode = "overhead" if SettingsStore.camera_mode == "seated" else "seated"
	SettingsStore.save_settings()
	table.rig.set_mode(SettingsStore.camera_mode)


func _explain(reason: String) -> void:
	match reason:
		"insufficient_bankroll":
			hud.toast("Not enough in your bankroll for that chip", ThemeFactoryRef.BAD)
		"table_max":
			hud.toast("Table maximum reached ($10,000 main · $1,000 side bets)", ThemeFactoryRef.BAD)
		"side_bets_off":
			hud.toast("Side bets are switched off in Table Rules", ThemeFactoryRef.MUTED)


# --- actions ----------------------------------------------------------------

func _do(action: String) -> void:
	if _busy or overlay.visible_page() or not _seated:
		return
	match action:
		"deal":
			await _deal()
		"repeat":
			if engine.can_rebet():
				engine.rebet()
				table.show_pending_bets(engine)
				await _deal()
		"rebet":
			if engine.rebet().get("ok", false):
				AudioManager.play("chip_stack")
				table.show_pending_bets(engine)
		"undo":
			if engine.undo_chip().get("ok", false):
				AudioManager.play("chip")
				table.show_pending_bets(engine)
		"clear":
			if engine.clear_bet().get("ok", false):
				AudioManager.play("chip_stack")
				table.show_pending_bets(engine)
		"hint":
			_show_hint()
		"insurance_yes", "insurance_no":
			await _insurance(action == "insurance_yes")
		"hit", "stand", "double", "split", "surrender":
			await _player_action(action)
	_refresh()


func _deal() -> void:
	if engine.phase != Phase.BETTING or engine.pending_bet() <= 0:
		return
	var reshuffled := _apply_pending_rules()
	var shuffling := reshuffled or engine.shoe.needs_reshuffle()
	var r := engine.deal()
	if not r.get("ok", false):
		_explain(str(r.get("reason", "")))
		return
	_busy = true
	hud.set_settled_view(false)
	hud.hide_result()
	_refresh()
	if shuffling:
		hud.toast("Shuffling a fresh shoe")
		AudioManager.play("shuffle")
		table.update_shoe(engine)
		await _wait(1.3)
	table.show_round_bets(engine)
	await _wait(table.sync_cards(engine))
	table.update_shoe(engine)
	if not engine.side_results.is_empty():
		hud.show_side_results(engine.side_results)
		var won := false
		for s in engine.side_results:
			won = won or int(s["payout"]) > 0
		await _wait(table.resolve_side_bets(engine) * (0.8 if won else 0.4))
	if engine.phase == Phase.INSURANCE:
		AudioManager.play("insurance")
		_busy = false
		_refresh()
		return
	await _after_initial()


func _after_initial() -> void:
	var up = engine.dealer_upcard()
	if up != null and (up.is_ace() or up.is_ten_value()):
		await _wait(table.peek_hole(engine))
	if engine.phase == Phase.SETTLE:
		await _settle()
		return
	_busy = false
	_refresh()


func _insurance(accept: bool) -> void:
	if engine.phase != Phase.INSURANCE:
		return
	var r := engine.take_insurance(accept)
	if not r.get("ok", false):
		_explain(str(r.get("reason", "")))
		return
	_busy = true
	_coach_feedback()
	if engine.insurance_cents > 0:
		table.show_round_bets(engine)
		await _wait(0.45)
	if str(r.get("action", "")) == "even_money":
		await _settle()
		return
	await _after_initial()


func _player_action(action: String) -> void:
	if engine.phase != Phase.PLAYER or not engine.can(action):
		return
	var r: Dictionary
	match action:
		"hit":
			r = engine.hit()
		"stand":
			r = engine.stand()
		"double":
			r = engine.double_down()
		"split":
			r = engine.split()
		"surrender":
			r = engine.surrender()
	if not r.get("ok", false):
		return
	_busy = true
	_coach_feedback()
	match action:
		"double", "split":
			AudioManager.play("chip_stack")
		"stand":
			AudioManager.play("card_place")
	table.show_round_bets(engine)
	_refresh()
	await _wait(table.sync_cards(engine))
	table.update_shoe(engine)
	if engine.phase == Phase.SETTLE:
		await _settle()
		return
	_busy = false
	_refresh()


func _settle() -> void:
	_busy = true
	table.rig.focus_x = 0.0
	_refresh()
	var sc := SettingsStore.anim_scale()
	var d := table.sync_cards(engine, 0.5 * sc, 2.2)
	await _wait(d + 0.2 * sc)
	table.update_shoe(engine)
	hud.set_settled_view(true)
	var chips := table.settle_chips(engine)
	_result_fx()
	hud.show_result(engine)
	StatsStore.record_round(engine.round_record)
	Achievements.evaluate(engine.round_record, StatsStore)
	await _wait(chips)
	_awaiting_next = true
	_busy = false
	_refresh()
	_schedule_auto_clear()


## Clears the table by itself a few seconds after a result unless the player acts first.
func _schedule_auto_clear() -> void:
	_auto_clear_id += 1
	var my_id := _auto_clear_id
	await _wait(2.8)
	if _awaiting_next and my_id == _auto_clear_id and not overlay.visible_page() and not _busy:
		await _clear_table()
		_refresh()


func _result_fx() -> void:
	var best := ""
	var n := engine.player_hands.size()
	for i in n:
		var h = engine.player_hands[i]
		match str(h.outcome):
			"blackjack":
				best = "blackjack"
				table.celebrate("blackjack", TableLayout.player_bet(i, n))
			"win", "even_money":
				if best != "blackjack":
					best = "win"
				table.celebrate("win", TableLayout.player_bet(i, n))
	if best.is_empty():
		var net := engine.last_net_cents
		if net == 0:
			best = "push"
		else:
			var all_bust := true
			for h in engine.player_hands:
				all_bust = all_bust and h.outcome == "bust"
			best = "bust" if all_bust else "lose"
	AudioManager.play(best)


## Clears the finished round from the table and returns to betting.
func _clear_table() -> void:
	if not _awaiting_next:
		return
	_awaiting_next = false
	_busy = true
	hud.hide_result()
	var d := table.collect_cards()
	await _wait(d)
	engine.finish_round()
	hud.set_settled_view(false)
	hud.clear_badges()
	table.clear_bet_stacks()
	table.update_shoe(engine)
	StatsStore.apply_engine(engine)
	_busy = false
	_apply_pending_rules()
	if engine.is_broke() and _seated:
		overlay.show_page("broke")


func _next_hand(repeat: bool) -> void:
	if _busy or not _awaiting_next:
		return
	await _clear_table()
	if repeat and engine.can_rebet():
		engine.rebet()
		table.show_pending_bets(engine)
		await _deal()
	_refresh()


# --- coach ------------------------------------------------------------------

func _coach_feedback() -> void:
	var d := engine.last_decision
	if d.is_empty() or SettingsStore.coach_mode != "coach":
		return
	if d.get("correct", false):
		hud.coach("%s — matches basic strategy" % BJStrategy.action_title(d["action"]), true)
		AudioManager.play("coach_good")
	else:
		hud.coach("Basic strategy: %s  (%s)" % [BJStrategy.action_title(d["recommended"]).to_upper(), d["situation"]], false)
		AudioManager.play("coach_bad")


func _show_hint() -> void:
	var rec := engine.hint()
	if rec.is_empty():
		return
	var situation := "insurance vs A"
	if engine.phase == Phase.PLAYER:
		situation = BJStrategy.situation_text(engine.player_hands[engine.active_hand], engine.dealer_upcard())
	hud.coach("Basic strategy: %s  (%s)" % [BJStrategy.action_title(rec).to_upper(), situation], false)
	hud.highlight_action(rec)


# --- helpers ----------------------------------------------------------------

func _ctx() -> Dictionary:
	return {"busy": _busy, "awaiting": _awaiting_next, "selected": _selected_chip}


func _refresh() -> void:
	hud.refresh(engine, _ctx())
	var betting := engine.phase == Phase.BETTING and not _busy and _seated
	table.set_spot_available("main", betting and not _awaiting_next)
	table.set_spot_available("pp", betting and engine.rules.side_bets and not _awaiting_next)
	table.set_spot_available("t3", betting and engine.rules.side_bets and not _awaiting_next)
	if engine.phase == Phase.PLAYER and engine.player_hands.size() > 1:
		table.rig.focus_x = TableLayout.hand_x(engine.active_hand, engine.player_hands.size()) * 0.6
	elif engine.phase != Phase.PLAYER:
		table.rig.focus_x = 0.0


func _default_chip() -> int:
	var last: int = engine.last_bet_cents
	for v in [10000, 2500, 500, 100]:
		if last >= v:
			return v
	return 2500


func _wait(seconds: float) -> void:
	if seconds <= 0.0:
		return
	await get_tree().create_timer(seconds).timeout


func _screenshot(path: String) -> void:
	var img := get_viewport().get_texture().get_image()
	if img == null:
		return
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	img.save_png(path)
	BJLog.event("screenshot %s  fps=%.1f" % [path, Engine.get_frames_per_second()])


# --- QA / screenshot harness (SF_BJ_QA=shots) ------------------------------

func _qa_out(name: String) -> String:
	var root := OS.get_environment("SF_BJ_QA_OUTPUT")
	if root.is_empty():
		root = OS.get_environment("TMPDIR") if not OS.get_environment("TMPDIR").is_empty() else "/tmp"
		root = root.path_join("sfbj-qa")
	return root.path_join(name)


func _run_qa(mode: String) -> void:
	var QA := preload("res://scripts/game/qa_harness.gd")
	var qa = QA.new()
	add_child(qa)
	await qa.run(self, mode)
	get_tree().quit()
