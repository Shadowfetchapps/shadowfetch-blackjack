class_name BlackjackEngine
extends RefCounted
## Pure rules engine: no nodes, tweens, or presentation. Every mutating call returns
## { ok, action, reason?, phase } and illegal calls change nothing.

const BJCard = preload("res://scripts/engine/bj_card.gd")
const BJHand = preload("res://scripts/engine/bj_hand.gd")
const BJShoe = preload("res://scripts/engine/bj_shoe.gd")
const BJMoney = preload("res://scripts/engine/bj_money.gd")
const BJRules = preload("res://scripts/engine/bj_rules.gd")
const BJSideBets = preload("res://scripts/engine/bj_side_bets.gd")
const BJStrategy = preload("res://scripts/engine/bj_strategy.gd")

enum Phase { BETTING, INSURANCE, PLAYER, DEALER, SETTLE }

const SPOTS: PackedStringArray = ["main", "pp", "t3"]
const DEALER_STANDS := 17
const HISTORY_ACTIONS := {"hit": "H", "stand": "S", "double": "D", "split": "P", "surrender": "R"}

signal phase_changed(phase: int)
signal rejected(action: String, reason: String)
signal round_cleared
signal shoe_reshuffled(full: bool)

var rules: BJRules = BJRules.new()
var shoe: BJShoe
var phase: int = Phase.BETTING
var bankroll_cents: int = BJMoney.STARTING_BANKROLL

## Pending wagers while betting, per spot, and the order chips were placed (for undo).
var bets: Dictionary = {"main": 0, "pp": 0, "t3": 0}
var chip_log: Array = []
var last_bets: Dictionary = {"main": 0, "pp": 0, "t3": 0}
var last_bet_cents: int = 0
var previous_bet_cents: int = 0

var player_hands: Array[BJHand] = []
var dealer: BJHand = BJHand.new()
var active_hand: int = 0
var insurance_cents: int = 0
var insurance_payout_cents: int = 0
var insurance_offered: bool = false
var even_money_offered: bool = false
var insurance_resolved: bool = false
var side_results: Array = []

var last_results: Array = []
var last_net_cents: int = 0
var last_reject: String = ""
var round_record: Dictionary = {}
var round_number: int = 0
var round_wagered_cents: int = 0
var round_decisions: int = 0
var round_correct: int = 0
var last_decision: Dictionary = {}
var _round_start_bankroll: int = 0

## Session counters (lifetime totals live in StatsStore).
var hands_played: int = 0
var wins: int = 0
var losses: int = 0
var pushes: int = 0
var blackjacks: int = 0
var largest_win_cents: int = 0
var session_profit_cents: int = 0
var win_streak: int = 0
var best_win_streak: int = 0

## Hi-Lo running count of every card the player has seen since the last shuffle.
var running_count: int = 0
var _hole_seen: bool = false


func _init(seed_value: int = 0, p_rules: BJRules = null) -> void:
	if p_rules != null:
		rules = p_rules.duplicate_rules()
	shoe = BJShoe.new(seed_value, rules.decks, rules.penetration)
	shoe.reshuffled.connect(_on_shoe_reshuffled)
	reset_round()


# --- rules / session -------------------------------------------------------

## Adopts a new rule set. Only allowed between rounds; a deck or penetration change
## builds and shuffles a fresh shoe.
func set_rules(p_rules: BJRules) -> Dictionary:
	if phase != Phase.BETTING:
		return _reject("rules", "not_betting")
	var fresh_shoe := p_rules.needs_new_shoe(rules)
	rules = p_rules.duplicate_rules()
	if fresh_shoe:
		shoe.configure(rules.decks, rules.penetration)
	if not rules.side_bets:
		_clear_spot("pp")
		_clear_spot("t3")
	return _ok("rules", {"reshuffled": fresh_shoe})


func reset_session(starting: int = BJMoney.STARTING_BANKROLL) -> void:
	bankroll_cents = maxi(starting, 0)
	_zero_bets()
	last_bets = {"main": 0, "pp": 0, "t3": 0}
	last_bet_cents = 0
	previous_bet_cents = 0
	hands_played = 0
	wins = 0
	losses = 0
	pushes = 0
	blackjacks = 0
	largest_win_cents = 0
	session_profit_cents = 0
	win_streak = 0
	best_win_streak = 0
	round_number = 0
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
	insurance_payout_cents = 0
	insurance_offered = false
	even_money_offered = false
	insurance_resolved = false
	side_results.clear()
	last_decision = {}
	_hole_seen = false
	_set_phase(Phase.BETTING)
	round_cleared.emit()


## Refills an empty bankroll between rounds. Returns ok only when the player is broke.
func rebuy(amount: int = BJMoney.STARTING_BANKROLL) -> Dictionary:
	if phase != Phase.BETTING:
		return _reject("rebuy", "not_betting")
	if bankroll_cents >= BJMoney.TABLE_MIN or pending_total() > 0:
		return _reject("rebuy", "not_broke")
	bankroll_cents = amount
	return _ok("rebuy")


func is_broke() -> bool:
	return phase == Phase.BETTING and pending_total() == 0 and bankroll_cents < BJMoney.TABLE_MIN


# --- betting ----------------------------------------------------------------

var current_bet_cents: int:
	get:
		return int(bets["main"])

var chip_stack: Array[int]:
	get:
		return chips_for("main")


func pending_bet() -> int:
	return int(bets["main"])


func pending_total() -> int:
	return int(bets["main"]) + int(bets["pp"]) + int(bets["t3"])


func chips_for(spot: String) -> Array[int]:
	var out: Array[int] = []
	for entry in chip_log:
		if entry[0] == spot:
			out.append(int(entry[1]))
	return out


func spot_limit(spot: String) -> int:
	return BJMoney.TABLE_MAX if spot == "main" else BJMoney.SIDE_MAX


## Why a chip could not be placed, or "" when it can.
func chip_block_reason(cents: int, spot: String = "main") -> String:
	if phase != Phase.BETTING:
		return "not_betting"
	if not SPOTS.has(spot):
		return "invalid_spot"
	if spot != "main" and not rules.side_bets:
		return "side_bets_off"
	if BJMoney.CHIP_VALUES.find(cents) < 0:
		return "invalid_denomination"
	if cents > bankroll_cents - pending_total():
		return "insufficient_bankroll"
	if int(bets[spot]) + cents > spot_limit(spot):
		return "table_max"
	return ""


func can_add_chip(cents: int, spot: String = "main") -> bool:
	return chip_block_reason(cents, spot).is_empty()


func add_chip(cents: int, spot: String = "main") -> Dictionary:
	var why := chip_block_reason(cents, spot)
	if not why.is_empty():
		return _reject("chip", why)
	chip_log.append([spot, cents])
	bets[spot] = int(bets[spot]) + cents
	return _ok("chip", {"spot": spot})


## Replaces one spot's wager with `cents` made of the fewest chips. Used by tests,
## the simulation, and the max-bet shortcut.
func set_bet(cents: int, spot: String = "main") -> Dictionary:
	if phase != Phase.BETTING:
		return _reject("set_bet", "not_betting")
	if not SPOTS.has(spot) or (spot != "main" and not rules.side_bets):
		return _reject("set_bet", "invalid_spot")
	if cents < 0 or cents % BJMoney.TABLE_MIN != 0:
		return _reject("set_bet", "invalid_amount")
	if cents > spot_limit(spot):
		return _reject("set_bet", "table_max")
	if pending_total() - int(bets[spot]) + cents > bankroll_cents:
		return _reject("set_bet", "insufficient_bankroll")
	_clear_spot(spot)
	for v in BJMoney.breakdown(cents):
		chip_log.append([spot, v])
	bets[spot] = cents
	return _ok("set_bet", {"spot": spot})


func undo_chip() -> Dictionary:
	if phase != Phase.BETTING:
		return _reject("undo", "not_betting")
	if chip_log.is_empty():
		return _reject("undo", "empty")
	var entry: Array = chip_log.pop_back()
	bets[entry[0]] = int(bets[entry[0]]) - int(entry[1])
	return _ok("undo", {"removed": entry[1], "spot": entry[0]})


## Removes the most recent chip placed on one spot.
func remove_chip(spot: String) -> Dictionary:
	if phase != Phase.BETTING:
		return _reject("remove", "not_betting")
	for i in range(chip_log.size() - 1, -1, -1):
		if chip_log[i][0] == spot:
			var cents := int(chip_log[i][1])
			chip_log.remove_at(i)
			bets[spot] = int(bets[spot]) - cents
			return _ok("remove", {"removed": cents, "spot": spot})
	return _reject("remove", "empty")


func clear_bet() -> Dictionary:
	if phase != Phase.BETTING:
		return _reject("clear", "not_betting")
	_zero_bets()
	return _ok("clear")


func can_rebet() -> bool:
	return phase == Phase.BETTING and int(last_bets["main"]) > 0 and int(last_bets["main"]) <= bankroll_cents


## Restores the previous round's wagers. Side bets come back only when they are
## enabled and affordable together with the main bet.
func rebet() -> Dictionary:
	if phase != Phase.BETTING:
		return _reject("rebet", "not_betting")
	var main := int(last_bets["main"])
	if main <= 0:
		return _reject("rebet", "no_previous")
	if main > bankroll_cents:
		return _reject("rebet", "insufficient_bankroll")
	_zero_bets()
	var sides := 0
	if rules.side_bets:
		sides = int(last_bets["pp"]) + int(last_bets["t3"])
	var with_sides := sides > 0 and main + sides <= bankroll_cents
	for spot in SPOTS:
		var amount := int(last_bets[spot])
		if spot != "main" and not with_sides:
			continue
		for v in BJMoney.breakdown(amount):
			chip_log.append([spot, v])
		bets[spot] = amount
	return _ok("rebet", {"sides": with_sides})


func repeat_and_deal() -> Dictionary:
	var r := rebet()
	if not r.get("ok", false):
		return r
	return deal()


# --- round flow -------------------------------------------------------------

func deal() -> Dictionary:
	if phase != Phase.BETTING:
		return _reject("deal", "not_betting")
	var main := int(bets["main"])
	if main <= 0:
		return _reject("deal", "no_bet")
	var total := pending_total()
	if total > bankroll_cents:
		return _reject("deal", "insufficient_bankroll")
	_discard_live_cards()
	player_hands.clear()
	dealer = BJHand.new()
	if shoe.needs_reshuffle():
		shoe.reshuffle()
	_round_start_bankroll = bankroll_cents
	bankroll_cents -= total
	round_wagered_cents = total
	round_decisions = 0
	round_correct = 0
	last_decision = {}
	previous_bet_cents = last_bet_cents
	last_bet_cents = main
	last_bets = bets.duplicate()
	var side_stakes := {"pp": int(bets["pp"]), "t3": int(bets["t3"])}
	_zero_bets()
	var hand := BJHand.new()
	hand.bet_cents = main
	player_hands.append(hand)
	active_hand = 0
	insurance_cents = 0
	insurance_payout_cents = 0
	insurance_offered = false
	even_money_offered = false
	insurance_resolved = false
	_hole_seen = false
	hand.add(_draw_visible())
	dealer.add(shoe.draw())
	hand.add(_draw_visible())
	dealer.add(_draw_visible())
	_resolve_side_bets(side_stakes)
	if _dealer_up().is_ace():
		insurance_offered = true
		even_money_offered = hand.is_blackjack()
		_set_phase(Phase.INSURANCE)
		return _ok("deal", {"insurance": true, "even_money": even_money_offered})
	return _after_insurance()


## Accepts or declines insurance (or even money when the player holds a natural).
func take_insurance(accept: bool) -> Dictionary:
	if phase != Phase.INSURANCE:
		return _reject("insurance", "not_offered")
	var action := "insurance_yes" if accept else "insurance_no"
	if accept and not even_money_offered:
		var cost := BJMoney.insurance_cost(player_hands[0].bet_cents)
		if cost <= 0 or cost > bankroll_cents:
			return _reject("insurance", "insufficient_bankroll")
		_judge_insurance(action)
		bankroll_cents -= cost
		insurance_cents = cost
		round_wagered_cents += cost
	else:
		_judge_insurance(action)
	insurance_resolved = true
	if accept and even_money_offered:
		var hand := player_hands[0]
		hand.even_money = true
		hand.stood = true
		_reveal_hole()
		_settle_round(false)
		return _ok("even_money")
	return _after_insurance()


func hit() -> Dictionary:
	if phase != Phase.PLAYER:
		return _reject("hit", "not_player_turn")
	var hand := _current_hand()
	if hand == null or not _can_hit(hand):
		return _reject("hit", "illegal")
	_judge("hit")
	hand.actions += "H"
	hand.add(_draw_visible())
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
	_judge("stand")
	hand.actions += "S"
	hand.stood = true
	return _advance_hand("stand")


func surrender() -> Dictionary:
	if phase != Phase.PLAYER:
		return _reject("surrender", "not_player_turn")
	var hand := _current_hand()
	if hand == null or not _can_surrender(hand):
		return _reject("surrender", "illegal")
	_judge("surrender")
	hand.actions += "R"
	hand.surrendered = true
	hand.stood = true
	hand.outcome = "surrender"
	return _advance_hand("surrender")


func double_down() -> Dictionary:
	if phase != Phase.PLAYER:
		return _reject("double", "not_player_turn")
	var hand := _current_hand()
	if hand == null or not _can_double(hand):
		return _reject("double", "illegal")
	if bankroll_cents < hand.bet_cents:
		return _reject("double", "insufficient_bankroll")
	_judge("double")
	hand.actions += "D"
	bankroll_cents -= hand.bet_cents
	round_wagered_cents += hand.bet_cents
	hand.bet_cents += hand.bet_cents
	hand.doubled = true
	hand.add(_draw_visible())
	hand.stood = true
	if hand.is_bust():
		hand.outcome = "bust"
	return _advance_hand("double")


## Splits the active pair. The new hand waits for its second card until it is played
## (split aces receive one card each immediately and stand unless they may resplit).
func split() -> Dictionary:
	if phase != Phase.PLAYER:
		return _reject("split", "not_player_turn")
	var hand := _current_hand()
	if hand == null or not _can_split(hand):
		return _reject("split", "illegal")
	if bankroll_cents < hand.bet_cents:
		return _reject("split", "insufficient_bankroll")
	_judge("split")
	hand.actions += "P"
	bankroll_cents -= hand.bet_cents
	round_wagered_cents += hand.bet_cents
	var moved: BJCard = hand.cards.pop_back()
	var extra := BJHand.new()
	extra.bet_cents = hand.bet_cents
	extra.from_split = true
	extra.add(moved)
	hand.from_split = true
	var aces := hand.cards[0].is_ace() and moved.is_ace()
	player_hands.insert(active_hand + 1, extra)
	if aces:
		hand.from_split_aces = true
		extra.from_split_aces = true
		hand.add(_draw_visible())
		extra.add(_draw_visible())
		_close_split_aces()
		if hand.stood:
			return _advance_hand("split")
		return _ok("split")
	hand.add(_draw_visible())
	if hand.is_twenty_one():
		hand.stood = true
		return _advance_hand("split")
	return _ok("split")


func finish_round() -> Dictionary:
	if phase != Phase.SETTLE:
		return _reject("finish", "not_settled")
	reset_round()
	return _ok("finish")


# --- queries ----------------------------------------------------------------

func legal_actions() -> PackedStringArray:
	var out := PackedStringArray()
	match phase:
		Phase.BETTING:
			if int(bets["main"]) > 0 and pending_total() <= bankroll_cents:
				out.append("deal")
			if not chip_log.is_empty():
				out.append("undo")
				out.append("clear")
			if can_rebet():
				out.append("rebet")
				out.append("repeat")
			for v in BJMoney.CHIP_VALUES:
				if can_add_chip(v, "main"):
					out.append("chip_%d" % v)
		Phase.INSURANCE:
			if even_money_offered or BJMoney.insurance_cost(player_hands[0].bet_cents) <= bankroll_cents:
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
			if _can_surrender(hand):
				out.append("surrender")
	return out


func can(action: String) -> bool:
	return legal_actions().has(action)


## Basic-strategy advice for the current decision, or "" when there is none.
func hint() -> String:
	if phase == Phase.INSURANCE:
		return "insurance_no"
	if phase != Phase.PLAYER:
		return ""
	var hand := _current_hand()
	if hand == null:
		return ""
	return BJStrategy.recommend(hand, _dealer_up(), rules, _can_double(hand), _can_split(hand), _can_surrender(hand))


func win_percent() -> float:
	if hands_played <= 0:
		return 0.0
	return 100.0 * float(wins) / float(hands_played)


func dealer_upcard() -> BJCard:
	return _dealer_up()


func hole_revealed() -> bool:
	return _hole_seen


func dealer_should_hit() -> bool:
	var total := dealer.best_total()
	return total < DEALER_STANDS or (rules.dealer_hits_soft_17 and total == DEALER_STANDS and dealer.is_soft())


## Running count divided by decks left in the shoe (never less than half a deck).
func true_count() -> float:
	return float(running_count) / maxf(shoe.decks_remaining(), 0.5)


func total_on_table() -> int:
	var t := 0
	for h in player_hands:
		t += h.bet_cents
	return t + insurance_cents


func snapshot() -> Dictionary:
	var hands := []
	for h in player_hands:
		hands.append(_hand_dict(h))
	return {
		"phase": phase,
		"rules": rules.to_dict(),
		"bankroll_cents": bankroll_cents,
		"bets": bets.duplicate(),
		"last_bets": last_bets.duplicate(),
		"active_hand": active_hand,
		"insurance_cents": insurance_cents,
		"player_hands": hands,
		"dealer": _hand_dict(dealer),
		"side_results": side_results.duplicate(true),
		"last_net_cents": last_net_cents,
		"last_results": last_results.duplicate(true),
		"shoe_remaining": shoe.remaining(),
		"shoe_unique": shoe.unique_ok(),
		"cut_reached": shoe.cut_reached,
		"running_count": running_count,
	}


# --- internals --------------------------------------------------------------

func _after_insurance() -> Dictionary:
	if dealer.is_blackjack():
		_reveal_hole()
		_settle_round(true)
		return _ok("peek_blackjack")
	if player_hands[0].is_blackjack():
		player_hands[0].stood = true
		_reveal_hole()
		_settle_round(false)
		return _ok("player_blackjack")
	_set_phase(Phase.PLAYER)
	return _ok("player_turn")


func _advance_hand(action: String) -> Dictionary:
	while true:
		var nxt := _next_unfinished()
		if nxt < 0:
			break
		active_hand = nxt
		var h := player_hands[nxt]
		if h.cards.size() < 2:
			h.add(_draw_visible())
			if h.is_twenty_one():
				h.stood = true
				continue
		_set_phase(Phase.PLAYER)
		return _ok(action)
	if _any_live_player():
		_play_dealer()
	else:
		_reveal_hole()
	_settle_round(false)
	return _ok(action)


func _play_dealer() -> void:
	_set_phase(Phase.DEALER)
	_reveal_hole()
	while dealer_should_hit():
		dealer.add(_draw_visible())
	dealer.stood = true


func _close_split_aces() -> void:
	for h in player_hands:
		if h.from_split_aces and not h.stood and not _can_resplit_aces(h):
			h.stood = true


func _can_resplit_aces(h: BJHand) -> bool:
	return rules.resplit_aces and h.is_pair() and h.cards[0].is_ace() and player_hands.size() < rules.max_hands


func _resolve_side_bets(stakes: Dictionary) -> void:
	side_results.clear()
	var p := player_hands[0]
	for kind in BJSideBets.KINDS:
		var stake := int(stakes.get(kind, 0))
		if stake <= 0:
			continue
		var result := ""
		if kind == BJSideBets.PERFECT_PAIRS:
			result = BJSideBets.perfect_pairs(p.cards[0], p.cards[1])
		else:
			result = BJSideBets.twenty_one_three(p.cards[0], p.cards[1], _dealer_up())
		var pay := BJSideBets.payout(kind, result, stake)
		bankroll_cents += pay
		side_results.append({
			"kind": kind,
			"stake": stake,
			"result": result,
			"payout": pay,
			"net": pay - stake,
		})


func _settle_round(dealer_bj: bool) -> void:
	last_results.clear()
	var net := 0
	for s in side_results:
		net += int(s["net"])
	insurance_payout_cents = 0
	if insurance_cents > 0:
		if dealer.is_blackjack():
			insurance_payout_cents = BJMoney.insurance_win(insurance_cents)
			bankroll_cents += insurance_payout_cents
		net += insurance_payout_cents - insurance_cents
	for hand in player_hands:
		var result := _settle_hand(hand, dealer_bj)
		last_results.append(result)
		bankroll_cents += hand.payout_cents
		net += hand.payout_cents - hand.bet_cents
		hands_played += 1
		match hand.outcome:
			"win", "blackjack", "even_money":
				wins += 1
				win_streak += 1
				best_win_streak = maxi(best_win_streak, win_streak)
				if hand.outcome == "blackjack" or hand.outcome == "even_money":
					blackjacks += 1
			"lose", "bust", "surrender":
				losses += 1
				win_streak = 0
			"push":
				pushes += 1
	last_net_cents = net
	session_profit_cents += net
	largest_win_cents = maxi(largest_win_cents, net)
	if bankroll_cents < 0:
		bankroll_cents = 0
		push_warning("Bankroll clamped to zero")
	round_number += 1
	round_record = _build_record()
	_set_phase(Phase.SETTLE)


func _settle_hand(hand: BJHand, dealer_bj: bool) -> Dictionary:
	var pay := 0
	var out := "lose"
	if hand.surrendered:
		out = "surrender"
		pay = hand.bet_cents / 2
	elif hand.even_money:
		out = "even_money"
		pay = BJMoney.even_money_return(hand.bet_cents)
	elif hand.is_bust():
		out = "bust"
	elif hand.is_blackjack() and dealer.is_blackjack():
		out = "push"
		pay = hand.bet_cents
	elif hand.is_blackjack():
		out = "blackjack"
		pay = BJMoney.blackjack_payout(hand.bet_cents, rules.blackjack_pays_6_5)
	elif dealer.is_blackjack() or dealer_bj:
		out = "lose"
	elif dealer.is_bust():
		out = "win"
		pay = BJMoney.even_money_return(hand.bet_cents)
	elif hand.best_total() > dealer.best_total():
		out = "win"
		pay = BJMoney.even_money_return(hand.bet_cents)
	elif hand.best_total() < dealer.best_total():
		out = "lose"
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
		"doubled": hand.doubled,
		"cards": hand.cards.size(),
	}


func _build_record() -> Dictionary:
	var hands := []
	for i in player_hands.size():
		var h := player_hands[i]
		hands.append({
			"cards": Array(h.face_keys()),
			"total": h.best_total(),
			"text": h.total_text(),
			"actions": h.actions,
			"bet": h.bet_cents,
			"payout": h.payout_cents,
			"net": h.payout_cents - h.bet_cents,
			"outcome": h.outcome,
			"doubled": h.doubled,
			"split": h.from_split,
		})
	return {
		"round": round_number,
		"time": int(Time.get_unix_time_from_system()),
		"rules": rules.short_summary(),
		"hands": hands,
		"dealer": {
			"cards": Array(dealer.face_keys()),
			"total": dealer.best_total(),
			"text": dealer.total_text(),
		},
		"insurance": insurance_cents,
		"insurance_payout": insurance_payout_cents,
		"even_money": player_hands.size() > 0 and player_hands[0].even_money,
		"side": side_results.duplicate(true),
		"wagered": round_wagered_cents,
		"net": last_net_cents,
		"bankroll": bankroll_cents,
		"bankroll_before": _round_start_bankroll,
		"decisions": round_decisions,
		"correct": round_correct,
		"running_count": running_count,
	}


func _judge(action: String) -> void:
	var hand := _current_hand()
	var up := _dealer_up()
	var rec := BJStrategy.recommend(hand, up, rules, _can_double(hand), _can_split(hand), _can_surrender(hand))
	_record_decision(action, rec, BJStrategy.situation_text(hand, up))


func _judge_insurance(action: String) -> void:
	var what := "even money" if even_money_offered else "insurance"
	_record_decision(action, "insurance_no", what + " vs A")


func _record_decision(action: String, recommended: String, situation: String) -> void:
	var correct := action == recommended
	round_decisions += 1
	if correct:
		round_correct += 1
	last_decision = {
		"action": action,
		"recommended": recommended,
		"correct": correct,
		"situation": situation,
	}


func _can_hit(hand: BJHand) -> bool:
	if hand.from_split_aces:
		return false
	if hand.doubled or hand.stood or hand.is_finished() or hand.best_total() >= 21:
		return false
	return true


func _can_double(hand: BJHand) -> bool:
	if hand.cards.size() != 2 or hand.from_split_aces:
		return false
	if hand.stood or hand.doubled:
		return false
	if hand.from_split and not rules.double_after_split:
		return false
	return bankroll_cents >= hand.bet_cents


func _can_split(hand: BJHand) -> bool:
	if player_hands.size() >= rules.max_hands:
		return false
	if hand.cards.size() != 2 or not hand.is_pair() or hand.stood:
		return false
	if hand.from_split_aces and not rules.resplit_aces:
		return false
	return bankroll_cents >= hand.bet_cents


func _can_surrender(hand: BJHand) -> bool:
	return (
		rules.late_surrender
		and player_hands.size() == 1
		and hand.cards.size() == 2
		and not hand.from_split
		and not hand.stood
		and not hand.doubled
	)


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
		if not h.is_bust() and not h.surrendered and not h.even_money:
			return true
	return false


func _dealer_up() -> BJCard:
	if dealer.cards.size() < 2:
		return dealer.cards[0] if dealer.cards.size() == 1 else null
	return dealer.cards[1]


func _draw_visible() -> BJCard:
	var c := shoe.draw()
	running_count += c.hilo()
	return c


func _reveal_hole() -> void:
	if _hole_seen or dealer.cards.is_empty():
		return
	_hole_seen = true
	running_count += dealer.cards[0].hilo()


func _on_shoe_reshuffled(_full: bool) -> void:
	running_count = 0
	shoe_reshuffled.emit(_full)


func _discard_live_cards() -> void:
	if dealer.cards.size() > 0:
		shoe.discard_hand(dealer)
	for h in player_hands:
		if h.cards.size() > 0:
			shoe.discard_hand(h)


func _zero_bets() -> void:
	chip_log.clear()
	bets = {"main": 0, "pp": 0, "t3": 0}


func _clear_spot(spot: String) -> void:
	for i in range(chip_log.size() - 1, -1, -1):
		if chip_log[i][0] == spot:
			chip_log.remove_at(i)
	bets[spot] = 0


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
		"surrendered": h.surrendered,
		"actions": h.actions,
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
