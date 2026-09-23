class_name CardTextures
extends RefCounted
## Loads the card artwork and caches one material per face / back so every card on
## the table shares GPU resources. Supports the classic and four-colour decks.

const BJCard = preload("res://scripts/engine/bj_card.gd")

const DECK_DIRS := {
	"classic": "res://assets/cards/classic/",
	"fourcolor": "res://assets/cards/fourcolor/",
}
const BACK_DIR := "res://assets/cards/backs/"

var deck_style := "classic"
var back_name := "emerald"
var _faces: Dictionary = {}
var _face_mats: Dictionary = {}
var _back_mats: Dictionary = {}
var _edge_mat: StandardMaterial3D


func build(style: String = "classic", back: String = "emerald") -> void:
	deck_style = style if DECK_DIRS.has(style) else "classic"
	back_name = back


func face_texture(card) -> Texture2D:
	var key := "%s/%s" % [deck_style, card.face_key()]
	if _faces.has(key):
		return _faces[key]
	var tex := _load(str(DECK_DIRS[deck_style]) + card.face_key() + ".png")
	if tex == null and deck_style != "classic":
		tex = _load(str(DECK_DIRS["classic"]) + card.face_key() + ".png")
	if tex == null:
		tex = _fallback(Color(0.97, 0.95, 0.9))
	_faces[key] = tex
	return tex


func back_texture(name: String = "") -> Texture2D:
	var n := back_name if name.is_empty() else name
	var tex := _load(BACK_DIR + n + ".png")
	if tex == null:
		tex = _fallback(Color(0.05, 0.25, 0.16))
	return tex


func face_material(card) -> Material:
	var key := "%s/%s" % [deck_style, card.face_key()]
	if not _face_mats.has(key):
		_face_mats[key] = _paper(face_texture(card), 0.0)
	return _face_mats[key]


func back_material() -> Material:
	if not _back_mats.has(back_name):
		_back_mats[back_name] = _paper(back_texture(), 0.03)
	return _back_mats[back_name]


func edge_material() -> Material:
	if _edge_mat == null:
		_edge_mat = StandardMaterial3D.new()
		_edge_mat.albedo_color = Color(0.93, 0.91, 0.85)
		_edge_mat.roughness = 0.6
		_edge_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return _edge_mat


func _paper(tex: Texture2D, glow: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = tex
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	m.roughness = 0.55
	m.metallic_specular = 0.3
	m.clearcoat_enabled = true
	m.clearcoat = 0.12
	m.clearcoat_roughness = 0.45
	# Optional self-illumination keeps a design legible outside the lamp's hot spot.
	if glow > 0.0:
		m.emission_enabled = true
		m.emission_texture = tex
		m.emission = Color.WHITE
		m.emission_energy_multiplier = glow
	return m


func _load(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		var res = load(path)
		if res is Texture2D:
			return res
	return null


func _fallback(color: Color) -> Texture2D:
	var img := Image.create(64, 90, false, Image.FORMAT_RGBA8)
	img.fill(color)
	return ImageTexture.create_from_image(img)
