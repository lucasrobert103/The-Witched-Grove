class_name ValleyBuilder
extends RefCounted
## Monta o Vale dos Sussurros: terreno, água, vegetação (MultiMesh), estruturas,
## pontos de interesse, NPCs, criaturas, obstáculos e segredos.
## Layout coerente com data/world/regions.json.

var root: Node3D
var terrain := ValleyTerrain.new()
var rng := RandomNumberGenerator.new()
var quality: int = 1
var static_body: StaticBody3D        # colisões estáticas agrupadas
var pond: WaterBody
var creek: WaterBody
var corruption: MeshInstance3D
var outside_doors: Dictionary = {}
var rooms: Dictionary = {}


func build(p_root: Node3D, p_quality: int) -> void:
	root = p_root
	quality = p_quality
	rng.seed = 2024
	static_body = StaticBody3D.new()
	static_body.name = "StaticColliders"
	root.add_child(static_body)
	_build_terrain()
	_build_water()
	_build_walls()
	_build_vegetation()
	_build_home()
	_build_pois()
	_build_harvest_nodes()
	_build_npcs()
	_build_creatures()
	_build_village()
	_build_far_areas()
	_build_magic_props()
	_build_ambient()
	rooms = InteriorBuilder.new().build_all(root, outside_doors)


func h(x: float, z: float) -> float:
	return terrain.height(x, z)


func at(x: float, z: float, y_off: float = 0.0) -> Vector3:
	return Vector3(x, h(x, z) + y_off, z)


func _add(node: Node3D, pos: Vector3, rot_y_deg: float = 0.0) -> Node3D:
	node.position = pos
	node.rotation_degrees.y = rot_y_deg
	root.add_child(node)
	return node


func _box_collider(pos: Vector3, size: Vector3, rot_y: float = 0.0) -> void:
	var cs := CollisionShape3D.new()
	var s := BoxShape3D.new()
	s.size = size
	cs.shape = s
	cs.position = pos
	cs.rotation.y = rot_y
	static_body.add_child(cs)


func _cyl_collider(pos: Vector3, r: float, height: float) -> void:
	var cs := CollisionShape3D.new()
	var s := CylinderShape3D.new()
	s.radius = r
	s.height = height
	cs.shape = s
	cs.position = pos + Vector3(0, height * 0.5, 0)
	static_body.add_child(cs)


# ===================================================================== terreno

func _build_terrain() -> void:
	var mesh := terrain.build_mesh()
	var mi := MeshInstance3D.new()
	mi.name = "Terrain"
	mi.mesh = mesh
	mi.material_override = Toon.terrain()
	root.add_child(mi)
	var body := StaticBody3D.new()
	body.name = "TerrainBody"
	var cs := CollisionShape3D.new()
	cs.shape = mesh.create_trimesh_shape()
	body.add_child(cs)
	root.add_child(body)
	# Bordas invisíveis (além das montanhas)
	for i in 48:
		var a := i * TAU / 48.0
		var p := Vector3(sin(a), 0, cos(a)) * (ValleyTerrain.BOUNDARY + 6.0)
		var cs2 := CollisionShape3D.new()
		var b := BoxShape3D.new()
		b.size = Vector3(14.0, 60.0, 2.0)
		cs2.shape = b
		cs2.position = p + Vector3(0, 10, 0)
		cs2.rotation.y = a
		static_body.add_child(cs2)


func _build_water() -> void:
	pond = WaterBody.new()
	pond.name = "Lagoa"
	root.add_child(pond)
	pond.setup("lagoa", ValleyTerrain.POND_LEVEL)
	pond.add_disc(Vector3(ValleyTerrain.POND_CENTER.x, 0, ValleyTerrain.POND_CENTER.y), ValleyTerrain.POND_RADIUS + 0.6)
	creek = WaterBody.new()
	creek.name = "Riacho"
	root.add_child(creek)
	creek.setup("riacho", ValleyTerrain.CREEK_LEVEL)
	var pts := terrain.creek
	for i in pts.size() - 1:
		creek.add_segment(Vector3(pts[i].x, 0, pts[i].y), Vector3(pts[i + 1].x, 0, pts[i + 1].y), 4.2)
	# Lírios na lagoa
	var lily := Toon.mat(Color("#4fae5a"), {"outline": 0.01})
	for i in 9:
		var a := i * 0.83 + 0.4
		var r := rng.randf_range(3.2, 6.6)
		var p := Vector3(ValleyTerrain.POND_CENTER.x + sin(a) * r, ValleyTerrain.POND_LEVEL + 0.04, ValleyTerrain.POND_CENTER.y + cos(a) * r)
		MeshKit.part(root, MeshKit.cylinder(0.45, 0.45, 0.02, 10), lily, p)
		if i % 3 == 0:
			MeshKit.part(root, MeshKit.sphere(0.12, 8, 4), Toon.mat(Color("#ffd1f0"), {"emission": 0.3}), p + Vector3(0.1, 0.08, 0))


func _build_walls() -> void:
	## Muralhas de pedra que definem as sub-regiões (portões: cogumelo, sarças, riacho).
	var rock_m := Toon.mat(Color("#8b889c"), {"surface": "stone", "rim": 0.2, "outline": 0.03})
	var walls := [
		[Vector2(28.5, -96), Vector2(28.5, -6.6)],
		[Vector2(28.5, -1.4), Vector2(28.5, 7.0)],
		[Vector2(32.5, 7.5), Vector2(96, 7.5)],
		[Vector2(-96, -21.5), Vector2(-28.3, -21.5)],
		[Vector2(-23.7, -21.5), Vector2(-21.5, -21.5)],
		[Vector2(-21.5, -21.5), Vector2(-21.5, -96)],
	]
	for w in walls:
		var a: Vector2 = w[0]
		var b: Vector2 = w[1]
		var d := b - a
		var n := maxi(1, int(d.length() / 2.0))
		for i in n + 1:
			var p := a + d * (float(i) / n)
			if p.length() > ValleyTerrain.BOUNDARY + 6.0:
				continue
			var s := rng.randf_range(1.7, 2.6)
			var mi := MeshKit.part(root, MeshKit.rock(rng.randi_range(0, 9), 1.0), rock_m, at(p.x, p.y, s * 0.4), Vector3(0, rng.randf_range(0, 360), 0), Vector3(s, s * rng.randf_range(1.1, 1.6), s))
			mi.name = "WallRock"
		var mid := (a + b) * 0.5
		_box_collider(Vector3(mid.x, h(mid.x, mid.y) + 2.0, mid.y), Vector3(2.4, 14.0, d.length() + 1.0) if absf(d.x) < absf(d.y) else Vector3(d.length() + 1.0, 14.0, 2.4))


# ===================================================================== vegetação

func _multimesh(mesh: Mesh, material: Material, transforms: Array, colors: Array, shadows: bool = true) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	mm.instance_count = transforms.size()
	for i in transforms.size():
		mm.set_instance_transform(i, transforms[i])
		mm.set_instance_color(i, colors[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = material
	if not shadows:
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mmi)
	return mmi


func _build_vegetation() -> void:
	var trunks: Array = []
	var trunk_c: Array = []
	var blobs: Array = []
	var blob_c: Array = []
	var cones: Array = []
	var cone_c: Array = []
	var leaf_palette := [Color("#4fae5a"), Color("#5fbf5f"), Color("#3f9a55"), Color("#7cc96a"), Color("#3d8f6a")]
	var autumn := [Color("#f2a541"), Color("#e8743b"), Color("#d9a441")]
	var placed := 0
	var tries := 0
	var target := 560
	while placed < target and tries < 14000:
		tries += 1
		var a := rng.randf_range(0, TAU)
		var r := sqrt(rng.randf()) * 94.0
		var x := sin(a) * r
		var z := cos(a) * r
		if not terrain.is_free(x, z, 0.5):
			continue
		var dens := 0.25 if r < 22.0 else 1.0
		if rng.randf() > dens:
			continue
		var y := h(x, z)
		var s := rng.randf_range(0.85, 1.35)
		if Vector2(x, z).distance_to(Vector2(58, 44)) < 15.0 or Vector2(x, z).distance_to(Vector2(0, 74)) < 24.0:
			continue
		var pine := (z < -20.0 and rng.randf() < 0.65) or (r > 76.0 and rng.randf() < 0.6)
		var basis := Basis(Vector3.UP, rng.randf_range(0, TAU))
		trunks.append(Transform3D(basis.scaled(Vector3(s, s, s)), Vector3(x, y + 1.2 * s, z)))
		trunk_c.append(Color("#7a5236").lerp(Color("#5a3d2a"), rng.randf()))
		if pine:
			var pc := Color("#2f7a5a").lerp(Color("#3d8f6a"), rng.randf())
			for k in 3:
				var ks := s * (1.25 - k * 0.3)
				cones.append(Transform3D(basis.scaled(Vector3(ks, ks, ks)), Vector3(x, y + (2.0 + k * 1.1) * s, z)))
				cone_c.append(pc.lightened(k * 0.06))
		else:
			var lc: Color = leaf_palette[rng.randi() % leaf_palette.size()]
			if rng.randf() < 0.12:
				lc = autumn[rng.randi() % autumn.size()]
			for k in 3:
				var off := Vector3(rng.randf_range(-0.6, 0.6), 2.4 + k * 0.55 + rng.randf_range(0, 0.3), rng.randf_range(-0.6, 0.6)) * s
				var bs := s * rng.randf_range(0.9, 1.25) * (1.0 - k * 0.15)
				blobs.append(Transform3D(Basis(Vector3.UP, rng.randf_range(0, TAU)).scaled(Vector3(bs, bs * 0.9, bs)), Vector3(x, y, z) + off))
				blob_c.append(lc.lightened(k * 0.05))
		_cyl_collider(Vector3(x, y, z), 0.35 * s, 3.0)
		placed += 1
	var bark := Toon.vertex_colored({"surface": "wood"})
	_multimesh(_trunk_mesh(), bark, trunks, trunk_c)
	_multimesh(MeshKit.canopy(1, 1.25), Toon.foliage(), blobs, blob_c)
	_multimesh(MeshKit.pine_tier(1.4, 1.9, 9), Toon.foliage(), cones, cone_c)

	# Grama e flores
	var grass_count: int = [2600, 5600, 9000][clampi(quality, 0, 2)]
	var gt: Array = []
	var gc: Array = []
	var ft: Array = []
	var fc: Array = []
	var flower_cols := [Color("#ff9fb2"), Color("#fff3a0"), Color("#c8a2ff"), Color("#ffffff"), Color("#8fd6ff"), Color("#ffb86b")]
	tries = 0
	while gt.size() < grass_count and tries < grass_count * 4:
		tries += 1
		var x := rng.randf_range(-88, 88)
		var z := rng.randf_range(-88, 88)
		if Vector2(x, z).length() > 86.0:
			continue
		if terrain.dist_to_path(x, z) < 1.3 or terrain.dist_to_creek(x, z) < 3.2 or terrain.dist_to_pond(x, z) < ValleyTerrain.POND_RADIUS + 1.0:
			continue
		if Vector2(x, z).distance_to(Vector2(0, -6)) < 5.5:
			continue
		var y := h(x, z)
		var s := rng.randf_range(0.7, 1.45)
		gt.append(Transform3D(Basis(Vector3.UP, rng.randf_range(0, TAU)).scaled(Vector3(s, s, s)), Vector3(x, y - 0.02, z)))
		gc.append(Color("#6fbf5c").lerp(Color("#9ad46a"), rng.randf()))
		if rng.randf() < 0.14:
			var fs := rng.randf_range(0.8, 1.2)
			ft.append(Transform3D(Basis().scaled(Vector3(fs, fs, fs)), Vector3(x + 0.2, y + 0.32 * fs, z)))
			fc.append(flower_cols[rng.randi() % flower_cols.size()])
	_multimesh(MeshKit.grass_clump(), Toon.grass(), gt, gc, false)
	_multimesh(MeshKit.sphere(0.07, 8, 4), Toon.vertex_colored({"emission": 0.15}), ft, fc, false)

	# Pedras decorativas e arbustos
	var rock_m := Toon.mat(Color("#9894a8"), {"surface": "stone", "outline": 0.02})
	var bush_t: Array = []
	var bush_c: Array = []
	for i in 170:
		var x := rng.randf_range(-86, 86)
		var z := rng.randf_range(-86, 86)
		if not terrain.is_free(x, z, -0.8):
			continue
		if i % 2 == 0:
			var s := rng.randf_range(0.4, 1.0)
			MeshKit.part(root, MeshKit.rock(i % 10, 1.0), rock_m, at(x, z, s * 0.2), Vector3(0, rng.randf_range(0, 360), 0), Vector3(s, s * 0.8, s))
			if s > 0.75:
				_cyl_collider(at(x, z), s * 0.8, 1.0)
		else:
			var s2 := rng.randf_range(0.5, 0.9)
			bush_t.append(Transform3D(Basis().scaled(Vector3(s2, s2 * 0.75, s2)), at(x, z, 0.25)))
			bush_c.append(Color("#4f9f55").lerp(Color("#6fbf5c"), rng.randf()))
	_multimesh(MeshKit.canopy(2, 0.8), Toon.foliage(), bush_t, bush_c)


## Tronco com raízes alargadas e uma leve curva (no lugar do cilindro reto).
func _trunk_mesh() -> Mesh:
	return OrganicMesh.cached("trunk", func():
		return OrganicMesh.tube([Vector3(0, -1.3, 0), Vector3(0, -1.0, 0.02), Vector3(0.02, -0.2, 0.0), Vector3(-0.03, 0.6, -0.03), Vector3(0.0, 1.25, 0.02)], [0.42, 0.3, 0.26, 0.23, 0.18], {"segs": 12, "sub": 3}))


# ===================================================================== casa

func _build_home() -> void:
	var base := at(0, -6)
	var home := Node3D.new()
	home.name = "Cabana"
	_add(home, base)
	var wall := Toon.mat(Color("#f1e3c6"), {"surface": "plaster", "rim": 0.2, "outline": 0.025})
	var timber := Toon.mat(Color("#6b4630"), {"surface": "wood", "outline": 0.02})
	var roof := Toon.mat(Color("#5a3a8a"), {"surface": "roof", "rim": 0.3, "outline": 0.03})
	var stone := Toon.mat(Color("#9a96a8"), {"surface": "stone", "outline": 0.02})
	var glow := Toon.glow(Color("#ffd27a"), 1.6)
	# fundação e paredes
	MeshKit.part(home, MeshKit.box(Vector3(7.4, 0.5, 5.6)), stone, Vector3(0, 0.0, 0))
	MeshKit.part(home, MeshKit.box(Vector3(7.0, 3.0, 5.0)), wall, Vector3(0, 1.75, 0))
	for x in [-3.45, 3.45]:
		for z in [-2.45, 2.45]:
			MeshKit.part(home, MeshKit.box(Vector3(0.25, 3.1, 0.25)), timber, Vector3(x, 1.75, z))
	MeshKit.part(home, MeshKit.box(Vector3(7.2, 0.22, 0.2)), timber, Vector3(0, 3.2, 2.52))
	MeshKit.part(home, MeshKit.box(Vector3(7.2, 0.22, 0.2)), timber, Vector3(0, 1.6, 2.52))
	# telhado em duas águas, inclinado e torto (charme)
	for side in [-1.0, 1.0]:
		MeshKit.part(home, MeshKit.box(Vector3(8.4, 0.3, 3.8)), roof, Vector3(0, 4.35, side * 1.45), Vector3(side * -38, 0, 1.5))
	MeshKit.part(home, MeshKit.prism(Vector3(7.0, 1.7, 5.0)), wall, Vector3(0, 4.05, 0))
	MeshKit.part(home, MeshKit.box(Vector3(8.6, 0.25, 0.4)), Toon.mat(Color("#f3c74f"), {"outline": 0.02}), Vector3(0, 5.5, 0), Vector3(0, 0, 1.5))
	# chaminé torta
	var ch := MeshKit.pivot(home, Vector3(2.2, 4.4, -1.0))
	ch.rotation_degrees = Vector3(0, 0, -6)
	MeshKit.part(ch, MeshKit.cylinder(0.42, 0.5, 2.4, 10), stone, Vector3(0, 0.6, 0))
	MeshKit.part(ch, MeshKit.cylinder(0.5, 0.42, 0.3, 10), stone, Vector3(0, 1.9, 0))
	var smoke := _smoke_particles()
	smoke.position = Vector3(0, 2.2, 0)
	ch.add_child(smoke)
	# porta arredondada e janelas redondas
	MeshKit.part(home, MeshKit.box(Vector3(1.3, 2.0, 0.15)), Toon.mat(Color("#7a3f5a"), {"outline": 0.02}), Vector3(0, 1.25, 2.55))
	MeshKit.part(home, MeshKit.cylinder(0.65, 0.65, 0.15, 16), Toon.mat(Color("#7a3f5a"), {"outline": 0.02}), Vector3(0, 2.25, 2.55), Vector3(90, 0, 0))
	MeshKit.part(home, MeshKit.sphere(0.08, 8, 6), Toon.mat(Color("#f3c74f")), Vector3(0.4, 1.3, 2.65))
	for wx in [-2.2, 2.2]:
		MeshKit.part(home, MeshKit.torus(0.48, 0.6, 18, 6), timber, Vector3(wx, 2.0, 2.53), Vector3(90, 0, 0))
		MeshKit.part(home, MeshKit.cylinder(0.5, 0.5, 0.08, 16), glow, Vector3(wx, 2.0, 2.52), Vector3(90, 0, 0))
		MeshKit.part(home, MeshKit.box(Vector3(1.2, 0.25, 0.4)), timber, Vector3(wx, 1.35, 2.7))
		for k in 3:
			MeshKit.part(home, MeshKit.sphere(0.13, 8, 4), Toon.mat([Color("#ff9fb2"), Color("#fff3a0"), Color("#c8a2ff")][k]), Vector3(wx - 0.35 + k * 0.35, 1.55, 2.72))
	MeshKit.light(home, Color("#ffcf8a"), 1.4, 7.0, Vector3(0, 2.6, 3.4), false)
	# varanda
	MeshKit.part(home, MeshKit.box(Vector3(7.6, 0.18, 2.2)), Toon.mat(Color("#9a6a3e"), {"surface": "wood", "outline": 0.02}), Vector3(0, 0.3, 3.6))
	for x in [-3.6, 3.6]:
		MeshKit.part(home, MeshKit.cylinder(0.1, 0.12, 2.9, 8), timber, Vector3(x, 1.75, 4.5))
	MeshKit.part(home, MeshKit.box(Vector3(7.8, 0.15, 2.4)), roof, Vector3(0, 3.25, 3.7), Vector3(-14, 0, 0))
	# lanterna pendurada
	var lan := MeshKit.pivot(home, Vector3(-3.0, 2.6, 4.4))
	MeshKit.part(lan, MeshKit.sphere(0.16, 10, 6), glow)
	MeshKit.part(lan, MeshKit.cylinder(0.12, 0.18, 0.08, 8), timber, Vector3(0, 0.18, 0))
	_box_collider(base + Vector3(0, 2.0, 0), Vector3(7.4, 4.0, 5.4))

	# Porta da cabana: entra no interior (cama, estantes, grimório, baú)
	var door := Station.new()
	door.setup("door", {"room": "cabana", "title": "Cabana da Clareira"})
	_add(door, at(0, -2.9))
	door.map_label = "Casa"
	outside_doors["cabana"] = at(0, -1.6, 0.1)

	# Runa da porta (Marca de Retorno) — surge após a missão do Guardião
	var rune := Readable.new()
	rune.setup("pedra_retorno", "carving", "quest_done.mq02_raizes")
	_add(rune, at(1.2, -3.2, 0.6))

	# Caldeirão sob pérgola (laboratório)
	var lab := Station.new()
	lab.setup("cauldron")
	_add(lab, at(6.2, -1.2))
	lab.map_label = "Caldeirão"
	var wood := Toon.mat(Color("#8a5a36"), {"surface": "wood", "outline": 0.02})
	for p in [Vector3(-1.4, 0, -1.4), Vector3(1.4, 0, -1.4), Vector3(-1.4, 0, 1.4), Vector3(1.4, 0, 1.4)]:
		MeshKit.part(lab, MeshKit.cylinder(0.08, 0.1, 2.8, 6), wood, p + Vector3(0, 1.4, 0))
	MeshKit.part(lab, MeshKit.box(Vector3(3.4, 0.12, 3.4)), roof, Vector3(0, 2.85, 0), Vector3(0, 45, 0))
	MeshKit.part(lab, MeshKit.sphere(0.75, 16, 10), Toon.mat(Color("#2a2433"), {"rim": 0.4, "outline": 0.03}), Vector3(0, 0.75, 0), Vector3.ZERO, Vector3(1.0, 0.8, 1.0))
	MeshKit.part(lab, MeshKit.torus(0.6, 0.72, 20, 6), Toon.mat(Color("#3a3444"), {"outline": 0.02}), Vector3(0, 1.3, 0))
	var brew := MeshKit.pivot(lab, Vector3(0, 1.28, 0))
	MeshKit.part(brew, MeshKit.cylinder(0.6, 0.6, 0.05, 18), Toon.glow(Color("#7dffb0"), 1.4))
	lab.set_anim_node(brew)
	MeshKit.light(lab, Color("#7dffb0"), 1.2, 4.5, Vector3(0, 1.8, 0))
	for k in 3:
		MeshKit.part(lab, MeshKit.cylinder(0.08, 0.08, 0.9, 6), wood, Vector3(sin(k * 2.1) * 0.35, 0.1, cos(k * 2.1) * 0.35), Vector3(80, k * 60, 0))
	var fire := _fire_particles(Color("#ff9a3c"))
	fire.position = Vector3(0, 0.1, 0)
	lab.add_child(fire)
	var bubbles := _bubble_particles()
	bubbles.position = Vector3(0, 1.3, 0)
	lab.add_child(bubbles)
	_cyl_collider(lab.position, 0.8, 1.4)
	var receituario := Readable.new()
	receituario.setup("receituario_caldeirao", "book")
	_add(receituario, at(7.4, -2.9, 1.25))
	# prateleira de ingredientes
	MeshKit.part(lab, MeshKit.box(Vector3(1.6, 0.08, 0.4)), wood, Vector3(0, 1.4, -1.6))
	for k in 5:
		MeshKit.part(lab, MeshKit.cylinder(0.08, 0.1, 0.28, 8), Toon.mat([Color("#ff6f7d"), Color("#7fa8ff"), Color("#c8a2ff"), Color("#fff3a0"), Color("#8fcf5a")][k], {"emission": 0.4}), Vector3(-0.6 + k * 0.3, 1.58, -1.6))

	# Jardim: 9 canteiros (3×3), luz definida por posição
	for i in Garden.MAX_PLOTS:
		var plot := GardenPlot.new()
		plot.setup(i)
		var gx := -8.6 + (i % 3) * 2.0
		var gz := 1.6 + int(i / 3.0) * 2.0
		_add(plot, at(gx, gz))
	# cerca do jardim
	for k in 8:
		MeshKit.part(root, MeshKit.box(Vector3(0.12, 0.7, 0.12)), wood, at(-10.0 + k * 0.95, 0.2, 0.35))
	MeshKit.part(root, MeshKit.box(Vector3(7.0, 0.08, 0.06)), wood, at(-6.6, 0.2, 0.55))
	# Espantalho simpático com chapéu de bruxa
	var scare := MeshKit.pivot(root, at(-11.2, 4.0))
	MeshKit.part(scare, MeshKit.cylinder(0.05, 0.06, 2.0, 6), wood, Vector3(0, 1.0, 0))
	MeshKit.part(scare, MeshKit.cylinder(0.04, 0.04, 1.4, 6), wood, Vector3(0, 1.4, 0), Vector3(0, 0, 90))
	MeshKit.part(scare, MeshKit.sphere(0.25, 10, 8), Toon.mat(Color("#e8c66a"), {"outline": 0.015}), Vector3(0, 2.1, 0))
	MeshKit.part(scare, MeshKit.cylinder(0.0, 0.25, 0.6, 10), Toon.mat(Color("#3a2068"), {"outline": 0.015}), Vector3(0, 2.55, 0), Vector3(0, 0, -12))
	MeshKit.part(scare, MeshKit.cylinder(0.45, 0.45, 0.03, 14), Toon.mat(Color("#3a2068"), {"outline": 0.015}), Vector3(0, 2.28, 0))

	# Círculo ritual (Sala Ritual)
	var ritual := Station.new()
	ritual.setup("ritual")
	_add(ritual, at(7.5, 6.0))
	for k in 6:
		var a := k * TAU / 6.0
		MeshKit.part(ritual, MeshKit.box(Vector3(0.35, 0.9, 0.25)), stone, Vector3(sin(a) * 2.0, 0.45, cos(a) * 2.0), Vector3(0, rad_to_deg(a), 0))
	var ring := MeshKit.pivot(ritual, Vector3(0, 0.05, 0))
	MeshKit.part(ring, MeshKit.torus(1.5, 1.6, 32, 4), Toon.glow(Color("#c9a5ff"), 1.0))
	MeshKit.part(ring, MeshKit.star(1.2, 0.5, 0.01), Toon.glow(Color("#7a4fc4"), 0.6), Vector3(0, 0.02, 0), Vector3(-90, 0, 0))
	ritual.set_anim_node(ring)

	# Lanternas da trilha
	for p in [Vector2(-1.8, 6), Vector2(1.8, 6), Vector2(-6, 13.5), Vector2(4, 12), Vector2(-14, 18), Vector2(13, 3), Vector2(-2.5, -14), Vector2(-15, 2.5)]:
		_lantern(p)
	MeshKit.batch(home)


func _lantern(p: Vector2) -> void:
	var n := MeshKit.pivot(root, at(p.x, p.y))
	n.add_to_group("lantern")
	var wood := Toon.mat(Color("#5a3d2a"), {"surface": "wood", "outline": 0.015})
	MeshKit.part(n, MeshKit.cylinder(0.06, 0.08, 1.8, 6), wood, Vector3(0, 0.9, 0))
	MeshKit.part(n, MeshKit.box(Vector3(0.5, 0.06, 0.06)), wood, Vector3(0.2, 1.75, 0))
	var bulb := MeshKit.part(n, MeshKit.sphere(0.14, 10, 6), Toon.glow(Color("#ffd27a"), 2.0), Vector3(0.4, 1.55, 0))
	bulb.name = "Bulb"


func _smoke_particles() -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = 12
	p.lifetime = 4.0
	p.direction = Vector3(0.3, 1, 0)
	p.spread = 12.0
	p.initial_velocity_min = 0.5
	p.initial_velocity_max = 0.9
	p.gravity = Vector3(0.15, 0.05, 0)
	p.scale_amount_min = 0.3
	p.scale_amount_max = 0.6
	var curve := Curve.new()
	curve.add_point(Vector2(0, 0.4))
	curve.add_point(Vector2(1, 1.6))
	p.scale_amount_curve = curve
	var m := SphereMesh.new()
	m.radius = 0.5
	m.height = 1.0
	m.radial_segments = 8
	m.rings = 4
	m.material = Toon.translucent(Color("#e9e4f2"), 0.45)
	p.mesh = m
	return p


func _fire_particles(c: Color) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = 18
	p.lifetime = 0.8
	p.direction = Vector3.UP
	p.spread = 15.0
	p.initial_velocity_min = 0.6
	p.initial_velocity_max = 1.2
	p.gravity = Vector3(0, 0.5, 0)
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.25
	p.scale_amount_min = 0.12
	p.scale_amount_max = 0.25
	var curve := Curve.new()
	curve.add_point(Vector2(0, 1))
	curve.add_point(Vector2(1, 0))
	p.scale_amount_curve = curve
	var m := SphereMesh.new()
	m.radius = 0.5
	m.height = 1.0
	m.radial_segments = 6
	m.rings = 3
	m.material = Toon.glow(c, 2.5)
	p.mesh = m
	return p


func _bubble_particles() -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = 10
	p.lifetime = 1.2
	p.direction = Vector3.UP
	p.spread = 30.0
	p.initial_velocity_min = 0.3
	p.initial_velocity_max = 0.6
	p.gravity = Vector3.ZERO
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.45
	p.scale_amount_min = 0.06
	p.scale_amount_max = 0.14
	var m := SphereMesh.new()
	m.radius = 0.5
	m.height = 1.0
	m.radial_segments = 8
	m.rings = 4
	m.material = Toon.glow(Color("#b6ffcf"), 1.2)
	p.mesh = m
	return p


# ===================================================================== pontos de interesse

func _build_pois() -> void:
	var stone := Toon.mat(Color("#9a96a8"), {"surface": "stone", "outline": 0.025})
	var wood := Toon.mat(Color("#8a5a36"), {"surface": "wood", "outline": 0.02})
	var thatch := Toon.mat(Color("#d9b56a"), {"rim": 0.3, "outline": 0.03})

	# --- Casa de chá de Sálvia
	var hut := MeshKit.pivot(root, at(-23, 17))
	MeshKit.part(hut, MeshKit.cylinder(2.2, 2.3, 2.6, 16), Toon.mat(Color("#e8d6b0"), {"outline": 0.025}), Vector3(0, 1.3, 0))
	MeshKit.part(hut, MeshKit.cylinder(0.2, 3.1, 2.2, 16), thatch, Vector3(0, 3.6, 0))
	MeshKit.part(hut, MeshKit.box(Vector3(1.1, 1.9, 0.2)), Toon.mat(Color("#5f7f4a"), {"outline": 0.02}), Vector3(0.8, 0.95, 2.1), Vector3(0, 20, 0))
	MeshKit.part(hut, MeshKit.cylinder(0.45, 0.45, 0.1, 14), Toon.glow(Color("#ffd27a"), 1.3), Vector3(-1.2, 1.7, 1.8), Vector3(90, -30, 0))
	MeshKit.light(hut, Color("#ffcf8a"), 1.0, 6.0, Vector3(0.5, 2.0, 3.0))
	_cyl_collider(hut.position, 2.3, 3.0)
	var hut_door := Station.new()
	hut_door.setup("door", {"room": "cha", "title": "Casa de Chá da Vovó Sálvia"})
	_add(hut_door, at(-22.2, 19.8))
	outside_doors["cha"] = at(-21.8, 21.2, 0.1)
	var table := MeshKit.pivot(root, at(-18.5, 22.2))
	MeshKit.part(table, MeshKit.cylinder(0.7, 0.7, 0.08, 14), wood, Vector3(0, 0.75, 0))
	MeshKit.part(table, MeshKit.cylinder(0.08, 0.1, 0.75, 6), wood, Vector3(0, 0.37, 0))
	MeshKit.part(table, MeshKit.sphere(0.16, 10, 8), Toon.mat(Color("#7fb0d8"), {"outline": 0.01}), Vector3(0, 0.92, 0), Vector3.ZERO, Vector3(1.0, 0.8, 1.0))
	MeshKit.part(table, MeshKit.capsule(0.03, 0.18), Toon.mat(Color("#7fb0d8")), Vector3(0.18, 0.95, 0), Vector3(0, 0, 50))
	var steam := _smoke_particles()
	steam.amount = 5
	steam.scale_amount_min = 0.06
	steam.scale_amount_max = 0.12
	steam.position = Vector3(0, 1.1, 0)
	table.add_child(steam)

	# --- Carroça do Bento
	var cart := MeshKit.pivot(root, at(11.2, 16.6))
	cart.rotation_degrees.y = -20
	MeshKit.part(cart, MeshKit.box(Vector3(2.6, 0.9, 1.5)), wood, Vector3(0, 0.95, 0))
	for p in [Vector3(-0.9, 0.45, 0.8), Vector3(0.9, 0.45, 0.8), Vector3(-0.9, 0.45, -0.8), Vector3(0.9, 0.45, -0.8)]:
		MeshKit.part(cart, MeshKit.cylinder(0.45, 0.45, 0.12, 12), Toon.mat(Color("#5a3d2a"), {"surface": "wood", "outline": 0.02}), p, Vector3(90, 0, 0))
	for k in 5:
		MeshKit.part(cart, MeshKit.box(Vector3(0.52, 0.06, 1.7)), Toon.mat(Color("#e8574a") if k % 2 == 0 else Color("#fff3e0"), {"outline": 0.015}), Vector3(-1.04 + k * 0.52, 2.5, 0), Vector3(12, 0, 0))
	for p in [Vector3(-1.2, 1.25, 0.8), Vector3(1.2, 1.25, 0.8)]:
		MeshKit.part(cart, MeshKit.cylinder(0.05, 0.05, 2.5, 6), wood, p + Vector3(0, 0.6, -0.8))
	for k in 4:
		MeshKit.part(cart, MeshKit.sphere(0.2, 8, 6), Toon.mat([Color("#ff7a3c"), Color("#f5b335"), Color("#b18cff"), Color("#6fd38a")][k], {"rim": 0.4}), Vector3(-0.8 + k * 0.5, 1.55, -0.4))
	_box_collider(cart.position + Vector3(0, 1.0, 0), Vector3(2.8, 2.0, 1.7), deg_to_rad(-20))

	# --- Acampamento de Mirela
	var camp := MeshKit.pivot(root, at(23.5, 7.5))
	camp.rotation_degrees.y = -35
	MeshKit.part(camp, MeshKit.prism(Vector3(3.0, 2.2, 3.4)), Toon.mat(Color("#e07a2f"), {"rim": 0.3, "outline": 0.03}), Vector3(0, 1.1, 0))
	MeshKit.part(camp, MeshKit.prism(Vector3(1.4, 1.2, 0.1)), Toon.mat(Color("#5a3a2a"), {"surface": "wood"}), Vector3(0, 0.6, -1.72))
	var mc := MeshKit.pivot(root, at(19.4, 4.2))
	MeshKit.part(mc, MeshKit.sphere(0.45, 12, 8), Toon.mat(Color("#2a2433"), {"outline": 0.02}), Vector3(0, 0.45, 0), Vector3.ZERO, Vector3(1.0, 0.8, 1.0))
	MeshKit.part(mc, MeshKit.cylinder(0.36, 0.36, 0.04, 12), Toon.glow(Color("#ff9a3c"), 1.5), Vector3(0, 0.78, 0))
	MeshKit.light(mc, Color("#ff9a3c"), 1.0, 4.0, Vector3(0, 1.2, 0))
	var mf := _fire_particles(Color("#ff7a3c"))
	mc.add_child(mf)
	for k in 3:
		MeshKit.part(root, MeshKit.box(Vector3(0.6, 0.5, 0.6)), wood, at(25.5 + k * 0.7, 4.0 - k * 0.4, 0.25), Vector3(0, k * 20, 0))
	_box_collider(camp.position + Vector3(0, 1.0, 0), Vector3(3.0, 2.2, 3.4), deg_to_rad(-35))
	var tabua := Readable.new()
	tabua.setup("tabua_viajante", "sign")
	_add(tabua, at(26.0, 0.2), -70)

	# --- Passagem resmungona: pedras grandes ladeando
	for p in [Vector2(28.5, -7.6), Vector2(28.5, -0.4)]:
		MeshKit.part(root, MeshKit.rock(3, 1.0), stone, at(p.x, p.y, 0.8), Vector3.ZERO, Vector3(2.0, 2.8, 2.0))

	# --- Santuário do Fogo Paciente
	var shrine := MeshKit.pivot(root, at(44.5, -11))
	MeshKit.part(shrine, MeshKit.box(Vector3(2.4, 0.4, 2.4)), stone, Vector3(0, 0.2, 0))
	MeshKit.part(shrine, MeshKit.box(Vector3(1.0, 1.0, 1.0)), stone, Vector3(0, 0.9, 0))
	for k in 4:
		var a := k * TAU / 4.0 + 0.78
		var cnd := MeshKit.pivot(shrine, Vector3(sin(a) * 1.0, 0.4, cos(a) * 1.0))
		MeshKit.part(cnd, MeshKit.cylinder(0.07, 0.07, 0.35, 8), Toon.mat(Color("#fff3e0")), Vector3(0, 0.17, 0))
		var fl := _fire_particles(Color("#7fd6ff"))
		fl.amount = 6
		fl.scale_amount_min = 0.05
		fl.scale_amount_max = 0.09
		fl.position = Vector3(0, 0.4, 0)
		cnd.add_child(fl)
	MeshKit.light(shrine, Color("#7fd6ff"), 1.2, 5.0, Vector3(0, 1.8, 0))
	var p3 := Readable.new()
	p3.setup("ondina_3", "book")
	_add(p3, at(44.5, -11, 1.4))

	# --- Árvore do Guardião: mancha cinza ao redor (some quando purificado)
	corruption = MeshKit.part(root, MeshKit.cylinder(11.0, 11.0, 0.05, 32), Toon.translucent(Color("#7b7a80"), 0.55), at(0, -37, 0.12), Vector3.ZERO, Vector3.ONE, false)
	corruption.name = "Corruption"
	var diary := Readable.new()
	diary.setup("diario_ondina", "book", "diario_visivel")
	_add(diary, at(3.2, -34.0, 0.2))

	# --- Portal das Ruínas
	var portal := Station.new()
	portal.setup("portal", {"title": "Portal das Ruínas"})
	_add(portal, at(-15.5, -44.5), 30)
	portal.map_label = "Portal"
	for sx in [-1.0, 1.0]:
		MeshKit.part(portal, MeshKit.box(Vector3(0.9, 5.0, 0.9)), stone, Vector3(sx * 2.2, 2.5, 0))
		for k in 3:
			MeshKit.part(portal, MeshKit.box(Vector3(0.5, 0.3, 0.05)), Toon.glow(Color("#c9a5ff"), 1.2), Vector3(sx * 2.2, 1.2 + k * 1.2, -0.47))
	MeshKit.part(portal, MeshKit.box(Vector3(5.6, 0.9, 1.0)), stone, Vector3(0, 5.2, 0))
	MeshKit.part(portal, MeshKit.box(Vector3(3.5, 4.7, 0.05)), Toon.translucent(Color("#c9a5ff"), 0.3, 0.8), Vector3(0, 2.4, 0))
	_box_collider(portal.position + Vector3(0, 2.5, 0), Vector3(5.6, 5.0, 1.0), deg_to_rad(30))

	# --- Salgueiro Oco
	_willow(Vector2(-28.5, 4.0))
	var carving := Readable.new()
	carving.setup("inscricao_salgueiro", "carving")
	_add(carving, at(-27.4, 2.6, 0.0), 40)

	# --- Círculo de Pedras (topo da colina)
	var circle := MeshKit.pivot(root, at(19, -24))
	for k in 7:
		var a := k * TAU / 7.0
		var hh := 2.4 + (k % 3) * 0.5
		MeshKit.part(circle, MeshKit.box(Vector3(0.9, hh, 0.6)), stone, Vector3(sin(a) * 4.2, hh * 0.5, cos(a) * 4.2), Vector3(0, rad_to_deg(a), (k % 2) * 4 - 2))
		_cyl_collider(circle.position + Vector3(sin(a) * 4.2, 0, cos(a) * 4.2), 0.55, hh)
	MeshKit.part(circle, MeshKit.cylinder(1.0, 1.2, 0.6, 12), stone, Vector3(0, 0.3, 0))
	var runes := Readable.new()
	runes.setup("runas_circulo", "stone")
	_add(runes, at(19 + sin(2 * TAU / 7.0) * 3.2, -24 + cos(2 * TAU / 7.0) * 3.2), rad_to_deg(2 * TAU / 7.0) + 180)

	# --- Recanto do Gelo (além do riacho)
	var ice := MeshKit.pivot(root, at(41, 26))
	for k in 5:
		MeshKit.part(ice, MeshKit.crystal(0.35 + k * 0.1), Toon.mat(Color("#cfeeff"), {"rim": 0.6, "emission": 0.3, "outline": 0.02}), Vector3(sin(k * 1.3) * 1.4, 0.6 + k * 0.15, cos(k * 1.3) * 1.4), Vector3(0, k * 40, (k - 2) * 10))
	MeshKit.light(ice, Color("#bfe9ff"), 1.0, 5.0, Vector3(0, 1.5, 0))
	var pgelo := Readable.new()
	pgelo.setup("folha_gelo", "scroll")
	_add(pgelo, at(39.0, 24.0))

	# --- Ilhota da lagoa (alcançável só com gelo)
	var islet := Readable.new()
	islet.setup("ondina_5", "book")
	_add(islet, at(ValleyTerrain.POND_CENTER.x - 0.6, ValleyTerrain.POND_CENTER.y + 0.4, 0.1))

	# --- Bosque das Corujas
	var p4 := Readable.new()
	p4.setup("ondina_4", "scroll")
	_add(p4, at(-38.5, -35.0))
	for p in [Vector3(-34, 0, -30), Vector3(-40, 0, -31), Vector3(-37, 0, -38)]:
		_owl(at(p.x, p.z, 3.2))

	# --- Obstáculos
	var bramble := Obstacle.new()
	bramble.setup("sarca_oeste", "bramble", 5.0)
	_add(bramble, at(-26.0, -21.5))
	var bridge := Obstacle.new()
	bridge.setup("ponte_vinhas", "vine_bridge", 7.0)
	var bz := 22.0
	var bx := 30.0 + sin(bz * 0.15) * 2.0
	_add(bridge, Vector3(bx, ValleyTerrain.CREEK_LEVEL + 0.4, bz))

	# --- Marcas estelares
	var marks := [Vector2(-25.0, 9.0), Vector2(25.5, 13.0), Vector2(5.5, -28.0)]
	for i in marks.size():
		var m := StarMark.new()
		m.setup(i + 1)
		_add(m, at(marks[i].x, marks[i].y), rng.randf_range(0, 360))

	# --- Placas para regiões futuras
	var signs := [
		[Vector2(-84.0, -8.0), "floresta_encantada", "", ""],
		[Vector2(44.0, -76.0), "picos_lua", "", ""],
		[Vector2(-58.0, 60.0), "lagoa_espelhada", "", ""],
		[Vector2(-6.0, 88.0), "estrada", "Estrada do Reino", "A estrada continua para além das montanhas, até cidades que Asterion só conhece de livros. (Região futura.)"],
	]
	for s in signs:
		var st := Station.new()
		var title: String = s[2]
		var text: String = s[3]
		if title == "" and s[1] != "estrada":
			var reg := DataRegistry.region(s[1])
			title = reg.get("name", "")
			text = "%s\n\n%s\nFoco: %s.\n\n(Região planejada para a V1 — ainda não aberta nesta demonstração.)" % [title, reg.get("mood", ""), reg.get("focus", "")]
		st.setup("sign", {"title": title, "text": text})
		_add(st, at(s[0].x, s[0].y), rng.randf_range(-20, 20))
		var post := MeshKit.pivot(st)
		MeshKit.part(post, MeshKit.cylinder(0.07, 0.09, 2.0, 6), wood, Vector3(0, 1.0, 0))
		MeshKit.part(post, MeshKit.box(Vector3(1.4, 0.4, 0.08)), wood, Vector3(0.4, 1.7, 0), Vector3(0, 0, 4))
		MeshKit.part(post, MeshKit.prism(Vector3(0.4, 0.4, 0.08)), wood, Vector3(1.25, 1.7, 0), Vector3(0, 0, -90))


# ===================================================================== Aldeia Vime

func _house(c: Vector2, rot: float, w: float, d: float, wall_c: Color, roof_c: Color, room: String = "", title: String = "") -> Node3D:
	var base := at(c.x, c.y)
	var hn := Node3D.new()
	hn.position = base
	hn.rotation_degrees.y = rot
	root.add_child(hn)
	_house_body(hn, w, d, wall_c, roof_c)
	MeshKit.batch(hn)
	var cs := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = Vector3(w + 0.3, 4.0, d + 0.3)
	cs.shape = b
	cs.position = base + Vector3(0, 2.0, 0)
	cs.rotation_degrees.y = rot
	static_body.add_child(cs)
	if room != "":
		var door := Station.new()
		door.setup("door", {"room": room, "title": title})
		var front := Vector3(0, 0, d * 0.5 + 0.7).rotated(Vector3.UP, deg_to_rad(rot))
		door.position = base + front
		door.map_label = title
		root.add_child(door)
		var out := Vector3(0, 0, d * 0.5 + 1.8).rotated(Vector3.UP, deg_to_rad(rot))
		outside_doors[room] = at(base.x + out.x, base.z + out.z, 0.1)
	return hn


## Casa em enxaimel: fundação de pedra, vigas aparentes com mãos-francesas, janelas
## com moldura, cruz, peitoril, floreira e venezianas, porta de tábuas, telhado com
## espessura, beiral e fiadas de telhas, oitões, cumeeira e chaminé de pedra.
func _house_body(hn: Node3D, w: float, d: float, wall_c: Color, roof_c: Color) -> void:
	var wall := Toon.mat(wall_c, {"surface": "plaster"})
	var timber := Toon.mat(Color("#5e3d28"), {"surface": "wood"})
	var stone := Toon.mat(Color("#8e8a86"), {"surface": "stone"})
	var roof := Toon.mat(roof_c, {"surface": "roof"})
	var roof_dark := Toon.mat(roof_c.darkened(0.25), {"surface": "roof"})
	var top := 3.0
	MeshKit.part(hn, MeshKit.box(Vector3(w + 0.3, 0.5, d + 0.3)), stone, Vector3(0, 0.05, 0))
	MeshKit.part(hn, MeshKit.box(Vector3(w, top - 0.3, d)), wall, Vector3(0, 0.3 + (top - 0.3) * 0.5, 0))
	# vigas horizontais (soleira, meio e frechal) nos quatro lados
	for y in [0.36, 1.35, top - 0.08]:
		for sz: float in [-1.0, 1.0]:
			MeshKit.part(hn, MeshKit.box(Vector3(w + 0.16, 0.16, 0.12)), timber, Vector3(0, y, sz * (d * 0.5 + 0.03)))
		for sx: float in [-1.0, 1.0]:
			MeshKit.part(hn, MeshKit.box(Vector3(0.12, 0.16, d + 0.16)), timber, Vector3(sx * (w * 0.5 + 0.03), y, 0))
	# montantes e mãos-francesas
	var n_posts := maxi(2, int(w / 1.3))
	for i in n_posts + 1:
		var x := -w * 0.5 + w * float(i) / float(n_posts)
		for sz: float in [-1.0, 1.0]:
			MeshKit.part(hn, MeshKit.box(Vector3(0.14, top - 0.3, 0.12)), timber, Vector3(x, 0.3 + (top - 0.3) * 0.5, sz * (d * 0.5 + 0.035)))
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			MeshKit.part(hn, MeshKit.box(Vector3(0.1, 1.5, 0.1)), timber, Vector3(sx * (w * 0.5 - 0.45), 2.15, sz * (d * 0.5 + 0.04)), Vector3(0, 0, sx * 35.0))
		for zz in [-d * 0.3, d * 0.3]:
			MeshKit.part(hn, MeshKit.box(Vector3(0.12, top - 0.3, 0.14)), timber, Vector3(sx * (w * 0.5 + 0.035), 0.3 + (top - 0.3) * 0.5, zz))
	# janelas (frente e fundos)
	var glass := Toon.mat(Color("#2a3440"), {"surface": "ceramic", "roughness": 0.08})
	var shutter := Toon.mat(roof_c.darkened(0.35).lerp(Color("#3f5a3a"), 0.3), {"surface": "wood"})
	var flower_cols := [Color("#ff7a9a"), Color("#fff3a0"), Color("#c8a2ff"), Color("#ff9a5a")]
	for sz: float in [-1.0, 1.0]:
		for wx in [-w * 0.3, w * 0.3]:
			var wz: float = sz * (d * 0.5 + 0.05)
			var win := MeshKit.pivot(hn, Vector3(wx, 1.95, wz))
			win.rotation_degrees.y = 0.0 if sz > 0.0 else 180.0
			MeshKit.part(win, MeshKit.box(Vector3(0.78, 0.82, 0.04)), glass, Vector3(0, 0, -0.02))
			MeshKit.part(win, MeshKit.box(Vector3(0.74, 0.78, 0.02)), Toon.glow(Color("#ffcf7a"), 0.35), Vector3(0, 0, -0.035))
			for e in [[Vector3(0.96, 0.1, 0.1), Vector3(0, 0.46, 0)], [Vector3(1.0, 0.12, 0.16), Vector3(0, -0.46, 0.03)], [Vector3(0.1, 0.9, 0.1), Vector3(-0.44, 0, 0)], [Vector3(0.1, 0.9, 0.1), Vector3(0.44, 0, 0)], [Vector3(0.05, 0.8, 0.05), Vector3(0, 0, 0.01)], [Vector3(0.78, 0.05, 0.05), Vector3(0, 0.05, 0.01)]]:
				MeshKit.part(win, MeshKit.box(e[0]), timber, e[1])
			for side: float in [-1.0, 1.0]:
				MeshKit.part(win, MeshKit.box(Vector3(0.36, 0.86, 0.04)), shutter, Vector3(side * 0.66, 0, 0.0), Vector3(0, side * 12.0, 0))
			MeshKit.part(win, MeshKit.box(Vector3(0.9, 0.18, 0.2)), timber, Vector3(0, -0.6, 0.1))
			for k in 5:
				MeshKit.part(win, MeshKit.sphere(0.07, 8, 6), Toon.mat(flower_cols[(k + int(wx * 3.0)) % flower_cols.size()], {"surface": "leaf"}), Vector3(-0.32 + k * 0.16, -0.47, 0.12))
	# porta de tábuas com batente, maçaneta e degrau
	var door_n := MeshKit.pivot(hn, Vector3(0, 0, d * 0.5 + 0.05))
	for k in 4:
		MeshKit.part(door_n, MeshKit.box(Vector3(0.27, 1.95, 0.08)), Toon.mat(roof_c.darkened(0.45).lerp(Color("#6b4630"), 0.5), {"surface": "wood"}), Vector3(-0.41 + k * 0.275, 1.27, 0.0))
	MeshKit.part(door_n, MeshKit.box(Vector3(1.32, 0.14, 0.14)), timber, Vector3(0, 2.3, 0.02))
	for sx: float in [-1.0, 1.0]:
		MeshKit.part(door_n, MeshKit.box(Vector3(0.14, 2.1, 0.14)), timber, Vector3(sx * 0.62, 1.25, 0.02))
	MeshKit.part(door_n, MeshKit.sphere(0.04, 10, 8), Toon.mat(Color("#c9a24a"), {"metal": 0.8}), Vector3(0.36, 1.2, 0.07))
	MeshKit.part(door_n, MeshKit.box(Vector3(1.4, 0.18, 0.6)), stone, Vector3(0, 0.12, 0.3))
	# oitões (paredes triangulares) com viga em X
	var pitch := deg_to_rad(38.0)
	var rise := d * 0.5 * tan(pitch)
	for sx: float in [-1.0, 1.0]:
		MeshKit.part(hn, MeshKit.prism(Vector3(d, rise, w * 0.02 + 0.2)), wall, Vector3(sx * (w * 0.5 - 0.1), top + rise * 0.5, 0), Vector3(0, 90, 0))
		MeshKit.part(hn, MeshKit.box(Vector3(0.1, rise * 1.1, 0.1)), timber, Vector3(sx * (w * 0.5 + 0.02), top + rise * 0.45, 0))
	# telhado: placa com espessura + fiadas de telhas sobrepostas + cumeeira
	var slope_len := (d * 0.5 + 0.55) / cos(pitch)
	for sz: float in [-1.0, 1.0]:
		var dir := Vector3(0, -sin(pitch), sz * cos(pitch))
		var ridge := Vector3(0, top + rise + 0.12, 0)
		var nrm := Vector3(0, cos(pitch), sz * sin(pitch))
		var slab := MeshKit.part(hn, MeshKit.box(Vector3(w + 0.9, 0.12, slope_len)), roof_dark, ridge + dir * slope_len * 0.5, Vector3(sz * rad_to_deg(pitch), 0, 0))
		slab.name = "Roof"
		var rows := 7
		for k in rows:
			var t := (float(k) + 0.6) / float(rows)
			var rp := ridge + dir * slope_len * t + nrm * 0.08
			MeshKit.part(hn, MeshKit.box(Vector3(w + 0.95, 0.06, slope_len / rows * 1.22)), roof if k % 2 == 0 else Toon.mat(roof_c.darkened(0.08), {"surface": "roof"}), rp, Vector3(sz * (rad_to_deg(pitch) + 4.0), 0, 0))
	var ridge_beam := MeshKit.part(hn, MeshKit.cylinder(0.11, 0.11, w + 1.0, 12), roof_dark, Vector3(0, top + rise + 0.2, 0), Vector3(0, 0, 90))
	ridge_beam.name = "Ridge"
	# chaminé de pedra com coroa
	var ch := MeshKit.pivot(hn, Vector3(w * 0.28, top + rise * 0.6, -d * 0.22))
	ch.name = "Chimney"
	MeshKit.part(ch, MeshKit.box(Vector3(0.6, 2.0, 0.6)), stone, Vector3(0, 0.5, 0))
	MeshKit.part(ch, MeshKit.box(Vector3(0.74, 0.14, 0.74)), stone, Vector3(0, 1.56, 0))
	MeshKit.part(ch, MeshKit.box(Vector3(0.36, 0.1, 0.36)), Toon.mat(Color("#2a2420"), {"surface": "stone"}), Vector3(0, 1.62, 0))


func _build_village() -> void:
	var walls := [Color("#f1e3c6"), Color("#e8d0b0"), Color("#f6e6d0"), Color("#e6dcc8")]
	var roofs := [Color("#c4673a"), Color("#5a7f4a"), Color("#7a4f9c"), Color("#3a6a8a")]
	_house(Vector2(-12.0, 64.0), 70.0, 6.0, 5.0, Color("#f6e6d0"), Color("#d9984a"), "padaria", "Padaria Pão-de-Mel")
	var signboard := MeshKit.pivot(root, at(-8.6, 62.0))
	MeshKit.part(signboard, MeshKit.cylinder(0.05, 0.06, 2.2, 6), Toon.mat(Color("#6b4630"), {"surface": "wood"}), Vector3(0, 1.1, 0))
	MeshKit.part(signboard, MeshKit.sphere(0.45, 12, 8), Toon.mat(Color("#e8a94a"), {"outline": 0.02}), Vector3(0, 2.4, 0), Vector3.ZERO, Vector3(1.2, 0.7, 0.3))
	var spots := [[Vector2(12, 63), -60.0], [Vector2(14, 78), -110.0], [Vector2(-13, 80), 110.0], [Vector2(2, 89), 180.0], [Vector2(-22, 72), 90.0]]
	for i in spots.size():
		_house(spots[i][0], spots[i][1], 5.0 + (i % 2), 4.5, walls[i % walls.size()], roofs[i % roofs.size()])
	# poço da praça
	var well := MeshKit.pivot(root, at(0.5, 70.0))
	MeshKit.part(well, MeshKit.cylinder(1.0, 1.1, 0.9, 16), Toon.mat(Color("#9a96a8"), {"surface": "stone", "outline": 0.02}), Vector3(0, 0.45, 0))
	MeshKit.part(well, MeshKit.cylinder(0.85, 0.85, 0.05, 16), Toon.mat(Color("#3a6a8a"), {"emission": 0.2}), Vector3(0, 0.8, 0))
	for sx in [-1.0, 1.0]:
		MeshKit.part(well, MeshKit.cylinder(0.07, 0.07, 1.8, 6), Toon.mat(Color("#6b4630"), {"surface": "wood", "outline": 0.015}), Vector3(sx * 0.9, 1.4, 0))
	MeshKit.part(well, MeshKit.prism(Vector3(2.4, 0.7, 1.4)), Toon.mat(Color("#c4673a"), {"outline": 0.02}), Vector3(0, 2.6, 0))
	_cyl_collider(well.position, 1.1, 1.0)
	var placa := Readable.new()
	placa.setup("placa_aldeia", "sign")
	_add(placa, at(5.0, 62.0), 200)
	# barraca de feira
	var stall := MeshKit.pivot(root, at(-6.0, 77.0))
	stall.rotation_degrees.y = 30
	MeshKit.part(stall, MeshKit.box(Vector3(2.4, 0.9, 1.0)), Toon.mat(Color("#8a5a36"), {"outline": 0.02}), Vector3(0, 0.45, 0))
	for k in 4:
		MeshKit.part(stall, MeshKit.box(Vector3(0.62, 0.06, 1.4)), Toon.mat(Color("#e8574a") if k % 2 == 0 else Color("#fff3e0"), {"outline": 0.015}), Vector3(-0.93 + k * 0.62, 2.2, 0.1), Vector3(14, 0, 0))
	for k in 5:
		MeshKit.part(stall, MeshKit.sphere(0.16, 8, 6), Toon.mat([Color("#ff7a3c"), Color("#e8322e"), Color("#8fcf5a"), Color("#f5b335"), Color("#b18cff")][k], {"rim": 0.4}), Vector3(-0.8 + k * 0.4, 1.05, 0))
	_box_collider(stall.position + Vector3(0, 0.5, 0), Vector3(2.4, 1.0, 1.0), deg_to_rad(30))
	# cercas e lanternas
	for k in 10:
		MeshKit.part(root, MeshKit.box(Vector3(0.12, 0.8, 0.12)), Toon.mat(Color("#8a5a36"), {"outline": 0.015}), at(-20.0 + k * 1.1, 55.0, 0.3))
	for p in [Vector2(-4, 66), Vector2(6, 67), Vector2(-3, 76), Vector2(7, 76)]:
		_lantern(p)


# ===================================================================== áreas distantes

func _build_far_areas() -> void:
	var stone := Toon.mat(Color("#a8a4b8"), {"surface": "stone", "outline": 0.025})
	# Campos de Lavanda: fileiras roxas, colmeias e moinho
	var lav_t: Array = []
	var lav_c: Array = []
	for row in 9:
		for k in 22:
			var x := 48.0 + k * 0.9 + rng.randf_range(-0.2, 0.2)
			var z := 36.0 + row * 1.6
			if Vector2(x, z).distance_to(Vector2(58, 44)) > 12.5 or terrain.dist_to_path(x, z) < 1.4:
				continue
			var sc := rng.randf_range(0.8, 1.2)
			lav_t.append(Transform3D(Basis().scaled(Vector3(sc, sc * 1.3, sc)), at(x, z, 0.3)))
			lav_c.append(Color("#9a6ad8").lerp(Color("#c8a2ff"), rng.randf()))
	_multimesh(MeshKit.sphere(0.38, 8, 6), Toon.foliage(), lav_t, lav_c)
	for p in [Vector2(52, 50), Vector2(54, 51), Vector2(56, 52.5)]:
		var hive := MeshKit.pivot(root, at(p.x, p.y))
		for k in 3:
			MeshKit.part(hive, MeshKit.cylinder(0.35 - k * 0.07, 0.4 - k * 0.07, 0.3, 10), Toon.mat(Color("#e8c66a"), {"outline": 0.015}), Vector3(0, 0.15 + k * 0.28, 0))
		MeshKit.part(hive, MeshKit.sphere(0.07, 6, 4), Toon.mat(Color("#2a1d18")), Vector3(0, 0.3, -0.38))
	var bees := HarvestNode.new()
	bees.setup("colmeia_1", "mel_silvestre", "crystal", 1)
	_add(bees, at(54.0, 49.0))
	var lav_node := HarvestNode.new()
	lav_node.setup("lavanda_campo", "lavanda_sonolenta", "spikes", 2)
	_add(lav_node, at(60.0, 39.0))
	var mill := MeshKit.pivot(root, at(64.0, 50.0))
	mill.name = "Windmill"
	MeshKit.part(mill, MeshKit.cylinder(1.4, 2.1, 7.0, 10), Toon.mat(Color("#f1e3c6"), {"rim": 0.2, "outline": 0.03}), Vector3(0, 3.5, 0))
	MeshKit.part(mill, MeshKit.cylinder(0.2, 1.9, 1.8, 10), Toon.mat(Color("#c4673a"), {"outline": 0.03}), Vector3(0, 7.9, 0))
	var blades := MeshKit.pivot(mill, Vector3(0, 6.6, -1.7))
	blades.name = "Blades"
	blades.add_to_group("windmill_blades")
	for k in 4:
		var bl := MeshKit.pivot(blades)
		bl.rotation.z = k * PI / 2.0
		MeshKit.part(bl, MeshKit.box(Vector3(0.9, 3.4, 0.08)), Toon.mat(Color("#f6efe2"), {"outline": 0.02}), Vector3(0, 2.0, 0))
	MeshKit.part(blades, MeshKit.sphere(0.35, 10, 8), Toon.mat(Color("#6b4630"), {"surface": "wood"}))
	_cyl_collider(mill.position, 2.0, 7.0)
	# Observatório em ruínas
	var obs := MeshKit.pivot(root, at(62.0, -48.0))
	for k in 10:
		var a := k * TAU / 10.0
		if k in [2, 7]:
			continue
		var hh := 3.0 + (k % 3) * 1.4
		MeshKit.part(obs, MeshKit.box(Vector3(1.4, hh, 0.7)), stone, Vector3(sin(a) * 5.5, hh * 0.5, cos(a) * 5.5), Vector3(0, rad_to_deg(a), (k % 2) * 6 - 3))
		_cyl_collider(obs.position + Vector3(sin(a) * 5.5, 0, cos(a) * 5.5), 0.7, hh)
	MeshKit.part(obs, MeshKit.sphere(5.6, 20, 10, true), Toon.mat(Color("#8a8796"), {"surface": "stone", "outline": 0.03, "double_sided": true}), Vector3(1.5, 5.0, 0), Vector3(0, 0, 38), Vector3(1.0, 0.5, 1.0))
	var scope := MeshKit.pivot(obs, Vector3(0, 0.8, 0))
	scope.rotation_degrees = Vector3(-35, 30, 0)
	MeshKit.part(obs, MeshKit.cylinder(0.3, 0.5, 0.8, 8), Toon.mat(Color("#c9a24a"), {"metal": 0.5, "outline": 0.02}), Vector3(0, 0.4, 0))
	MeshKit.part(scope, MeshKit.cylinder(0.22, 0.35, 3.2, 12), Toon.mat(Color("#c9a24a"), {"metal": 0.6, "rim": 0.5, "outline": 0.02}), Vector3(0, 1.6, 0))
	var obs_c := HarvestNode.new()
	obs_c.setup("observatorio_estrela", "po_estrela", "crystal", 1)
	_add(obs_c, at(64.0, -45.0))
	# Anel de Cogumelos (fadas)
	var ring := MeshKit.pivot(root, at(-62.0, -56.0))
	for k in 16:
		var a := k * TAU / 16.0
		var sc := 0.7 + (k % 3) * 0.25
		MeshKit.part(ring, MeshKit.cylinder(0.08 * sc, 0.11 * sc, 0.5 * sc, 8), Toon.mat(Color("#f3e6cf")), Vector3(sin(a) * 4.0, 0.25 * sc, cos(a) * 4.0))
		MeshKit.part(ring, MeshKit.sphere(0.32 * sc, 10, 6, true), Toon.mat(Color("#9fe8ff") if k % 2 == 0 else Color("#d6b8ff"), {"emission": 1.2, "outline": 0.01}), Vector3(sin(a) * 4.0, 0.48 * sc, cos(a) * 4.0), Vector3.ZERO, Vector3(1.0, 0.6, 1.0))
	MeshKit.light(ring, Color("#b6d8ff"), 1.5, 9.0, Vector3(0, 1.5, 0))
	var orq := HarvestNode.new()
	orq.setup("orquidea_anel", "orquidea_sombra", "flower", 1)
	_add(orq, at(-62.0, -56.0))
	# Pomar Abandonado: árvores secas (o Crescimento as faz florescer)
	for k in 9:
		var p := Vector2(-64.0 + (k % 3) * 6.0, 36.0 + int(k / 3.0) * 6.0)
		var prop := MagicProp.new()
		prop.setup("pomar_%d" % k, "dead_bush" if k % 2 == 0 else "stump")
		_add(prop, at(p.x, p.y))
		var trunk := MeshKit.pivot(root, at(p.x + 1.5, p.y + 1.2))
		MeshKit.part(trunk, MeshKit.cylinder(0.15, 0.25, 2.6, 7), Toon.mat(Color("#6b5a48"), {"surface": "wood", "outline": 0.02}), Vector3(0, 1.3, 0), Vector3(0, 0, 6))
		for b in 3:
			MeshKit.part(trunk, MeshKit.cylinder(0.03, 0.08, 1.2, 5), Toon.mat(Color("#6b5a48"), {"surface": "wood"}), Vector3(0, 2.4, 0), Vector3(b * 40 - 40, b * 120, 35))
	# Clareira dos Cogumelos Gigantes
	for k in 7:
		var a := k * TAU / 7.0 + 0.3
		var p := Vector2(-76.0 + sin(a) * 7.0, 4.0 + cos(a) * 7.0)
		var sc := rng.randf_range(1.5, 3.0)
		var mush := MeshKit.pivot(root, at(p.x, p.y))
		MeshKit.part(mush, MeshKit.cylinder(0.35 * sc, 0.5 * sc, 2.2 * sc, 12), Toon.mat(Color("#f3e6cf"), {"outline": 0.03}), Vector3(0, 1.1 * sc, 0))
		MeshKit.part(mush, MeshKit.sphere(1.3 * sc, 16, 10, true), Toon.mat([Color("#d9442f"), Color("#9a6ad8"), Color("#e8a94a")][k % 3], {"rim": 0.4, "outline": 0.04}), Vector3(0, 2.1 * sc, 0), Vector3.ZERO, Vector3(1.0, 0.65, 1.0))
		_cyl_collider(mush.position, 0.5 * sc, 2.2 * sc)
	for p in [Vector2(-74.0, 6.0), Vector2(-78.0, 1.0)]:
		var f := CreatureActor.new()
		f.setup("frog", Callable(terrain, "height"))
		_add(f, at(p.x, p.y))


## Objetos mágicos espalhados para experimentar feitiços.
func _build_magic_props() -> void:
	var props := [
		["casa_pedra_1", "rock", Vector2(4.0, 3.0)], ["casa_pedra_2", "rock", Vector2(-3.5, 6.0)],
		["casa_caixa_1", "crate", Vector2(3.6, -4.3)], ["casa_barril_1", "barrel", Vector2(4.7, -4.3)],
		["casa_abobora_1", "pumpkin", Vector2(-11.0, 6.8)], ["casa_abobora_2", "pumpkin", Vector2(-10.2, 7.6)],
		["casa_poca_1", "puddle", Vector2(1.5, 10.5)], ["casa_botao_1", "bud", Vector2(-2.0, 4.5)],
		["casa_botao_2", "bud", Vector2(5.5, 7.0)], ["casa_toco_1", "stump", Vector2(-13.0, -6.0)],
		["casa_lampiao_1", "lamp", Vector2(2.2, 2.2)], ["casa_lampiao_2", "lamp", Vector2(-2.2, 2.2)],
		["trilha_seco_1", "dead_bush", Vector2(-4.0, -16.0)], ["trilha_seco_2", "dead_bush", Vector2(3.0, -24.0)],
		["trilha_seco_3", "dead_bush", Vector2(-6.0, -30.0)], ["trilha_pedra_1", "rock", Vector2(-9.0, 14.0)],
		["trilha_poca_1", "puddle", Vector2(-17.0, 16.0)], ["mirela_barril", "barrel", Vector2(25.0, 9.5)],
		["mirela_caixa", "crate", Vector2(18.0, 9.0)], ["bento_caixa", "crate", Vector2(13.4, 18.0)],
		["bento_abobora", "pumpkin", Vector2(12.6, 14.6)], ["salgueiro_pedra", "rock", Vector2(-24.0, 6.0)],
		["lagoa_botao", "bud", Vector2(-23.5, -15.0)], ["circulo_pedra", "rock", Vector2(15.0, -20.0)],
		["aldeia_abobora_1", "pumpkin", Vector2(-18.0, 57.0)], ["aldeia_abobora_2", "pumpkin", Vector2(-16.5, 57.5)],
		["aldeia_abobora_3", "pumpkin", Vector2(-15.0, 56.8)], ["aldeia_barril_1", "barrel", Vector2(9.0, 66.5)],
		["aldeia_caixa_1", "crate", Vector2(10.0, 67.5)], ["aldeia_lampiao_1", "lamp", Vector2(-1.0, 64.0)],
		["aldeia_lampiao_2", "lamp", Vector2(4.0, 80.0)], ["aldeia_poca", "puddle", Vector2(-4.0, 72.0)],
		["aldeia_botao", "bud", Vector2(6.0, 73.0)], ["lavanda_pedra", "rock", Vector2(50.0, 40.0)],
		["lavanda_toco", "stump", Vector2(66.0, 40.0)], ["obs_pedra", "rock", Vector2(58.0, -44.0)],
		["obs_caixa", "crate", Vector2(66.0, -50.0)], ["fadas_botao", "bud", Vector2(-58.0, -52.0)],
		["cogumelos_pedra", "rock", Vector2(-72.0, 8.0)], ["santuario_seco", "dead_bush", Vector2(40.0, -12.0)],
	]
	for pr in props:
		var mp := MagicProp.new()
		mp.setup(pr[0], pr[1])
		var p: Vector2 = pr[2]
		_add(mp, at(p.x, p.y), rng.randf_range(0, 360))


func _willow(p: Vector2) -> void:
	var w := MeshKit.pivot(root, at(p.x, p.y))
	var bark := Toon.mat(Color("#6b5a42"), {"outline": 0.03})
	MeshKit.part(w, MeshKit.cylinder(0.6, 1.0, 3.6, 12), bark, Vector3(0, 1.8, 0))
	MeshKit.part(w, MeshKit.sphere(0.55, 10, 8), Toon.mat(Color("#2a1d18")), Vector3(0.4, 1.2, -0.75), Vector3.ZERO, Vector3(0.9, 1.4, 0.4))
	var leaf := Toon.mat(Color("#8fcf6a"), {"rim": 0.4, "outline": 0.03})
	MeshKit.part(w, MeshKit.sphere(2.6, 14, 8), leaf, Vector3(0, 4.6, 0), Vector3.ZERO, Vector3(1.2, 0.6, 1.2))
	var strand := Toon.mat(Color("#9ad46a"))
	for k in 22:
		var a := k * TAU / 22.0
		var r := 2.6 + (k % 3) * 0.3
		MeshKit.part(w, MeshKit.capsule(0.12, 2.6 + (k % 4) * 0.4), strand, Vector3(sin(a) * r, 3.2, cos(a) * r))
	_cyl_collider(w.position, 1.0, 3.5)


func _owl(pos: Vector3) -> void:
	var o := MeshKit.pivot(root, pos)
	var f := Toon.mat(Color("#f2f5ff"), {"rim": 0.5, "outline": 0.01})
	MeshKit.part(o, MeshKit.box(Vector3(1.2, 0.08, 0.08)), Toon.mat(Color("#5a3d2a"), {"surface": "wood"}), Vector3(0, -0.05, 0))
	MeshKit.part(o, MeshKit.sphere(0.22, 12, 8), f, Vector3(0, 0.22, 0), Vector3.ZERO, Vector3(1.0, 1.2, 0.9))
	for sx in [-1.0, 1.0]:
		MeshKit.part(o, MeshKit.sphere(0.07, 8, 6), Toon.glow(Color("#f3c74f"), 1.0), Vector3(sx * 0.08, 0.32, -0.16))
		MeshKit.part(o, MeshKit.sphere(0.03, 6, 4), Toon.mat(Color("#1a1420"), {"unshaded": true}), Vector3(sx * 0.08, 0.32, -0.21))
		MeshKit.part(o, MeshKit.cylinder(0.0, 0.05, 0.12, 4), f, Vector3(sx * 0.12, 0.47, 0), Vector3(0, 0, -sx * 20))


# ===================================================================== coletáveis

func _build_harvest_nodes() -> void:
	var nodes := [
		["folha_1", "folha_orvalho", "rosette", Vector2(-4.0, 9.0)],
		["folha_2", "folha_orvalho", "rosette", Vector2(4.5, 4.5)],
		["folha_3", "folha_orvalho", "rosette", Vector2(-11.0, 16.5)],
		["folha_4", "folha_orvalho", "rosette", Vector2(-16.0, 23.5)],
		["folha_5", "folha_orvalho", "rosette", Vector2(-12.0, -4.0)],
		["lucid_1", "petala_claridade", "flower", Vector2(10.0, 9.0)],
		["lucid_2", "petala_claridade", "flower", Vector2(-6.0, -12.0)],
		["lucid_3", "petala_claridade", "flower", Vector2(15.0, -12.0)],
		["lavanda_1", "lavanda_sonolenta", "spikes", Vector2(-15.0, 10.0)],
		["lavanda_2", "lavanda_sonolenta", "spikes", Vector2(13.0, 24.0)],
		["lavanda_3", "lavanda_sonolenta", "spikes", Vector2(-20.0, 27.0)],
		["musgo_1", "musgo_lunar", "moss", Vector2(-24.0, -9.0)],
		["musgo_2", "musgo_lunar", "moss", Vector2(-8.0, -30.0)],
		["cogu_1", "cogumelo_brasa", "mushroom", Vector2(-6.0, -20.0)],
		["cogu_2", "cogumelo_brasa", "mushroom", Vector2(16.0, -6.0)],
		["cogu_3", "cogumelo_brasa", "mushroom", Vector2(-35.0, -27.0)],
		["salgueiro_1", "casca_salgueiro", "bark", Vector2(-28.5, 5.2)],
		["fonte", "agua_manancial", "spring", Vector2(-25.0, 23.0)],
		["pedras_1", "pedra_comum", "stone", Vector2(27.0, 16.0)],
		["pedras_2", "pedra_comum", "stone", Vector2(-21.5, -11.0)],
		["cristal_santuario", "cristal_lunar", "crystal", Vector2(46.5, -8.0)],
		["cristal_ilhota", "cristal_lunar", "crystal", Vector2(ValleyTerrain.POND_CENTER.x + 0.8, ValleyTerrain.POND_CENTER.y - 0.6)],
		["trevo_1", "trevo_quatro", "clover", Vector2(-33.0, -36.0)],
		["trevo_2", "trevo_quatro", "clover", Vector2(-41.0, -28.0)],
		["pena_1", "pena_coruja", "feather", Vector2(-38.0, -30.5)],
		["aurora_1", "flor_aurora", "flower", Vector2(43.0, 22.5)],
		["raiz_1", "raiz_concentracao", "rosette", Vector2(36.0, 28.0)],
		["flocos_1", "flocos_neve", "crystal", Vector2(42.5, 27.5)],
	]
	for n in nodes:
		var hn := HarvestNode.new()
		hn.setup(n[0], n[1], n[2], 1)
		var p: Vector2 = n[3]
		_add(hn, at(p.x, p.y), rng.randf_range(0, 360))


# ===================================================================== NPCs e criaturas

func _build_npcs() -> void:
	for id in DataRegistry.region("vale_sussurros").get("npcs", []):
		var npc := NPCActor.new()
		npc.setup(id, Callable(terrain, "height"))
		npc.name = "NPC_" + id
		if id == "musgo":
			npc.rotation_degrees.y = 180
			_cyl_collider(at(0, -38), 1.6, 6.0)
		root.add_child(npc)


func _build_creatures() -> void:
	var mush := CreatureActor.new()
	mush.setup("mushroom", Callable(terrain, "height"))
	_add(mush, at(30.5, -4.0))
	for i in 7:
		var a := i * TAU / 7.0
		var w := CreatureActor.new()
		w.setup("wisp", Callable(terrain, "height"))
		_add(w, Vector3(ValleyTerrain.POND_CENTER.x + sin(a) * 4.5, ValleyTerrain.POND_LEVEL + 1.4, ValleyTerrain.POND_CENTER.y + cos(a) * 4.5))
	var fa := CreatureActor.new()
	fa.setup("faisca", Callable(terrain, "height"))
	_add(fa, Vector3(ValleyTerrain.POND_CENTER.x + 5.0, ValleyTerrain.POND_LEVEL + 1.6, ValleyTerrain.POND_CENTER.y + 4.0))
	for p in [Vector2(-23.0, -9.5), Vector2(-36.5, -9.0), Vector2(26.5, 18.0)]:
		var f := CreatureActor.new()
		f.setup("frog", Callable(terrain, "height"))
		_add(f, at(p.x, p.y), rng.randf_range(0, 360))


func _build_ambient() -> void:
	var cols := [Color("#ff9fb2"), Color("#fff3a0"), Color("#c8a2ff"), Color("#8fd6ff")]
	for p in [Vector2(-6, 8), Vector2(12, 10), Vector2(-14, 22), Vector2(-20, -2), Vector2(14, -10), Vector2(4, 22), Vector2(-30, 10), Vector2(-36, -32),
			Vector2(55, 40), Vector2(62, 46), Vector2(52, 44), Vector2(-58, 40), Vector2(-62, 46), Vector2(-4, 70), Vector2(8, 78), Vector2(-60, -54)]:
		var b := ButterflyModel.new()
		b.color = cols[rng.randi() % cols.size()]
		b.center = at(p.x, p.y)
		b.add_to_group("butterfly")
		b.position = b.center
		root.add_child(b)
