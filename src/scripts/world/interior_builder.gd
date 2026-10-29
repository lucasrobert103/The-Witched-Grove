class_name InteriorBuilder
extends RefCounted
## Mobília e interiores: Cabana da Clareira (casa da Asterion), Casa de Chá da Sálvia
## e Padaria da Dorinha. Cada cômodo é um InteriorRoom fora do mapa (x > 300).

const ORIGINS := {
	"cabana": Vector3(400, 0, 0),
	"cha": Vector3(400, 0, 60),
	"padaria": Vector3(460, 0, 0),
}

var root: Node3D
var wood := Toon.mat(Color("#8a5a36"), {"outline": 0.02})
var dark_wood := Toon.mat(Color("#5a3a26"), {"outline": 0.02})
var stone := Toon.mat(Color("#8f8b9c"), {"outline": 0.02})
var glow := Toon.glow(Color("#ffd27a"), 1.8)


func build_all(p_root: Node3D, outside_doors: Dictionary) -> Dictionary:
	root = p_root
	var rooms := {}
	rooms["cabana"] = _cabana(outside_doors.get("cabana", Vector3.ZERO))
	rooms["cha"] = _cha(outside_doors.get("cha", Vector3.ZERO))
	rooms["padaria"] = _padaria(outside_doors.get("padaria", Vector3.ZERO))
	return rooms


func _room(id: String, title: String, size: Vector3, floor_c: Color, wall_c: Color, outside: Vector3) -> InteriorRoom:
	var r := InteriorRoom.new()
	r.setup(id, title, size, floor_c, wall_c)
	r.position = ORIGINS[id]
	r.name = "Interior_" + id
	root.add_child(r)
	r.spawn = ORIGINS[id] + Vector3(0, 0.1, size.z * 0.5 - 1.3)
	r.exit_outside = outside
	# porta de saída na parede sul
	var door := Station.new()
	door.setup("door_exit", {"room": id, "title": title})
	door.position = Vector3(0, 0, size.z * 0.5 - 0.5)
	r.add_child(door)
	var s := r.wall_node("s")
	MeshKit.part(s, MeshKit.box(Vector3(1.2, 2.1, 0.08)), Toon.mat(Color("#7a3f5a"), {"outline": 0.02}), Vector3(0, 1.05, 0.06))
	MeshKit.part(s, MeshKit.sphere(0.07, 8, 6), Toon.mat(Color("#f3c74f")), Vector3(-0.4, 1.05, 0.14))
	return r


func _part(parent: Node3D, mesh: Mesh, mat: Material, pos: Vector3, rot: Vector3 = Vector3.ZERO, scl: Vector3 = Vector3.ONE) -> MeshInstance3D:
	return MeshKit.part(parent, mesh, mat, pos, rot, scl)


func _collider(r: InteriorRoom, pos: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	r.add_child(body)
	var cs := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = size
	cs.shape = b
	cs.position = pos + Vector3(0, size.y * 0.5, 0)
	body.add_child(cs)


func _window(wall: Node3D, x: float, y: float, night_col: Color = Color("#9ab8ff")) -> void:
	_part(wall, MeshKit.torus(0.5, 0.62, 20, 6), dark_wood, Vector3(x, y, 0.06), Vector3(90, 0, 0))
	_part(wall, MeshKit.cylinder(0.5, 0.5, 0.04, 20), Toon.glow(night_col.lerp(Color("#fff3d0"), 0.5), 1.1), Vector3(x, y, 0.04), Vector3(90, 0, 0))
	_part(wall, MeshKit.box(Vector3(0.06, 1.0, 0.06)), dark_wood, Vector3(x, y, 0.08))
	_part(wall, MeshKit.box(Vector3(1.0, 0.06, 0.06)), dark_wood, Vector3(x, y, 0.08))


func _bookshelf(parent: Node3D, pos: Vector3, rot_y: float, w: float = 1.6) -> void:
	var sh := MeshKit.pivot(parent, pos)
	sh.rotation_degrees.y = rot_y
	_part(sh, MeshKit.box(Vector3(w, 2.4, 0.45)), dark_wood, Vector3(0, 1.2, 0))
	var cols := [Color("#7a2f3a"), Color("#2f5a7a"), Color("#4f7a3a"), Color("#7a5a2f"), Color("#5a3a7a"), Color("#a8743e"), Color("#3a6a6a")]
	var k := 0
	for row in 4:
		var y := 0.3 + row * 0.55
		_part(sh, MeshKit.box(Vector3(w - 0.1, 0.05, 0.4)), wood, Vector3(0, y - 0.05, 0.02))
		var x := -w * 0.5 + 0.12
		while x < w * 0.5 - 0.15:
			var bw := 0.07 + (k % 3) * 0.025
			var bh := 0.32 + (k % 4) * 0.04
			_part(sh, MeshKit.box(Vector3(bw, bh, 0.3)), Toon.mat(cols[k % cols.size()], {"outline": 0.006}), Vector3(x + bw * 0.5, y + bh * 0.5, 0.05), Vector3(0, 0, (5 if k % 7 == 0 else 0)))
			x += bw + 0.012
			k += 1


func _candle(parent: Node3D, pos: Vector3, light: bool = false) -> void:
	_part(parent, MeshKit.cylinder(0.04, 0.045, 0.2, 8), Toon.mat(Color("#fff3e0")), pos + Vector3(0, 0.1, 0))
	_part(parent, MeshKit.sphere(0.03, 6, 4), Toon.glow(Color("#ffcf6a"), 3.0), pos + Vector3(0, 0.24, 0), Vector3.ZERO, Vector3(1.0, 1.6, 1.0))
	if light:
		MeshKit.light(parent, Color("#ffcf8a"), 0.8, 4.0, pos + Vector3(0, 0.4, 0))


func _herbs(parent: Node3D, pos: Vector3) -> void:
	var cols := [Color("#7fb85a"), Color("#b18cff"), Color("#d9b56a"), Color("#6fd38a")]
	for i in 5:
		var p := pos + Vector3(i * 0.35 - 0.7, 0, 0)
		_part(parent, MeshKit.cylinder(0.005, 0.005, 0.3, 4), Toon.mat(Color("#5a3d2a")), p + Vector3(0, -0.15, 0))
		_part(parent, MeshKit.cylinder(0.1, 0.02, 0.32, 6), Toon.mat(cols[i % cols.size()], {"outline": 0.008}), p + Vector3(0, -0.45, 0))


func _table(parent: Node3D, pos: Vector3, w: float = 1.6, d: float = 1.0) -> void:
	_part(parent, MeshKit.box(Vector3(w, 0.08, d)), wood, pos + Vector3(0, 0.78, 0))
	for p in [Vector3(-w * 0.42, 0, -d * 0.38), Vector3(w * 0.42, 0, -d * 0.38), Vector3(-w * 0.42, 0, d * 0.38), Vector3(w * 0.42, 0, d * 0.38)]:
		_part(parent, MeshKit.cylinder(0.05, 0.05, 0.78, 6), wood, pos + p + Vector3(0, 0.39, 0))


func _chair(parent: Node3D, pos: Vector3, rot_y: float) -> void:
	var c := MeshKit.pivot(parent, pos)
	c.rotation_degrees.y = rot_y
	_part(c, MeshKit.box(Vector3(0.5, 0.06, 0.5)), wood, Vector3(0, 0.46, 0))
	_part(c, MeshKit.box(Vector3(0.5, 0.6, 0.06)), wood, Vector3(0, 0.78, 0.22))
	for p in [Vector3(-0.2, 0, -0.2), Vector3(0.2, 0, -0.2), Vector3(-0.2, 0, 0.2), Vector3(0.2, 0, 0.2)]:
		_part(c, MeshKit.cylinder(0.03, 0.03, 0.46, 5), wood, p + Vector3(0, 0.23, 0))


func _rug(parent: Node3D, pos: Vector3, r: float, c1: Color, c2: Color) -> void:
	_part(parent, MeshKit.cylinder(r, r, 0.02, 32), Toon.mat(c1), pos + Vector3(0, 0.01, 0), Vector3.ZERO, Vector3(1.0, 1.0, 0.7))
	_part(parent, MeshKit.cylinder(r * 0.7, r * 0.7, 0.025, 32), Toon.mat(c2), pos + Vector3(0, 0.012, 0), Vector3.ZERO, Vector3(1.0, 1.0, 0.7))
	_part(parent, MeshKit.star(r * 0.45, r * 0.2, 0.01), Toon.mat(c1), pos + Vector3(0, 0.03, 0), Vector3(-90, 0, 0), Vector3(1.0, 0.7, 1.0))


func _fire(parent: Node3D, pos: Vector3) -> void:
	var p := CPUParticles3D.new()
	p.amount = 22
	p.lifetime = 0.8
	p.direction = Vector3.UP
	p.spread = 15.0
	p.initial_velocity_min = 0.5
	p.initial_velocity_max = 1.0
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.25
	p.scale_amount_min = 0.12
	p.scale_amount_max = 0.24
	var curve := Curve.new()
	curve.add_point(Vector2(0, 1))
	curve.add_point(Vector2(1, 0))
	p.scale_amount_curve = curve
	var m := SphereMesh.new()
	m.radius = 0.5
	m.height = 1.0
	m.radial_segments = 6
	m.rings = 3
	m.material = Toon.glow(Color("#ff9a3c"), 2.6)
	p.mesh = m
	p.position = pos
	parent.add_child(p)
	MeshKit.light(parent, Color("#ff9a4c"), 2.2, 7.0, pos + Vector3(0, 0.6, 0.6))


# ================================================================== cabana

func _cabana(outside: Vector3) -> InteriorRoom:
	var r := _room("cabana", "Cabana da Clareira", Vector3(11, 3.4, 8), Color("#9a6a3e"), Color("#f1e3c6"), outside)
	var n := r.wall_node("n")
	var w := r.wall_node("w")
	var e := r.wall_node("e")
	_window(n, -1.0, 1.9)
	_window(n, 2.6, 1.9)
	_window(e, -1.2, 1.9)
	# lareira na parede oeste
	_part(w, MeshKit.box(Vector3(2.2, 1.5, 0.8)), stone, Vector3(0, 0.75, 0.4))
	_part(w, MeshKit.box(Vector3(1.2, 0.9, 0.5)), Toon.mat(Color("#1a1210")), Vector3(0, 0.55, 0.62))
	_part(w, MeshKit.box(Vector3(1.0, 1.9, 0.6)), stone, Vector3(0, 2.45, 0.3))
	_part(w, MeshKit.box(Vector3(2.4, 0.15, 0.95)), dark_wood, Vector3(0, 1.55, 0.45))
	_candle(w, Vector3(-0.8, 1.62, 0.5))
	_candle(w, Vector3(0.8, 1.62, 0.5))
	_part(w, MeshKit.sphere(0.25, 12, 8), Toon.mat(Color("#3a3444"), {"outline": 0.01}), Vector3(0.3, 0.35, 0.65), Vector3.ZERO, Vector3(1.0, 0.8, 1.0))
	_fire(r, Vector3(-5.5 + 0.62, 0.25, 0))
	_rug(r, Vector3(-3.0, 0, 0.2), 1.6, Color("#7a4fc4"), Color("#f3c74f"))
	# cama no canto nordeste
	var bed := Station.new()
	bed.setup("bed")
	bed.position = Vector3(3.9, 0, -2.4)
	r.add_child(bed)
	_part(bed, MeshKit.box(Vector3(1.6, 0.4, 2.4)), wood, Vector3(0, 0.3, 0))
	_part(bed, MeshKit.box(Vector3(1.5, 0.2, 2.3)), Toon.mat(Color("#f6efe2")), Vector3(0, 0.6, 0))
	_part(bed, MeshKit.box(Vector3(1.56, 0.1, 1.6)), Toon.mat(Color("#5a3a8a"), {"outline": 0.01}), Vector3(0, 0.74, 0.35))
	for k in 6:
		_part(bed, MeshKit.star(0.08, 0.035, 0.01), Toon.mat(Color("#f3c74f")), Vector3(-0.5 + (k % 3) * 0.5, 0.8, 0.0 + int(k / 3.0) * 0.6), Vector3(-90, k * 20, 0))
	_part(bed, MeshKit.capsule(0.16, 0.6), Toon.mat(Color("#ffffff")), Vector3(-0.32, 0.8, -0.85), Vector3(0, 0, 90), Vector3(1.0, 1.0, 0.7))
	_part(bed, MeshKit.capsule(0.16, 0.6), Toon.mat(Color("#ffffff")), Vector3(0.32, 0.8, -0.85), Vector3(0, 0, 90), Vector3(1.0, 1.0, 0.7))
	_part(bed, MeshKit.box(Vector3(1.7, 1.3, 0.12)), dark_wood, Vector3(0, 0.75, -1.2))
	_part(bed, MeshKit.torus(0.18, 0.24, 18, 4), Toon.mat(Color("#f3c74f")), Vector3(0, 1.15, -1.13), Vector3(90, 0, 0))
	_collider(r, Vector3(3.9, 0, -2.4), Vector3(1.6, 0.9, 2.4))
	var letter := Readable.new()
	letter.setup("carta_travesseiro", "book")
	letter.position = Vector3(3.5, 0.75, -3.2)
	r.add_child(letter)
	# baú (armazém) ao pé da cama
	var chest := Station.new()
	chest.setup("chest")
	chest.position = Vector3(3.9, 0, -0.5)
	r.add_child(chest)
	_part(chest, MeshKit.box(Vector3(1.1, 0.6, 0.6)), Toon.mat(Color("#8a5a36"), {"outline": 0.02}), Vector3(0, 0.3, 0))
	_part(chest, MeshKit.cylinder(0.3, 0.3, 1.1, 10), Toon.mat(Color("#7a4a2e"), {"outline": 0.02}), Vector3(0, 0.6, 0), Vector3(0, 0, 90))
	for x in [-0.38, 0.38]:
		_part(chest, MeshKit.box(Vector3(0.08, 0.62, 0.64)), Toon.mat(Color("#f3c74f")), Vector3(x, 0.32, 0))
	_collider(r, Vector3(3.9, 0, -0.5), Vector3(1.1, 0.8, 0.6))
	# estantes e atril (biblioteca)
	_bookshelf(r, Vector3(-1.2, 0, -3.65), 0.0, 1.8)
	_bookshelf(r, Vector3(0.8, 0, -3.65), 0.0, 1.6)
	_collider(r, Vector3(-0.2, 0, -3.65), Vector3(3.6, 2.4, 0.5))
	var lectern := Station.new()
	lectern.setup("lectern")
	lectern.position = Vector3(-2.0, 0, -1.6)
	r.add_child(lectern)
	_part(lectern, MeshKit.cylinder(0.1, 0.2, 1.1, 8), dark_wood, Vector3(0, 0.55, 0))
	_part(lectern, MeshKit.box(Vector3(0.75, 0.08, 0.55)), dark_wood, Vector3(0, 1.12, 0), Vector3(-20, 0, 0))
	_part(lectern, MeshKit.box(Vector3(0.66, 0.06, 0.46)), Toon.mat(Color("#f3e6c4"), {"outline": 0.01}), Vector3(0, 1.18, 0), Vector3(-20, 0, 0))
	var floaty := MeshKit.pivot(lectern, Vector3(0, 1.55, 0))
	_part(floaty, MeshKit.star(0.09, 0.04, 0.02), Toon.glow(Color("#fff3b0"), 2.0), Vector3.ZERO)
	lectern.set_anim_node(floaty)
	# mesa de chá
	_table(r, Vector3(0.6, 0, 0.8), 1.4, 1.0)
	_chair(r, Vector3(-0.3, 0, 0.8), 90)
	_chair(r, Vector3(1.5, 0, 0.8), -90)
	_part(r, MeshKit.sphere(0.16, 12, 8), Toon.mat(Color("#7fb0d8"), {"outline": 0.01}), Vector3(0.5, 0.95, 0.75), Vector3.ZERO, Vector3(1.0, 0.8, 1.0))
	_part(r, MeshKit.cylinder(0.06, 0.05, 0.08, 10), Toon.mat(Color("#f6efe2")), Vector3(0.95, 0.86, 0.95))
	_candle(r, Vector3(0.2, 0.82, 1.05), true)
	_collider(r, Vector3(0.6, 0, 0.8), Vector3(1.4, 0.8, 1.0))
	# bancada de poções na parede leste (decoração)
	_part(e, MeshKit.box(Vector3(2.2, 0.08, 0.7)), wood, Vector3(1.5, 0.95, 0.38))
	_part(e, MeshKit.box(Vector3(2.2, 0.9, 0.08)), wood, Vector3(1.5, 0.47, 0.7))
	for k in 6:
		_part(e, MeshKit.cylinder(0.07, 0.09, 0.26, 8), Toon.mat([Color("#ff6f7d"), Color("#7fa8ff"), Color("#c8a2ff"), Color("#fff3a0"), Color("#8fcf5a"), Color("#ffb070")][k], {"emission": 0.5, "outline": 0.006}), Vector3(0.6 + k * 0.35, 1.12, 0.35 + (k % 2) * 0.12))
	_part(e, MeshKit.cylinder(0.14, 0.1, 0.16, 10), stone, Vector3(2.3, 1.07, 0.3))
	# ervas penduradas, vasos, vassoura, caminha do Nimbus, retrato de Ondina
	_herbs(r, Vector3(-1.5, 3.1, 1.0))
	_herbs(r, Vector3(2.0, 3.1, -1.0))
	for p in [Vector3(-5.0, 0, -3.4), Vector3(5.0, 0, 3.4), Vector3(-5.0, 0, 3.4)]:
		_part(r, MeshKit.cylinder(0.22, 0.16, 0.4, 10), Toon.mat(Color("#c4673a"), {"outline": 0.01}), p + Vector3(0, 0.2, 0))
		_part(r, MeshKit.sphere(0.38, 10, 8), Toon.mat(Color("#5fae58"), {"outline": 0.01}), p + Vector3(0, 0.65, 0))
	_part(r, MeshKit.cylinder(0.02, 0.025, 1.5, 6), wood, Vector3(-4.9, 0.75, 2.6), Vector3(0, 0, 12))
	_part(r, MeshKit.cylinder(0.02, 0.18, 0.4, 8), Toon.mat(Color("#d9b56a")), Vector3(-4.75, 0.15, 2.6), Vector3(0, 0, 12))
	_part(r, MeshKit.cylinder(0.45, 0.5, 0.15, 16), Toon.mat(Color("#c8a2ff"), {"outline": 0.01}), Vector3(-3.6, 0.08, -2.6))
	_part(n, MeshKit.box(Vector3(0.9, 1.1, 0.06)), Toon.mat(Color("#c9a24a"), {"outline": 0.01}), Vector3(-3.6, 2.0, 0.05))
	_part(n, MeshKit.box(Vector3(0.75, 0.95, 0.04)), Toon.mat(Color("#3a5a8a")), Vector3(-3.6, 2.0, 0.08))
	_part(n, MeshKit.sphere(0.16, 10, 8), Toon.mat(Color("#e8c9a8")), Vector3(-3.6, 2.1, 0.1), Vector3.ZERO, Vector3(1.0, 1.0, 0.3))
	_part(n, MeshKit.cylinder(0.0, 0.18, 0.35, 10), Toon.mat(Color("#5a3a8a")), Vector3(-3.6, 2.38, 0.1), Vector3.ZERO, Vector3(1.0, 1.0, 0.3))
	MeshKit.light(r, Color("#ffd9a0"), 1.2, 9.0, Vector3(0.5, 2.8, 0))
	# objetos mágicos dentro de casa
	var prop := MagicProp.new()
	prop.setup("cabana_abobora", "pumpkin")
	prop.position = Vector3(-4.5, 0, 1.6)
	r.add_child(prop)
	var prop2 := MagicProp.new()
	prop2.setup("cabana_caixa", "crate")
	prop2.position = Vector3(4.6, 0, 2.6)
	r.add_child(prop2)
	return r


# ================================================================== casa de chá

func _cha(outside: Vector3) -> InteriorRoom:
	var r := _room("cha", "Casa de Chá da Vovó Sálvia", Vector3(9, 3.2, 8), Color("#b08a5a"), Color("#e8d6b0"), outside)
	var n := r.wall_node("n")
	var w := r.wall_node("w")
	var e := r.wall_node("e")
	_window(n, 0.0, 1.8, Color("#ffd9a0"))
	_window(e, 0.0, 1.8, Color("#ffd9a0"))
	# prateleiras de potes
	for side in [w, n]:
		for row in 3:
			_part(side, MeshKit.box(Vector3(3.2, 0.06, 0.35)), wood, Vector3(-2.2 if side == n else 0.0, 0.9 + row * 0.55, 0.2))
			for k in 7:
				var c: Color = [Color("#e8a94a"), Color("#b18cff"), Color("#6fd38a"), Color("#ff9fb2"), Color("#8fd6ff"), Color("#d9b56a")][(k + row) % 6]
				_part(side, MeshKit.cylinder(0.09, 0.09, 0.22, 10), Toon.mat(c, {"alpha": 0.85, "outline": 0.006}), Vector3((-2.2 if side == n else 0.0) - 1.35 + k * 0.45, 1.05 + row * 0.55, 0.2))
	_herbs(r, Vector3(0.0, 2.95, -1.5))
	_herbs(r, Vector3(1.0, 2.95, 1.2))
	_rug(r, Vector3(0.5, 0, 0.3), 1.5, Color("#5f7f4a"), Color("#d9c27a"))
	_table(r, Vector3(0.5, 0, 0.3), 1.2, 1.2)
	_part(r, MeshKit.sphere(0.22, 14, 10), Toon.mat(Color("#7fb0d8"), {"outline": 0.01}), Vector3(0.5, 1.0, 0.3), Vector3.ZERO, Vector3(1.0, 0.85, 1.0))
	_part(r, MeshKit.cylinder(0.04, 0.08, 0.25, 6), Toon.mat(Color("#7fb0d8")), Vector3(0.78, 1.05, 0.3), Vector3(0, 0, -55))
	for p in [Vector3(0.1, 0.86, 0.6), Vector3(0.9, 0.86, 0.0)]:
		_part(r, MeshKit.cylinder(0.06, 0.05, 0.08, 10), Toon.mat(Color("#f6efe2")), p)
	_collider(r, Vector3(0.5, 0, 0.3), Vector3(1.2, 0.8, 1.2))
	_chair(r, Vector3(-0.5, 0, 0.3), 90)
	# cadeira de balanço e fogão de ferro
	_part(r, MeshKit.box(Vector3(0.6, 0.06, 0.6)), wood, Vector3(2.8, 0.45, -2.2))
	_part(r, MeshKit.box(Vector3(0.6, 0.8, 0.06)), wood, Vector3(2.8, 0.85, -1.92), Vector3(-12, 0, 0))
	_part(r, MeshKit.torus(0.6, 0.66, 20, 4), wood, Vector3(2.8, 0.2, -2.2), Vector3(0, 90, 90), Vector3(1.0, 0.4, 1.0))
	_part(r, MeshKit.box(Vector3(1.0, 0.9, 0.8)), Toon.mat(Color("#3a3444"), {"outline": 0.02}), Vector3(-3.6, 0.45, -3.3))
	_part(r, MeshKit.cylinder(0.12, 0.12, 2.5, 8), Toon.mat(Color("#3a3444")), Vector3(-3.6, 2.0, -3.5))
	_fire(r, Vector3(-3.6, 0.5, -2.85))
	_collider(r, Vector3(-3.6, 0, -3.3), Vector3(1.0, 0.9, 0.8))
	# vasos de plantas
	for p in [Vector3(3.8, 0, 3.2), Vector3(-3.8, 0, 3.2), Vector3(3.8, 0, 0.5)]:
		_part(r, MeshKit.cylinder(0.25, 0.18, 0.45, 10), Toon.mat(Color("#c4673a"), {"outline": 0.01}), p + Vector3(0, 0.22, 0))
		_part(r, MeshKit.sphere(0.42, 10, 8), Toon.mat(Color("#6fbf5c"), {"outline": 0.01}), p + Vector3(0, 0.75, 0))
	# coletáveis da despensa
	var lav := HarvestNode.new()
	lav.setup("cha_lavanda", "lavanda_sonolenta", "spikes", 2)
	lav.position = Vector3(-2.6, 0, 1.6)
	r.add_child(lav)
	var mel := HarvestNode.new()
	mel.setup("cha_mel", "mel_silvestre", "crystal", 1)
	mel.position = Vector3(2.2, 0.85, 3.2)
	r.add_child(mel)
	MeshKit.light(r, Color("#ffd9a0"), 1.2, 8.0, Vector3(0, 2.6, 0))
	return r


# ================================================================== padaria

func _padaria(outside: Vector3) -> InteriorRoom:
	var r := _room("padaria", "Padaria Pão-de-Mel", Vector3(10, 3.4, 8), Color("#c9a27a"), Color("#f6e6d0"), outside)
	var n := r.wall_node("n")
	var e := r.wall_node("e")
	_window(e, 0.5, 1.9, Color("#ffd9a0"))
	# forno de tijolos
	_part(n, MeshKit.box(Vector3(2.6, 2.0, 1.2)), Toon.mat(Color("#b05a3a"), {"outline": 0.02}), Vector3(-3.0, 1.0, 0.6))
	_part(n, MeshKit.sphere(0.6, 16, 10, true), Toon.mat(Color("#1a1210")), Vector3(-3.0, 0.5, 1.2), Vector3(90, 0, 0), Vector3(1.0, 1.0, 0.4))
	_fire(r, Vector3(-3.0, 0.6, -2.7))
	_collider(r, Vector3(-3.0, 0, -3.4), Vector3(2.6, 2.0, 1.2))
	# balcão com pães
	_part(r, MeshKit.box(Vector3(5.0, 1.0, 0.8)), Toon.mat(Color("#8a5a36"), {"outline": 0.02}), Vector3(1.0, 0.5, -1.0))
	_part(r, MeshKit.box(Vector3(5.1, 0.08, 0.9)), Toon.mat(Color("#e8d6b0")), Vector3(1.0, 1.02, -1.0))
	_collider(r, Vector3(1.0, 0, -1.0), Vector3(5.0, 1.0, 0.8))
	for k in 8:
		_part(r, MeshKit.capsule(0.12, 0.42), Toon.mat(Color("#d9984a"), {"rim": 0.4, "outline": 0.01}), Vector3(-1.1 + k * 0.6, 1.17, -1.0 + (k % 2) * 0.15), Vector3(0, 0, 90), Vector3(1.0, 1.0, 0.8))
	for k in 5:
		_part(r, MeshKit.sphere(0.13, 10, 8), Toon.mat(Color("#e8a94a"), {"rim": 0.4, "outline": 0.01}), Vector3(-0.6 + k * 0.45, 1.2, -0.75), Vector3.ZERO, Vector3(1.0, 0.75, 1.0))
	# bancada com a massa encantada
	_part(r, MeshKit.box(Vector3(2.4, 0.9, 0.9)), wood, Vector3(1.0, 0.45, -3.4))
	_collider(r, Vector3(1.0, 0, -3.4), Vector3(2.4, 0.9, 0.9))
	var dough := MagicProp.new()
	dough.setup("massa_dorinha", "dough")
	dough.position = Vector3(1.0, 0.92, -3.5)
	r.add_child(dough)
	# sacos de farinha, cestos, prateleira
	for p in [Vector3(4.2, 0, 2.8), Vector3(4.2, 0, 2.0), Vector3(3.5, 0, 3.0)]:
		_part(r, MeshKit.capsule(0.32, 0.8), Toon.mat(Color("#f2ead8"), {"outline": 0.015}), p + Vector3(0, 0.4, 0))
	_part(n, MeshKit.box(Vector3(2.8, 0.06, 0.4)), wood, Vector3(2.4, 1.8, 0.22))
	for k in 5:
		_part(n, MeshKit.cylinder(0.18, 0.14, 0.25, 10), Toon.mat(Color("#c99a5a"), {"outline": 0.01}), Vector3(1.4 + k * 0.5, 1.96, 0.22))
	_herbs(r, Vector3(2.0, 3.1, 1.5))
	MeshKit.light(r, Color("#ffd9a0"), 1.3, 9.0, Vector3(0.5, 2.8, 0.5))
	return r
