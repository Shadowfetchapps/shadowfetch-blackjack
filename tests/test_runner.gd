extends SceneTree

const TestBlackjackEngineScript = preload("res://tests/test_engine.gd")


func _initialize() -> void:
	print("Running Shadowfetch Blackjack engine tests...")
	var tests = TestBlackjackEngineScript.new()
	var ok: bool = tests.run_all()
	quit(0 if ok else 1)
