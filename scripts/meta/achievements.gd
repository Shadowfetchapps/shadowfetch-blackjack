extends Node
## Autoload `Achievements`: unlockable milestones evaluated after every round.
## Stored in `<data>/achievements.json` as { id: unix_time }.

const _Paths = preload("res://scripts/save/paths.gd")
const _Log = preload("res://scripts/engine/bj_log.gd")
const _Money = preload("res://scripts/engine/bj_money.gd")

signal unlocked(def: Dictionary)

const DEFS: Array[Dictionary] = [
	{"id": "first_hand", "title": "Take a Seat", "desc": "Play your first hand.", "icon": "♠"},
	{"id": "first_win", "title": "In the Black", "desc": "Win a hand.", "icon": "✓"},
	{"id": "natural", "title": "Natural", "desc": "Be dealt a blackjack.", "icon": "21"},
	{"id": "natural_10", "title": "Natural Talent", "desc": "Be dealt 10 blackjacks.", "icon": "10"},
	{"id": "double_win", "title": "Double Down", "desc": "Win a doubled hand.", "icon": "×2"},
	{"id": "split_sweep", "title": "Two for Two", "desc": "Win every hand of a split.", "icon": "⑂"},
	{"id": "split_four", "title": "Full Spread", "desc": "Split into four hands.", "icon": "4"},
	{"id": "five_card", "title": "Five Card Charlie", "desc": "Win with five or more cards.", "icon": "5"},
	{"id": "triple_seven", "title": "Lucky Sevens", "desc": "Make 21 with three sevens.", "icon": "7"},
	{"id": "streak_5", "title": "Hot Streak", "desc": "Win five hands in a row.", "icon": "5×"},
	{"id": "streak_10", "title": "On Fire", "desc": "Win ten hands in a row.", "icon": "10×"},
	{"id": "perfect_pair", "title": "Perfect Match", "desc": "Hit a Perfect Pair side bet.", "icon": "♥♥"},
	{"id": "suited_trips", "title": "Suited Trips", "desc": "Hit suited trips on 21+3.", "icon": "♦♦♦"},
	{"id": "side_win", "title": "Side Action", "desc": "Win any side bet.", "icon": "+"},
	{"id": "insured", "title": "Covered", "desc": "Win an insurance bet.", "icon": "2:1"},
	{"id": "even_money", "title": "Sure Thing", "desc": "Take even money on a blackjack.", "icon": "1:1"},
	{"id": "surrender", "title": "Live to Fight", "desc": "Surrender a hand.", "icon": "½"},
	{"id": "high_roller", "title": "High Roller", "desc": "Place a $1,000 main bet.", "icon": "1K"},
	{"id": "table_max", "title": "Table Max", "desc": "Bet the $10,000 table maximum.", "icon": "MAX"},
	{"id": "bankroll_20k", "title": "Doubled Up", "desc": "Reach a $20,000 bankroll.", "icon": "20K"},
	{"id": "bankroll_100k", "title": "Whale", "desc": "Reach a $100,000 bankroll.", "icon": "100K"},
	{"id": "comeback", "title": "Comeback Kid", "desc": "Win a hand while holding under $1,000.", "icon": "↺"},
	{"id": "hands_100", "title": "Regular", "desc": "Play 100 hands.", "icon": "100"},
	{"id": "hands_1000", "title": "Card Room Veteran", "desc": "Play 1,000 hands.", "icon": "1000"},
	{"id": "by_the_book", "title": "By the Book", "desc": "Make 50 basic-strategy decisions in a row.", "icon": "✎"},
	{"id": "fresh_stack", "title": "Fresh Stack", "desc": "Rebuy after going broke.", "icon": "$"},
]

var unlocked_at: Dictionary = {}


func _ready() -> void:
	load_state()


func path() -> String:
	return _Paths.data_dir().path_join("achievements.json")


func def(id: String) -> Dictionary:
	for d in DEFS:
		if d["id"] == id:
			return d
	return {}


func is_unlocked(id: String) -> bool:
	return unlocked_at.has(id)


func unlocked_count() -> int:
	return unlocked_at.size()


func total() -> int:
	return DEFS.size()


## Unlocks `id` if it is new. Returns true when it was newly unlocked.
func unlock(id: String, save: bool = true) -> bool:
	if unlocked_at.has(id) or def(id).is_empty():
		return false
	unlocked_at[id] = int(Time.get_unix_time_from_system())
	if save:
		save_state()
	unlocked.emit(def(id))
	return true


## Checks one settled round (and the lifetime stats it was folded into).
## Returns the ids unlocked by this round.
func evaluate(rec: Dictionary, stats) -> PackedStringArray:
	var fresh := PackedStringArray()
	var hands: Array = rec.get("hands", [])
	var won_any := false
	var split_round := hands.size() > 1
	var split_all_won := split_round
	for h in hands:
		var outcome := str(h.get("outcome", ""))
		var won := outcome in ["win", "blackjack", "even_money"]
		won_any = won_any or won
		if not won:
			split_all_won = false
		if outcome == "blackjack" or outcome == "even_money":
			_try(fresh, "natural")
		if won and bool(h.get("doubled", false)):
			_try(fresh, "double_win")
		var cards: Array = h.get("cards", [])
		if won and cards.size() >= 5:
			_try(fresh, "five_card")
		if cards.size() == 3 and int(h.get("total", 0)) == 21:
			var sevens := true
			for c in cards:
				if not str(c).begins_with("7"):
					sevens = false
			if sevens:
				_try(fresh, "triple_seven")
		if outcome == "surrender":
			_try(fresh, "surrender")
	if not hands.is_empty():
		_try(fresh, "first_hand")
	if won_any:
		_try(fresh, "first_win")
		if int(rec.get("bankroll_before", 1_000_000)) < 100_000:
			_try(fresh, "comeback")
	if split_all_won:
		_try(fresh, "split_sweep")
	if hands.size() >= 4:
		_try(fresh, "split_four")
	for s in rec.get("side", []):
		if int(s.get("payout", 0)) > 0:
			_try(fresh, "side_win")
			match str(s.get("result", "")):
				"perfect":
					_try(fresh, "perfect_pair")
				"suited_trips":
					_try(fresh, "suited_trips")
	if int(rec.get("insurance_payout", 0)) > 0:
		_try(fresh, "insured")
	if bool(rec.get("even_money", false)):
		_try(fresh, "even_money")
	if not hands.is_empty():
		var first: Dictionary = hands[0]
		var base_bet := int(first.get("bet", 0))
		if bool(first.get("doubled", false)):
			base_bet /= 2
		if base_bet >= 100_000:
			_try(fresh, "high_roller")
		if base_bet >= _Money.TABLE_MAX:
			_try(fresh, "table_max")
	var bankroll := int(rec.get("bankroll", 0))
	if bankroll >= 2_000_000:
		_try(fresh, "bankroll_20k")
	if bankroll >= 10_000_000:
		_try(fresh, "bankroll_100k")
	if stats != null:
		if int(stats.blackjacks) >= 10:
			_try(fresh, "natural_10")
		if int(stats.best_streak) >= 5:
			_try(fresh, "streak_5")
		if int(stats.best_streak) >= 10:
			_try(fresh, "streak_10")
		if int(stats.hands) >= 100:
			_try(fresh, "hands_100")
		if int(stats.hands) >= 1000:
			_try(fresh, "hands_1000")
		if int(stats.best_strategy_run) >= 50:
			_try(fresh, "by_the_book")
	if not fresh.is_empty():
		save_state()
	return fresh


func reset() -> void:
	unlocked_at.clear()
	save_state()


func save_state() -> void:
	if not _Paths.write_json(path(), {"version": 1, "unlocked": unlocked_at}):
		_Log.warn("Could not write achievements")


func load_state() -> void:
	unlocked_at.clear()
	var parsed: Variant = _Paths.read_json(path())
	if parsed is Dictionary and parsed.get("unlocked", null) is Dictionary:
		for k in parsed["unlocked"]:
			if not def(str(k)).is_empty():
				unlocked_at[str(k)] = int(parsed["unlocked"][k])


func _try(fresh: PackedStringArray, id: String) -> void:
	if unlock(id, false):
		fresh.append(id)
