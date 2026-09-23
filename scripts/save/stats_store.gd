extends Node
## Autoload `StatsStore`: bankroll, lifetime statistics, the session bankroll trail
## and recent hand history. Schema v2; v1 files migrate automatically.

const _Log = preload("res://scripts/engine/bj_log.gd")
const _Money = preload("res://scripts/engine/bj_money.gd")
const _Paths = preload("res://scripts/save/paths.gd")

const STATS_VERSION := 2
const HISTORY_LIMIT := 60
const TRAIL_LIMIT := 400
const BIG := 1_000_000_000_000

signal stats_changed

var bankroll_cents: int = _Money.STARTING_BANKROLL
var last_bet_cents: int = 0
var previous_bet_cents: int = 0
var last_bets: Dictionary = {"main": 0, "pp": 0, "t3": 0}
var lifetime_profit_cents: int = 0
var session_profit_cents: int = 0
var session_hands: int = 0
var hands: int = 0
var rounds: int = 0
var wins: int = 0
var losses: int = 0
var pushes: int = 0
var blackjacks: int = 0
var largest_win_cents: int = 0
var total_wagered_cents: int = 0
var doubles: int = 0
var doubles_won: int = 0
var splits: int = 0
var surrenders: int = 0
var insurance_taken: int = 0
var insurance_won: int = 0
var even_money_taken: int = 0
var side_bets_placed: int = 0
var side_bets_won: int = 0
var side_net_cents: int = 0
var decisions: int = 0
var correct_decisions: int = 0
var strategy_run: int = 0
var best_strategy_run: int = 0
var current_streak: int = 0
var best_streak: int = 0
var rebuys: int = 0
var peak_bankroll_cents: int = _Money.STARTING_BANKROLL
var first_played: int = 0
## Bankroll after each round of the current session (for the statistics chart).
var trail: Array = []
## Most recent round records, newest last.
var history: Array = []


func _ready() -> void:
	load_stats()


func stats_path() -> String:
	return _Paths.data_dir().path_join("stats.json")


func history_path() -> String:
	return _Paths.data_dir().path_join("history.json")


func to_dict() -> Dictionary:
	return {
		"version": STATS_VERSION,
		"bankroll_cents": bankroll_cents,
		"last_bet_cents": last_bet_cents,
		"previous_bet_cents": previous_bet_cents,
		"last_bets": last_bets.duplicate(),
		"lifetime_profit_cents": lifetime_profit_cents,
		"session_profit_cents": session_profit_cents,
		"session_hands": session_hands,
		"hands": hands,
		"rounds": rounds,
		"wins": wins,
		"losses": losses,
		"pushes": pushes,
		"blackjacks": blackjacks,
		"largest_win_cents": largest_win_cents,
		"total_wagered_cents": total_wagered_cents,
		"doubles": doubles,
		"doubles_won": doubles_won,
		"splits": splits,
		"surrenders": surrenders,
		"insurance_taken": insurance_taken,
		"insurance_won": insurance_won,
		"even_money_taken": even_money_taken,
		"side_bets_placed": side_bets_placed,
		"side_bets_won": side_bets_won,
		"side_net_cents": side_net_cents,
		"decisions": decisions,
		"correct_decisions": correct_decisions,
		"strategy_run": strategy_run,
		"best_strategy_run": best_strategy_run,
		"current_streak": current_streak,
		"best_streak": best_streak,
		"rebuys": rebuys,
		"peak_bankroll_cents": peak_bankroll_cents,
		"first_played": first_played,
		"trail": trail.duplicate(),
	}


func reset_all() -> void:
	bankroll_cents = _Money.STARTING_BANKROLL
	last_bet_cents = 0
	previous_bet_cents = 0
	last_bets = {"main": 0, "pp": 0, "t3": 0}
	lifetime_profit_cents = 0
	session_profit_cents = 0
	session_hands = 0
	hands = 0
	rounds = 0
	wins = 0
	losses = 0
	pushes = 0
	blackjacks = 0
	largest_win_cents = 0
	total_wagered_cents = 0
	doubles = 0
	doubles_won = 0
	splits = 0
	surrenders = 0
	insurance_taken = 0
	insurance_won = 0
	even_money_taken = 0
	side_bets_placed = 0
	side_bets_won = 0
	side_net_cents = 0
	decisions = 0
	correct_decisions = 0
	strategy_run = 0
	best_strategy_run = 0
	current_streak = 0
	best_streak = 0
	rebuys = 0
	peak_bankroll_cents = _Money.STARTING_BANKROLL
	first_played = 0
	trail = [bankroll_cents]
	history.clear()
	save_stats()
	save_history()


## Fresh fictional bankroll; lifetime totals are kept.
func reset_session_keep_lifetime() -> void:
	bankroll_cents = _Money.STARTING_BANKROLL
	session_profit_cents = 0
	session_hands = 0
	current_streak = 0
	trail = [bankroll_cents]
	save_stats()


func note_rebuy(amount: int) -> void:
	rebuys += 1
	bankroll_cents = amount
	trail.append(bankroll_cents)
	_trim_trail()
	save_stats()


func from_dict(d: Dictionary) -> bool:
	if d.is_empty():
		return false
	bankroll_cents = _safe_int(d.get("bankroll_cents", _Money.STARTING_BANKROLL), 0, BIG)
	last_bet_cents = _safe_int(d.get("last_bet_cents", 0), 0, _Money.TABLE_MAX)
	previous_bet_cents = _safe_int(d.get("previous_bet_cents", 0), 0, _Money.TABLE_MAX)
	var lb: Variant = d.get("last_bets", null)
	last_bets = {"main": last_bet_cents, "pp": 0, "t3": 0}
	if lb is Dictionary:
		last_bets["main"] = _safe_int(lb.get("main", last_bet_cents), 0, _Money.TABLE_MAX)
		last_bets["pp"] = _safe_int(lb.get("pp", 0), 0, _Money.SIDE_MAX)
		last_bets["t3"] = _safe_int(lb.get("t3", 0), 0, _Money.SIDE_MAX)
	lifetime_profit_cents = _safe_int(d.get("lifetime_profit_cents", 0), -BIG, BIG)
	session_profit_cents = _safe_int(d.get("session_profit_cents", 0), -BIG, BIG)
	session_hands = _safe_int(d.get("session_hands", 0), 0, BIG)
	hands = _safe_int(d.get("hands", 0), 0, BIG)
	wins = _safe_int(d.get("wins", 0), 0, BIG)
	losses = _safe_int(d.get("losses", 0), 0, BIG)
	pushes = _safe_int(d.get("pushes", 0), 0, BIG)
	rounds = _safe_int(d.get("rounds", hands), 0, BIG)
	blackjacks = _safe_int(d.get("blackjacks", 0), 0, BIG)
	largest_win_cents = _safe_int(d.get("largest_win_cents", 0), 0, BIG)
	total_wagered_cents = _safe_int(d.get("total_wagered_cents", 0), 0, BIG)
	doubles = _safe_int(d.get("doubles", 0), 0, BIG)
	doubles_won = _safe_int(d.get("doubles_won", 0), 0, BIG)
	splits = _safe_int(d.get("splits", 0), 0, BIG)
	surrenders = _safe_int(d.get("surrenders", 0), 0, BIG)
	insurance_taken = _safe_int(d.get("insurance_taken", 0), 0, BIG)
	insurance_won = _safe_int(d.get("insurance_won", 0), 0, BIG)
	even_money_taken = _safe_int(d.get("even_money_taken", 0), 0, BIG)
	side_bets_placed = _safe_int(d.get("side_bets_placed", 0), 0, BIG)
	side_bets_won = _safe_int(d.get("side_bets_won", 0), 0, BIG)
	side_net_cents = _safe_int(d.get("side_net_cents", 0), -BIG, BIG)
	decisions = _safe_int(d.get("decisions", 0), 0, BIG)
	correct_decisions = _safe_int(d.get("correct_decisions", 0), 0, decisions)
	strategy_run = _safe_int(d.get("strategy_run", 0), 0, BIG)
	best_strategy_run = _safe_int(d.get("best_strategy_run", 0), 0, BIG)
	current_streak = _safe_int(d.get("current_streak", 0), 0, BIG)
	best_streak = _safe_int(d.get("best_streak", 0), 0, BIG)
	rebuys = _safe_int(d.get("rebuys", 0), 0, BIG)
	peak_bankroll_cents = maxi(_safe_int(d.get("peak_bankroll_cents", bankroll_cents), 0, BIG), bankroll_cents)
	first_played = _safe_int(d.get("first_played", 0), 0, BIG)
	if wins + losses + pushes > hands:
		hands = wins + losses + pushes
	trail.clear()
	var t: Variant = d.get("trail", [])
	if t is Array:
		for v in t:
			if v is float or v is int:
				trail.append(clampi(int(v), 0, BIG))
	if trail.is_empty():
		trail.append(bankroll_cents)
	_trim_trail()
	return true


## Folds one settled round (BlackjackEngine.round_record) into the lifetime totals.
func record_round(rec: Dictionary) -> void:
	if first_played == 0:
		first_played = int(rec.get("time", Time.get_unix_time_from_system()))
	var net := int(rec.get("net", 0))
	bankroll_cents = int(rec.get("bankroll", bankroll_cents))
	rounds += 1
	lifetime_profit_cents += net
	session_profit_cents += net
	total_wagered_cents += int(rec.get("wagered", 0))
	largest_win_cents = maxi(largest_win_cents, net)
	peak_bankroll_cents = maxi(peak_bankroll_cents, bankroll_cents)
	for h in rec.get("hands", []):
		hands += 1
		session_hands += 1
		var outcome := str(h.get("outcome", ""))
		var acts := str(h.get("actions", ""))
		if bool(h.get("doubled", false)):
			doubles += 1
		if acts.contains("P"):
			splits += acts.count("P")
		match outcome:
			"win", "blackjack", "even_money":
				wins += 1
				current_streak += 1
				best_streak = maxi(best_streak, current_streak)
				if outcome != "win":
					blackjacks += 1
				if bool(h.get("doubled", false)):
					doubles_won += 1
			"lose", "bust":
				losses += 1
				current_streak = 0
			"surrender":
				losses += 1
				surrenders += 1
				current_streak = 0
			"push":
				pushes += 1
	if int(rec.get("insurance", 0)) > 0:
		insurance_taken += 1
		if int(rec.get("insurance_payout", 0)) > 0:
			insurance_won += 1
	if bool(rec.get("even_money", false)):
		even_money_taken += 1
	for s in rec.get("side", []):
		side_bets_placed += 1
		side_net_cents += int(s.get("net", 0))
		if int(s.get("payout", 0)) > 0:
			side_bets_won += 1
	var d := int(rec.get("decisions", 0))
	var c := int(rec.get("correct", 0))
	decisions += d
	correct_decisions += c
	if d > 0:
		if c == d:
			strategy_run += d
		else:
			strategy_run = 0
		best_strategy_run = maxi(best_strategy_run, strategy_run)
	var stored := rec.duplicate(true)
	stored["id"] = rounds
	history.append(stored)
	while history.size() > HISTORY_LIMIT:
		history.pop_front()
	trail.append(bankroll_cents)
	_trim_trail()
	save_stats()
	save_history()


func hydrate_engine(engine) -> void:
	engine.bankroll_cents = bankroll_cents
	engine.last_bet_cents = last_bet_cents
	engine.previous_bet_cents = previous_bet_cents
	engine.last_bets = last_bets.duplicate()


## Called after every round and on quit so the next launch resumes the table state.
func apply_engine(engine) -> void:
	bankroll_cents = engine.bankroll_cents
	last_bet_cents = engine.last_bet_cents
	previous_bet_cents = engine.previous_bet_cents
	last_bets = engine.last_bets.duplicate()
	save_stats()


func win_percent() -> float:
	if hands <= 0:
		return 0.0
	return 100.0 * float(wins) / float(hands)


func strategy_accuracy() -> float:
	if decisions <= 0:
		return 0.0
	return 100.0 * float(correct_decisions) / float(decisions)


func save_stats() -> void:
	if not _Paths.write_json(stats_path(), to_dict()):
		_Log.warn("Could not write stats")
	stats_changed.emit()


func save_history() -> void:
	if not _Paths.write_json(history_path(), {"version": 1, "rounds": history}):
		_Log.warn("Could not write history")


func load_stats() -> void:
	var parsed: Variant = _Paths.read_json(stats_path())
	if parsed != null:
		if parsed is Dictionary and not parsed.has("__corrupt") and from_dict(parsed):
			if int(parsed.get("version", 1)) < STATS_VERSION:
				_Log.info("Migrated stats.json to v%d" % STATS_VERSION)
				save_stats()
		else:
			_Log.warn("Corrupt stats.json (kept as stats.json.corrupt) — restoring defaults")
			reset_all()
	else:
		trail = [bankroll_cents]
	var hist: Variant = _Paths.read_json(history_path())
	history.clear()
	if hist is Dictionary and hist.get("rounds", null) is Array:
		for r in hist["rounds"]:
			if r is Dictionary:
				history.append(r)
		while history.size() > HISTORY_LIMIT:
			history.pop_front()


func _trim_trail() -> void:
	while trail.size() > TRAIL_LIMIT:
		trail.pop_front()


func _safe_int(value: Variant, lo: int, hi: int) -> int:
	var n := 0
	if value is float:
		n = int(round(value))
	elif value is int:
		n = value
	elif value is String and str(value).is_valid_int():
		n = int(value)
	else:
		return 0 if lo <= 0 else lo
	return clampi(n, lo, hi)
