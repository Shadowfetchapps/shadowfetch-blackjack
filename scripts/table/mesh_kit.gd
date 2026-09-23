class_name MeshKit
extends RefCounted
## Procedural meshes for the table: rounded cards, chips, the padded rail, the felt.
## Godot treats clockwise winding (as seen from the front) as front-facing.

static var _card_mesh: ArrayMesh
static var _chip_mesh: ArrayMesh


## Card lying in the XZ plane, face up (+Y). Surface 0 face, 1 back, 2 edge.
## The top of the face texture points to -Z (away from a seated player).
static func card_mesh(w: float, h: float, t: float, r: float, seg: int = 6) -> ArrayMesh:
	if _card_mesh != null:
		return _card_mesh
	var outline := _rounded_rect(w, h, r, seg)
	var mesh := ArrayMesh.new()
	# Face (top).
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := outline.size()
	for i in n:
		var a: Vector2 = outline[i]
		var b: Vector2 = outline[(i + 1) % n]
		for p in [Vector2.ZERO, a, b]:
			st.set_normal(Vector3.UP)
			st.set_uv(Vector2((p.x + w * 0.5) / w, (p.y + h * 0.5) / h))
			st.add_vertex(Vector3(p.x, t * 0.5, p.y))
	st.generate_tangents()
	st.commit(mesh)
	# Back (bottom), mirrored U so it reads correctly once the card is flipped.
	st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in n:
		var a: Vector2 = outline[i]
		var b: Vector2 = outline[(i + 1) % n]
		for p in [Vector2.ZERO, b, a]:
			st.set_normal(Vector3.DOWN)
			st.set_uv(Vector2(1.0 - (p.x + w * 0.5) / w, (p.y + h * 0.5) / h))
			st.add_vertex(Vector3(p.x, -t * 0.5, p.y))
	st.generate_tangents()
	st.commit(mesh)
	# Edge band.
	st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in n:
		var a: Vector2 = outline[i]
		var b: Vector2 = outline[(i + 1) % n]
		var na := Vector3(a.x, 0, a.y).normalized()
		var nb := Vector3(b.x, 0, b.y).normalized()
		var a_top := Vector3(a.x, t * 0.5, a.y)
		var b_top := Vector3(b.x, t * 0.5, b.y)
		var a_bot := Vector3(a.x, -t * 0.5, a.y)
		var b_bot := Vector3(b.x, -t * 0.5, b.y)
		_quad(st, [a_top, b_top, b_bot, a_bot], [na, nb, nb, na])
	st.commit(mesh)
	_card_mesh = mesh
	return mesh


## Chip cylinder. Surface 0 = both faces (planar UV), surface 1 = side band.
static func chip_mesh(radius: float, height: float, seg: int = 40) -> ArrayMesh:
	if _chip_mesh != null:
		return _chip_mesh
	var mesh := ArrayMesh.new()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var ring: Array[Vector2] = []
	for i in seg:
		var ang := TAU * float(i) / float(seg)
		ring.append(Vector2(cos(ang), sin(ang)) * radius)
	for i in seg:
		var a := ring[i]
		var b := ring[(i + 1) % seg]
		for p in [Vector2.ZERO, a, b]:
			st.set_normal(Vector3.UP)
			st.set_uv(Vector2(0.5 + p.x / (2.0 * radius), 0.5 + p.y / (2.0 * radius)))
			st.add_vertex(Vector3(p.x, height * 0.5, p.y))
		for p in [Vector2.ZERO, b, a]:
			st.set_normal(Vector3.DOWN)
			st.set_uv(Vector2(0.5 + p.x / (2.0 * radius), 0.5 - p.y / (2.0 * radius)))
			st.add_vertex(Vector3(p.x, -height * 0.5, p.y))
	st.commit(mesh)
	st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in seg:
		var a := ring[i]
		var b := ring[(i + 1) % seg]
		var ua := float(i) / float(seg)
		var ub := float(i + 1) / float(seg)
		var na := Vector3(a.x, 0, a.y).normalized()
		var nb := Vector3(b.x, 0, b.y).normalized()
		var verts := [
			Vector3(a.x, height * 0.5, a.y), Vector3(b.x, height * 0.5, b.y),
			Vector3(b.x, -height * 0.5, b.y), Vector3(a.x, -height * 0.5, a.y),
		]
		var uvs := [Vector2(ua, 0), Vector2(ub, 0), Vector2(ub, 1), Vector2(ua, 1)]
		for k in [0, 1, 2, 0, 2, 3]:
			st.set_normal(na if k == 0 or k == 3 else nb)
			st.set_uv(uvs[k])
			st.add_vertex(verts[k])
	st.commit(mesh)
	_chip_mesh = mesh
	return mesh


## Half disc (z >= center.z side) used for the felt. UV maps the bounding box:
## u across X, v from the straight edge (0) to the arc apex (1).
static func half_disc(radius: float, seg: int = 96) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in seg:
		var a0 := PI * float(i) / float(seg)
		var a1 := PI * float(i + 1) / float(seg)
		var p0 := Vector2(cos(a0), sin(a0)) * radius
		var p1 := Vector2(cos(a1), sin(a1)) * radius
		for p in [Vector2.ZERO, p0, p1]:
			st.set_normal(Vector3.UP)
			st.set_uv(Vector2((p.x + radius) / (2.0 * radius), p.y / radius))
			st.set_uv2(p * 4.0)
			st.add_vertex(Vector3(p.x, 0, p.y))
	st.generate_tangents()
	return st.commit()


## A profile swept along an arc around the origin (angles in radians, XZ plane,
## angle 0 = +X, PI/2 = +Z). Profile points are (radial offset, height).
static func arc_sweep(radius: float, a0: float, a1: float, profile: PackedVector2Array, seg: int = 96, caps: bool = true) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var pn := profile.size()
	var length := radius * absf(a1 - a0)
	var rings: Array = []
	for i in seg + 1:
		var ang := lerpf(a0, a1, float(i) / float(seg))
		var dir := Vector3(cos(ang), 0, sin(ang))
		var ring: Array = []
		for p in profile:
			ring.append(dir * (radius + p.x) + Vector3.UP * p.y)
		rings.append(ring)
	for i in seg:
		var ang0 := lerpf(a0, a1, float(i) / float(seg))
		var ang1 := lerpf(a0, a1, float(i + 1) / float(seg))
		var d0 := Vector3(cos(ang0), 0, sin(ang0))
		var d1 := Vector3(cos(ang1), 0, sin(ang1))
		for j in pn:
			var k := (j + 1) % pn
			var pj: Vector2 = profile[j]
			var pk: Vector2 = profile[k]
			var edge := (pk - pj).normalized()
			var n2 := Vector2(edge.y, -edge.x)
			var n0 := (d0 * n2.x + Vector3.UP * n2.y).normalized()
			var n1 := (d1 * n2.x + Vector3.UP * n2.y).normalized()
			var u0 := length * float(i) / float(seg) * 4.0
			var u1 := length * float(i + 1) / float(seg) * 4.0
			var v0 := float(j) / float(pn)
			var v1 := float(j + 1) / float(pn)
			var quad := [rings[i][j], rings[i + 1][j], rings[i + 1][k], rings[i][k]]
			var norms := [n0, n1, n1, n0]
			var uvs := [Vector2(u0, v0), Vector2(u1, v0), Vector2(u1, v1), Vector2(u0, v1)]
			for idx in [0, 1, 2, 0, 2, 3]:
				st.set_normal(norms[idx])
				st.set_uv(uvs[idx])
				st.add_vertex(quad[idx])
	if caps:
		for end in [0, seg]:
			var ring: Array = rings[end]
			var center := Vector3.ZERO
			for v in ring:
				center += v
			center /= float(pn)
			var ang := a0 if end == 0 else a1
			var tangent := Vector3(-sin(ang), 0, cos(ang)) * (-1.0 if end == 0 else 1.0)
			for j in pn:
				var k := (j + 1) % pn
				var tri := [center, ring[j], ring[k]] if end == 0 else [center, ring[k], ring[j]]
				for v in tri:
					st.set_normal(tangent)
					st.set_uv(Vector2(0.5, 0.5))
					st.add_vertex(v)
	return st.commit()


## Rounded pill-like profile for the padded arm rail.
static func rail_profile(width: float, height: float, pts: int = 20) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in pts:
		var a := TAU * float(i) / float(pts)
		var c := cos(a)
		var s := sin(a)
		# Superellipse gives a plump, upholstered cross-section.
		var x := signf(c) * pow(absf(c), 0.7) * width * 0.5
		var y := signf(s) * pow(absf(s), 0.8) * height * 0.5
		out.append(Vector2(x, y))
	return out


static func rect_profile(inner: float, outer: float, y0: float, y1: float) -> PackedVector2Array:
	return PackedVector2Array([Vector2(inner, y1), Vector2(outer, y1), Vector2(outer, y0), Vector2(inner, y0)])


static func _rounded_rect(w: float, h: float, r: float, seg: int) -> PackedVector2Array:
	var out := PackedVector2Array()
	var cx := w * 0.5 - r
	var cz := h * 0.5 - r
	var centers := [Vector2(cx, cz), Vector2(-cx, cz), Vector2(-cx, -cz), Vector2(cx, -cz)]
	for k in 4:
		for i in seg + 1:
			var a := deg_to_rad(90.0 * k + 90.0 * float(i) / float(seg))
			out.append(centers[k] + Vector2(cos(a), sin(a)) * r)
	return out


static func _quad(st: SurfaceTool, v: Array, n: Array) -> void:
	for idx in [0, 1, 2, 0, 2, 3]:
		st.set_normal(n[idx])
		st.add_vertex(v[idx])
