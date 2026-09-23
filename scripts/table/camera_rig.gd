class_name CameraRig
extends Node3D
## Seated, overhead and menu-orbit camera poses with smooth blends, subtle breathing
## sway, mouse parallax, split-hand focus and a push-in for big moments.

const POSES := {
	"seated": {"pos": Vector3(0.0, 1.25, 0.87), "look": Vector3(0.0, 0.70, -0.08), "fov": 46.0},
	"overhead": {"pos": Vector3(0.0, 1.90, 0.60), "look": Vector3(0.0, 0.76, 0.06), "fov": 44.0},
}
const ORBIT_CENTER := Vector3(0.0, 0.80, -0.30)

var camera: Camera3D
var attributes: CameraAttributesPractical
var mode := "seated"
var focus_x := 0.0
var _focus := 0.0
var _from := {}
var _blend := 1.0
var _blend_time := 0.9
var _time := 0.0
var _push := 0.0
var _parallax := Vector2.ZERO


func setup() -> void:
	camera = Camera3D.new()
	camera.near = 0.03
	camera.far = 30.0
	camera.current = true
	attributes = CameraAttributesPractical.new()
	camera.attributes = attributes
	add_child(camera)
	var p: Dictionary = POSES["seated"]
	_apply(p["pos"], p["look"], p["fov"])
	apply_quality()


func apply_quality() -> void:
	var q: String = SettingsStore.quality
	attributes.dof_blur_far_enabled = q in ["high", "ultra"]
	attributes.dof_blur_far_distance = 2.9 if mode == "orbit" else 2.5
	attributes.dof_blur_far_transition = 1.8
	attributes.dof_blur_amount = 0.07


func set_mode(new_mode: String, instant: bool = false) -> void:
	if new_mode == mode and not instant:
		return
	var prev := mode
	_from = _current_pose()
	mode = new_mode
	_blend = 1.0 if instant else 0.0
	_blend_time = 1.4 if new_mode == "orbit" or prev == "orbit" else 0.8
	apply_quality()


## Brief FOV push toward the table (blackjacks, big wins).
func punch(amount: float = 1.0) -> void:
	if not SettingsStore.motion_enabled():
		return
	var tw := create_tween()
	tw.tween_property(self, "_push", 3.2 * amount, 0.35).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "_push", 0.0, 0.9).set_trans(Tween.TRANS_SINE)


func _process(delta: float) -> void:
	_time += delta
	if _blend < 1.0:
		_blend = minf(1.0, _blend + delta / _blend_time)
	var motion := SettingsStore.motion_enabled() and SettingsStore.camera_sway
	var target := _target_pose()
	var pos: Vector3 = target["pos"]
	var look: Vector3 = target["look"]
	var fov: float = target["fov"]
	if mode != "orbit":
		_focus = lerpf(_focus, focus_x, minf(1.0, delta * 3.0))
		look.x += _focus
		pos.x += _focus * 0.35
		if motion:
			var vp := get_viewport()
			var m := Vector2.ZERO
			if vp:
				var size := vp.get_visible_rect().size
				if size.x > 0:
					m = (vp.get_mouse_position() / size - Vector2(0.5, 0.5)) * 2.0
					m = m.clamp(Vector2(-1, -1), Vector2(1, 1))
			_parallax = _parallax.lerp(m, minf(1.0, delta * 2.0))
			pos += Vector3(_parallax.x * 0.018, -_parallax.y * 0.010, 0.0)
			pos += Vector3(sin(_time * 0.37) * 0.004, sin(_time * 0.53) * 0.003, 0.0)
	if _blend < 1.0:
		var e := _blend * _blend * (3.0 - 2.0 * _blend)
		pos = (_from["pos"] as Vector3).lerp(pos, e)
		look = (_from["look"] as Vector3).lerp(look, e)
		fov = lerpf(float(_from["fov"]), fov, e)
	_apply(pos, look, fov - _push)


func _target_pose() -> Dictionary:
	if mode == "orbit":
		var speed := 0.06 if SettingsStore.motion_enabled() else 0.0
		var ang := sin(_time * speed) * 0.6
		var r := 2.05
		var pos := ORBIT_CENTER + Vector3(sin(ang) * r, 0.78, cos(ang) * r)
		return {"pos": pos, "look": ORBIT_CENTER + Vector3(0, -0.05, 0), "fov": 40.0}
	var p: Dictionary = POSES.get(mode, POSES["seated"])
	return {"pos": p["pos"], "look": p["look"], "fov": p["fov"]}


func _current_pose() -> Dictionary:
	var look := camera.global_position - camera.global_transform.basis.z * 1.2
	return {"pos": camera.global_position, "look": look, "fov": camera.fov}


func _apply(pos: Vector3, look: Vector3, fov: float) -> void:
	camera.global_position = pos
	if pos.distance_to(look) > 0.001:
		camera.look_at(look, Vector3.UP)
	camera.fov = fov
