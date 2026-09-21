class_name ResultVFX
extends Node3D


func play(kind: String) -> void:
	var color := Color(0.85, 0.72, 0.32)
	var count := 18
	match kind:
		"blackjack":
			color = Color(1.0, 0.84, 0.32)
			count = 36
		"win":
			color = Color(0.55, 0.92, 0.58)
			count = 22
		"bust", "lose":
			color = Color(0.85, 0.28, 0.24)
			count = 14
		"push":
			color = Color(0.75, 0.75, 0.80)
			count = 12
	var particles := GPUParticles3D.new()
	particles.amount = count
	particles.lifetime = 0.9
	particles.one_shot = true
	particles.explosiveness = 0.92
	particles.position = Vector3(0, 0.95, 0.05)
	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0, 1, 0)
	mat.spread = 48.0
	mat.initial_velocity_min = 0.4
	mat.initial_velocity_max = 1.3
	mat.gravity = Vector3(0, -1.6, 0)
	mat.scale_min = 0.015
	mat.scale_max = 0.04
	mat.color = color
	particles.process_material = mat
	var mesh := SphereMesh.new()
	mesh.radius = 0.012
	mesh.height = 0.024
	var sm := StandardMaterial3D.new()
	sm.albedo_color = color
	sm.emission_enabled = true
	sm.emission = color
	sm.emission_energy_multiplier = 2.2
	mesh.material = sm
	particles.draw_pass_1 = mesh
	add_child(particles)
	particles.emitting = true
	var t := get_tree().create_timer(1.2)
	t.timeout.connect(particles.queue_free)
