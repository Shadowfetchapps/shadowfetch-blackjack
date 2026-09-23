class_name TestSimulation
extends "res://tests/test_base.gd"
## Randomized long-run simulation across several rule sets. A basic-strategy player
## with 8% random legal actions, random side bets and occasional insurance.

var hands_target := 200000


func run() -> void:
	var configs: Array = [
		{"name": "6D S17 DAS LS", "rules": {}},
		{"name": "6D H17 no LS", "rules": {"dealer_hits_soft_17": true, "late_surrender": false}},
		{"name": "1D 6:5 split-to-2", "rules": {"decks": 1, "blackjack_pays_6_5": true, "max_hands": 2, "double_after_split": false, "late_surrender": false, "penetration": 0.65}},
		{"name": "8D RSA", "rules": {"decks": 8, "resplit_aces": true, "penetration": 0.85}},
		{"name": "2D H17 no DAS split-to-3", "rules": {"decks": 2, "dealer_hits_soft_17": true, "double_after_split": false, "max_hands": 3}},
	]
	var per := hands_target / configs.size()
	for i in configs.size():
		_simulate(configs[i], per, 20260920 + i)


func _simulate(config: Dictionary, n: int, seed_value: int) -> void:
	var rules := BJRules.new()
	rules.from_dict(config["rules"])
	section("simulation %s — %d hands" % [config["name"], n])
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var e := BlackjackEngine.new(seed_value, rules)
	e.bankroll_cents = 50_000_000
	var started := Time.get_ticks_msec()
	var illegal := 0
	var negatives := 0
	var broken_shoe := 0
	var money_mismatch := 0
	var payout_mismatch := 0
	var side_mismatch := 0
	var hand_limit := 0
	var played := 0
	var guard := 0
	var main_wagered := 0
	var main_net := 0
	while played < n and guard < n * 8:
		guard += 1
		if e.bankroll_cents < 200_000:
			e.bankroll_cents = 50_000_000
		var before := e.bankroll_cents
		var bet := 100 * rng.randi_range(1, 25)
		e.set_bet(bet)
		if rng.randf() < 0.3:
			e.set_bet(100 * rng.randi_range(1, 5), "pp")
		if rng.randf() < 0.3:
			e.set_bet(100 * rng.randi_range(1, 5), "t3")
		if not e.deal().get("ok", false):
			illegal += 1
			e.clear_bet()
			continue
		var first_two: Array = [e.player_hands[0].cards[0], e.player_hands[0].cards[1]]
		var up_card: BJCard = e.dealer.cards[1]
		if e.phase == BlackjackEngine.Phase.INSURANCE:
			if not e.take_insurance(rng.randf() < 0.1).get("ok", false):
				e.take_insurance(false)
		var actions := 0
		while e.phase == BlackjackEngine.Phase.PLAYER and actions < 40:
			actions += 1
			var choice := e.hint()
			if rng.randf() < 0.08:
				var acts := e.legal_actions()
				choice = acts[rng.randi_range(0, acts.size() - 1)]
			if not e.can(choice):
				illegal += 1
				choice = "stand"
			var r: Dictionary
			match choice:
				"hit":
					r = e.hit()
				"double":
					r = e.double_down()
				"split":
					r = e.split()
				"surrender":
					r = e.surrender()
				_:
					r = e.stand()
			if not r.get("ok", false):
				illegal += 1
				e.stand()
		if e.phase != BlackjackEngine.Phase.SETTLE:
			illegal += 1
			e.reset_round()
			continue
		played += e.last_results.size()
		if e.player_hands.size() > rules.max_hands:
			hand_limit += 1
		if e.bankroll_cents < 0:
			negatives += 1
		if e.bankroll_cents - before != e.last_net_cents:
			money_mismatch += 1
		if not e.shoe.unique_ok():
			broken_shoe += 1
		for res in e.last_results:
			var pay: int = int(res["payout_cents"])
			var b: int = int(res["bet_cents"])
			main_wagered += b
			main_net += pay - b
			var expected := -1
			match str(res["outcome"]):
				"blackjack":
					expected = BJMoney.blackjack_payout(b, rules.blackjack_pays_6_5)
				"push":
					expected = b
				"win", "even_money":
					expected = b * 2
				"lose", "bust":
					expected = 0
				"surrender":
					expected = b / 2
			if pay != expected:
				payout_mismatch += 1
		for s in e.side_results:
			var want := ""
			if s["kind"] == "pp":
				want = BJSideBets.perfect_pairs(first_two[0], first_two[1])
			else:
				want = BJSideBets.twenty_one_three(first_two[0], first_two[1], up_card)
			if s["result"] != want or int(s["payout"]) != BJSideBets.payout(s["kind"], want, int(s["stake"])):
				side_mismatch += 1
		e.finish_round()
		if e.phase != BlackjackEngine.Phase.BETTING:
			broken_shoe += 1
	simulated_hands += played
	var ms := Time.get_ticks_msec() - started
	ok("simulated enough hands", played >= n, str(played))
	ok("no negative bankroll", negatives == 0, str(negatives))
	ok("shoe invariants held", broken_shoe == 0, str(broken_shoe))
	ok("money conserved every round", money_mismatch == 0, str(money_mismatch))
	ok("main payouts match table", payout_mismatch == 0, str(payout_mismatch))
	ok("side bets match evaluator", side_mismatch == 0, str(side_mismatch))
	ok("hand limit respected", hand_limit == 0, str(hand_limit))
	ok("no unexpected illegal", illegal == 0, str(illegal))
	ok("engine back to betting", e.phase == BlackjackEngine.Phase.BETTING)
	var ret := 100.0 * float(main_net) / maxf(float(main_wagered), 1.0)
	print("  sim   %d hands in %d ms · main-bet return %.2f%% (≈ -%.2f%% edge estimate, 8%% random play)" % [played, ms, ret, rules.house_edge_percent()])
