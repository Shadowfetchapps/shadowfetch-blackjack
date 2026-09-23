class_name BJTestBase
extends RefCounted
## Minimal assertion harness shared by every suite.

const BJCard = preload("res://scripts/engine/bj_card.gd")
const BJHand = preload("res://scripts/engine/bj_hand.gd")
const BJShoe = preload("res://scripts/engine/bj_shoe.gd")
const BJMoney = preload("res://scripts/engine/bj_money.gd")
const BJRules = preload("res://scripts/engine/bj_rules.gd")
const BJSideBets = preload("res://scripts/engine/bj_side_bets.gd")
const BJStrategy = preload("res://scripts/engine/bj_strategy.gd")
const BlackjackEngine = preload("res://scripts/engine/blackjack_engine.gd")

var passed := 0
var failed := 0
var errors: PackedStringArray = PackedStringArray()
var simulated_hands := 0


func run() -> void:
	pass


func ok(name: String, cond: bool, detail: String = "") -> void:
	if cond:
		passed += 1
		print("  ok    ", name)
	else:
		failed += 1
		var msg := name if detail.is_empty() else "%s — %s" % [name, detail]
		errors.append(msg)
		print("  FAIL  ", msg)


func section(title: String) -> void:
	print(title)


func card(token: String) -> BJCard:
	var c := BJCard.parse(token)
	assert(c != null)
	return c


func hand_of(tokens: Array) -> BJHand:
	var h := BJHand.new()
	for t in tokens:
		h.add(card(str(t)))
	return h


func engine(seed_value: int = 1, rules: BJRules = null) -> BlackjackEngine:
	return BlackjackEngine.new(seed_value, rules)


## Stacks the shoe so the deal goes player, dealer hole, player, dealer up, then extras.
func force_deal(e: BlackjackEngine, p1: String, d1: String, p2: String, d2: String, extra: Array = []) -> Dictionary:
	var seq: Array = [card(p1), card(d1), card(p2), card(d2)]
	for t in extra:
		seq.append(card(str(t)))
	e.shoe.force_next(seq)
	if e.current_bet_cents <= 0:
		e.add_chip(10000)
	return e.deal()
