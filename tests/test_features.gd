class_name TestFeatures
extends "res://tests/test_base.gd"
## Table rules, side bets, even money, basic strategy, the coach, counting, records.


func run() -> void:
	_test_rules_model()
	_test_rules_shoe()
	_test_six_five()
	_test_das_off()
	_test_resplit_aces()
	_test_even_money()
	_test_perfect_pairs()
	_test_twenty_one_three()
	_test_side_bet_settlement()
	_test_strategy_chart()
	_test_strategy_recommend()
	_test_coach_judging()
	_test_hilo_count()
	_test_round_record()


func _test_rules_model() -> void:
	section("rules model")
	var r := BJRules.new()
	ok("defaults 6D S17 3:2 DAS LS", r.decks == 6 and not r.dealer_hits_soft_17 and not r.blackjack_pays_6_5 and r.double_after_split and r.late_surrender)
	ok("default edge ≈0.33%", absf(r.house_edge_percent() - 0.33) < 0.005, str(r.house_edge_percent()))
	ok("default matches Vegas Strip preset", r.matching_preset() == "strip")
	var h17 := r.duplicate_rules()
	h17.dealer_hits_soft_17 = true
	ok("H17 raises edge", h17.house_edge_percent() > r.house_edge_percent())
	var sixfive := r.duplicate_rules()
	sixfive.blackjack_pays_6_5 = true
	ok("6:5 raises edge by 1.39", absf(sixfive.house_edge_percent() - r.house_edge_percent() - 1.39) < 0.001)
	var one := r.duplicate_rules()
	one.decks = 1
	ok("fewer decks lowers edge", one.house_edge_percent() < r.house_edge_percent())
	var bad := BJRules.new()
	bad.from_dict({"decks": 5, "max_hands": 9, "penetration": 2.0, "late_surrender": false})
	ok("invalid decks rejected", bad.decks == 6)
	ok("invalid max hands rejected", bad.max_hands == 4)
	ok("penetration clamped", is_equal_approx(bad.penetration, BJRules.PENETRATION_MAX))
	ok("valid key applied", not bad.late_surrender)
	var round_trip := BJRules.new()
	round_trip.from_dict(sixfive.to_dict())
	ok("dict round trip", round_trip.equals(sixfive))
	for key in BJRules.PRESETS:
		var p := BJRules.new()
		p.apply_preset(key)
		ok("preset %s recognised" % key, p.matching_preset() == key)
	ok("summary text", r.summary().contains("6 DECKS") and r.summary().contains("S17"))
	ok("felt text follows rules", h17.soft17_text() == "DEALER HITS SOFT 17" and sixfive.blackjack_ratio_text() == "6 TO 5")


func _test_rules_shoe() -> void:
	section("rules → shoe")
	for decks in BJRules.DECK_OPTIONS:
		var r := BJRules.new()
		r.decks = decks
		var e := engine(11, r)
		ok("%d-deck shoe capacity" % decks, e.shoe.capacity == decks * 52 and e.shoe.unique_ok())
	var e2 := engine(12)
	var r2 := BJRules.new()
	r2.decks = 2
	var res := e2.set_rules(r2)
	ok("deck change rebuilds shoe", res.get("reshuffled", false) and e2.shoe.capacity == 104)
	var r3 := r2.duplicate_rules()
	r3.dealer_hits_soft_17 = true
	ok("non-shoe rule keeps shoe", not e2.set_rules(r3).get("reshuffled", true))


func _test_six_five() -> void:
	section("6:5 blackjack")
	var r := BJRules.new()
	r.blackjack_pays_6_5 = true
	var e := engine(1, r)
	force_deal(e, "AS", "9D", "KS", "5C")
	ok("6:5 payout", e.player_hands[0].payout_cents == 22000, str(e.player_hands[0].payout_cents))
	ok("6:5 net", e.last_net_cents == 12000)


func _test_das_off() -> void:
	section("no double after split")
	var r := BJRules.new()
	r.double_after_split = false
	var e := engine(1, r)
	force_deal(e, "8S", "5D", "8H", "6C", ["3S", "2H", "10D"])
	e.split()
	ok("split hand cannot double without DAS", not e.can("double"))
	var e2 := engine()
	force_deal(e2, "8S", "5D", "8H", "6C", ["3S", "2H", "10D"])
	e2.split()
	ok("split hand can double with DAS", e2.can("double"))


func _test_resplit_aces() -> void:
	section("resplit aces")
	var r := BJRules.new()
	r.resplit_aces = true
	var e := engine(1, r)
	force_deal(e, "AS", "9D", "AH", "7C", ["AD", "5H", "8C", "9S", "2C"])
	e.split()
	ok("ace pair stays open with RSA", e.phase == BlackjackEngine.Phase.PLAYER and e.active_hand == 0)
	ok("only split or stand on ace pair", e.can("split") and not e.can("hit") and not e.can("double"))
	e.split()
	ok("resplit aces to three hands", e.player_hands.size() == 3)
	ok("round settles once aces are dealt", e.phase == BlackjackEngine.Phase.SETTLE)
	var e2 := engine()
	force_deal(e2, "AS", "9D", "AH", "7C", ["AD", "5H", "2C"])
	e2.split()
	ok("no RSA closes the ace pair", e2.phase == BlackjackEngine.Phase.SETTLE and e2.player_hands.size() == 2)


func _test_even_money() -> void:
	section("even money")
	var e := engine()
	force_deal(e, "AS", "9D", "KS", "AC")
	ok("even money offered on BJ vs ace", e.phase == BlackjackEngine.Phase.INSURANCE and e.even_money_offered)
	ok("even money legal while broke", e.can("insurance_yes"))
	e.take_insurance(true)
	ok("even money settles", e.phase == BlackjackEngine.Phase.SETTLE and e.player_hands[0].outcome == "even_money")
	ok("even money pays 1:1", e.last_net_cents == 10000 and e.player_hands[0].payout_cents == 20000)
	ok("even money recorded", e.round_record.get("even_money", false))
	ok("counts as blackjack win", e.wins == 1 and e.blackjacks == 1)
	var e2 := engine()
	force_deal(e2, "AS", "9D", "KS", "AC")
	e2.take_insurance(false)
	ok("declined even money pays 3:2", e2.player_hands[0].outcome == "blackjack" and e2.last_net_cents == 15000)
	var e3 := engine()
	force_deal(e3, "AS", "KD", "KS", "AC")
	e3.take_insurance(false)
	ok("declined even money vs dealer BJ pushes", e3.player_hands[0].outcome == "push" and e3.last_net_cents == 0)


func _test_perfect_pairs() -> void:
	section("perfect pairs")
	ok("perfect pair", BJSideBets.perfect_pairs(card("0:QH"), card("1:QH")) == "perfect")
	ok("colored pair", BJSideBets.perfect_pairs(card("QH"), card("QD")) == "colored")
	ok("colored black pair", BJSideBets.perfect_pairs(card("7S"), card("7C")) == "colored")
	ok("mixed pair", BJSideBets.perfect_pairs(card("QH"), card("QS")) == "mixed")
	ok("10/K is not a pair", BJSideBets.perfect_pairs(card("10H"), card("KH")) == "")
	ok("pays 25/12/6", BJSideBets.payout("pp", "perfect", 100) == 2600 and BJSideBets.payout("pp", "colored", 100) == 1300 and BJSideBets.payout("pp", "mixed", 100) == 700)
	ok("loss pays nothing", BJSideBets.payout("pp", "", 100) == 0)
	for d: int in [1, 2, 4, 6, 8]:
		var rest: float = 52.0 * d - 1.0
		var ev: float = (25.0 * (d - 1) + 12.0 * d + 6.0 * 2.0 * d) / rest - (1.0 - (4.0 * d - 1.0) / rest)
		ok("perfect pairs edge table %d decks" % d, absf(-ev * 100.0 - BJSideBets.house_edge("pp", d)) < 0.01, "%.3f" % (-ev * 100.0))


func _test_twenty_one_three() -> void:
	section("21+3")
	ok("suited trips", BJSideBets.twenty_one_three(card("0:8D"), card("1:8D"), card("2:8D")) == "suited_trips")
	ok("straight flush", BJSideBets.twenty_one_three(card("9S"), card("10S"), card("JS")) == "straight_flush")
	ok("three of a kind", BJSideBets.twenty_one_three(card("8D"), card("8S"), card("8C")) == "three_kind")
	ok("straight", BJSideBets.twenty_one_three(card("9S"), card("10H"), card("JS")) == "straight")
	ok("ace-low straight", BJSideBets.twenty_one_three(card("AS"), card("2H"), card("3D")) == "straight")
	ok("ace-high straight", BJSideBets.twenty_one_three(card("QS"), card("KH"), card("AD")) == "straight")
	ok("no wrap-around", BJSideBets.twenty_one_three(card("KS"), card("AH"), card("2D")) == "")
	ok("flush", BJSideBets.twenty_one_three(card("2C"), card("9C"), card("KC")) == "flush")
	ok("pair is not a win", BJSideBets.twenty_one_three(card("2C"), card("2D"), card("KC")) == "")
	ok("nothing", BJSideBets.twenty_one_three(card("2C"), card("9D"), card("KS")) == "")
	ok("100:1 return", BJSideBets.payout("t3", "suited_trips", 500) == 50500)
	# Exhaustive single-deck check: 22,100 three-card combinations → known category counts.
	var counts := {"straight_flush": 0, "three_kind": 0, "straight": 0, "flush": 0, "": 0}
	var deck: Array = []
	for s in 4:
		for r in range(1, 14):
			deck.append(BJCard.new(s, r, 0))
	for i in 52:
		for j in range(i + 1, 52):
			for k in range(j + 1, 52):
				var res := BJSideBets.twenty_one_three(deck[i], deck[j], deck[k])
				counts[res] = int(counts.get(res, 0)) + 1
	ok("single deck straight flushes = 48", counts["straight_flush"] == 48, str(counts))
	ok("single deck trips = 52", counts["three_kind"] == 52, str(counts))
	ok("single deck straights = 720", counts["straight"] == 720, str(counts))
	ok("single deck flushes = 1096", counts["flush"] == 1096, str(counts))


func _test_side_bet_settlement() -> void:
	section("side bet settlement")
	var e := engine()
	e.add_chip(10000)
	e.add_chip(500, "pp")
	e.add_chip(100, "t3")
	var before := e.bankroll_cents
	force_deal(e, "8H", "5D", "8D", "10C", ["5S"])
	ok("side bets deducted and paid at deal", e.bankroll_cents == before - 10600 + 6500, str(e.bankroll_cents))
	ok("colored pair result", e.side_results.size() == 2 and e.side_results[0]["result"] == "colored")
	ok("21+3 loses", e.side_results[1]["result"] == "" and e.side_results[1]["payout"] == 0)
	e.stand()
	ok("round net includes side bets", e.last_net_cents == -10000 + 6000 - 100, str(e.last_net_cents))
	ok("record lists side bets", e.round_record["side"].size() == 2)
	ok("wagered includes side bets", e.round_record["wagered"] == 10600)
	var e2 := engine()
	e2.add_chip(10000)
	e2.add_chip(100, "t3")
	force_deal(e2, "9H", "KD", "10H", "JH")
	ok("21+3 straight flush 40:1", e2.side_results[0]["result"] == "straight_flush" and e2.side_results[0]["payout"] == 4100)


func _test_strategy_chart() -> void:
	section("basic strategy chart")
	var s17 := BJRules.new()
	var h17 := BJRules.new()
	h17.dealer_hits_soft_17 = true
	ok("hard 16 vs 10 surrender", BJStrategy.hard_code(16, 10, s17) == "Rh")
	ok("hard 16 vs 7 hit", BJStrategy.hard_code(16, 7, s17) == "H")
	ok("hard 16 vs 6 stand", BJStrategy.hard_code(16, 6, s17) == "S")
	ok("hard 15 vs A hit S17", BJStrategy.hard_code(15, 11, s17) == "H")
	ok("hard 15 vs A surrender H17", BJStrategy.hard_code(15, 11, h17) == "Rh")
	ok("hard 17 vs A surrender H17", BJStrategy.hard_code(17, 11, h17) == "Rs")
	ok("hard 12 vs 3 hit", BJStrategy.hard_code(12, 3, s17) == "H")
	ok("hard 12 vs 4 stand", BJStrategy.hard_code(12, 4, s17) == "S")
	ok("hard 11 vs A hit S17 6D", BJStrategy.hard_code(11, 11, s17) == "H")
	ok("hard 11 vs A double H17", BJStrategy.hard_code(11, 11, h17) == "D")
	ok("hard 10 vs 10 hit", BJStrategy.hard_code(10, 10, s17) == "H")
	ok("hard 9 vs 2 hit (6D)", BJStrategy.hard_code(9, 2, s17) == "H")
	var dd := BJRules.new()
	dd.decks = 2
	ok("hard 9 vs 2 double (2D)", BJStrategy.hard_code(9, 2, dd) == "D")
	ok("soft 18 vs 2 stand S17", BJStrategy.soft_code(18, 2, s17) == "S")
	ok("soft 18 vs 2 double H17", BJStrategy.soft_code(18, 2, h17) == "Ds")
	ok("soft 18 vs 9 hit", BJStrategy.soft_code(18, 9, s17) == "H")
	ok("soft 19 vs 6 double H17", BJStrategy.soft_code(19, 6, h17) == "Ds")
	ok("soft 17 vs 3 double", BJStrategy.soft_code(17, 3, s17) == "D")
	ok("soft 13 vs 4 hit", BJStrategy.soft_code(13, 4, s17) == "H")
	ok("A,A split", BJStrategy.pair_code(11, 11, s17) == "P")
	ok("8,8 vs A split S17", BJStrategy.pair_code(8, 11, s17) == "P")
	ok("8,8 vs A surrender H17", BJStrategy.pair_code(8, 11, h17) == "Rp")
	ok("9,9 vs 7 stand", BJStrategy.pair_code(9, 7, s17) == "")
	ok("4,4 vs 5 split with DAS", BJStrategy.pair_code(4, 5, s17) == "Ph")
	ok("10,10 never split", BJStrategy.pair_code(10, 6, s17) == "")
	var chart := BJStrategy.chart(s17)
	ok("chart sizes", chart["hard"].size() == 11 and chart["soft"].size() == 8 and chart["pairs"].size() == 10)
	ok("chart 5,5 row shows doubles", chart["pairs"][3][1][0] == "D")
	var no_ls := BJRules.new()
	no_ls.late_surrender = false
	no_ls.double_after_split = false
	var chart2 := BJStrategy.chart(no_ls)
	ok("chart hides surrender when off", chart2["hard"][8][1][8] == "H")
	ok("chart 2,2 vs 2 hits without DAS", chart2["pairs"][0][1][0] == "H")
	ok("chart 2,2 vs 2 splits with DAS", chart["pairs"][0][1][0] == "P")


func _test_strategy_recommend() -> void:
	section("basic strategy advice")
	var r := BJRules.new()
	ok("11 vs 6 double", BJStrategy.recommend(hand_of(["6S", "5D"]), card("6C"), r, true, false, true) == "double")
	ok("11 vs 6 hit when cannot double", BJStrategy.recommend(hand_of(["6S", "3D", "2H"]), card("6C"), r, false, false, false) == "hit")
	ok("16 vs 10 surrender", BJStrategy.recommend(hand_of(["10S", "6D"]), card("KC"), r, true, false, true) == "surrender")
	ok("16 vs 10 hit without surrender", BJStrategy.recommend(hand_of(["10S", "6D"]), card("KC"), r, true, false, false) == "hit")
	ok("8,8 vs 10 split", BJStrategy.recommend(hand_of(["8S", "8D"]), card("10C"), r, true, true, true) == "split")
	ok("8,8 at max hands plays 16", BJStrategy.recommend(hand_of(["8S", "8D"]), card("10C"), r, true, false, false) == "hit")
	ok("soft 18 vs 4 double", BJStrategy.recommend(hand_of(["AS", "7D"]), card("4C"), r, true, false, true) == "double")
	ok("soft 18 3-card vs 4 stand", BJStrategy.recommend(hand_of(["AS", "4D", "3H"]), card("4C"), r, false, false, false) == "stand")
	ok("A,A split", BJStrategy.recommend(hand_of(["AS", "AD"]), card("KC"), r, true, true, true) == "split")
	ok("situation text", BJStrategy.situation_text(hand_of(["8S", "8D"]), card("AC")) == "pair of 8s vs A")


func _test_coach_judging() -> void:
	section("coach judging")
	var e := engine()
	force_deal(e, "6S", "5D", "5H", "6C", ["2S", "10D", "9S"])
	ok("hint double on 11 vs 6", e.hint() == "double")
	e.hit()
	ok("hit judged wrong", e.last_decision.get("correct", true) == false and e.last_decision.get("recommended", "") == "double")
	ok("hint stand on 13 vs 6", e.hint() == "stand")
	e.stand()
	ok("stand judged right", e.last_decision.get("correct", false))
	ok("decisions tallied", e.round_record["decisions"] == 2 and e.round_record["correct"] == 1)
	var e2 := engine()
	force_deal(e2, "10S", "5C", "9D", "AH", ["10D"])
	ok("insurance hint declines", e2.hint() == "insurance_no")
	e2.take_insurance(true)
	ok("taking insurance judged wrong", not e2.last_decision.get("correct", true))


func _test_hilo_count() -> void:
	section("hi-lo count")
	var shoe := BJShoe.new(3)
	var total := 0
	for i in shoe.capacity:
		total += shoe.draw().hilo()
	ok("balanced count sums to zero", total == 0)
	var e := engine()
	force_deal(e, "2S", "KD", "5H", "6C", ["9S"])
	ok("hole card not counted", e.running_count == 3)
	e.stand()
	ok("hole counted on reveal", e.running_count == 2, str(e.running_count))
	var true_count := e.true_count()
	ok("true count scales by decks left", absf(true_count - float(e.running_count) / e.shoe.decks_remaining()) < 0.001)
	e.finish_round()
	e.shoe.reshuffle()
	ok("reshuffle resets count", e.running_count == 0)


func _test_round_record() -> void:
	section("round record")
	var e := engine()
	force_deal(e, "8S", "5D", "8H", "6C", ["3S", "2H", "10D"])
	e.split()
	e.stand()
	e.stand()
	var rec := e.round_record
	ok("record has two hands", rec["hands"].size() == 2)
	ok("record cards", rec["hands"][0]["cards"] == ["8S", "3S"] and rec["hands"][1]["cards"] == ["8H", "2H"])
	ok("record actions", rec["hands"][0]["actions"] == "PS" and rec["hands"][1]["actions"] == "S")
	ok("record dealer", rec["dealer"]["cards"] == ["5D", "6C", "10D"] and rec["dealer"]["total"] == 21)
	ok("record net", rec["net"] == -20000 and rec["bankroll"] == BJMoney.STARTING_BANKROLL - 20000)
	ok("record bankroll before", rec["bankroll_before"] == BJMoney.STARTING_BANKROLL)
	ok("record round number", rec["round"] == 1)
