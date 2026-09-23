class_name BJMoney
extends RefCounted
## Integer-cent money helpers. Fictional currency only.

const DOLLAR := 100
const STARTING_BANKROLL := 1_000_000
const CHIP_VALUES: Array[int] = [100, 500, 2500, 10000, 50000, 100000]
const CHIP_LABELS: PackedStringArray = ["$1", "$5", "$25", "$100", "$500", "$1K"]
## Table limits (cents).
const TABLE_MIN := 100
const TABLE_MAX := 1_000_000
const SIDE_MAX := 100_000


static func format_cents(cents: int) -> String:
	var sign := "-" if cents < 0 else ""
	var n: int = absi(cents)
	var whole := n / 100
	var frac := n % 100
	return "%s$%s.%02d" % [sign, _group(whole), frac]


## "$1,250" when there are no cents, otherwise "$1,250.50".
static func format_short(cents: int) -> String:
	if absi(cents) % 100 != 0:
		return format_cents(cents)
	var sign := "-" if cents < 0 else ""
	return "%s$%s" % [sign, _group(absi(cents) / 100)]


## Compact label for tight spaces: "$950", "$1.5K", "$12K", "$1.2M".
static func format_compact(cents: int) -> String:
	var sign := "-" if cents < 0 else ""
	var dollars := absi(cents) / 100.0
	if dollars >= 1_000_000.0:
		return "%s$%sM" % [sign, _trim(dollars / 1_000_000.0)]
	if dollars >= 1000.0:
		return "%s$%sK" % [sign, _trim(dollars / 1000.0)]
	return sign + format_short(absi(cents))


static func format_signed(cents: int) -> String:
	if cents > 0:
		return "+" + format_cents(cents)
	return format_cents(cents)


static func format_signed_short(cents: int) -> String:
	if cents > 0:
		return "+" + format_short(cents)
	return format_short(cents)


static func breakdown(cents: int) -> Array[int]:
	var out: Array[int] = []
	var left := maxi(cents, 0)
	for i in range(CHIP_VALUES.size() - 1, -1, -1):
		var v: int = CHIP_VALUES[i]
		while left >= v:
			out.append(v)
			left -= v
	return out


static func chip_label(cents: int) -> String:
	var i := CHIP_VALUES.find(cents)
	return CHIP_LABELS[i] if i >= 0 else format_short(cents)


## Total return (stake + winnings) for a natural. 3:2 by default, 6:5 when requested.
static func blackjack_payout(bet_cents: int, six_five: bool = false) -> int:
	if six_five:
		return bet_cents + (bet_cents * 6 / 5)
	return bet_cents + (bet_cents * 3 / 2)


static func even_money_return(bet_cents: int) -> int:
	return bet_cents * 2


static func insurance_cost(bet_cents: int) -> int:
	return bet_cents / 2


static func insurance_win(ins_cents: int) -> int:
	return ins_cents * 3


static func _group(whole: int) -> String:
	var digits := str(whole)
	var grouped := ""
	while digits.length() > 3:
		grouped = "," + digits.substr(digits.length() - 3, 3) + grouped
		digits = digits.substr(0, digits.length() - 3)
	return digits + grouped


static func _trim(v: float) -> String:
	if v >= 100.0 or is_equal_approx(v, round(v)):
		return str(int(round(v)))
	return ("%.1f" % v).trim_suffix(".0")
