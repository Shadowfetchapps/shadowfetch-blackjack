class_name TestBlackjackEngine
extends "res://tests/test_base.gd"
## Core engine rules: totals, shoe, payouts, player actions, bankroll safety.


func run() -> void:
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
	_test_undo_and_rebet()


func _test_card_values() -> void:
	section("card values")
	ok("ace pip 1", card("AS").pip_value() == 1)
	ok("ten 10", card("10H").pip_value() == 10)
	ok("jack 10", card("JS").pip_value() == 10)
	ok("king 10", card("KD").pip_value() == 10)
	ok("nine 9", card("9C").pip_value() == 9)
	ok("same rank 10 10", card("10S").same_rank(card("10D")))
	ok("10 and J different ranks", not card("10S").same_rank(card("JS")))
	ok("uid unique per deck", card("0:AS").uid() != card("1:AS").uid())
	ok("uid range", card("5:KC").uid() == 5 * 52 + 3 * 13 + 12)
	ok("label", card("10D").label() == "10♦")
	ok("parse rejects junk", BJCard.parse("ZZ") == null and BJCard.parse("") == null)


func _test_soft_hard_multi_ace() -> void:
	section("soft / hard / multi-ace")
	var a6 := hand_of(["AS", "6D"])
	ok("A6 soft 17", a6.is_soft() and a6.best_total() == 17 and a6.hard_total() == 7)
	ok("A6 text", a6.total_text() == "Soft 17")
	var aa9 := hand_of(["AS", "AH", "9C"])
	ok("AA9 is 21 soft", aa9.best_total() == 21 and aa9.is_soft())
	var aaaa := hand_of(["AS", "AH", "AD", "AC"])
	ok("four aces 14 soft", aaaa.best_total() == 14 and aaaa.ace_count() == 4)
	var a105 := hand_of(["AS", "10H", "5C"])
	ok("A-10-5 hard 16", a105.best_total() == 16 and not a105.is_soft())
	var bj := hand_of(["AS", "KD"])
	ok("natural blackjack", bj.is_blackjack() and bj.best_total() == 21 and bj.total_text() == "Blackjack")
	ok("bust text", hand_of(["KS", "QD", "5H"]).total_text() == "Bust 25")


func _test_shoe_shuffle_and_cut() -> void:
	section("shoe")
	var shoe := BJShoe.new(42)
	ok("312 cards", shoe.remaining() == 312 and shoe.total_accounted() == 312)
	ok("unique full shoe", shoe.unique_ok())
	var first := shoe.draw()
	ok("draw accounts", shoe.remaining() == 311 and shoe.in_play_count() == 1)
	var hand := BJHand.new()
	hand.add(first)
	shoe.discard_hand(hand)
	ok("discard moves", shoe.in_play_count() == 0 and shoe.discarded_count() == 1)
	ok("conserved after discard", shoe.total_accounted() == 312 and shoe.unique_ok())
	while not shoe.cut_reached and shoe.remaining() > 0:
		shoe.discard_cards([shoe.draw()])
	ok("cut card eventually reached", shoe.cut_reached)
	ok("cut near 75% penetration", absf(shoe.dealt_fraction() - 0.75) < 0.04, str(shoe.dealt_fraction()))
	ok("still conserved", shoe.total_accounted() == 312)
	shoe.reshuffle()
	ok("reshuffle restores 312", shoe.remaining() == 312 and shoe.discarded_count() == 0)
	ok("reshuffle unique", shoe.unique_ok())
	ok("cut after reshuffle reset", not shoe.cut_reached)


func _test_no_duplicate_cards() -> void:
	section("no duplicates")
	var shoe := BJShoe.new(7)
	var seen := {}
	var dup := false
	for i in 312:
		var id := shoe.draw().id()
		if seen.has(id):
			dup = true
		seen[id] = true
	ok("312 unique draws", not dup and seen.size() == 312)


func _test_deal_and_totals() -> void:
	section("deal")
	var e := engine()
	var r := force_deal(e, "9S", "5D", "7H", "8C")
	ok("deal ok", r.get("ok", false))
	ok("player 16", e.player_hands[0].best_total() == 16)
	ok("dealer 13", e.dealer.best_total() == 13)
	ok("upcard is second dealer card", e.dealer_upcard().face_key() == "8C")
	ok("player turn", e.phase == BlackjackEngine.Phase.PLAYER)
	ok("bet deducted", e.bankroll_cents == BJMoney.STARTING_BANKROLL - 10000)


func _test_blackjack_payout() -> void:
	section("blackjack 3:2")
	var e := engine()
	force_deal(e, "AS", "9D", "KS", "5C")
	ok("player BJ phase settle", e.phase == BlackjackEngine.Phase.SETTLE)
	ok("outcome blackjack", e.player_hands[0].outcome == "blackjack")
	ok("payout 3:2", e.player_hands[0].payout_cents == 25000, str(e.player_hands[0].payout_cents))
	ok("bankroll +150", e.bankroll_cents == BJMoney.STARTING_BANKROLL + 15000, str(e.bankroll_cents))
	ok("stats bj", e.blackjacks == 1 and e.wins == 1)
	ok("hole revealed at settle", e.hole_revealed())


func _test_blackjack_both_push() -> void:
	section("bj both sides")
	var e := engine()
	force_deal(e, "AH", "AS", "KD", "KC")
	ok("push both bj", e.player_hands[0].outcome == "push")
	ok("bet returned", e.bankroll_cents == BJMoney.STARTING_BANKROLL)
	ok("push counted", e.pushes == 1 and e.wins == 0)


func _test_push() -> void:
	section("push")
	var e := engine()
	force_deal(e, "10S", "9D", "9H", "10C")
	e.stand()
	ok("push 19", e.player_hands[0].outcome == "push" and e.player_hands[0].best_total() == 19)
	ok("bankroll even", e.bankroll_cents == BJMoney.STARTING_BANKROLL)


func _test_bust() -> void:
	section("bust")
	var e := engine()
	force_deal(e, "10S", "5D", "9H", "6C", ["8D"])
	e.hit()
	ok("player bust", e.player_hands[0].is_bust() and e.player_hands[0].outcome == "bust")
	ok("lost bet", e.bankroll_cents == BJMoney.STARTING_BANKROLL - 10000)
	ok("dealer did not draw", e.dealer.cards.size() == 2)
	ok("hole still revealed", e.hole_revealed())


func _test_double() -> void:
	section("double")
	var e := engine()
	force_deal(e, "5S", "9D", "6H", "7C", ["10S", "9S"])
	var r := e.double_down()
	ok("double ok", r.get("ok", false))
	ok("one extra card", e.player_hands[0].cards.size() == 3)
	ok("bet doubled", e.player_hands[0].bet_cents == 20000 and e.player_hands[0].doubled)
	ok("21 wins even on double", e.player_hands[0].outcome == "win")
	ok("double payout 2x doubled bet", e.player_hands[0].payout_cents == 40000)
	ok("action recorded", e.player_hands[0].actions == "D")
	ok("wagered includes double", e.round_record.get("wagered", 0) == 20000)


func _test_split() -> void:
	section("split")
	var e := engine()
	force_deal(e, "8S", "5D", "8H", "6C", ["3S", "2H", "10D"])
	var r := e.split()
	ok("split ok", r.get("ok", false), str(r))
	ok("two hands", e.player_hands.size() == 2)
	ok("first hand drew immediately", e.player_hands[0].cards.size() == 2 and e.player_hands[0].best_total() == 11)
	ok("second hand waits for its card", e.player_hands[1].cards.size() == 1)
	ok("split bet taken", e.bankroll_cents == BJMoney.STARTING_BANKROLL - 20000)
	e.stand()
	ok("second hand dealt when played", e.player_hands[1].cards.size() == 2 and e.player_hands[1].best_total() == 10)
	ok("active hand advanced", e.active_hand == 1)
	e.stand()
	ok("settled after both stands", e.phase == BlackjackEngine.Phase.SETTLE)
	ok("dealer drew to 21", e.dealer.best_total() == 21)
	ok("split hand not blackjack", not e.player_hands[0].is_blackjack())


func _test_split_aces() -> void:
	section("split aces")
	var e := engine()
	force_deal(e, "AS", "9D", "AH", "7C", ["5S", "9H", "2C"])
	var r := e.split()
	ok("split aces ok", r.get("ok", false), str(r))
	ok("one card each", e.player_hands[0].cards.size() == 2 and e.player_hands[1].cards.size() == 2)
	ok("split aces auto stand", e.phase == BlackjackEngine.Phase.SETTLE)
	ok("A+9 after split is 20 not BJ", not e.player_hands[1].is_blackjack() and e.player_hands[1].best_total() == 20)
	var e2 := engine()
	force_deal(e2, "AS", "9D", "AH", "7C", ["KS", "QH", "2C"])
	e2.split()
	ok("split ace + ten is 21 not blackjack", e2.player_hands[0].best_total() == 21 and e2.player_hands[0].outcome == "win")
	ok("split 21 pays even money", e2.player_hands[0].payout_cents == 20000)


func _test_resplit_and_max_hands() -> void:
	section("resplit / max hands")
	var e := engine()
	force_deal(e, "8S", "2D", "8H", "9C", ["8D", "7S", "8C", "4H", "2S", "3D", "5H", "6S"])
	ok("first split", e.split().get("ok", false))
	ok("resplit allowed", e.can("split"))
	ok("second split", e.split().get("ok", false))
	ok("three hands", e.player_hands.size() == 3)
	var guard := 0
	while e.phase == BlackjackEngine.Phase.PLAYER and guard < 20:
		guard += 1
		if e.can("split"):
			e.split()
		else:
			e.stand()
	ok("never more than four hands", e.player_hands.size() <= 4)
	ok("resplit round settled", e.phase == BlackjackEngine.Phase.SETTLE)
	var rules := BJRules.new()
	rules.max_hands = 2
	var e2 := engine(1, rules)
	force_deal(e2, "8S", "2D", "8H", "9C", ["8D", "7S"])
	e2.split()
	ok("max_hands 2 blocks resplit", e2.player_hands.size() == 2 and not e2.can("split"))


func _test_insurance() -> void:
	section("insurance")
	var e := engine()
	force_deal(e, "10S", "KS", "9D", "AH")
	ok("insurance offered", e.phase == BlackjackEngine.Phase.INSURANCE and not e.even_money_offered)
	var before := e.bankroll_cents
	var r := e.take_insurance(true)
	ok("insurance accepted", r.get("ok", false))
	ok("dealer BJ", e.dealer.is_blackjack())
	ok("insurance 2:1", e.bankroll_cents == before - 5000 + 15000, str(e.bankroll_cents))
	ok("main bet lost", e.player_hands[0].outcome == "lose")
	ok("round net zero", e.last_net_cents == 0, str(e.last_net_cents))
	var e2 := engine(3)
	force_deal(e2, "9S", "5C", "7D", "AH", ["10S", "10D"])
	ok("ins offered no bj", e2.phase == BlackjackEngine.Phase.INSURANCE)
	var b2 := e2.bankroll_cents
	e2.take_insurance(true)
	ok("insurance stake taken", e2.insurance_cents == 5000 and e2.bankroll_cents == b2 - 5000)
	ok("play continues after lost insurance", e2.phase == BlackjackEngine.Phase.PLAYER)
	e2.stand()
	ok("insurance lost in net", e2.last_net_cents == 10000 - 5000, str(e2.last_net_cents))
	var e3 := engine()
	force_deal(e3, "10S", "5C", "9D", "AH")
	e3.bankroll_cents = 1000
	ok("insurance unaffordable not legal", not e3.can("insurance_yes") and e3.can("insurance_no"))


func _test_soft_17() -> void:
	section("dealer soft 17")
	var e := engine()
	force_deal(e, "10S", "AS", "8H", "6D")
	e.stand()
	ok("dealer A6 stands", e.dealer.best_total() == 17 and e.dealer.is_soft())
	ok("dealer did not hit S17", e.dealer.cards.size() == 2)
	ok("player 18 beats 17", e.player_hands[0].outcome == "win")


func _test_h17_option() -> void:
	section("dealer H17 option")
	var rules := BJRules.new()
	rules.dealer_hits_soft_17 = true
	var e := engine(1, rules)
	force_deal(e, "10S", "AS", "8H", "6D", ["2C"])
	e.stand()
	ok("H17 dealer hits A6", e.dealer.cards.size() == 3)
	ok("H17 dealer reaches 19", e.dealer.best_total() == 19)
	ok("H17 changes outcome", e.player_hands[0].outcome == "lose")


func _test_late_surrender() -> void:
	section("late surrender")
	var e := engine()
	force_deal(e, "10S", "9D", "6H", "7C")
	ok("surrender initially legal", e.can("surrender"))
	var r := e.surrender()
	ok("surrender accepted", r.get("ok", false))
	ok("surrender settles round", e.phase == BlackjackEngine.Phase.SETTLE)
	ok("surrender returns half", e.player_hands[0].payout_cents == 5000)
	ok("surrender net half loss", e.last_net_cents == -5000)
	ok("surrender counts loss", e.losses == 1)
	var rules := BJRules.new()
	rules.late_surrender = false
	var e2 := engine(1, rules)
	force_deal(e2, "10S", "9D", "6H", "7C")
	ok("surrender setting honored", not e2.can("surrender"))
	e2.hit()
	ok("cannot surrender after hit", not e2.surrender().get("ok", true))
	var e3 := engine()
	force_deal(e3, "8S", "5D", "8H", "6C", ["3S", "2H"])
	e3.split()
	ok("cannot surrender split hand", not e3.can("surrender"))


func _test_dealer_hits_16() -> void:
	section("dealer hits 16")
	var e := engine()
	force_deal(e, "10S", "10D", "9H", "6C", ["5S"])
	e.stand()
	ok("dealer hit 16", e.dealer.cards.size() == 3)
	ok("dealer 21", e.dealer.best_total() == 21)
	ok("player 19 loses", e.player_hands[0].outcome == "lose")


func _test_bankroll_bounds() -> void:
	section("bankroll bounds")
	var e := engine()
	e.bankroll_cents = 500
	ok("cannot chip more than bankroll", not e.add_chip(1000).get("ok", true))
	ok("can chip $5", e.add_chip(500).get("ok", false))
	ok("cannot overbet", not e.add_chip(100).get("ok", true))
	e.bankroll_cents = 10000
	e.clear_bet()
	e.add_chip(10000)
	force_deal(e, "8S", "5D", "8H", "6C")
	e.bankroll_cents = 0
	ok("cannot split broke", not e.split().get("ok", true))
	ok("cannot double broke", not e.double_down().get("ok", true))
	ok("never negative after reject", e.bankroll_cents >= 0)
	var e2 := engine()
	e2.bankroll_cents = 5_000_000
	for i in 10:
		e2.add_chip(100000)
	ok("table max reached", e2.current_bet_cents == BJMoney.TABLE_MAX)
	ok("table max enforced", e2.chip_block_reason(100, "main") == "table_max")
	ok("side limit enforced", e2.set_bet(BJMoney.SIDE_MAX + 100, "pp").get("reason", "") == "table_max")
	var e3 := engine()
	e3.bankroll_cents = 50
	ok("broke detected", e3.is_broke())
	ok("rebuy when broke", e3.rebuy().get("ok", false) and e3.bankroll_cents == BJMoney.STARTING_BANKROLL)
	ok("no rebuy when solvent", not e3.rebuy().get("ok", true))


func _test_illegal_actions() -> void:
	section("illegal actions")
	var e := engine()
	ok("deal without bet rejected", not e.deal().get("ok", true))
	ok("hit in betting rejected", not e.hit().get("ok", true))
	ok("stand in betting rejected", not e.stand().get("ok", true))
	ok("split in betting rejected", not e.split().get("ok", true))
	ok("insurance in betting rejected", not e.take_insurance(true).get("ok", true))
	ok("bad denomination rejected", not e.add_chip(700).get("ok", true))
	ok("unknown spot rejected", not e.add_chip(100, "nowhere").get("ok", true))
	force_deal(e, "9S", "5D", "7H", "8C")
	ok("cannot split non-pair", not e.split().get("ok", true))
	ok("chips rejected mid-round", not e.add_chip(100).get("ok", true))
	ok("rules locked mid-round", not e.set_rules(BJRules.new()).get("ok", true))
	var e2 := engine()
	force_deal(e2, "10S", "5D", "9H", "8C", ["2D"])
	e2.hit()
	ok("cannot double after hit", not e2.double_down().get("ok", true))
	var e3 := engine()
	force_deal(e3, "10S", "5C", "9D", "AH")
	ok("cannot hit during insurance", not e3.hit().get("ok", true))


func _test_rapid_input() -> void:
	section("rapid input")
	var e := engine()
	force_deal(e, "10S", "5D", "6H", "8C", ["KS", "3D"])
	var first := e.hit()
	var second := e.hit()
	ok("first hit busts and settles", first.get("ok", false) and e.phase == BlackjackEngine.Phase.SETTLE)
	ok("extra hit ignored after hand done", not second.get("ok", true))
	var e2 := engine()
	force_deal(e2, "10S", "9D", "9H", "8C")
	e2.stand()
	ok("rapid stand after settle rejected", not e2.stand().get("ok", true))
	ok("rapid deal before finish rejected", not e2.deal().get("ok", true))


func _test_integer_payouts() -> void:
	section("integer payouts")
	ok("3:2 of $100", BJMoney.blackjack_payout(10000) == 25000)
	ok("3:2 of $1", BJMoney.blackjack_payout(100) == 250)
	ok("6:5 of $100", BJMoney.blackjack_payout(10000, true) == 22000)
	ok("6:5 of $5", BJMoney.blackjack_payout(500, true) == 1100)
	ok("insurance half", BJMoney.insurance_cost(10000) == 5000)
	ok("insurance 2:1 return", BJMoney.insurance_win(5000) == 15000)
	ok("even money", BJMoney.even_money_return(2500) == 5000)
	var e := engine()
	e.add_chip(100)
	force_deal(e, "AS", "9D", "KS", "5C")
	ok("tiny BJ integer bankroll", e.bankroll_cents == BJMoney.STARTING_BANKROLL + 150)
	ok("format cents", BJMoney.format_cents(123456789) == "$1,234,567.89")
	ok("format short", BJMoney.format_short(250000) == "$2,500" and BJMoney.format_short(150) == "$1.50")
	ok("format compact", BJMoney.format_compact(150000) == "$1.5K" and BJMoney.format_compact(120_000_000) == "$1.2M")
	ok("format signed", BJMoney.format_signed(-500) == "-$5.00" and BJMoney.format_signed(500) == "+$5.00")


func _test_clean_new_round() -> void:
	section("clean new round")
	var e := engine()
	force_deal(e, "10S", "9D", "8H", "7C")
	e.stand()
	ok("settle then finish", e.finish_round().get("ok", false))
	ok("betting again", e.phase == BlackjackEngine.Phase.BETTING)
	ok("hands cleared", e.player_hands.is_empty() and e.dealer.cards.is_empty())
	ok("insurance reset", e.insurance_cents == 0 and not e.insurance_offered)
	ok("no leftover bet", e.pending_total() == 0 and e.chip_log.is_empty())
	ok("shoe still valid", e.shoe.unique_ok() and e.shoe.total_accounted() == 312)


func _test_reshuffle_conservation() -> void:
	section("reshuffle conservation")
	var e := engine(99)
	e.shoe.cut_index = 8
	var conserved := true
	for i in 60:
		if e.phase == BlackjackEngine.Phase.BETTING:
			e.add_chip(100)
			e.deal()
		if e.phase == BlackjackEngine.Phase.INSURANCE:
			e.take_insurance(false)
		while e.phase == BlackjackEngine.Phase.PLAYER:
			e.stand()
		if e.phase == BlackjackEngine.Phase.SETTLE:
			e.finish_round()
		if not (e.shoe.total_accounted() == 312 and e.shoe.unique_ok()):
			conserved = false
		if e.shoe.shuffle_count > 3:
			break
	ok("conserved across rounds", conserved)
	ok("reshuffled at least once", e.shoe.shuffle_count >= 2)
	var small := BJShoe.new(5, 1, 0.65)
	var held: Array = []
	for i in 30:
		held.append(small.draw())
	small.discard_cards(held.slice(0, 20))
	for i in 40:
		held.append(small.draw())
	ok("emergency reshuffle keeps table cards", small.unique_ok() and small.total_accounted() == 52, "%d" % small.total_accounted())
	ok("emergency reshuffle forces full shuffle next", small.needs_reshuffle())


func _test_undo_and_rebet() -> void:
	section("undo / rebet")
	var e := engine()
	e.add_chip(2500)
	e.add_chip(500, "pp")
	e.add_chip(100, "t3")
	ok("three spots", e.bets["main"] == 2500 and e.bets["pp"] == 500 and e.bets["t3"] == 100)
	e.undo_chip()
	ok("undo removes latest chip", e.bets["t3"] == 0 and e.pending_total() == 3000)
	e.remove_chip("main")
	ok("remove chip from spot", e.bets["main"] == 0 and e.bets["pp"] == 500)
	ok("cannot deal without main", not e.can("deal"))
	e.add_chip(10000)
	e.add_chip(100, "t3")
	force_deal(e, "9S", "5D", "7H", "8C")
	e.stand()
	e.finish_round()
	ok("rebet legal", e.can("rebet"))
	e.rebet()
	ok("rebet restores all spots", e.bets["main"] == 10000 and e.bets["pp"] == 500 and e.bets["t3"] == 100)
	e.clear_bet()
	var off := BJRules.new()
	off.side_bets = false
	e.set_rules(off)
	e.rebet()
	ok("rebet skips sides when disabled", e.bets["main"] == 10000 and e.bets["pp"] == 0 and e.bets["t3"] == 0)
	ok("side chips rejected when disabled", e.chip_block_reason(100, "pp") == "side_bets_off")
	var e2 := engine()
	e2.add_chip(10000)
	e2.add_chip(500, "pp")
	force_deal(e2, "9S", "5D", "7H", "8C")
	e2.stand()
	e2.finish_round()
	e2.bankroll_cents = 10000
	e2.rebet()
	ok("rebet drops unaffordable sides", e2.bets["main"] == 10000 and e2.bets["pp"] == 0)
