class_name GameController
extends Node3D

const BlackjackEngine = preload("res://scripts/engine/blackjack_engine.gd")
const TableView = preload("res://scripts/table/table_view.gd")
const GameHUD = preload("res://scripts/ui/hud.gd")
const OverlayUI = preload("res://scripts/ui/overlay_ui.gd")
const ResultVFX = preload("res://scripts/vfx/result_vfx.gd")
const BJMoney = preload("res://scripts/engine/bj_money.gd")
const BJLog = preload("res://scripts/engine/bj_log.gd")

var engine: BlackjackEngine
var table: TableView
var hud: GameHUD
var overlay: OverlayUI
var vfx: ResultVFX
var _busy: bool = false
var _seated: bool = false


func _ready() -> void:
	engine = BlackjackEngine.new()
	StatsStore.hydrate_engine(engine)
	table = TableView.new()
	add_child(table)
	table.build()
	table.chip_clicked.connect(_on_chip)
	vfx = ResultVFX.new()
	add_child(vfx)
	hud = GameHUD.new()
	add_child(hud)
	hud.build()
	hud.action.connect(_on_hud_action)
	hud.chip.connect(_on_chip)
	overlay = OverlayUI.new()
	add_child(overlay)
	overlay.build()
	overlay.play.connect(_sit)
	overlay.resume.connect(_resume)
	overlay.restart_session.connect(_restart)
	overlay.main_menu.connect(_to_main)
	overlay.quit_game.connect(_quit)
	overlay.settings_changed.connect(_on_settings)
	SettingsStore.apply_display()
	_refresh()
	if not SettingsStore.seen_tutorial:
		overlay.show_page("tutorial")
	else:
		_sit()
	BJLog.info("Table ready")
	if not OS.get_environment("SF_BJ_SCREENSHOT").is_empty():
		await get_tree().process_frame
		await get_tree().process_frame
		_dump_screenshot(OS.get_environment("SF_BJ_SCREENSHOT"))
	var qa_mode := OS.get_environment("SF_BJ_QA")
	if qa_mode == "cards":
		await _qa_card_visibility()
	elif qa_mode == "full":
		await _qa_full_flow()


func _sit() -> void:
	overlay.hide_all()
	_seated = true
	_refresh()
	hud.set_status("Place a wager, then Deal")


func _resume() -> void:
	overlay.hide_all()
	_refresh()


func _to_main() -> void:
	overlay.show_page("main")


func _restart() -> void:
	StatsStore.reset_session_keep_lifetime()
	engine.reset_session()
	StatsStore.hydrate_engine(engine)
	table.clear_cards()
	table.set_bet_stack([])
	overlay.hide_all()
	hud.set_status("New session. $10,000 fictional bankroll.")
	_refresh()


func _quit() -> void:
	StatsStore.save_stats()
	SettingsStore.save_settings()
	get_tree().quit()


func _on_settings() -> void:
	table.apply_quality()
	_refresh()


func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	var key: int = event.physical_keycode
	if key == KEY_ESCAPE:
		if overlay.visible_page():
			if overlay.current == "pause":
				_resume()
			elif overlay.current in ["settings", "stats", "howto"]:
				overlay.show_page(overlay.settings_return if overlay.current == "settings" else "main")
			else:
				if overlay.current == "tutorial":
					SettingsStore.seen_tutorial = true
					SettingsStore.save_settings()
				overlay.hide_all()
		else:
			overlay.show_page("pause")
		return
	if overlay.visible_page() or _busy:
		return
	if key == KEY_F12:
		_dump_screenshot("/tmp/sfbj-qa/f12.png")
		return
	match key:
		KEY_SPACE:
			_try("deal")
		KEY_H:
			_try("hit")
		KEY_S:
			_try("stand")
		KEY_D:
			_try("double")
		KEY_P:
			_try("split")
		KEY_U:
			_try("surrender")
		KEY_R:
			_try("repeat")


func _on_hud_action(name: String) -> void:
	if name == "menu":
		overlay.show_page("pause")
		return
	_try(name)


func _on_chip(cents: int) -> void:
	if _busy or overlay.visible_page():
		return
	var r: Dictionary = engine.add_chip(cents)
	if r.get("ok", false):
		AudioManager.play("chip")
		table.set_bet_stack(engine.chip_stack)
		_refresh()


func _try(action: String) -> void:
	if _busy or overlay.visible_page():
		return
	if not engine.can(action) and action not in ["repeat"]:
		return
	match action:
		"deal":
			_do_deal()
		"hit":
			_do_simple(engine.hit(), "card")
		"stand":
			_do_simple(engine.stand(), "button")
		"double":
			_do_simple(engine.double_down(), "chip_stack")
		"split":
			_do_split()
		"surrender":
			_do_simple(engine.surrender(), "button")
		"insurance_yes":
			_do_insurance(true)
		"insurance_no":
			_do_insurance(false)
		"undo":
			if engine.undo_chip().get("ok", false):
				AudioManager.play("button")
				table.set_bet_stack(engine.chip_stack)
		"clear":
			if engine.clear_bet().get("ok", false):
				AudioManager.play("button")
				table.set_bet_stack([])
		"rebet":
			if engine.rebet().get("ok", false):
				AudioManager.play("chip_stack")
				table.set_bet_stack(engine.chip_stack)
		"repeat":
			if engine.rebet().get("ok", false):
				table.set_bet_stack(engine.chip_stack)
				_do_deal()
	_refresh()


func _do_deal() -> void:
	engine.dealer_hits_soft_17 = SettingsStore.dealer_hits_soft_17
	engine.late_surrender_enabled = SettingsStore.late_surrender
	var r: Dictionary = engine.deal()
	if not r.get("ok", false):
		return
	_busy = true
	table.set_bet_stack([])
	AudioManager.play("deal")
	var p = engine.player_hands[0]
	table.spawn_card(p.cards[0], true, table.player_card_pos(0, 0, 1), table.PLAYER_TILT, table.player_card_yaw(0, 0, 1))
	await _gap(0.18)
	table.spawn_card(engine.dealer.cards[0], false, table.dealer_card_pos(0), table.DEALER_TILT, 0.0)
	await _gap(0.16)
	table.spawn_card(p.cards[1], true, table.player_card_pos(0, 1, 1), table.PLAYER_TILT, table.player_card_yaw(0, 1, 1))
	await _gap(0.16)
	table.spawn_card(engine.dealer.cards[1], true, table.dealer_card_pos(1), table.DEALER_TILT, 0.0)
	_busy = false
	_after_action(r)


func _do_simple(r: Dictionary, sound: String) -> void:
	if not r.get("ok", false):
		return
	_busy = true
	AudioManager.play(sound)
	var added := _sync_new_cards()
	if added > 0:
		await _gap(0.34)
	_busy = false
	_after_action(r)


func _do_split() -> void:
	var r: Dictionary = engine.split()
	if not r.get("ok", false):
		return
	_busy = true
	AudioManager.play("card")
	table.clear_cards(true)
	_respawn_all(false)
	await _gap(0.34)
	_busy = false
	_after_action(r)


func _do_insurance(yes: bool) -> void:
	var r: Dictionary = engine.take_insurance(yes)
	if not r.get("ok", false):
		return
	AudioManager.play("insurance")
	_after_action(r)


func _after_action(r: Dictionary) -> void:
	if engine.phase == BlackjackEngine.Phase.SETTLE:
		_finish_settle()
	elif r.get("action", "") == "peek_blackjack" or engine.dealer.is_blackjack():
		_finish_settle()
	_refresh()


func _finish_settle() -> void:
	_busy = true
	table.reveal_dealer_hole()
	await _gap(0.28)
	_sync_new_cards()
	await _gap(0.2)
	StatsStore.apply_engine(engine)
	var kind := "push"
	if engine.last_results.size() > 0:
		kind = str(engine.last_results[0].get("outcome", "push"))
	for res in engine.last_results:
		if str(res.get("outcome", "")) == "blackjack":
			kind = "blackjack"
			break
	vfx.play(kind)
	match kind:
		"blackjack":
			AudioManager.play("blackjack")
			table.cinematic_push(0.12)
		"win":
			AudioManager.play("win")
			table.cinematic_push(0.05)
		"bust":
			AudioManager.play("bust")
		"lose":
			AudioManager.play("lose")
		"surrender":
			AudioManager.play("lose")
		_:
			AudioManager.play("push")
	hud.set_status(_result_text())
	_refresh()
	await _gap(1.15)
	table.clear_cards()
	engine.finish_round()
	table.set_bet_stack([])
	_busy = false
	hud.set_status("Place a wager, then Deal")
	_refresh()


func _sync_new_cards() -> int:
	var existing := {}
	var added := 0
	for c in table._cards:
		if c is Node and c.get("card"):
			existing[c.card.id()] = true
	var hc := engine.player_hands.size()
	for hi in hc:
		var hand = engine.player_hands[hi]
		for ci in hand.cards.size():
			var card = hand.cards[ci]
			if not existing.has(card.id()):
				table.spawn_card(card, true, table.player_card_pos(hi, ci, hc), table.PLAYER_TILT, table.player_card_yaw(hi, ci, hc))
				added += 1
	for ci in engine.dealer.cards.size():
		var card = engine.dealer.cards[ci]
		if not existing.has(card.id()):
			var up := ci > 0 or engine.phase == BlackjackEngine.Phase.SETTLE
			table.spawn_card(card, up, table.dealer_card_pos(ci), table.DEALER_TILT, 0.0)
			added += 1
	return added


func _respawn_all(reveal_hole: bool) -> void:
	var hc := engine.player_hands.size()
	for hi in hc:
		var hand = engine.player_hands[hi]
		for ci in hand.cards.size():
			table.spawn_card(hand.cards[ci], true, table.player_card_pos(hi, ci, hc), table.PLAYER_TILT, table.player_card_yaw(hi, ci, hc))
	for ci in engine.dealer.cards.size():
		var up := ci > 0 or reveal_hole
		table.spawn_card(engine.dealer.cards[ci], up, table.dealer_card_pos(ci), table.DEALER_TILT, 0.0)


func _result_text() -> String:
	var bits: PackedStringArray = PackedStringArray()
	for r in engine.last_results:
		bits.append(str(r.get("outcome", "")).capitalize())
	var net := BJMoney.format_signed(engine.last_net_cents)
	return "  ·  ".join(bits) + "   " + net


func _refresh() -> void:
	hud.refresh(engine, engine.legal_actions())
	if engine.phase == BlackjackEngine.Phase.INSURANCE:
		hud.set_status("Dealer shows an Ace. Take insurance?")
	elif engine.phase == BlackjackEngine.Phase.PLAYER:
		var hand = engine.player_hands[engine.active_hand]
		hud.set_status("Your hand  %d%s" % [hand.best_total(), "  (soft)" if hand.is_soft() else ""])
	elif engine.phase == BlackjackEngine.Phase.BETTING and engine.current_bet_cents > 0:
		hud.set_status("Press DEAL when you are ready")


func _gap(seconds: float) -> void:
	await get_tree().create_timer(seconds * SettingsStore.anim_scale()).timeout


func _dump_screenshot(path: String) -> void:
	var tex := get_viewport().get_texture()
	if tex == null:
		return
	var img := tex.get_image()
	if img == null:
		return
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	img.save_png(path)
	BJLog.event("screenshot %s  fps=%.1f" % [path, Engine.get_frames_per_second()])


func _qa_card_visibility() -> void:
	overlay.hide_all()
	SettingsStore.seen_tutorial = true
	SettingsStore.animation_speed = 1.8
	var Card := preload("res://scripts/engine/bj_card.gd")
	engine.reset_round()
	engine.add_chip(10000)
	engine.shoe.force_next([
		Card.parse("8S"),
		Card.parse("6D"),
		Card.parse("8H"),
		Card.parse("5C"),
		Card.parse("3S"),
		Card.parse("2H"),
	])
	await _do_deal()
	await _gap(0.85)
	_dump_screenshot(_qa_path("deal.png"))
	if engine.can("split"):
		await _do_split()
		await _gap(1.05)
		_dump_screenshot(_qa_path("split.png"))
	await _gap(0.25)
	get_tree().quit()


func _qa_full_flow() -> void:
	overlay.show_page("main")
	await get_tree().process_frame
	_dump_screenshot(_qa_path("main-menu.png"))
	overlay.show_page("settings")
	await get_tree().process_frame
	_dump_screenshot(_qa_path("settings.png"))
	overlay.show_page("howto")
	await get_tree().process_frame
	_dump_screenshot(_qa_path("how-to-play.png"))
	overlay.show_page("stats")
	await get_tree().process_frame
	_dump_screenshot(_qa_path("statistics.png"))
	overlay.show_page("pause")
	await get_tree().process_frame
	_dump_screenshot(_qa_path("pause.png"))
	overlay.hide_all()
	await get_tree().process_frame
	_dump_screenshot(_qa_path("table.png"))
	await _qa_card_visibility()


func _qa_path(filename: String) -> String:
	var root := OS.get_environment("SF_BJ_QA_OUTPUT")
	if root.is_empty():
		root = "/tmp/sfbj-qa"
	return root.path_join(filename)
