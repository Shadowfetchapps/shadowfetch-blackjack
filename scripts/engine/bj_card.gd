class_name BJCard
extends RefCounted
## One physical card from the shoe. `uid()` is unique across every deck in the shoe.

const SUITS: PackedStringArray = ["S", "H", "D", "C"]
const SUIT_NAMES: PackedStringArray = ["spades", "hearts", "diamonds", "clubs"]
const SUIT_SYMBOLS: PackedStringArray = ["♠", "♥", "♦", "♣"]
const RANK_NAMES: PackedStringArray = [
	"", "A", "2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K"
]


var suit: int
var rank: int
var deck: int
## Order in which the shoe dealt this card (used to sequence table animations).
var seq: int = 0


func _init(p_suit: int = 0, p_rank: int = 1, p_deck: int = 0) -> void:
	suit = p_suit
	rank = p_rank
	deck = p_deck


func id() -> String:
	return "%d-%s-%s" % [deck, suit_code(), rank_name()]


## Integer identity: deck * 52 + suit * 13 + (rank - 1). Stable and unique within a shoe.
func uid() -> int:
	return deck * 52 + suit * 13 + (rank - 1)


func face_key() -> String:
	return rank_name() + suit_code()


func suit_code() -> String:
	return SUITS[suit]


func suit_name() -> String:
	return SUIT_NAMES[suit]


func suit_symbol() -> String:
	return SUIT_SYMBOLS[suit]


func rank_name() -> String:
	return RANK_NAMES[rank]


## Short human label such as "K♠" or "10♦".
func label() -> String:
	return rank_name() + suit_symbol()


func is_red() -> bool:
	return suit == 1 or suit == 2


func is_ace() -> bool:
	return rank == 1


func is_face() -> bool:
	return rank >= 11


func is_ten_value() -> bool:
	return rank >= 10


func pip_value() -> int:
	if rank == 1:
		return 1
	if rank >= 10:
		return 10
	return rank


## Hi-Lo count tag: 2-6 = +1, 7-9 = 0, tens and aces = -1.
func hilo() -> int:
	if rank >= 2 and rank <= 6:
		return 1
	if rank >= 7 and rank <= 9:
		return 0
	return -1


func same_rank(other: BJCard) -> bool:
	return other != null and rank == other.rank


func duplicate_card() -> BJCard:
	return BJCard.new(suit, rank, deck)


## Parses "KS", "10h", "AD" or "3:QC" (deck 3). Returns null on bad input.
static func parse(token: String) -> BJCard:
	var t := token.strip_edges().to_upper()
	var deck_i := 0
	if t.contains(":"):
		var parts := t.split(":")
		deck_i = int(parts[0])
		t = parts[1]
	if t.length() < 2:
		return null
	var suit_c := t.substr(t.length() - 1, 1)
	var rank_s := t.substr(0, t.length() - 1)
	var s := SUITS.find(suit_c)
	var r := RANK_NAMES.find(rank_s)
	if s < 0 or r < 1:
		return null
	return BJCard.new(s, r, deck_i)


func _to_string() -> String:
	return rank_name() + suit_code()
