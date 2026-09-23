class_name BJHand
extends RefCounted
## A player or dealer hand. Totals count at most one ace as 11.

const BJCard = preload("res://scripts/engine/bj_card.gd")

var cards: Array[BJCard] = []
var bet_cents: int = 0
var doubled: bool = false
var from_split: bool = false
var from_split_aces: bool = false
var stood: bool = false
var surrendered: bool = false
var even_money: bool = false
var settled: bool = false
var outcome: String = ""
var payout_cents: int = 0
## Player decisions in order: H hit, S stand, D double, P split, R surrender.
var actions: String = ""


func add(card: BJCard) -> void:
	cards.append(card)


func card_count() -> int:
	return cards.size()


func hard_total() -> int:
	var total := 0
	for c in cards:
		total += c.pip_value()
	return total


func ace_count() -> int:
	var n := 0
	for c in cards:
		if c.is_ace():
			n += 1
	return n


func is_soft() -> bool:
	return ace_count() > 0 and hard_total() + 10 <= 21


func best_total() -> int:
	var hard := hard_total()
	if ace_count() > 0 and hard + 10 <= 21:
		return hard + 10
	return hard


func is_bust() -> bool:
	return best_total() > 21


func is_blackjack() -> bool:
	return cards.size() == 2 and best_total() == 21 and not from_split


func is_twenty_one() -> bool:
	return best_total() == 21


func is_pair() -> bool:
	return cards.size() == 2 and cards[0].same_rank(cards[1])


func is_finished() -> bool:
	return stood or surrendered or is_bust() or settled


## Display text such as "16", "Soft 18", "Blackjack" or "Bust 24".
func total_text() -> String:
	if cards.is_empty():
		return ""
	if is_blackjack():
		return "Blackjack"
	var t := best_total()
	if t > 21:
		return "Bust %d" % t
	if is_soft() and t < 21:
		return "Soft %d" % t
	return str(t)


func upcard() -> BJCard:
	if cards.is_empty():
		return null
	return cards[cards.size() - 1]


func hole_card() -> BJCard:
	if cards.is_empty():
		return null
	return cards[0]


func ids() -> PackedStringArray:
	var out := PackedStringArray()
	for c in cards:
		out.append(c.id())
	return out


func face_keys() -> PackedStringArray:
	var out := PackedStringArray()
	for c in cards:
		out.append(c.face_key())
	return out


func clear() -> void:
	cards.clear()
	bet_cents = 0
	doubled = false
	from_split = false
	from_split_aces = false
	stood = false
	surrendered = false
	even_money = false
	settled = false
	outcome = ""
	payout_cents = 0
	actions = ""
