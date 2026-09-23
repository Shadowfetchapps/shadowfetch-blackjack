class_name CardView
extends Node3D
## One physical card on the table. The node carries position and yaw; the inner
## body carries the face-up / face-down flip so the two animate independently.

const TableLayout = preload("res://scripts/table/table_layout.gd")
const MeshKit = preload("res://scripts/table/mesh_kit.gd")

var card
var face_up: bool = false
var uid: int = -1
var _body: Node3D
var _mesh: MeshInstance3D
var _move_tween: Tween
var _flip_tween: Tween


func setup(p_card, textures, start_face_up: bool) -> void:
	card = p_card
	uid = p_card.uid()
	face_up = start_face_up
	_body = Node3D.new()
	add_child(_body)
	_mesh = MeshInstance3D.new()
	_mesh.mesh = MeshKit.card_mesh(TableLayout.CARD_W, TableLayout.CARD_H, TableLayout.CARD_T, TableLayout.CARD_CORNER)
	_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	_body.add_child(_mesh)
	refresh_materials(textures)
	_body.rotation.z = 0.0 if face_up else PI


func refresh_materials(textures) -> void:
	_mesh.set_surface_override_material(0, textures.face_material(card))
	_mesh.set_surface_override_material(1, textures.back_material())
	_mesh.set_surface_override_material(2, textures.edge_material())


## Slides to `dest` along a shallow arc while turning to `yaw`.
func move_to(dest: Vector3, yaw: float, duration: float, lift: float = 0.03) -> void:
	if _move_tween and _move_tween.is_valid():
		_move_tween.kill()
	var start := position
	var start_yaw := rotation.y
	var dur := maxf(duration, 0.01)
	_move_tween = create_tween()
	_move_tween.tween_method(func(t: float) -> void:
		var e := 1.0 - pow(1.0 - t, 3.0)
		position = start.lerp(dest, e) + Vector3.UP * sin(t * PI) * lift
		rotation.y = lerp_angle(start_yaw, yaw, e)
	, 0.0, 1.0, dur)


func set_face_up(up: bool, duration: float) -> void:
	if face_up == up:
		return
	face_up = up
	if _flip_tween and _flip_tween.is_valid():
		_flip_tween.kill()
	var target := 0.0 if up else PI
	var start := _body.rotation.z
	var dur := maxf(duration, 0.05)
	_flip_tween = create_tween()
	_flip_tween.tween_method(func(t: float) -> void:
		var e := t * t * (3.0 - 2.0 * t)
		_body.rotation.z = lerpf(start, target, e)
		_body.position.y = sin(t * PI) * TableLayout.CARD_W * 0.55
	, 0.0, 1.0, dur)


func snap_face(up: bool) -> void:
	face_up = up
	_body.rotation.z = 0.0 if up else PI
	_body.position.y = 0.0


## The dealer lifts the near corner of the hole card to check for blackjack.
func peek(duration: float) -> void:
	var tw := create_tween()
	tw.tween_property(_body, "rotation:x", deg_to_rad(-14.0), duration * 0.4).set_trans(Tween.TRANS_SINE)
	tw.tween_interval(duration * 0.2)
	tw.tween_property(_body, "rotation:x", 0.0, duration * 0.4).set_trans(Tween.TRANS_SINE)
