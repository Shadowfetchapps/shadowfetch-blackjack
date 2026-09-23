class_name TestPersistence
extends "res://tests/test_base.gd"
## Settings, statistics, history and achievements: round trips, migration, corruption.

const SettingsScript = preload("res://scripts/save/settings_store.gd")
const StatsScript = preload("res://scripts/save/stats_store.gd")
const AchievementsScript = preload("res://scripts/meta/achievements.gd")
const Paths = preload("res://scripts/save/paths.gd")


func run() -> void:
	_test_settings_round_trip()
	_test_settings_migration_v1()
	_test_settings_migration_v2()
	_test_settings_validation()
	_test_corrupt_settings()
	_test_stats_round_trip()
	_test_stats_migration_v1()
	_test_record_round()
	_test_corrupt_stats()
	_test_achievements()


func _write(path: String, text: String) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text)
	f.close()


func _test_settings_round_trip() -> void:
	section("settings round trip")
	var s = SettingsScript.new()
	s.animation_speed = 1.75
	s.master_volume = 0.4
	s.coach_mode = "coach"
	s.felt_color = "crimson"
	s.four_color = true
	s.rules.decks = 2
	s.rules.dealer_hits_soft_17 = true
	s.save_settings()
	var t = SettingsScript.new()
	t.load_settings()
	ok("reload anim speed", is_equal_approx(t.animation_speed, 1.75))
	ok("reload coach + appearance", t.coach_mode == "coach" and t.felt_color == "crimson" and t.four_color)
	ok("reload rules", t.rules.decks == 2 and t.rules.dealer_hits_soft_17)
	ok("no temp file left", not FileAccess.file_exists(t.settings_path() + ".tmp"))
	s.free()
	t.free()


func _test_settings_migration_v1() -> void:
	section("settings migration v1")
	var s = SettingsScript.new()
	# The exact shape written by Shadowfetch Blackjack 1.x.
	_write(s.settings_path(), """{
	"aa": 4, "ambient_volume": 0.2, "animation_speed": 1.6, "fullscreen": false,
	"fx_volume": 0.6, "master_volume": 0.5, "music_volume": 0.15, "muted": false,
	"quality": "ultra", "resolution": [1920, 1080], "seen_tutorial": true,
	"shadows": true, "version": 1, "vsync": true
}""")
	s.load_settings()
	ok("v1 volumes kept", is_equal_approx(s.master_volume, 0.5) and is_equal_approx(s.music_volume, 0.15))
	ok("v1 quality kept", s.quality == "ultra" and is_equal_approx(s.animation_speed, 1.6))
	ok("v1 tutorial flag kept", s.seen_tutorial)
	ok("v1 gets default rules", s.rules.decks == 6 and not s.rules.dealer_hits_soft_17)
	ok("v1 new keys defaulted", s.coach_mode == "hints" and s.camera_mode == "seated")
	var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(s.settings_path()))
	ok("v1 file rewritten as v3", int(saved.get("version", 0)) == 3 and saved.has("rules"))
	s.free()


func _test_settings_migration_v2() -> void:
	section("settings migration v2")
	var s = SettingsScript.new()
	s.from_dict({"version": 2, "dealer_hits_soft_17": true, "late_surrender": false})
	ok("v2 top-level rules migrate", s.rules.dealer_hits_soft_17 and not s.rules.late_surrender)
	s.free()


func _test_settings_validation() -> void:
	section("settings validation")
	var s = SettingsScript.new()
	s.from_dict({
		"quality": "extreme", "aa": 3, "resolution": [10, 10], "animation_speed": 99,
		"master_volume": "loud", "coach_mode": "yelling", "felt_color": "pink", "ui_scale": 9,
		"rules": {"decks": 3, "max_hands": 3},
	})
	ok("bad quality ignored", s.quality == "high")
	ok("bad aa ignored", s.aa == 4)
	ok("bad resolution ignored", s.resolution == Vector2i(1920, 1080))
	ok("speed clamped", is_equal_approx(s.animation_speed, 2.5))
	ok("non-numeric volume safe", s.master_volume >= 0.0 and s.master_volume <= 1.0)
	ok("bad enums ignored", s.coach_mode == "hints" and s.felt_color == "emerald")
	ok("ui scale clamped", is_equal_approx(s.ui_scale, 1.5))
	ok("nested rules validated", s.rules.decks == 6 and s.rules.max_hands == 3)
	s.free()


func _test_corrupt_settings() -> void:
	section("corrupt settings")
	var s = SettingsScript.new()
	_write(s.settings_path(), "{not json")
	s.animation_speed = 2.0
	s.load_settings()
	ok("corrupt settings restore defaults", is_equal_approx(s.animation_speed, 1.0))
	ok("corrupt file kept aside", FileAccess.file_exists(s.settings_path() + ".corrupt"))
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(s.settings_path()))
	ok("clean settings rewritten", parsed is Dictionary)
	s.free()


func _test_stats_round_trip() -> void:
	section("stats round trip")
	var store = StatsScript.new()
	store.bankroll_cents = 1234500
	store.hands = 12
	store.wins = 5
	store.losses = 4
	store.pushes = 3
	store.blackjacks = 1
	store.largest_win_cents = 15000
	store.last_bets = {"main": 2500, "pp": 500, "t3": 0}
	store.trail = [1000000, 1010000, 1234500]
	store.save_stats()
	var t = StatsScript.new()
	t.load_stats()
	ok("reload bankroll", t.bankroll_cents == 1234500)
	ok("reload hands", t.hands == 12 and t.wins == 5)
	ok("reload last bets", t.last_bets["main"] == 2500 and t.last_bets["pp"] == 500)
	ok("reload trail", t.trail == [1000000, 1010000, 1234500])
	store.free()
	t.free()


func _test_stats_migration_v1() -> void:
	section("stats migration v1")
	var store = StatsScript.new()
	_write(store.stats_path(), """{
	"bankroll_cents": 990000, "blackjacks": 0, "hands": 6, "largest_win_cents": 100000,
	"last_bet_cents": 100000, "lifetime_profit_cents": -10000, "losses": 3,
	"previous_bet_cents": 100000, "pushes": 1, "session_hands": 6,
	"session_profit_cents": -10000, "version": 1, "wins": 2
}""")
	store.load_stats()
	ok("v1 bankroll kept", store.bankroll_cents == 990000)
	ok("v1 record kept", store.hands == 6 and store.wins == 2 and store.losses == 3 and store.pushes == 1)
	ok("v1 last bet becomes main rebet", store.last_bets["main"] == 100000)
	ok("v1 lifetime P/L kept", store.lifetime_profit_cents == -10000)
	ok("v1 new counters zeroed", store.decisions == 0 and store.side_bets_placed == 0)
	ok("v1 trail seeded", store.trail == [990000])
	var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(store.stats_path()))
	ok("v1 stats rewritten as v2", int(saved.get("version", 0)) == 2)
	store.free()


func _test_record_round() -> void:
	section("record round")
	var store = StatsScript.new()
	store.reset_all()
	var e := engine()
	e.add_chip(10000)
	e.add_chip(500, "pp")
	force_deal(e, "8S", "5D", "8H", "6C", ["3S", "2H", "10D"])
	e.split()
	e.double_down()
	e.stand()
	store.record_round(e.round_record)
	ok("hands counted", store.hands == 2 and store.rounds == 1)
	ok("split + double counted", store.splits == 1 and store.doubles == 1)
	ok("side bet counted", store.side_bets_placed == 1 and store.side_bets_won == 1)
	ok("wagered totals", store.total_wagered_cents == 10000 + 500 + 10000 + 10000)
	ok("bankroll follows record", store.bankroll_cents == e.bankroll_cents)
	ok("history appended", store.history.size() == 1 and int(store.history[0]["id"]) == 1)
	ok("trail appended", store.trail.back() == e.bankroll_cents)
	ok("decisions tallied", store.decisions == 3)
	for i in StatsScript.HISTORY_LIMIT + 5:
		store.record_round(e.round_record)
	ok("history capped", store.history.size() == StatsScript.HISTORY_LIMIT)
	var t = StatsScript.new()
	t.load_stats()
	ok("history persisted", t.history.size() == StatsScript.HISTORY_LIMIT)
	ok("counters persisted", t.rounds == store.rounds and t.splits == store.splits)
	store.free()
	t.free()


func _test_corrupt_stats() -> void:
	section("corrupt stats")
	var store = StatsScript.new()
	var ok_dict: bool = store.from_dict({"bankroll_cents": -5, "hands": "nope", "trail": ["x", 5]})
	ok("invalid stats sanitized", ok_dict and store.bankroll_cents >= 0 and store.hands == 0)
	ok("invalid trail entries dropped", store.trail == [5])
	_write(store.stats_path(), "[1, 2")
	store.bankroll_cents = 1
	store.load_stats()
	ok("corrupt stats reset", store.bankroll_cents == BJMoney.STARTING_BANKROLL)
	ok("corrupt stats kept aside", FileAccess.file_exists(store.stats_path() + ".corrupt"))
	_write(store.history_path(), "{\"rounds\": \"bad\"}")
	store.load_stats()
	ok("bad history ignored", store.history.is_empty())
	store.free()


func _test_achievements() -> void:
	section("achievements")
	var ach = AchievementsScript.new()
	ach.reset()
	var stats = StatsScript.new()
	stats.reset_all()
	var e := engine()
	force_deal(e, "AS", "9D", "KS", "5C")
	stats.record_round(e.round_record)
	var fresh: PackedStringArray = ach.evaluate(e.round_record, stats)
	ok("natural unlocked", fresh.has("natural") and fresh.has("first_hand") and fresh.has("first_win"))
	ok("not unlocked twice", not ach.evaluate(e.round_record, stats).has("natural"))
	var e2 := engine()
	e2.add_chip(10000)
	e2.add_chip(500, "pp")
	force_deal(e2, "0:QH", "5D", "1:QH", "6C", ["2S"])
	e2.stand()
	var f2: PackedStringArray = ach.evaluate(e2.round_record, null)
	ok("perfect pair unlocked", f2.has("perfect_pair") and f2.has("side_win"))
	var e3 := engine()
	e3.bankroll_cents = 5_000_000
	for i in 10:
		e3.add_chip(100000)
	force_deal(e3, "10S", "7D", "9H", "10C")
	e3.stand()
	var f3: PackedStringArray = ach.evaluate(e3.round_record, null)
	ok("high roller + table max", f3.has("high_roller") and f3.has("table_max"))
	var seven := {"hands": [{"cards": ["7S", "7H", "7D"], "total": 21, "outcome": "win", "bet": 100}], "bankroll": 100}
	ok("lucky sevens", ach.evaluate(seven, null).has("triple_seven"))
	stats.best_strategy_run = 50
	ok("by the book via stats", ach.evaluate({"hands": []}, stats).has("by_the_book"))
	ok("manual unlock", ach.unlock("fresh_stack") and ach.is_unlocked("fresh_stack"))
	var reload = AchievementsScript.new()
	reload.load_state()
	ok("achievements persisted", reload.is_unlocked("natural") and reload.is_unlocked("fresh_stack"))
	ok("defs have unique ids", _unique_ids())
	ach.free()
	reload.free()
	stats.free()


func _unique_ids() -> bool:
	var seen := {}
	for d in AchievementsScript.DEFS:
		if seen.has(d["id"]):
			return false
		seen[d["id"]] = true
	return true
