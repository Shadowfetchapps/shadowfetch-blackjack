class_name CardView
extends Node3D

const BJCard = preload("res://scripts/engine/bj_card.gd")
const CardTextures = preload("res://scripts/table/card_textures.gd")

const WIDTH := 0.132
const HEIGHT := 0.188
const THICK := 0.0045

var card: BJCard
var face_up: bool = false
var _body: Node3D
var _face_mi: MeshInstance3D
var _back_mi: MeshInstance3D
var _tilt := 0.0
var _yaw := 0.0


func setup(p_card, textures, start_face_up: bool) -> void:
	card = p_card
	face_up = start_face_up
	_body = Node3D.new()
	add_child(_body)
	var edge := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(WIDTH, THICK, HEIGHT)
	edge.mesh = box
	var edge_mat := StandardMaterial3D.new()
	edge_mat.albedo_color = Color(0.93, 0.90, 0.82)
	edge_mat.roughness = 0.58
	edge.material_override = edge_mat
	edge.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_body.add_child(edge)
	var face_tex: Texture2D = textures.face_for(card)
	if face_tex == null:
		face_tex = textures.back
	_face_mi = _quad(Vector3(0, THICK * 0.55, 0), face_tex, false)
	_back_mi = _quad(Vector3(0, -THICK * 0.55, 0), textures.back, true)
	_body.add_child(_face_mi)
	_body.add_child(_back_mi)
	_body.rotation.z = 0.0 if face_up else PI


func apply_display(tilt_deg: float, yaw_deg: float = 0.0) -> void:
	_tilt = deg_to_rad(tilt_deg)
	_yaw = deg_to_rad(yaw_deg)
	rotation.x = _tilt
	rotation.y = _yaw


func _quad(pos: Vector3, tex: Texture2D, is_back: bool) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(WIDTH * 0.97, HEIGHT * 0.97)
	mi.mesh = q
	mi.position = pos
	mi.rotation.x = -PI / 2.0
	if is_back:
		mi.rotation.y = PI
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color.WHITE
	mat.albedo_texture = tex
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	mat.disable_receive_shadows = true
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


func set_face_up(up: bool, duration: float) -> void:
	if face_up == up and is_equal_approx(_body.rotation.z, 0.0 if up else PI):
		return
	face_up = up
	var target := 0.0 if up else PI
	var tw := create_tween()
	tw.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(_body, "rotation:z", target, maxf(duration, 0.05))


func snap_face_up(up: bool) -> void:
	face_up = up
	if _body:
		_body.rotation.z = 0.0 if up else PI
