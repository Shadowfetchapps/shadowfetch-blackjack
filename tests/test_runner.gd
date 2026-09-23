extends SceneTree
## Headless test entry point: `godot --headless --path . --script res://tests/test_runner.gd`.
## SF_BJ_SIM_HANDS overrides the simulation size (0 skips it).

const SUITES := [
	preload("res://tests/test_engine.gd"),
	preload("res://tests/test_features.gd"),
	preload("res://tests/test_persistence.gd"),
	preload("res://tests/test_simulation.gd"),
]


func _initialize() -> void:
	print("Running Shadowfetch Blackjack tests...")
	var started := Time.get_ticks_msec()
	var passed := 0
	var failed := 0
	var simulated := 0
	var errors: PackedStringArray = PackedStringArray()
	var sim_env := OS.get_environment("SF_BJ_SIM_HANDS")
	for script in SUITES:
		var suite = script.new() if script.can_instantiate() else null
		if suite == null:
			failed += 1
			errors.append("%s failed to compile" % script.resource_path.get_file())
			continue
		if suite.has_method("_simulate"):
			if not sim_env.is_empty():
				suite.hands_target = int(sim_env)
			if suite.hands_target <= 0:
				continue
		print("\n== %s ==" % script.resource_path.get_file())
		suite.run()
		passed += suite.passed
		failed += suite.failed
		simulated += suite.simulated_hands
		errors.append_array(suite.errors)
	print("\n==============================")
	print("Shadowfetch Blackjack  —  %d passed, %d failed, %d simulated hands, %.1fs" % [
		passed, failed, simulated, (Time.get_ticks_msec() - started) / 1000.0
	])
	for e in errors:
		print("  FAIL  ", e)
	print("==============================\n")
	quit(0 if failed == 0 else 1)
