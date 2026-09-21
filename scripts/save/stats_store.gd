extends Node

const _Log = preload("res://scripts/engine/bj_log.gd")
const _Money = preload("res://scripts/engine/bj_money.gd")
const STATS_VERSION := 1

var bankroll_cents: int = _Money.STARTING_BANKROLL
var last_bet_cents: int = 0
var previous_bet_cents: int = 0
var lifetime_profit_cents: int = 0
var hands: int = 0
var wins: int = 0
var losses: int = 0
var pushes: int = 0
var blackjacks: int = 0
var largest_win_cents: int = 0
var session_profit_cents: int = 0
var session_hands: int = 0

signal stats_changed


func _ready() -> void:
	load_stats()


func stats_path() -> String:
	return _data_dir().path_join("stats.json")


func _data_dir() -> String:
	var box := OS.get_environment("SHADOWFETCH_BJ_HOME")
	if not box.is_empty():
		return box.path_join("data")
	var xdg := OS.get_environment("XDG_DATA_HOME")
	if xdg.is_empty():
		xdg = OS.get_environment("HOME").path_join(".local/share")
	return xdg.path_join("shadowfetch-blackjack")


func to_dict() -> Dictionary:
	return {
		"version": STATS_VERSION,
		"bankroll_cents": bankroll_cents,
		"last_bet_cents": last_bet_cents,
		"previous_bet_cents": previous_bet_cents,
		"lifetime_profit_cents": lifetime_profit_cents,
		"hands": hands,
		"wins": wins,
		"losses": losses,
		"pushes": pushes,
		"blackjacks": blackjacks,
		"largest_win_cents": largest_win_cents,
		"session_profit_cents": session_profit_cents,
		"session_hands": session_hands,
	}


func reset_all() -> void:
	bankroll_cents = _Money.STARTING_BANKROLL
	last_bet_cents = 0
	previous_bet_cents = 0
	lifetime_profit_cents = 0
	hands = 0
	wins = 0
	losses = 0
	pushes = 0
	blackjacks = 0
	largest_win_cents = 0
	session_profit_cents = 0
	session_hands = 0
	save_stats()


func reset_session_keep_lifetime() -> void:
	bankroll_cents = _Money.STARTING_BANKROLL
	session_profit_cents = 0
	session_hands = 0
	save_stats()


func from_dict(d: Dictionary) -> bool:
	if d.is_empty():
		return false
	bankroll_cents = _safe_int(d.get("bankroll_cents", _Money.STARTING_BANKROLL), 0, 1_000_000_000)
	last_bet_cents = _safe_int(d.get("last_bet_cents", 0), 0, 1_000_000_000)
	previous_bet_cents = _safe_int(d.get("previous_bet_cents", 0), 0, 1_000_000_000)
	lifetime_profit_cents = _safe_int(d.get("lifetime_profit_cents", 0), -1_000_000_000, 1_000_000_000)
	hands = _safe_int(d.get("hands", 0), 0, 1_000_000_000)
	wins = _safe_int(d.get("wins", 0), 0, 1_000_000_000)
	losses = _safe_int(d.get("losses", 0), 0, 1_000_000_000)
	pushes = _safe_int(d.get("pushes", 0), 0, 1_000_000_000)
	blackjacks = _safe_int(d.get("blackjacks", 0), 0, 1_000_000_000)
	largest_win_cents = _safe_int(d.get("largest_win_cents", 0), 0, 1_000_000_000)
	session_profit_cents = _safe_int(d.get("session_profit_cents", 0), -1_000_000_000, 1_000_000_000)
	session_hands = _safe_int(d.get("session_hands", 0), 0, 1_000_000_000)
	if wins + losses + pushes > hands and hands > 0:
		hands = wins + losses + pushes
	return true


func apply_engine(engine) -> void:
	bankroll_cents = engine.bankroll_cents
	last_bet_cents = engine.last_bet_cents
	previous_bet_cents = engine.previous_bet_cents
	lifetime_profit_cents += engine.last_net_cents
	hands += engine.last_results.size()
	session_hands += engine.last_results.size()
	session_profit_cents += engine.last_net_cents
	for r in engine.last_results:
		match str(r.get("outcome", "")):
			"win", "blackjack":
				wins += 1
				if str(r.get("outcome", "")) == "blackjack":
					blackjacks += 1
			"lose", "bust":
				losses += 1
			"push":
				pushes += 1
		var net: int = int(r.get("net_cents", 0))
		if net > largest_win_cents:
			largest_win_cents = net
	save_stats()


func hydrate_engine(engine) -> void:
	engine.bankroll_cents = bankroll_cents
	engine.last_bet_cents = last_bet_cents
	engine.previous_bet_cents = previous_bet_cents


func win_percent() -> float:
	if hands <= 0:
		return 0.0
	return 100.0 * float(wins) / float(hands)


func save_stats() -> void:
	DirAccess.make_dir_recursive_absolute(_data_dir())
	var f := FileAccess.open(stats_path(), FileAccess.WRITE)
	if f == null:
		_Log.warn("Could not write stats")
		return
	f.store_string(JSON.stringify(to_dict(), "\t"))
	stats_changed.emit()


func load_stats() -> void:
	var path := stats_path()
	if not FileAccess.file_exists(path):
		return
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		_Log.warn("Could not read stats; using defaults")
		return
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if parsed is Dictionary:
		if not from_dict(parsed):
			_Log.warn("Invalid stats.json — restoring defaults")
			reset_all()
	else:
		_Log.warn("Corrupt stats.json — restoring defaults")
		reset_all()


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
