class_name MeshKit
extends RefCounted
## Kit de primitivas para montar personagens, props e cenário em código.
## Malhas são cacheadas por parâmetros (instâncias compartilham a mesma malha).

static var _meshes: Dictionary = {}


static func _cached(key: String, maker: Callable) -> Mesh:
	if not _meshes.has(key):
		_meshes[key] = maker.call()
	return _meshes[key]


## Fator de suavidade: as primitivas recebem mais segmentos (sem facetas visíveis).
static func _seg(n: int, cap: int) -> int:
	return clampi(n * 2, n, cap) if Settings.quality > 0 else n


static func sphere(r: float, segs: int = 16, rings: int = 10, hemi: bool = false) -> Mesh:
	segs = _seg(segs, 36)
	rings = _seg(rings, 20)
	return _cached("sph|%f|%d|%d|%s" % [r, segs, rings, hemi], func():
		var m := SphereMesh.new()
		m.radius = r
		m.height = r * (1.0 if hemi else 2.0)
		m.radial_segments = segs
		m.rings = rings
		m.is_hemisphere = hemi
		return m)


static func capsule(r: float, h: float, segs: int = 12) -> Mesh:
	segs = _seg(segs, 28)
	return _cached("cap|%f|%f|%d" % [r, h, segs], func():
		var m := CapsuleMesh.new()
		m.radius = r
		m.height = maxf(h, r * 2.0)
		m.radial_segments = segs
		m.rings = 8
		return m)


static func cylinder(top: float, bottom: float, h: float, segs: int = 14) -> Mesh:
	segs = _seg(segs, 32)
	return _cached("cyl|%f|%f|%f|%d" % [top, bottom, h, segs], func():
		var m := CylinderMesh.new()
		m.top_radius = top
		m.bottom_radius = bottom
		m.height = h
		m.radial_segments = segs
		m.rings = 1
		return m)


## Tronco de cone aberto (sem tampas) — capas, saias e abajures.
static func open_cone(top: float, bottom: float, h: float, segs: int = 24) -> Mesh:
	segs = _seg(segs, 40)
	return _cached("ocone|%f|%f|%f|%d" % [top, bottom, h, segs], func():
		var m := CylinderMesh.new()
		m.top_radius = top
		m.bottom_radius = bottom
		m.height = h
		m.radial_segments = segs
		m.rings = 2
		m.cap_top = false
		m.cap_bottom = false
		return m)


## Caixa com quinas levemente chanfradas (pegam luz como madeira e pedra de verdade).
static func box(size: Vector3) -> Mesh:
	var mn := minf(size.x, minf(size.y, size.z))
	if Settings.quality > 0 and mn > 0.015:
		return OrganicMesh.rounded_box(size, clampf(mn * 0.12, 0.004, 0.06))
	return _cached("box|%s" % str(size), func():
		var m := BoxMesh.new()
		m.size = size
		return m)


static func torus(inner: float, outer: float, segs: int = 20, ring_segs: int = 8) -> Mesh:
	segs = _seg(segs, 40)
	ring_segs = _seg(ring_segs, 14)
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


## Tufo de grama: lâminas curvas e afiladas em leque (para MultiMesh).
static func grass_clump() -> Mesh:
	return _cached("grass_clump2", func():
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var rng := RandomNumberGenerator.new()
		rng.seed = 5
		for i in 7:
			var a := float(i) / 7.0 * TAU + rng.randf_range(-0.3, 0.3)
			var dir := Vector3(cos(a), 0, sin(a))
			var side := Vector3(-dir.z, 0, dir.x)
			var hgt := rng.randf_range(0.32, 0.55)
			var w := rng.randf_range(0.022, 0.034)
			var lean := rng.randf_range(0.08, 0.2)
			var base := dir * rng.randf_range(0.0, 0.06)
			var segs := 3
			var prev_l := base - side * w
			var prev_r := base + side * w
			for k in segs:
				var t := float(k + 1) / float(segs)
				var c := base + Vector3(0, hgt * t, 0) + dir * lean * t * t
				var ww := w * (1.0 - t * 0.92)
				var l := c - side * ww
				var r := c + side * ww
				var v0 := float(k) / float(segs)
				st.set_uv(Vector2(0, 1.0 - v0)); st.add_vertex(prev_l)
				st.set_uv(Vector2(1, 1.0 - v0)); st.add_vertex(prev_r)
				st.set_uv(Vector2(0, 1.0 - t)); st.add_vertex(l)
				st.set_uv(Vector2(1, 1.0 - v0)); st.add_vertex(prev_r)
				st.set_uv(Vector2(1, 1.0 - t)); st.add_vertex(r)
				st.set_uv(Vector2(0, 1.0 - t)); st.add_vertex(l)
				prev_l = l
				prev_r = r
		st.generate_normals()
		return st.commit())


## Pedra natural: esfera deformada por ruído em várias escalas, normais suaves.
static func rock(seed_value: int, r: float = 1.0) -> Mesh:
	return _cached("rock2|%d|%f" % [seed_value, r], func():
		var n := FastNoiseLite.new()
		n.seed = seed_value * 17 + 3
		n.frequency = 0.9
		n.fractal_octaves = 4
		var rows: Array = []
		var rings := 16
		var segs := 24
		for i in rings + 1:
			var phi := float(i) / float(rings) * PI
			var row := PackedVector3Array()
			for j in segs:
				var th := float(j) / float(segs) * TAU
				var d := Vector3(sin(phi) * sin(th), cos(phi), -sin(phi) * cos(th))
				var k := 1.0 + n.get_noise_3dv(d * 1.3) * 0.32 + n.get_noise_3dv(d * 4.0) * 0.06
				var p := d * r * k
				p.y *= 0.8
				# base achatada (assenta no chão)
				p.y = maxf(p.y, -r * 0.5)
				row.append(p)
			rows.append(row)
		return OrganicMesh.grid(rows, true))


## Copa de árvore: massa irregular com "tufos" (ruído de baixa frequência), normais suaves.
static func canopy(seed_value: int, r: float = 1.25) -> Mesh:
	return _cached("canopy|%d|%f" % [seed_value, r], func():
		var n := FastNoiseLite.new()
		n.seed = seed_value * 31 + 7
		n.frequency = 1.4
		n.fractal_octaves = 2
		var rows: Array = []
		var rings := 14
		var segs := 22
		for i in rings + 1:
			var phi := float(i) / float(rings) * PI
			var row := PackedVector3Array()
			for j in segs:
				var th := float(j) / float(segs) * TAU
				var d := Vector3(sin(phi) * sin(th), cos(phi), -sin(phi) * cos(th))
				var k := 1.0 + n.get_noise_3dv(d) * 0.28
				var p := d * r * k
				if p.y < 0.0:
					p.y *= 0.72
				row.append(p)
			rows.append(row)
		return OrganicMesh.grid(rows, true))


## Camada de pinheiro: cone com borda recortada em pontas que caem (galhos).
static func pine_tier(r: float = 1.4, h: float = 1.9, points: int = 9) -> Mesh:
	return _cached("pine|%f|%f|%d" % [r, h, points], func():
		var rows: Array = []
		var segs := points * 4
		var rings := 6
		for i in rings + 1:
			var t := float(i) / float(rings)      # 0 = ponta, 1 = base
			var row := PackedVector3Array()
			for j in segs:
				var th := float(j) / float(segs) * TAU
				var spike := 0.5 + 0.5 * cos(th * points)
				var rr := r * t * (0.8 + 0.2 * spike * t)
				var y := h * 0.5 - h * t - spike * 0.18 * h * t * t
				row.append(Vector3(sin(th) * rr, y, -cos(th) * rr))
			rows.append(row)
		# fundo (levemente côncavo)
		var bottom := PackedVector3Array()
		for j in segs:
			bottom.append(Vector3(0, -h * 0.32, 0))
		rows.append(bottom)
		return OrganicMesh.grid(rows, true))


## Junta as peças estáticas de um conjunto (casa, cerca…) numa malha por material:
## centenas de peças viram poucas chamadas de desenho. Subárvores com script
## (interativos) e nós com nome próprio que o jogo procura ficam de fora.
static func batch(root_node: Node3D) -> void:
	var groups: Dictionary = {}       # chave -> [material, [[mesh, xform], ...], sombra]
	var victims: Array = []
	_collect(root_node, root_node, Transform3D.IDENTITY, groups, victims)
	for key in groups:
		var g: Array = groups[key]
		var parts: Array = g[1]
		if parts.size() < 2:
			continue
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for e in parts:
			var pe: Array = e
			st.append_from(pe[0], 0, pe[1])
			(pe[2] as Node).queue_free()
		var mi := MeshInstance3D.new()
		mi.mesh = st.commit()
		mi.material_override = g[0]
		if not g[2]:
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root_node.add_child(mi)


static func _collect(n: Node, root_node: Node3D, xf: Transform3D, groups: Dictionary, victims: Array) -> void:
	for c in n.get_children():
		if not (c is Node3D) or c.get_script() != null or not c.get_groups().is_empty():
			continue
		var c3: Node3D = c
		var cx := xf * c3.transform
		if c is MeshInstance3D:
			var mi: MeshInstance3D = c
			var anonymous := str(mi.name).begins_with("@")
			if anonymous and mi.mesh and mi.material_override and mi.material_overlay == null and mi.get_child_count() == 0 and mi.mesh.get_surface_count() == 1:
				var shadow := mi.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				# primitivas e malhas geradas têm formatos de vértice diferentes: grupos separados
				var fmt := -1
				if mi.mesh is ArrayMesh:
					fmt = (mi.mesh as ArrayMesh).surface_get_format(0) & (Mesh.ARRAY_FORMAT_NORMAL | Mesh.ARRAY_FORMAT_TANGENT | Mesh.ARRAY_FORMAT_TEX_UV | Mesh.ARRAY_FORMAT_COLOR)
				var key := "%d|%d|%s" % [mi.material_override.get_instance_id(), fmt, str(shadow)]
				if not groups.has(key):
					groups[key] = [mi.material_override, [], shadow]
				(groups[key][1] as Array).append([mi.mesh, cx, mi])
		elif c.get_class() == "Node3D":
			_collect(c, root_node, cx, groups, victims)


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
