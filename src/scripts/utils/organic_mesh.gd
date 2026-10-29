class_name OrganicMesh
extends RefCounted
## Malhas orgânicas e lisas geradas em código: corpos por seções (loft), tubos ao
## longo de curvas (membros, mechas de cabelo, alças), cabeça esculpida, abas de
## chapéu e caixas chanfradas. Todas saem de uma grade de vértices com normais
## calculadas por diferenças centrais — sem costuras nem facetas.
## Frente = -Z. As malhas são cacheadas pela chave informada.

static var _cache: Dictionary = {}


static func cached(key: String, maker: Callable) -> Mesh:
	if not _cache.has(key):
		_cache[key] = maker.call()
	return _cache[key]


# ------------------------------------------------------------------ grade base

## Constrói a malha de uma grade: rows[i] é um PackedVector3Array com o mesmo
## número de pontos. wrap fecha as colunas (superfície de revolução).
## UV.x corre ao longo da linha, UV.y ao longo das linhas (0..1 × v_scale).
## A tangente aponta ao longo de UV.y (direção das mechas) — usada pelo brilho do cabelo.
static func grid(rows: Array, wrap: bool, inward: bool = false, v_scale: float = 1.0, colors: Array = [], normal_rows: Array = []) -> ArrayMesh:
	var nr := rows.size()
	var nc: int = (rows[0] as PackedVector3Array).size()
	var cols_out := nc + (1 if wrap else 0)
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var tans := PackedFloat32Array()
	var uvs := PackedVector2Array()
	var vcol := PackedColorArray()
	var use_col := colors.size() == nr
	for i in nr:
		var row: PackedVector3Array = rows[i]
		for jj in cols_out:
			var j := jj % nc
			var p := row[j]
			var jl := (j - 1 + nc) % nc if wrap else maxi(j - 1, 0)
			var jr := (j + 1) % nc if wrap else mini(j + 1, nc - 1)
			var du := row[jr] - row[jl]
			var ia := maxi(i - 1, 0)
			var ib := mini(i + 1, nr - 1)
			var dv := (rows[ib] as PackedVector3Array)[j] - (rows[ia] as PackedVector3Array)[j]
			var n := du.cross(dv)
			if normal_rows.size() == nr:
				n = (normal_rows[i] as PackedVector3Array)[j]
			elif n.length_squared() < 1e-14:
				n = _pole_normal(rows, i, p)
			elif inward:
				n = -n
			n = n.normalized()
			verts.append(p)
			norms.append(n)
			var t := dv.normalized() if dv.length_squared() > 1e-14 else Vector3.DOWN
			tans.append_array([t.x, t.y, t.z, 1.0])
			uvs.append(Vector2(float(jj) / float(cols_out - 1), float(i) / float(maxi(nr - 1, 1)) * v_scale))
			if use_col:
				vcol.append(colors[i])
	var idx := PackedInt32Array()
	for i in nr - 1:
		for j in cols_out - 1:
			var a := i * cols_out + j
			var b := a + 1
			var c2 := a + cols_out
			var d := c2 + 1
			_quad(idx, verts, norms, a, b, c2, d)
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = norms
	arr[Mesh.ARRAY_TANGENT] = tans
	arr[Mesh.ARRAY_TEX_UV] = uvs
	if use_col:
		arr[Mesh.ARRAY_COLOR] = vcol
	arr[Mesh.ARRAY_INDEX] = idx
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return m


## Normal num polo (linha degenerada): soma dos triângulos do leque, virada para
## longe do anel seguinte.
static func _pole_normal(rows: Array, i: int, p: Vector3) -> Vector3:
	var nr := rows.size()
	var adj: PackedVector3Array = rows[mini(i + 1, nr - 1)] if i < nr - 1 else rows[i - 1]
	var far: PackedVector3Array = rows[mini(i + 2, nr - 1)] if i < nr - 1 else rows[maxi(i - 2, 0)]
	var n := Vector3.ZERO
	for j in adj.size():
		n += (adj[j] - p).cross(adj[(j + 1) % adj.size()] - p)
	if n.length_squared() < 1e-16:
		return Vector3.UP
	var c := Vector3.ZERO
	for q in far:
		c += q
	c /= float(far.size())
	if n.dot(p - c) < 0.0:
		n = -n
	return n


## Godot desenha como frente os triângulos em sentido horário: escolhe a ordem
## que deixa a face voltada para o lado das normais.
static func _quad(idx: PackedInt32Array, v: PackedVector3Array, n: PackedVector3Array, a: int, b: int, c: int, d: int) -> void:
	var avg := n[a] + n[b] + n[c] + n[d]
	var geo := (v[b] - v[a]).cross(v[c] - v[a])
	if geo.length_squared() < 1e-16:
		geo = (v[d] - v[b]).cross(v[c] - v[b])
	if geo.dot(avg) < 0.0:
		idx.append_array([a, b, c, b, d, c])
	else:
		idx.append_array([a, c, b, b, c, d])


# ------------------------------------------------------------------ curvas

static func catmull(p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, t: float) -> Vector3:
	var t2 := t * t
	var t3 := t2 * t
	return 0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3)


static func _catf(a: float, b: float, c: float, d: float, t: float) -> float:
	return catmull(Vector3(a, 0, 0), Vector3(b, 0, 0), Vector3(c, 0, 0), Vector3(d, 0, 0), t).x


## Subdivide pontos de controle com Catmull-Rom (passa por todos os pontos).
static func smooth_points(pts: Array, sub: int) -> Array:
	var out: Array = []
	var n := pts.size()
	if n < 2:
		return pts.duplicate()
	for i in n - 1:
		var p0: Vector3 = pts[maxi(i - 1, 0)]
		var p1: Vector3 = pts[i]
		var p2: Vector3 = pts[i + 1]
		var p3: Vector3 = pts[mini(i + 2, n - 1)]
		if i == 0:
			p0 = p1 * 2.0 - p2
		if i + 2 >= n:
			p3 = p2 * 2.0 - p1
		for s in sub:
			out.append(catmull(p0, p1, p2, p3, float(s) / float(sub)))
	out.append(pts[n - 1])
	return out


static func smooth_values(vals: Array, sub: int) -> Array:
	var out: Array = []
	var n := vals.size()
	for i in n - 1:
		var a: float = vals[maxi(i - 1, 0)]
		var b: float = vals[i]
		var c: float = vals[i + 1]
		var d: float = vals[mini(i + 2, n - 1)]
		for s in sub:
			out.append(maxf(0.0, _catf(a, b, c, d, float(s) / float(sub))))
	out.append(vals[n - 1])
	return out


# ------------------------------------------------------------------ loft

## Superfície de revolução por seções elípticas ao longo de Y.
## sections: [[y, rx, rz], ...] ou [[y, rx, rz, cz], ...] (cz desloca para frente/trás).
## opts: folds (amplitude relativa), fold_n, fold_from (0..1), fold_seed, cap_top, cap_bottom,
## front_bulge [y, amplitude, largura] (ex.: busto), flat_back (0..1), open (ângulo da abertura frontal).
static func loft(sections: Array, segs: int = 32, sub: int = 3, opts: Dictionary = {}) -> ArrayMesh:
	var ys: Array = []
	var rxs: Array = []
	var rzs: Array = []
	var czs: Array = []
	for s in sections:
		var sec: Array = s
		ys.append(float(sec[0]))
		rxs.append(float(sec[1]))
		rzs.append(float(sec[2]))
		czs.append(float(sec[3]) if sec.size() > 3 else 0.0)
	var sy := smooth_values_signed(ys, sub)
	var srx := smooth_values(rxs, sub)
	var srz := smooth_values(rzs, sub)
	var scz := smooth_values_signed(czs, sub)
	var folds := float(opts.get("folds", 0.0))
	var fold_n := int(opts.get("fold_n", 8))
	var fold_from := float(opts.get("fold_from", 0.0))
	var fold_seed := float(opts.get("fold_seed", 0.0))
	var fold_y: Array = opts.get("fold_y", [])
	var bulge: Array = opts.get("front_bulge", [])
	var open_ang := float(opts.get("open", 0.0))
	var arc: Array = opts.get("arc", [])
	if open_ang > 0.0 and arc.is_empty():
		arc = [open_ang * 0.5, TAU - open_ang * 0.5]
	var rows: Array = []
	var nrows := sy.size()
	if opts.get("cap_bottom", false):
		var pr := PackedVector3Array()
		for j in segs:
			pr.append(Vector3(0, sy[0], scz[0]))
		rows.append(pr)
	for i in nrows:
		var y: float = sy[i]
		var rx: float = srx[i]
		var rz: float = srz[i]
		var cz: float = scz[i]
		var t := float(i) / float(maxi(nrows - 1, 1))
		var fk := clampf((t - fold_from) / maxf(0.001, 1.0 - fold_from), 0.0, 1.0)
		var row := PackedVector3Array()
		for j in segs:
			var th := float(j) / float(segs) * TAU
			if arc.size() == 2:
				# faixa parcial (abertura frontal, avental): colunas de arc[0] até arc[1]
				th = lerpf(float(arc[0]), float(arc[1]), float(j) / float(segs - 1))
			var k := 1.0
			if folds > 0.0:
				k += folds * fk * (sin(th * fold_n + fold_seed) * 0.7 + sin(th * fold_n * 2.3 + fold_seed * 1.7) * 0.3)
			var x := sin(th) * rx * k
			var z := -cos(th) * rz * k
			if bulge.size() == 3:
				var by := float(bulge[0])
				var ba := float(bulge[1])
				var bw := float(bulge[2])
				var fy := exp(-pow((y - by) / bw, 2.0))
				var front := maxf(0.0, cos(th))
				z -= ba * fy * pow(front, 1.5) * (0.6 + 0.4 * absf(cos(th * 2.0)))
			row.append(Vector3(x, y, z + cz))
		rows.append(row)
	if opts.get("cap_top", false):
		var pt := PackedVector3Array()
		for j in segs:
			pt.append(Vector3(0, sy[nrows - 1], scz[nrows - 1]))
		rows.append(pt)
	# com seções em y crescente o produto vetorial aponta para dentro: inverte
	var ascending: bool = float(sy[nrows - 1]) > float(sy[0])
	return grid(rows, arc.is_empty(), ascending)


static func smooth_values_signed(vals: Array, sub: int) -> Array:
	var out: Array = []
	var n := vals.size()
	for i in n - 1:
		var a: float = vals[maxi(i - 1, 0)]
		var b: float = vals[i]
		var c: float = vals[i + 1]
		var d: float = vals[mini(i + 2, n - 1)]
		if i == 0:
			a = b * 2.0 - c
		if i + 2 >= n:
			d = c * 2.0 - b
		for s in sub:
			out.append(_catf(a, b, c, d, float(s) / float(sub)))
	out.append(vals[n - 1])
	return out


# ------------------------------------------------------------------ tubos

## Tubo liso ao longo de uma curva (membros, mechas, alças, caules).
## radii: um raio por ponto (float) — interpolados. opts: segs, sub, flat (0..1 achata a seção),
## twist (rad ao longo do tubo), round_start/round_end (pontas arredondadas), up (vetor de referência),
## wave (amplitude de ondulação lateral), closed (anel fechado).
static func tube(pts: Array, radii: Array, opts: Dictionary = {}) -> ArrayMesh:
	var segs := int(opts.get("segs", 12))
	var sub := int(opts.get("sub", 4))
	var flat := float(opts.get("flat", 0.0))
	var twist := float(opts.get("twist", 0.0))
	var closed: bool = opts.get("closed", false)
	var cpts := pts.duplicate()
	var crad := radii.duplicate()
	if closed:
		cpts.append(pts[0])
		crad.append(radii[0])
	var sp := smooth_points(cpts, sub)
	var sr := smooth_values(crad, sub)
	var n := sp.size()
	# quadros por transporte paralelo
	var up: Vector3 = opts.get("up", Vector3(0, 0, -1))
	var tangents: Array = []
	for i in n:
		var a: Vector3 = sp[maxi(i - 1, 0)]
		var b: Vector3 = sp[mini(i + 1, n - 1)]
		var t := (b - a)
		tangents.append(t.normalized() if t.length_squared() > 1e-12 else Vector3.DOWN)
	var t0: Vector3 = tangents[0]
	var normal := up - t0 * up.dot(t0)
	if normal.length_squared() < 1e-8:
		normal = Vector3.RIGHT - t0 * t0.x
	normal = normal.normalized()
	var rows: Array = []
	if opts.get("round_start", false):
		var r0: float = sr[0]
		var p0: Vector3 = sp[0]
		for k in [3, 2, 1]:
			var ang := float(k) / 3.0 * PI * 0.5
			rows.append(_ring(p0 - t0 * sin(ang) * r0, t0, normal, r0 * cos(ang), segs, flat, 0.0))
		rows[0] = _ring(p0 - t0 * r0, t0, normal, 0.0, segs, flat, 0.0)
	for i in n:
		var t: Vector3 = tangents[i]
		if i > 0:
			var tp: Vector3 = tangents[i - 1]
			var axis := tp.cross(t)
			if axis.length_squared() > 1e-12:
				normal = normal.rotated(axis.normalized(), tp.angle_to(t))
			normal = (normal - t * normal.dot(t)).normalized()
		var tw := twist * float(i) / float(maxi(n - 1, 1))
		rows.append(_ring(sp[i], t, normal, sr[i], segs, flat, tw))
	if opts.get("round_end", false):
		var rn: float = sr[n - 1]
		var pn: Vector3 = sp[n - 1]
		var tn: Vector3 = tangents[n - 1]
		for k in [1, 2, 3]:
			var ang2 := float(k) / 3.0 * PI * 0.5
			rows.append(_ring(pn + tn * sin(ang2) * rn, tn, normal, rn * cos(ang2) if k < 3 else 0.0, segs, flat, twist))
	return grid(rows, true)


static func _ring(c: Vector3, t: Vector3, nrm: Vector3, r: float, segs: int, flat: float, twist: float) -> PackedVector3Array:
	var bin := t.cross(nrm).normalized()
	var row := PackedVector3Array()
	for j in segs:
		var a := float(j) / float(segs) * TAU + twist
		row.append(c + (nrm * cos(a) * (1.0 - flat) + bin * sin(a)) * r)
	return row


# ------------------------------------------------------------------ cabeça

## Cabeça esculpida (estilo anime realista): crânio arredondado, maçãs do rosto,
## mandíbula afinando até o queixo, nariz discreto. Centro na altura dos olhos.
## p: width, height, depth, jaw (0..1 quão fina), chin (projeção), nose, cheek, age.
static func head(p: Dictionary) -> ArrayMesh:
	var key := "head|" + str(p)
	return cached(key, func(): return _build_head(p)) as ArrayMesh


static func head_point(d: Vector3, p: Dictionary) -> Vector3:
	var w := float(p.get("width", 0.074))
	var h := float(p.get("height", 0.118))
	var dp := float(p.get("depth", 0.092))
	var jaw := float(p.get("jaw", 0.55))
	var chin := float(p.get("chin", 0.012))
	var nose := float(p.get("nose", 0.006))
	var cheek := float(p.get("cheek", 0.004))
	var y := d.y
	# largura: cheia no crânio, afina na mandíbula
	var sx := 1.0
	if y < -0.15:
		var k := smoothstep(-0.15, -1.0, y)
		sx = lerpf(1.0, 1.0 - jaw * 0.8, pow(k, 1.5))
	# profundidade: nuca mais cheia, rosto achatado
	var front := d.z < 0.0
	var sz := 1.0 if front else 1.06
	if front:
		sz *= lerpf(1.0, 0.9, smoothstep(0.2, -0.6, y) * 0.6)
	var x := d.x * w * sx
	# rosto mais curto abaixo dos olhos (proporção anime), crânio mais alto
	var yy := y * h * (1.0 if y > 0.0 else 0.86) + (0.016 if y > 0.0 else 0.0) * y
	var z := d.z * dp * sz
	# crânio sobe um pouco para trás
	if not front:
		yy += 0.008 * maxf(0.0, y) * (-d.z)
	# queixo: puxa a parte de baixo da frente para frente
	var fz := maxf(0.0, -d.z)
	z -= chin * smoothstep(-0.55, -0.98, y) * pow(fz, 2.0)
	yy -= 0.006 * smoothstep(-0.6, -1.0, y)
	# nariz (gaussiana pequena)
	var nx := d.x / 0.2
	var ny := (y + 0.28) / 0.22
	z -= nose * exp(-(nx * nx + ny * ny)) * pow(fz, 4.0)
	# maçãs do rosto
	for sxs: float in [-1.0, 1.0]:
		var cx := (d.x - sxs * 0.5) / 0.28
		var cy := (y + 0.25) / 0.25
		var g := exp(-(cx * cx + cy * cy)) * pow(fz, 2.0)
		x += sxs * cheek * g * 0.5
		z -= cheek * g * 0.5
	return Vector3(x, yy, z)


static func _build_head(p: Dictionary) -> ArrayMesh:
	var rings := 30
	var segs := 40
	var rows: Array = []
	for i in rings + 1:
		var phi := float(i) / float(rings) * PI          # 0 = topo
		var row := PackedVector3Array()
		for j in segs:
			var th := float(j) / float(segs) * TAU     # 0 = frente (-Z)
			var d := Vector3(sin(phi) * sin(th), cos(phi), -sin(phi) * cos(th))
			row.append(head_point(d, p))
		rows.append(row)
	return grid(rows, true)


## Casca que acompanha o crânio (cabelo, capuz, barba). hairline(th) devolve o ângulo
## polar máximo (rad, a partir do topo) coberto na direção th (0 = frente).
static func scalp(p: Dictionary, grow: float, hairline: Callable, segs: int = 44, rings: int = 16, inward: bool = false) -> ArrayMesh:
	var rows: Array = []
	for i in rings + 1:
		var row := PackedVector3Array()
		var k := float(i) / float(rings)
		for j in segs:
			var th := float(j) / float(segs) * TAU
			var pmax: float = hairline.call(th)
			var phi := k * pmax
			var d := Vector3(sin(phi) * sin(th), cos(phi), -sin(phi) * cos(th))
			var hp := head_point(d, p)
			# afasta da pele ao longo da direção radial (mais na nuca/topo)
			var g := grow * (1.0 + 0.35 * maxf(0.0, d.y))
			row.append(hp + d * g)
		rows.append(row)
	return grid(rows, true, inward)


## Retalho da superfície da cabeça (barba, sombra do capuz): faixa polar phi0..phi1
## (rad a partir do topo) e azimute th0..th1 (0 = frente).
static func head_patch(p: Dictionary, grow: float, phi0: float, phi1: float, th0: float, th1: float, segs: int = 24, rings: int = 10) -> ArrayMesh:
	var rows: Array = []
	for i in rings + 1:
		var phi := lerpf(phi0, phi1, float(i) / float(rings))
		var row := PackedVector3Array()
		for j in segs:
			var th := lerpf(th0, th1, float(j) / float(segs - 1))
			var d := Vector3(sin(phi) * sin(th), cos(phi), -sin(phi) * cos(th))
			# encolhe nas bordas para fundir com a pele
			var e := minf(minf(float(i), float(rings - i)) / 2.0, minf(float(j), float(segs - 1 - j)) / 3.0)
			row.append(head_point(d, p) + d * grow * clampf(e, 0.15, 1.0))
		rows.append(row)
	return grid(rows, false)


## Direção unitária a partir de ângulo polar (do topo) e azimute (0 = frente, +X à direita).
static func dir(phi: float, th: float) -> Vector3:
	return Vector3(sin(phi) * sin(th), cos(phi), -sin(phi) * cos(th))


## Ponto na superfície do crânio (com afastamento) — usado para enraizar mechas.
static func on_head(p: Dictionary, phi: float, th: float, out: float) -> Vector3:
	var d := dir(phi, th)
	return head_point(d, p) + d * out


# ------------------------------------------------------------------ abas e caixas

## Aba de chapéu: anel com caimento (droop), ondulação e borda enrolada.
## side: 0 = as duas faces, 1 = só a de cima, 2 = só a de baixo (para cores diferentes).
static func brim(inner: float, outer: float, droop: float, wave: float, thickness: float, segs: int = 64, squash: float = 0.94, side: int = 0) -> ArrayMesh:
	var key := "brim|%f|%f|%f|%f|%f|%d|%f|%d" % [inner, outer, droop, wave, thickness, segs, squash, side]
	return cached(key, func():
		var rows: Array = []
		var nr := 9
		# superfície de cima (de dentro para fora) e de baixo (de fora para dentro)
		var profile: Array = []
		for i in nr:
			var t := float(i) / float(nr - 1)
			profile.append([lerpf(inner, outer, t), -droop * t * t, thickness * 0.5])
		for pass_i in 2:
			if (side == 1 and pass_i == 1) or (side == 2 and pass_i == 0):
				continue
			var seq: Array = profile.duplicate()
			if pass_i == 1:
				seq.reverse()
			for e in seq:
				var r: float = e[0]
				var yb: float = e[1]
				var ht: float = e[2]
				var row := PackedVector3Array()
				for j in segs:
					var th := float(j) / float(segs) * TAU
					var tt := (r - inner) / (outer - inner)
					var wv := wave * tt * tt * (sin(th * 3.0 + 0.6) * 0.6 + sin(th * 5.0) * 0.4)
					var y := yb + wv + (ht if pass_i == 0 else -ht)
					# borda levemente virada para cima na frente e atrás
					y += droop * 0.35 * tt * tt * tt * absf(cos(th))
					row.append(Vector3(sin(th) * r, y, -cos(th) * r * squash))
				rows.append(row)
		return grid(rows, true))


## Caixa com quinas arredondadas (chanfro liso) — tira o aspecto "quadrado" de props.
static func rounded_box(size: Vector3, bevel: float) -> ArrayMesh:
	var key := "rbox|%s|%f" % [str(size), bevel]
	return cached(key, func():
		var b := clampf(bevel, 0.0005, minf(size.x, minf(size.y, size.z)) * 0.5 - 0.0005)
		var inner := size * 0.5 - Vector3(b, b, b)
		var q := 3
		var rows: Array = []
		var nrows: Array = []
		# tampa de cima (polo), hemisfério superior, hemisfério inferior, tampa de baixo
		var phis: Array = [0.0]
		var ys: Array = [1.0]
		for i in q + 1:
			phis.append(float(i) / float(q) * PI * 0.5)
			ys.append(1.0)
		for i in q + 1:
			phis.append(PI * 0.5 + float(i) / float(q) * PI * 0.5)
			ys.append(-1.0)
		phis.append(PI)
		ys.append(-1.0)
		var corner_x := [1.0, 1.0, -1.0, -1.0]
		var corner_z := [-1.0, 1.0, 1.0, -1.0]
		for i in phis.size():
			var phi: float = phis[i]
			var sy: float = ys[i]
			var row := PackedVector3Array()
			var nrow := PackedVector3Array()
			var pole := i == 0 or i == phis.size() - 1
			for quad in 4:
				for jj in q + 1:
					var th := (float(quad) + float(jj) / float(q)) * PI * 0.5
					var d := Vector3(sin(phi) * sin(th), cos(phi), -sin(phi) * cos(th))
					var c := Vector3(inner.x * corner_x[quad], inner.y * sy, inner.z * corner_z[quad])
					if pole:
						c = Vector3(0, inner.y * sy, 0)
						d = Vector3(0, sy, 0)
					row.append(c + d * b)
					nrow.append(d)
			rows.append(row)
			nrows.append(nrow)
		return grid(rows, true, false, 1.0, [], nrows))
