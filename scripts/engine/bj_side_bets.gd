class_name BJSideBets
extends RefCounted
## Side bets resolved on the initial deal.
##
## Perfect Pairs uses the player's first two cards.
## 21+3 uses the player's first two cards plus the dealer's up-card as a poker hand.

const BJCard = preload("res://scripts/engine/bj_card.gd")

const PERFECT_PAIRS := "pp"
const TWENTY_ONE_THREE := "t3"
const KINDS: PackedStringArray = ["pp", "t3"]

## Winning multipliers ("to 1").
const PP_PAYS := {"perfect": 25, "colored": 12, "mixed": 6}
const T3_PAYS := {"suited_trips": 100, "straight_flush": 40, "three_kind": 30, "straight": 10, "flush": 5}

## Exact house edge (percent) by deck count, from tools/side_bet_edges.py.
const HOUSE_EDGE := {
	"pp": {1: 47.06, 2: 22.33, 4: 10.14, 6: 6.11, 8: 4.10},
	"t3": {1: 18.21, 2: 11.17, 4: 6.39, 6: 4.62, 8: 3.70},
}

const TITLES := {
	"pp": "Perfect Pairs",
	"t3": "21+3",
}
const RESULT_TITLES := {
	"perfect": "Perfect Pair",
	"colored": "Colored Pair",
	"mixed": "Mixed Pair",
	"suited_trips": "Suited Trips",
	"straight_flush": "Straight Flush",
	"three_kind": "Three of a Kind",
	"straight": "Straight",
	"flush": "Flush",
}


## Returns "perfect", "colored", "mixed" or "" for no pair.
static func perfect_pairs(a: BJCard, b: BJCard) -> String:
	if a == null or b == null or a.rank != b.rank:
		return ""
	if a.suit == b.suit:
		return "perfect"
	if a.is_red() == b.is_red():
		return "colored"
	return "mixed"


## Returns the best 21+3 result for three cards, or "" when nothing pays.
static func twenty_one_three(a: BJCard, b: BJCard, c: BJCard) -> String:
	if a == null or b == null or c == null:
		return ""
	var flush := a.suit == b.suit and b.suit == c.suit
	var trips := a.rank == b.rank and b.rank == c.rank
	if trips and flush:
		return "suited_trips"
	var straight := is_straight([a.rank, b.rank, c.rank])
	if straight and flush:
		return "straight_flush"
	if trips:
		return "three_kind"
	if straight:
		return "straight"
	if flush:
		return "flush"
	return ""


## Three distinct consecutive ranks. Ace plays low (A-2-3) or high (Q-K-A); no wrap.
static func is_straight(ranks: Array) -> bool:
	var r: Array = ranks.duplicate()
	r.sort()
	if r[0] == r[1] or r[1] == r[2]:
		return false
	if r[2] - r[0] == 2:
		return true
	return r == [1, 12, 13]


static func multiplier(kind: String, result: String) -> int:
	if result.is_empty():
		return 0
	if kind == PERFECT_PAIRS:
		return int(PP_PAYS.get(result, 0))
	if kind == TWENTY_ONE_THREE:
		return int(T3_PAYS.get(result, 0))
	return 0


## Total return (stake + winnings) in cents.
static func payout(kind: String, result: String, stake_cents: int) -> int:
	var m := multiplier(kind, result)
	if m <= 0:
		return 0
	return stake_cents * (m + 1)


static func house_edge(kind: String, decks: int) -> float:
	return float(HOUSE_EDGE.get(kind, {}).get(decks, 0.0))


static func title(kind: String) -> String:
	return str(TITLES.get(kind, kind))


static func result_title(result: String) -> String:
	return str(RESULT_TITLES.get(result, "No win"))


static func paytable_text(kind: String) -> String:
	if kind == PERFECT_PAIRS:
		return "Perfect 25:1  ·  Colored 12:1  ·  Mixed 6:1"
	return "Suited Trips 100:1  ·  Straight Flush 40:1  ·  Trips 30:1  ·  Straight 10:1  ·  Flush 5:1"
