class_name MeshKit
extends RefCounted
## Kit de primitivas para montar personagens, props e cenário em código.
## Malhas são cacheadas por parâmetros (instâncias compartilham a mesma malha).

static var _meshes: Dictionary = {}


static func _cached(key: String, maker: Callable) -> Mesh:
	if not _meshes.has(key):
		_meshes[key] = maker.call()
	return _meshes[key]


static func sphere(r: float, segs: int = 16, rings: int = 10, hemi: bool = false) -> Mesh:
	return _cached("sph|%f|%d|%d|%s" % [r, segs, rings, hemi], func():
		var m := SphereMesh.new()
		m.radius = r
		m.height = r * (1.0 if hemi else 2.0)
		m.radial_segments = segs
		m.rings = rings
		m.is_hemisphere = hemi
		return m)


static func capsule(r: float, h: float, segs: int = 12) -> Mesh:
	return _cached("cap|%f|%f|%d" % [r, h, segs], func():
		var m := CapsuleMesh.new()
		m.radius = r
		m.height = maxf(h, r * 2.0)
		m.radial_segments = segs
		m.rings = 4
		return m)


static func cylinder(top: float, bottom: float, h: float, segs: int = 14) -> Mesh:
	return _cached("cyl|%f|%f|%f|%d" % [top, bottom, h, segs], func():
		var m := CylinderMesh.new()
		m.top_radius = top
		m.bottom_radius = bottom
		m.height = h
		m.radial_segments = segs
		m.rings = 1
		return m)


static func box(size: Vector3) -> Mesh:
	return _cached("box|%s" % str(size), func():
		var m := BoxMesh.new()
		m.size = size
		return m)


static func torus(inner: float, outer: float, segs: int = 20, ring_segs: int = 8) -> Mesh:
	return _cached("tor|%f|%f|%d" % [inner, outer, segs], func():
		var m := TorusMesh.new()
		m.inner_radius = inner
		m.outer_radius = outer
		m.rings = segs
		m.ring_segments = ring_segs
		return m)


static func prism(size: Vector3) -> Mesh:
	return _cached("pri|%s" % str(size), func():
		var m := PrismMesh.new()
		m.size = size
		return m)


static func plane(size: Vector2) -> Mesh:
	return _cached("pla|%s" % str(size), func():
		var m := PlaneMesh.new()
		m.size = size
		return m)


## Octaedro (cristal) — esfera de 4 segmentos e 2 anéis.
static func crystal(r: float) -> Mesh:
	return _cached("cry|%f" % r, func():
		var m := SphereMesh.new()
		m.radius = r
		m.height = r * 2.6
		m.radial_segments = 4
		m.rings = 2
		return m)


## Estrela de cinco pontas extrudada.
static func star(outer: float, inner: float, depth: float) -> Mesh:
	return _cached("star|%f|%f|%f" % [outer, inner, depth], func():
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var pts: Array[Vector2] = []
		for i in 10:
			var a := -PI / 2.0 + i * PI / 5.0
			var r := outer if i % 2 == 0 else inner
			pts.append(Vector2(cos(a), sin(a)) * r)
		var hz := depth * 0.5
		for i in 10:
			var a2 := pts[i]
			var b2 := pts[(i + 1) % 10]
			# frente e verso
			st.add_vertex(Vector3(0, 0, hz)); st.add_vertex(Vector3(b2.x, -b2.y, hz)); st.add_vertex(Vector3(a2.x, -a2.y, hz))
			st.add_vertex(Vector3(0, 0, -hz)); st.add_vertex(Vector3(a2.x, -a2.y, -hz)); st.add_vertex(Vector3(b2.x, -b2.y, -hz))
			# lateral
			var a3 := Vector3(a2.x, -a2.y, hz)
			var b3 := Vector3(b2.x, -b2.y, hz)
			var a4 := Vector3(a2.x, -a2.y, -hz)
			var b4 := Vector3(b2.x, -b2.y, -hz)
			st.add_vertex(a3); st.add_vertex(b3); st.add_vertex(b4)
			st.add_vertex(a3); st.add_vertex(b4); st.add_vertex(a4)
		st.generate_normals()
		return st.commit())


## Tufo de grama: três lâminas cruzadas e afiladas (para MultiMesh).
static func grass_clump() -> Mesh:
	return _cached("grass_clump", func():
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for i in 3:
			var a := i * PI / 3.0
			var dir := Vector3(cos(a), 0, sin(a))
			var w := 0.09
			var hgt := 0.42 + 0.08 * i
			var lean := Vector3(sin(a * 2.0), 0, cos(a * 3.0)) * 0.08
			var p0 := -dir * w
			var p1 := dir * w
			var p2 := Vector3(0, hgt, 0) + lean
			st.set_uv(Vector2(0, 1)); st.add_vertex(p0)
			st.set_uv(Vector2(1, 1)); st.add_vertex(p1)
			st.set_uv(Vector2(0.5, 0)); st.add_vertex(p2)
		st.generate_normals()
		return st.commit())


## Pedra low-poly: esfera deformada com faces planas.
static func rock(seed_value: int, r: float = 1.0) -> Mesh:
	return _cached("rock|%d|%f" % [seed_value, r], func():
		var base := SphereMesh.new()
		base.radius = r
		base.height = r * 1.6
		base.radial_segments = 7
		base.rings = 4
		var arrays := base.get_mesh_arrays()
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value
		var offsets := {}
		for i in verts.size():
			var key := (verts[i] * 100.0).round()
			if not offsets.has(key):
				offsets[key] = rng.randf_range(0.82, 1.15)
			verts[i] *= offsets[key]
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for i in idx:
			st.add_vertex(verts[i])
		st.generate_normals()
		return st.commit())


## Cria um MeshInstance3D filho com transformação local.
static func part(parent: Node3D, mesh: Mesh, material: Material, pos: Vector3 = Vector3.ZERO,
		rot_deg: Vector3 = Vector3.ZERO, scl: Vector3 = Vector3.ONE, cast_shadow: bool = true) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = material
	mi.position = pos
	mi.rotation_degrees = rot_deg
	mi.scale = scl
	if not cast_shadow:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


static func pivot(parent: Node3D, pos: Vector3 = Vector3.ZERO, node_name: String = "") -> Node3D:
	var n := Node3D.new()
	n.position = pos
	if node_name != "":
		n.name = node_name
	parent.add_child(n)
	return n


static func light(parent: Node3D, color: Color, energy: float, light_range: float, pos: Vector3 = Vector3.ZERO, shadows: bool = false) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.light_color = color
	l.light_energy = energy
	l.omni_range = light_range
	l.position = pos
	l.shadow_enabled = shadows
	parent.add_child(l)
	return l
