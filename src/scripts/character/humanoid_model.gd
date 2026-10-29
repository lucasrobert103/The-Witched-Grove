class_name HumanoidModel
extends Node3D
## Personagem em estilo realista-anime, todo gerado em código com malhas orgânicas:
## corpo contínuo com proporções reais (~6,5 cabeças), braços com cotovelo e mãos com
## dedos, pernas com joelho, rosto esculpido com olhos pintados em alta definição,
## cabelo em mechas com brilho de fios e roupas com dobras que balançam.
## A aparência vem de data/npcs/npcs.json → "appearance". Frente = -Z.

const ANKLE_Y := 0.065
const THIGH := 0.36
const SHIN := 0.36
const WAIST_Y := 0.9
## Estilização: cabeça maior que a real (≈4,8 cabeças de altura) — expressiva e fofa,
## como nos RPGs de anime atuais; o corpo segue proporções naturais.
const HEAD_STYLE := 1.36

var appearance: Dictionary = {}
var move_amount: float = 0.0          # 0 parado .. 1 correndo
var cast_timer: float = 0.0
var talk_timer: float = 0.0
var wave_timer: float = 0.0
var ghost: bool = false : set = set_ghost
var anime: bool = false

var _t: float = 0.0
var _phase: float = 0.0
var _blink: float = 2.0
var _blink_v: float = 0.0
var _mouth_v: float = 0.0
var _height: float = 1.0
var _wide: float = 1.0
var _fem: bool = false
var _hp: Dictionary = {}              # forma da cabeça
var _head_y: float = 0.586           # centro da cabeça (altura dos olhos) acima da cintura
var _head_s: float = 1.0
var _body: Node3D
var _torso: Node3D
var _head: Node3D
var _skirt: Node3D
var _thigh_l: Node3D
var _thigh_r: Node3D
var _shin_l: Node3D
var _shin_r: Node3D
var _foot_l: Node3D
var _foot_r: Node3D
var _arm_l: Node3D
var _arm_r: Node3D
var _fore_l: Node3D
var _fore_r: Node3D
var _hand_l: Node3D
var _hand_r: Node3D
var _hat: Node3D
var _hat_tip: Node3D
var _charm: Node3D
var _lantern: Node3D
var _wand_tip: Node3D
var _crystal: MeshInstance3D
var _crystal_light: OmniLight3D
var _face_mi: MeshInstance3D
var _hair_mis: Array[MeshInstance3D] = []
var _cloth_mis: Array[MeshInstance3D] = []
var _ghost_mat: StandardMaterial3D
var _prev_pos := Vector3.INF
var _sway_hair := Vector3.ZERO
var _sway_cloth := Vector3.ZERO
var _book_pose := false
var _cane := false


func build(p_appearance: Dictionary) -> void:
	appearance = p_appearance
	for c in get_children():
		c.queue_free()
	_hair_mis.clear()
	_cloth_mis.clear()
	_hat = null
	_hat_tip = null
	_charm = null
	_lantern = null
	_wand_tip = null
	_crystal = null
	_crystal_light = null
	anime = appearance.get("style", "") == "anime"
	_height = float(appearance.get("height", 1.0))
	_wide = 1.22 if appearance.get("build", "slim") == "round" else 1.0
	_fem = appearance.get("figure", "") == "f"
	var acc: Array = appearance.get("accessories", [])
	_book_pose = "book" in acc
	_cane = "cane" in acc
	scale = Vector3.ONE * _height
	_body = MeshKit.pivot(self, Vector3.ZERO, "Body")
	_build_legs(acc)
	_build_lower(acc)
	_build_torso(acc)
	_build_arms(acc)
	_build_head(acc)
	if appearance.get("age", "") == "elder":
		_torso.rotation.x = deg_to_rad(7)
	_ghost_mat = Toon.translucent(Color("#b9a8ff"), 0.35, 0.6)


# ---------------------------------------------------------------- materiais

func _c(key: String, fallback: String) -> Color:
	return Color(appearance.get(key, fallback))


func _mi(parent: Node3D, mesh: Mesh, mat: Material, pos: Vector3 = Vector3.ZERO, rot_deg: Vector3 = Vector3.ZERO, scl: Vector3 = Vector3.ONE) -> MeshInstance3D:
	return MeshKit.part(parent, mesh, mat, pos, rot_deg, scl)


## Junta várias malhas (com transformações) numa só — menos chamadas de desenho.
static func merge(parts: Array) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for p in parts:
		var e: Array = p
		var m: Mesh = e[0]
		var tr: Transform3D = e[1] if e.size() > 1 else Transform3D.IDENTITY
		st.append_from(m, 0, tr)
	return st.commit()


# ---------------------------------------------------------------- pernas

func _build_legs(acc: Array) -> void:
	var outfit_kind: String = appearance.get("outfit", "robe")
	var skin := _c("skin", "#e0ac8a")
	var leg_mat: Material = CharMat.skin(skin)
	if appearance.has("legwear_color"):
		leg_mat = CharMat.fabric(_c("legwear_color", "#2a2224"), {"rough": 0.6, "sheen": 0.55, "weave": 3000.0, "weave_strength": 0.2})
	elif outfit_kind in ["coat", "tunic"]:
		leg_mat = CharMat.fabric(_c("accent_color", "#5a4a3a").darkened(0.45))
	var shoe_c := _c("boot_color", "") if appearance.has("boot_color") else _c("outfit_color", "#5a4a8a").darkened(0.6)
	var m_shoe := CharMat.leather(shoe_c)
	var m_sole := CharMat.leather(Color("#2a1c14"), {"rough": 0.8})
	var hip_x := 0.085 * _wide
	var thick := 1.18 if _wide > 1.0 else (0.9 if _fem else 1.0)
	var thigh_mesh := OrganicMesh.cached("thigh|%f" % thick, func():
		return OrganicMesh.tube([Vector3(0, 0.02, 0), Vector3(0, -0.12, -0.008), Vector3(0, -0.28, -0.004), Vector3(0, -THIGH, 0.004)], [0.07 * thick, 0.064 * thick, 0.052 * thick, 0.042 * thick], {"segs": 16, "round_start": true}))
	var shin_mesh := OrganicMesh.cached("shin|%f" % thick, func():
		return OrganicMesh.tube([Vector3(0, 0.0, 0.0), Vector3(0, -0.1, 0.014), Vector3(0, -0.26, 0.006), Vector3(0, -SHIN, 0.0)], [0.041 * thick, 0.044 * thick, 0.03 * thick, 0.023 * thick], {"segs": 16, "round_start": true}))
	var foot_mesh := OrganicMesh.cached("foot", func():
		return OrganicMesh.tube([Vector3(0, -0.02, 0.04), Vector3(0, -0.034, -0.015), Vector3(0, -0.044, -0.08), Vector3(0, -0.05, -0.125)], [0.034, 0.039, 0.034, 0.02], {"segs": 14, "flat": 0.38, "up": Vector3.UP, "round_start": true, "round_end": true}))
	var sole_mesh := OrganicMesh.cached("sole", func():
		return OrganicMesh.tube([Vector3(0, -0.058, 0.04), Vector3(0, -0.061, -0.02), Vector3(0, -0.063, -0.085), Vector3(0, -0.064, -0.13)], [0.034, 0.039, 0.035, 0.022], {"segs": 14, "flat": 0.82, "up": Vector3.UP, "round_start": true, "round_end": true}))
	var boot_mesh := OrganicMesh.cached("boot", func():
		return OrganicMesh.tube([Vector3(0, -0.06, 0.0), Vector3(0, -0.14, 0.014), Vector3(0, -0.28, 0.008), Vector3(0, -SHIN - 0.01, 0.0)], [0.049, 0.049, 0.037, 0.033], {"segs": 16}))
	var cuff_mesh := OrganicMesh.cached("bootcuff", func():
		return OrganicMesh.loft([[-0.085, 0.052, 0.053], [-0.05, 0.058, 0.06], [-0.04, 0.056, 0.058]], 20, 2))
	for side: float in [-1.0, 1.0]:
		var thigh := MeshKit.pivot(_body, Vector3(side * hip_x, ANKLE_Y + SHIN + THIGH, 0.0))
		thigh.rotation.z = side * 0.02
		_mi(thigh, thigh_mesh, leg_mat)
		var shin := MeshKit.pivot(thigh, Vector3(0, -THIGH, 0.004))
		_mi(shin, shin_mesh, leg_mat)
		var foot := MeshKit.pivot(shin, Vector3(0, -SHIN, 0.0))
		_mi(foot, foot_mesh, m_shoe)
		_mi(foot, sole_mesh, m_sole)
		if "tall_boots" in acc:
			_mi(shin, boot_mesh, m_shoe)
			_mi(shin, cuff_mesh, m_shoe)
		elif outfit_kind in ["coat", "tunic"]:
			# barra da calça por cima do sapato
			_mi(shin, OrganicMesh.cached("pantcuff", func():
				return OrganicMesh.loft([[-SHIN + 0.02, 0.036, 0.038], [-SHIN + 0.06, 0.04, 0.042], [-SHIN + 0.1, 0.042, 0.044]], 18, 2)), leg_mat)
		if side < 0.0:
			_thigh_l = thigh
			_shin_l = shin
			_foot_l = foot
		else:
			_thigh_r = thigh
			_shin_r = shin
			_foot_r = foot


# ---------------------------------------------------------------- roupa de baixo

func _skirt_sections(kind: String) -> Array:
	var w := _wide
	match kind:
		"coat_dress":
			return [[0.035, 0.124 * w, 0.088 * w], [-0.06, 0.15 * w, 0.108 * w], [-0.16, 0.178 * w, 0.13 * w], [-0.27, 0.203 * w, 0.152 * w], [-0.38, 0.232 * w, 0.177 * w], [-0.48, 0.256 * w, 0.2 * w]]
		"robe":
			return [[0.035, 0.126 * w, 0.09 * w], [-0.12, 0.172 * w, 0.125 * w], [-0.34, 0.212 * w, 0.163 * w], [-0.58, 0.258 * w, 0.207 * w], [-0.8, 0.3 * w, 0.252 * w]]
		"dress":
			return [[0.035, 0.124 * w, 0.088 * w], [-0.1, 0.165 * w, 0.12 * w], [-0.28, 0.212 * w, 0.168 * w], [-0.46, 0.258 * w, 0.21 * w], [-0.55, 0.278 * w, 0.23 * w]]
		"coat":
			return [[0.035, 0.128 * w, 0.092 * w], [-0.1, 0.165 * w, 0.122 * w], [-0.28, 0.19 * w, 0.145 * w], [-0.48, 0.215 * w, 0.17 * w]]
	return [[0.035, 0.13 * w, 0.094 * w], [-0.08, 0.162 * w, 0.12 * w], [-0.2, 0.178 * w, 0.132 * w], [-0.26, 0.184 * w, 0.138 * w]]


func _build_lower(acc: Array) -> void:
	var kind: String = appearance.get("outfit", "robe")
	var outfit := _c("outfit_color", "#5a4a8a")
	var accent := _c("accent_color", "#f3c74f")
	var lining := _c("lining_color", "") if appearance.has("lining_color") else outfit.darkened(0.4)
	_skirt = MeshKit.pivot(_body, Vector3(0, WAIST_Y, 0), "Skirt")
	var secs := _skirt_sections(kind)
	var hem: float = (secs[secs.size() - 1] as Array)[0]
	var fold_n := 7 if kind in ["coat_dress", "coat", "tunic"] else 9
	var opts := {"folds": 0.08, "fold_n": fold_n, "fold_y": [-0.08, hem], "fold_seed": 0.7}
	if kind == "coat":
		opts["open"] = 0.55
	var mesh := OrganicMesh.loft(secs, 48, 4, opts)
	var m_skirt := CharMat.fabric(outfit, {"inner": lining, "sway_top": 0.0, "sway_len": -hem, "sheen": 0.4})
	_cloth_mis.append(_mi(_skirt, mesh, m_skirt))
	# barra de outra cor (mesmas dobras, um pouco por fora)
	var last: Array = secs[secs.size() - 1]
	var prev: Array = secs[secs.size() - 2]
	var trim_h := 0.035
	var t := trim_h / absf(float(last[0]) - float(prev[0]))
	var band := [[float(last[0]) + trim_h, lerpf(float(last[1]), float(prev[1]), t) * 1.012, lerpf(float(last[2]), float(prev[2]), t) * 1.012], [float(last[0]) - 0.002, float(last[1]) * 1.012, float(last[2]) * 1.012]]
	var bopts := opts.duplicate()
	var trim_c := outfit.darkened(0.3) if kind == "coat_dress" else accent
	_cloth_mis.append(_mi(_skirt, OrganicMesh.loft(band, 48, 2, bopts), CharMat.fabric(trim_c, {"inner": lining, "sway_top": 0.0, "sway_len": -hem, "sheen": 0.5})))
	if kind == "coat_dress":
		# costura central e botões
		var m_btn := CharMat.metal(_c("metal_color", "#c9a25a"), 0.35)
		var seam_pts: Array = []
		for s in secs:
			var sa: Array = s
			seam_pts.append(Vector3(0.0, float(sa[0]), -float(sa[2]) - 0.002))
		_cloth_mis.append(_mi(_skirt, OrganicMesh.tube(seam_pts, [0.004, 0.004, 0.004, 0.004, 0.004, 0.004], {"segs": 6}), CharMat.fabric(outfit.darkened(0.4), {"sway_top": 0.0, "sway_len": -hem})))
		for k in 3:
			var yy := -0.02 - k * 0.1
			_mi(_skirt, MeshKit.sphere(0.0075, 12, 8), m_btn, Vector3(0.022, yy, -_rz_at(secs, yy) - 0.004))
	if "apron" in acc:
		var asecs: Array = []
		for s in secs:
			var sa: Array = s
			if float(sa[0]) < hem * 0.75:
				break
			asecs.append([float(sa[0]), float(sa[1]) * 1.03, float(sa[2]) * 1.05])
		asecs.append([hem * 0.8, float(secs[secs.size() - 2][1]) * 1.03, float(secs[secs.size() - 2][2]) * 1.05])
		var amesh := OrganicMesh.loft(asecs, 20, 3, {"arc": [-1.05, 1.05], "folds": 0.03, "fold_n": 5, "fold_y": [-0.05, hem]})
		_cloth_mis.append(_mi(_skirt, amesh, CharMat.fabric(Color("#f3ece0"), {"sway_top": 0.0, "sway_len": -hem, "weave": 600.0})))
	if "stars" in acc and kind in ["robe", "dress"]:
		var m_star := Toon.glow(accent, 1.4)
		var rng := RandomNumberGenerator.new()
		rng.seed = 7
		for i in 12:
			var ang := rng.randf_range(-PI, PI)
			var yy := rng.randf_range(hem * 0.85, -0.12)
			var rx := _rx_at(secs, yy) + 0.006
			var rz := _rz_at(secs, yy) + 0.006
			var s := _mi(_skirt, MeshKit.star(0.022, 0.009, 0.004), m_star, Vector3(sin(ang) * rx, yy, -cos(ang) * rz), Vector3(0, rad_to_deg(-ang) + 180.0, 0))
			s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _sec_lerp(secs: Array, y: float, idx: int) -> float:
	for i in secs.size() - 1:
		var a: Array = secs[i]
		var b: Array = secs[i + 1]
		if y <= float(a[0]) and y >= float(b[0]):
			var t := (float(a[0]) - y) / maxf(0.0001, float(a[0]) - float(b[0]))
			return lerpf(float(a[idx]), float(b[idx]), t)
	return float((secs[secs.size() - 1] as Array)[idx])


func _rx_at(secs: Array, y: float) -> float:
	return _sec_lerp(secs, y, 1)


func _rz_at(secs: Array, y: float) -> float:
	return _sec_lerp(secs, y, 2)


# ---------------------------------------------------------------- tronco

func _torso_sections() -> Array:
	var w := _wide
	var hip := (0.152 if _fem else 0.138) * w
	var waist := (0.118 if _fem else 0.13) * (1.3 if w > 1.0 else 1.0)
	var chest := (0.142 if _fem else 0.158) * (1.12 if w > 1.0 else 1.0)
	var sh := 0.162 if _fem else 0.185
	var dz := 1.3 if w > 1.0 else 1.0
	return [
		[-0.14, hip, 0.104 * dz, 0.006],
		[-0.05, hip * 0.93, 0.094 * dz, 0.002],
		[0.03, waist, 0.083 * dz, 0.0],
		[0.11, waist * 1.07, 0.088 * dz, -0.003],
		[0.19, chest, 0.097 * (1.15 if w > 1.0 else 1.0), -0.006],
		[0.27, sh * 0.97, 0.092, 0.0],
		[0.322, sh, 0.078, 0.008],
		[0.355, sh * 0.66, 0.06, 0.012],
		[0.385, 0.05, 0.047, 0.012],
	]


func _build_torso(acc: Array) -> void:
	var outfit := _c("outfit_color", "#5a4a8a")
	var accent := _c("accent_color", "#f3c74f")
	var metal := CharMat.metal(_c("metal_color", "#c9a25a"), 0.3)
	_torso = MeshKit.pivot(_body, Vector3(0, WAIST_Y, 0), "Torso")
	var secs := _torso_sections()
	var opts := {"cap_bottom": true}
	if _fem:
		opts["front_bulge"] = [0.175, 0.026, 0.055]
	_mi(_torso, OrganicMesh.loft(secs, 40, 4, opts), CharMat.fabric(outfit, {"sheen": 0.35}))
	# gola
	_mi(_torso, OrganicMesh.loft([[0.35, 0.066, 0.062, 0.01], [0.39, 0.046, 0.045, 0.01], [0.412, 0.041, 0.04, 0.008]], 28, 3), CharMat.fabric(outfit.darkened(0.25)))
	# pescoço
	var skin := _c("skin", "#e0ac8a")
	_mi(_torso, OrganicMesh.cached("neck", func():
		return OrganicMesh.tube([Vector3(0, 0.35, 0.012), Vector3(0, 0.42, 0.006), Vector3(0, 0.47, 0.0)], [0.04, 0.037, 0.036], {"segs": 16})), CharMat.skin(skin))
	if appearance.get("outfit", "") in ["robe", "dress"]:
		# faixa na cintura
		_mi(_torso, _ring_mesh(0.03, secs, 0.006, 0.014, 0.75), CharMat.fabric(accent, {"sheen": 0.55}))
	if "belt" in acc:
		var m_belt := CharMat.leather(_c("belt_color", "#7a4a2a"))
		_mi(_torso, _ring_mesh(-0.035, secs, 0.009, 0.016, 0.55), m_belt)
		var front_z := -_sec_lerp_t(secs, -0.035, 2) - 0.018
		_mi(_torso, OrganicMesh.rounded_box(Vector3(0.045, 0.036, 0.008), 0.004), metal, Vector3(0, -0.035, front_z))
		_mi(_torso, OrganicMesh.rounded_box(Vector3(0.028, 0.02, 0.01), 0.003), m_belt, Vector3(0, -0.035, front_z - 0.002))
	if "strap" in acc:
		var pts: Array = []
		var radii: Array = []
		for k in 16:
			var a := float(k) / 16.0 * TAU
			var y := 0.11 + 0.17 * sin(a)
			var rx := _sec_lerp_t(secs, y, 1) + 0.01
			var rz := _sec_lerp_t(secs, y, 2) + 0.012
			pts.append(Vector3(sin(a) * rx, y, -cos(a) * rz))
			radii.append(0.011)
		_mi(_torso, OrganicMesh.tube(pts, radii, {"segs": 8, "flat": 0.7, "closed": true}), CharMat.leather(_c("belt_color", "#7a4a2a").darkened(0.1)))
		_mi(_torso, OrganicMesh.rounded_box(Vector3(0.03, 0.03, 0.008), 0.004), metal, Vector3(0.09, 0.18, -0.1), Vector3(0, 0, -40))
	if "satchel" in acc:
		var bag := MeshKit.pivot(_torso, Vector3(-0.17 * _wide, -0.12, 0.02))
		bag.rotation_degrees = Vector3(0, 80, 6)
		var m_bag := CharMat.leather(Color("#8a5a3a"))
		_mi(bag, OrganicMesh.rounded_box(Vector3(0.13, 0.11, 0.055), 0.016), m_bag)
		_mi(bag, OrganicMesh.rounded_box(Vector3(0.135, 0.06, 0.012), 0.006), CharMat.leather(Color("#6a3f26")), Vector3(0, 0.03, -0.028), Vector3(-8, 0, 0))
		_mi(bag, OrganicMesh.rounded_box(Vector3(0.018, 0.022, 0.006), 0.003), metal, Vector3(0, 0.0, -0.036))
	if "capelet" in acc or "shawl" in acc:
		var shawl := "shawl" in acc
		var cape_c := _c("cape_color", "") if appearance.has("cape_color") else accent.darkened(0.1)
		var inner := _c("lining_color", "") if appearance.has("lining_color") else cape_c.darkened(0.3)
		var low := 0.1 if shawl else 0.14
		var w := _wide
		low = 0.13 if shawl else 0.235
		var csecs := [[0.395, 0.05, 0.049, 0.01], [0.375, 0.115, 0.088, 0.01], [0.345, 0.185 * w, 0.118 * w, 0.006], [0.29, 0.222 * w, 0.142 * w, 0.004], [low, 0.252 * w, 0.168 * w, 0.004]]
		var copts := {"folds": 0.09, "fold_n": 9, "fold_y": [0.34, low], "fold_seed": 1.3}
		if shawl:
			copts["open"] = 0.5
		var m_cape := CharMat.fabric(cape_c, {"inner": inner, "sway_top": 0.36, "sway_len": 0.25, "sheen": 0.5, "weave": 500.0 if shawl else 900.0, "weave_strength": 0.8 if shawl else 0.35})
		_cloth_mis.append(_mi(_torso, OrganicMesh.loft(csecs, 48, 4, copts), m_cape))
		if not shawl:
			_mi(_torso, MeshKit.sphere(0.013, 12, 8), metal, Vector3(0, 0.375, -0.072))
	if "scarf" in acc:
		# cachecol de tricô: gola enrolada com dobras e duas pontas caindo na frente
		var scarf_c := _c("scarf_color", "#2fb9a8")
		var m_scarf := CharMat.fabric(scarf_c, {"weave": 420.0, "weave_strength": 1.4, "sheen": 0.3, "grain": 0.1})
		_mi(_torso, OrganicMesh.loft([[0.345, 0.082, 0.078, 0.006], [0.37, 0.088, 0.084, 0.008], [0.395, 0.074, 0.07, 0.01], [0.415, 0.06, 0.057, 0.01]], 36, 3, {"folds": 0.07, "fold_n": 7, "fold_y": [0.42, 0.34], "cap_bottom": false}), m_scarf)
		var tails := [
			[Vector3(0.035, 0.36, -0.085), Vector3(0.05, 0.3, -0.11), Vector3(0.06, 0.22, -0.12), Vector3(0.062, 0.15, -0.118)],
			[Vector3(0.012, 0.355, -0.088), Vector3(0.018, 0.29, -0.112), Vector3(0.02, 0.2, -0.124)],
		]
		for tl in tails:
			var pts: Array = tl
			var rr: Array = []
			for i in pts.size():
				rr.append(0.026 if i < pts.size() - 1 else 0.022)
			_mi(_torso, OrganicMesh.tube(pts, rr, {"segs": 10, "flat": 0.72, "up": Vector3(0, 0, -1)}), m_scarf)
			# franjas na ponta
			var tip: Vector3 = pts[pts.size() - 1]
			for f in 4:
				var fx := (float(f) - 1.5) * 0.011
				_mi(_torso, OrganicMesh.tube([tip + Vector3(fx, 0.004, 0), tip + Vector3(fx, -0.022, -0.002)], [0.003, 0.002], {"segs": 5}), m_scarf)


## Anel que acompanha a seção do tronco numa altura (cinto, faixa).
func _ring_mesh(y: float, secs: Array, out: float, r: float, flat: float) -> ArrayMesh:
	var pts: Array = []
	var radii: Array = []
	var rx := _sec_lerp_t(secs, y, 1) + out
	var rz := _sec_lerp_t(secs, y, 2) + out
	for k in 16:
		var a := float(k) / 16.0 * TAU
		pts.append(Vector3(sin(a) * rx, y, -cos(a) * rz))
		radii.append(r)
	return OrganicMesh.tube(pts, radii, {"segs": 8, "flat": flat, "closed": true})


## Interpolação nas seções do tronco (y crescente).
func _sec_lerp_t(secs: Array, y: float, idx: int) -> float:
	for i in secs.size() - 1:
		var a: Array = secs[i]
		var b: Array = secs[i + 1]
		if y >= float(a[0]) and y <= float(b[0]):
			var t := (y - float(a[0])) / maxf(0.0001, float(b[0]) - float(a[0]))
			return lerpf(float(a[idx]), float(b[idx]), t)
	return float((secs[0] as Array)[idx]) if y < float((secs[0] as Array)[0]) else float((secs[secs.size() - 1] as Array)[idx])


# ---------------------------------------------------------------- braços e mãos

func _build_arms(acc: Array) -> void:
	var outfit := _c("outfit_color", "#5a4a8a")
	var accent := _c("accent_color", "#f3c74f")
	var skin := _c("skin", "#e0ac8a")
	var kind: String = appearance.get("outfit", "robe")
	var m_sleeve := CharMat.fabric(outfit, {"sheen": 0.35})
	var gloves := "gloves" in acc
	var m_hand: Material = CharMat.leather(Color("#2e221c")) if gloves else CharMat.skin(skin)
	var sh_x := (0.136 if _fem else 0.158) * (1.0 + (_wide - 1.0) * 0.6)
	var thick := 1.15 if _wide > 1.0 else 1.0
	var upper := OrganicMesh.cached("uarm|%f" % thick, func():
		return OrganicMesh.tube([Vector3(0, 0.02, 0), Vector3(0, -0.13, 0.004), Vector3(0, -0.27, 0)], [0.05 * thick, 0.042 * thick, 0.036 * thick], {"segs": 14, "round_start": true}))
	var fore := OrganicMesh.cached("farm|%f" % thick, func():
		return OrganicMesh.tube([Vector3(0, 0.01, 0), Vector3(0, -0.12, -0.004), Vector3(0, -0.24, 0)], [0.036 * thick, 0.031 * thick, 0.024], {"segs": 14, "round_start": true}))
	for side: float in [-1.0, 1.0]:
		var arm := MeshKit.pivot(_torso, Vector3(side * sh_x, 0.3, 0.004))
		arm.rotation.z = side * 0.16
		_mi(arm, upper, m_sleeve)
		var fa := MeshKit.pivot(arm, Vector3(0, -0.27, 0))
		fa.rotation.x = 0.18
		if kind in ["robe", "dress"]:
			_cloth_mis.append(_mi(fa, OrganicMesh.cached("bell", func():
				return OrganicMesh.loft([[0.02, 0.04, 0.04], [-0.1, 0.05, 0.05], [-0.2, 0.072, 0.072], [-0.23, 0.08, 0.08]], 22, 3, {"folds": 0.06, "fold_n": 5, "fold_y": [-0.05, -0.23]})), CharMat.fabric(outfit, {"inner": outfit.darkened(0.4), "sway_top": 0.0, "sway_len": 0.25})))
			_mi(fa, fore, CharMat.skin(skin))
		else:
			_mi(fa, fore, m_sleeve)
			_mi(fa, OrganicMesh.cached("cuff", func():
				return OrganicMesh.loft([[-0.2, 0.03, 0.03], [-0.17, 0.034, 0.034], [-0.15, 0.033, 0.033]], 16, 2)), CharMat.fabric(accent.darkened(0.2) if kind == "coat_dress" else outfit.darkened(0.25)))
		var hand := MeshKit.pivot(fa, Vector3(0, -0.245, 0))
		_build_hand(hand, side, m_hand, gloves)
		if side < 0.0:
			_arm_l = arm
			_fore_l = fa
			_hand_l = hand
		else:
			_arm_r = arm
			_fore_r = fa
			_hand_r = hand
	var metal := CharMat.metal(_c("metal_color", "#c9a25a"), 0.3)
	if "wand" in acc:
		var wand := MeshKit.pivot(_hand_r, Vector3(-0.004, -0.085, -0.016), "Wand")
		wand.rotation_degrees = Vector3(-100, 0, 0)
		var m_wand := CharMat.wood(Color("#5a3a26"))
		_mi(wand, OrganicMesh.cached("wand", func():
			return OrganicMesh.tube([Vector3(0, -0.07, 0), Vector3(0, 0.0, 0), Vector3(0, 0.12, 0.004), Vector3(0, 0.28, 0)], [0.009, 0.0085, 0.006, 0.003], {"segs": 10, "round_start": true, "round_end": true})), m_wand)
		_mi(wand, OrganicMesh.cached("wandring", func():
			return OrganicMesh.loft([[0.0, 0.0095, 0.0095], [0.012, 0.0098, 0.0098]], 12, 2)), metal)
		_wand_tip = MeshKit.pivot(wand, Vector3(0, 0.29, 0), "WandTip")
		MeshKit.part(_wand_tip, MeshKit.sphere(0.008, 12, 8), Toon.glow(Color("#fff3c4"), 3.0), Vector3.ZERO, Vector3.ZERO, Vector3.ONE, false)
	if "staff" in acc:
		var staff := MeshKit.pivot(_hand_r, Vector3(0, -0.06, -0.01), "Staff")
		staff.rotation_degrees = Vector3(-10, 0, -12)
		_mi(staff, OrganicMesh.tube([Vector3(0, -0.72, 0), Vector3(0, 0.0, 0.01), Vector3(0, 0.62, 0), Vector3(0.03, 0.72, 0), Vector3(0.0, 0.78, 0)], [0.016, 0.017, 0.019, 0.016, 0.01], {"segs": 10}), CharMat.wood(Color("#7a4f2e")))
		_crystal = _mi(staff, MeshKit.crystal(0.04), Toon.glow(Color("#c58cff"), 2.2), Vector3(0, 0.84, 0))
		_crystal_light = MeshKit.light(staff, Color("#c58cff"), 0.5, 2.5, Vector3(0, 0.86, 0))
		if _wand_tip == null:
			# os feitiços saem do cristal do cajado
			_wand_tip = MeshKit.pivot(staff, Vector3(0, 0.84, 0), "WandTip")
	if "lantern" in acc:
		_lantern = MeshKit.pivot(_hand_l, Vector3(0.0, -0.075, -0.01), "Lantern")
		var m_iron := CharMat.metal(Color("#3a3028"), 0.5)
		_mi(_lantern, OrganicMesh.tube([Vector3(0, 0.02, 0), Vector3(0, -0.02, 0)], [0.004, 0.004], {"segs": 6}), m_iron)
		_mi(_lantern, OrganicMesh.loft([[-0.03, 0.024, 0.024], [-0.02, 0.03, 0.03], [-0.012, 0.012, 0.012]], 16, 2, {"cap_top": true}), m_iron)
		_mi(_lantern, MeshKit.sphere(0.034, 20, 14), Toon.glow(Color("#9dff6a"), 2.2), Vector3(0, -0.07, 0), Vector3.ZERO, Vector3(1.0, 1.2, 1.0)).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_mi(_lantern, MeshKit.sphere(0.04, 20, 14), CharMat.glass(Color("#e8ffd8"), 0.25), Vector3(0, -0.07, 0), Vector3.ZERO, Vector3(1.0, 1.22, 1.0)).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		for k in 4:
			var a := k * TAU / 4.0 + 0.4
			_mi(_lantern, OrganicMesh.tube([Vector3(sin(a) * 0.026, -0.024, cos(a) * 0.026), Vector3(sin(a) * 0.042, -0.07, cos(a) * 0.042), Vector3(sin(a) * 0.026, -0.118, cos(a) * 0.026)], [0.003, 0.003, 0.003], {"segs": 5}), m_iron)
		_mi(_lantern, OrganicMesh.loft([[-0.13, 0.012, 0.012], [-0.122, 0.03, 0.03], [-0.112, 0.024, 0.024]], 16, 2, {"cap_bottom": true}), m_iron)
		MeshKit.light(_lantern, Color("#9dff6a"), 0.22, 0.9, Vector3(0, -0.07, 0))
	if _cane:
		var cane := MeshKit.pivot(_hand_l, Vector3(0, -0.05, -0.02), "Cane")
		_mi(cane, OrganicMesh.tube([Vector3(0.03, 0.03, 0), Vector3(0, 0.04, 0), Vector3(0, 0.0, 0), Vector3(0, -0.4, -0.02), Vector3(0, -0.78, -0.04)], [0.014, 0.015, 0.015, 0.014, 0.013], {"segs": 8, "round_end": true}), CharMat.wood(Color("#6b4a2a")))
	if _book_pose:
		var m_cover := CharMat.leather(Color("#7a2f3a"))
		var book := MeshKit.pivot(_hand_l, Vector3(0.02, -0.06, -0.06))
		book.rotation_degrees = Vector3(0, 0, 80)
		_mi(book, OrganicMesh.rounded_box(Vector3(0.17, 0.035, 0.23), 0.008), m_cover)
		_mi(book, OrganicMesh.rounded_box(Vector3(0.16, 0.03, 0.218), 0.004), Toon.mat(Color("#f3e8cc")), Vector3(0.006, 0, 0))


func _build_hand(hand: Node3D, side: float, mat: Material, gloves: bool) -> void:
	var k := "%s|%s" % [str(side), str(gloves)]
	var mesh := OrganicMesh.cached("hand|" + k, func():
		var g := 1.08 if gloves else 1.0
		var parts: Array = []
		parts.append([OrganicMesh.rounded_box(Vector3(0.026, 0.07, 0.068) * g, 0.012), Transform3D(Basis(), Vector3(0, -0.04, 0))])
		for f in 4:
			var z := lerpf(-0.024, 0.024, float(f) / 3.0) * g
			var ln: float = [0.052, 0.058, 0.055, 0.045][f]
			var curl := -side * 0.012
			parts.append([OrganicMesh.tube([Vector3(0, -0.07, z), Vector3(curl * 0.4, -0.07 - ln * 0.5, z), Vector3(curl, -0.07 - ln, z + 0.004)], [0.0085 * g, 0.0078 * g, 0.0068 * g], {"segs": 8, "round_end": true, "round_start": true})])
		parts.append([OrganicMesh.tube([Vector3(-side * 0.004, -0.02, -0.03), Vector3(-side * 0.012, -0.05, -0.044), Vector3(-side * 0.016, -0.075, -0.048)], [0.011 * g, 0.009 * g, 0.0075 * g], {"segs": 8, "round_end": true, "round_start": true})])
		return merge(parts))
	_mi(hand, mesh, mat)
	if gloves:
		_mi(hand, OrganicMesh.cached("glovecuff", func():
			return OrganicMesh.loft([[0.025, 0.027, 0.04], [0.0, 0.03, 0.045], [-0.02, 0.026, 0.04]], 16, 2)), mat)


# ---------------------------------------------------------------- cabeça e rosto

func _head_params() -> Dictionary:
	var age: String = appearance.get("age", "adult")
	var p := {"width": 0.072, "height": 0.116, "depth": 0.09, "jaw": 0.6, "chin": 0.01, "nose": 0.0045, "cheek": 0.004}
	if not _fem:
		p = {"width": 0.077, "height": 0.12, "depth": 0.094, "jaw": 0.42, "chin": 0.014, "nose": 0.008, "cheek": 0.003}
	if age == "child":
		p = {"width": 0.074, "height": 0.11, "depth": 0.09, "jaw": 0.5, "chin": 0.008, "nose": 0.003, "cheek": 0.006}
	if age == "elder":
		p["nose"] = 0.009
		p["jaw"] = float(p["jaw"]) - 0.08
	if _wide > 1.0:
		p["width"] = float(p["width"]) * 1.08
		p["jaw"] = float(p["jaw"]) - 0.15
		p["cheek"] = 0.007
	return p


func _face_params() -> Dictionary:
	var age: String = appearance.get("age", "adult")
	var acc: Array = appearance.get("accessories", [])
	var hair := _c("hair_color", "#3a2a1a")
	var skin := _c("skin", "#e0ac8a")
	var dark_skin := skin.get_luminance() < 0.35
	var f := {
		"eye_color": _c("eye_color", "#4a3a2a"),
		"brow_color": hair.darkened(0.3) if hair.get_luminance() > 0.25 else hair.lightened(0.05),
		"lash_color": Color("#2a1810") if not dark_skin else Color("#120a08"),
		"lip_color": skin.lerp(Color("#c0505a"), 0.45),
		"eye_center": Vector2(0.03, -0.004),
		"eye_half": Vector2(0.0135, 0.0098),
		"eye_tilt": 0.05,
		"brow_y": 0.026,
		"mouth_y": -0.066,
		"mouth_w": 0.0095,
		"blush": 0.2,
		"lash_weight": 0.6,
		"freckles": 1.0 if "freckles" in acc else 0.0,
		"wrinkles": 1.0 if age == "elder" else 0.0,
		"beard_shadow": 0.25 if appearance.get("beard", "none") != "none" else 0.0,
	}
	if anime:
		f["eye_center"] = Vector2(0.031, -0.012)
		f["eye_half"] = Vector2(0.0205, 0.0198)
		f["eye_tilt"] = 0.1
		f["brow_y"] = 0.029
		f["blush"] = 0.5
		f["lash_weight"] = 1.0
		f["mouth_y"] = -0.066
		f["mouth_w"] = 0.0075
		f["freckles"] = 0.35 if "freckles" in acc else 0.0
	elif age == "child":
		f["eye_half"] = Vector2(0.0155, 0.0135)
		f["blush"] = 0.45
		f["lash_weight"] = 0.7
	elif _fem:
		f["eye_half"] = Vector2(0.0145, 0.011)
		f["lash_weight"] = 0.85
		f["blush"] = 0.26
	if age == "elder":
		f["eye_half"] = Vector2(0.0135, 0.008)
	return f


func _build_head(acc: Array) -> void:
	var age: String = appearance.get("age", "adult")
	_head_s = HEAD_STYLE * (1.14 if age == "child" else 1.0)
	_head_y = 0.44 + 0.097 * _head_s
	_hp = _head_params()
	_head = MeshKit.pivot(_torso, Vector3(0, _head_y, -0.004), "Head")
	_head.scale = Vector3.ONE * _head_s
	var skin := _c("skin", "#e0ac8a")
	_face_mi = _mi(_head, OrganicMesh.head(_hp), CharMat.face(skin, _face_params()))
	var ear := OrganicMesh.cached("ear", func():
		return OrganicMesh.tube([Vector3(0, 0.016, 0.004), Vector3(0.004, 0.0, 0.006), Vector3(0, -0.016, 0.0)], [0.009, 0.011, 0.007], {"segs": 10, "flat": 0.55, "up": Vector3.RIGHT, "round_start": true, "round_end": true}))
	for sx: float in [-1.0, 1.0]:
		_mi(_head, ear, CharMat.skin(skin), Vector3(sx * (float(_hp.width) - 0.004), -0.012, 0.012), Vector3(0, sx * 15.0, 0))
	_build_beard(appearance.get("beard", "none"))
	_build_hair(appearance.get("hair_style", "short"))
	_build_hat(appearance.get("hat", "none"))
	if "glasses" in acc:
		_build_glasses()


func _build_glasses() -> void:
	var m := CharMat.metal(Color("#c9a24a"), 0.3)
	var ez := OrganicMesh.head_point(OrganicMesh.dir(PI * 0.5, 0.42), _hp).z - 0.012
	for sx: float in [-1.0, 1.0]:
		var ring: Array = []
		var rr: Array = []
		for k in 14:
			var a := float(k) / 14.0 * TAU
			ring.append(Vector3(sx * 0.031 + cos(a) * 0.02, -0.006 + sin(a) * 0.016, ez))
			rr.append(0.0022)
		_mi(_head, OrganicMesh.tube(ring, rr, {"segs": 6, "closed": true}), m)
		_mi(_head, MeshKit.sphere(0.019, 16, 10), CharMat.glass(Color("#e8f4ff"), 0.18), Vector3(sx * 0.031, -0.006, ez + 0.001), Vector3.ZERO, Vector3(1.0, 0.82, 0.12))
		_mi(_head, OrganicMesh.tube([Vector3(sx * 0.051, -0.004, ez), Vector3(sx * (float(_hp.width) + 0.004), -0.004, -0.02), Vector3(sx * (float(_hp.width) + 0.002), -0.01, 0.03)], [0.0022, 0.0022, 0.0022], {"segs": 6}), m)
	_mi(_head, OrganicMesh.tube([Vector3(-0.011, -0.002, ez - 0.002), Vector3(0, 0.002, ez - 0.006), Vector3(0.011, -0.002, ez - 0.002)], [0.002, 0.002, 0.002], {"segs": 6}), m)


func _build_beard(kind: String) -> void:
	if kind == "none":
		return
	var hc := _c("hair_color", "#3a2a1a")
	var m := CharMat.hair(hc, 0.0)
	_mi(_head, OrganicMesh.head_patch(_hp, 0.012, 1.95, 2.95, -1.75, 1.75, 28, 12), m)
	# bigode
	var parts: Array = []
	for sx: float in [-1.0, 1.0]:
		var a := OrganicMesh.on_head(_hp, 2.02, sx * 0.05, 0.006)
		var b := OrganicMesh.on_head(_hp, 2.1, sx * 0.32, 0.007)
		var c := OrganicMesh.on_head(_hp, 2.25, sx * 0.5, 0.004)
		parts.append([OrganicMesh.tube([a, b, c], [0.008, 0.007, 0.002], {"segs": 8, "flat": 0.4})])
	if kind == "long":
		for i in 7:
			var th := lerpf(-0.7, 0.7, float(i) / 6.0)
			var r := OrganicMesh.on_head(_hp, 2.7, th, 0.012)
			var ln := 0.2 + 0.06 * (1.0 - absf(th))
			parts.append([OrganicMesh.tube([r, r + Vector3(th * 0.02, -ln * 0.4, -0.02), r + Vector3(th * 0.01, -ln, -0.01)], [0.02, 0.016, 0.002], {"segs": 8, "flat": 0.4, "up": Vector3.FORWARD})])
	_hair_mis.append(_mi(_head, merge(parts), CharMat.hair(hc, 1.0)))


# ---------------------------------------------------------------- cabelo

## Linha do cabelo: ângulo polar máximo coberto pelo couro cabeludo em cada direção.
func _hairline(th: float) -> float:
	var c := cos(th)
	return lerpf(2.22, 0.98, (c + 1.0) * 0.5) + 0.2 * pow(sin(th), 2.0)


## Uma mecha (fita achatada ao longo da curva), pronta para merge().
func _lock(pts: Array, radii: Array, flat: float, up: Vector3, twist: float = 0.0) -> Array:
	return [OrganicMesh.tube(pts, radii, {"segs": 8, "sub": 4, "flat": flat, "up": up, "twist": twist})]


func _build_hair(style: String) -> void:
	if style == "bald":
		if appearance.get("age", "") == "elder":
			# coroa de cabelos ralos nas laterais
			var hc0 := _c("hair_color", "#c8c8c8")
			_hair_mis.append(_mi(_head, OrganicMesh.head_patch(_hp, 0.007, 1.45, 2.05, 1.2, TAU - 1.2, 32, 8), CharMat.hair(hc0, 0.0)))
		return
	var hc := _c("hair_color", "#3a2a1a")
	var g := 0.009
	_hair_mis.append(_mi(_head, OrganicMesh.scalp(_hp, g, _hairline), CharMat.hair(hc, 0.0)))
	var parts: Array = []
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(str(appearance.get("hair_color", "")) + style)
	# franja
	var bang_n := 11 if anime else 8
	var bang_len := 1.52 if anime else (1.3 if style == "short" else 1.38)
	if style in ["curly"]:
		bang_n = 0
	for i in bang_n:
		var k := float(i) / float(bang_n - 1)
		var th := lerpf(-1.05, 1.05, k) + rng.randf_range(-0.05, 0.05)
		var center := 1.0 - absf(th) / 1.05
		var tip_phi := bang_len + center * 0.08 - absf(th) * 0.12 + (0.05 if i % 2 == 0 else -0.03)
		var sweep := 0.18 if anime else 0.1
		var pts := [
			OrganicMesh.on_head(_hp, 0.3, th * 0.45, g),
			OrganicMesh.on_head(_hp, 0.7, th * 0.8, g + 0.004),
			OrganicMesh.on_head(_hp, 0.98, th, g + 0.01),
			OrganicMesh.on_head(_hp, 1.2, th + sweep * 0.4, g + 0.016),
			OrganicMesh.on_head(_hp, (1.2 + tip_phi) * 0.5, th + sweep * 0.8, g + 0.014),
			OrganicMesh.on_head(_hp, tip_phi, th + sweep, g + 0.006),
		]
		var w := 0.017 if anime else 0.02
		parts.append(_lock(pts, [w * 0.8, w * 1.1, w * 1.2, w, w * 0.6, 0.0015], 0.62, OrganicMesh.dir(1.0, th)))
	# mechas laterais que emolduram o rosto
	if style in ["long", "long_braid", "twin_tails_long"] or anime:
		for sx: float in [-1.0, 1.0]:
			for j in 3:
				var th := sx * (1.38 + j * 0.15)
				var drop := 0.07 + (0.06 if anime else 0.02) - j * 0.02
				var a := OrganicMesh.on_head(_hp, 0.5, th * 0.7, g)
				var b := OrganicMesh.on_head(_hp, 1.05, th, g + 0.006)
				var c := OrganicMesh.on_head(_hp, 1.65, th - sx * 0.05, g + 0.02)
				var d := OrganicMesh.on_head(_hp, 2.05, th - sx * 0.1, g + 0.018)
				var e := d + Vector3(sx * 0.004, -drop * 0.6, -0.006)
				var f := d + Vector3(sx * 0.002, -drop, -0.002)
				parts.append(_lock([a, b, c, d, e, f], [0.014, 0.018, 0.02, 0.017, 0.012, 0.0015], 0.55, OrganicMesh.dir(1.6, th)))
	# volume de trás
	match style:
		"long", "long_braid":
			var n := 16
			var length := 0.55 if style == "long" else 0.3
			for i in n:
				var th := lerpf(1.55, TAU - 1.55, float(i) / float(n - 1)) + rng.randf_range(-0.04, 0.04)
				var a := OrganicMesh.on_head(_hp, 0.35, th, g)
				var b := OrganicMesh.on_head(_hp, 1.3, th, g + 0.008)
				var c := OrganicMesh.on_head(_hp, 2.1, th, g + 0.016)
				var spread := 1.0 + 0.35 * absf(sin(th))
				var d := Vector3(c.x * spread, c.y - length * 0.35, maxf(c.z, 0.0) + 0.03 + 0.03 * absf(sin(th)))
				var e := Vector3(c.x * spread * 1.1, c.y - length * 0.75, maxf(c.z, 0.0) + 0.05)
				var f := Vector3(c.x * spread * 1.05 + rng.randf_range(-0.01, 0.01), c.y - length, maxf(c.z, 0.0) + 0.045)
				parts.append(_lock([a, b, c, d, e, f], [0.02, 0.026, 0.03, 0.03, 0.024, 0.003], 0.5, OrganicMesh.dir(1.5, th), rng.randf_range(-0.6, 0.6)))
			if style == "long_braid":
				_build_braid(parts)
		"twin_tails_long":
			for i in 9:
				var th := lerpf(2.1, TAU - 2.1, float(i) / 8.0)
				var a := OrganicMesh.on_head(_hp, 0.5, th, g)
				var b := OrganicMesh.on_head(_hp, 1.5, th, g + 0.006)
				var c := OrganicMesh.on_head(_hp, 2.18, th, g + 0.008)
				parts.append(_lock([a, b, c, c + Vector3(0, -0.03, 0.006)], [0.02, 0.026, 0.02, 0.002], 0.55, OrganicMesh.dir(1.5, th)))
			for sx: float in [-1.0, 1.0]:
				_build_tail(parts, sx, rng)
		"bun":
			var top := OrganicMesh.on_head(_hp, 0.85, PI, g + 0.03)
			var spiral: Array = []
			var sr: Array = []
			for k in 22:
				var a := float(k) / 7.0 * TAU
				var r := 0.04 * (1.0 - float(k) / 26.0)
				spiral.append(top + Vector3(cos(a) * r, sin(a) * r * 0.85 + 0.01, 0.018 - float(k) * 0.0012))
				sr.append(0.017)
			parts.append([OrganicMesh.tube(spiral, sr, {"segs": 8, "flat": 0.25})])
			for i in 10:
				var th := lerpf(1.5, TAU - 1.5, float(i) / 9.0)
				var a := OrganicMesh.on_head(_hp, 1.9, th, g)
				parts.append(_lock([a, OrganicMesh.on_head(_hp, 1.4, lerpf(th, PI, 0.4), g + 0.01), top + Vector3(0, -0.02, -0.01)], [0.016, 0.018, 0.006], 0.5, OrganicMesh.dir(1.5, th)))
		"short":
			for i in 18:
				var th := lerpf(1.25, TAU - 1.25, float(i) / 17.0) + rng.randf_range(-0.05, 0.05)
				var tip := _hairline(th) + 0.08
				var a := OrganicMesh.on_head(_hp, 0.4, th, g)
				var b := OrganicMesh.on_head(_hp, tip * 0.6, th, g + 0.008)
				var c := OrganicMesh.on_head(_hp, tip, th + rng.randf_range(-0.1, 0.1), g + 0.012)
				parts.append(_lock([a, b, c], [0.02, 0.024, 0.002], 0.55, OrganicMesh.dir(1.5, th)))
		"curly":
			for i in 46:
				var th := rng.randf_range(-PI, PI)
				var phi := rng.randf_range(0.1, _hairline(th) + 0.1)
				var root := OrganicMesh.on_head(_hp, phi, th, g)
				var nrm := OrganicMesh.dir(phi, th)
				var t1 := nrm.cross(Vector3.UP).normalized() if absf(nrm.y) < 0.95 else Vector3.RIGHT
				var t2 := nrm.cross(t1)
				var coil: Array = []
				var cr: Array = []
				for k in 7:
					var a := float(k) / 6.0 * TAU * 1.2
					coil.append(root + nrm * (0.004 + k * 0.004) + (t1 * cos(a) + t2 * sin(a)) * 0.011)
					cr.append(0.011 if k < 6 else 0.004)
				parts.append([OrganicMesh.tube(coil, cr, {"segs": 7})])
	if not parts.is_empty():
		_hair_mis.append(_mi(_head, merge(parts), CharMat.hair(hc, 1.0)))


## Rabo de cavalo duplo: feixe de mechas torcidas presas por laço, até a cintura.
func _build_tail(parts: Array, sx: float, rng: RandomNumberGenerator) -> void:
	var g := 0.009
	var tie := OrganicMesh.on_head(_hp, 1.32, sx * 2.1, g + 0.02)
	var path := [
		tie,
		tie + Vector3(sx * 0.04, -0.012, 0.022),
		tie + Vector3(sx * 0.08, -0.1, 0.04),
		tie + Vector3(sx * 0.095, -0.27, 0.035),
		tie + Vector3(sx * 0.088, -0.46, 0.02),
		tie + Vector3(sx * 0.074, -0.63, 0.03),
		tie + Vector3(sx * 0.062, -0.76, 0.045),
	]
	var bundle := [0.008, 0.03, 0.044, 0.042, 0.034, 0.022, 0.004]
	var n := 9
	for k in n:
		var a0 := float(k) / float(n) * TAU
		var pts: Array = []
		var rr: Array = []
		for i in path.size():
			var a := a0 + float(i) * 0.38 * sx
			var bw: float = bundle[i]
			var off := Vector3(cos(a) * bw * 0.72, 0.0, sin(a) * bw * 0.72)
			var jit := Vector3(rng.randf_range(-0.004, 0.004), 0, rng.randf_range(-0.004, 0.004)) * float(i > 1)
			pts.append((path[i] as Vector3) + off + jit)
			rr.append(maxf(0.0015, bw * 0.48))
		var lenk := 1.0 - rng.randf_range(0.0, 0.08)
		pts[pts.size() - 1] = (pts[pts.size() - 2] as Vector3).lerp(pts[pts.size() - 1], lenk)
		parts.append(_lock(pts, rr, 0.3, Vector3(0, 0, 1), sx * 0.8))
	# mechas puxadas do couro cabeludo até o laço
	for j in 6:
		var th := sx * lerpf(1.3, 2.6, float(j) / 5.0)
		var phi := lerpf(0.45, 1.5, float(j % 3) / 2.0)
		var a := OrganicMesh.on_head(_hp, phi, th, g)
		var mid := OrganicMesh.on_head(_hp, lerpf(phi, 1.32, 0.5), lerpf(th, sx * 2.1, 0.5), g + 0.008)
		parts.append(_lock([a, mid, tie], [0.014, 0.016, 0.01], 0.6, OrganicMesh.dir(phi, th)))
	# laço / prendedor
	var accent := _c("accent_color", "#d98a2b")
	var m_tie := CharMat.fabric(accent, {"sheen": 0.6, "weave": 1400.0})
	var ring: Array = []
	var rr2: Array = []
	var axis := ((path[1] as Vector3) - tie).normalized()
	var t1 := axis.cross(Vector3.UP).normalized()
	var t2 := axis.cross(t1).normalized()
	var center := tie.lerp(path[1], 0.6)
	for k in 12:
		var a := float(k) / 12.0 * TAU
		ring.append(center + (t1 * cos(a) + t2 * sin(a)) * 0.018)
		rr2.append(0.009)
	_mi(_head, OrganicMesh.tube(ring, rr2, {"segs": 8, "closed": true}), m_tie)
	for lob: float in [-1.0, 1.0]:
		var lp: Array = [center, center + t2 * 0.028 * lob + t1 * 0.012 + axis * -0.008, center + t2 * 0.045 * lob + axis * 0.004, center + t2 * 0.026 * lob - t1 * 0.012 + axis * 0.01, center]
		_mi(_head, OrganicMesh.tube(lp, [0.006, 0.01, 0.012, 0.01, 0.006], {"segs": 8, "flat": 0.6, "up": t1}), m_tie)


## Trança de três mechas que sai de trás da orelha direita, passa por cima do ombro
## e cai na frente do peito, presa por um laço (a "assinatura" da Asterion).
func _build_braid(parts: Array) -> void:
	var g := 0.009
	var hp := Vector3(0, _head_y, -0.004)
	var tor := [Vector3(0.1, 0.43, 0.045), Vector3(0.135, 0.37, -0.03), Vector3(0.132, 0.29, -0.108), Vector3(0.118, 0.19, -0.138), Vector3(0.112, 0.09, -0.124), Vector3(0.11, 0.025, -0.114)]
	var ctrl: Array = [OrganicMesh.on_head(_hp, 1.8, 2.15, g + 0.012)]
	for q in tor:
		ctrl.append(((q as Vector3) - hp) / _head_s)
	var path := OrganicMesh.smooth_points(ctrl, 6)
	var n := path.size()
	var r0 := 0.026 / _head_s
	for strand in 3:
		var pts: Array = []
		var rr: Array = []
		for i in n:
			var p: Vector3 = path[i]
			var t := ((path[mini(i + 1, n - 1)] as Vector3) - (path[maxi(i - 1, 0)] as Vector3)).normalized()
			var n1 := t.cross(Vector3(0, 0, 1)).normalized()
			if n1.length_squared() < 0.01:
				n1 = Vector3.RIGHT
			var n2 := t.cross(n1).normalized()
			var k := float(i) / float(n - 1)
			var taper := lerpf(0.75, 1.0, sin(minf(k * 3.0, 1.0) * PI * 0.5)) * lerpf(1.0, 0.7, k)
			var a := k * 26.0 + float(strand) * TAU / 3.0
			pts.append(p + (n1 * cos(a) + n2 * sin(a)) * r0 * 0.55 * taper)
			rr.append(r0 * 0.62 * taper)
		parts.append([OrganicMesh.tube(pts, rr, {"segs": 8, "sub": 2})])
	var tie: Vector3 = path[n - 1]
	var dir_end := (tie - (path[n - 2] as Vector3)).normalized()
	var tuft := [tie, tie + dir_end * 0.03 / _head_s + Vector3(0, 0, -0.004), tie + dir_end * 0.075 / _head_s + Vector3(0.004, 0, -0.008)]
	parts.append(_lock(tuft, [r0 * 0.7, r0 * 0.85, 0.002], 0.25, Vector3.BACK))
	# laço turquesa
	var m_tie := CharMat.fabric(_c("scarf_color", "#2fb9a8"), {"sheen": 0.6, "weave": 1400.0})
	var t1 := dir_end.cross(Vector3(0, 0, 1)).normalized()
	var t2 := dir_end.cross(t1).normalized()
	var ring: Array = []
	var rr2: Array = []
	for k in 12:
		var a2 := float(k) / 12.0 * TAU
		ring.append(tie + (t1 * cos(a2) + t2 * sin(a2)) * r0 * 0.75)
		rr2.append(r0 * 0.32)
	_mi(_head, OrganicMesh.tube(ring, rr2, {"segs": 8, "closed": true}), m_tie)
	for lob: float in [-1.0, 1.0]:
		var lp: Array = [tie, tie + t1 * r0 * 1.4 * lob + t2 * r0 * 0.5, tie + t1 * r0 * 2.3 * lob - dir_end * r0 * 0.2, tie + t1 * r0 * 1.3 * lob - t2 * r0 * 0.6, tie]
		_mi(_head, OrganicMesh.tube(lp, [r0 * 0.3, r0 * 0.5, r0 * 0.6, r0 * 0.5, r0 * 0.3], {"segs": 8, "flat": 0.6, "up": t2}), m_tie)
		_mi(_head, OrganicMesh.tube([tie, tie + dir_end * r0 * 1.6 + t1 * r0 * 0.6 * lob, tie + dir_end * r0 * 3.2 + t1 * r0 * 1.1 * lob], [r0 * 0.3, r0 * 0.28, r0 * 0.12], {"segs": 6, "flat": 0.7, "up": t2}), m_tie)


# ---------------------------------------------------------------- chapéus

func _crown(parent: Node3D, pts: Array, radii: Array, mat: Material, flat: float) -> MeshInstance3D:
	return _mi(parent, OrganicMesh.tube(pts, radii, {"segs": 28, "sub": 5, "flat": flat, "up": Vector3.RIGHT}), mat)


func _build_hat(kind: String) -> void:
	var hat_c := _c("hat_color", "") if appearance.has("hat_color") else _c("outfit_color", "#3a2068")
	var accent := _c("accent_color", "#f3c74f")
	var metal := CharMat.metal(_c("metal_color", "#c9a25a"), 0.3)
	var m_hat := CharMat.fabric(hat_c, {"rough": 0.9, "sheen": 0.3, "weave": 700.0, "weave_strength": 0.5, "grain": 0.16})
	match kind:
		"witch_wide", "witch":
			var wide := kind == "witch_wide"
			_hat = MeshKit.pivot(_head, Vector3(0, 0.072, 0.008), "Hat")
			# inclinado para trás: o rosto aparece mesmo com a câmera acima
			_hat.rotation_degrees = Vector3(5, 0, 5)
			var outer := 0.31 if wide else 0.275
			var under := hat_c.lerp(_c("hat_under", ""), 0.4) if appearance.has("hat_under") else hat_c.darkened(0.2)
			_mi(_hat, OrganicMesh.brim(0.094, outer, 0.04 if wide else 0.034, 0.012 if wide else 0.016, 0.0055, 80, 1.0, 1), m_hat, Vector3.ZERO, Vector3.ZERO, Vector3(1.0, 1.0, 1.08))
			_mi(_hat, OrganicMesh.brim(0.094, outer, 0.04 if wide else 0.034, 0.012 if wide else 0.016, 0.0055, 80, 1.0, 2), CharMat.fabric(under, {"rough": 0.9}), Vector3.ZERO, Vector3.ZERO, Vector3(1.0, 1.0, 1.08))
			var pts := [Vector3(0, -0.012, 0), Vector3(0, 0.07, 0.004), Vector3(0, 0.14, 0.016), Vector3(0.006, 0.2, 0.042), Vector3(0.026, 0.24, 0.09), Vector3(0.056, 0.245, 0.135), Vector3(0.084, 0.226, 0.168)]
			if not wide:
				# chapéu clássico: cone alto que entorta no alto e cai para trás
				pts = [Vector3(0, -0.012, 0), Vector3(0, 0.09, 0.006), Vector3(0, 0.18, 0.018), Vector3(-0.004, 0.27, 0.04), Vector3(0.012, 0.34, 0.08), Vector3(0.045, 0.37, 0.13), Vector3(0.085, 0.35, 0.17)]
			var radii := [0.1, 0.092, 0.077, 0.058, 0.038, 0.02, 0.003]
			_crown(_hat, pts, radii, m_hat, 0.08)
			# faixa e fivela
			_mi(_hat, OrganicMesh.loft([[0.0, 0.101, 0.11], [0.04, 0.095, 0.103]], 40, 2), CharMat.fabric(accent, {"sheen": 0.55, "weave": 1500.0}), Vector3.ZERO, Vector3.ZERO, Vector3(1.0, 1.0, 1.0))
			_mi(_hat, OrganicMesh.rounded_box(Vector3(0.042, 0.036, 0.008), 0.005), metal, Vector3(0.03, 0.02, -0.105), Vector3(0, -16, 0))
			_mi(_hat, OrganicMesh.rounded_box(Vector3(0.026, 0.022, 0.01), 0.004), CharMat.fabric(accent), Vector3(0.03, 0.02, -0.108), Vector3(0, -16, 0))
			_hat_tip = MeshKit.pivot(_hat, pts[4], "HatTip")
			if wide or anime:
				_charm = MeshKit.pivot(_hat, pts[6], "Charm")
				_mi(_charm, OrganicMesh.tube([Vector3.ZERO, Vector3(0, -0.05, 0), Vector3(0, -0.09, 0)], [0.0018, 0.0018, 0.0018], {"segs": 5}), CharMat.leather(Color("#3a2a1a")))
				_mi(_charm, MeshKit.star(0.03, 0.013, 0.01), Toon.glow(Color("#f3c74f"), 1.6), Vector3(0, -0.11, 0))
			if not wide:
				_mi(_hat, MeshKit.star(0.03, 0.013, 0.008), Toon.glow(Color("#fff3b0"), 1.6), Vector3(-0.03, 0.022, -0.106), Vector3(0, 16, 0))
		"hood":
			_hat = MeshKit.pivot(_head, Vector3.ZERO, "Hood")
			var m_hood := CharMat.fabric(hat_c, {"inner": hat_c.darkened(0.45), "sheen": 0.45})
			_mi(_hat, OrganicMesh.scalp(_hp, 0.032, _hood_line, 48, 18), m_hood)
			_mi(_hat, OrganicMesh.tube([OrganicMesh.on_head(_hp, 1.3, PI, 0.04), OrganicMesh.on_head(_hp, 1.9, PI, 0.06) + Vector3(0, -0.02, 0.04), OrganicMesh.on_head(_hp, 2.3, PI, 0.05) + Vector3(0, -0.08, 0.06)], [0.05, 0.03, 0.004], {"segs": 12}), m_hood)
			# caimento nos ombros
			_mi(_hat, OrganicMesh.loft([[-0.2, 0.17, 0.14, 0.02], [-0.15, 0.13, 0.11, 0.015], [-0.1, 0.095, 0.098, 0.01]], 36, 3, {"open": 1.6, "folds": 0.04, "fold_n": 6}), m_hood)
		"straw":
			_hat = MeshKit.pivot(_head, Vector3(0, 0.075, 0.006), "Straw")
			_hat.rotation_degrees.x = -5
			var m_straw := CharMat.fabric(Color("#d9b45a"), {"rough": 0.9, "weave": 420.0, "weave_strength": 1.6, "sheen": 0.2, "grain": 0.2})
			_mi(_hat, OrganicMesh.brim(0.094, 0.24, 0.018, 0.008, 0.006, 64, 1.0, 0), m_straw, Vector3.ZERO, Vector3.ZERO, Vector3(1.0, 1.0, 1.08))
			_mi(_hat, OrganicMesh.loft([[-0.005, 0.1, 0.108], [0.05, 0.095, 0.102], [0.08, 0.08, 0.086], [0.092, 0.05, 0.054]], 36, 3, {"cap_top": true}), m_straw)
			_mi(_hat, OrganicMesh.loft([[0.0, 0.102, 0.11], [0.025, 0.099, 0.106]], 36, 2), CharMat.fabric(Color("#c4473a")))
		"flower_crown":
			_hat = MeshKit.pivot(_head, Vector3.ZERO, "Crown")
			var ring: Array = []
			var rr: Array = []
			for k in 16:
				var th := float(k) / 16.0 * TAU
				ring.append(OrganicMesh.on_head(_hp, 0.78 + 0.05 * sin(th * 3.0), th, 0.02))
				rr.append(0.006)
			_mi(_hat, OrganicMesh.tube(ring, rr, {"segs": 6, "closed": true}), Toon.mat(Color("#5f8f4a"), {"surface": "leaf"}))
			var cols := ["#ff9fb2", "#fff3a0", "#c8a2ff", "#ffffff", "#ff9fb2", "#8fd6ff", "#fff3a0", "#ffffff"]
			for i in cols.size():
				var th := float(i) / float(cols.size()) * TAU
				var p := OrganicMesh.on_head(_hp, 0.78, th, 0.028)
				var fl := MeshKit.pivot(_hat, p)
				var m_pet := Toon.mat(Color(cols[i]), {"surface": "leaf", "roughness": 0.6})
				for pk in 5:
					var a := float(pk) / 5.0 * TAU
					_mi(fl, MeshKit.sphere(0.011, 10, 6), m_pet, Vector3(cos(a) * 0.011, sin(a) * 0.011 + 0.004, 0), Vector3.ZERO, Vector3(1.0, 1.0, 0.4))
				_mi(fl, MeshKit.sphere(0.006, 8, 6), Toon.mat(Color("#f3c74f")), Vector3(0, 0.004, -0.003))
				fl.rotation.y = -th
		"goggles":
			_hat = MeshKit.pivot(_head, Vector3.ZERO, "Goggles")
			var ring: Array = []
			var rr: Array = []
			for k in 18:
				var th := float(k) / 18.0 * TAU
				ring.append(OrganicMesh.on_head(_hp, 0.72, th, 0.018))
				rr.append(0.011)
			_mi(_hat, OrganicMesh.tube(ring, rr, {"segs": 8, "flat": 0.6, "closed": true}), CharMat.leather(Color("#4a3426")))
			for sx: float in [-1.0, 1.0]:
				var p := OrganicMesh.on_head(_hp, 0.62, sx * 0.42, 0.03)
				var lens := MeshKit.pivot(_hat, p)
				lens.rotation_degrees = Vector3(-50, -sx * 22.0, 0)
				_mi(lens, OrganicMesh.loft([[-0.012, 0.024, 0.024], [0.012, 0.022, 0.022], [0.016, 0.018, 0.018]], 20, 2), CharMat.metal(Color("#c9a24a"), 0.3), Vector3.ZERO, Vector3(90, 0, 0))
				_mi(lens, MeshKit.sphere(0.018, 16, 8), CharMat.glass(Color("#9fe8ff"), 0.5), Vector3(0, 0.0, -0.012), Vector3.ZERO, Vector3(1, 1, 0.35))
		"cap":
			_hat = MeshKit.pivot(_head, Vector3.ZERO, "Cap")
			_mi(_hat, OrganicMesh.scalp(_hp, 0.022, _cap_line, 40, 12), m_hat)
			_mi(_hat, OrganicMesh.tube([OrganicMesh.on_head(_hp, 1.05, -0.95, 0.024), OrganicMesh.on_head(_hp, 1.08, 0.0, 0.024) + Vector3(0, 0.006, -0.06), OrganicMesh.on_head(_hp, 1.05, 0.95, 0.024)], [0.012, 0.05, 0.012], {"segs": 14, "flat": 0.88, "up": Vector3.UP}), m_hat)
			_mi(_hat, MeshKit.sphere(0.012, 10, 8), CharMat.fabric(accent), OrganicMesh.on_head(_hp, 0.0, 0.0, 0.026))


func _hood_line(th: float) -> float:
	var c := cos(th)
	return lerpf(2.45, 1.2, (c + 1.0) * 0.5) + 0.25 * pow(sin(th), 2.0)


func _cap_line(_th: float) -> float:
	return 1.12


# ---------------------------------------------------------------- animação

## Posição global de onde saem os feitiços (ponta da varinha ou cristal do cajado).
func wand_tip_position() -> Vector3:
	if _wand_tip and _wand_tip.is_inside_tree():
		return _wand_tip.global_position
	if _hand_r and _hand_r.is_inside_tree():
		return _hand_r.global_position
	return global_position + Vector3(0, 1.2, 0)


## Altura (em espaço do modelo, já com a escala) do centro do rosto — enquadramento de retratos.
func face_height() -> float:
	return (WAIST_Y + _head_y) * _height


func play_cast() -> void:
	cast_timer = 0.7


func play_talk(duration: float = 2.0) -> void:
	talk_timer = duration


func play_wave() -> void:
	wave_timer = 1.4


func set_ghost(v: bool) -> void:
	ghost = v
	_apply_overlay(self, _ghost_mat if v else null)


func _apply_overlay(n: Node, m: Material) -> void:
	for c in n.get_children():
		if c is MeshInstance3D:
			c.material_overlay = m
			c.transparency = 0.55 if m != null else 0.0
		_apply_overlay(c, m)


static func _w(delta: float, k: float) -> float:
	return 1.0 - exp(-k * delta)


func _process(delta: float) -> void:
	if _body == null or delta <= 0.0:
		return
	_t += delta
	var mv := move_amount
	_phase += delta * (4.2 + 5.8 * mv) * (1.0 if mv > 0.02 else 0.0)
	var s := sin(_phase)
	var c := cos(_phase)
	# corpo: sobe e desce a cada passo, inclina para frente ao correr
	_body.position.y = (absf(c) * 0.03 - 0.012) * mv + sin(_t * 2.0) * 0.003
	_body.rotation.x = lerpf(_body.rotation.x, -0.09 * mv, _w(delta, 6.0))
	_torso.rotation.y = s * 0.07 * mv
	_torso.scale = Vector3(1.0, 1.0 + sin(_t * 2.0) * 0.008, 1.0 + sin(_t * 2.0) * 0.006)
	_skirt.rotation.y = -s * 0.04 * mv
	# pernas: quadril, joelho e tornozelo
	var stride := 0.5 * mv
	_thigh_l.rotation.x = s * stride
	_thigh_r.rotation.x = -s * stride
	_shin_l.rotation.x = -maxf(0.0, -c) * 0.95 * mv - 0.03
	_shin_r.rotation.x = -maxf(0.0, c) * 0.95 * mv - 0.03
	_foot_l.rotation.x = -(_thigh_l.rotation.x + _shin_l.rotation.x) * 0.7
	_foot_r.rotation.x = -(_thigh_r.rotation.x + _shin_r.rotation.x) * 0.7
	# braços: balanço oposto às pernas, cotovelo dobra mais ao correr
	var swing := -s * 0.5 * mv
	var idle := sin(_t * 1.7) * 0.025
	if not _book_pose:
		_arm_l.rotation.x = lerpf(_arm_l.rotation.x, swing + idle, _w(delta, 10.0))
		_fore_l.rotation.x = lerpf(_fore_l.rotation.x, 0.18 + 0.5 * mv, _w(delta, 10.0))
	else:
		_arm_l.rotation.x = lerpf(_arm_l.rotation.x, 0.25, _w(delta, 8.0))
		_fore_l.rotation.x = lerpf(_fore_l.rotation.x, 1.35, _w(delta, 8.0))
	if _cane:
		_arm_l.rotation.x = lerpf(_arm_l.rotation.x, 0.3 + swing * 0.3, _w(delta, 8.0))
		_fore_l.rotation.x = lerpf(_fore_l.rotation.x, -0.2, _w(delta, 8.0))
	if cast_timer > 0.0:
		cast_timer -= delta
		var k := sin(clampf(cast_timer / 0.7, 0.0, 1.0) * PI)
		_arm_r.rotation.x = lerpf(_arm_r.rotation.x, 1.45 * k, _w(delta, 20.0))
		_arm_r.rotation.z = lerpf(_arm_r.rotation.z, 0.05, _w(delta, 20.0))
		_fore_r.rotation.x = lerpf(_fore_r.rotation.x, 0.08, _w(delta, 20.0))
		if _crystal_light:
			_crystal_light.light_energy = 0.5 + 3.0 * k
	elif wave_timer > 0.0:
		wave_timer -= delta
		_arm_r.rotation.x = lerpf(_arm_r.rotation.x, 0.25, _w(delta, 10.0))
		_arm_r.rotation.z = lerpf(_arm_r.rotation.z, 2.45, _w(delta, 10.0))
		_fore_r.rotation.x = lerpf(_fore_r.rotation.x, 0.25, _w(delta, 10.0))
		_fore_r.rotation.z = sin(_t * 12.0) * 0.45
	else:
		_arm_r.rotation.x = lerpf(_arm_r.rotation.x, -swing + sin(_t * 1.7 + 1.0) * 0.025, _w(delta, 10.0))
		_arm_r.rotation.z = lerpf(_arm_r.rotation.z, 0.16, _w(delta, 8.0))
		_fore_r.rotation.x = lerpf(_fore_r.rotation.x, 0.18 + 0.5 * mv + (0.25 if _wand_tip else 0.0), _w(delta, 10.0))
		_fore_r.rotation.z = lerpf(_fore_r.rotation.z, 0.0, _w(delta, 10.0))
		if _crystal_light:
			_crystal_light.light_energy = lerpf(_crystal_light.light_energy, 0.5 + sin(_t * 3.0) * 0.1, _w(delta, 4.0))
	if _crystal:
		_crystal.rotation.y += delta * 1.5
	# cabeça e rosto
	var nod := 0.0
	var mouth := 0.0
	if talk_timer > 0.0:
		talk_timer -= delta
		nod = sin(_t * 9.0) * 0.04
		mouth = clampf(0.5 + 0.5 * sin(_t * 17.0) * sin(_t * 5.3), 0.0, 1.0)
	_head.rotation.x = nod + sin(_t * 0.8) * 0.025
	_head.rotation.y = sin(_t * 0.45) * 0.14 * (1.0 - mv)
	_blink -= delta
	var target_blink := 0.0
	if _blink < 0.0:
		target_blink = 1.0
		if _blink < -0.13:
			_blink = randf_range(2.2, 5.0)
	_blink_v = lerpf(_blink_v, target_blink, _w(delta, 32.0))
	_mouth_v = lerpf(_mouth_v, mouth, _w(delta, 18.0))
	if _face_mi:
		_face_mi.set_instance_shader_parameter("blink", _blink_v)
		_face_mi.set_instance_shader_parameter("mouth_open", _mouth_v)
		_face_mi.set_instance_shader_parameter("look", Vector2(sin(_t * 0.37) * 0.3, sin(_t * 0.23) * 0.15))
	# chapéu com mola, pingente e lanterna
	if _hat_tip:
		_hat.rotation_degrees.z = 5.0 + sin(_t * 1.3) * 0.8 + mv * s * 1.5
	if _charm:
		_charm.rotation.z = sin(_t * 2.3) * 0.3 + mv * s * 0.35
		_charm.rotation.x = sin(_t * 1.7) * 0.2 + mv * 0.4
	if _lantern:
		_lantern.rotation.x = -(_arm_l.rotation.x + _fore_l.rotation.x) * 0.85 + sin(_t * 1.9) * 0.08
	_update_sway(delta, mv, s)


## Balanço físico de cabelo e roupa: a velocidade do personagem (em espaço local)
## empurra as pontas para trás, com mola e um pouco de vento.
func _update_sway(delta: float, mv: float, s: float) -> void:
	var gp := global_position
	var vel := Vector3.ZERO
	if _prev_pos != Vector3.INF:
		vel = (gp - _prev_pos) / delta
	_prev_pos = gp
	if vel.length() > 20.0:
		vel = Vector3.ZERO
	var wind := Vector3(sin(_t * 1.1) * 0.006, 0.0, 0.004 + sin(_t * 0.7) * 0.004)
	var hb := _head.global_transform.basis.orthonormalized().inverse()
	var hv: Vector3 = hb * vel
	var target := -hv * 0.028 + wind + Vector3(0, -absf(s) * 0.012 * mv, 0)
	target = target.limit_length(0.09)
	_sway_hair = _sway_hair.lerp(target, _w(delta, 5.0))
	var bb := _skirt.global_transform.basis.orthonormalized().inverse()
	var bv: Vector3 = bb * vel
	var ct := (-bv * 0.02 + wind * 0.6 + Vector3(s * 0.012 * mv, 0, 0)).limit_length(0.07)
	_sway_cloth = _sway_cloth.lerp(ct, _w(delta, 6.0))
	for m in _hair_mis:
		m.set_instance_shader_parameter("sway", _sway_hair)
	for m in _cloth_mis:
		m.set_instance_shader_parameter("sway", _sway_cloth)
