class_name ResultVFX
extends Node3D
## Short GPU particle flourishes for wins and blackjacks. Losses stay quiet.

const PRESETS := {
	"blackjack": {"color": Color(1.0, 0.82, 0.38), "amount": 70, "speed": 0.9, "size": 0.010},
	"win": {"color": Color(0.98, 0.86, 0.52), "amount": 34, "speed": 0.6, "size": 0.008},
	"side": {"color": Color(0.70, 0.95, 0.80), "amount": 26, "speed": 0.5, "size": 0.007},
}


func burst(world_pos: Vector3, kind: String) -> void:
	if not PRESETS.has(kind) or SettingsStore.quality == "low":
		return
	var p: Dictionary = PRESETS[kind]
	var col: Color = p["color"]
	var particles := GPUParticles3D.new()
	particles.amount = int(p["amount"])
	particles.lifetime = 1.3
	particles.one_shot = true
	particles.explosiveness = 0.85
	particles.randomness = 0.4
	particles.position = world_pos + Vector3(0, 0.02, 0)
	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0, 1, 0)
	mat.spread = 55.0
	mat.initial_velocity_min = float(p["speed"]) * 0.5
	mat.initial_velocity_max = float(p["speed"])
	mat.gravity = Vector3(0, -1.2, 0)
	mat.damping_min = 0.8
	mat.damping_max = 1.6
	mat.scale_min = 0.5
	mat.scale_max = 1.2
	mat.angle_min = 0.0
	mat.angle_max = 360.0
	var fade := Gradient.new()
	fade.set_color(0, Color(col * 1.6, 1.0))
	fade.set_color(1, Color(col, 0.0))
	var ramp := GradientTexture1D.new()
	ramp.gradient = fade
	mat.color_ramp = ramp
	particles.process_material = mat
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * float(p["size"])
	var sm := StandardMaterial3D.new()
	sm.albedo_texture = _spark_texture()
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	sm.vertex_color_use_as_albedo = true
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm.albedo_color = Color(1, 1, 1, 1)
	sm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	quad.material = sm
	particles.draw_pass_1 = quad
	add_child(particles)
	particles.emitting = true
	get_tree().create_timer(1.8).timeout.connect(particles.queue_free)


static var _spark: Texture2D


static func _spark_texture() -> Texture2D:
	if _spark == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.add_point(0.35, Color(1, 1, 1, 0.55))
		g.set_color(g.get_point_count() - 1, Color(1, 1, 1, 0))
		var t := GradientTexture2D.new()
		t.gradient = g
		t.fill = GradientTexture2D.FILL_RADIAL
		t.fill_from = Vector2(0.5, 0.5)
		t.fill_to = Vector2(1.0, 0.5)
		t.width = 64
		t.height = 64
		_spark = t
	return _spark


## Brief warm swell of the pendant lamp.
func lamp_flash(light: Light3D, glow: StandardMaterial3D, strength: float = 1.0) -> void:
	if light == null or not SettingsStore.motion_enabled():
		return
	var base := light.light_energy
	var tw := create_tween()
	tw.tween_property(light, "light_energy", base * (1.0 + 0.35 * strength), 0.18)
	tw.tween_property(light, "light_energy", base, 0.8).set_trans(Tween.TRANS_SINE)
	if glow:
		var g := glow.emission_energy_multiplier
		var tw2 := create_tween()
		tw2.tween_property(glow, "emission_energy_multiplier", g * (1.0 + 0.8 * strength), 0.18)
		tw2.tween_property(glow, "emission_energy_multiplier", g, 0.8)
