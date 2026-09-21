class_name BlackjackEngine
extends RefCounted

const BJCard = preload("res://scripts/engine/bj_card.gd")
const BJHand = preload("res://scripts/engine/bj_hand.gd")
const BJShoe = preload("res://scripts/engine/bj_shoe.gd")
const BJMoney = preload("res://scripts/engine/bj_money.gd")

enum Phase { BETTING, INSURANCE, PLAYER, DEALER, SETTLE }

const MAX_HANDS := 4
const DEALER_STANDS := 17

signal phase_changed(phase: int)
signal rejected(action: String, reason: String)
signal round_cleared

var shoe: BJShoe
var phase: int = Phase.BETTING
var bankroll_cents: int = BJMoney.STARTING_BANKROLL
var chip_stack: Array[int] = []
var current_bet_cents: int = 0
var last_bet_cents: int = 0
var previous_bet_cents: int = 0
var player_hands: Array[BJHand] = []
var dealer: BJHand = BJHand.new()
var active_hand: int = 0
var insurance_cents: int = 0
var insurance_offered: bool = false
var insurance_resolved: bool = false
var last_results: Array = []
var last_net_cents: int = 0
var last_reject: String = ""
var hands_played: int = 0
var wins: int = 0
var losses: int = 0
var pushes: int = 0
var blackjacks: int = 0
var largest_win_cents: int = 0
var session_profit_cents: int = 0


func _init(seed_value: int = 0) -> void:
	shoe = BJShoe.new(seed_value)
	reset_round()


func reset_session(starting: int = BJMoney.STARTING_BANKROLL) -> void:
	bankroll_cents = maxi(starting, 0)
	chip_stack.clear()
	current_bet_cents = 0
	last_bet_cents = 0
	previous_bet_cents = 0
	insurance_cents = 0
	hands_played = 0
	wins = 0
	losses = 0
	pushes = 0
	blackjacks = 0
	largest_win_cents = 0
	session_profit_cents = 0
	last_net_cents = 0
	last_results.clear()
	shoe.reshuffle()
	reset_round()


func reset_round() -> void:
	_discard_live_cards()
	player_hands.clear()
	dealer = BJHand.new()
	active_hand = 0
	insurance_cents = 0
	insurance_offered = false
	insurance_resolved = false
	_set_phase(Phase.BETTING)
	round_cleared.emit()


func pending_bet() -> int:
	return current_bet_cents


func legal_actions() -> PackedStringArray:
	var out := PackedStringArray()
	match phase:
		Phase.BETTING:
			if current_bet_cents > 0:
				out.append("deal")
				out.append("undo")
				out.append("clear")
			if last_bet_cents > 0 and last_bet_cents <= bankroll_cents:
				out.append("rebet")
				out.append("repeat")
			for v in BJMoney.CHIP_VALUES:
				if v <= bankroll_cents - current_bet_cents:
					out.append("chip_%d" % v)
		Phase.INSURANCE:
			out.append("insurance_yes")
			out.append("insurance_no")
		Phase.PLAYER:
			var hand := _current_hand()
			if hand == null:
				return out
			if _can_hit(hand):
				out.append("hit")
			out.append("stand")
			if _can_double(hand):
				out.append("double")
			if _can_split(hand):
				out.append("split")
	return out


func can(action: String) -> bool:
	return legal_actions().has(action)


func add_chip(cents: int) -> Dictionary:
	if phase != Phase.BETTING:
		return _reject("chip", "not_betting")
	if BJMoney.CHIP_VALUES.find(cents) < 0:
		return _reject("chip", "invalid_denomination")
	if cents > bankroll_cents - current_bet_cents:
		return _reject("chip", "insufficient_bankroll")
	chip_stack.append(cents)
	current_bet_cents += cents
	return _ok("chip")


func undo_chip() -> Dictionary:
	if phase != Phase.BETTING:
		return _reject("undo", "not_betting")
	if chip_stack.is_empty():
		return _reject("undo", "empty")
	var last: int = chip_stack.pop_back()
	current_bet_cents -= last
	return _ok("undo", {"removed": last})


func clear_bet() -> Dictionary:
	if phase != Phase.BETTING:
		return _reject("clear", "not_betting")
	chip_stack.clear()
	current_bet_cents = 0
	return _ok("clear")


func rebet() -> Dictionary:
	if phase != Phase.BETTING:
		return _reject("rebet", "not_betting")
	if last_bet_cents <= 0:
		return _reject("rebet", "no_previous")
	if last_bet_cents > bankroll_cents:
		return _reject("rebet", "insufficient_bankroll")
	chip_stack = BJMoney.breakdown(last_bet_cents)
	current_bet_cents = last_bet_cents
	return _ok("rebet")


func repeat_and_deal() -> Dictionary:
	var r := rebet()
	if not r.get("ok", false):
		return r
	return deal()


func deal() -> Dictionary:
	if phase != Phase.BETTING:
		return _reject("deal", "not_betting")
	if current_bet_cents <= 0:
		return _reject("deal", "no_bet")
	if current_bet_cents > bankroll_cents:
		return _reject("deal", "insufficient_bankroll")
	if shoe.needs_reshuffle():
		shoe.reshuffle()
	_discard_live_cards()
	player_hands.clear()
	var hand := BJHand.new()
	hand.bet_cents = current_bet_cents
	player_hands.append(hand)
	dealer = BJHand.new()
	bankroll_cents -= current_bet_cents
	previous_bet_cents = last_bet_cents
	last_bet_cents = current_bet_cents
	current_bet_cents = 0
	chip_stack.clear()
	active_hand = 0
	insurance_cents = 0
	insurance_offered = false
	insurance_resolved = false
	hand.add(shoe.draw())
	dealer.add(shoe.draw())
	hand.add(shoe.draw())
	dealer.add(shoe.draw())
	if not shoe.unique_ok():
		push_warning("Shoe uniqueness invariant failed after deal")
	if _dealer_up().is_ace():
		insurance_offered = true
		_set_phase(Phase.INSURANCE)
		return _ok("deal", {"insurance": true})
	return _after_insurance()


func take_insurance(accept: bool) -> Dictionary:
	if phase != Phase.INSURANCE:
		return _reject("insurance", "not_offered")
	if accept:
		var cost := BJMoney.insurance_cost(player_hands[0].bet_cents)
		if cost <= 0 or cost > bankroll_cents:
			return _reject("insurance", "insufficient_bankroll")
		bankroll_cents -= cost
		insurance_cents = cost
	else:
		insurance_cents = 0
	insurance_resolved = true
	return _after_insurance()


func hit() -> Dictionary:
	if phase != Phase.PLAYER:
		return _reject("hit", "not_player_turn")
	var hand := _current_hand()
	if hand == null or not _can_hit(hand):
		return _reject("hit", "illegal")
	hand.add(shoe.draw())
	if hand.is_bust():
		hand.stood = true
		hand.outcome = "bust"
		return _advance_hand("hit")
	if hand.is_twenty_one():
		hand.stood = true
		return _advance_hand("hit")
	return _ok("hit")


func stand() -> Dictionary:
	if phase != Phase.PLAYER:
		return _reject("stand", "not_player_turn")
	var hand := _current_hand()
	if hand == null:
		return _reject("stand", "no_hand")
	hand.stood = true
	return _advance_hand("stand")


func double_down() -> Dictionary:
	if phase != Phase.PLAYER:
		return _reject("double", "not_player_turn")
	var hand := _current_hand()
	if hand == null or not _can_double(hand):
		return _reject("double", "illegal")
	if bankroll_cents < hand.bet_cents:
		return _reject("double", "insufficient_bankroll")
	bankroll_cents -= hand.bet_cents
	hand.bet_cents += hand.bet_cents
	hand.doubled = true
	hand.add(shoe.draw())
	hand.stood = true
	if hand.is_bust():
		hand.outcome = "bust"
	return _advance_hand("double")


func split() -> Dictionary:
	if phase != Phase.PLAYER:
		return _reject("split", "not_player_turn")
	var hand := _current_hand()
	if hand == null or not _can_split(hand):
		return _reject("split", "illegal")
	if bankroll_cents < hand.bet_cents:
		return _reject("split", "insufficient_bankroll")
	bankroll_cents -= hand.bet_cents
	var moved: BJCard = hand.cards.pop_back()
	var extra := BJHand.new()
	extra.bet_cents = hand.bet_cents
	extra.from_split = true
	extra.add(moved)
	hand.from_split = true
	var aces := hand.cards[0].is_ace() and moved.is_ace()
	if aces:
		hand.from_split_aces = true
		extra.from_split_aces = true
	player_hands.insert(active_hand + 1, extra)
	hand.add(shoe.draw())
	extra.add(shoe.draw())
	if aces:
		hand.stood = true
		extra.stood = true
		return _advance_hand("split")
	if hand.is_twenty_one():
		hand.stood = true
		return _advance_hand("split")
	return _ok("split")


func win_percent() -> float:
	if hands_played <= 0:
		return 0.0
	return 100.0 * float(wins) / float(hands_played)


func dealer_upcard() -> BJCard:
	return _dealer_up()


func dealer_should_hit() -> bool:
	return dealer.best_total() < DEALER_STANDS


func snapshot() -> Dictionary:
	var hands := []
	for h in player_hands:
		hands.append(_hand_dict(h))
	return {
		"phase": phase,
		"bankroll_cents": bankroll_cents,
		"current_bet_cents": current_bet_cents,
		"last_bet_cents": last_bet_cents,
		"previous_bet_cents": previous_bet_cents,
		"active_hand": active_hand,
		"insurance_cents": insurance_cents,
		"player_hands": hands,
		"dealer": _hand_dict(dealer),
		"last_net_cents": last_net_cents,
		"last_results": last_results.duplicate(true),
		"shoe_remaining": shoe.remaining(),
		"shoe_unique": shoe.unique_ok(),
		"cut_reached": shoe.cut_reached,
	}


func _after_insurance() -> Dictionary:
	if _dealer_has_blackjack():
		_set_phase(Phase.SETTLE)
		_settle_round(true)
		return _ok("peek_blackjack")
	var player := player_hands[0]
	if player.is_blackjack():
		_set_phase(Phase.SETTLE)
		_settle_round(false)
		return _ok("player_blackjack")
	_set_phase(Phase.PLAYER)
	return _ok("player_turn")


func _advance_hand(action: String) -> Dictionary:
	if _next_unfinished() >= 0:
		active_hand = _next_unfinished()
		_set_phase(Phase.PLAYER)
		return _ok(action)
	if _any_live_player():
		_play_dealer()
	_set_phase(Phase.SETTLE)
	_settle_round(false)
	return _ok(action)


func _play_dealer() -> void:
	_set_phase(Phase.DEALER)
	while dealer_should_hit():
		dealer.add(shoe.draw())
	dealer.stood = true


func _settle_round(dealer_bj: bool) -> void:
	last_results.clear()
	var net := 0
	if insurance_cents > 0:
		if dealer.is_blackjack():
			var ins_pay := BJMoney.insurance_win(insurance_cents)
			bankroll_cents += ins_pay
			net += ins_pay - insurance_cents
		else:
			net -= insurance_cents
	for hand in player_hands:
		var result := _settle_hand(hand, dealer_bj)
		last_results.append(result)
		bankroll_cents += hand.payout_cents
		net += hand.payout_cents - hand.bet_cents
		hands_played += 1
		match hand.outcome:
			"win", "blackjack":
				wins += 1
				if hand.outcome == "blackjack":
					blackjacks += 1
			"lose", "bust":
				losses += 1
			"push":
				pushes += 1
		var hand_net: int = hand.payout_cents - hand.bet_cents
		if hand_net > largest_win_cents:
			largest_win_cents = hand_net
	last_net_cents = net
	session_profit_cents += net
	if bankroll_cents < 0:
		bankroll_cents = 0
		push_warning("Bankroll clamped to zero")
	_set_phase(Phase.SETTLE)


func finish_round() -> Dictionary:
	if phase != Phase.SETTLE:
		return _reject("finish", "not_settled")
	reset_round()
	return _ok("finish")


func _settle_hand(hand: BJHand, dealer_bj: bool) -> Dictionary:
	var pay := 0
	var out := "lose"
	if hand.is_bust():
		out = "bust"
		pay = 0
	elif hand.is_blackjack() and dealer.is_blackjack():
		out = "push"
		pay = hand.bet_cents
	elif hand.is_blackjack():
		out = "blackjack"
		pay = BJMoney.blackjack_payout(hand.bet_cents)
	elif dealer.is_blackjack() or dealer_bj:
		out = "lose"
		pay = 0
	elif dealer.is_bust():
		out = "win"
		pay = BJMoney.even_money_return(hand.bet_cents)
	elif hand.best_total() > dealer.best_total():
		out = "win"
		pay = BJMoney.even_money_return(hand.bet_cents)
	elif hand.best_total() < dealer.best_total():
		out = "lose"
		pay = 0
	else:
		out = "push"
		pay = hand.bet_cents
	hand.outcome = out
	hand.payout_cents = pay
	hand.settled = true
	return {
		"outcome": out,
		"bet_cents": hand.bet_cents,
		"payout_cents": pay,
		"net_cents": pay - hand.bet_cents,
		"player_total": hand.best_total(),
		"dealer_total": dealer.best_total(),
		"blackjack": hand.is_blackjack(),
	}


func _can_hit(hand: BJHand) -> bool:
	if hand.from_split_aces:
		return false
	if hand.doubled or hand.stood or hand.is_bust() or hand.is_finished():
		return false
	return true


func _can_double(hand: BJHand) -> bool:
	if hand.cards.size() != 2:
		return false
	if hand.from_split_aces:
		return false
	if hand.stood or hand.doubled:
		return false
	if bankroll_cents < hand.bet_cents:
		return false
	return true


func _can_split(hand: BJHand) -> bool:
	if player_hands.size() >= MAX_HANDS:
		return false
	if not hand.is_pair():
		return false
	if hand.from_split_aces:
		return false
	if hand.cards.size() != 2:
		return false
	if bankroll_cents < hand.bet_cents:
		return false
	return true


func _current_hand() -> BJHand:
	if active_hand < 0 or active_hand >= player_hands.size():
		return null
	return player_hands[active_hand]


func _next_unfinished() -> int:
	for i in range(active_hand + 1, player_hands.size()):
		if not player_hands[i].is_finished():
			return i
	for i in range(0, player_hands.size()):
		if not player_hands[i].is_finished():
			return i
	return -1


func _any_live_player() -> bool:
	for h in player_hands:
		if not h.is_bust():
			return true
	return false


func _dealer_up() -> BJCard:
	if dealer.cards.size() < 2:
		return dealer.cards[0] if dealer.cards.size() == 1 else null
	return dealer.cards[1]


func _dealer_has_blackjack() -> bool:
	return dealer.is_blackjack()


func _discard_live_cards() -> void:
	if dealer.cards.size() > 0:
		shoe.discard_hand(dealer)
	for h in player_hands:
		if h.cards.size() > 0:
			shoe.discard_hand(h)


func _hand_dict(h: BJHand) -> Dictionary:
	var ids := []
	for c in h.cards:
		ids.append(str(c))
	return {
		"cards": ids,
		"total": h.best_total(),
		"soft": h.is_soft(),
		"bet_cents": h.bet_cents,
		"outcome": h.outcome,
		"blackjack": h.is_blackjack(),
		"bust": h.is_bust(),
	}


func _set_phase(p: int) -> void:
	phase = p
	phase_changed.emit(p)


func _ok(action: String, extra: Dictionary = {}) -> Dictionary:
	last_reject = ""
	var d := {"ok": true, "action": action, "phase": phase}
	for k in extra:
		d[k] = extra[k]
	return d


func _reject(action: String, reason: String) -> Dictionary:
	last_reject = "%s:%s" % [action, reason]
	rejected.emit(action, reason)
	return {"ok": false, "action": action, "reason": reason, "phase": phase}
