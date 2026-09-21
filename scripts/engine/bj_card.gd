class_name BJCard
extends RefCounted

const SUITS: PackedStringArray = ["S", "H", "D", "C"]
const SUIT_NAMES: PackedStringArray = ["spades", "hearts", "diamonds", "clubs"]
const RANK_NAMES: PackedStringArray = [
	"", "A", "2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K"
]


var suit: int
var rank: int
var deck: int


func _init(p_suit: int = 0, p_rank: int = 1, p_deck: int = 0) -> void:
	suit = p_suit
	rank = p_rank
	deck = p_deck


func id() -> String:
	return "%d-%s-%s" % [deck, suit_code(), rank_name()]


func suit_code() -> String:
	return SUITS[suit]


func suit_name() -> String:
	return SUIT_NAMES[suit]


func rank_name() -> String:
	return RANK_NAMES[rank]


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


func same_rank(other: BJCard) -> bool:
	return other != null and rank == other.rank


func duplicate_card() -> BJCard:
	return BJCard.new(suit, rank, deck)


static func parse(token: String) -> BJCard:
	var t := token.strip_edges().to_upper()
	var deck_i := 0
	if t.contains(":"):
		var parts := t.split(":")
		deck_i = int(parts[0])
		t = parts[1]
	var suit_c := t.substr(t.length() - 1, 1)
	var rank_s := t.substr(0, t.length() - 1)
	var s := SUITS.find(suit_c)
	var r := RANK_NAMES.find(rank_s)
	if s < 0 or r < 1:
		return null
	return BJCard.new(s, r, deck_i)


func _to_string() -> String:
	return rank_name() + suit_code()
