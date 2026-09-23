class_name TableBuilder
extends RefCounted
## Builds the static room and table geometry. Everything is procedural; baked
## textures (felt print, carpet, wallpaper, art, sign) are assigned later by TableView.

const MeshKit = preload("res://scripts/table/mesh_kit.gd")
const TableLayout = preload("res://scripts/table/table_layout.gd")
const ChipFactory = preload("res://scripts/table/chip_factory.gd")

const FELT_SHADER := preload("res://assets/shaders/felt.gdshader")


static func build(parent: Node3D) -> Dictionary:
	var nodes := {}
	_table(parent, nodes)
	_dealer_side(parent, nodes)
	_shoe(parent, nodes)
	_discard(parent, nodes)
	_lamp(parent, nodes)
	_room(parent, nodes)
	return nodes


# --- materials --------------------------------------------------------------

static func mat(color: Color, rough: float, metal: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	m.metallic = metal
	return m


static func wood() -> StandardMaterial3D:
	var m := mat(Color(0.15, 0.068, 0.034), 0.34, 0.0)
	m.clearcoat_enabled = true
	m.clearcoat = 0.6
	m.clearcoat_roughness = 0.2
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	noise.frequency = 0.02
	noise.fractal_octaves = 3
	var tex := NoiseTexture2D.new()
	tex.width = 512
	tex.height = 64
	tex.seamless = true
	tex.noise = noise
	var ramp := Gradient.new()
	ramp.set_color(0, Color(0.7, 0.66, 0.62))
	ramp.set_color(1, Color(1.0, 1.0, 1.0))
	tex.color_ramp = ramp
	m.albedo_texture = tex
	m.uv1_scale = Vector3(3, 12, 1)
	return m


static func brass() -> StandardMaterial3D:
	var m := mat(Color(0.80, 0.62, 0.32), 0.26, 0.92)
	return m


static func leather() -> StandardMaterial3D:
	var m := mat(Color(0.030, 0.024, 0.022), 0.5, 0.0)
	m.rim_enabled = true
	m.rim = 0.25
	m.rim_tint = 0.4
	m.clearcoat_enabled = true
	m.clearcoat = 0.3
	m.clearcoat_roughness = 0.45
	return m


static func emissive(color: Color, energy: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = energy
	return m


# --- helpers ----------------------------------------------------------------

static func box(parent: Node3D, size: Vector3, pos: Vector3, material: Material, shadows: bool = true) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.position = pos
	mi.material_override = material
	if not shadows:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


static func cyl(parent: Node3D, top: float, bottom: float, h: float, pos: Vector3, material: Material, segs: int = 32) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = top
	mesh.bottom_radius = bottom
	mesh.height = h
	mesh.radial_segments = segs
	mi.mesh = mesh
	mi.position = pos
	mi.material_override = material
	parent.add_child(mi)
	return mi


static func mesh_instance(parent: Node3D, mesh: Mesh, pos: Vector3, material: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	mi.material_override = material
	parent.add_child(mi)
	return mi


# --- table ------------------------------------------------------------------

static func _table(parent: Node3D, nodes: Dictionary) -> void:
	var c := TableLayout.CENTER
	var felt_mat := ShaderMaterial.new()
	felt_mat.shader = FELT_SHADER
	var fiber := NoiseTexture2D.new()
	fiber.width = 256
	fiber.height = 256
	fiber.seamless = true
	fiber.generate_mipmaps = true
	var fn := FastNoiseLite.new()
	fn.noise_type = FastNoiseLite.TYPE_CELLULAR
	fn.frequency = 0.09
	fiber.noise = fn
	felt_mat.set_shader_parameter("fiber_tex", fiber)
	var felt := mesh_instance(parent, MeshKit.half_disc(TableLayout.FELT_RADIUS), c, felt_mat)
	felt.name = "Felt"
	nodes["felt"] = felt
	nodes["felt_mat"] = felt_mat
	# Padded arm rail following the arc.
	var rail := mesh_instance(parent, MeshKit.arc_sweep(TableLayout.RAIL_RADIUS, 0.0, PI, MeshKit.rail_profile(0.150, 0.066), 128), c + Vector3(0, 0.020, 0), leather())
	rail.name = "Rail"
	# Brass bead where felt meets the rail.
	mesh_instance(parent, MeshKit.arc_sweep(TableLayout.FELT_RADIUS + 0.002, 0.0, PI, MeshKit.rail_profile(0.008, 0.008, 10), 128, false), c + Vector3(0, 0.003, 0), brass())
	# Wood apron under the rail.
	var wood_m := wood()
	mesh_instance(parent, MeshKit.arc_sweep(TableLayout.RAIL_RADIUS, 0.0, PI, MeshKit.rect_profile(-0.07, 0.058, -0.19, -0.012), 128), c, wood_m)
	# Under-slab to close the table.
	var under_m := mat(Color(0.05, 0.03, 0.02), 0.8)
	under_m.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh_instance(parent, MeshKit.half_disc(TableLayout.RAIL_RADIUS + 0.05), c + Vector3(0, -0.19, 0), under_m)
	# Pedestal legs.
	var dark := mat(Color(0.05, 0.03, 0.02), 0.5, 0.1)
	for x in [-0.55, 0.55]:
		cyl(parent, 0.05, 0.08, 0.56, Vector3(x, 0.28, -0.10), dark, 16)
		cyl(parent, 0.16, 0.18, 0.03, Vector3(x, 0.015, -0.10), brass(), 24)
	nodes["wood_mat"] = wood_m


static func _dealer_side(parent: Node3D, nodes: Dictionary) -> void:
	var c := TableLayout.CENTER
	var wood_m: Material = nodes["wood_mat"]
	# Dealer counter along the straight edge.
	box(parent, Vector3(2.46, 0.06, 0.12), Vector3(0, c.y - 0.01, c.z - 0.06), wood_m)
	box(parent, Vector3(2.46, 0.008, 0.012), Vector3(0, c.y + 0.02, c.z - 0.002), brass())
	box(parent, Vector3(2.46, 0.19, 0.03), Vector3(0, c.y - 0.1, c.z - 0.105), wood_m)
	# Chip rack (the dealer's float), inset into the felt.
	var rack := Node3D.new()
	rack.name = "ChipRack"
	rack.position = TableLayout.RACK_POS
	parent.add_child(rack)
	box(rack, Vector3(0.50, 0.018, 0.105), Vector3(0, 0.004, 0), mat(Color(0.03, 0.025, 0.02), 0.4, 0.2))
	box(rack, Vector3(0.51, 0.006, 0.108), Vector3(0, 0.014, 0), brass())
	var order := [100000, 50000, 10000, 2500, 500, 100]
	for i in order.size():
		var x := -0.20 + float(i) * 0.08
		for k in 17:
			var chip := ChipFactory.make(order[i])
			chip.rotation.x = PI * 0.5
			chip.position = Vector3(x, 0.024, -0.04 + float(k) * TableLayout.CHIP_HEIGHT * 1.02)
			chip.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			rack.add_child(chip)
	nodes["rack"] = rack
	# Table-limit placard.
	var placard := Node3D.new()
	placard.position = Vector3(0.40, c.y, -0.36)
	placard.rotation.y = -0.35
	parent.add_child(placard)
	box(placard, Vector3(0.11, 0.004, 0.02), Vector3(0, 0.002, 0.01), brass())
	var sign := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(0.10, 0.06)
	sign.mesh = q
	sign.position = Vector3(0, 0.03, 0.0)
	sign.rotation.x = deg_to_rad(-15)
	placard.add_child(sign)
	nodes["placard"] = sign


static func _shoe(parent: Node3D, nodes: Dictionary) -> void:
	var root := Node3D.new()
	root.name = "Shoe"
	root.position = TableLayout.SHOE_POS
	root.rotation.y = deg_to_rad(38)
	parent.add_child(root)
	var body := mat(Color(0.025, 0.025, 0.03), 0.22, 0.2)
	body.clearcoat_enabled = true
	body.clearcoat = 0.9
	box(root, Vector3(0.13, 0.012, 0.25), Vector3(0, 0.006, -0.01), body)
	for sx in [-1.0, 1.0]:
		box(root, Vector3(0.010, 0.072, 0.25), Vector3(sx * 0.060, 0.036, -0.01), body)
		box(root, Vector3(0.004, 0.004, 0.25), Vector3(sx * 0.060, 0.073, -0.01), brass())
	box(root, Vector3(0.13, 0.072, 0.010), Vector3(0, 0.036, -0.135), body)
	var smoke := mat(Color(0.05, 0.05, 0.06, 0.55), 0.08, 0.0)
	smoke.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	smoke.metallic_specular = 0.7
	box(root, Vector3(0.11, 0.004, 0.20), Vector3(0, 0.072, -0.035), smoke, false)
	# Block of cards leaning in the shoe; its depth tracks the cards remaining.
	var stack := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.105, 0.055, 1.0)
	stack.mesh = bm
	stack.material_override = mat(Color(0.90, 0.88, 0.82), 0.75)
	stack.position = Vector3(0, 0.04, -0.02)
	stack.scale = Vector3(1, 1, 0.2)
	root.add_child(stack)
	# Sloped mouth with the next card showing its back.
	var lip := box(root, Vector3(0.13, 0.010, 0.06), Vector3(0, 0.020, 0.135), body)
	lip.rotation.x = deg_to_rad(-12)
	var next := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(TableLayout.CARD_W * 0.98, TableLayout.CARD_H * 0.5)
	next.mesh = q
	next.position = Vector3(0, 0.030, 0.118)
	next.rotation.x = deg_to_rad(-78)
	root.add_child(next)
	box(root, Vector3(0.132, 0.006, 0.012), Vector3(0, 0.030, 0.163), brass())
	nodes["shoe"] = root
	nodes["shoe_stack"] = stack
	nodes["shoe_next"] = next


static func _discard(parent: Node3D, nodes: Dictionary) -> void:
	var root := Node3D.new()
	root.name = "Discard"
	root.position = TableLayout.DISCARD_POS
	root.rotation.y = deg_to_rad(-30)
	parent.add_child(root)
	var acrylic := mat(Color(0.06, 0.06, 0.07, 0.32), 0.06, 0.0)
	acrylic.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	acrylic.metallic_specular = 0.7
	acrylic.cull_mode = BaseMaterial3D.CULL_DISABLED
	var hw := TableLayout.CARD_W * 0.5 + 0.007
	var hd := TableLayout.CARD_H * 0.5 + 0.007
	box(root, Vector3(hw * 2.0, 0.006, hd * 2.0), Vector3(0, 0.003, 0), mat(Color(0.03, 0.025, 0.02), 0.4))
	for s in [-1.0, 1.0]:
		box(root, Vector3(0.004, 0.055, hd * 2.0), Vector3(s * hw, 0.0275, 0), acrylic, false)
		box(root, Vector3(hw * 2.0, 0.055, 0.004), Vector3(0, 0.0275, s * hd), acrylic, false)
		box(root, Vector3(0.005, 0.004, hd * 2.0 + 0.004), Vector3(s * hw, 0.056, 0), brass(), false)
	var stack := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(TableLayout.CARD_W, 1.0, TableLayout.CARD_H)
	stack.mesh = bm
	stack.position = Vector3(0, 0.006, 0)
	stack.scale = Vector3(1, 0.0001, 1)
	stack.visible = false
	root.add_child(stack)
	nodes["discard"] = root
	nodes["discard_stack"] = stack


static func _lamp(parent: Node3D, nodes: Dictionary) -> void:
	var root := Node3D.new()
	root.name = "Lamp"
	root.position = Vector3(0.0, 1.86, -0.12)
	parent.add_child(root)
	var shade_m := mat(Color(0.02, 0.10, 0.06), 0.28, 0.35)
	shade_m.clearcoat_enabled = true
	shade_m.clearcoat = 1.0
	cyl(root, 0.10, 0.34, 0.15, Vector3.ZERO, shade_m, 48)
	var rim := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.335
	torus.outer_radius = 0.35
	torus.rings = 64
	rim.mesh = torus
	rim.position = Vector3(0, -0.075, 0)
	rim.material_override = brass()
	root.add_child(rim)
	var glow_m := emissive(Color(1.0, 0.86, 0.62), 1.8)
	var glow := cyl(root, 0.32, 0.32, 0.004, Vector3(0, -0.07, 0), glow_m, 48)
	glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	cyl(root, 0.008, 0.008, 1.3, Vector3(0, 0.72, 0), brass(), 8)
	cyl(root, 0.03, 0.05, 0.06, Vector3(0, 0.1, 0), brass(), 16)
	var light := SpotLight3D.new()
	light.name = "LampLight"
	light.position = Vector3(0, -0.06, 0.02)
	light.rotation.x = -PI * 0.5
	light.light_color = Color(1.0, 0.86, 0.66)
	light.light_energy = 2.7
	light.spot_range = 3.2
	light.spot_angle = 58.0
	light.spot_angle_attenuation = 0.9
	light.spot_attenuation = 0.6
	light.shadow_enabled = true
	light.shadow_blur = 1.6
	light.shadow_bias = 0.015
	light.shadow_normal_bias = 0.6
	light.light_volumetric_fog_energy = 0.6
	root.add_child(light)
	nodes["lamp"] = root
	nodes["lamp_light"] = light
	nodes["lamp_glow"] = glow_m


# --- room -------------------------------------------------------------------

static func _room(parent: Node3D, nodes: Dictionary) -> void:
	var room := Node3D.new()
	room.name = "Room"
	parent.add_child(room)
	var carpet := mat(Color(1, 1, 1), 0.95)
	carpet.uv1_scale = Vector3(5, 5, 1)
	var floor := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(9, 9)
	floor.mesh = pm
	floor.material_override = carpet
	room.add_child(floor)
	nodes["carpet_mat"] = carpet
	var paper := mat(Color(1, 1, 1), 0.85)
	paper.uv1_scale = Vector3(4, 2, 1)
	nodes["wall_mat"] = paper
	var wood_m: Material = nodes["wood_mat"]
	var back_z := -2.6
	var side_x := 2.8
	# Back wall.
	_wall(room, Vector3(0, 0, back_z), 0.0, 5.6, paper, wood_m)
	# Side walls.
	_wall(room, Vector3(-side_x, 0, -0.2), PI * 0.5, 4.8, paper, wood_m)
	_wall(room, Vector3(side_x, 0, -0.2), -PI * 0.5, 4.8, paper, wood_m)
	# Front wall (behind the seated player, seen in the menu orbit).
	_wall(room, Vector3(0, 0, 2.2), PI, 5.6, paper, wood_m)
	var ceiling := MeshInstance3D.new()
	var cm := PlaneMesh.new()
	cm.size = Vector2(6, 5)
	cm.flip_faces = true
	ceiling.mesh = cm
	ceiling.position = Vector3(0, 3.1, -0.2)
	ceiling.material_override = mat(Color(0.02, 0.018, 0.016), 0.9)
	room.add_child(ceiling)
	# Illuminated sign.
	var sign_m := emissive(Color(1, 1, 1), 2.2)
	sign_m.albedo_color = Color(0, 0, 0)
	var plate := Node3D.new()
	plate.position = Vector3(0, 2.02, back_z + 0.05)
	room.add_child(plate)
	box(plate, Vector3(1.9, 0.34, 0.03), Vector3(0, 0, -0.01), mat(Color(0.015, 0.015, 0.018), 0.4, 0.2))
	box(plate, Vector3(1.94, 0.012, 0.035), Vector3(0, 0.175, -0.01), brass())
	box(plate, Vector3(1.94, 0.012, 0.035), Vector3(0, -0.175, -0.01), brass())
	var sign := MeshInstance3D.new()
	var sq := QuadMesh.new()
	sq.size = Vector2(1.8, 0.225)
	sign.mesh = sq
	sign.position = Vector3(0, 0, 0.008)
	sign.material_override = sign_m
	plate.add_child(sign)
	nodes["sign_mat"] = sign_m
	# Framed art.
	var art_mats: Array = []
	for x in [-1.75, 1.75]:
		var frame := Node3D.new()
		frame.position = Vector3(x, 1.9, back_z + 0.04)
		room.add_child(frame)
		box(frame, Vector3(0.86, 1.06, 0.04), Vector3(0, 0, 0), brass())
		var canvas := MeshInstance3D.new()
		var q := QuadMesh.new()
		q.size = Vector2(0.74, 0.94)
		canvas.mesh = q
		canvas.position = Vector3(0, 0, 0.022)
		var am := mat(Color(1, 1, 1), 0.8)
		am.emission_enabled = true
		am.emission_energy_multiplier = 0.25
		canvas.material_override = am
		frame.add_child(canvas)
		art_mats.append(am)
	nodes["art_mats"] = art_mats
	# Sconces.
	var lights: Array = []
	for pos in [Vector3(-0.95, 1.95, back_z + 0.06), Vector3(0.95, 1.95, back_z + 0.06), Vector3(-2.72, 1.95, -1.1), Vector3(2.72, 1.95, 0.6)]:
		var s := Node3D.new()
		s.position = pos
		if absf(pos.x) > 2.0:
			s.rotation.y = PI * 0.5 if pos.x < 0 else -PI * 0.5
		room.add_child(s)
		box(s, Vector3(0.08, 0.2, 0.02), Vector3(0, 0, 0), brass())
		var bulb := cyl(s, 0.035, 0.05, 0.12, Vector3(0, 0.06, 0.06), emissive(Color(1.0, 0.8, 0.55), 3.5), 16)
		bulb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var l := OmniLight3D.new()
		l.position = Vector3(0, 0.1, 0.12)
		l.light_color = Color(1.0, 0.78, 0.52)
		l.light_energy = 0.9
		l.omni_range = 1.8
		l.omni_attenuation = 1.4
		s.add_child(l)
		lights.append(l)
	nodes["sconces"] = lights
	_credenza(room, Vector3(0, 0, back_z + 0.32), nodes)
	_bar(room, Vector3(-side_x + 0.2, 0, -1.3))
	_curtains(room, Vector3(side_x - 0.1, 0, -1.2))


static func _wall(room: Node3D, pos: Vector3, yaw: float, width: float, paper: Material, wood_m: Material) -> void:
	var w := Node3D.new()
	w.position = pos
	w.rotation.y = yaw
	room.add_child(w)
	var upper := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(width, 2.1)
	upper.mesh = q
	upper.position = Vector3(0, 2.1, 0)
	upper.material_override = paper
	w.add_child(upper)
	box(w, Vector3(width, 1.06, 0.05), Vector3(0, 0.53, 0), wood_m)
	var panels := int(width / 0.9)
	for i in panels:
		var x := -width * 0.5 + (float(i) + 0.5) * width / float(panels)
		box(w, Vector3(width / float(panels) - 0.12, 0.7, 0.02), Vector3(x, 0.52, 0.03), wood_m)
	box(w, Vector3(width, 0.035, 0.07), Vector3(0, 1.075, 0.01), brass())
	box(w, Vector3(width, 0.12, 0.08), Vector3(0, 3.05, 0.0), wood_m)


## Low sideboard behind the dealer with two lamps: warm points of light that the
## seated camera sees (softened by depth of field) above the far rail.
static func _credenza(room: Node3D, pos: Vector3, nodes: Dictionary) -> void:
	var root := Node3D.new()
	root.position = pos
	room.add_child(root)
	var wood_m: Material = nodes["wood_mat"]
	box(root, Vector3(3.2, 0.50, 0.46), Vector3(0, 0.25, 0), wood_m)
	box(root, Vector3(3.24, 0.03, 0.5), Vector3(0, 0.515, 0), mat(Color(0.02, 0.02, 0.022), 0.15, 0.1))
	for i in 6:
		box(root, Vector3(0.46, 0.36, 0.012), Vector3(-1.3 + float(i) * 0.52, 0.25, 0.232), wood_m)
		cyl(root, 0.012, 0.012, 0.06, Vector3(-1.3 + float(i) * 0.52, 0.28, 0.25), brass(), 8).rotation.x = PI * 0.5
	var shade := emissive(Color(1.0, 0.78, 0.5), 1.5)
	for x in [-1.45, 1.45]:
		cyl(root, 0.045, 0.07, 0.2, Vector3(x, 0.63, 0), brass(), 20)
		var s := cyl(root, 0.09, 0.15, 0.17, Vector3(x, 0.80, 0), shade, 28)
		s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var l := OmniLight3D.new()
		l.position = Vector3(x, 0.78, 0.15)
		l.light_color = Color(1.0, 0.76, 0.5)
		l.light_energy = 1.0
		l.omni_range = 2.0
		root.add_child(l)


static func _bar(room: Node3D, pos: Vector3) -> void:
	var bar := Node3D.new()
	bar.position = pos
	bar.rotation.y = PI * 0.5
	room.add_child(bar)
	var glow := emissive(Color(0.95, 0.62, 0.30), 1.6)
	var panel := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(1.6, 1.3)
	panel.mesh = q
	panel.position = Vector3(0, 1.75, -0.08)
	panel.material_override = glow
	bar.add_child(panel)
	var shelf := mat(Color(0.12, 0.06, 0.03), 0.3)
	var rng := RandomNumberGenerator.new()
	rng.seed = 21
	var glass_colors := [Color(0.45, 0.22, 0.05), Color(0.12, 0.28, 0.12), Color(0.55, 0.52, 0.45), Color(0.35, 0.08, 0.06)]
	for row in 3:
		var y := 1.2 + float(row) * 0.42
		box(bar, Vector3(1.7, 0.03, 0.22), Vector3(0, y, 0), shelf)
		var x := -0.72
		while x < 0.72:
			var col: Color = glass_colors[rng.randi_range(0, glass_colors.size() - 1)]
			var g := mat(col, 0.08, 0.2)
			g.rim_enabled = true
			g.rim = 0.6
			var h := rng.randf_range(0.2, 0.3)
			cyl(bar, 0.032, 0.035, h, Vector3(x, y + 0.015 + h * 0.5, 0), g, 12)
			cyl(bar, 0.011, 0.014, 0.08, Vector3(x, y + 0.015 + h + 0.04, 0), g, 8)
			x += rng.randf_range(0.08, 0.12)
	var l := OmniLight3D.new()
	l.position = Vector3(0, 1.8, 0.4)
	l.light_color = Color(1.0, 0.7, 0.4)
	l.light_energy = 0.8
	l.omni_range = 2.2
	bar.add_child(l)


static func _curtains(room: Node3D, pos: Vector3) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var width := 1.8
	var height := 2.9
	var folds := 9
	var seg := 90
	for i in seg:
		var x0 := -width * 0.5 + width * float(i) / float(seg)
		var x1 := -width * 0.5 + width * float(i + 1) / float(seg)
		var z0 := sin(float(i) / float(seg) * TAU * folds) * 0.05
		var z1 := sin(float(i + 1) / float(seg) * TAU * folds) * 0.05
		var n0 := Vector3(-cos(float(i) / float(seg) * TAU * folds) * 0.6, 0, 1).normalized()
		var n1 := Vector3(-cos(float(i + 1) / float(seg) * TAU * folds) * 0.6, 0, 1).normalized()
		var v := [Vector3(x0, height, z0), Vector3(x1, height, z1), Vector3(x1, 0, z1), Vector3(x0, 0, z0)]
		var n := [n0, n1, n1, n0]
		for k in [0, 1, 2, 0, 2, 3]:
			st.set_normal(n[k])
			st.add_vertex(v[k])
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.position = pos
	mi.rotation.y = -PI * 0.5
	var velvet := mat(Color(0.22, 0.025, 0.04), 0.75)
	velvet.rim_enabled = true
	velvet.rim = 0.5
	velvet.rim_tint = 0.2
	velvet.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = velvet
	room.add_child(mi)
