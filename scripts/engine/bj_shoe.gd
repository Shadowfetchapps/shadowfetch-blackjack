class_name BJShoe
extends RefCounted

const BJCard = preload("res://scripts/engine/bj_card.gd")
const BJHand = preload("res://scripts/engine/bj_hand.gd")

const DECKS := 6
const CARDS_PER_DECK := 52
const CAPACITY := DECKS * CARDS_PER_DECK
const CUT_MIN_FROM_END := 60
const CUT_MAX_FROM_END := 78
const RESHUFFLE_FLOOR := 30

var _live: Array[BJCard] = []
var _discard: Array[BJCard] = []
var _in_play: Array[BJCard] = []
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var cut_index: int = 0
var cut_reached: bool = false
var shuffle_count: int = 0
var draw_count_since_shuffle: int = 0


func _init(seed_value: int = 0) -> void:
	if seed_value != 0:
		rng.seed = seed_value
	else:
		rng.randomize()
	reshuffle()


func remaining() -> int:
	return _live.size()


func discarded_count() -> int:
	return _discard.size()


func in_play_count() -> int:
	return _in_play.size()


func total_accounted() -> int:
	return remaining() + discarded_count() + in_play_count()


func needs_reshuffle() -> bool:
	return cut_reached or remaining() < RESHUFFLE_FLOOR


func reshuffle() -> void:
	_live.clear()
	_discard.clear()
	_in_play.clear()
	for d in DECKS:
		for s in 4:
			for r in range(1, 14):
				_live.append(BJCard.new(s, r, d))
	_fisher_yates()
	var from_end := rng.randi_range(CUT_MIN_FROM_END, CUT_MAX_FROM_END)
	cut_index = maxi(CAPACITY - from_end, 1)
	cut_reached = false
	draw_count_since_shuffle = 0
	shuffle_count += 1


func draw() -> BJCard:
	if _live.is_empty():
		reshuffle()
	var card: BJCard = _live.pop_back()
	_in_play.append(card)
	draw_count_since_shuffle += 1
	if draw_count_since_shuffle >= cut_index:
		cut_reached = true
	return card


func discard_cards(cards: Array) -> void:
	for item in cards:
		var card: BJCard = item
		var idx := _index_of(_in_play, card)
		if idx >= 0:
			_in_play.remove_at(idx)
		_discard.append(card)


func discard_hand(hand: BJHand) -> void:
	var copy: Array = []
	for c in hand.cards:
		copy.append(c)
	discard_cards(copy)


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
	for c in _in_play:
		out.append(c.id())
	return out


func unique_ok() -> bool:
	var seen := {}
	for id in all_known_ids():
		if seen.has(id):
			return false
		seen[id] = true
	return seen.size() == CAPACITY and total_accounted() == CAPACITY


func _fisher_yates() -> void:
	for i in range(_live.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp: BJCard = _live[i]
		_live[i] = _live[j]
		_live[j] = tmp


func _index_of(arr: Array[BJCard], card: BJCard) -> int:
	for i in arr.size():
		if arr[i].id() == card.id():
			return i
	return -1


func _remove_matching(card: BJCard) -> void:
	var idx := _index_of(_live, card)
	if idx >= 0:
		_live.remove_at(idx)
		return
	idx = _index_of(_discard, card)
	if idx >= 0:
		_discard.remove_at(idx)
		return
	idx = _index_of(_in_play, card)
	if idx >= 0:
		_in_play.remove_at(idx)
