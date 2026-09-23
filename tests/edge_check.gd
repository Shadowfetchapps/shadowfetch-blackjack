extends SceneTree
## Optional long-run check that perfect basic strategy (the HINT / coach advice)
## lands near the published house edge for the default rules.
##   godot --headless --path . --script res://tests/edge_check.gd
## SF_BJ_EDGE_HANDS sets the number of rounds (default 1,000,000).

const BlackjackEngine = preload("res://scripts/engine/blackjack_engine.gd")
const BJRules = preload("res://scripts/engine/bj_rules.gd")


func _initialize() -> void:
	var n := int(OS.get_environment("SF_BJ_EDGE_HANDS")) if not OS.get_environment("SF_BJ_EDGE_HANDS").is_empty() else 1_000_000
	var rules := BJRules.new()
	var e := BlackjackEngine.new(424242, rules)
	var wagered := 0
	var net := 0
	var sum_sq := 0.0
	var started := Time.get_ticks_msec()
	for i in n:
		e.bankroll_cents = 100_000_000
		e.set_bet(10000)
		e.deal()
		if e.phase == BlackjackEngine.Phase.INSURANCE:
			e.take_insurance(false)
		while e.phase == BlackjackEngine.Phase.PLAYER:
			match e.hint():
				"hit":
					e.hit()
				"double":
					e.double_down()
				"split":
					e.split()
				"surrender":
					e.surrender()
				_:
					e.stand()
		var round_net := e.last_net_cents
		net += round_net
		wagered += 10000
		sum_sq += pow(float(round_net) / 10000.0, 2.0)
		e.finish_round()
	var mean := float(net) / float(wagered)
	var sd := sqrt(sum_sq / float(n) - mean * mean)
	var se := sd / sqrt(float(n))
	print("Basic strategy, %s: %d rounds in %.1fs" % [rules.summary(), n, (Time.get_ticks_msec() - started) / 1000.0])
	print("  player return per initial bet: %+.3f%% ± %.3f%% (1 s.e.)" % [mean * 100.0, se * 100.0])
	print("  published estimate for these rules: -%.2f%%" % rules.house_edge_percent())
	quit()
