class_name ValleyTerrain
extends RefCounted
## Relevo do Vale dos Sussurros: colinas suaves, anel de montanhas, riacho e lagoa
## esculpidos, clareiras aplainadas e trilhas. Função de altura analítica usada
## tanto para a malha quanto para posicionar objetos.

const SIZE := 136.0
const STEP := 1.6
const POND_CENTER := Vector2(-31.0, -14.0)
const POND_RADIUS := 7.5
const ISLET_RADIUS := 2.2
const POND_LEVEL := -0.9
const CREEK_LEVEL := -0.8
const BOUNDARY := 54.0

var noise := FastNoiseLite.new()
var detail := FastNoiseLite.new()
var color_noise := FastNoiseLite.new()
var paths: Array = []          # Array[PackedVector2Array]
var flats: Array = []          # [Vector2 centro, raio, altura]
var creek: PackedVector2Array


func _init() -> void:
	noise.seed = 7
	noise.frequency = 0.03
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	detail.seed = 13
	detail.frequency = 0.11
	color_noise.seed = 21
	color_noise.frequency = 0.06
	# Riacho leste: de z=8 até as montanhas do sul, serpenteando.
	creek = PackedVector2Array()
	var z := 7.0
	while z <= 62.0:
		creek.append(Vector2(30.0 + sin(z * 0.15) * 2.0, z))
		z += 3.0
	_define_paths()
	_define_flats()


func _define_paths() -> void:
	var raw := [
		[Vector2(0, -2), Vector2(0, 9), Vector2(-8, 15), Vector2(-19, 20), Vector2(-23, 23)],
		[Vector2(0, 9), Vector2(8, 14), Vector2(7, 30), Vector2(8, 50)],
		[Vector2(2, -1), Vector2(10, 1), Vector2(20, 4), Vector2(27, -3), Vector2(34, -5), Vector2(43, -9)],
		[Vector2(0, -9), Vector2(-3, -18), Vector2(-4, -25), Vector2(0, -32)],
		[Vector2(-4, -25), Vector2(-9, -33), Vector2(-14, -40)],
		[Vector2(-3, -1), Vector2(-12, 1), Vector2(-23, 2), Vector2(-25, -6), Vector2(-25, -13)],
		[Vector2(-25, -13), Vector2(-26, -21), Vector2(-33, -29), Vector2(-37, -33)],
		[Vector2(3, -7), Vector2(11, -15), Vector2(18, -21)],
		[Vector2(7.5, 20), Vector2(18, 21), Vector2(27, 22), Vector2(34, 23), Vector2(40, 25)],
	]
	for p in raw:
		paths.append(PackedVector2Array(p))


func _define_flats() -> void:
	flats = [
		[Vector2(0, -2), 15.0, 0.0],       # clareira da cabana
		[Vector2(-21, 20), 7.0, 0.3],      # casa de chá de Sálvia
		[Vector2(9, 16), 5.0, 0.2],        # carroça do Bento
		[Vector2(21, 6), 6.0, 0.4],        # acampamento de Mirela
		[Vector2(30, -4), 4.0, 0.6],       # passagem resmungona
		[Vector2(43, -10), 6.0, 0.8],      # santuário leste
		[Vector2(0, -36), 10.0, 0.5],      # árvore do Guardião
		[Vector2(-14, -42), 6.0, 0.7],     # portal das ruínas
		[Vector2(-26, 3), 6.0, 0.2],       # salgueiro oco
		[Vector2(-36, -33), 9.0, 0.3],     # bosque das corujas
		[Vector2(19, -24), 7.0, 2.6],      # círculo de pedras (no alto da colina)
		[Vector2(40, 25), 5.0, 0.3],       # recanto do gelo
	]


static func _ss(e0: float, e1: float, x: float) -> float:
	var t := clampf((x - e0) / (e1 - e0), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


static func dist_to_polyline(p: Vector2, pts: PackedVector2Array) -> float:
	var best := INF
	for i in pts.size() - 1:
		var a := pts[i]
		var b := pts[i + 1]
		var ab := b - a
		var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
		best = minf(best, p.distance_to(a + ab * t))
	return best


func dist_to_path(x: float, z: float) -> float:
	var p := Vector2(x, z)
	var best := INF
	for path in paths:
		best = minf(best, dist_to_polyline(p, path))
	return best


func dist_to_creek(x: float, z: float) -> float:
	return dist_to_polyline(Vector2(x, z), creek)


func dist_to_pond(x: float, z: float) -> float:
	return Vector2(x, z).distance_to(POND_CENTER)


func raw_height(x: float, z: float) -> float:
	var h := noise.get_noise_2d(x, z) * 1.8 + detail.get_noise_2d(x, z) * 0.25
	h += 3.2 * exp(-(pow(x - 19.0, 2.0) + pow(z + 24.0, 2.0)) / 90.0)
	h += 1.6 * exp(-(pow(x + 18.0, 2.0) + pow(z - 38.0, 2.0)) / 220.0)
	var r := Vector2(x, z).length()
	if r > 48.0:
		h += pow((r - 48.0) * 0.6, 1.65)
	return h


func height(x: float, z: float) -> float:
	var h := raw_height(x, z)
	for f in flats:
		var d: float = Vector2(x, z).distance_to(f[0])
		var t := _ss(f[1], f[1] * 0.55, d)
		h = lerpf(h, f[2], t)
	var dp := dist_to_path(x, z)
	if dp < 3.0:
		h = lerpf(h, h * 0.7, _ss(3.0, 1.0, dp))
	var dc := dist_to_creek(x, z)
	if dc < 4.0:
		h = lerpf(h, CREEK_LEVEL - 1.8, _ss(4.0, 1.7, dc))
	var dpo := dist_to_pond(x, z)
	if dpo < POND_RADIUS + 2.0:
		var carved := lerpf(h, POND_LEVEL - 1.9, _ss(POND_RADIUS + 2.0, POND_RADIUS - 1.0, dpo))
		var islet := lerpf(carved, 0.15, _ss(ISLET_RADIUS + 0.8, ISLET_RADIUS - 0.4, dpo))
		h = islet
	return h


func ground_color(x: float, z: float, h: float) -> Color:
	var n := color_noise.get_noise_2d(x, z)
	var c := Color("#7cc96a").lerp(Color("#5fae58"), clampf(n * 0.5 + 0.5, 0.0, 1.0))
	c = c.lerp(Color("#a3d977"), clampf(detail.get_noise_2d(x * 0.5, z * 0.5) - 0.2, 0.0, 1.0) * 0.6)
	if x < -24.0 and z < -22.0:
		c = c.lerp(Color("#4f8f55"), 0.5)
	var dp := dist_to_path(x, z)
	if dp < 1.8:
		c = c.lerp(Color("#d8bf8a"), _ss(1.8, 0.9, dp))
	var dc := minf(dist_to_creek(x, z), absf(dist_to_pond(x, z) - POND_RADIUS) + 0.6)
	if dc < 3.0 and not (dist_to_pond(x, z) < ISLET_RADIUS + 0.6):
		c = c.lerp(Color("#b8a676"), _ss(3.0, 1.2, dc))
	if h < CREEK_LEVEL - 0.3:
		c = Color("#6a7a6a")
	var r := Vector2(x, z).length()
	if r > 50.0:
		c = c.lerp(Color("#8d8aa0"), _ss(50.0, 56.0, r))
	if h > 9.0:
		c = c.lerp(Color("#eef2fb"), _ss(9.0, 12.0, h))
	return c


func build_mesh() -> ArrayMesh:
	var n := int(SIZE / STEP) + 1
	var half := SIZE * 0.5
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var hs := PackedFloat32Array()
	hs.resize(n * n)
	for j in n:
		for i in n:
			hs[j * n + i] = height(-half + i * STEP, -half + j * STEP)
	for j in n:
		for i in n:
			var x := -half + i * STEP
			var z := -half + j * STEP
			st.set_color(ground_color(x, z, hs[j * n + i]))
			st.set_uv(Vector2(float(i) / n, float(j) / n))
			st.add_vertex(Vector3(x, hs[j * n + i], z))
	for j in n - 1:
		for i in n - 1:
			var a := j * n + i
			var b := a + 1
			var c := a + n
			var d := c + 1
			st.add_index(a); st.add_index(b); st.add_index(c)
			st.add_index(b); st.add_index(d); st.add_index(c)
	st.generate_normals()
	return st.commit()


## Ponto livre para vegetação (longe de trilhas, água e clareiras).
func is_free(x: float, z: float, margin: float = 0.0) -> bool:
	if dist_to_path(x, z) < 2.6 + margin:
		return false
	if dist_to_creek(x, z) < 4.5 + margin or dist_to_pond(x, z) < POND_RADIUS + 2.5 + margin:
		return false
	for f in flats:
		if Vector2(x, z).distance_to(f[0]) < float(f[1]) * 0.8 + margin:
			return false
	return Vector2(x, z).length() < 60.0
