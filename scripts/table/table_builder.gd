class_name TableBuilder
extends RefCounted


static func build(parent: Node3D) -> Dictionary:
	var nodes := {}
	_room(parent)
	_table(parent)
	nodes["shoe"] = _shoe(parent)
	nodes["tray"] = _tray(parent)
	nodes["discard"] = _discard(parent)
	nodes["lamp"] = _lamp(parent)
	nodes["dealer_station"] = _dealer_station(parent)
	_markings(parent)
	return nodes


static func _mat(color: Color, rough: float, metal: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	m.metallic = metal
	return m


static func _box(parent: Node3D, size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.position = pos
	mi.material_override = mat
	parent.add_child(mi)
	return mi


static func _cyl(parent: Node3D, r: float, h: float, pos: Vector3, mat: Material, segs := 32) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = r
	mesh.bottom_radius = r
	mesh.height = h
	mesh.radial_segments = segs
	mi.mesh = mesh
	mi.position = pos
	mi.material_override = mat
	parent.add_child(mi)
	return mi


static func _room(parent: Node3D) -> void:
	var floor_m := _mat(Color(0.07, 0.06, 0.05), 0.85)
	floor_m.albedo_color = Color(0.08, 0.06, 0.045)
	_box(parent, Vector3(8, 0.08, 8), Vector3(0, -0.04, 0.1), floor_m)
	var wall := _mat(Color(0.05, 0.045, 0.04), 0.9)
	_box(parent, Vector3(8, 3.2, 0.12), Vector3(0, 1.5, -2.2), wall)
	_box(parent, Vector3(0.12, 3.2, 6), Vector3(-2.6, 1.5, 0.2), wall)
	_box(parent, Vector3(0.12, 3.2, 6), Vector3(2.6, 1.5, 0.2), wall)
	var drape := _mat(Color(0.12, 0.04, 0.05), 0.78)
	_box(parent, Vector3(3.4, 2.2, 0.04), Vector3(0, 1.7, -2.12), drape)
	var brass := _mat(Color(0.72, 0.52, 0.20), 0.26, 0.78)
	_box(parent, Vector3(3.55, 0.025, 0.025), Vector3(0, 2.82, -2.07), brass)
	_box(parent, Vector3(3.55, 0.025, 0.025), Vector3(0, 0.58, -2.07), brass)
	_wall_text(parent, "SHADOWFETCH", Vector3(-0.92, 1.70, -2.045), 0.075)
	_wall_text(parent, "BLACKJACK  ·  PRIVATE TABLE", Vector3(-0.92, 1.49, -2.04), 0.026)


static func _table(parent: Node3D) -> void:
	var wood := _mat(Color(0.18, 0.09, 0.05), 0.38, 0.12)
	wood.clearcoat_enabled = true
	wood.clearcoat = 0.25
	_box(parent, Vector3(1.72, 0.08, 1.18), Vector3(0, 0.70, -0.08), wood)
	_box(parent, Vector3(1.78, 0.045, 1.24), Vector3(0, 0.66, -0.08), wood)
	var felt := _mat(Color(0.035, 0.22, 0.105), 0.88)
	felt.albedo_color = Color(0.035, 0.22, 0.105)
	_box(parent, Vector3(1.60, 0.012, 1.06), Vector3(0, 0.746, -0.08), felt)
	var rail := _mat(Color(0.12, 0.06, 0.035), 0.45, 0.08)
	_box(parent, Vector3(1.72, 0.05, 0.06), Vector3(0, 0.775, 0.49), rail)
	_box(parent, Vector3(1.72, 0.05, 0.06), Vector3(0, 0.775, -0.65), rail)
	_box(parent, Vector3(0.06, 0.05, 1.18), Vector3(-0.83, 0.775, -0.08), rail)
	_box(parent, Vector3(0.06, 0.05, 1.18), Vector3(0.83, 0.775, -0.08), rail)
	var brass := _mat(Color(0.78, 0.62, 0.28), 0.28, 0.72)
	for x in [-0.78, 0.78]:
		for z in [-0.58, 0.42]:
			_cyl(parent, 0.018, 0.08, Vector3(x, 0.80, z), brass, 16)
	var pedestal := _mat(Color(0.12, 0.06, 0.03), 0.5, 0.05)
	_cyl(parent, 0.22, 0.64, Vector3(0, 0.32, -0.08), pedestal, 20)


static func _markings(parent: Node3D) -> void:
	_gold_text(parent, "BLACKJACK PAYS 3 TO 2", Vector3(0, 0.756, -0.18), 0.042)
	_gold_text(parent, "DEALER STANDS ON ALL 17", Vector3(0, 0.756, -0.28), 0.030)
	_gold_text(parent, "INSURANCE PAYS 2 TO 1", Vector3(0, 0.756, -0.36), 0.026)
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.078
	torus.outer_radius = 0.086
	torus.rings = 28
	torus.ring_segments = 8
	ring.mesh = torus
	ring.position = Vector3(0, 0.754, 0.28)
	ring.scale = Vector3(1, 0.08, 1)
	ring.material_override = _mat(Color(0.82, 0.68, 0.30), 0.35, 0.55)
	parent.add_child(ring)
	_gold_text(parent, "BET", Vector3(0, 0.755, 0.28), 0.016)


static func _gold_text(parent: Node3D, text: String, pos: Vector3, size: float) -> void:
	var mi := MeshInstance3D.new()
	var tm := TextMesh.new()
	tm.text = text
	tm.font_size = 6
	tm.depth = 0.0015
	tm.pixel_size = size / 8.0
	mi.mesh = tm
	mi.position = pos
	mi.rotation.x = -PI / 2.0
	mi.material_override = _mat(Color(0.86, 0.70, 0.32), 0.32, 0.6)
	parent.add_child(mi)


static func _wall_text(parent: Node3D, text: String, pos: Vector3, size: float) -> void:
	var mi := MeshInstance3D.new()
	var tm := TextMesh.new()
	tm.text = text
	tm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tm.font_size = 10
	tm.depth = 0.003
	tm.pixel_size = size / 10.0
	mi.mesh = tm
	mi.position = pos
	var mat := _mat(Color(0.86, 0.67, 0.27), 0.24, 0.72)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.emission_enabled = true
	mat.emission = Color(0.86, 0.67, 0.27)
	mat.emission_energy_multiplier = 0.25
	mi.material_override = mat
	parent.add_child(mi)


static func _shoe(parent: Node3D) -> Node3D:
	var root := Node3D.new()
	root.name = "Shoe"
	root.position = Vector3(0.58, 0.78, -0.38)
	root.rotation.y = -0.55
	parent.add_child(root)
	var body := _mat(Color(0.10, 0.09, 0.08), 0.4, 0.05)
	_box(root, Vector3(0.16, 0.07, 0.22), Vector3(0, 0.03, 0), body)
	var mouth := _mat(Color(0.06, 0.05, 0.045), 0.5)
	_box(root, Vector3(0.14, 0.035, 0.06), Vector3(0, 0.04, 0.10), mouth)
	var brass := _mat(Color(0.80, 0.64, 0.28), 0.3, 0.7)
	_box(root, Vector3(0.165, 0.006, 0.225), Vector3(0, 0.066, 0), brass)
	return root


static func _tray(parent: Node3D) -> Node3D:
	var root := Node3D.new()
	root.name = "ChipTray"
	root.position = Vector3(-0.58, 0.752, 0.18)
	parent.add_child(root)
	var wood := _mat(Color(0.16, 0.08, 0.04), 0.42, 0.1)
	_box(root, Vector3(0.28, 0.03, 0.16), Vector3(0, 0.01, 0), wood)
	return root


static func _discard(parent: Node3D) -> Node3D:
	var root := Node3D.new()
	root.name = "Discard"
	root.position = Vector3(-0.56, 0.752, -0.38)
	parent.add_child(root)
	var wood := _mat(Color(0.14, 0.07, 0.04), 0.45, 0.08)
	_box(root, Vector3(0.16, 0.02, 0.14), Vector3(0, 0.008, 0), wood)
	return root


static func _lamp(parent: Node3D) -> Node3D:
	var root := Node3D.new()
	root.name = "DealerLamp"
	root.position = Vector3(0.0, 1.32, -0.72)
	parent.add_child(root)
	var brass := _mat(Color(0.72, 0.56, 0.24), 0.3, 0.7)
	_cyl(root, 0.018, 0.55, Vector3(0, -0.12, 0), brass, 12)
	var shade := MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 0.03
	cone.bottom_radius = 0.14
	cone.height = 0.12
	shade.mesh = cone
	shade.position = Vector3(0, 0.12, 0.02)
	var sm := _mat(Color(0.55, 0.16, 0.10), 0.55)
	sm.emission_enabled = true
	sm.emission = Color(0.8, 0.45, 0.15)
	sm.emission_energy_multiplier = 0.35
	shade.material_override = sm
	root.add_child(shade)
	return root


static func _dealer_station(parent: Node3D) -> Node3D:
	var root := Node3D.new()
	root.name = "DealerStation"
	root.position = Vector3(0.0, 0.752, -0.52)
	parent.add_child(root)
	var leather := _mat(Color(0.12, 0.07, 0.05), 0.62)
	_box(root, Vector3(0.42, 0.01, 0.16), Vector3(0, 0.006, 0), leather)
	var brass := _mat(Color(0.78, 0.62, 0.28), 0.3, 0.65)
	_box(root, Vector3(0.44, 0.008, 0.02), Vector3(0, 0.012, -0.08), brass)
	return root
