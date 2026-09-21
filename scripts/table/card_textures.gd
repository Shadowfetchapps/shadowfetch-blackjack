class_name CardTextures
extends RefCounted

const BJCard = preload("res://scripts/engine/bj_card.gd")

var faces: Dictionary = {}
var back: Texture2D


func build() -> void:
	back = _load_tex("res://assets/cards/back.png")
	for s in 4:
		for r in range(1, 14):
			var card = BJCard.new(s, r, 0)
			var path := "res://assets/cards/%s%s.png" % [card.rank_name(), card.suit_code()]
			faces[card.rank_name() + card.suit_code()] = _load_tex(path)
	if back == null:
		back = _fallback_texture(Color(0.12, 0.08, 0.05))


func face_for(card) -> Texture2D:
	var key := str(card.rank_name()) + str(card.suit_code())
	if faces.has(key) and faces[key] != null:
		return faces[key]
	return back


func _load_tex(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		var res = load(path)
		if res is Texture2D:
			return res
	return null


func _fallback_texture(color: Color) -> Texture2D:
	var img := Image.create(64, 96, false, Image.FORMAT_RGBA8)
	img.fill(color)
	return ImageTexture.create_from_image(img)
