class_name BJStrategy
extends RefCounted
## Basic strategy for the active table rules.
##
## The chart is the standard total-dependent multi-deck strategy with its
## H17, DAS and late-surrender variations, plus the two well-known one/two-deck
## doubling changes (11 vs A and 9 vs 2). Chart codes:
##   H  hit            S  stand
##   D  double, otherwise hit          Ds double, otherwise stand
##   P  split          Ph split when double-after-split is allowed, otherwise play the total
##   Rh surrender, otherwise hit       Rs surrender, otherwise stand
##   Rp surrender, otherwise split
## An empty pair code means "don't split; play the total".

const BJCard = preload("res://scripts/engine/bj_card.gd")
const BJHand = preload("res://scripts/engine/bj_hand.gd")
const BJRules = preload("res://scripts/engine/bj_rules.gd")

const UPCARDS: Array[int] = [2, 3, 4, 5, 6, 7, 8, 9, 10, 11]
const ACTION_TITLES := {
	"hit": "Hit",
	"stand": "Stand",
	"double": "Double",
	"split": "Split",
	"surrender": "Surrender",
	"insurance_no": "Decline insurance",
	"insurance_yes": "Take insurance",
}


## Card value used by the chart: aces are 11.
static func card_value(card: BJCard) -> int:
	if card == null:
		return 0
	return 11 if card.is_ace() else card.pip_value()


static func hard_code(total: int, up: int, rules: BJRules) -> String:
	var h17 := rules.dealer_hits_soft_17
	var few_decks := rules.decks <= 2
	if total >= 18:
		return "S"
	if total == 17:
		return "Rs" if h17 and up == 11 else "S"
	if total == 16:
		if up <= 6:
			return "S"
		if up >= 9:
			return "Rh"
		return "H"
	if total == 15:
		if up <= 6:
			return "S"
		if up == 10 or (h17 and up == 11):
			return "Rh"
		return "H"
	if total == 13 or total == 14:
		return "S" if up <= 6 else "H"
	if total == 12:
		return "S" if up >= 4 and up <= 6 else "H"
	if total == 11:
		if up <= 10:
			return "D"
		return "D" if h17 or few_decks else "H"
	if total == 10:
		return "D" if up <= 9 else "H"
	if total == 9:
		if up >= 3 and up <= 6:
			return "D"
		return "D" if up == 2 and few_decks else "H"
	return "H"


static func soft_code(total: int, up: int, rules: BJRules) -> String:
	var h17 := rules.dealer_hits_soft_17
	if total >= 20:
		return "S"
	if total == 19:
		return "Ds" if h17 and up == 6 else "S"
	if total == 18:
		if up >= 3 and up <= 6:
			return "Ds"
		if up == 2:
			return "Ds" if h17 else "S"
		if up == 7 or up == 8:
			return "S"
		return "H"
	if total == 17:
		return "D" if up >= 3 and up <= 6 else "H"
	if total == 15 or total == 16:
		return "D" if up >= 4 and up <= 6 else "H"
	if total == 13 or total == 14:
		return "D" if up >= 5 and up <= 6 else "H"
	return "H"


## `value` is the pair card value (aces 11).
static func pair_code(value: int, up: int, rules: BJRules) -> String:
	match value:
		11:
			return "P"
		10, 5:
			return ""
		9:
			return "P" if up <= 6 or up == 8 or up == 9 else ""
		8:
			return "Rp" if rules.dealer_hits_soft_17 and up == 11 else "P"
		7:
			return "P" if up <= 7 else ""
		6:
			if up == 2:
				return "Ph"
			return "P" if up <= 6 else ""
		4:
			return "Ph" if up == 5 or up == 6 else ""
		3, 2:
			if up <= 3:
				return "Ph"
			return "P" if up <= 7 else ""
	return ""


## The basic-strategy action for `hand` against the dealer's up-card, limited to
## what is currently legal. Returns hit / stand / double / split / surrender.
static func recommend(hand: BJHand, up: BJCard, rules: BJRules, can_double: bool, can_split: bool, can_surrender: bool) -> String:
	var u := card_value(up)
	if can_split and hand.is_pair():
		match pair_code(card_value(hand.cards[0]), u, rules):
			"P":
				return "split"
			"Ph":
				if rules.double_after_split:
					return "split"
			"Rp":
				return "surrender" if can_surrender else "split"
	if hand.from_split_aces:
		return "stand"
	var total := hand.best_total()
	var code := soft_code(total, u, rules) if hand.is_soft() else hard_code(total, u, rules)
	return resolve(code, can_double, can_surrender)


static func resolve(code: String, can_double: bool, can_surrender: bool) -> String:
	match code:
		"S":
			return "stand"
		"D":
			return "double" if can_double else "hit"
		"Ds":
			return "double" if can_double else "stand"
		"Rh":
			return "surrender" if can_surrender else "hit"
		"Rs":
			return "surrender" if can_surrender else "stand"
		"Rp":
			return "surrender" if can_surrender else "split"
		"P", "Ph":
			return "split"
	return "hit"


## Collapses codes the table rules make irrelevant (no surrender, DAS on/off).
static func display_code(code: String, rules: BJRules) -> String:
	match code:
		"Rh":
			return code if rules.late_surrender else "H"
		"Rs":
			return code if rules.late_surrender else "S"
		"Rp":
			return code if rules.late_surrender else "P"
		"Ph":
			return "P" if rules.double_after_split else "H"
	return code


## Full chart for display: { "hard": [[label, [codes x10]]...], "soft": ..., "pairs": ... }.
static func chart(rules: BJRules) -> Dictionary:
	var hard: Array = []
	for total in [8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18]:
		var row: PackedStringArray = PackedStringArray()
		for up in UPCARDS:
			row.append(display_code(hard_code(total, up, rules), rules))
		var label := str(total)
		if total == 8:
			label = "5–8"
		elif total == 18:
			label = "18+"
		hard.append([label, row])
	var soft: Array = []
	for other in range(2, 10):
		var row: PackedStringArray = PackedStringArray()
		for up in UPCARDS:
			row.append(display_code(soft_code(11 + other, up, rules), rules))
		soft.append(["A,%d" % other, row])
	var pairs: Array = []
	for v in [2, 3, 4, 5, 6, 7, 8, 9, 10, 11]:
		var row: PackedStringArray = PackedStringArray()
		for up in UPCARDS:
			var code := pair_code(v, up, rules)
			if code.is_empty() or (code == "Ph" and not rules.double_after_split):
				code = soft_code(12, up, rules) if v == 11 else hard_code(v * 2, up, rules)
			row.append(display_code(code, rules))
		var name := "A" if v == 11 else str(v)
		pairs.append(["%s,%s" % [name, name], row])
	return {"hard": hard, "soft": soft, "pairs": pairs}


static func action_title(action: String) -> String:
	return str(ACTION_TITLES.get(action, action.capitalize()))


## Short reason text such as "hard 11 vs 6" or "pair of 8s vs A".
static func situation_text(hand: BJHand, up: BJCard) -> String:
	var u := "A" if up != null and up.is_ace() else str(card_value(up))
	if hand.is_pair():
		var r := hand.cards[0].rank_name()
		return "pair of %s vs %s" % ["aces" if r == "A" else r + "s", u]
	if hand.is_soft():
		return "soft %d vs %s" % [hand.best_total(), u]
	return "hard %d vs %s" % [hand.best_total(), u]
