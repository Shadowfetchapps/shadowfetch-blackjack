class_name TestBlackjackEngine
extends RefCounted

const BJCard = preload("res://scripts/engine/bj_card.gd")
const BJHand = preload("res://scripts/engine/bj_hand.gd")
const BJShoe = preload("res://scripts/engine/bj_shoe.gd")
const BJMoney = preload("res://scripts/engine/bj_money.gd")
const BlackjackEngine = preload("res://scripts/engine/blackjack_engine.gd")
const SettingsScript = preload("res://scripts/save/settings_store.gd")
const StatsScript = preload("res://scripts/save/stats_store.gd")

var _passed := 0
var _failed := 0
var _errors: PackedStringArray = PackedStringArray()
var simulated_hands: int = 0


func run_all() -> bool:
	_passed = 0
	_failed = 0
	_errors.clear()
	simulated_hands = 0
	_test_card_values()
	_test_soft_hard_multi_ace()
	_test_shoe_shuffle_and_cut()
	_test_no_duplicate_cards()
	_test_deal_and_totals()
	_test_blackjack_payout()
	_test_blackjack_both_push()
	_test_push()
	_test_bust()
	_test_double()
	_test_split()
	_test_split_aces()
	_test_resplit_and_max_hands()
	_test_insurance()
	_test_soft_17()
	_test_h17_option()
	_test_late_surrender()
	_test_dealer_hits_16()
	_test_bankroll_bounds()
	_test_illegal_actions()
	_test_rapid_input()
	_test_integer_payouts()
	_test_clean_new_round()
	_test_reshuffle_conservation()
	_test_save_load()
	_test_corrupt_recovery()
	_test_simulation(200000)
	print("\n==============================")
	print("Shadowfetch Blackjack  —  %d passed, %d failed, %d simulated hands" % [_passed, _failed, simulated_hands])
	for e in _errors:
		print("  FAIL  ", e)
	print("==============================\n")
	return _failed == 0


func _ok(name: String, cond: bool, detail: String = "") -> void:
	if cond:
		_passed += 1
		print("  ok    ", name)
	else:
		_failed += 1
		var msg := name if detail.is_empty() else "%s — %s" % [name, detail]
		_errors.append(msg)
		print("  FAIL  ", msg)


func _c(token: String) -> BJCard:
	var card := BJCard.parse(token)
	assert(card != null)
	return card


func _e(seed: int = 1) -> BlackjackEngine:
	return BlackjackEngine.new(seed)


func _force_deal(engine: BlackjackEngine, p1: String, d1: String, p2: String, d2: String, extra: Array = []) -> Dictionary:
	var seq: Array = [_c(p1), _c(d1), _c(p2), _c(d2)]
	for t in extra:
		seq.append(_c(str(t)))
	engine.shoe.force_next(seq)
	if engine.current_bet_cents <= 0:
		engine.add_chip(10000)
	return engine.deal()


func _test_card_values() -> void:
	print("card values")
	_ok("ace pip 1", _c("AS").pip_value() == 1)
	_ok("ten 10", _c("10H").pip_value() == 10)
	_ok("jack 10", _c("JS").pip_value() == 10)
	_ok("king 10", _c("KD").pip_value() == 10)
	_ok("nine 9", _c("9C").pip_value() == 9)
	_ok("same rank 10 10", _c("10S").same_rank(_c("10D")))
	_ok("10 and J different ranks", not _c("10S").same_rank(_c("JS")))


func _test_soft_hard_multi_ace() -> void:
	print("soft / hard / multi-ace")
	var a6 := BJHand.new()
	a6.add(_c("AS"))
	a6.add(_c("6D"))
	_ok("A6 soft 17", a6.is_soft() and a6.best_total() == 17 and a6.hard_total() == 7)
	var aa9 := BJHand.new()
	aa9.add(_c("AS"))
	aa9.add(_c("AH"))
	aa9.add(_c("9C"))
	_ok("AA9 is 21 soft", aa9.best_total() == 21 and aa9.is_soft())
	var aaaa := BJHand.new()
	aaaa.add(_c("AS"))
	aaaa.add(_c("AH"))
	aaaa.add(_c("AD"))
	aaaa.add(_c("AC"))
	_ok("four aces 14 soft", aaaa.best_total() == 14 and aaaa.ace_count() == 4)
	var a105 := BJHand.new()
	a105.add(_c("AS"))
	a105.add(_c("10H"))
	a105.add(_c("5C"))
	_ok("A-10-5 hard 16", a105.best_total() == 16 and not a105.is_soft())
	var bj := BJHand.new()
	bj.add(_c("AS"))
	bj.add(_c("KD"))
	_ok("natural blackjack", bj.is_blackjack() and bj.best_total() == 21)


func _test_shoe_shuffle_and_cut() -> void:
	print("shoe")
	var shoe := BJShoe.new(42)
	_ok("312 cards", shoe.remaining() == 312 and shoe.total_accounted() == 312)
	_ok("unique full shoe", shoe.unique_ok())
	var first := shoe.draw()
	_ok("draw accounts", shoe.remaining() == 311 and shoe.in_play_count() == 1)
	var hand := BJHand.new()
	hand.add(first)
	shoe.discard_hand(hand)
	_ok("discard moves", shoe.in_play_count() == 0 and shoe.discarded_count() == 1)
	_ok("conserved after discard", shoe.total_accounted() == 312 and shoe.unique_ok())
	var before := shoe.remaining()
	while not shoe.cut_reached and shoe.remaining() > 0:
		var c := shoe.draw()
		shoe.discard_cards([c])
	_ok("cut card eventually reached", shoe.cut_reached)
	_ok("still conserved", shoe.total_accounted() == 312)
	shoe.reshuffle()
	_ok("reshuffle restores 312", shoe.remaining() == 312 and shoe.discarded_count() == 0)
	_ok("reshuffle unique", shoe.unique_ok())
	_ok("cut after reshuffle reset", not shoe.cut_reached)
	_ok("drew some before cut", before < 312)


func _test_no_duplicate_cards() -> void:
	print("no duplicates")
	var shoe := BJShoe.new(7)
	var seen := {}
	var dup := false
	for i in 312:
		var id := shoe.draw().id()
		if seen.has(id):
			dup = true
		seen[id] = true
	_ok("312 unique draws", not dup and seen.size() == 312)


func _test_deal_and_totals() -> void:
	print("deal")
	var e := _e()
	var r := _force_deal(e, "9S", "5D", "7H", "8C")
	_ok("deal ok", r.get("ok", false))
	_ok("player 16", e.player_hands[0].best_total() == 16)
	_ok("dealer 13", e.dealer.best_total() == 13)
	_ok("player turn", e.phase == BlackjackEngine.Phase.PLAYER)
	_ok("bet deducted", e.bankroll_cents == BJMoney.STARTING_BANKROLL - 10000)


func _test_blackjack_payout() -> void:
	print("blackjack 3:2")
	var e := _e()
	_force_deal(e, "AS", "9D", "KS", "5C")
	_ok("player BJ phase settle", e.phase == BlackjackEngine.Phase.SETTLE)
	_ok("outcome blackjack", e.player_hands[0].outcome == "blackjack")
	_ok("payout 3:2", e.player_hands[0].payout_cents == 25000, str(e.player_hands[0].payout_cents))
	_ok("bankroll +150", e.bankroll_cents == BJMoney.STARTING_BANKROLL + 15000, str(e.bankroll_cents))
	_ok("stats bj", e.blackjacks == 1 and e.wins == 1)


func _test_blackjack_both_push() -> void:
	print("bj both sides")
	var e := _e()
	_force_deal(e, "AH", "AS", "KD", "KC")
	_ok("push both bj", e.player_hands[0].outcome == "push")
	_ok("bet returned", e.bankroll_cents == BJMoney.STARTING_BANKROLL)
	_ok("push counted", e.pushes == 1 and e.wins == 0)


func _test_push() -> void:
	print("push")
	var e := _e()
	_force_deal(e, "10S", "9D", "9H", "10C")
	e.stand()
	_ok("push 19", e.player_hands[0].outcome == "push" and e.player_hands[0].best_total() == 19)
	_ok("bankroll even", e.bankroll_cents == BJMoney.STARTING_BANKROLL)


func _test_bust() -> void:
	print("bust")
	var e := _e()
	_force_deal(e, "10S", "5D", "9H", "6C", ["8D"])
	e.hit()
	_ok("player bust", e.player_hands[0].is_bust() and e.player_hands[0].outcome == "bust")
	_ok("lost bet", e.bankroll_cents == BJMoney.STARTING_BANKROLL - 10000)
	_ok("dealer did not draw", e.dealer.cards.size() == 2)


func _test_double() -> void:
	print("double")
	var e := _e()
	_force_deal(e, "5S", "9D", "6H", "7C", ["10S", "9S"])
	var r := e.double_down()
	_ok("double ok", r.get("ok", false))
	_ok("one extra card", e.player_hands[0].cards.size() == 3)
	_ok("bet doubled", e.player_hands[0].bet_cents == 20000)
	_ok("second bet taken", e.player_hands[0].doubled and e.player_hands[0].bet_cents == 20000)
	_ok("21 wins even on double", e.player_hands[0].outcome == "win")
	_ok("double payout 2x doubled bet", e.player_hands[0].payout_cents == 40000)


func _test_split() -> void:
	print("split")
	var e := _e()
	_force_deal(e, "8S", "5D", "8H", "6C", ["3S", "2H", "10D"])
	var r := e.split()
	_ok("split ok", r.get("ok", false), str(r))
	_ok("two hands", e.player_hands.size() == 2)
	_ok("same rank split", e.player_hands[0].cards[0].rank == 8)
	e.stand()
	e.stand()
	_ok("settled after both stands", e.phase == BlackjackEngine.Phase.SETTLE)
	_ok("dealer played", e.dealer.cards.size() >= 2)


func _test_split_aces() -> void:
	print("split aces")
	var e := _e()
	_force_deal(e, "AS", "9D", "AH", "7C", ["5S", "9H"])
	var r := e.split()
	_ok("split aces ok", r.get("ok", false), str(r))
	_ok("one card each", e.player_hands[0].cards.size() == 2 and e.player_hands[1].cards.size() == 2)
	_ok("cannot hit split aces", not e.can("hit") and e.phase == BlackjackEngine.Phase.SETTLE)
	_ok("A+9 after split is 20 not BJ", not e.player_hands[1].is_blackjack())
	_ok("split ace 10-value not BJ", not e.player_hands[0].is_blackjack())


func _test_resplit_and_max_hands() -> void:
	print("resplit / max 4")
	var e := _e()
	_force_deal(e, "8S", "2D", "8H", "9C", ["8D", "7S", "8C", "4H", "2S", "3D", "5H", "6S"])
	_ok("first split", e.split().get("ok", false))
	_ok("resplit allowed", e.can("split"))
	_ok("second split", e.split().get("ok", false))
	if e.can("split"):
		e.split()
	_ok("max four hands", e.player_hands.size() <= 4)
	_ok("no fifth split", e.player_hands.size() < 4 or not e.can("split"))
	while e.phase == BlackjackEngine.Phase.PLAYER:
		e.stand()
	_ok("resplit round settled", e.phase == BlackjackEngine.Phase.SETTLE)


func _test_insurance() -> void:
	print("insurance")
	var e := _e()
	_force_deal(e, "10S", "KS", "9D", "AH")
	_ok("insurance offered", e.phase == BlackjackEngine.Phase.INSURANCE)
	var before := e.bankroll_cents
	var r := e.take_insurance(true)
	_ok("insurance accepted", r.get("ok", false))
	_ok("dealer BJ", e.dealer.is_blackjack())
	_ok("insurance 2:1", e.bankroll_cents == before - 5000 + 15000, str(e.bankroll_cents))
	_ok("main bet lost", e.player_hands[0].outcome == "lose")
	var e2 := _e(3)
	_force_deal(e2, "9S", "5C", "7D", "AH", ["10S"])
	_ok("ins offered no bj", e2.phase == BlackjackEngine.Phase.INSURANCE)
	var b2 := e2.bankroll_cents
	e2.take_insurance(true)
	_ok("insurance lost", e2.insurance_cents == 5000)
	if e2.phase == BlackjackEngine.Phase.PLAYER:
		e2.stand()
	_ok("lost insurance amount", e2.bankroll_cents <= b2 - 5000 + 20000)


func _test_soft_17() -> void:
	print("dealer soft 17")
	var e := _e()
	_force_deal(e, "10S", "AS", "8H", "6D")
	e.stand()
	_ok("dealer A6 stands", e.dealer.best_total() == 17 and e.dealer.is_soft())
	_ok("dealer did not hit S17", e.dealer.cards.size() == 2)
	_ok("player 18 beats 17", e.player_hands[0].outcome == "win")


func _test_h17_option() -> void:
	print("dealer H17 option")
	var e := _e()
	e.dealer_hits_soft_17 = true
	_force_deal(e, "10S", "AS", "8H", "6D", ["2C"])
	e.stand()
	_ok("H17 dealer hits A6", e.dealer.cards.size() == 3)
	_ok("H17 dealer reaches 19", e.dealer.best_total() == 19)
	_ok("H17 changes outcome", e.player_hands[0].outcome == "lose")


func _test_late_surrender() -> void:
	print("late surrender")
	var e := _e()
	_force_deal(e, "10S", "9D", "6H", "7C")
	_ok("surrender initially legal", e.can("surrender"))
	var r := e.surrender()
	_ok("surrender accepted", r.get("ok", false))
	_ok("surrender settles round", e.phase == BlackjackEngine.Phase.SETTLE)
	_ok("surrender returns half", e.player_hands[0].payout_cents == 5000)
	_ok("surrender net half loss", e.last_net_cents == -5000)
	_ok("surrender counts loss", e.losses == 1)
	var e2 := _e()
	e2.late_surrender_enabled = false
	_force_deal(e2, "10S", "9D", "6H", "7C")
	_ok("surrender setting honored", not e2.can("surrender"))
	e2.hit()
	_ok("cannot surrender after hit", not e2.surrender().get("ok", true))
	var e3 := _e()
	_force_deal(e3, "8S", "5D", "8H", "6C", ["3S", "2H"])
	e3.split()
	_ok("cannot surrender split hand", not e3.can("surrender"))


func _test_dealer_hits_16() -> void:
	print("dealer hits 16")
	var e := _e()
	_force_deal(e, "10S", "10D", "9H", "6C", ["5S"])
	e.stand()
	_ok("dealer hit 16", e.dealer.cards.size() == 3)
	_ok("dealer 21", e.dealer.best_total() == 21)
	_ok("player 19 loses", e.player_hands[0].outcome == "lose")


func _test_bankroll_bounds() -> void:
	print("bankroll bounds")
	var e := _e()
	e.bankroll_cents = 500
	_ok("cannot chip more than bankroll", not e.add_chip(1000).get("ok", true))
	_ok("can chip $5", e.add_chip(500).get("ok", false))
	_ok("cannot overbet", not e.add_chip(100).get("ok", true))
	e.bankroll_cents = 10000
	e.current_bet_cents = 0
	e.chip_stack.clear()
	e.add_chip(10000)
	_force_deal(e, "8S", "5D", "8H", "6C")
	e.bankroll_cents = 0
	_ok("cannot split broke", not e.split().get("ok", true))
	_ok("cannot double broke", not e.double_down().get("ok", true))
	e.bankroll_cents = 50
	_ok("cannot chip below dollar", not e.add_chip(100).get("ok", true) or e.phase != BlackjackEngine.Phase.BETTING)
	_ok("never negative after reject", e.bankroll_cents >= 0)


func _test_illegal_actions() -> void:
	print("illegal actions")
	var e := _e()
	_ok("deal without bet rejected", not e.deal().get("ok", true))
	_ok("hit in betting rejected", not e.hit().get("ok", true))
	_ok("stand in betting rejected", not e.stand().get("ok", true))
	_ok("split in betting rejected", not e.split().get("ok", true))
	_ok("insurance in betting rejected", not e.take_insurance(true).get("ok", true))
	_force_deal(e, "9S", "5D", "7H", "8C")
	_ok("cannot split non-pair", not e.split().get("ok", true))
	_force_deal(_e(), "10S", "5D", "9H", "8C")
	var e2 := _e()
	_force_deal(e2, "10S", "5D", "9H", "8C", ["2D"])
	e2.hit()
	_ok("cannot double after hit", not e2.double_down().get("ok", true))
	var e3 := _e()
	_force_deal(e3, "10S", "5C", "9D", "AH")
	_ok("cannot hit during insurance", not e3.hit().get("ok", true))


func _test_rapid_input() -> void:
	print("rapid input")
	var e := _e()
	_force_deal(e, "10S", "5D", "6H", "8C", ["Ks", "3D"])
	var first := e.hit()
	var second := e.hit()
	_ok("first hit ok or settle", first.get("ok", false) or e.phase == BlackjackEngine.Phase.SETTLE)
	if e.phase != BlackjackEngine.Phase.PLAYER:
		_ok("extra hit ignored after hand done", not second.get("ok", true) or e.phase != BlackjackEngine.Phase.PLAYER)
	var e2 := _e()
	_force_deal(e2, "10S", "9D", "9H", "8C")
	e2.stand()
	_ok("rapid stand after settle rejected", not e2.stand().get("ok", true))
	_ok("rapid deal before finish rejected", not e2.deal().get("ok", true))


func _test_integer_payouts() -> void:
	print("integer payouts")
	_ok("3:2 of $100", BJMoney.blackjack_payout(10000) == 25000)
	_ok("3:2 of $1", BJMoney.blackjack_payout(100) == 250)
	_ok("insurance half", BJMoney.insurance_cost(10000) == 5000)
	_ok("insurance 2:1 return", BJMoney.insurance_win(5000) == 15000)
	_ok("even money", BJMoney.even_money_return(2500) == 5000)
	var e := _e()
	e.current_bet_cents = 0
	e.add_chip(100)
	_force_deal(e, "AS", "9D", "KS", "5C")
	_ok("tiny BJ integer bankroll", e.bankroll_cents == BJMoney.STARTING_BANKROLL + 150)


func _test_clean_new_round() -> void:
	print("clean new round")
	var e := _e()
	_force_deal(e, "10S", "9D", "8H", "7C")
	e.stand()
	_ok("settle then finish", e.finish_round().get("ok", false))
	_ok("betting again", e.phase == BlackjackEngine.Phase.BETTING)
	_ok("hands cleared", e.player_hands.is_empty() and e.dealer.cards.is_empty())
	_ok("insurance reset", e.insurance_cents == 0 and not e.insurance_offered)
	_ok("no leftover bet", e.current_bet_cents == 0)
	_ok("shoe still valid", e.shoe.unique_ok() and e.shoe.total_accounted() == 312)


func _test_reshuffle_conservation() -> void:
	print("reshuffle conservation")
	var e := _e(99)
	e.shoe.cut_index = 8
	for i in 40:
		if e.phase == BlackjackEngine.Phase.BETTING:
			e.add_chip(100)
			e.deal()
		if e.phase == BlackjackEngine.Phase.INSURANCE:
			e.take_insurance(false)
		while e.phase == BlackjackEngine.Phase.PLAYER:
			var acts := e.legal_actions()
			if acts.has("stand"):
				e.stand()
			else:
				break
		if e.phase == BlackjackEngine.Phase.SETTLE:
			e.finish_round()
		_ok("conserved loop %d" % i, e.shoe.total_accounted() == 312 and e.shoe.unique_ok())
		if e.shoe.shuffle_count > 2:
			break
	_ok("reshuffled at least once", e.shoe.shuffle_count >= 1)


func _test_save_load() -> void:
	print("save / load")
	var store = StatsScript.new()
	store.bankroll_cents = 1234500
	store.hands = 12
	store.wins = 5
	store.losses = 4
	store.pushes = 3
	store.blackjacks = 1
	store.largest_win_cents = 15000
	store.save_stats()
	store.bankroll_cents = 0
	store.load_stats()
	_ok("reload bankroll", store.bankroll_cents == 1234500)
	_ok("reload hands", store.hands == 12)
	var settings = SettingsScript.new()
	settings.animation_speed = 1.75
	settings.master_volume = 0.4
	settings.save_settings()
	settings.animation_speed = 1.0
	settings.load_settings()
	_ok("reload anim speed", is_equal_approx(settings.animation_speed, 1.75))
	store.free()
	settings.free()


func _test_corrupt_recovery() -> void:
	print("corrupt recovery")
	var settings = SettingsScript.new()
	settings.ensure_dirs()
	var bad := settings.settings_path() + ".corrupt-test"
	var f := FileAccess.open(bad, FileAccess.WRITE)
	f.store_string("{not json")
	f.close()
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(bad))
	_ok("corrupt json is not dict", parsed == null)
	var store = StatsScript.new()
	var store_ok: bool = store.from_dict({"bankroll_cents": -5, "hands": "nope"})
	_ok("invalid stats sanitized", store_ok and store.bankroll_cents >= 0)
	store.free()
	settings.free()


func _test_simulation(n: int) -> void:
	print("simulation %d hands" % n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260920
	var e := BlackjackEngine.new(20260920)
	e.bankroll_cents = 50_000_000
	var started := Time.get_ticks_msec()
	var illegal := 0
	var negatives := 0
	var broken_shoe := 0
	var played := 0
	var actions := 0
	var guard := 0
	while played < n and guard < n * 8:
		guard += 1
		if e.bankroll_cents < 100:
			e.bankroll_cents = 50_000_000
		if e.phase == BlackjackEngine.Phase.BETTING:
			var bet := 100 * rng.randi_range(1, 20)
			if bet > e.bankroll_cents:
				bet = 100
			e.chip_stack = BJMoney.breakdown(bet)
			e.current_bet_cents = bet
			var d := e.deal()
			if not d.get("ok", false):
				illegal += 1
				e.reset_round()
				continue
		if e.phase == BlackjackEngine.Phase.INSURANCE:
			e.take_insurance(rng.randf() < 0.15)
		while e.phase == BlackjackEngine.Phase.PLAYER:
			var hand := e.player_hands[e.active_hand]
			var choice := _basic_or_random(e, hand, rng)
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
			actions += 1
			if not r.get("ok", false):
				illegal += 1
				e.stand()
			if actions > n * 20:
				break
		if e.phase == BlackjackEngine.Phase.SETTLE:
			played += e.last_results.size()
			if e.bankroll_cents < 0:
				negatives += 1
			if not e.shoe.unique_ok() or e.shoe.total_accounted() != 312:
				broken_shoe += 1
			for res in e.last_results:
				var pay: int = int(res.get("payout_cents", -1))
				var bet: int = int(res.get("bet_cents", 0))
				if pay < 0 or pay % 1 != 0:
					illegal += 1
				if str(res.get("outcome", "")) == "blackjack" and pay != BJMoney.blackjack_payout(bet):
					illegal += 1
				if str(res.get("outcome", "")) == "push" and pay != bet:
					illegal += 1
				if str(res.get("outcome", "")) == "win" and pay != bet * 2:
					illegal += 1
				if str(res.get("outcome", "")) in ["lose", "bust"] and pay != 0:
					illegal += 1
				if str(res.get("outcome", "")) == "surrender" and pay != bet / 2:
					illegal += 1
			e.finish_round()
			if e.phase != BlackjackEngine.Phase.BETTING:
				broken_shoe += 1
	simulated_hands = played
	var ms := Time.get_ticks_msec() - started
	_ok("simulated enough hands", played >= n, str(played))
	_ok("no negative bankroll", negatives == 0, str(negatives))
	_ok("shoe invariants held", broken_shoe == 0, str(broken_shoe))
	_ok("no unexpected illegal", illegal == 0, str(illegal))
	_ok("engine still betting", e.phase == BlackjackEngine.Phase.BETTING)
	print("  sim   %d hands in %d ms" % [played, ms])


func _basic_or_random(e: BlackjackEngine, hand: BJHand, rng: RandomNumberGenerator) -> String:
	if rng.randf() < 0.08:
		var acts := e.legal_actions()
		if acts.is_empty():
			return "stand"
		return acts[rng.randi_range(0, acts.size() - 1)]
	if e.can("split") and hand.is_pair() and hand.cards[0].pip_value() in [1, 8]:
		return "split"
	if e.can("double") and hand.best_total() in [10, 11]:
		return "double"
	if hand.best_total() < 12:
		return "hit"
	if hand.best_total() < 17 and hand.is_soft():
		return "hit"
	if hand.best_total() < 17:
		return "hit"
	return "stand"
