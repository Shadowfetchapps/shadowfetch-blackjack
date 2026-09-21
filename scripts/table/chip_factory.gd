class_name ChipFactory
extends RefCounted

const COLORS := {
	100: Color(0.92, 0.92, 0.90),
	500: Color(0.72, 0.14, 0.16),
	2500: Color(0.12, 0.42, 0.24),
	10000: Color(0.08, 0.08, 0.09),
	50000: Color(0.38, 0.16, 0.52),
	100000: Color(0.82, 0.48, 0.12),
}

const EDGE := {
	100: Color(0.12, 0.12, 0.14),
	500: Color(0.95, 0.92, 0.86),
	2500: Color(0.94, 0.90, 0.78),
	10000: Color(0.82, 0.66, 0.28),
	50000: Color(0.90, 0.78, 0.40),
	100000: Color(0.12, 0.08, 0.06),
}


static func make(cents: int, clickable: bool = false) -> Node3D:
	var root := Node3D.new()
	root.name = "Chip_%d" % cents
	var body := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.024
	cyl.bottom_radius = 0.024
	cyl.height = 0.0046
	cyl.radial_segments = 28
	body.mesh = cyl
	var mat := StandardMaterial3D.new()
	mat.albedo_color = COLORS.get(cents, Color.WHITE)
	mat.roughness = 0.32
	mat.metallic = 0.18
	mat.clearcoat_enabled = true
	mat.clearcoat = 0.35
	body.material_override = mat
	root.add_child(body)
	var rim := MeshInstance3D.new()
	var ring := TorusMesh.new()
	ring.inner_radius = 0.019
	ring.outer_radius = 0.0246
	ring.rings = 18
	ring.ring_segments = 10
	rim.mesh = ring
	rim.scale = Vector3(1, 0.18, 1)
	var rm := StandardMaterial3D.new()
	rm.albedo_color = EDGE.get(cents, Color.GOLD)
	rm.metallic = 0.55
	rm.roughness = 0.28
	rim.material_override = rm
	root.add_child(rim)
	var spot := MeshInstance3D.new()
	var dec := CylinderMesh.new()
	dec.top_radius = 0.007
	dec.bottom_radius = 0.007
	dec.height = 0.0006
	spot.mesh = dec
	spot.position.y = 0.0023
	var sm := StandardMaterial3D.new()
	sm.albedo_color = EDGE.get(cents, Color.GOLD)
	sm.roughness = 0.4
	spot.material_override = sm
	root.add_child(spot)
	if clickable:
		var area := Area3D.new()
		area.input_ray_pickable = true
		area.collision_layer = 1
		area.collision_mask = 0
		var col := CollisionShape3D.new()
		var sh := CylinderShape3D.new()
		sh.radius = 0.02
		sh.height = 0.01
		col.shape = sh
		area.add_child(col)
		area.set_meta("chip_cents", cents)
		root.add_child(area)
	return root
