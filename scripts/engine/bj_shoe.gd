class_name BJShoe
extends RefCounted
## A multi-deck shoe with a cut card. Every card is always in exactly one of:
## the live draw stack, the discard tray, or in play on the table.

const BJCard = preload("res://scripts/engine/bj_card.gd")
const BJHand = preload("res://scripts/engine/bj_hand.gd")

const DEFAULT_DECKS := 6
const CARDS_PER_DECK := 52
const CUT_JITTER := 6
## Minimum cards required in the live stack before a new round is dealt.
const RESHUFFLE_FLOOR := 20

signal reshuffled(full: bool)

var decks: int = DEFAULT_DECKS
var capacity: int = DEFAULT_DECKS * CARDS_PER_DECK
var penetration: float = 0.75
var _live: Array[BJCard] = []
var _discard: Array[BJCard] = []
var _in_play: Dictionary = {}
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var cut_index: int = 0
var cut_reached: bool = false
var shuffle_count: int = 0
var draw_count_since_shuffle: int = 0
var total_draws: int = 0


func _init(seed_value: int = 0, p_decks: int = DEFAULT_DECKS, p_penetration: float = 0.75) -> void:
	if seed_value != 0:
		rng.seed = seed_value
	else:
		rng.randomize()
	configure(p_decks, p_penetration)


## Rebuilds the shoe for a new deck count / penetration and shuffles.
func configure(p_decks: int, p_penetration: float) -> void:
	decks = clampi(p_decks, 1, 8)
	capacity = decks * CARDS_PER_DECK
	penetration = clampf(p_penetration, 0.5, 0.9)
	reshuffle()


func remaining() -> int:
	return _live.size()


func discarded_count() -> int:
	return _discard.size()


func in_play_count() -> int:
	return _in_play.size()


func total_accounted() -> int:
	return remaining() + discarded_count() + in_play_count()


func decks_remaining() -> float:
	return float(remaining()) / float(CARDS_PER_DECK)


## Fraction of the shoe dealt since the last full shuffle (0..1).
func dealt_fraction() -> float:
	return clampf(float(capacity - remaining()) / float(capacity), 0.0, 1.0)


func cut_fraction() -> float:
	return float(cut_index) / float(capacity)


func needs_reshuffle() -> bool:
	return cut_reached or remaining() < RESHUFFLE_FLOOR


## Full shuffle: every card (including any still on the table) returns to the shoe.
func reshuffle() -> void:
	_live.clear()
	_discard.clear()
	_in_play.clear()
	for d in decks:
		for s in 4:
			for r in range(1, 14):
				_live.append(BJCard.new(s, r, d))
	_fisher_yates()
	var target := int(round(float(capacity) * penetration)) + rng.randi_range(-CUT_JITTER, CUT_JITTER)
	cut_index = clampi(target, capacity / 2, capacity - 12)
	cut_reached = false
	draw_count_since_shuffle = 0
	shuffle_count += 1
	reshuffled.emit(true)


func draw() -> BJCard:
	if _live.is_empty():
		_emergency_reshuffle()
	var card: BJCard = _live.pop_back()
	total_draws += 1
	card.seq = total_draws
	_in_play[card.uid()] = card
	draw_count_since_shuffle += 1
	if draw_count_since_shuffle >= cut_index:
		cut_reached = true
	return card


func discard_cards(cards: Array) -> void:
	for item in cards:
		var card: BJCard = item
		_in_play.erase(card.uid())
		_discard.append(card)


func discard_hand(hand: BJHand) -> void:
	discard_cards(hand.cards.duplicate())


## Test helper: moves the given cards (matched by uid) to the top of the draw stack,
## first element drawn first.
func force_next(cards: Array) -> void:
	for i in range(cards.size() - 1, -1, -1):
		var card: BJCard = cards[i]
		_remove_matching(card)
		_live.append(card)


func peek_remaining_ids() -> PackedStringArray:
	var out := PackedStringArray()
	for c in _live:
		out.append(c.id())
	return out


func all_known_ids() -> PackedStringArray:
	var out := PackedStringArray()
	for c in _live:
		out.append(c.id())
	for c in _discard:
		out.append(c.id())
	for c in _in_play.values():
		out.append(c.id())
	return out


## Conservation check: every card of every deck appears exactly once.
func unique_ok() -> bool:
	if total_accounted() != capacity:
		return false
	var seen := PackedByteArray()
	seen.resize(capacity)
	for c in _live:
		if not _mark(seen, c):
			return false
	for c in _discard:
		if not _mark(seen, c):
			return false
	for c in _in_play.values():
		if not _mark(seen, c):
			return false
	return true


func _mark(seen: PackedByteArray, c: BJCard) -> bool:
	var u := c.uid()
	if u < 0 or u >= capacity or seen[u] != 0:
		return false
	seen[u] = 1
	return true


## The live stack ran dry mid-round: shuffle the discard tray back in (cards on the
## table stay where they are) and force a full reshuffle before the next round.
func _emergency_reshuffle() -> void:
	if _discard.is_empty():
		push_warning("Shoe exhausted with nothing to reshuffle; rebuilding")
		reshuffle()
		return
	_live.append_array(_discard)
	_discard.clear()
	_fisher_yates()
	cut_reached = true
	reshuffled.emit(false)


func _fisher_yates() -> void:
	for i in range(_live.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp: BJCard = _live[i]
		_live[i] = _live[j]
		_live[j] = tmp


func _remove_matching(card: BJCard) -> void:
	var u := card.uid()
	for i in range(_live.size() - 1, -1, -1):
		if _live[i].uid() == u:
			_live.remove_at(i)
			return
	for i in _discard.size():
		if _discard[i].uid() == u:
			_discard.remove_at(i)
			return
	_in_play.erase(u)
