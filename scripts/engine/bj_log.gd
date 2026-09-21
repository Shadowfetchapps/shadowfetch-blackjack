class_name BJLog
extends RefCounted


static func verbose() -> bool:
	return OS.is_debug_build() or OS.has_feature("editor")


static func info(msg: String) -> void:
	if verbose():
		print("[blackjack] ", msg)


static func event(msg: String) -> void:
	print("[blackjack] ", msg)


static func warn(msg: String) -> void:
	push_warning("[blackjack] " + msg)


static func error(msg: String) -> void:
	push_error("[blackjack] " + msg)
