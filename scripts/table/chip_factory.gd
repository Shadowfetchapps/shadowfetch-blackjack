class_name ChipFactory
extends RefCounted
## Clay chips built from the procedural chip mesh and the generated face / edge art.

const MeshKit = preload("res://scripts/table/mesh_kit.gd")
const TableLayout = preload("res://scripts/table/table_layout.gd")

const FALLBACK_COLORS := {
	100: Color(0.92, 0.91, 0.87),
	500: Color(0.70, 0.13, 0.16),
	2500: Color(0.12, 0.48, 0.24),
	10000: Color(0.09, 0.09, 0.10),
	50000: Color(0.36, 0.16, 0.52),
	100000: Color(0.82, 0.46, 0.11),
}

static var _face_mats: Dictionary = {}
static var _edge_mats: Dictionary = {}
static var _icons: Dictionary = {}


static func make(cents: int) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = MeshKit.chip_mesh(TableLayout.CHIP_RADIUS, TableLayout.CHIP_HEIGHT)
	mi.set_surface_override_material(0, face_material(cents))
	mi.set_surface_override_material(1, edge_material(cents))
	return mi


static func face_material(cents: int) -> Material:
	if not _face_mats.has(cents):
		var m := StandardMaterial3D.new()
		var tex := _load("res://assets/chips/face_%d.png" % cents)
		if tex:
			m.albedo_texture = tex
			m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		else:
			m.albedo_color = FALLBACK_COLORS.get(cents, Color.WHITE)
		m.roughness = 0.42
		m.metallic_specular = 0.4
		m.clearcoat_enabled = true
		m.clearcoat = 0.18
		_face_mats[cents] = m
	return _face_mats[cents]


static func edge_material(cents: int) -> Material:
	if not _edge_mats.has(cents):
		var m := StandardMaterial3D.new()
		var tex := _load("res://assets/chips/edge_%d.png" % cents)
		if tex:
			m.albedo_texture = tex
		else:
			m.albedo_color = FALLBACK_COLORS.get(cents, Color.WHITE).darkened(0.1)
		m.roughness = 0.5
		_edge_mats[cents] = m
	return _edge_mats[cents]


## HUD chip icon (falls back to the face texture).
static func icon(cents: int) -> Texture2D:
	if not _icons.has(cents):
		var tex := _load("res://assets/ui/chip_%d.png" % cents)
		if tex == null:
			tex = _load("res://assets/chips/face_%d.png" % cents)
		_icons[cents] = tex
	return _icons[cents]


static func _load(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		var res = load(path)
		if res is Texture2D:
			return res
	return null
