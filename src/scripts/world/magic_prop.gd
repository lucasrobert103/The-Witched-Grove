class_name MagicProp
extends Interactable
## Objeto do cenário que reage a feitiços com efeitos e TRANSFORMAÇÕES.
## Cada combinação nova (objeto × feitiço) é uma descoberta registrada no grimório.
## Os objetos voltam ao normal a cada novo dia.

const FORMS := {
	"rock": ["rock", "frog", "crystal_flower"],
	"crate": ["crate", "teapot", "gift"],
	"barrel": ["barrel", "sapling", "barrel"],
	"pumpkin": ["pumpkin", "carriage"],
	"dead_bush": ["dead_bush", "rose_bush"],
	"lamp": ["lamp", "flower_lamp"],
	"puddle": ["puddle", "lily_pond"],
	"bud": ["bud", "giant_flower"],
	"stump": ["stump", "mushroom_house"],
	"dough": ["dough"],
}
const NAMES := {
	"rock": "pedra", "frog": "sapo", "crystal_flower": "flor de cristal", "crate": "caixa", "teapot": "bule gigante",
	"gift": "caixa de presente", "barrel": "barril", "sapling": "árvore jovem", "pumpkin": "abóbora",
	"carriage": "carruagem de abóbora", "dead_bush": "arbusto seco", "rose_bush": "roseira", "lamp": "lampião",
	"flower_lamp": "lampião-flor", "puddle": "poça", "lily_pond": "laguinho de lírios", "bud": "botão de flor",
	"giant_flower": "flor gigante", "stump": "toco", "mushroom_house": "casinha de cogumelo", "dough": "massa de pão",
}

var prop_id: String = ""
var kind: String = "rock"
var form: String = "rock"
var form_index: int = 0
var status: String = ""         # "", burning, burned, frozen, lit, grown
var _visual: Node3D
var _fx: Node3D
var _lev_t: float = 0.0
var _shake_t: float = 0.0
var _burn_t: float = 0.0
var _base_y: float = 0.0
var _t: float = 0.0
var _last_day: int = -1


func setup(p_id: String, p_kind: String) -> void:
	prop_id = p_id
	kind = p_kind
	form = kind
	radius = 1.6
	marker_height = 1.4


func _ready() -> void:
	add_to_group("spell_target")
	_base_y = position.y
	_visual = MeshKit.pivot(self)
	_fx = MeshKit.pivot(self)
	_last_day = Game.clock.day()
	_rebuild()


func can_interact() -> bool:
	return false


func accepts_spells() -> bool:
	return true


func refresh_state() -> void:
	if Game.clock.day() != _last_day:
		_last_day = Game.clock.day()
		form_index = 0
		form = kind
		status = ""
		_rebuild()


func display_name() -> String:
	return NAMES.get(form, form)


# ------------------------------------------------------------------ reações

func on_spell(tags: Array, _result: Dictionary) -> bool:
	var before := "%s|%s" % [form, status]
	var tag_used := ""
	if "transfigure" in tags and FORMS[kind].size() > 1 and status != "burned":
		form_index = (form_index + 1) % FORMS[kind].size()
		form = FORMS[kind][form_index]
		status = ""
		tag_used = "transfigurar"
		SpellFX.burst(get_parent(), global_position + Vector3(0, 0.6, 0), Color("#ff9fd6"), 40, 1.2, 2.5)
	elif "fire" in tags:
		tag_used = "fogo"
		match form:
			"lamp", "flower_lamp":
				status = "lit"
			"pumpkin":
				status = "lit"
			"crate", "barrel", "dead_bush", "gift", "teapot", "sapling", "rose_bush", "stump":
				status = "burning"
				_burn_t = 2.2
			"frog":
				status = ""
				say("O sapo pula, ofendido, e fica vermelho de vergonha.", "info")
			"puddle", "lily_pond":
				status = ""
				SpellFX.burst(get_parent(), global_position + Vector3(0, 0.3, 0), Color("#f2f5ff"), 30, 1.0, 1.5)
			_:
				status = "hot"
	elif "ice" in tags:
		tag_used = "gelo"
		status = "frozen"
	elif "grow" in tags:
		tag_used = "crescimento"
		match form:
			"dead_bush":
				form = "rose_bush"
				form_index = 1
			"bud":
				form = "giant_flower"
				form_index = 1
			"stump":
				form = "mushroom_house"
				form_index = 1
			"dough":
				status = "grown"
				if not Game.has_flag("massa_crescida"):
					Game.set_flag("massa_crescida")
					say("A massa estufa, respira e cresce até virar uma nuvem dourada!", "discovery")
			"puddle":
				form = "lily_pond"
				form_index = 1
			_:
				if status == "burned":
					status = ""
					say("Das cinzas brotam florzinhas novas.", "discovery")
				else:
					status = "grown"
	elif "levitate" in tags:
		tag_used = "levitação"
		if form in ["rock", "crate", "barrel", "pumpkin", "frog", "gift", "teapot", "carriage", "crystal_flower"]:
			_lev_t = 6.0
		else:
			say("Isso está preso demais ao chão para flutuar.", "info")
			return true
	elif "wind" in tags:
		tag_used = "vento"
		_shake_t = 1.2
		if form in ["dead_bush", "rose_bush", "bud", "giant_flower", "sapling"]:
			SpellFX.burst(get_parent(), global_position + Vector3(0, 0.8, 0), Color("#9ad46a"), 24, 1.0, 2.0, 0.07)
		if status == "burning":
			status = "burned"
	elif "light" in tags and form in ["lamp", "flower_lamp"]:
		tag_used = "luz"
		status = "lit"
	if tag_used == "":
		return false
	var after := "%s|%s" % [form, status]
	_rebuild()
	if after != before or tag_used == "levitação":
		_register_discovery(tag_used)
	return true


func _register_discovery(tag_used: String) -> void:
	var key := "transf.%s.%s" % [kind, tag_used]
	if Game.has_flag(key):
		return
	Game.set_flag(key)
	Game.add_school_xp("transmutation", 2.0)
	var desc := "%s → %s" % [NAMES.get(kind, kind), display_name()]
	if status != "":
		desc += " (%s)" % {"lit": "acesa", "frozen": "congelada", "burning": "em chamas", "burned": "em cinzas", "grown": "enorme", "hot": "em brasa"}.get(status, status)
	if tag_used == "levitação":
		desc = "%s flutua no ar" % NAMES.get(kind, kind)
	Game.discover("transformacao", key, "Descoberta mágica (%s): %s." % [tag_used, desc])


# ------------------------------------------------------------------ visual

func _rebuild() -> void:
	if _visual == null:
		return
	for c in _visual.get_children():
		c.queue_free()
	for c in _fx.get_children():
		c.queue_free()
	var frozen := status == "frozen"
	var tint := Color("#bfe9ff") if frozen else Color.WHITE
	_build_form(form, tint)
	if status == "burned":
		for c in _visual.get_children():
			c.queue_free()
		MeshKit.part(_visual, MeshKit.sphere(0.45, 10, 6, true), Toon.mat(Color("#4a4448")), Vector3.ZERO, Vector3.ZERO, Vector3(1.2, 0.35, 1.2))
		for k in 3:
			MeshKit.part(_visual, MeshKit.sphere(0.06, 6, 4), Toon.glow(Color("#ff7a3c"), 1.5), Vector3(sin(k * 2.0) * 0.2, 0.08, cos(k * 2.0) * 0.2))
	if status == "burning":
		var f := _fire()
		f.position.y = 0.4
		_fx.add_child(f)
		MeshKit.light(_fx, Color("#ff9a3c"), 1.6, 4.0, Vector3(0, 1.0, 0))
	if status == "lit":
		MeshKit.light(_fx, Color("#ffcf6a"), 1.8, 6.0, Vector3(0, 1.0 if form != "pumpkin" else 0.5, 0))
	if status == "hot":
		MeshKit.light(_fx, Color("#ff5a2a"), 1.0, 2.5, Vector3(0, 0.6, 0))
	if frozen:
		for k in 5:
			var a := k * TAU / 5.0
			MeshKit.part(_fx, MeshKit.crystal(0.12 + (k % 2) * 0.06), Toon.mat(Color("#dff4ff"), {"alpha": 0.75, "emission": 0.4}), Vector3(sin(a) * 0.45, 0.2, cos(a) * 0.45), Vector3(0, k * 40, (k - 2) * 12))
	if status == "grown":
		_visual.scale = Vector3.ONE * 1.8
	else:
		_visual.scale = Vector3.ONE


func _m(c: Color, tint: Color, opts: Dictionary = {}) -> StandardMaterial3D:
	var o := opts.duplicate()
	if not o.has("outline"):
		o["outline"] = 0.015
	o["rim"] = 0.3
	return Toon.mat(c * tint if tint != Color.WHITE else c, o)


func _build_form(f: String, tint: Color) -> void:
	var v := _visual
	match f:
		"rock":
			MeshKit.part(v, MeshKit.rock(hash(prop_id) % 10, 0.5), _m(Color("#9894a8"), tint), Vector3(0, 0.25, 0))
		"frog":
			var frog := FrogModel.new()
			frog.scale = Vector3.ONE * 2.6
			v.add_child(frog)
		"crystal_flower":
			MeshKit.part(v, MeshKit.cylinder(0.02, 0.03, 0.6, 6), _m(Color("#7fd6b0"), tint), Vector3(0, 0.3, 0))
			for k in 6:
				var a := k * TAU / 6.0
				MeshKit.part(v, MeshKit.crystal(0.1), Toon.glow(Color("#c8b4ff"), 1.6), Vector3(sin(a) * 0.14, 0.66, cos(a) * 0.14), Vector3(cos(a) * 60, 0, -sin(a) * 60))
			MeshKit.light(v, Color("#c8b4ff"), 0.8, 3.0, Vector3(0, 0.7, 0))
		"crate":
			MeshKit.part(v, MeshKit.box(Vector3(0.8, 0.7, 0.8)), _m(Color("#a8743e"), tint), Vector3(0, 0.35, 0))
			for y in [0.12, 0.58]:
				MeshKit.part(v, MeshKit.box(Vector3(0.82, 0.08, 0.82)), _m(Color("#7a4f2a"), tint), Vector3(0, y, 0))
		"teapot":
			MeshKit.part(v, MeshKit.sphere(0.5, 16, 10), _m(Color("#7fb0d8"), tint), Vector3(0, 0.5, 0), Vector3.ZERO, Vector3(1.0, 0.85, 1.0))
			MeshKit.part(v, MeshKit.cylinder(0.05, 0.12, 0.5, 8), _m(Color("#7fb0d8"), tint), Vector3(0.55, 0.6, 0), Vector3(0, 0, -50))
			MeshKit.part(v, MeshKit.torus(0.15, 0.22, 12, 6), _m(Color("#5a8ab0"), tint), Vector3(-0.5, 0.55, 0), Vector3(90, 0, 0))
			MeshKit.part(v, MeshKit.sphere(0.12, 10, 6), _m(Color("#f3c74f"), tint), Vector3(0, 0.98, 0))
			var steam := _steam()
			steam.position = Vector3(0.8, 0.85, 0)
			_fx.add_child(steam)
		"gift":
			MeshKit.part(v, MeshKit.box(Vector3(0.75, 0.65, 0.75)), _m(Color("#e8574a"), tint), Vector3(0, 0.33, 0))
			MeshKit.part(v, MeshKit.box(Vector3(0.16, 0.67, 0.77)), _m(Color("#f3c74f"), tint), Vector3(0, 0.33, 0))
			MeshKit.part(v, MeshKit.box(Vector3(0.77, 0.67, 0.16)), _m(Color("#f3c74f"), tint), Vector3(0, 0.33, 0))
			for sx in [-1.0, 1.0]:
				MeshKit.part(v, MeshKit.torus(0.06, 0.14, 12, 6), _m(Color("#f3c74f"), tint), Vector3(sx * 0.12, 0.72, 0), Vector3(0, 0, 90 + sx * 30))
		"barrel":
			MeshKit.part(v, MeshKit.cylinder(0.36, 0.36, 0.9, 16), _m(Color("#8a5a36"), tint), Vector3(0, 0.45, 0))
			MeshKit.part(v, MeshKit.sphere(0.42, 16, 8), _m(Color("#8a5a36"), tint), Vector3(0, 0.45, 0), Vector3.ZERO, Vector3(1.0, 1.05, 1.0))
			for y in [0.15, 0.75]:
				MeshKit.part(v, MeshKit.torus(0.37, 0.42, 18, 4), _m(Color("#4a4a52"), tint), Vector3(0, y, 0))
		"sapling":
			MeshKit.part(v, MeshKit.cylinder(0.06, 0.1, 1.2, 8), _m(Color("#7a5236"), tint), Vector3(0, 0.6, 0))
			for k in 3:
				MeshKit.part(v, MeshKit.sphere(0.45 - k * 0.08, 12, 8), _m(Color("#6fcf5c"), tint), Vector3(sin(k * 2.0) * 0.2, 1.3 + k * 0.25, cos(k * 2.0) * 0.2))
		"pumpkin":
			for k in 6:
				var a := k * TAU / 6.0
				MeshKit.part(v, MeshKit.sphere(0.32, 12, 8), _m(Color("#f08a2a"), tint), Vector3(sin(a) * 0.15, 0.3, cos(a) * 0.15), Vector3.ZERO, Vector3(0.75, 0.9, 0.75))
			MeshKit.part(v, MeshKit.cylinder(0.03, 0.05, 0.18, 6), _m(Color("#4f8a3a"), tint), Vector3(0, 0.65, 0), Vector3(0, 0, 12))
			if status == "lit":
				for sx in [-1.0, 1.0]:
					MeshKit.part(v, MeshKit.prism(Vector3(0.1, 0.1, 0.02)), Toon.glow(Color("#ffd27a"), 3.0), Vector3(sx * 0.12, 0.38, -0.44))
				MeshKit.part(v, MeshKit.box(Vector3(0.24, 0.05, 0.02)), Toon.glow(Color("#ffd27a"), 3.0), Vector3(0, 0.22, -0.45))
		"carriage":
			for k in 8:
				var a := k * TAU / 8.0
				MeshKit.part(v, MeshKit.sphere(0.7, 14, 10), _m(Color("#f08a2a"), tint), Vector3(sin(a) * 0.35, 1.1, cos(a) * 0.35), Vector3.ZERO, Vector3(0.7, 1.0, 0.7))
			MeshKit.part(v, MeshKit.torus(0.8, 0.9, 20, 6), _m(Color("#f3c74f"), tint), Vector3(0, 1.1, 0), Vector3(90, 0, 0), Vector3(1.1, 1.1, 0.3))
			for p in [Vector3(-0.8, 0.4, 0.7), Vector3(0.8, 0.4, 0.7), Vector3(-0.8, 0.4, -0.7), Vector3(0.8, 0.4, -0.7)]:
				MeshKit.part(v, MeshKit.torus(0.3, 0.38, 16, 4), _m(Color("#f3c74f"), tint), p, Vector3(0, 0, 90))
			MeshKit.part(v, MeshKit.box(Vector3(0.5, 0.6, 0.04)), Toon.glow(Color("#fff3c4"), 1.2), Vector3(0, 1.1, -0.97))
			MeshKit.part(v, MeshKit.cylinder(0.05, 0.1, 0.35, 6), _m(Color("#4f8a3a"), tint), Vector3(0, 1.95, 0))
		"dead_bush":
			for k in 7:
				var a := k * TAU / 7.0
				MeshKit.part(v, MeshKit.cylinder(0.01, 0.03, 0.7, 4), _m(Color("#6b5a48"), tint), Vector3(sin(a) * 0.15, 0.3, cos(a) * 0.15), Vector3(cos(a) * 30, 0, -sin(a) * 30))
		"rose_bush":
			MeshKit.part(v, MeshKit.sphere(0.6, 14, 8), _m(Color("#4f9f55"), tint), Vector3(0, 0.5, 0), Vector3.ZERO, Vector3(1.0, 0.8, 1.0))
			for k in 9:
				var a := k * 2.4
				MeshKit.part(v, MeshKit.sphere(0.1, 8, 6), _m(Color(["#ff5a7a", "#ff9fb2", "#fff3a0"][k % 3]), tint, {"emission": 0.3, "outline": 0.008}), Vector3(sin(a) * 0.45, 0.5 + cos(a * 1.7) * 0.25, cos(a) * 0.45))
		"lamp", "flower_lamp":
			MeshKit.part(v, MeshKit.cylinder(0.05, 0.08, 1.8, 6), _m(Color("#3a3444"), tint), Vector3(0, 0.9, 0))
			if f == "lamp":
				MeshKit.part(v, MeshKit.cylinder(0.12, 0.2, 0.3, 6), _m(Color("#3a3444"), tint), Vector3(0, 1.95, 0))
				MeshKit.part(v, MeshKit.sphere(0.13, 10, 6), Toon.glow(Color("#ffd27a"), 2.5) if status == "lit" else _m(Color("#e8e2d8"), tint), Vector3(0, 1.8, 0))
			else:
				for k in 5:
					var a := k * TAU / 5.0
					MeshKit.part(v, MeshKit.sphere(0.16, 8, 4), _m(Color("#ff9fb2"), tint, {"emission": 0.6}), Vector3(sin(a) * 0.18, 1.9, cos(a) * 0.18), Vector3.ZERO, Vector3(1.0, 0.4, 1.0))
				MeshKit.part(v, MeshKit.sphere(0.12, 10, 6), Toon.glow(Color("#fff3a0"), 2.5 if status == "lit" else 0.8), Vector3(0, 1.92, 0))
		"puddle":
			MeshKit.part(v, MeshKit.cylinder(0.9, 0.9, 0.03, 18), Toon.mat(Color("#cfeeff") if status == "frozen" else Color("#6ab0d8"), {"alpha": 0.85, "emission": 0.15}), Vector3(0, 0.03, 0), Vector3.ZERO, Vector3(1.0, 1.0, 0.7))
		"lily_pond":
			MeshKit.part(v, MeshKit.cylinder(0.95, 0.95, 0.03, 18), Toon.mat(Color("#5ab0d8"), {"alpha": 0.85, "emission": 0.15}), Vector3(0, 0.03, 0), Vector3.ZERO, Vector3(1.0, 1.0, 0.7))
			for k in 4:
				MeshKit.part(v, MeshKit.cylinder(0.2, 0.2, 0.02, 10), _m(Color("#4fae5a"), tint), Vector3(sin(k * 1.6) * 0.5, 0.06, cos(k * 1.6) * 0.35))
				MeshKit.part(v, MeshKit.sphere(0.07, 8, 4), _m(Color("#ffd1f0"), tint, {"emission": 0.4}), Vector3(sin(k * 1.6) * 0.5, 0.1, cos(k * 1.6) * 0.35))
		"bud":
			MeshKit.part(v, MeshKit.cylinder(0.015, 0.02, 0.5, 5), _m(Color("#4f9f55"), tint), Vector3(0, 0.25, 0))
			MeshKit.part(v, MeshKit.sphere(0.09, 10, 6), _m(Color("#ff9fb2"), tint), Vector3(0, 0.55, 0), Vector3.ZERO, Vector3(0.8, 1.3, 0.8))
		"giant_flower":
			MeshKit.part(v, MeshKit.cylinder(0.05, 0.08, 2.2, 8), _m(Color("#4f9f55"), tint), Vector3(0, 1.1, 0))
			MeshKit.part(v, MeshKit.sphere(0.4, 10, 6), _m(Color("#4f9f55"), tint), Vector3(0.3, 0.8, 0), Vector3(0, 0, 40), Vector3(1.0, 0.2, 0.6))
			var head := MeshKit.pivot(v, Vector3(0, 2.25, 0))
			head.rotation_degrees.x = -20
			for k in 8:
				var a := k * TAU / 8.0
				MeshKit.part(head, MeshKit.sphere(0.32, 10, 6), _m(Color("#ff9fb2"), tint, {"emission": 0.2}), Vector3(sin(a) * 0.38, 0, cos(a) * 0.38), Vector3.ZERO, Vector3(1.0, 0.25, 0.6))
			MeshKit.part(head, MeshKit.sphere(0.2, 12, 8), Toon.glow(Color("#fff3a0"), 1.2), Vector3(0, 0.05, 0), Vector3.ZERO, Vector3(1.0, 0.5, 1.0))
		"stump":
			MeshKit.part(v, MeshKit.cylinder(0.4, 0.5, 0.5, 12), _m(Color("#7a5236"), tint), Vector3(0, 0.25, 0))
			MeshKit.part(v, MeshKit.cylinder(0.38, 0.38, 0.02, 12), _m(Color("#d9b98a"), tint), Vector3(0, 0.51, 0))
		"mushroom_house":
			MeshKit.part(v, MeshKit.cylinder(0.55, 0.65, 1.2, 14), _m(Color("#f3e6cf"), tint), Vector3(0, 0.6, 0))
			MeshKit.part(v, MeshKit.sphere(1.0, 16, 10, true), _m(Color("#d9442f"), tint), Vector3(0, 1.15, 0), Vector3.ZERO, Vector3(1.0, 0.7, 1.0))
			MeshKit.part(v, MeshKit.box(Vector3(0.3, 0.5, 0.04)), _m(Color("#7a4a2a"), tint), Vector3(0, 0.3, -0.62))
			MeshKit.part(v, MeshKit.cylinder(0.12, 0.12, 0.04, 10), Toon.glow(Color("#ffd27a"), 1.5), Vector3(0.3, 0.8, -0.58), Vector3(90, 0, 0))
			for k in 6:
				var a := k * 1.1
				MeshKit.part(v, MeshKit.sphere(0.12, 8, 4), _m(Color("#fff6e6"), tint), Vector3(sin(a) * 0.7, 1.45, cos(a) * 0.7), Vector3.ZERO, Vector3(1.0, 0.4, 1.0))
		"dough":
			var grown := status == "grown"
			MeshKit.part(v, MeshKit.cylinder(0.32, 0.36, 0.08, 16), _m(Color("#c8a27a"), tint), Vector3(0, 0.04, 0))
			MeshKit.part(v, MeshKit.sphere(0.28, 14, 8, true), _m(Color("#f2deb8"), tint), Vector3(0, 0.08, 0), Vector3.ZERO, Vector3(1.0, 1.6 if grown else 0.25, 1.0))
			if grown:
				MeshKit.light(v, Color("#ffd27a"), 0.6, 2.0, Vector3(0, 0.5, 0))


func _fire() -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = 24
	p.lifetime = 0.8
	p.direction = Vector3.UP
	p.spread = 20.0
	p.initial_velocity_min = 0.8
	p.initial_velocity_max = 1.6
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.35
	p.scale_amount_min = 0.15
	p.scale_amount_max = 0.3
	var curve := Curve.new()
	curve.add_point(Vector2(0, 1))
	curve.add_point(Vector2(1, 0))
	p.scale_amount_curve = curve
	var m := SphereMesh.new()
	m.radius = 0.5
	m.height = 1.0
	m.radial_segments = 6
	m.rings = 3
	m.material = Toon.glow(Color("#7fd6ff"), 2.5)
	p.mesh = m
	return p


func _steam() -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = 8
	p.lifetime = 2.0
	p.direction = Vector3.UP
	p.spread = 15.0
	p.initial_velocity_min = 0.4
	p.initial_velocity_max = 0.7
	p.gravity = Vector3.ZERO
	p.scale_amount_min = 0.1
	p.scale_amount_max = 0.2
	var m := SphereMesh.new()
	m.radius = 0.5
	m.height = 1.0
	m.radial_segments = 6
	m.rings = 3
	m.material = Toon.translucent(Color.WHITE, 0.5)
	p.mesh = m
	return p


func _process(delta: float) -> void:
	_t += delta
	if _lev_t > 0.0:
		_lev_t -= delta
		var up := 2.0 if _lev_t > 0.6 else 2.0 * (_lev_t / 0.6)
		position.y = lerpf(position.y, _base_y + up + sin(_t * 3.0) * 0.15, 1.0 - exp(-4.0 * delta))
		_visual.rotation.y += delta * 1.5
		if _lev_t <= 0.0:
			position.y = _base_y
			_visual.rotation = Vector3.ZERO
			SpellFX.burst(get_parent(), global_position + Vector3(0, 0.1, 0), Color("#d8c8a8"), 14, 0.8, 1.2, 0.08)
	if _shake_t > 0.0:
		_shake_t -= delta
		_visual.rotation.z = sin(_t * 30.0) * 0.12 * _shake_t
	if status == "burning":
		_burn_t -= delta
		if _burn_t <= 0.0:
			status = "burned"
			_rebuild()
