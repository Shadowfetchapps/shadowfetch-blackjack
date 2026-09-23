extends Node
## Scripted walkthrough used for visual QA and the documentation screenshots.
## Run with SF_BJ_QA=shots (and SHADOWFETCH_BJ_HOME pointing at a scratch folder).

const BJCard = preload("res://scripts/engine/bj_card.gd")

var c
var out_dir := ""


func run(controller, mode: String) -> void:
	c = controller
	out_dir = c._qa_out("")
	SettingsStore.seen_tutorial = true
	SettingsStore.animation_speed = 1.6
	if not c.table.textures_baked:
		await c.table.textures_ready
	await _frames(20)
	match mode:
		"shots":
			await _shots()
		"smoke":
			await _smoke()
		_:
			await _shots()


func _shots() -> void:
	await _sleep(2.5)
	await _shot("main-menu.png")
	c.overlay.show_page("settings")
	await _sleep(0.4)
	await _shot("settings.png")
	c.overlay.show_page("rules")
	await _sleep(0.4)
	await _shot("rules.png")
	c.overlay.show_page("chart")
	await _sleep(0.4)
	await _shot("strategy-chart.png")
	c.overlay.show_page("howto")
	await _sleep(0.4)
	await _shot("how-to-play.png")
	c._sit()
	await _sleep(1.4)
	# Betting with side bets.
	c._selected_chip = 2500
	c._add_chip("main", 10000)
	c._add_chip("main", 2500)
	c._add_chip("pp", 500)
	c._add_chip("t3", 500)
	await _sleep(0.6)
	await _shot("betting.png")
	# A perfect pair + a pat hand.
	_force(["0:QH", "KS", "1:QH", "7C"])
	await c._deal()
	await _sleep(0.3)
	await _shot("deal.png")
	await c._player_action("stand")
	await _sleep(0.25)
	await _shot("win.png")
	await c._next_hand(false)
	# Split with the coach's hint.
	SettingsStore.coach_mode = "coach"
	c._add_chip("main", 10000)
	_force(["8S", "6D", "8H", "5C", "3D", "KH", "2S", "9C", "10D"])
	await c._deal()
	await c._player_action("split")
	await _sleep(0.3)
	c._show_hint()
	await _sleep(0.5)
	await _shot("split.png")
	await c._player_action("double")
	await _sleep(0.3)
	await c._player_action("stand")
	await _sleep(0.3)
	await _shot("split-result.png")
	await c._next_hand(false)
	# Blackjack.
	c._add_chip("main", 10000)
	_force(["AS", "9D", "KH", "6C"])
	await c._deal()
	await _sleep(0.2)
	await _shot("blackjack.png")
	await c._next_hand(false)
	# Insurance offer.
	c._add_chip("main", 10000)
	_force(["10S", "7D", "9H", "AC"])
	await c._deal()
	await _sleep(0.4)
	await _shot("insurance.png")
	await c._insurance(false)
	if c.engine.phase == 2:
		await c._player_action("stand")
	await c._next_hand(false)
	# Overhead camera with the count trainer.
	SettingsStore.show_count = true
	c._toggle_camera()
	c._add_chip("main", 2500)
	_force(["5S", "10D", "6H", "4C", "9S"])
	await c._deal()
	await _sleep(1.2)
	await _shot("overhead.png")
	c._toggle_camera()
	await c._player_action("hit")
	await c._next_hand(false)
	# Pages that need played hands.
	c.overlay.show_page("stats")
	await _sleep(0.4)
	await _shot("statistics.png")
	c.overlay.show_page("history")
	await _sleep(0.4)
	await _shot("history.png")
	c.overlay.show_page("achievements")
	await _sleep(0.4)
	await _shot("achievements.png")
	c.overlay.hide_all()
	c.overlay.show_page("pause")
	await _sleep(0.4)
	await _shot("pause.png")
	c.overlay.hide_all()
	c.hud.start_tutorial()
	c.hud._next_tutorial()
	await _sleep(0.5)
	await _shot("tutorial.png")


func _smoke() -> void:
	c._sit()
	for i in 12:
		c._add_chip("main", 2500)
		await c._deal()
		var guard := 0
		while c.engine.phase in [1, 2] and guard < 10:
			guard += 1
			if c.engine.phase == 1:
				await c._insurance(false)
			else:
				var hint: String = c.engine.hint()
				await c._player_action(hint if c.engine.can(hint) else "stand")
		await c._next_hand(false)
	print("[qa] smoke ok  bankroll=%d hands=%d fps=%.1f" % [c.engine.bankroll_cents, c.engine.hands_played, Engine.get_frames_per_second()])


func _force(tokens: Array) -> void:
	var cards: Array = []
	for t in tokens:
		cards.append(BJCard.parse(str(t)))
	c.engine.shoe.force_next(cards)


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	c._screenshot(out_dir.path_join(name))


func _sleep(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame
