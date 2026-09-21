class_name BJMoney
extends RefCounted

const DOLLAR := 100
const STARTING_BANKROLL := 1_000_000
const CHIP_VALUES: Array[int] = [100, 500, 2500, 10000, 50000, 100000]
const CHIP_LABELS: PackedStringArray = ["$1", "$5", "$25", "$100", "$500", "$1000"]


static func format_cents(cents: int) -> String:
	var sign := "-" if cents < 0 else ""
	var n: int = absi(cents)
	var whole := n / 100
	var frac := n % 100
	var digits := str(whole)
	var grouped := ""
	while digits.length() > 3:
		grouped = "," + digits.substr(digits.length() - 3, 3) + grouped
		digits = digits.substr(0, digits.length() - 3)
	grouped = digits + grouped
	return "%s$%s.%02d" % [sign, grouped, frac]


static func format_signed(cents: int) -> String:
	if cents > 0:
		return "+" + format_cents(cents)
	return format_cents(cents)


static func breakdown(cents: int) -> Array[int]:
	var out: Array[int] = []
	var left := maxi(cents, 0)
	for i in range(CHIP_VALUES.size() - 1, -1, -1):
		var v: int = CHIP_VALUES[i]
		while left >= v:
			out.append(v)
			left -= v
	return out


static func blackjack_payout(bet_cents: int) -> int:
	return bet_cents + (bet_cents * 3 / 2)


static func even_money_return(bet_cents: int) -> int:
	return bet_cents * 2


static func insurance_cost(bet_cents: int) -> int:
	return bet_cents / 2


static func insurance_win(ins_cents: int) -> int:
	return ins_cents * 3
