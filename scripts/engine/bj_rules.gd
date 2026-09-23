class_name BJRules
extends RefCounted
## Table rule set. Copied into the engine at the deal boundary so a round never
## changes rules mid-hand.

const DECK_OPTIONS: Array[int] = [1, 2, 4, 6, 8]
const MAX_HAND_OPTIONS: Array[int] = [2, 3, 4]
const PENETRATION_MIN := 0.60
const PENETRATION_MAX := 0.85

## Approximate house-edge contributions (percent, basic strategy) relative to an
## 8-deck, S17, no-DAS, no-surrender, no-RSA, split-to-4, 3:2, peek baseline.
## These are the widely published rule-effect estimates; the total is an estimate.
const EDGE_BASE := 0.57
const EDGE_DECKS := {1: -0.48, 2: -0.19, 4: -0.06, 6: -0.02, 8: 0.0}
const EDGE_H17 := 0.22
const EDGE_DAS := -0.14
const EDGE_RSA := -0.08
const EDGE_LATE_SURRENDER := -0.08
const EDGE_SIX_FIVE := 1.39
const EDGE_MAX_HANDS := {2: 0.05, 3: 0.01, 4: 0.0}

const PRESETS := {
	"strip": {
		"title": "Vegas Strip",
		"rules": {"decks": 6, "dealer_hits_soft_17": false, "blackjack_pays_6_5": false, "double_after_split": true,
			"resplit_aces": false, "max_hands": 4, "late_surrender": true, "penetration": 0.75},
	},
	"downtown": {
		"title": "Downtown Double Deck",
		"rules": {"decks": 2, "dealer_hits_soft_17": true, "blackjack_pays_6_5": false, "double_after_split": true,
			"resplit_aces": false, "max_hands": 4, "late_surrender": false, "penetration": 0.70},
	},
	"atlantic": {
		"title": "Atlantic Eight Deck",
		"rules": {"decks": 8, "dealer_hits_soft_17": false, "blackjack_pays_6_5": false, "double_after_split": true,
			"resplit_aces": true, "max_hands": 4, "late_surrender": true, "penetration": 0.80},
	},
	"single": {
		"title": "Single Deck 6:5",
		"rules": {"decks": 1, "dealer_hits_soft_17": true, "blackjack_pays_6_5": true, "double_after_split": false,
			"resplit_aces": false, "max_hands": 2, "late_surrender": false, "penetration": 0.65},
	},
}

var decks: int = 6
var dealer_hits_soft_17: bool = false
var blackjack_pays_6_5: bool = false
var double_after_split: bool = true
var resplit_aces: bool = false
var max_hands: int = 4
var late_surrender: bool = true
var penetration: float = 0.75
var side_bets: bool = true


func duplicate_rules() -> BJRules:
	var r := BJRules.new()
	r.from_dict(to_dict())
	return r


func to_dict() -> Dictionary:
	return {
		"decks": decks,
		"dealer_hits_soft_17": dealer_hits_soft_17,
		"blackjack_pays_6_5": blackjack_pays_6_5,
		"double_after_split": double_after_split,
		"resplit_aces": resplit_aces,
		"max_hands": max_hands,
		"late_surrender": late_surrender,
		"penetration": snappedf(penetration, 0.01),
		"side_bets": side_bets,
	}


## Loads validated values; anything missing or out of range keeps its current value.
func from_dict(d: Dictionary) -> void:
	var dk := int(d.get("decks", decks))
	if DECK_OPTIONS.has(dk):
		decks = dk
	dealer_hits_soft_17 = bool(d.get("dealer_hits_soft_17", dealer_hits_soft_17))
	blackjack_pays_6_5 = bool(d.get("blackjack_pays_6_5", blackjack_pays_6_5))
	double_after_split = bool(d.get("double_after_split", double_after_split))
	resplit_aces = bool(d.get("resplit_aces", resplit_aces))
	var mh := int(d.get("max_hands", max_hands))
	if MAX_HAND_OPTIONS.has(mh):
		max_hands = mh
	late_surrender = bool(d.get("late_surrender", late_surrender))
	var pen: Variant = d.get("penetration", penetration)
	if pen is float or pen is int:
		penetration = clampf(float(pen), PENETRATION_MIN, PENETRATION_MAX)
	side_bets = bool(d.get("side_bets", side_bets))


func equals(other: BJRules) -> bool:
	return other != null and to_dict() == other.to_dict()


## True when switching from `other` to these rules needs a fresh shoe.
func needs_new_shoe(other: BJRules) -> bool:
	return other == null or other.decks != decks or not is_equal_approx(other.penetration, penetration)


func apply_preset(key: String) -> bool:
	if not PRESETS.has(key):
		return false
	from_dict(PRESETS[key]["rules"])
	return true


func matching_preset() -> String:
	for key in PRESETS:
		var probe := BJRules.new()
		probe.side_bets = side_bets
		probe.from_dict(PRESETS[key]["rules"])
		if probe.equals(self):
			return key
	return ""


func house_edge_percent() -> float:
	var edge := EDGE_BASE
	edge += float(EDGE_DECKS.get(decks, 0.0))
	if dealer_hits_soft_17:
		edge += EDGE_H17
	if double_after_split:
		edge += EDGE_DAS
	if resplit_aces:
		edge += EDGE_RSA
	if late_surrender:
		edge += EDGE_LATE_SURRENDER
	if blackjack_pays_6_5:
		edge += EDGE_SIX_FIVE
	edge += float(EDGE_MAX_HANDS.get(max_hands, 0.0))
	return edge


func blackjack_ratio_text() -> String:
	return "6 TO 5" if blackjack_pays_6_5 else "3 TO 2"


func soft17_text() -> String:
	return "DEALER HITS SOFT 17" if dealer_hits_soft_17 else "DEALER MUST STAND ON ALL 17s"


func summary() -> String:
	var bits: PackedStringArray = PackedStringArray()
	bits.append("%d DECK%s" % [decks, "" if decks == 1 else "S"])
	bits.append("H17" if dealer_hits_soft_17 else "S17")
	bits.append("BJ 6:5" if blackjack_pays_6_5 else "BJ 3:2")
	if double_after_split:
		bits.append("DAS")
	if resplit_aces:
		bits.append("RSA")
	if late_surrender:
		bits.append("LATE SURRENDER")
	bits.append("SPLIT TO %d" % max_hands)
	return "  ·  ".join(bits)


func short_summary() -> String:
	var s := "%dD %s %s" % [decks, "H17" if dealer_hits_soft_17 else "S17", "6:5" if blackjack_pays_6_5 else "3:2"]
	if double_after_split:
		s += " DAS"
	if late_surrender:
		s += " LS"
	if resplit_aces:
		s += " RSA"
	return s
