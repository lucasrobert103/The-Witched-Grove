class_name HumanoidModel
extends Node3D
## Personagem estilizado montado com primitivas (cabeça grande, olhos expressivos,
## roupas de silhueta forte) e animado proceduralmente.
## A aparência vem de data/npcs/npcs.json → "appearance". Frente = -Z.

const OUTLINE := 0.012

var appearance: Dictionary = {}
var move_amount: float = 0.0          # 0 parado .. 1 correndo
var cast_timer: float = 0.0
var talk_timer: float = 0.0
var wave_timer: float = 0.0
var ghost: bool = false : set = set_ghost

var _t: float = 0.0
var _phase: float = 0.0
var _blink: float = 2.0
var _height: float = 1.0
var _body: Node3D
var _torso: Node3D
var _head: Node3D
var _hat: Node3D
var _hat_tip: Node3D
var _arm_l: Node3D
var _arm_r: Node3D
var _foot_l: Node3D
var _foot_r: Node3D
var _skirt: Node3D
var _eyes: Array[Node3D] = []
var _braid: Array[Node3D] = []
var _crystal_light: OmniLight3D
var _crystal: MeshInstance3D
var _ghost_mat: StandardMaterial3D


func build(p_appearance: Dictionary) -> void:
	appearance = p_appearance
	for c in get_children():
		c.queue_free()
	_eyes.clear()
	_braid.clear()
	_height = float(appearance.get("height", 1.0))
	var age: String = appearance.get("age", "adult")
	var head_scale := 1.18 if age == "child" else 1.0
	var build_kind: String = appearance.get("build", "slim")
	var wide := 1.18 if build_kind == "round" else 1.0

	var skin := Color(appearance.get("skin", "#e0ac8a"))
	var hair := Color(appearance.get("hair_color", "#3a2a1a"))
	var outfit := Color(appearance.get("outfit_color", "#5a4a8a"))
	var accent := Color(appearance.get("accent_color", "#f3c74f"))
	var eye_c := Color(appearance.get("eye_color", "#4a3a2a"))
	var acc: Array = appearance.get("accessories", [])

	var m_skin := Toon.mat(skin, {"rim": 0.25, "outline": OUTLINE})
	var m_skin_plain := Toon.mat(skin)
	var m_hair := Toon.mat(hair, {"rim": 0.4, "outline": OUTLINE})
	var m_outfit := Toon.mat(outfit, {"rim": 0.3, "outline": OUTLINE})
	var m_accent := Toon.mat(accent, {"rim": 0.5, "outline": OUTLINE * 0.7})
	var m_dark := Toon.mat(Color("#2a1d2e"))
	var m_white := Toon.mat(Color("#fbf8ff"), {"unshaded": true})
	var m_boot := Toon.mat(outfit.darkened(0.55), {"outline": OUTLINE})

	scale = Vector3.ONE * _height
	_body = MeshKit.pivot(self, Vector3.ZERO, "Body")

	# --- pés
	_foot_l = MeshKit.pivot(_body, Vector3(-0.09, 0.06, 0.0))
	_foot_r = MeshKit.pivot(_body, Vector3(0.09, 0.06, 0.0))
	for f in [_foot_l, _foot_r]:
		MeshKit.part(f, MeshKit.capsule(0.06, 0.2), m_boot, Vector3(0, 0, -0.03), Vector3(90, 0, 0))

	# --- roupa inferior
	var outfit_kind: String = appearance.get("outfit", "robe")
	_skirt = MeshKit.pivot(_body, Vector3(0, 0.42, 0), "Skirt")
	match outfit_kind:
		"robe":
			MeshKit.part(_skirt, MeshKit.cylinder(0.17 * wide, 0.36 * wide, 0.7, 18), m_outfit)
			MeshKit.part(_skirt, MeshKit.torus(0.33 * wide, 0.375 * wide, 24), m_accent, Vector3(0, -0.33, 0))
		"dress":
			MeshKit.part(_skirt, MeshKit.cylinder(0.17 * wide, 0.33 * wide, 0.62, 18), m_outfit, Vector3(0, 0.03, 0))
			MeshKit.part(_skirt, MeshKit.torus(0.3 * wide, 0.34 * wide, 24), m_accent, Vector3(0, -0.27, 0))
		"coat":
			MeshKit.part(_skirt, MeshKit.cylinder(0.18 * wide, 0.27 * wide, 0.42, 16), m_outfit, Vector3(0, 0.1, 0))
			MeshKit.part(_skirt, MeshKit.capsule(0.07, 0.38), m_boot, Vector3(-0.09, -0.18, 0))
			MeshKit.part(_skirt, MeshKit.capsule(0.07, 0.38), m_boot, Vector3(0.09, -0.18, 0))
			MeshKit.part(_skirt, MeshKit.box(Vector3(0.03, 0.4, 0.02)), m_accent, Vector3(0, 0.1, -0.2 * wide))
		_:
			MeshKit.part(_skirt, MeshKit.cylinder(0.18 * wide, 0.24 * wide, 0.32, 16), m_outfit, Vector3(0, 0.14, 0))
			var m_pants := Toon.mat(Color(appearance.get("accent_color", "#5a4a3a")).darkened(0.35), {"outline": OUTLINE})
			MeshKit.part(_skirt, MeshKit.capsule(0.075, 0.42), m_pants, Vector3(-0.09, -0.16, 0))
			MeshKit.part(_skirt, MeshKit.capsule(0.075, 0.42), m_pants, Vector3(0.09, -0.16, 0))
	if "apron" in acc:
		MeshKit.part(_skirt, MeshKit.box(Vector3(0.24 * wide, 0.36, 0.02)), Toon.mat(Color("#f6efe2"), {"outline": OUTLINE * 0.6}), Vector3(0, 0.1, -0.205 * wide), Vector3(-9, 0, 0))
	if "stars" in acc and outfit_kind in ["robe", "dress"]:
		var m_star := Toon.glow(accent, 1.2)
		var rng := RandomNumberGenerator.new()
		rng.seed = 7
		for i in 9:
			var ang := rng.randf_range(0, TAU)
			var yy := rng.randf_range(-0.28, 0.2)
			var rr := lerpf(0.36, 0.17, (yy + 0.35) / 0.7) * wide + 0.008
			var s := MeshKit.part(_skirt, MeshKit.star(0.035, 0.015, 0.01), m_star, Vector3(sin(ang) * rr, yy, cos(ang) * rr), Vector3(0, rad_to_deg(ang), 0))
			s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	# --- tronco
	_torso = MeshKit.pivot(_body, Vector3(0, 0.84, 0), "Torso")
	MeshKit.part(_torso, MeshKit.capsule(0.16 * wide, 0.42), m_outfit, Vector3(0, 0.0, 0), Vector3.ZERO, Vector3(1.0, 1.0, 0.85))
	MeshKit.part(_torso, MeshKit.torus(0.13 * wide, 0.17 * wide, 20), m_accent, Vector3(0, -0.14, 0))
	if "shawl" in acc:
		MeshKit.part(_torso, MeshKit.sphere(0.24 * wide, 16, 8, true), Toon.mat(accent.darkened(0.1), {"outline": OUTLINE}), Vector3(0, 0.06, 0), Vector3(180, 0, 0), Vector3(1.0, 0.7, 0.9))
	if "scarf" in acc:
		var scarf_c := Color(appearance.get("scarf_color", "#2fb9a8"))
		var m_scarf := Toon.mat(scarf_c, {"rim": 0.4, "outline": OUTLINE})
		MeshKit.part(_torso, MeshKit.torus(0.08, 0.15, 18), m_scarf, Vector3(0, 0.2, 0), Vector3(8, 0, 0))
		MeshKit.part(_torso, MeshKit.sphere(0.04, 10, 6), m_scarf, Vector3(0.07, 0.17, -0.13))
		MeshKit.part(_torso, MeshKit.capsule(0.028, 0.12), m_scarf, Vector3(0.1, 0.11, -0.13), Vector3(-10, 0, 25))
		MeshKit.part(_torso, MeshKit.capsule(0.028, 0.1), m_scarf, Vector3(0.05, 0.11, -0.14), Vector3(-10, 0, -15))
	if "satchel" in acc:
		MeshKit.part(_torso, MeshKit.box(Vector3(0.14, 0.12, 0.07)), Toon.mat(Color("#8a5a3a"), {"outline": OUTLINE}), Vector3(0.19, -0.2, 0.02))
		MeshKit.part(_torso, MeshKit.torus(0.2, 0.215, 20, 4), Toon.mat(Color("#6a4a2a")), Vector3(0.02, 0.0, 0), Vector3(0, 0, 50), Vector3(1.0, 1.0, 0.55))

	# --- braços
	_arm_l = MeshKit.pivot(_torso, Vector3(-0.2 * wide, 0.14, 0))
	_arm_r = MeshKit.pivot(_torso, Vector3(0.2 * wide, 0.14, 0))
	for arm in [_arm_l, _arm_r]:
		var side := -1.0 if arm == _arm_l else 1.0
		arm.rotation.z = side * 0.12
		if outfit_kind == "robe":
			MeshKit.part(arm, MeshKit.cylinder(0.06, 0.115, 0.34, 12), m_outfit, Vector3(0, -0.17, 0))
			MeshKit.part(arm, MeshKit.torus(0.1, 0.12, 14, 6), m_accent, Vector3(0, -0.335, 0))
		else:
			MeshKit.part(arm, MeshKit.capsule(0.06, 0.34), m_outfit, Vector3(0, -0.15, 0))
		MeshKit.part(arm, MeshKit.sphere(0.055, 10, 6), m_skin, Vector3(0, -0.36, 0))

	if "staff" in acc:
		var staff := MeshKit.pivot(_arm_r, Vector3(0, -0.36, -0.02), "Staff")
		staff.rotation_degrees = Vector3(-8, 0, 0)
		var m_wood := Toon.mat(Color("#7a4f2e"), {"outline": OUTLINE * 0.8})
		MeshKit.part(staff, MeshKit.cylinder(0.018, 0.024, 1.25, 8), m_wood, Vector3(0, 0.1, 0))
		MeshKit.part(staff, MeshKit.torus(0.035, 0.06, 12, 6), m_wood, Vector3(0, 0.76, 0), Vector3(90, 0, 0))
		_crystal = MeshKit.part(staff, MeshKit.crystal(0.055), Toon.glow(Color("#c58cff"), 2.2), Vector3(0, 0.78, 0))
		_crystal_light = MeshKit.light(staff, Color("#c58cff"), 0.5, 2.5, Vector3(0, 0.8, 0))
	if "cane" in acc:
		MeshKit.part(_arm_l, MeshKit.cylinder(0.018, 0.018, 0.85, 8), Toon.mat(Color("#6b4a2a"), {"outline": OUTLINE}), Vector3(0, -0.72, -0.06))
	if "book" in acc:
		_arm_l.rotation_degrees = Vector3(-55, 0, -20)
		MeshKit.part(_arm_l, MeshKit.box(Vector3(0.16, 0.04, 0.22)), Toon.mat(Color("#7a2f3a"), {"outline": OUTLINE}), Vector3(0.04, -0.36, -0.04))

	# --- cabeça
	_head = MeshKit.pivot(_torso, Vector3(0, 0.42 * head_scale, 0), "Head")
	_head.scale = Vector3.ONE * head_scale
	var face := MeshKit.pivot(_head, Vector3.ZERO, "Face")
	MeshKit.part(face, MeshKit.sphere(0.25, 22, 14), m_skin, Vector3.ZERO, Vector3.ZERO, Vector3(1.0, 0.96, 0.98))
	MeshKit.part(face, MeshKit.sphere(0.05, 8, 6), m_skin, Vector3(-0.245, -0.01, 0.0), Vector3.ZERO, Vector3(0.5, 1.0, 0.8))
	MeshKit.part(face, MeshKit.sphere(0.05, 8, 6), m_skin, Vector3(0.245, -0.01, 0.0), Vector3.ZERO, Vector3(0.5, 1.0, 0.8))
	# olhos grandes e expressivos
	var eye_y := -0.01 if age != "child" else -0.02
	for sx in [-1.0, 1.0]:
		var eye := MeshKit.pivot(face, Vector3(sx * 0.088, eye_y, -0.2))
		MeshKit.part(eye, MeshKit.sphere(0.072, 14, 10), m_white, Vector3.ZERO, Vector3.ZERO, Vector3(0.9, 1.15, 0.55))
		MeshKit.part(eye, MeshKit.sphere(0.052, 14, 10), Toon.mat(eye_c, {"unshaded": true}), Vector3(0, -0.006, -0.024), Vector3.ZERO, Vector3(0.9, 1.1, 0.5))
		MeshKit.part(eye, MeshKit.sphere(0.027, 10, 8), Toon.mat(Color("#160f1c"), {"unshaded": true}), Vector3(0, -0.008, -0.04), Vector3.ZERO, Vector3(0.9, 1.1, 0.4))
		MeshKit.part(eye, MeshKit.sphere(0.014, 8, 6), m_white, Vector3(sx * -0.016, 0.022, -0.05))
		MeshKit.part(eye, MeshKit.sphere(0.007, 6, 4), m_white, Vector3(sx * 0.014, -0.024, -0.049))
		# cílios / pálpebra superior
		MeshKit.part(eye, MeshKit.capsule(0.009, 0.12), m_dark, Vector3(sx * 0.005, 0.074, -0.018), Vector3(0, 0, 90 + sx * 12))
		if age != "child" and appearance.get("build", "") != "round":
			MeshKit.part(eye, MeshKit.capsule(0.006, 0.03), m_dark, Vector3(sx * 0.058, 0.058, -0.012), Vector3(0, 0, sx * -40))
		# sobrancelha
		var brow_c := hair.darkened(0.35)
		MeshKit.part(face, MeshKit.capsule(0.009, 0.075), Toon.mat(brow_c), Vector3(sx * 0.09, 0.105, -0.218), Vector3(0, 0, 90 - sx * 8))
		_eyes.append(eye)
	# bochechas, nariz, boca
	var m_blush := Toon.mat(skin.lerp(Color("#ff7a9a"), 0.45), {"unshaded": true})
	for sx in [-1.0, 1.0]:
		MeshKit.part(face, MeshKit.sphere(0.04, 10, 6), m_blush, Vector3(sx * 0.15, -0.085, -0.19), Vector3.ZERO, Vector3(1.2, 0.6, 0.3))
	MeshKit.part(face, MeshKit.sphere(0.022, 8, 6), Toon.mat(skin.darkened(0.08)), Vector3(0, -0.06, -0.245))
	MeshKit.part(face, MeshKit.sphere(0.034, 10, 6, true), Toon.mat(Color("#7a2a3a")), Vector3(0, -0.12, -0.226), Vector3(180, 0, 0), Vector3(1.2, 0.7, 0.45))
	if "freckles" in acc:
		var m_fr := Toon.mat(skin.darkened(0.3), {"unshaded": true})
		for p in [Vector3(-0.13, -0.06, -0.205), Vector3(-0.165, -0.075, -0.19), Vector3(-0.14, -0.095, -0.2), Vector3(0.13, -0.06, -0.205), Vector3(0.165, -0.075, -0.19), Vector3(0.14, -0.095, -0.2)]:
			MeshKit.part(face, MeshKit.sphere(0.006, 6, 4), m_fr, p)
	if "glasses" in acc:
		var m_gl := Toon.mat(Color("#c9a24a"), {"metal": 0.6})
		for sx in [-1.0, 1.0]:
			MeshKit.part(face, MeshKit.torus(0.05, 0.062, 16, 4), m_gl, Vector3(sx * 0.088, -0.01, -0.255), Vector3(90, 0, 0))
		MeshKit.part(face, MeshKit.capsule(0.006, 0.06), m_gl, Vector3(0, 0.0, -0.262), Vector3(0, 0, 90))

	_build_beard(face, appearance.get("beard", "none"), hair)
	_build_hair(_head, appearance.get("hair_style", "short"), m_hair, hair)
	_build_hat(_head, appearance.get("hat", "none"), appearance, m_accent, hair)

	if age == "elder":
		_torso.rotation.x = deg_to_rad(8)
	_ghost_mat = Toon.translucent(Color("#b9a8ff"), 0.35, 0.6)


func _build_beard(face: Node3D, kind: String, hair: Color) -> void:
	var m := Toon.mat(hair, {"rim": 0.3, "outline": OUTLINE})
	match kind:
		"short":
			MeshKit.part(face, MeshKit.sphere(0.16, 14, 8), m, Vector3(0, -0.15, -0.09), Vector3.ZERO, Vector3(1.15, 0.7, 0.9))
		"long":
			MeshKit.part(face, MeshKit.sphere(0.15, 14, 8), m, Vector3(0, -0.16, -0.1), Vector3.ZERO, Vector3(1.1, 0.8, 0.9))
			MeshKit.part(face, MeshKit.cylinder(0.11, 0.02, 0.32, 10), m, Vector3(0, -0.36, -0.12), Vector3(-10, 0, 0))
	if kind != "none":
		MeshKit.part(face, MeshKit.sphere(0.034, 10, 6, true), Toon.mat(Color("#7a2a3a")), Vector3(0, -0.125, -0.236), Vector3(180, 0, 0), Vector3(1.0, 0.5, 0.4))


func _build_hair(head: Node3D, style: String, m_hair: Material, _hair: Color) -> void:
	if style == "bald":
		return
	var hair_root := MeshKit.pivot(head, Vector3.ZERO, "Hair")
	# calota: hemisfério inclinado para trás (deixa o rosto livre)
	MeshKit.part(hair_root, MeshKit.sphere(0.268, 22, 10, true), m_hair, Vector3(0, 0.01, 0.02), Vector3(30, 0, 0), Vector3(1.05, 1.07, 1.05))
	# franja
	for i in 5:
		var x := -0.16 + i * 0.08
		MeshKit.part(hair_root, MeshKit.sphere(0.075, 10, 6), m_hair, Vector3(x, 0.15 - absf(x) * 0.35, -0.17 + absf(x) * 0.12), Vector3(0, 0, -x * 80), Vector3(1.0, 0.75, 0.75))
	match style:
		"long", "long_braid":
			MeshKit.part(hair_root, MeshKit.sphere(0.26, 16, 10), m_hair, Vector3(0, -0.08, 0.08), Vector3.ZERO, Vector3(1.08, 1.0, 0.9))
			for sx in [-1.0, 1.0]:
				MeshKit.part(hair_root, MeshKit.capsule(0.07, 0.36), m_hair, Vector3(sx * 0.21, -0.2, -0.02), Vector3(0, 0, sx * -6))
			if style == "long":
				MeshKit.part(hair_root, MeshKit.capsule(0.17, 0.62), m_hair, Vector3(0, -0.32, 0.12), Vector3(8, 0, 0), Vector3(1.1, 1.0, 0.6))
			else:
				var parent: Node3D = MeshKit.pivot(hair_root, Vector3(0, -0.12, 0.2))
				for i in 6:
					var seg := MeshKit.pivot(parent, Vector3(0, -0.085 if i > 0 else 0.0, 0.0))
					var r := 0.07 - i * 0.006
					MeshKit.part(seg, MeshKit.sphere(r, 12, 8), m_hair, Vector3(0, -0.04, 0), Vector3.ZERO, Vector3(1.0, 1.15, 1.0))
					_braid.append(seg)
					parent = seg
				var tie := MeshKit.part(parent, MeshKit.torus(0.02, 0.045, 12, 6), Toon.mat(Color(appearance.get("scarf_color", "#2fb9a8"))), Vector3(0, -0.1, 0))
				tie.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				MeshKit.part(parent, MeshKit.capsule(0.03, 0.1), m_hair, Vector3(0, -0.16, 0))
		"bun":
			MeshKit.part(hair_root, MeshKit.sphere(0.12, 14, 8), m_hair, Vector3(0, 0.2, 0.14))
			MeshKit.part(hair_root, MeshKit.sphere(0.25, 16, 10), m_hair, Vector3(0, -0.02, 0.06), Vector3.ZERO, Vector3(1.04, 0.95, 0.9))
		"curly":
			var rng := RandomNumberGenerator.new()
			rng.seed = hash(appearance.get("hair_color", ""))
			for i in 16:
				var a := rng.randf_range(-PI * 0.68, PI * 0.68)
				var y := rng.randf_range(-0.22, 0.2)
				var rr := 0.25 + rng.randf_range(0.0, 0.05)
				MeshKit.part(hair_root, MeshKit.sphere(0.085, 10, 6), m_hair, Vector3(sin(a) * rr, y, cos(a) * rr * 0.9 + 0.04))
		"short":
			MeshKit.part(hair_root, MeshKit.sphere(0.25, 16, 10), m_hair, Vector3(0, 0.0, 0.05), Vector3.ZERO, Vector3(1.05, 0.98, 0.95))


func _build_hat(head: Node3D, kind: String, ap: Dictionary, m_accent: Material, _hair: Color) -> void:
	var hat_c := Color(ap.get("hat_color", ap.get("outfit_color", "#3a2068")))
	var m_hat := Toon.mat(hat_c, {"rim": 0.35, "outline": OUTLINE})
	match kind:
		"witch":
			_hat = MeshKit.pivot(head, Vector3(0, 0.19, 0.02), "Hat")
			_hat.rotation_degrees = Vector3(-6, 0, 4)
			MeshKit.part(_hat, MeshKit.cylinder(0.52, 0.52, 0.03, 28), m_hat, Vector3.ZERO, Vector3.ZERO, Vector3(1.0, 1.0, 0.94))
			MeshKit.part(_hat, MeshKit.torus(0.5, 0.54, 28, 6), m_hat, Vector3(0, 0.005, 0), Vector3.ZERO, Vector3(1.0, 1.4, 0.94))
			var seg1 := MeshKit.pivot(_hat, Vector3(0, 0.02, 0))
			MeshKit.part(seg1, MeshKit.cylinder(0.17, 0.27, 0.3, 20), m_hat, Vector3(0, 0.15, 0))
			MeshKit.part(seg1, MeshKit.cylinder(0.255, 0.275, 0.07, 20), m_accent, Vector3(0, 0.04, 0))
			MeshKit.part(seg1, MeshKit.star(0.06, 0.026, 0.02), Toon.glow(Color("#fff3b0"), 1.6), Vector3(0, 0.05, -0.275))
			var seg2 := MeshKit.pivot(seg1, Vector3(0, 0.29, 0))
			seg2.rotation_degrees = Vector3(14, 0, 0)
			MeshKit.part(seg2, MeshKit.cylinder(0.09, 0.17, 0.25, 16), m_hat, Vector3(0, 0.12, 0))
			var seg3 := MeshKit.pivot(seg2, Vector3(0, 0.24, 0))
			seg3.rotation_degrees = Vector3(28, 0, 0)
			MeshKit.part(seg3, MeshKit.cylinder(0.01, 0.09, 0.24, 12), m_hat, Vector3(0, 0.11, 0))
			MeshKit.part(seg3, MeshKit.star(0.04, 0.017, 0.015), Toon.glow(Color("#f3c74f"), 1.8), Vector3(0, 0.25, 0))
			_hat_tip = seg3
		"hood":
			_hat = MeshKit.pivot(head, Vector3(0, 0.0, 0.0), "Hood")
			MeshKit.part(_hat, MeshKit.sphere(0.31, 20, 10, true), m_hat, Vector3(0, 0.0, 0.04), Vector3(38, 0, 0), Vector3(1.0, 1.05, 1.05))
			MeshKit.part(_hat, MeshKit.cylinder(0.0, 0.12, 0.3, 10), m_hat, Vector3(0, 0.1, 0.3), Vector3(105, 0, 0))
			MeshKit.part(_hat, MeshKit.torus(0.285, 0.325, 24, 6), m_hat, Vector3(0, 0.0, 0.04), Vector3(38, 0, 0))
		"straw":
			_hat = MeshKit.pivot(head, Vector3(0, 0.2, 0.0), "Straw")
			var m_straw := Toon.mat(Color("#e8c66a"), {"outline": OUTLINE})
			MeshKit.part(_hat, MeshKit.cylinder(0.46, 0.46, 0.025, 24), m_straw)
			MeshKit.part(_hat, MeshKit.cylinder(0.2, 0.24, 0.16, 18), m_straw, Vector3(0, 0.08, 0))
			MeshKit.part(_hat, MeshKit.cylinder(0.245, 0.245, 0.05, 18), Toon.mat(Color("#c4473a")), Vector3(0, 0.035, 0))
		"flower_crown":
			_hat = MeshKit.pivot(head, Vector3(0, 0.16, 0.02), "Crown")
			_hat.rotation_degrees = Vector3(-12, 0, 0)
			MeshKit.part(_hat, MeshKit.torus(0.2, 0.24, 24, 6), Toon.mat(Color("#5f8f4a")), Vector3.ZERO)
			var cols := ["#ff9fb2", "#fff3a0", "#c8a2ff", "#ffffff", "#ff9fb2", "#8fd6ff", "#fff3a0", "#ffffff"]
			for i in cols.size():
				var a := i * TAU / cols.size()
				MeshKit.part(_hat, MeshKit.sphere(0.04, 8, 6), Toon.mat(Color(cols[i]), {"rim": 0.4}), Vector3(sin(a) * 0.22, 0.02, cos(a) * 0.22))
		"goggles":
			_hat = MeshKit.pivot(head, Vector3(0, 0.12, 0.0), "Goggles")
			MeshKit.part(_hat, MeshKit.torus(0.245, 0.27, 24, 6), Toon.mat(Color("#4a3426")), Vector3.ZERO, Vector3(-10, 0, 0))
			for sx in [-1.0, 1.0]:
				MeshKit.part(_hat, MeshKit.cylinder(0.06, 0.065, 0.06, 14), Toon.mat(Color("#c9a24a"), {"metal": 0.5, "outline": OUTLINE}), Vector3(sx * 0.08, 0.05, -0.22), Vector3(80, 0, 0))
				MeshKit.part(_hat, MeshKit.cylinder(0.048, 0.048, 0.065, 14), Toon.glow(Color("#9fe8ff"), 0.6), Vector3(sx * 0.08, 0.05, -0.222), Vector3(80, 0, 0))
		"cap":
			_hat = MeshKit.pivot(head, Vector3(0, 0.02, 0.0), "Cap")
			MeshKit.part(_hat, MeshKit.sphere(0.27, 18, 8, true), m_hat, Vector3(0, 0.03, 0.02), Vector3(-12, 0, 0))
			MeshKit.part(_hat, MeshKit.box(Vector3(0.24, 0.02, 0.16)), m_hat, Vector3(0, 0.08, -0.27), Vector3(-15, 0, 0))
			MeshKit.part(_hat, MeshKit.sphere(0.03, 8, 6), m_accent, Vector3(0, 0.3, 0.0))


# ---------------------------------------------------------------- animação

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
			if m != null:
				c.transparency = 0.55
			else:
				c.transparency = 0.0
		_apply_overlay(c, m)


static func _w(delta: float, k: float) -> float:
	return 1.0 - exp(-k * delta)


func _process(delta: float) -> void:
	if _body == null:
		return
	_t += delta
	var mv := move_amount
	_phase += delta * (4.0 + 6.0 * mv) * (1.0 if mv > 0.02 else 0.0)
	var step := sin(_phase)
	# corpo
	_body.position.y = absf(step) * 0.045 * mv + sin(_t * 2.0) * 0.006
	_body.rotation.x = lerpf(_body.rotation.x, -0.12 * mv, _w(delta, 6.0))
	_torso.scale = Vector3(1.0, 1.0 + sin(_t * 2.0) * 0.012, 1.0)
	_skirt.rotation.z = step * 0.05 * mv
	_skirt.rotation.x = 0.06 * mv
	# pés
	_foot_l.position.z = step * 0.12 * mv
	_foot_r.position.z = -step * 0.12 * mv
	_foot_l.position.y = 0.06 + maxf(0.0, -step) * 0.05 * mv
	_foot_r.position.y = 0.06 + maxf(0.0, step) * 0.05 * mv
	# braços
	var arm_swing := step * 0.55 * mv
	_arm_l.rotation.x = lerpf(_arm_l.rotation.x, arm_swing + sin(_t * 1.7) * 0.03, _w(delta, 10.0))
	if cast_timer > 0.0:
		cast_timer -= delta
		var k := clampf(cast_timer / 0.7, 0.0, 1.0)
		_arm_r.rotation.x = lerpf(_arm_r.rotation.x, -2.4 * sin(k * PI), _w(delta, 18.0))
		if _crystal_light:
			_crystal_light.light_energy = 0.5 + 3.0 * sin(k * PI)
	elif wave_timer > 0.0:
		wave_timer -= delta
		_arm_r.rotation.x = lerpf(_arm_r.rotation.x, -2.6, _w(delta, 10.0))
		_arm_r.rotation.z = 0.4 + sin(_t * 14.0) * 0.35
	else:
		_arm_r.rotation.x = lerpf(_arm_r.rotation.x, -arm_swing + sin(_t * 1.7 + 1.0) * 0.03, _w(delta, 10.0))
		_arm_r.rotation.z = lerpf(_arm_r.rotation.z, 0.12, _w(delta, 8.0))
		if _crystal_light:
			_crystal_light.light_energy = lerpf(_crystal_light.light_energy, 0.5 + sin(_t * 3.0) * 0.1, _w(delta, 4.0))
	if _crystal:
		_crystal.rotation.y += delta * 1.5
	# cabeça
	var nod := 0.0
	if talk_timer > 0.0:
		talk_timer -= delta
		nod = sin(_t * 9.0) * 0.06
	_head.rotation.x = nod + sin(_t * 0.8) * 0.03
	_head.rotation.y = sin(_t * 0.45) * 0.12 * (1.0 - mv)
	# piscar
	_blink -= delta
	var eye_s := 1.0
	if _blink < 0.0:
		eye_s = 0.12
		if _blink < -0.12:
			_blink = randf_range(2.2, 5.0)
	for e in _eyes:
		e.scale.y = lerpf(e.scale.y, eye_s, _w(delta, 30.0))
	# chapéu e trança com "mola"
	if _hat_tip:
		_hat_tip.rotation.x = deg_to_rad(28) + sin(_t * 1.6) * 0.06 + mv * 0.25 * (0.5 + 0.5 * sin(_phase * 0.5))
		_hat_tip.rotation.z = sin(_t * 1.1) * 0.05
	for i in _braid.size():
		var b := _braid[i]
		b.rotation.x = lerpf(b.rotation.x, mv * 0.35 + sin(_t * 2.0 - i * 0.6) * 0.06, _w(delta, 8.0 - i))
		b.rotation.z = sin(_phase * 0.5 - i * 0.5) * 0.08 * mv
